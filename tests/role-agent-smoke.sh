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
        if [ "$got" = "{}" ]; then
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

result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh")
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
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh")
assert "api-spec with all 7 handoffs allows" allow "$result"

# Schema violation: remove data-from-role from one handoff
sed -i '' '/data-from-role/d' specs/handoffs/step-3.3-api-feature-security-architect.html
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh")
assert "missing data-from-role schema violation blocks" block "$result"
write_handoff specs/handoffs step-3.3 api-feature security-architect  # restore

# Slug mismatch
sed -i '' 's/data-spec-slug="api-feature"/data-spec-slug="wrong-slug"/' specs/handoffs/step-3.3-api-feature-security-architect.html
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh")
assert "slug mismatch blocks" block "$result"
write_handoff specs/handoffs step-3.3 api-feature security-architect  # restore

# @handoff-skip override
rm specs/handoffs/step-3.3-api-feature-security-architect.html
PAYLOAD_SKIP=$(mkpayload_edit "$TMP/specs/api-feature.md" '@status(verified)
@handoff-skip(security-architect: synthetic test no security surface)')
result=$(printf '%s\n' "$PAYLOAD_SKIP" | bash "$HOOK_DIR/require-handoff-artifact.sh")
assert "@handoff-skip allows when handoff missing" allow "$result"
write_handoff specs/handoffs step-3.3 api-feature security-architect

# @trivial bypass
cat > specs/trivial.md <<'EOF'
@status(approved)
@layer(infra)
@trivial
EOF
PAYLOAD_TRIV=$(mkpayload_edit "$TMP/specs/trivial.md" '@status(verified)')
result=$(printf '%s\n' "$PAYLOAD_TRIV" | bash "$HOOK_DIR/require-handoff-artifact.sh")
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
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh")
assert "ui-spec (no @touches-data) allows without data-architect" allow "$result"

# Now add @touches-data — should block until data-architect present
sed -i '' '/^@layer(ui)/a\
@touches-data
' specs/ui-feature.md
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh")
assert "ui-spec + @touches-data blocks without data-architect" block "$result"

write_handoff specs/handoffs step-3.3 ui-feature data-architect
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh")
assert "ui-spec + @touches-data + data-architect allows" allow "$result"

# Critical-blocking aside causes failure
cat >> specs/handoffs/step-3.3-ui-feature-security-architect.html <<'EOF'
<aside data-severity="critical" data-blocks-next-step="true"><p>do not proceed</p></aside>
EOF
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh")
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
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $NONEPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh")
    assert "non-epic bd close allows" allow "$result"

    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh")
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
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh")
    assert "epic bd close with PASS verdict allows" allow "$result"

    sed -i '' 's/READY-TO-CLOSE/BLOCKED/' "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html"
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh")
    assert "epic bd close with BLOCKED verdict blocks" block "$result"

    rm "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html"
    bd comments add "$EPIC_ID" "RELEASE-SKIP: smoke test override" > /dev/null 2>&1
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh")
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
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/guard-agent-memory-secrets.sh")
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
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/guard-agent-memory-secrets.sh")
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
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/guard-agent-memory-secrets.sh")
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
echo "=========================================="
echo "Total: $TOTAL  Pass: $PASS  Fail: $FAIL"
echo "=========================================="
exit $FAIL
