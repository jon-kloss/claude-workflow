#!/usr/bin/env bash
# Smoke test for the role-agent hook system.
#
# What this DOES test:
#   - require-handoff-artifact.sh fires correctly per spec @layer
#   - require-release-handoff.sh blocks/allows bd close epic
#   - Handoff schema validation (missing meta, missing section, slug mismatch)
#   - @handoff-skip and @release-skip overrides
#   - Phase B agent expected-handoffs (devops, data) per @layer + @touches-data
#
# What this does NOT test:
#   - That real role agents produce well-formed handoffs (requires real Agent dispatch)
#   - That the SKILL.md text correctly orchestrates the agents (requires fresh session)
#   - That `/impeccable` Skill invocations are tracked correctly (requires Skill tool)
#
# Usage:  bash tests/role-agent-smoke.sh
# Exit:   0 if all pass, non-zero with count of failures otherwise.

set -uo pipefail

WORKFLOW_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_DIR="$WORKFLOW_DIR/hooks"
TMP="$(mktemp -d -t role-smoke.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
TOTAL=0

# Hooks now block via `exit 2 + stderr message` (not stdout JSON). Existing
# test bodies pipe a payload into the hook and capture the output with 2>&1
# (merge stderr into stdout), so the captured `$got` will contain BLOCKED on
# blocking paths and {} on allow paths. The assert below checks both.
assert() {
    local name="$1" expected="$2" got="$3"
    TOTAL=$((TOTAL+1))
    if [ "$expected" = "block" ]; then
        if echo "$got" | grep -q "BLOCKED"; then
            echo "  PASS  $name"; PASS=$((PASS+1))
        else
            echo "  FAIL  $name (expected BLOCK, got: ${got:0:120})"; FAIL=$((FAIL+1))
        fi
    elif [ "$expected" = "allow" ]; then
        if echo "$got" | grep -q '^{}$' || [ -z "$got" ]; then
            echo "  PASS  $name"; PASS=$((PASS+1))
        else
            echo "  FAIL  $name (expected ALLOW, got: ${got:0:120})"; FAIL=$((FAIL+1))
        fi
    fi
}

mkpayload_edit() {
    local file="$1" content="$2"
    FILE="$file" CONTENT="$content" python3 -c '
import json, os
print(json.dumps({"tool":{"name":"Edit","input":{"file_path":os.environ["FILE"],"new_string":os.environ["CONTENT"]}}}))'
}

mkpayload_bash() {
    local cmd="$1"
    CMD="$cmd" python3 -c '
import json, os
print(json.dumps({"tool":{"name":"Bash","input":{"command":os.environ["CMD"]}}}))'
}

write_handoff() {
    local dir="$1" step="$2" slug="$3" role="$4"
    cat > "${dir}/${step}-${slug}-${role}.html" <<EOF
<!DOCTYPE html><html lang="en" data-handoff-version="1"><head>
<meta charset="utf-8">
<meta data-from-role="${role}">
<meta data-spec-slug="${slug}">
<meta data-step="${step}">
<meta data-produced-at="2026-05-25T18:00:00Z">
<meta data-input-references="">
<title>x</title></head><body>
<section data-role="summary"><p>x</p></section>
<section data-role="findings"><p>x</p></section>
<section data-role="acceptance-criteria"><dl><dt data-id="a">x</dt><dd data-check="x">PASS</dd></dl></section>
<section data-role="open-questions"><ul></ul></section>
</body></html>
EOF
}

# Set up a fake project under $TMP
mkdir -p "$TMP/specs/handoffs"
cd "$TMP" || exit 1

echo "=== require-handoff-artifact.sh ==="

# @layer(api) — expects 7 handoffs
cat > specs/api-feature.md <<'EOF'
@status(approved)
@layer(api)

## Investigation Findings
- src/a.ts:1
- src/b.ts:2
- decision
EOF
PAYLOAD=$(mkpayload_edit "$TMP/specs/api-feature.md" '@status(verified)')

result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "api-spec with no handoffs blocks" block "$result"

for h in product-owner application-architect security-architect qa-engineer backend-engineer devops-architect data-architect; do
    case "$h" in
        product-owner)         step=step-2 ;;
        application-architect) step=step-2.5 ;;
        backend-engineer)      step=step-3.2 ;;
        security-architect|devops-architect|data-architect) step=step-3.3 ;;
        qa-engineer)           step=step-3.3 ;;
    esac
    write_handoff specs/handoffs "$step" api-feature "$h"
done
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "api-spec with all 7 handoffs allows" allow "$result"

# Schema violation: remove data-from-role from one handoff
sed -i '' '/data-from-role/d' specs/handoffs/step-3.3-api-feature-security-architect.html
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "missing data-from-role schema violation blocks" block "$result"
write_handoff specs/handoffs step-3.3 api-feature security-architect  # restore

# Slug mismatch
sed -i '' 's/data-spec-slug="api-feature"/data-spec-slug="wrong-slug"/' specs/handoffs/step-3.3-api-feature-security-architect.html
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "slug mismatch blocks" block "$result"
write_handoff specs/handoffs step-3.3 api-feature security-architect  # restore

# @handoff-skip override
rm specs/handoffs/step-3.3-api-feature-security-architect.html
PAYLOAD_SKIP=$(mkpayload_edit "$TMP/specs/api-feature.md" '@status(verified)
@handoff-skip(security-architect: synthetic test no security surface)')
result=$(printf '%s\n' "$PAYLOAD_SKIP" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "@handoff-skip allows when handoff missing" allow "$result"
write_handoff specs/handoffs step-3.3 api-feature security-architect

# @trivial bypass
cat > specs/trivial.md <<'EOF'
@status(approved)
@layer(infra)
@trivial
EOF
PAYLOAD_TRIV=$(mkpayload_edit "$TMP/specs/trivial.md" '@status(verified)')
result=$(printf '%s\n' "$PAYLOAD_TRIV" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "@trivial bypasses all handoff requirements" allow "$result"

# @layer(ui) without @touches-data — no data-architect required
cat > specs/ui-feature.md <<'EOF'
@status(approved)
@layer(ui)

## Investigation Findings
- src/a.tsx:1
- src/b.tsx:2
- decision
EOF
for h in product-owner application-architect security-architect qa-engineer uiux-designer frontend-engineer devops-architect; do
    case "$h" in
        product-owner)         step=step-2 ;;
        application-architect) step=step-2.5 ;;
        uiux-designer)         step=step-2.85 ;;
        frontend-engineer)     step=step-3.2 ;;
        security-architect|devops-architect) step=step-3.3 ;;
        qa-engineer)           step=step-3.3 ;;
    esac
    write_handoff specs/handoffs "$step" ui-feature "$h"
done
PAYLOAD_UI=$(mkpayload_edit "$TMP/specs/ui-feature.md" '@status(verified)')
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "ui-spec (no @touches-data) allows without data-architect" allow "$result"

# Now add @touches-data — should block until data-architect present
sed -i '' '/^@layer(ui)/a\
@touches-data
' specs/ui-feature.md
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "ui-spec + @touches-data blocks without data-architect" block "$result"

write_handoff specs/handoffs step-3.3 ui-feature data-architect
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "ui-spec + @touches-data + data-architect allows" allow "$result"

# Critical-blocking aside causes failure
cat >> specs/handoffs/step-3.3-ui-feature-security-architect.html <<'EOF'
<aside data-severity="critical" data-blocks-next-step="true"><p>do not proceed</p></aside>
EOF
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "critical-blocking aside blocks" block "$result"

echo ""
echo "=== require-release-handoff.sh ==="

# We use the workflow repo's actual bd db, but with synthetic test issues.
# Switch back to the workflow dir so `bd` works.
cd "$WORKFLOW_DIR" || exit 1

# Regression: build-test (2026-05-25) found that bd with --type=epic auto-displays [EPIC]
# uppercase in bd show output, but require-release-handoff.sh's grep was case-sensitive
# '[epic]'. The hook never matched → silent under-block. Use --type=epic here, NOT
# --type=feature with [epic] in title (the latter doesn't reproduce the bug because
# bd echoes the title verbatim).
EPIC_ID=$(bd create --title="SMOKE TEST release hook (uppercase prefix)" --description="smoke test, ignore" --type=epic --priority=4 2>&1 | grep -oE 'workflow-[a-z0-9]+' | head -1)
NONEPIC_ID=$(bd create --title="smoke non-epic" --description="smoke test, ignore" --type=task --priority=4 2>&1 | grep -oE 'workflow-[a-z0-9]+' | head -1)

if [ -z "$EPIC_ID" ] || [ -z "$NONEPIC_ID" ]; then
    echo "  SKIP  release-handoff tests (could not create synthetic bd issues)"
else
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $NONEPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "non-epic bd close allows" allow "$result"

    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "epic bd close without handoff blocks" block "$result"

    # Add a release handoff with PASS verdict — put it in workflow repo's specs/handoffs/
    mkdir -p specs/handoffs
    cat > "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html" <<EOF
<!DOCTYPE html><html lang="en" data-handoff-version="1"><head>
<meta data-from-role="release-coordinator"><meta data-spec-slug="${EPIC_ID}">
<meta data-step="x"><meta data-produced-at="x"><meta data-input-references="">
<title>x</title></head><body><section data-role="summary"></section>
<section data-role="findings"></section>
<section data-role="acceptance-criteria"></section>
<section data-role="open-questions"></section>
<p>Verdict: READY-TO-CLOSE</p></body></html>
EOF
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "epic bd close with PASS verdict allows" allow "$result"

    sed -i '' 's/READY-TO-CLOSE/BLOCKED/' "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html"
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "epic bd close with BLOCKED verdict blocks" block "$result"

    rm "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html"
    bd comments add "$EPIC_ID" "RELEASE-SKIP: smoke test override" > /dev/null 2>&1
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "RELEASE-SKIP bd comment override allows" allow "$result"

    # Cleanup
    bd close "$EPIC_ID" --reason="smoke test cleanup" > /dev/null 2>&1
    bd close "$NONEPIC_ID" --reason="smoke test cleanup" > /dev/null 2>&1
fi

echo ""
echo "=== installed-form regressions (require ~/.claude/hooks/ to reflect a real install) ==="
# These tests catch the 2026-05-25 build-test regression: install.sh was only globbing
# *.sh and skipping *.py helpers like _validate_handoff.py. The earlier smoke tests
# all ran against the workflow repo's hooks/ directly, so they couldn't catch the
# install-symlink path. These regressions check the installed form.

TOTAL=$((TOTAL+1))
if [ -f "$HOME/.claude/hooks/_validate_handoff.py" ]; then
    echo "  PASS  _validate_handoff.py present in ~/.claude/hooks/ (install.sh symlinked *.py)"
    PASS=$((PASS+1))
else
    echo "  FAIL  _validate_handoff.py MISSING from ~/.claude/hooks/ — install.sh did not symlink *.py helpers"
    echo "        (run: cd $WORKFLOW_DIR && bash install.sh)"
    FAIL=$((FAIL+1))
fi

# Regression: require-handoff-artifact.sh must degrade gracefully when validator missing.
# We can't easily simulate "missing validator" without touching the install (classifier
# would block), so we check the hook source for the defensive guard pattern.
TOTAL=$((TOTAL+1))
if grep -q 'VALIDATOR=' "$HOOK_DIR/require-handoff-artifact.sh" && \
   grep -q 'if \[ ! -f "\$VALIDATOR" \]' "$HOOK_DIR/require-handoff-artifact.sh"; then
    echo "  PASS  require-handoff-artifact.sh has defensive validator-existence guard"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-handoff-artifact.sh lacks defensive validator check — will hard-block silently on missing _validate_handoff.py"
    FAIL=$((FAIL+1))
fi

# Regression: require-release-handoff.sh must use case-insensitive [epic] grep.
TOTAL=$((TOTAL+1))
if grep -qE 'grep -[a-z]*i[a-z]*E.*\\\[epic\\\]' "$HOOK_DIR/require-release-handoff.sh"; then
    echo "  PASS  require-release-handoff.sh uses case-insensitive [epic] grep"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-release-handoff.sh has case-sensitive [epic] regex — will miss [EPIC] uppercase from bd --type=epic"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== /onboard skill + agent-memory regressions ==="

# /onboard skill installed
TOTAL=$((TOTAL+1))
if [ -f "$HOME/.claude/skills/onboard/SKILL.md" ]; then
    echo "  PASS  /onboard skill installed at ~/.claude/skills/onboard/SKILL.md"
    PASS=$((PASS+1))
else
    echo "  FAIL  /onboard SKILL.md missing from install"
    FAIL=$((FAIL+1))
fi

# All 16 memory templates exist in the repo (11 original + 5 game-design)
TOTAL=$((TOTAL+1))
template_count=$(ls "$WORKFLOW_DIR"/skills/onboard/resources/memory-template-*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$template_count" -eq 16 ]; then
    echo "  PASS  16 memory templates present in skills/onboard/resources/"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 16 memory templates, found $template_count"
    FAIL=$((FAIL+1))
fi

# _detect_memory_secrets.py symlinked
TOTAL=$((TOTAL+1))
if [ -f "$HOME/.claude/hooks/_detect_memory_secrets.py" ]; then
    echo "  PASS  _detect_memory_secrets.py present in ~/.claude/hooks/"
    PASS=$((PASS+1))
else
    echo "  FAIL  _detect_memory_secrets.py MISSING — secret-guard hook won't function"
    FAIL=$((FAIL+1))
fi

# guard-agent-memory-secrets.sh blocks JWT in agent-memory write
TOTAL=$((TOTAL+1))
PAYLOAD=$(FILE="/proj/.claude/agent-memory/backend-engineer.md" \
          CONTENT="Token leaked: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" \
          python3 -c 'import json, os; print(json.dumps({"tool":{"name":"Edit","input":{"file_path":os.environ["FILE"],"new_string":os.environ["CONTENT"]}}}))')
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/guard-agent-memory-secrets.sh" 2>&1)
if echo "$result" | grep -q "BLOCKED" && echo "$result" | grep -q "JWT"; then
    echo "  PASS  guard-agent-memory-secrets blocks JWT-shaped content"
    PASS=$((PASS+1))
else
    echo "  FAIL  guard-agent-memory-secrets did not block JWT"
    FAIL=$((FAIL+1))
fi

# guard-agent-memory-secrets.sh allows benign pointer text
TOTAL=$((TOTAL+1))
PAYLOAD=$(FILE="/proj/.claude/agent-memory/security-architect.md" \
          CONTENT="Secrets live in env vars. See devops-architect.md#pointer-secret-handling for details." \
          python3 -c 'import json, os; print(json.dumps({"tool":{"name":"Edit","input":{"file_path":os.environ["FILE"],"new_string":os.environ["CONTENT"]}}}))')
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/guard-agent-memory-secrets.sh" 2>&1)
if [ "$result" = "{}" ]; then
    echo "  PASS  guard-agent-memory-secrets allows pointer text"
    PASS=$((PASS+1))
else
    echo "  FAIL  guard-agent-memory-secrets incorrectly blocked pointer text: ${result:0:120}"
    FAIL=$((FAIL+1))
fi

# guard-agent-memory-secrets.sh allows @memory-allow-secret override
TOTAL=$((TOTAL+1))
PAYLOAD=$(FILE="/proj/.claude/agent-memory/qa-engineer.md" \
          CONTENT="Public test fixture: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0In0.test @memory-allow-secret(known-public test fixture)" \
          python3 -c 'import json, os; print(json.dumps({"tool":{"name":"Edit","input":{"file_path":os.environ["FILE"],"new_string":os.environ["CONTENT"]}}}))')
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/guard-agent-memory-secrets.sh" 2>&1)
if [ "$result" = "{}" ]; then
    echo "  PASS  @memory-allow-secret override allows the write"
    PASS=$((PASS+1))
else
    echo "  FAIL  @memory-allow-secret override did not work"
    FAIL=$((FAIL+1))
fi

# All 16 agent prompts have the memory block (11 original + 5 game-design)
TOTAL=$((TOTAL+1))
agents_with_memory=$(grep -lE '^## Memory: read first, update last' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if [ "$agents_with_memory" -eq 16 ]; then
    echo "  PASS  all 16 agent prompts have the Memory section"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 16 agents with Memory block, found $agents_with_memory"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== /onboard regressions from 2026-05-26 SquashBuckler dogfood ==="

# workflow-hkg: bootstrap prompt must document bootstrap-LAZY content per role
# so qa-engineer doesn't eagerly write a per-spec test inventory.
TOTAL=$((TOTAL+1))
if grep -q 'Per-role bootstrap scope (eager vs lazy)' "$WORKFLOW_DIR/skills/onboard/SKILL.md" && \
   grep -q 'Bootstrap-LAZY content for your role' "$WORKFLOW_DIR/skills/onboard/SKILL.md"; then
    echo "  PASS  /onboard SKILL.md documents per-role bootstrap-LAZY scope"
    PASS=$((PASS+1))
else
    echo "  FAIL  /onboard SKILL.md missing per-role bootstrap-LAZY scope guidance (workflow-hkg regression)"
    FAIL=$((FAIL+1))
fi

# workflow-hkg part 2: qa-engineer template must call out the lazy section explicitly
TOTAL=$((TOTAL+1))
if grep -q 'BOOTSTRAP SCOPE' "$WORKFLOW_DIR/skills/onboard/resources/memory-template-qa-engineer.md" && \
   grep -q 'Test inventory (lazy' "$WORKFLOW_DIR/skills/onboard/resources/memory-template-qa-engineer.md"; then
    echo "  PASS  qa-engineer template has Bootstrap-scope + lazy Test-inventory section"
    PASS=$((PASS+1))
else
    echo "  FAIL  qa-engineer template missing lazy-scope guidance (workflow-hkg regression)"
    FAIL=$((FAIL+1))
fi

# workflow-1y5: dispatch prompt must specify seconds-precision timestamp
TOTAL=$((TOTAL+1))
if grep -q 'seconds precision' "$WORKFLOW_DIR/skills/onboard/SKILL.md" && \
   grep -q 'date -u +%Y-%m-%dT%H:%M:%SZ' "$WORKFLOW_DIR/skills/onboard/SKILL.md"; then
    echo "  PASS  /onboard SKILL.md specifies seconds-precision timestamp"
    PASS=$((PASS+1))
else
    echo "  FAIL  /onboard SKILL.md missing seconds-precision timestamp guidance (workflow-1y5 regression)"
    FAIL=$((FAIL+1))
fi

# workflow-1y5 part 2: validator step must check for T00:00:00Z stubs
TOTAL=$((TOTAL+1))
if grep -q 'T00:00:00Z' "$WORKFLOW_DIR/skills/onboard/SKILL.md"; then
    echo "  PASS  /onboard SKILL.md validator references T00:00:00Z stub timestamps"
    PASS=$((PASS+1))
else
    echo "  FAIL  /onboard SKILL.md validator missing T00:00:00Z stub check (workflow-1y5 regression)"
    FAIL=$((FAIL+1))
fi

# workflow-1y5 part 3: every template should signal seconds-precision in its frontmatter placeholder
TOTAL=$((TOTAL+1))
templates_with_precision=$(grep -lE 'at seconds precision' "$WORKFLOW_DIR/skills/onboard/resources/"memory-template-*.md | wc -l | tr -d ' ')
if [ "$templates_with_precision" -eq 16 ]; then
    echo "  PASS  all 16 templates use seconds-precision timestamp placeholder"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 16 templates with seconds-precision placeholder, found $templates_with_precision (workflow-1y5 regression)"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== fix-cycle handoff symmetry + exit checklists (2026-05-26 SquashBuckler session) ==="

# workflow-b66: require-fix-cycle-handoff.sh hook exists and is registered
TOTAL=$((TOTAL+1))
if [ -f "$HOOK_DIR/require-fix-cycle-handoff.sh" ] && [ -x "$HOOK_DIR/require-fix-cycle-handoff.sh" ]; then
    echo "  PASS  require-fix-cycle-handoff.sh present and executable"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-fix-cycle-handoff.sh missing or not executable"
    FAIL=$((FAIL+1))
fi

TOTAL=$((TOTAL+1))
if grep -q 'require-fix-cycle-handoff.sh' "$WORKFLOW_DIR/install.sh"; then
    echo "  PASS  require-fix-cycle-handoff.sh registered in install.sh"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-fix-cycle-handoff.sh not registered in install.sh"
    FAIL=$((FAIL+1))
fi

# Hook behavior tests — build a synthetic project with handoffs and exercise
FC_TMP="$TMP/fix-cycle-test"
mkdir -p "$FC_TMP/specs/handoffs"
FC_SPEC="$FC_TMP/specs/example-feature.md"
echo "@layer(api)" > "$FC_SPEC"
FC_VERIFIED_CONTENT="@layer(api) @status(verified)"

# Case 1: no cycle handoffs at all => allow (base-handoff hook owns the non-cycle case)
got=$(mkpayload_edit "$FC_SPEC" "$FC_VERIFIED_CONTENT" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "no fix-cycle handoffs at all -> allow" "allow" "$got"

# Case 2: cycle 1 has BOTH implementer + reviewer => allow
touch "$FC_TMP/specs/handoffs/step-3.2-example-feature-backend-engineer-fix-cycle-1.html"
touch "$FC_TMP/specs/handoffs/step-3.3-example-feature-qa-engineer-cycle-1.html"
got=$(mkpayload_edit "$FC_SPEC" "$FC_VERIFIED_CONTENT" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "cycle 1 symmetric (impl + reviewer) -> allow" "allow" "$got"

# Case 3: cycle 2 has reviewer but NOT implementer (the actual bug) => block
touch "$FC_TMP/specs/handoffs/step-3.3-example-feature-qa-engineer-cycle-2.html"
got=$(mkpayload_edit "$FC_SPEC" "$FC_VERIFIED_CONTENT" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "cycle 2 reviewer-only (the bug) -> block" "block" "$got"

# Case 4: cycle 2 implementer added => allow
touch "$FC_TMP/specs/handoffs/step-3.2-example-feature-backend-engineer-fix-cycle-2.html"
got=$(mkpayload_edit "$FC_SPEC" "$FC_VERIFIED_CONTENT" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "cycle 2 now symmetric -> allow" "allow" "$got"

# Case 5: cycle 3 has implementer but NOT reviewer => block (other direction)
touch "$FC_TMP/specs/handoffs/step-3.2-example-feature-backend-engineer-fix-cycle-3.html"
got=$(mkpayload_edit "$FC_SPEC" "$FC_VERIFIED_CONTENT" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "cycle 3 implementer-only (no re-verify) -> block" "block" "$got"

# Case 6: @fix-cycle-skip(3: reason) override => allow
FC_VERIFIED_SKIP="@layer(api) @status(verified) @fix-cycle-skip(3: reviewer findings withdrawn after re-investigation — see workflow-st3 and commit 9c88227)"
got=$(mkpayload_edit "$FC_SPEC" "$FC_VERIFIED_SKIP" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "cycle 3 with @fix-cycle-skip(3: ...) -> allow" "allow" "$got"

# Case 7: @trivial spec bypasses fix-cycle check
FC_TRIVIAL_SPEC="$FC_TMP/specs/trivial-fix.md"
echo "@layer(api) @trivial" > "$FC_TRIVIAL_SPEC"
got=$(mkpayload_edit "$FC_TRIVIAL_SPEC" "@layer(api) @trivial @status(verified)" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "@trivial spec bypasses fix-cycle hook" "allow" "$got"

# workflow-myr: every agent has the terminal Exit checklist section
# Total agent count is now 16 (11 original + 5 game-design)
TOTAL=$((TOTAL+1))
agents_with_exit=$(grep -lE '^## Exit checklist \(run before returning\)' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if [ "$agents_with_exit" -eq 16 ]; then
    echo "  PASS  all 16 agents have terminal Exit checklist section"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 16 agents with Exit checklist, found $agents_with_exit (workflow-myr regression)"
    FAIL=$((FAIL+1))
fi

# workflow-myr: exit checklist names handoff-write as terminal step
TOTAL=$((TOTAL+1))
agents_with_terminal_handoff=$(grep -lE 'TERMINAL|handoff file is NOT|verbal confirmation is NOT the deliverable' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if [ "$agents_with_terminal_handoff" -ge 16 ]; then
    echo "  PASS  all agents emphasize handoff-as-deliverable in exit checklist"
    PASS=$((PASS+1))
else
    echo "  FAIL  only $agents_with_terminal_handoff/16 agents emphasize terminal handoff-write"
    FAIL=$((FAIL+1))
fi

# workflow-1bo: sleep-poll anti-pattern guidance present in agent prompts
TOTAL=$((TOTAL+1))
agents_with_sleep_warn=$(grep -lE 'do not poll background tasks with .sleep' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if [ "$agents_with_sleep_warn" -eq 16 ]; then
    echo "  PASS  all 16 agents carry sleep-poll anti-pattern warning"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 16 agents with sleep-poll warning, found $agents_with_sleep_warn (workflow-1bo regression)"
    FAIL=$((FAIL+1))
fi

# workflow-1bo: build/SKILL.md Step 3.3h references the sleep anti-pattern
TOTAL=$((TOTAL+1))
if grep -q 'Do not sleep-poll background work' "$WORKFLOW_DIR/skills/build/SKILL.md"; then
    echo "  PASS  build/SKILL.md Step 3.3h flags sleep-poll anti-pattern"
    PASS=$((PASS+1))
else
    echo "  FAIL  build/SKILL.md missing sleep-poll guidance in Step 3.3h"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== Game-design agents (workflow-5wm epic) ==="

# All 5 new game agents exist
for agent in game-designer level-designer narrative-designer systems-designer game-ui-designer; do
    TOTAL=$((TOTAL+1))
    if [ -f "$WORKFLOW_DIR/agents/${agent}.md" ]; then
        echo "  PASS  agents/${agent}.md present"
        PASS=$((PASS+1))
    else
        echo "  FAIL  agents/${agent}.md missing"
        FAIL=$((FAIL+1))
    fi
done

# All 5 new memory templates exist
for agent in game-designer level-designer narrative-designer systems-designer game-ui-designer; do
    TOTAL=$((TOTAL+1))
    if [ -f "$WORKFLOW_DIR/skills/onboard/resources/memory-template-${agent}.md" ]; then
        echo "  PASS  memory-template-${agent}.md present"
        PASS=$((PASS+1))
    else
        echo "  FAIL  memory-template-${agent}.md missing"
        FAIL=$((FAIL+1))
    fi
done

# game-context template exists
TOTAL=$((TOTAL+1))
if [ -f "$WORKFLOW_DIR/skills/onboard/resources/game-context-template.md" ]; then
    echo "  PASS  game-context-template.md present"
    PASS=$((PASS+1))
else
    echo "  FAIL  game-context-template.md missing"
    FAIL=$((FAIL+1))
fi

# require-layer-tag.sh accepts @layer(gameplay)
LT_TMP="$TMP/layer-test/specs"
mkdir -p "$LT_TMP"
LT_SPEC="$LT_TMP/gameplay-spec.md"
got=$(mkpayload_edit "$LT_SPEC" "@status(approved) @layer(gameplay) Feature: combat loop" | bash "$HOOK_DIR/require-layer-tag.sh" 2>&1 || true)
assert "@layer(gameplay) accepted by require-layer-tag.sh" "allow" "$got"

# require-layer-tag.sh still blocks without any layer
got=$(mkpayload_edit "$LT_SPEC" "@status(approved) Feature: no layer" | bash "$HOOK_DIR/require-layer-tag.sh" 2>&1 || true)
assert "spec without @layer still blocked" "block" "$got"

# require-handoff-artifact.sh: game-context.md presence triggers game-designer expectation
# Set up synthetic game project
GP_TMP="$TMP/game-project"
mkdir -p "$GP_TMP/specs/handoffs" "$GP_TMP/.claude"
echo "# Game Context (test fixture)" > "$GP_TMP/.claude/game-context.md"
GP_SPEC="$GP_TMP/specs/core-loop.md"
echo "@layer(gameplay)" > "$GP_SPEC"

# Without ANY handoffs, the verified write blocks (multiple missing including game-designer)
got=$(mkpayload_edit "$GP_SPEC" "@layer(gameplay) @status(verified)" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1 || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q "step-2.3-core-loop-game-designer.html"; then
    echo "  PASS  require-handoff-artifact.sh expects step-2.3-<slug>-game-designer.html when .claude/game-context.md present"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-handoff-artifact.sh does NOT expect game-designer on game project (workflow-5wm regression)"
    FAIL=$((FAIL+1))
fi

# require-handoff-artifact.sh: NO game-context.md => no game handoffs expected
NG_TMP="$TMP/non-game-project"
mkdir -p "$NG_TMP/specs/handoffs"
NG_SPEC="$NG_TMP/specs/regular-api.md"
echo "@layer(api)" > "$NG_SPEC"

got=$(mkpayload_edit "$NG_SPEC" "@layer(api) @status(verified)" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1 || true)
TOTAL=$((TOTAL+1))
if ! echo "$got" | grep -q "game-designer\|level-designer\|narrative-designer\|systems-designer"; then
    echo "  PASS  require-handoff-artifact.sh does NOT expect game handoffs on non-game project"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-handoff-artifact.sh incorrectly expects game handoffs without game-context.md"
    FAIL=$((FAIL+1))
fi

# require-handoff-artifact.sh: @surface(game) routes to game-ui-designer instead of uiux-designer
GUI_SPEC="$GP_TMP/specs/hud-spec.md"
echo "@layer(ui)" > "$GUI_SPEC"
got=$(mkpayload_edit "$GUI_SPEC" "@layer(ui) @surface(game) @status(verified)" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1 || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q "step-2.85-hud-spec-game-ui-designer.html" && ! echo "$got" | grep -q "step-2.85-hud-spec-uiux-designer.html"; then
    echo "  PASS  @surface(game) routes UI spec to game-ui-designer (not uiux-designer)"
    PASS=$((PASS+1))
else
    echo "  FAIL  @surface(game) routing incorrect"
    FAIL=$((FAIL+1))
fi

# workflow-st3: require-release-handoff.sh title-line-only check (non-epic with epic parent allows)
TOTAL=$((TOTAL+1))
if grep -q 'title_line=' "$HOOK_DIR/require-release-handoff.sh" && \
   grep -q 'head -n 1' "$HOOK_DIR/require-release-handoff.sh"; then
    echo "  PASS  require-release-handoff.sh restricts [epic] check to title line (workflow-st3 fix)"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-release-handoff.sh missing title-line restriction (workflow-st3 regression)"
    FAIL=$((FAIL+1))
fi

# Onboard SKILL.md documents conditional game-agent dispatch
TOTAL=$((TOTAL+1))
if grep -q 'Game-design agents (conditional)' "$WORKFLOW_DIR/skills/onboard/SKILL.md" && \
   grep -q 'game-context.md exists' "$WORKFLOW_DIR/skills/onboard/SKILL.md"; then
    echo "  PASS  /onboard SKILL.md documents conditional game-agent dispatch"
    PASS=$((PASS+1))
else
    echo "  FAIL  /onboard SKILL.md missing game-agent dispatch guidance"
    FAIL=$((FAIL+1))
fi

# Design SKILL.md has Step 2.3 (game-designer) and Step 2.7 (parallel game design)
TOTAL=$((TOTAL+1))
if grep -q 'Step 2.3: Game Design' "$WORKFLOW_DIR/skills/design/SKILL.md" && \
   grep -q 'Step 2.7: Per-spec Game Design' "$WORKFLOW_DIR/skills/design/SKILL.md"; then
    echo "  PASS  /design SKILL.md has Step 2.3 + Step 2.7 game-design steps"
    PASS=$((PASS+1))
else
    echo "  FAIL  /design SKILL.md missing game-design steps"
    FAIL=$((FAIL+1))
fi

# Design SKILL.md Step 2.85 documents @surface(game) routing
TOTAL=$((TOTAL+1))
if grep -q '@surface(game)' "$WORKFLOW_DIR/skills/design/SKILL.md" && \
   grep -q 'game-ui-designer' "$WORKFLOW_DIR/skills/design/SKILL.md"; then
    echo "  PASS  /design SKILL.md Step 2.85 documents @surface(game) → game-ui-designer routing"
    PASS=$((PASS+1))
else
    echo "  FAIL  /design SKILL.md Step 2.85 missing @surface(game) routing"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== override-reason quality validator (workflow-ccw / 2026-05-27 adversarial pressure) ==="

# Validator file exists
TOTAL=$((TOTAL+1))
if [ -f "$HOOK_DIR/_validate_override_reason.py" ]; then
    echo "  PASS  _validate_override_reason.py present"
    PASS=$((PASS+1))
else
    echo "  FAIL  _validate_override_reason.py missing"
    FAIL=$((FAIL+1))
fi

# Direct validator behavior tests
VALIDATOR_PY="$HOOK_DIR/_validate_override_reason.py"

vtest_pass() {
    local name="$1" reason="$2"
    TOTAL=$((TOTAL+1))
    if python3 "$VALIDATOR_PY" "test" "@tag" "-" "$reason" >/dev/null 2>&1; then
        echo "  PASS  validator accepts: $name"
        PASS=$((PASS+1))
    else
        echo "  FAIL  validator should accept '$name' but rejected"
        FAIL=$((FAIL+1))
    fi
}

vtest_fail() {
    local name="$1" reason="$2" expected_substr="$3"
    TOTAL=$((TOTAL+1))
    out=$(python3 "$VALIDATOR_PY" "test" "@tag" "-" "$reason" 2>&1)
    rc=$?
    if [ $rc -ne 0 ] && echo "$out" | grep -q "$expected_substr"; then
        echo "  PASS  validator rejects: $name"
        PASS=$((PASS+1))
    else
        echo "  FAIL  validator should reject '$name' with '$expected_substr' (rc=$rc, got: ${out:0:120})"
        FAIL=$((FAIL+1))
    fi
}

# Rejected cases
vtest_fail "empty string"        "" "empty"
vtest_fail "too short"           "ok fine" "minimum is 30"
vtest_fail "stop phrase only"    "covered elsewhere covered elsewhere" "stop-phrase"
vtest_fail "long but no anchor"  "the build is broken because of a temporary issue with the configuration" "concrete reference"
vtest_fail "padded n/a"          "n/a n/a n/a n/a n/a n/a n/a n/a n/a" "stop-phrase"

# Accepted cases (must include a concrete reference)
vtest_pass "commit SHA reference"      "fix landed in commit 9c88227 — verified locally with running app"
vtest_pass "beads ID reference"        "tracked in workflow-abc1; this hook can't see across project boundary"
vtest_pass "file path reference"       "evidence is in tests/role-agent-smoke.sh case 4 — verified passing"
vtest_pass "URL reference"             "see https://github.com/jon-kloss/claude-workflow/pull/2 for full context"
vtest_pass "user authorization"        "user authorized this bypass after reviewing the diff manually"
vtest_pass "per-name citation"         "per jon: deferred until after the release cut on 2026-06-01"

# Audit log gets a line on PASS
AUDIT_LOG_PATH="$HOME/.claude/hooks/state/override-audit.log"
TOTAL=$((TOTAL+1))
# Use unique marker reason so we don't false-positive on prior runs
unique_marker="audit-test-$(date +%s%N)"
unique_reason="audit log entry verification ${unique_marker} via commit 9c88227"
python3 "$VALIDATOR_PY" "smoke-test" "@audit-tag" "smoke-role" "$unique_reason" >/dev/null 2>&1
if [ -f "$AUDIT_LOG_PATH" ] && grep -q "$unique_marker" "$AUDIT_LOG_PATH"; then
    echo "  PASS  audit log appended on validation pass"
    PASS=$((PASS+1))
else
    echo "  FAIL  audit log entry not found for marker $unique_marker"
    FAIL=$((FAIL+1))
fi

# Integration: guard-handoff-owner.sh enforces validator on @handoff-author-skip
# Re-use the GHO_TMP/state set up earlier — at this point gho-test has the
# guard-handoff-owner state and the file path conventions. Build fresh tmp.
OR_TMP="$TMP/override-test"
mkdir -p "$OR_TMP/specs/handoffs" "$OR_TMP/.claude/hooks/state"

# Empty session log; no dispatch logged for frontend-engineer
HANDOFF_PATH="$OR_TMP/specs/handoffs/step-3.2-myslug-frontend-engineer.html"
# Bad reason ("documented")
content_bad='<html data-handoff-version="1"></html><!-- @handoff-author-skip(frontend-engineer: documented) -->'
got=$(mkpayload_edit "$HANDOFF_PATH" "$content_bad" | (cd "$OR_TMP" && HOME="$OR_TMP" bash "$HOOK_DIR/guard-handoff-owner.sh" 2>&1) || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q "override reason failed quality validation"; then
    echo "  PASS  guard-handoff-owner blocks trivial @handoff-author-skip reason"
    PASS=$((PASS+1))
else
    echo "  FAIL  guard-handoff-owner accepted trivial override reason (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# Good reason with file-path reference
content_good='<html data-handoff-version="1"></html><!-- @handoff-author-skip(frontend-engineer: subagent inline-synthesis fallback per docs/role-agent-handoff-schema.md — no Agent tool available) -->'
got=$(mkpayload_edit "$HANDOFF_PATH" "$content_good" | (cd "$OR_TMP" && HOME="$OR_TMP" bash "$HOOK_DIR/guard-handoff-owner.sh" 2>&1) || true)
assert "guard-handoff-owner accepts quality override reason" "allow" "$got"

# Integration: require-fix-cycle-handoff.sh enforces validator on @fix-cycle-skip
FC_SPEC2="$OR_TMP/specs/cycle-test.md"
mkdir -p "$OR_TMP/specs/handoffs"
touch "$OR_TMP/specs/handoffs/step-3.3-cycle-test-qa-engineer-cycle-1.html"
echo "@layer(api)" > "$FC_SPEC2"
# Bad reason
bad_skip_content="@layer(api) @status(verified) @fix-cycle-skip(1: n/a)"
got=$(mkpayload_edit "$FC_SPEC2" "$bad_skip_content" | (cd "$OR_TMP" && bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1) || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q "override reason failed quality validation"; then
    echo "  PASS  require-fix-cycle-handoff blocks trivial @fix-cycle-skip reason"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-fix-cycle-handoff accepted trivial reason (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# Good reason
good_skip_content="@layer(api) @status(verified) @fix-cycle-skip(1: reviewer findings were withdrawn after re-investigation in commit 9c88227 — see workflow-ccw)"
got=$(mkpayload_edit "$FC_SPEC2" "$good_skip_content" | (cd "$OR_TMP" && bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1) || true)
# Expected: the cycle is now skipped (validator passed), but cycle 1 has reviewer
# handoff but no implementer => normal asymmetry block, NOT the validator block
TOTAL=$((TOTAL+1))
if ! echo "$got" | grep -q "override reason failed"; then
    echo "  PASS  require-fix-cycle-handoff accepts quality @fix-cycle-skip reason (validator pass)"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-fix-cycle-handoff rejected a quality reason (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# Integration: _validate_handoff.py enforces validator on data-resolution-skip
RV_TMP="$TMP/override-resolve-test"
mkdir -p "$RV_TMP/specs/handoffs"
RV_HOFF="$RV_TMP/specs/handoffs/step-3.3-test-spec-devops-architect.html"
# Build minimal handoff with trivial data-resolution-skip
cat > "$RV_HOFF" <<HOFF
<!DOCTYPE html>
<html lang="en" data-handoff-version="1">
<head>
<meta charset="utf-8">
<meta data-from-role="devops-architect">
<meta data-spec-slug="test-spec">
<meta data-step="3.3">
<meta data-produced-at="2026-05-27T00:00:00Z">
<meta data-input-references="(none)">
<title>devops-architect handoff</title>
</head>
<body>
<section data-role="summary"><p>summary</p></section>
<section data-role="findings">
<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolution-skip="documented"><h2>Bad override</h2></aside>
</section>
<section data-role="acceptance-criteria"><dl><dt data-id="ac-1">x</dt><dd>x</dd></dl></section>
<section data-role="open-questions"><ul></ul></section>
</body>
</html>
HOFF
TOTAL=$((TOTAL+1))
out=$(python3 "$HOOK_DIR/_validate_handoff.py" "$RV_HOFF" "test-spec" "devops-architect" 2>&1)
if echo "$out" | grep -q "data-resolution-skip reason failed quality check"; then
    echo "  PASS  _validate_handoff rejects trivial data-resolution-skip reason"
    PASS=$((PASS+1))
else
    echo "  FAIL  _validate_handoff accepted trivial data-resolution-skip (got: ${out:0:200})"
    FAIL=$((FAIL+1))
fi

# Good data-resolution-skip
cat > "$RV_HOFF" <<HOFF
<!DOCTYPE html>
<html lang="en" data-handoff-version="1">
<head>
<meta charset="utf-8">
<meta data-from-role="devops-architect">
<meta data-spec-slug="test-spec">
<meta data-step="3.3">
<meta data-produced-at="2026-05-27T00:00:00Z">
<meta data-input-references="(none)">
<title>devops-architect handoff</title>
</head>
<body>
<section data-role="summary"><p>summary</p></section>
<section data-role="findings">
<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolution-skip="upstream library fix landed in vendored dep — see commit 9c88227 for the patch we applied locally"><h2>Documented bypass</h2></aside>
</section>
<section data-role="acceptance-criteria"><dl><dt data-id="ac-1">x</dt><dd>x</dd></dl></section>
<section data-role="open-questions"><ul></ul></section>
</body>
</html>
HOFF
TOTAL=$((TOTAL+1))
out=$(python3 "$HOOK_DIR/_validate_handoff.py" "$RV_HOFF" "test-spec" "devops-architect" 2>&1)
if [ -z "$out" ]; then
    echo "  PASS  _validate_handoff accepts quality data-resolution-skip reason"
    PASS=$((PASS+1))
else
    echo "  FAIL  _validate_handoff rejected a quality data-resolution-skip (got: ${out:0:200})"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== memory-update warn hooks (workflow-gq3 / 2026-05-27 user observation) ==="

# Both hook files present
for h in track-agent-memory-baseline.sh warn-agent-memory-not-updated.sh; do
    TOTAL=$((TOTAL+1))
    if [ -f "$HOOK_DIR/$h" ]; then
        echo "  PASS  $h present"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $h missing"
        FAIL=$((FAIL+1))
    fi
done

# Both registered in install.sh
for h in track-agent-memory-baseline.sh warn-agent-memory-not-updated.sh; do
    TOTAL=$((TOTAL+1))
    if grep -q "$h" "$WORKFLOW_DIR/install.sh"; then
        echo "  PASS  $h registered in install.sh"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $h not registered in install.sh"
        FAIL=$((FAIL+1))
    fi
done

# Behavior tests — synthetic project with memory file
MEM_TMP="$TMP/memory-warn-test"
mkdir -p "$MEM_TMP/.claude/agent-memory" "$MEM_TMP/.claude/hooks/state"
MEM_FILE="$MEM_TMP/.claude/agent-memory/backend-engineer.md"
echo "# backend-engineer — project memory" > "$MEM_FILE"

# Helper: build Agent payload
mkpayload_agent() {
    local subagent_type="$1" prompt="$2"
    SUB="$subagent_type" P="$prompt" python3 -c '
import json, os
print(json.dumps({"tool":{"name":"Agent","input":{"subagent_type":os.environ["SUB"],"prompt":os.environ["P"]}}}))'
}

# Helper: run baseline + warn hook in isolated HOME with project as cwd
run_baseline() {
    local subagent_type="$1" prompt="$2"
    mkpayload_agent "$subagent_type" "$prompt" | (cd "$MEM_TMP" && HOME="$MEM_TMP" bash "$HOOK_DIR/track-agent-memory-baseline.sh" 2>&1)
}
run_warn() {
    local subagent_type="$1" prompt="$2"
    mkpayload_agent "$subagent_type" "$prompt" | (cd "$MEM_TMP" && HOME="$MEM_TMP" bash "$HOOK_DIR/warn-agent-memory-not-updated.sh" 2>&1)
}

# Case 1: baseline records mtime
run_baseline "backend-engineer" "test prompt" > /dev/null
TOTAL=$((TOTAL+1))
if [ -f "$MEM_TMP/.claude/hooks/state/agent-memory-baseline-backend-engineer.txt" ]; then
    echo "  PASS  baseline hook records pre-dispatch mtime"
    PASS=$((PASS+1))
else
    echo "  FAIL  baseline hook did not record mtime"
    FAIL=$((FAIL+1))
fi

# Case 2: memory unchanged → warn emits additionalContext
got=$(run_warn "backend-engineer" "test prompt")
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q '"additionalContext"' && echo "$got" | grep -q "WARNING.*backend-engineer.*not modified"; then
    echo "  PASS  warn hook emits additionalContext when memory unchanged"
    PASS=$((PASS+1))
else
    echo "  FAIL  warn hook did not emit warning for unchanged memory (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# Case 3: memory updated → no warning
sleep 1  # ensure mtime can advance
echo "## Recent changes" >> "$MEM_FILE"
got=$(run_warn "backend-engineer" "test prompt")
TOTAL=$((TOTAL+1))
if [ "$got" = "{}" ]; then
    echo "  PASS  warn hook is silent when memory was updated"
    PASS=$((PASS+1))
else
    echo "  FAIL  warn hook emitted warning even though memory was updated (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# Case 4: @memory-update-skip override suppresses warning
run_baseline "backend-engineer" "trivial dispatch with @memory-update-skip(backend-engineer: spec is @trivial typo fix in workflow-test123 — no memory delta needed)" > /dev/null
got=$(run_warn "backend-engineer" "trivial dispatch with @memory-update-skip(backend-engineer: spec is @trivial typo fix in workflow-test123 — no memory delta needed)")
TOTAL=$((TOTAL+1))
if [ "$got" = "{}" ]; then
    echo "  PASS  @memory-update-skip(role: reason) override suppresses warning"
    PASS=$((PASS+1))
else
    echo "  FAIL  @memory-update-skip override was not respected (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# Case 5: non-role subagent_type ignored
got=$(run_warn "general-purpose" "doing something")
TOTAL=$((TOTAL+1))
if [ "$got" = "{}" ]; then
    echo "  PASS  non-role subagent_type (general-purpose) is ignored"
    PASS=$((PASS+1))
else
    echo "  FAIL  hook fired on general-purpose subagent (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# Case 6: memory file missing → no warning
rm "$MEM_FILE"
rm -f "$MEM_TMP/.claude/hooks/state/agent-memory-baseline-backend-engineer.txt"
run_baseline "backend-engineer" "test" > /dev/null
TOTAL=$((TOTAL+1))
if [ ! -f "$MEM_TMP/.claude/hooks/state/agent-memory-baseline-backend-engineer.txt" ]; then
    echo "  PASS  baseline hook skips when memory file does not exist"
    PASS=$((PASS+1))
else
    echo "  FAIL  baseline hook recorded mtime for nonexistent file"
    FAIL=$((FAIL+1))
fi

got=$(run_warn "backend-engineer" "test")
TOTAL=$((TOTAL+1))
if [ "$got" = "{}" ]; then
    echo "  PASS  warn hook silent when memory file does not exist (pre-/onboard)"
    PASS=$((PASS+1))
else
    echo "  FAIL  warn hook fired with no memory file present (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== aside resolution-pointer validation (workflow-ax6 / 2026-05-27 bypass) ==="

# Set up project root for resolution tests
AX_TMP="$TMP/aside-test"
mkdir -p "$AX_TMP/specs/handoffs"

# Helper: write minimal valid handoff with caller-controlled <aside>
write_handoff() {
    local outpath="$1"
    local from_role="$2"
    local slug="$3"
    local extra="$4"
    cat > "$outpath" <<HOFF
<!DOCTYPE html>
<html lang="en" data-handoff-version="1">
<head>
<meta charset="utf-8">
<meta data-from-role="${from_role}">
<meta data-spec-slug="${slug}">
<meta data-step="3.3">
<meta data-produced-at="2026-05-27T00:00:00Z">
<meta data-input-references="(none)">
<title>${from_role} handoff</title>
</head>
<body>
<section data-role="summary"><p>summary</p></section>
<section data-role="findings">
<h1>Findings</h1>
${extra}
</section>
<section data-role="acceptance-criteria"><dl><dt data-id="ac-1">test</dt><dd>n/a</dd></dl></section>
<section data-role="open-questions"><ul></ul></section>
</body>
</html>
HOFF
}

# Case 1: aside flipped to false with NO pointers => validator emits error
TARGET="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect.html"
write_handoff "$TARGET" "devops-architect" "test-spec" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false"><h2>Resolved without proof</h2></aside>'
TOTAL=$((TOTAL+1))
out=$(python3 "$WORKFLOW_DIR/hooks/_validate_handoff.py" "$TARGET" "test-spec" "devops-architect" 2>&1)
if echo "$out" | grep -q "missing data-resolved-in"; then
    echo "  PASS  validator flags aside flipped to false with no data-resolved-in"
    PASS=$((PASS+1))
else
    echo "  FAIL  validator did not catch missing data-resolved-in (got: ${out:0:120})"
    FAIL=$((FAIL+1))
fi

# Case 2: pointer present but points to non-existent file
TARGET2="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect-cycle-1.html"
write_handoff "$TARGET2" "devops-architect" "test-spec" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolved-in="specs/handoffs/does-not-exist.html" data-re-verified-in="specs/handoffs/also-missing.html"><h2>Orphan pointers</h2></aside>'
TOTAL=$((TOTAL+1))
out=$(python3 "$WORKFLOW_DIR/hooks/_validate_handoff.py" "$TARGET2" "test-spec" "devops-architect" 2>&1)
if echo "$out" | grep -q "does not exist on disk"; then
    echo "  PASS  validator flags data-resolved-in pointing to non-existent file"
    PASS=$((PASS+1))
else
    echo "  FAIL  validator did not catch orphan data-resolved-in pointer (got: ${out:0:120})"
    FAIL=$((FAIL+1))
fi

# Case 3: pointers valid AND re-verify is clean => allow
# Build fix-cycle implementer handoff
FIX_HOFF="$AX_TMP/specs/handoffs/step-3.2-test-spec-backend-engineer-fix-cycle-1.html"
write_handoff "$FIX_HOFF" "backend-engineer" "test-spec" '<p>Fix applied at file:line</p>'
# Build re-verify handoff with NO unresolved critical aside
REVERIFY_HOFF="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect-cycle-1.html"
write_handoff "$REVERIFY_HOFF" "devops-architect" "test-spec" '<p>Re-verified clean</p>'
# Original handoff points to both
TARGET3="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect.html"
write_handoff "$TARGET3" "devops-architect" "test-spec" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolved-in="specs/handoffs/step-3.2-test-spec-backend-engineer-fix-cycle-1.html" data-resolved-by="commit:abc123" data-re-verified-in="specs/handoffs/step-3.3-test-spec-devops-architect-cycle-1.html"><h2>Cleanly resolved</h2></aside>'
TOTAL=$((TOTAL+1))
out=$(python3 "$WORKFLOW_DIR/hooks/_validate_handoff.py" "$TARGET3" "test-spec" "devops-architect" 2>&1)
if [ -z "$out" ]; then
    echo "  PASS  validator allows aside with valid pointers + clean re-verify"
    PASS=$((PASS+1))
else
    echo "  FAIL  validator wrongly flagged clean resolution (got: ${out:0:200})"
    FAIL=$((FAIL+1))
fi

# Case 4: re-verify file still has an unresolved critical on same route => block
REVERIFY_DIRTY="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect-cycle-2.html"
write_handoff "$REVERIFY_DIRTY" "devops-architect" "test-spec" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="true"><h2>Same problem still present</h2></aside>'
TARGET4="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect-fakerev.html"
write_handoff "$TARGET4" "devops-architect" "test-spec" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolved-in="specs/handoffs/step-3.2-test-spec-backend-engineer-fix-cycle-1.html" data-re-verified-in="specs/handoffs/step-3.3-test-spec-devops-architect-cycle-2.html"><h2>Claims resolved but reviewer says no</h2></aside>'
TOTAL=$((TOTAL+1))
out=$(python3 "$WORKFLOW_DIR/hooks/_validate_handoff.py" "$TARGET4" "test-spec" "devops-architect" 2>&1)
if echo "$out" | grep -q "still contains an unresolved critical-blocking aside"; then
    echo "  PASS  validator catches re-verify file with persisting critical on same route"
    PASS=$((PASS+1))
else
    echo "  FAIL  validator did not catch dirty re-verify (got: ${out:0:200})"
    FAIL=$((FAIL+1))
fi

# Case 5: data-resolution-skip override allows the bypass
TARGET5="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect-override.html"
write_handoff "$TARGET5" "devops-architect" "test-spec" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolution-skip="upstream library fix lives in vendored dep — see commit 9c88227 for the patch we applied locally"><h2>Bypassed for documented reason</h2></aside>'
TOTAL=$((TOTAL+1))
out=$(python3 "$WORKFLOW_DIR/hooks/_validate_handoff.py" "$TARGET5" "test-spec" "devops-architect" 2>&1)
if [ -z "$out" ]; then
    echo "  PASS  data-resolution-skip override allows the bypass"
    PASS=$((PASS+1))
else
    echo "  FAIL  data-resolution-skip override was not respected (got: ${out:0:200})"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== guard-handoff-owner.sh (workflow-g7o / 2026-05-27 orchestrator-synthesis bypass) ==="

# guard-handoff-owner.sh exists and is executable
TOTAL=$((TOTAL+1))
if [ -x "$HOOK_DIR/guard-handoff-owner.sh" ]; then
    echo "  PASS  guard-handoff-owner.sh present and executable"
    PASS=$((PASS+1))
else
    echo "  FAIL  guard-handoff-owner.sh missing or not executable"
    FAIL=$((FAIL+1))
fi

# Registered in install.sh
TOTAL=$((TOTAL+1))
if grep -q 'guard-handoff-owner.sh' "$WORKFLOW_DIR/install.sh"; then
    echo "  PASS  guard-handoff-owner.sh registered in install.sh"
    PASS=$((PASS+1))
else
    echo "  FAIL  guard-handoff-owner.sh not registered in install.sh"
    FAIL=$((FAIL+1))
fi

# Behavior tests — isolate session log via env override
GHO_TMP="$TMP/gho-test"
mkdir -p "$GHO_TMP/specs/handoffs" "$GHO_TMP/state"
GHO_AGENTS_LOG="$GHO_TMP/state/session-agents.log"

# Run hook with HOME pointed at our temp dir so it reads our session log.
# IMPORTANT: HOME must be exported to the bash invocation that runs the hook,
# not just to mkpayload_edit upstream of the pipe. Use a subshell to scope it.
run_gho_hook() {
    local file="$1" content="$2"
    mkpayload_edit "$file" "$content" | (HOME="$GHO_TMP" bash "$HOOK_DIR/guard-handoff-owner.sh" 2>&1) || true
}
mkdir -p "$GHO_TMP/.claude/hooks/state"

# Case 1: writing handoff with NO dispatch logged => block
GHO_HANDOFF="$GHO_TMP/specs/handoffs/step-3.2-myslug-frontend-engineer.html"
got=$(run_gho_hook "$GHO_HANDOFF" "<html data-handoff-version='1'></html>")
assert "no dispatch logged for frontend-engineer -> block" "block" "$got"

# Case 2: dispatch logged for frontend-engineer => allow
echo "2026-05-27T00:00:00Z|frontend-engineer|test dispatch" > "$GHO_TMP/.claude/hooks/state/session-agents.log"
got=$(run_gho_hook "$GHO_HANDOFF" "<html data-handoff-version='1'></html>")
assert "dispatch logged for frontend-engineer -> allow" "allow" "$got"

# Case 3: dispatch logged for backend-engineer but not frontend => block frontend handoff
echo "2026-05-27T00:00:00Z|backend-engineer|test dispatch" > "$GHO_TMP/.claude/hooks/state/session-agents.log"
got=$(run_gho_hook "$GHO_HANDOFF" "<html data-handoff-version='1'></html>")
assert "wrong-role dispatch -> block" "block" "$got"

# Case 4: @handoff-author-skip override allows
got=$(run_gho_hook "$GHO_HANDOFF" "<html data-handoff-version='1'></html><!-- @handoff-author-skip(frontend-engineer: subagent inline-synthesis fallback per docs/role-agent-handoff-schema.md — no Agent tool available in this dispatch context) -->")
assert "@handoff-author-skip override -> allow" "allow" "$got"

# Case 5: non-handoff file path is ignored
NON_HOFF="$GHO_TMP/specs/some-spec.md"
got=$(run_gho_hook "$NON_HOFF" "@status(verified)")
assert "non-handoff file -> allow (hook ignores)" "allow" "$got"

# Case 6: handoff with cycle suffix correctly parses role (fix-cycle naming)
CYCLE_HOFF="$GHO_TMP/specs/handoffs/step-3.2-myslug-backend-engineer-fix-cycle-1.html"
# backend-engineer IS in the log from case 3
got=$(run_gho_hook "$CYCLE_HOFF" "<html data-handoff-version='1'></html>")
assert "fix-cycle-N suffix correctly parsed -> allow when dispatched" "allow" "$got"

echo ""
echo "=== require-ui-tests first-word blocklist (catches 2026-05-26 hook-enforcement dogfood finding) ==="
# Bug: when a spec's first hyphen-split word is "test", "spec", "unit", "e2e",
# or "integration", the first-word substitution matched every *.test.ts file
# in the project. The hook source should now have a `case "$first_word" in
# test|tests|spec|...) first_word="$slug" ;;` block.
TOTAL=$((TOTAL+1))
if grep -qE 'first_word="\$slug"' "$HOOK_DIR/require-ui-tests.sh" && \
   grep -qE 'test\|tests\|spec' "$HOOK_DIR/require-ui-tests.sh"; then
    echo "  PASS  require-ui-tests.sh first-word blocklist present"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-ui-tests.sh missing first-word blocklist — slugs starting with 'test-' etc. will match any *.test.ts"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== hook output-shape regressions (catches the 2026-05-26 dogfood finding) ==="
# Regression: every blocking hook must either exit 2 (with stderr message) OR
# emit the modern hookSpecificOutput JSON schema with permissionDecision=deny.
# The legacy stdout '{"error":"BLOCKED: ..."}' shape is ignored by current
# Claude Code and was the root cause of the silent-allow finding from the
# onboard dogfood.
BLOCKING_HOOKS=(
    "require-bead-description.sh"
    "require-design-ui.sh"
    "require-handoff-artifact.sh"
    "require-investigation-findings.sh"
    "require-layer-tag.sh"
    "require-release-handoff.sh"
    "require-ui-tests.sh"
    "require-verifier-agents.sh"
    "block-status-during-verification.sh"
    "block-unread-edits.sh"
    "claim-vs-call-audit.sh"
    "guard-agent-memory-secrets.sh"
    "guard-spec-bash-writes.sh"
)
for h in "${BLOCKING_HOOKS[@]}"; do
    TOTAL=$((TOTAL+1))
    path="$HOOK_DIR/$h"
    if [ ! -f "$path" ]; then
        echo "  FAIL  $h (file not found)"
        FAIL=$((FAIL+1))
        continue
    fi
    has_exit_2=$(grep -cE '^[[:space:]]*exit 2$' "$path")
    has_modern_json=$(grep -cE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"' "$path")
    has_legacy_error=$(grep -cE '"error"[[:space:]]*:[[:space:]]*"BLOCKED' "$path")
    if [ "$has_exit_2" -gt 0 ] || [ "$has_modern_json" -gt 0 ]; then
        if [ "$has_legacy_error" -gt 0 ]; then
            echo "  FAIL  $h still contains legacy {\"error\":\"BLOCKED:...\"} stdout JSON — harness will ignore"
            FAIL=$((FAIL+1))
        else
            echo "  PASS  $h uses exit 2 + stderr (or modern hookSpecificOutput)"
            PASS=$((PASS+1))
        fi
    else
        echo "  FAIL  $h has neither exit 2 nor modern hookSpecificOutput — won't actually block"
        FAIL=$((FAIL+1))
    fi
done

echo ""
echo "=========================================="
echo "Total: $TOTAL  Pass: $PASS  Fail: $FAIL"
echo "=========================================="
exit $FAIL
