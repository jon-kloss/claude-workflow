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

# All 11 memory templates exist in the repo
TOTAL=$((TOTAL+1))
template_count=$(ls "$WORKFLOW_DIR"/skills/onboard/resources/memory-template-*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$template_count" -eq 11 ]; then
    echo "  PASS  11 memory templates present in skills/onboard/resources/"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 11 memory templates, found $template_count"
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

# All 11 agent prompts have the memory block
TOTAL=$((TOTAL+1))
agents_with_memory=$(grep -lE '^## Memory: read first, update last' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if [ "$agents_with_memory" -eq 11 ]; then
    echo "  PASS  all 11 agent prompts have the Memory section"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 11 agents with Memory block, found $agents_with_memory"
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
if [ "$templates_with_precision" -eq 11 ]; then
    echo "  PASS  all 11 templates use seconds-precision timestamp placeholder"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 11 templates with seconds-precision placeholder, found $templates_with_precision (workflow-1y5 regression)"
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
FC_VERIFIED_SKIP="@layer(api) @status(verified) @fix-cycle-skip(3: reviewer findings withdrawn after re-investigation)"
got=$(mkpayload_edit "$FC_SPEC" "$FC_VERIFIED_SKIP" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "cycle 3 with @fix-cycle-skip(3: ...) -> allow" "allow" "$got"

# Case 7: @trivial spec bypasses fix-cycle check
FC_TRIVIAL_SPEC="$FC_TMP/specs/trivial-fix.md"
echo "@layer(api) @trivial" > "$FC_TRIVIAL_SPEC"
got=$(mkpayload_edit "$FC_TRIVIAL_SPEC" "@layer(api) @trivial @status(verified)" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "@trivial spec bypasses fix-cycle hook" "allow" "$got"

# workflow-myr: every agent has the terminal Exit checklist section
TOTAL=$((TOTAL+1))
agents_with_exit=$(grep -lE '^## Exit checklist \(run before returning\)' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if [ "$agents_with_exit" -eq 11 ]; then
    echo "  PASS  all 11 agents have terminal Exit checklist section"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 11 agents with Exit checklist, found $agents_with_exit (workflow-myr regression)"
    FAIL=$((FAIL+1))
fi

# workflow-myr: exit checklist names handoff-write as terminal step
TOTAL=$((TOTAL+1))
agents_with_terminal_handoff=$(grep -lE 'TERMINAL|handoff file is NOT|verbal confirmation is NOT the deliverable' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if [ "$agents_with_terminal_handoff" -ge 11 ]; then
    echo "  PASS  all agents emphasize handoff-as-deliverable in exit checklist"
    PASS=$((PASS+1))
else
    echo "  FAIL  only $agents_with_terminal_handoff/11 agents emphasize terminal handoff-write"
    FAIL=$((FAIL+1))
fi

# workflow-1bo: sleep-poll anti-pattern guidance present in agent prompts
TOTAL=$((TOTAL+1))
agents_with_sleep_warn=$(grep -lE 'do not poll background tasks with .sleep' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if [ "$agents_with_sleep_warn" -eq 11 ]; then
    echo "  PASS  all 11 agents carry sleep-poll anti-pattern warning"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 11 agents with sleep-poll warning, found $agents_with_sleep_warn (workflow-1bo regression)"
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
