#!/usr/bin/env bash
# Smoke test for the role-agent hook system.
#
# SANDBOX GUARANTEE
#   Every run is fully self-contained under a throwaway $SANDBOX directory:
#     - $HOME is redirected to $SANDBOX/home for the entire suite, so every
#       hook invocation writes its state — including the override-audit
#       ledger at ~/.claude/hooks/state/override-audit.log — inside the
#       sandbox, never into the real ~/.claude.
#     - bd-backed checks run in a scratch project ($SANDBOX/proj) against a
#       throwaway database created by `bd init` there. The workflow repo's
#       own .beads is never written to. If bd (or its init) is unavailable,
#       those checks are SKIPped with a reason instead of touching anything.
#     - Fixture mini-projects live under $SANDBOX/tmp.
#     - The sandbox (including its scratch dolt server) is torn down on exit.
#   Known caveat: bd v0.60 `bd init` performs machine-wide orphan
#   housekeeping and may stop OTHER projects' idle dolt sql-servers (bd
#   restarts them transparently on next use; no issue data is affected).
#   This is bd behavior the suite cannot disable, not a sandbox leak.
#
# HOOKS UNDER TEST are always the REPO's own hooks (HOOK_DIR below), never
# the ~/.claude symlinks — a clean checkout needs no prior install.sh run.
#
# FLAGS
#   --installed   Additionally assert the installed form under the real
#                 $HOME/.claude (install.sh symlinked *.py helpers, /onboard
#                 skill, secret detector). Default OFF so a clean checkout /
#                 CI passes; when off those 3 checks are counted as SKIP.
#
# CHECK COUNT is dynamic: the summary prints Total/Pass/Fail/Skip and
# Total == Pass + Fail + Skip on every run.
#
# COVERAGE GAPS (honest inventory, 2026-07-05):
#   - Shape-checks only (source greps, no behavior test):
#       guard-spec-bash-writes.sh, require-verifier-agents.sh
#   - Partial: claim-vs-call-audit.sh (only the @gate-skip validator paths;
#     the core claim-vs-call tracking is not behavior-tested)
#   - Zero coverage: beads-auto-resume.sh, molecule-autoclose-warn.sh,
#     remind-integration-tests.sh, track-reads.sh (its state format is
#     exercised only via hand-written fixtures), track-skills.sh
#   - Not testable here: real role agents producing handoffs (needs Agent
#     dispatch), SKILL.md orchestration (needs a fresh session), /impeccable
#     Skill invocation tracking (needs the Skill tool).
#
# Usage:  bash tests/role-agent-smoke.sh [--installed]
# Exit:   0 if no failures, 1 otherwise (skips never fail the run).

set -uo pipefail

WORKFLOW_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# The hooks under test — always the repo's own hooks/, never ~/.claude.
HOOK_DIR="$WORKFLOW_DIR/hooks"

RUN_INSTALLED=0
for arg in "$@"; do
    case "$arg" in
        --installed) RUN_INSTALLED=1 ;;
        *) echo "usage: bash tests/role-agent-smoke.sh [--installed]" >&2; exit 64 ;;
    esac
done

# ---- sandbox ---------------------------------------------------------------
REAL_HOME="$HOME"
SANDBOX="$(mktemp -d -t role-smoke.XXXXXX)"
HOME="$SANDBOX/home"
export HOME
mkdir -p "$HOME"
TMP="$SANDBOX/tmp"     # fixture mini-projects
PROJ="$SANDBOX/proj"   # scratch project for bd-backed checks
mkdir -p "$TMP" "$PROJ/specs/handoffs"

cleanup() {
    # Stop the scratch project's dolt server (if bd started one), then
    # remove the sandbox. Never touches anything outside $SANDBOX.
    if [ -f "$PROJ/.beads/dolt-server.pid" ]; then
        kill "$(cat "$PROJ/.beads/dolt-server.pid" 2>/dev/null)" 2>/dev/null || true
    fi
    rm -rf "$SANDBOX"
}
trap cleanup EXIT

PASS=0
FAIL=0
SKIP=0
TOTAL=0

# skip <name> <reason> — counted separately; skips never fail the run.
skip() {
    TOTAL=$((TOTAL+1)); SKIP=$((SKIP+1))
    echo "  SKIP  $1 ($2)"
}

# sed -i differs between BSD and GNU sed — always edit through this instead.
sed_inplace() {  # <sed-script> <file>
    sed "$1" "$2" > "$2.sedtmp" && mv "$2.sedtmp" "$2"
}

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

# ---- session/cwd-aware payload builders + state-key helper (T3.2) ----------
# Hook state now lives at ~/.claude/hooks/state/<12-hex sha1(cwd)>/<session_id>/
skey() {
    python3 -c "import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode()).hexdigest()[:12])" "$1"
}

mkpayload_edit_s() {  # file content session_id cwd [event]
    FILE="$1" CONTENT="$2" SID="$3" CW="$4" EV="${5:-PreToolUse}" python3 -c '
import json, os
print(json.dumps({"hook_event_name":os.environ["EV"],"session_id":os.environ["SID"],"cwd":os.environ["CW"],"tool_name":"Edit","tool_input":{"file_path":os.environ["FILE"],"new_string":os.environ["CONTENT"]}}))'
}

mkpayload_bash_s() {  # cmd session_id cwd
    CMD="$1" SID="$2" CW="$3" python3 -c '
import json, os
print(json.dumps({"hook_event_name":"PreToolUse","session_id":os.environ["SID"],"cwd":os.environ["CW"],"tool_name":"Bash","tool_input":{"command":os.environ["CMD"]}}))'
}

mkpayload_agent_s() {  # subagent_type prompt session_id cwd [event]
    SUB="$1" P="$2" SID="$3" CW="$4" EV="${5:-PreToolUse}" python3 -c '
import json, os
print(json.dumps({"hook_event_name":os.environ["EV"],"session_id":os.environ["SID"],"cwd":os.environ["CW"],"tool_name":"Agent","tool_input":{"subagent_type":os.environ["SUB"],"prompt":os.environ["P"]}}))'
}

# write_handoff <outpath> <role> <slug> [step] [findings_extra]
# The single fixture writer for schema-valid handoffs (the suite used to
# carry a second, shadowing definition — now unified). Reviewer/coordinator
# roles get the required <meta data-verdict> (registry §4, enforced by
# _validate_handoff.py since T3.4). findings_extra is injected verbatim into
# the findings section (used by the aside/resolution-pointer tests).
write_handoff() {
    local outpath="$1" role="$2" slug="$3" step="${4:-3.3}" extra="${5:-}"
    local verdict_meta=""
    case "$role" in
        security-architect|devops-architect|data-architect|qa-engineer|spec-sre-auditor)
            verdict_meta='<meta data-verdict="PASS">' ;;
        release-coordinator)
            verdict_meta='<meta data-verdict="READY-TO-CLOSE">' ;;
    esac
    [ -n "$extra" ] || extra='<p>x</p>'
    cat > "$outpath" <<EOF
<!DOCTYPE html><html lang="en" data-handoff-version="1"><head>
<meta charset="utf-8">
<meta data-from-role="${role}">
<meta data-spec-slug="${slug}">
<meta data-step="${step}">
<meta data-produced-at="2026-05-25T18:00:00Z">
<meta data-input-references="">
${verdict_meta}
<title>${role} handoff</title></head><body>
<section data-role="summary"><p>x</p></section>
<section data-role="findings">${extra}</section>
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
    write_handoff "specs/handoffs/${step}-api-feature-${h}.html" "$h" api-feature "$step"
done
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "api-spec with all 7 handoffs allows" allow "$result"

# Schema violation: remove data-from-role from one handoff
sed_inplace '/data-from-role/d' specs/handoffs/step-3.3-api-feature-security-architect.html
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "missing data-from-role schema violation blocks" block "$result"
write_handoff specs/handoffs/step-3.3-api-feature-security-architect.html security-architect api-feature step-3.3  # restore

# Slug mismatch
sed_inplace 's/data-spec-slug="api-feature"/data-spec-slug="wrong-slug"/' specs/handoffs/step-3.3-api-feature-security-architect.html
result=$(printf '%s\n' "$PAYLOAD" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "slug mismatch blocks" block "$result"
write_handoff specs/handoffs/step-3.3-api-feature-security-architect.html security-architect api-feature step-3.3  # restore

# @handoff-skip override
rm specs/handoffs/step-3.3-api-feature-security-architect.html
PAYLOAD_SKIP=$(mkpayload_edit "$TMP/specs/api-feature.md" '@status(verified)
@handoff-skip(security-architect: synthetic test no security surface — see tests/role-agent-smoke.sh fixture)')
result=$(printf '%s\n' "$PAYLOAD_SKIP" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "@handoff-skip allows when handoff missing" allow "$result"
write_handoff specs/handoffs/step-3.3-api-feature-security-architect.html security-architect api-feature step-3.3

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
    write_handoff "specs/handoffs/${step}-ui-feature-${h}.html" "$h" ui-feature "$step"
done
PAYLOAD_UI=$(mkpayload_edit "$TMP/specs/ui-feature.md" '@status(verified)')
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "ui-spec (no @touches-data) allows without data-architect" allow "$result"

# Now add @touches-data — should block until data-architect present
# (regenerate the spec rather than sed-append: BSD/GNU `a\` syntax differs)
cat > specs/ui-feature.md <<'EOF'
@status(approved)
@layer(ui)
@touches-data

## Investigation Findings
- src/a.tsx:1
- src/b.tsx:2
- decision
EOF
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "ui-spec + @touches-data blocks without data-architect" block "$result"

write_handoff specs/handoffs/step-3.3-ui-feature-data-architect.html data-architect ui-feature step-3.3
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "ui-spec + @touches-data + data-architect allows" allow "$result"

# Critical-blocking aside causes failure
cat >> specs/handoffs/step-3.3-ui-feature-security-architect.html <<'EOF'
<aside data-severity="critical" data-blocks-next-step="true"><p>do not proceed</p></aside>
EOF
result=$(printf '%s\n' "$PAYLOAD_UI" | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1)
assert "critical-blocking aside blocks" block "$result"

echo ""
echo "=== require-release-handoff.sh (sandboxed bd db in \$SANDBOX/proj) ==="

# All bd operations target a throwaway database created by `bd init` inside
# the scratch project — NEVER the workflow repo's own .beads. cwd moves to
# the scratch project so the hook's `bd show` / specs/ scans resolve there.
# (This also makes the @release-skip in-spec tests deterministic: the hook
# scans specs/ under cwd, and the scratch project's specs/ is empty — a real
# spec carrying @release-skip can no longer unlock these fixtures.)
BD_PREFIX="smoke"
BD_OK=0
if command -v bd >/dev/null 2>&1; then
    ( cd "$PROJ" \
        && { command -v git >/dev/null 2>&1 && git init -q . >/dev/null 2>&1; true; } \
        && bd init -q --prefix "$BD_PREFIX" >/dev/null 2>&1 ) && BD_OK=1
fi

EPIC_ID=""
NONEPIC_ID=""
if [ "$BD_OK" -eq 1 ]; then
    cd "$PROJ" || exit 1
    # Regression: build-test (2026-05-25) found that bd with --type=epic
    # auto-displays [EPIC] uppercase in bd show output, but the hook's grep
    # was case-sensitive '[epic]' → silent under-block. Use --type=epic, NOT
    # --type=feature with [epic] in the title (the latter doesn't reproduce
    # the bug because bd echoes the title verbatim).
    EPIC_ID=$(bd create --title="SMOKE TEST release hook (uppercase prefix)" --description="smoke test, ignore" --type=epic --priority=4 2>&1 | grep -oE "${BD_PREFIX}-[a-z0-9]+" | head -1)
    NONEPIC_ID=$(bd create --title="smoke non-epic" --description="smoke test, ignore" --type=task --priority=4 2>&1 | grep -oE "${BD_PREFIX}-[a-z0-9]+" | head -1)
fi

if [ -z "$EPIC_ID" ] || [ -z "$NONEPIC_ID" ]; then
    for t in \
        "non-epic bd close allows" \
        "epic bd close without handoff blocks" \
        "multi-id close with epic in 2nd position blocks (H9)" \
        "cd prefix + epic close still gated (H9)" \
        "echo-mention of bd close epic allows" \
        "meta data-verdict=BLOCKED wins over READY-TO-CLOSE prose (H10)" \
        "meta data-verdict=READY-TO-CLOSE allows" \
        "legacy handoff (no meta) prose verdict allows" \
        "epic bd close with BLOCKED verdict blocks" \
        "garbage RELEASE-SKIP reason still blocks (validator)" \
        "quality RELEASE-SKIP reason overrides BLOCKED verdict (H4)" \
        "quality RELEASE-SKIP also covers missing-handoff branch" \
        "garbage @release-skip in-spec reason blocks" \
        "quality @release-skip in-spec reason allows" \
        "non-last child close does not trigger epic gate (fx8r + st3)" \
        "last-child close is gated by parent epic release gate (fx8r)" \
        "last-child close allowed with parent RELEASE-SKIP override (fx8r)"
    do
        skip "$t" "bd init unavailable in sandbox — the real db is never touched"
    done
else
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $NONEPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "non-epic bd close allows" allow "$result"

    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "epic bd close without handoff blocks" block "$result"

    # H9: multi-id close gates EVERY id — epic in second position still blocks
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $NONEPIC_ID $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "multi-id close with epic in 2nd position blocks (H9)" block "$result"

    # H9: id extraction takes argument positions after `close` — a path-shaped
    # token before bd must not shadow the epic id
    result=$(printf '%s\n' "$(mkpayload_bash "cd my-project && bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "cd prefix + epic close still gated (H9)" block "$result"

    # H15-style: a MENTION of bd close inside a string must not gate
    result=$(printf '%s\n' "$(mkpayload_bash "echo \"next step: bd close $EPIC_ID\"")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "echo-mention of bd close epic allows" allow "$result"

    # Add a release handoff — meta data-verdict BLOCKED must win over body
    # text READY-TO-CLOSE (H10: verdict from meta, not first-token prose)
    mkdir -p specs/handoffs
    cat > "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html" <<EOF
<!DOCTYPE html><html lang="en" data-handoff-version="1"><head>
<meta data-from-role="release-coordinator"><meta data-spec-slug="${EPIC_ID}">
<meta data-step="4.2"><meta data-produced-at="x"><meta data-input-references="">
<meta data-verdict="BLOCKED">
<title>x</title></head><body><section data-role="summary"></section>
<section data-role="findings"><p>Earlier draft said Verdict: READY-TO-CLOSE but the meta is authoritative.</p></section>
<section data-role="acceptance-criteria"></section>
<section data-role="open-questions"></section>
</body></html>
EOF
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "meta data-verdict=BLOCKED wins over READY-TO-CLOSE prose (H10)" block "$result"

    sed_inplace 's/data-verdict="BLOCKED"/data-verdict="READY-TO-CLOSE"/' "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html"
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "meta data-verdict=READY-TO-CLOSE allows" allow "$result"

    # Legacy fallback: handoff with NO meta at all falls back to prose search
    cat > "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html" <<EOF
<!DOCTYPE html><html lang="en" data-handoff-version="1"><head>
<meta data-from-role="release-coordinator"><meta data-spec-slug="${EPIC_ID}">
<meta data-step="4.2"><meta data-produced-at="x"><meta data-input-references="">
<title>x</title></head><body><section data-role="summary"></section>
<section data-role="findings"></section>
<section data-role="acceptance-criteria"></section>
<section data-role="open-questions"></section>
<p>Verdict: READY-TO-CLOSE</p></body></html>
EOF
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "legacy handoff (no meta) prose verdict allows" allow "$result"

    sed_inplace 's/READY-TO-CLOSE/BLOCKED/' "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html"
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "epic bd close with BLOCKED verdict blocks" block "$result"

    # H4: the override must work in the BLOCKED branch too — but only with a
    # quality-validated reason. Garbage reason first: still blocked.
    bd comments add "$EPIC_ID" "RELEASE-SKIP: smoke test override" > /dev/null 2>&1
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "garbage RELEASE-SKIP reason still blocks (validator)" block "$result"

    bd comments add "$EPIC_ID" "RELEASE-SKIP: verified manually against tests/role-agent-smoke.sh fixtures; epic tracked in workflow-8o6" > /dev/null 2>&1
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "quality RELEASE-SKIP reason overrides BLOCKED verdict (H4)" allow "$result"

    rm "specs/handoffs/step-4.2-${EPIC_ID}-release-coordinator.html"
    result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
    assert "quality RELEASE-SKIP also covers missing-handoff branch" allow "$result"

    # @release-skip(<reason>) in-spec form (registry §7) — second epic with no
    # comments. Garbage reason blocks; quality reason allows.
    EPIC2_ID=$(bd create --title="SMOKE TEST release hook (in-spec tag)" --description="smoke test, ignore" --type=epic --priority=4 2>&1 | grep -oE "${BD_PREFIX}-[a-z0-9]+" | head -1)
    if [ -n "$EPIC2_ID" ]; then
        RS_FIXTURE="specs/smoke-release-skip-fixture.md"
        echo "# smoke fixture — deleted by tests/role-agent-smoke.sh" > "$RS_FIXTURE"
        echo "@release-skip(intentional)" >> "$RS_FIXTURE"
        result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC2_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
        assert "garbage @release-skip in-spec reason blocks" block "$result"

        echo "# smoke fixture — deleted by tests/role-agent-smoke.sh" > "$RS_FIXTURE"
        echo "@release-skip(release gate run manually per tests/role-agent-smoke.sh; epic covered by workflow-8o6 phase plan)" >> "$RS_FIXTURE"
        result=$(printf '%s\n' "$(mkpayload_bash "bd close $EPIC2_ID")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
        assert "quality @release-skip in-spec reason allows" allow "$result"
        rm -f "$RS_FIXTURE"
        bd close "$EPIC2_ID" --reason="smoke test cleanup" > /dev/null 2>&1
    else
        skip "garbage @release-skip in-spec reason blocks" "could not create second synthetic epic in sandbox db"
        skip "quality @release-skip in-spec reason allows" "could not create second synthetic epic in sandbox db"
    fi

    # workflow-fx8r: closing the LAST open child of an epic triggers beads'
    # molecule auto-close (the epic is promoted to closed WITHOUT a
    # `bd close <epic>` command), which must still satisfy the epic release
    # gate. Also subsumes workflow-st3: FX_A carries the epic in its PARENT
    # section, so a whole-output [epic] grep would wrongly gate it.
    FX_EPIC=$(bd create --title="SMOKE TEST release hook (molecule)" --description="smoke test, ignore" --type=epic --priority=4 2>&1 | grep -oE "${BD_PREFIX}-[a-z0-9]+" | head -1)
    FX_A=$(bd create --title="smoke child A" --description="smoke test, ignore" --type=task --priority=4 2>&1 | grep -oE "${BD_PREFIX}-[a-z0-9]+" | head -1)
    FX_B=$(bd create --title="smoke child B" --description="smoke test, ignore" --type=task --priority=4 2>&1 | grep -oE "${BD_PREFIX}-[a-z0-9]+" | head -1)
    if [ -n "$FX_EPIC" ] && [ -n "$FX_A" ] && [ -n "$FX_B" ]; then
        bd dep add "$FX_A" "$FX_EPIC" --type parent-child >/dev/null 2>&1
        bd dep add "$FX_B" "$FX_EPIC" --type parent-child >/dev/null 2>&1
        # Both children open: closing A is not the last -> epic won't promote -> allow.
        result=$(printf '%s\n' "$(mkpayload_bash "bd close $FX_A")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
        assert "non-last child close does not trigger epic gate (fx8r + st3)" allow "$result"
        bd close "$FX_A" --reason="smoke test" >/dev/null 2>&1
        # Only B remains open: closing it completes the epic -> auto-promotion ->
        # gate fires (no handoff / no override) -> block.
        result=$(printf '%s\n' "$(mkpayload_bash "bd close $FX_B")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
        assert "last-child close is gated by parent epic release gate (fx8r)" block "$result"
        # Quality RELEASE-SKIP on the parent epic -> last-child close now allowed.
        bd comments add "$FX_EPIC" "RELEASE-SKIP: smoke molecule-autoclose path; parent epic gate verified in tests/role-agent-smoke.sh, see hooks/require-release-handoff.sh gate_epic" >/dev/null 2>&1
        result=$(printf '%s\n' "$(mkpayload_bash "bd close $FX_B")" | bash "$HOOK_DIR/require-release-handoff.sh" 2>&1)
        assert "last-child close allowed with parent RELEASE-SKIP override (fx8r)" allow "$result"
        bd close "$FX_B" --reason="smoke test" >/dev/null 2>&1
    else
        skip "non-last child close does not trigger epic gate (fx8r + st3)" "could not create molecule epic in sandbox db"
        skip "last-child close is gated by parent epic release gate (fx8r)" "could not create molecule epic in sandbox db"
        skip "last-child close allowed with parent RELEASE-SKIP override (fx8r)" "could not create molecule epic in sandbox db"
    fi

    # Cleanup (scratch db only — the whole thing is deleted on exit anyway)
    bd close "$EPIC_ID" --reason="smoke test cleanup" > /dev/null 2>&1
    bd close "$NONEPIC_ID" --reason="smoke test cleanup" > /dev/null 2>&1
fi
cd "$WORKFLOW_DIR" || exit 1

echo ""
echo "=== installed-form regressions (--installed: assert against the real ~/.claude) ==="
# These tests catch the 2026-05-25 build-test regression: install.sh was only globbing
# *.sh and skipping *.py helpers like _validate_handoff.py. The earlier smoke tests
# all ran against the workflow repo's hooks/ directly, so they couldn't catch the
# install-symlink path. Gated behind --installed (and checked under $REAL_HOME,
# since $HOME points into the sandbox) so a clean checkout / CI passes by default.

if [ "$RUN_INSTALLED" -eq 1 ]; then
    TOTAL=$((TOTAL+1))
    if [ -f "$REAL_HOME/.claude/hooks/_validate_handoff.py" ]; then
        echo "  PASS  _validate_handoff.py present in ~/.claude/hooks/ (install.sh symlinked *.py)"
        PASS=$((PASS+1))
    else
        echo "  FAIL  _validate_handoff.py MISSING from ~/.claude/hooks/ — install.sh did not symlink *.py helpers"
        echo "        (run: cd $WORKFLOW_DIR && bash install.sh)"
        FAIL=$((FAIL+1))
    fi
else
    skip "_validate_handoff.py present in ~/.claude/hooks/" "--installed not set; run with --installed after bash install.sh"
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

# /onboard skill installed (installed-form check — gated behind --installed)
if [ "$RUN_INSTALLED" -eq 1 ]; then
    TOTAL=$((TOTAL+1))
    if [ -f "$REAL_HOME/.claude/skills/onboard/SKILL.md" ]; then
        echo "  PASS  /onboard skill installed at ~/.claude/skills/onboard/SKILL.md"
        PASS=$((PASS+1))
    else
        echo "  FAIL  /onboard SKILL.md missing from install"
        FAIL=$((FAIL+1))
    fi
else
    skip "/onboard skill installed at ~/.claude/skills/onboard/SKILL.md" "--installed not set"
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

# _detect_memory_secrets.py symlinked (installed-form check — gated behind --installed)
if [ "$RUN_INSTALLED" -eq 1 ]; then
    TOTAL=$((TOTAL+1))
    if [ -f "$REAL_HOME/.claude/hooks/_detect_memory_secrets.py" ]; then
        echo "  PASS  _detect_memory_secrets.py present in ~/.claude/hooks/"
        PASS=$((PASS+1))
    else
        echo "  FAIL  _detect_memory_secrets.py MISSING — secret-guard hook won't function"
        FAIL=$((FAIL+1))
    fi
else
    skip "_detect_memory_secrets.py present in ~/.claude/hooks/" "--installed not set"
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
# (reviewer side uses -fix-cycle-N too — the retired -cycle-N spelling is
# no longer recognized, registry §1 / evaluation M7)
touch "$FC_TMP/specs/handoffs/step-3.2-example-feature-backend-engineer-fix-cycle-1.html"
touch "$FC_TMP/specs/handoffs/step-3.3-example-feature-qa-engineer-fix-cycle-1.html"
got=$(mkpayload_edit "$FC_SPEC" "$FC_VERIFIED_CONTENT" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "cycle 1 symmetric (impl + reviewer) -> allow" "allow" "$got"

# Case 3: cycle 2 has reviewer but NOT implementer (the actual bug) => block
touch "$FC_TMP/specs/handoffs/step-3.3-example-feature-qa-engineer-fix-cycle-2.html"
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

# Case 8 (H11): slug boundary — spec 'example' must NOT inherit
# example-feature's cycle files (role segment is a known-role alternation)
FC_SHORT_SPEC="$FC_TMP/specs/example.md"
echo "@layer(api)" > "$FC_SHORT_SPEC"
got=$(mkpayload_edit "$FC_SHORT_SPEC" "@layer(api) @status(verified)" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "slug 'example' does not match example-feature cycle files (H11)" "allow" "$got"

# Case 9 (M7): retired -cycle-N reviewer spelling is NOT accepted — a
# reviewer file in the old spelling leaves the cycle asymmetric.
# (Remove case 5's asymmetric cycle-3 implementer file first so the block
# can only come from cycle 4.)
rm -f "$FC_TMP/specs/handoffs/step-3.2-example-feature-backend-engineer-fix-cycle-3.html"
touch "$FC_TMP/specs/handoffs/step-3.2-example-feature-backend-engineer-fix-cycle-4.html"
touch "$FC_TMP/specs/handoffs/step-3.3-example-feature-qa-engineer-cycle-4.html"
got=$(mkpayload_edit "$FC_SPEC" "$FC_VERIFIED_CONTENT" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "retired -cycle-N reviewer spelling does not satisfy symmetry (M7)" "block" "$got"
rm -f "$FC_TMP/specs/handoffs/step-3.2-example-feature-backend-engineer-fix-cycle-4.html" \
      "$FC_TMP/specs/handoffs/step-3.3-example-feature-qa-engineer-cycle-4.html"

# Case 10 (registry §1): design-side fix cycles — step-2.85 implementer side
FC_DSGN_SPEC="$FC_TMP/specs/dsgn-widget.md"
echo "@layer(ui)" > "$FC_DSGN_SPEC"
touch "$FC_TMP/specs/handoffs/step-2.85-dsgn-widget-uiux-designer-fix-cycle-1.html"
got=$(mkpayload_edit "$FC_DSGN_SPEC" "@layer(ui) @status(verified)" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "design-side fix without reviewer re-verify -> block" "block" "$got"
touch "$FC_TMP/specs/handoffs/step-3.3-dsgn-widget-qa-engineer-fix-cycle-1.html"
got=$(mkpayload_edit "$FC_DSGN_SPEC" "@layer(ui) @status(verified)" | bash "$HOOK_DIR/require-fix-cycle-handoff.sh" 2>&1 || true)
assert "design-side fix (2.85) + reviewer re-verify -> allow" "allow" "$got"

# workflow-myr (updated for T2.3 boilerplate extraction): every agent carries the
# shared Exit protocol section pointing at docs/agent-protocol.md
TOTAL=$((TOTAL+1))
agents_with_exit=$(grep -lE '^## Exit protocol' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if [ "$agents_with_exit" -eq 16 ]; then
    echo "  PASS  all 16 agents have the Exit protocol section"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 16 agents with Exit protocol section, found $agents_with_exit (workflow-myr regression)"
    FAIL=$((FAIL+1))
fi

# workflow-myr: the shared protocol doc exists and names handoff-write as the deliverable
TOTAL=$((TOTAL+1))
if [ -f "$WORKFLOW_DIR/docs/agent-protocol.md" ] \
   && grep -qE 'handoff.*deliverable|deliverable.*handoff' "$WORKFLOW_DIR/docs/agent-protocol.md" \
   && grep -qE 'fix-cycle-(<N>|N)' "$WORKFLOW_DIR/docs/agent-protocol.md"; then
    echo "  PASS  agent-protocol.md exists with handoff-as-deliverable + fix-cycle naming"
    PASS=$((PASS+1))
else
    echo "  FAIL  docs/agent-protocol.md missing or lacks handoff-as-deliverable / fix-cycle naming (workflow-myr regression)"
    FAIL=$((FAIL+1))
fi

# workflow-1bo: sleep-poll anti-pattern guidance lives in the shared protocol doc,
# and every agent points at that doc from its Exit protocol section
TOTAL=$((TOTAL+1))
agents_with_pointer=$(grep -lF 'docs/agent-protocol.md' "$WORKFLOW_DIR"/agents/*.md | wc -l | tr -d ' ')
if grep -qiE 'sleep' "$WORKFLOW_DIR/docs/agent-protocol.md" 2>/dev/null && [ "$agents_with_pointer" -eq 16 ]; then
    echo "  PASS  sleep-poll rule in agent-protocol.md; all 16 agents reference the doc"
    PASS=$((PASS+1))
else
    echo "  FAIL  sleep-poll rule missing from agent-protocol.md or only $agents_with_pointer/16 agents reference it (workflow-1bo regression)"
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

# workflow-st3: require-release-handoff.sh restricts the [epic] detection to the
# title line (head -n 1), so a non-epic whose PARENT section names an epic is not
# mis-gated. Static backstop; the behavior is proven by the fx8r checks above
# (FX_A has an epic parent and must be allowed).
TOTAL=$((TOTAL+1))
if grep -q 'head -n 1 | grep -qiE' "$HOOK_DIR/require-release-handoff.sh"; then
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

# Audit log gets a line on PASS. $HOME is the sandbox here, so this exercises
# the ledger append WITHOUT touching the real ~/.claude/hooks/state ledger.
AUDIT_LOG_PATH="$HOME/.claude/hooks/state/override-audit.log"
TOTAL=$((TOTAL+1))
# Unique marker (macOS date lacks %N, so mix in pid + RANDOM instead)
unique_marker="audit-test-$(date +%s).$$.$RANDOM"
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
touch "$OR_TMP/specs/handoffs/step-3.3-cycle-test-qa-engineer-fix-cycle-1.html"
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
<meta data-verdict="PASS">
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
<meta data-verdict="PASS">
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

# Phase 2 rollout: @handoff-skip + @gate-skip now validated too
# (workflow-ccw extension — driven by 2026-05-27 commit-details-panel audit)

# require-handoff-artifact.sh: @handoff-skip with trivial reason should block
HS_TMP="$TMP/handoff-skip-rollout"
mkdir -p "$HS_TMP/specs/handoffs"
HS_SPEC="$HS_TMP/specs/test-spec.md"
bad_hs="@layer(api) @status(verified) @handoff-skip(security-architect: n/a)"
got=$(mkpayload_edit "$HS_SPEC" "$bad_hs" | (cd "$HS_TMP" && bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1) || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q "@handoff-skip(security-architect: ...) override reason failed quality validation"; then
    echo "  PASS  require-handoff-artifact blocks trivial @handoff-skip reason"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-handoff-artifact accepted trivial @handoff-skip reason (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# require-handoff-artifact.sh: @handoff-skip with quality reason passes validator
# (will still block on other missing handoffs but NOT on the override reason itself)
good_hs="@layer(api) @status(verified) @handoff-skip(security-architect: spec is a UI text-only copy change verified by user authorization — see workflow-ccw and PRODUCT.md)"
got=$(mkpayload_edit "$HS_SPEC" "$good_hs" | (cd "$HS_TMP" && bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1) || true)
TOTAL=$((TOTAL+1))
if ! echo "$got" | grep -q "override reason failed"; then
    echo "  PASS  require-handoff-artifact accepts quality @handoff-skip reason (validator pass)"
    PASS=$((PASS+1))
else
    echo "  FAIL  require-handoff-artifact rejected a quality @handoff-skip reason (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# claim-vs-call-audit.sh: @gate-skip with trivial reason should block
GS_TMP="$TMP/gate-skip-rollout"
mkdir -p "$GS_TMP/specs"
mkdir -p "$GS_TMP/state"
GS_SPEC="$GS_TMP/specs/ui-test.md"
# Bad reason: "spec body" (self-referential, no concrete artifact)
bad_gs="@layer(ui) @status(verified) @gate-skip(critique: spec body)"
got=$(mkpayload_edit "$GS_SPEC" "$bad_gs" | bash "$HOOK_DIR/claim-vs-call-audit.sh" 2>&1 || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q "@gate-skip(critique: ...) override reason failed quality validation"; then
    echo "  PASS  claim-vs-call-audit blocks self-referential @gate-skip reason"
    PASS=$((PASS+1))
else
    echo "  FAIL  claim-vs-call-audit accepted self-referential @gate-skip reason (got: ${got:0:200})"
    FAIL=$((FAIL+1))
fi

# claim-vs-call-audit.sh: @gate-skip with quality reason passes validator
good_gs="@layer(ui) @status(verified) @gate-skip(critique: design critique was captured in specs/mockups/ui-test.html during the original design phase — see commit 9c88227)"
got=$(mkpayload_edit "$GS_SPEC" "$good_gs" | bash "$HOOK_DIR/claim-vs-call-audit.sh" 2>&1 || true)
TOTAL=$((TOTAL+1))
if ! echo "$got" | grep -q "override reason failed"; then
    echo "  PASS  claim-vs-call-audit accepts quality @gate-skip reason (validator pass)"
    PASS=$((PASS+1))
else
    echo "  FAIL  claim-vs-call-audit rejected a quality @gate-skip reason (got: ${got:0:200})"
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

# Behavior tests — synthetic project with memory file.
# Payloads carry no session_id/cwd, so state_dir falls back to
# <sha1($PWD)>/no-session under the overridden HOME (T3.2 layout).
MEM_TMP="$TMP/memory-warn-test"
mkdir -p "$MEM_TMP/.claude/agent-memory"
MEM_FILE="$MEM_TMP/.claude/agent-memory/backend-engineer.md"
MEM_STATE="$MEM_TMP/.claude/hooks/state/$(skey "$MEM_TMP")/no-session"
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

# Case 1: baseline records mtime (under the session-keyed state dir)
run_baseline "backend-engineer" "test prompt" > /dev/null
TOTAL=$((TOTAL+1))
if [ -f "$MEM_STATE/agent-memory-baseline-backend-engineer.txt" ]; then
    echo "  PASS  baseline hook records pre-dispatch mtime (keyed state dir)"
    PASS=$((PASS+1))
else
    echo "  FAIL  baseline hook did not record mtime at $MEM_STATE"
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
rm -f "$MEM_STATE/agent-memory-baseline-backend-engineer.txt"
run_baseline "backend-engineer" "test" > /dev/null
TOTAL=$((TOTAL+1))
if [ ! -f "$MEM_STATE/agent-memory-baseline-backend-engineer.txt" ]; then
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

# (Uses the single top-level write_handoff fixture writer — the section
# used to redefine a shadowing variant here; the definitions are unified.)

# Case 1: aside flipped to false with NO pointers => validator emits error
TARGET="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect.html"
write_handoff "$TARGET" "devops-architect" "test-spec" "3.3" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false"><h2>Resolved without proof</h2></aside>'
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
write_handoff "$TARGET2" "devops-architect" "test-spec" "3.3" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolved-in="specs/handoffs/does-not-exist.html" data-re-verified-in="specs/handoffs/also-missing.html"><h2>Orphan pointers</h2></aside>'
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
write_handoff "$FIX_HOFF" "backend-engineer" "test-spec" "3.2" '<p>Fix applied at file:line</p>'
# Build re-verify handoff with NO unresolved critical aside
REVERIFY_HOFF="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect-cycle-1.html"
write_handoff "$REVERIFY_HOFF" "devops-architect" "test-spec" "3.3" '<p>Re-verified clean</p>'
# Original handoff points to both
TARGET3="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect.html"
write_handoff "$TARGET3" "devops-architect" "test-spec" "3.3" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolved-in="specs/handoffs/step-3.2-test-spec-backend-engineer-fix-cycle-1.html" data-resolved-by="commit:abc123" data-re-verified-in="specs/handoffs/step-3.3-test-spec-devops-architect-cycle-1.html"><h2>Cleanly resolved</h2></aside>'
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
write_handoff "$REVERIFY_DIRTY" "devops-architect" "test-spec" "3.3" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="true"><h2>Same problem still present</h2></aside>'
TARGET4="$AX_TMP/specs/handoffs/step-3.3-test-spec-devops-architect-fakerev.html"
write_handoff "$TARGET4" "devops-architect" "test-spec" "3.3" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolved-in="specs/handoffs/step-3.2-test-spec-backend-engineer-fix-cycle-1.html" data-re-verified-in="specs/handoffs/step-3.3-test-spec-devops-architect-cycle-2.html"><h2>Claims resolved but reviewer says no</h2></aside>'
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
write_handoff "$TARGET5" "devops-architect" "test-spec" "3.3" '<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="false" data-resolution-skip="upstream library fix lives in vendored dep — see commit 9c88227 for the patch we applied locally"><h2>Bypassed for documented reason</h2></aside>'
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

# Behavior tests — session+project-keyed state (T3.2): the session log lives
# at $HOME/.claude/hooks/state/<sha1(cwd)>/<session_id>/session-agents.log
GHO_TMP="$TMP/gho-test"
GHO_SID="gho-sess"
mkdir -p "$GHO_TMP/specs/handoffs"
GHO_STATE="$GHO_TMP/.claude/hooks/state/$(skey "$GHO_TMP")/$GHO_SID"
mkdir -p "$GHO_STATE"

run_gho_hook() {
    local file="$1" content="$2"
    mkpayload_edit_s "$file" "$content" "$GHO_SID" "$GHO_TMP" | (HOME="$GHO_TMP" bash "$HOOK_DIR/guard-handoff-owner.sh" 2>&1) || true
}

# Case 1: writing handoff with NO dispatch logged => block
GHO_HANDOFF="$GHO_TMP/specs/handoffs/step-3.2-myslug-frontend-engineer.html"
got=$(run_gho_hook "$GHO_HANDOFF" "<html data-handoff-version='1'></html>")
assert "no dispatch logged for frontend-engineer -> block" "block" "$got"

# Case 2: 'dispatched' record (PreToolUse, new 4-field format) => allow (E2/H1)
echo "2026-05-27T00:00:00Z|frontend-engineer|dispatched|test dispatch" > "$GHO_STATE/session-agents.log"
got=$(run_gho_hook "$GHO_HANDOFF" "<html data-handoff-version='1'></html>")
assert "dispatched record for frontend-engineer -> allow (H1)" "allow" "$got"

# Case 2b: 'returned' record also accepted
echo "2026-05-27T00:00:00Z|frontend-engineer|returned|test dispatch" > "$GHO_STATE/session-agents.log"
got=$(run_gho_hook "$GHO_HANDOFF" "<html data-handoff-version='1'></html>")
assert "returned record for frontend-engineer -> allow" "allow" "$got"

# Case 2c: legacy 3-field record still accepted
echo "2026-05-27T00:00:00Z|frontend-engineer|test dispatch" > "$GHO_STATE/session-agents.log"
got=$(run_gho_hook "$GHO_HANDOFF" "<html data-handoff-version='1'></html>")
assert "legacy 3-field record -> allow" "allow" "$got"

# Case 2d: dispatch logged under a DIFFERENT session id does not unlock this
# session (H5 isolation)
OTHER_STATE="$GHO_TMP/.claude/hooks/state/$(skey "$GHO_TMP")/other-sess"
mkdir -p "$OTHER_STATE"
mv "$GHO_STATE/session-agents.log" "$OTHER_STATE/session-agents.log"
got=$(run_gho_hook "$GHO_HANDOFF" "<html data-handoff-version='1'></html>")
assert "dispatch in another session does not unlock (H5)" "block" "$got"

# Case 3: dispatch logged for backend-engineer but not frontend => block frontend handoff
echo "2026-05-27T00:00:00Z|backend-engineer|dispatched|test dispatch" > "$GHO_STATE/session-agents.log"
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

# Case 7: end-to-end with track-agents.sh — a PreToolUse dispatch record
# written by the tracker itself unlocks the same session's handoff write
E2E_SID="gho-e2e"
mkpayload_agent_s "uiux-designer" "design the myslug mockups" "$E2E_SID" "$GHO_TMP" "PreToolUse" \
    | (HOME="$GHO_TMP" bash "$HOOK_DIR/track-agents.sh" > /dev/null 2>&1) || true
got=$(mkpayload_edit_s "$GHO_TMP/specs/handoffs/step-2.85-myslug-uiux-designer.html" "<html data-handoff-version='1'></html>" "$E2E_SID" "$GHO_TMP" | (HOME="$GHO_TMP" bash "$HOOK_DIR/guard-handoff-owner.sh" 2>&1) || true)
assert "track-agents PreToolUse record unlocks first handoff write (E2)" "allow" "$got"
TOTAL=$((TOTAL+1))
if grep -q "|uiux-designer|dispatched|" "$GHO_TMP/.claude/hooks/state/$(skey "$GHO_TMP")/$E2E_SID/session-agents.log" 2>/dev/null; then
    echo "  PASS  track-agents.sh writes <ts>|<role>|dispatched|<prompt> at PreToolUse"
    PASS=$((PASS+1))
else
    echo "  FAIL  track-agents.sh dispatched record missing or wrong format"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== engineering standards doc + language sub-files (workflow-equ) ==="

# Main doc exists
TOTAL=$((TOTAL+1))
if [ -f "$WORKFLOW_DIR/docs/engineering-standards.md" ]; then
    echo "  PASS  docs/engineering-standards.md present"
    PASS=$((PASS+1))
else
    echo "  FAIL  docs/engineering-standards.md missing"
    FAIL=$((FAIL+1))
fi

# All 11 language sub-files exist
for lang in rust typescript-react python go jvm csharp-dotnet c-cpp swift ruby sql shell; do
    TOTAL=$((TOTAL+1))
    if [ -f "$WORKFLOW_DIR/docs/engineering-standards/${lang}.md" ]; then
        echo "  PASS  engineering-standards/${lang}.md present"
        PASS=$((PASS+1))
    else
        echo "  FAIL  engineering-standards/${lang}.md missing"
        FAIL=$((FAIL+1))
    fi
done

# §5 index references each sub-file
TOTAL=$((TOTAL+1))
missing_refs=""
for lang in rust typescript-react python go jvm csharp-dotnet c-cpp swift ruby sql shell; do
    grep -q "engineering-standards/${lang}.md" "$WORKFLOW_DIR/docs/engineering-standards.md" || missing_refs="$missing_refs $lang"
done
if [ -z "$missing_refs" ]; then
    echo "  PASS  §5 index references all 11 language sub-files"
    PASS=$((PASS+1))
else
    echo "  FAIL  §5 index missing sub-file references:$missing_refs"
    FAIL=$((FAIL+1))
fi

# Both engineers reference the standards doc
for agent in backend-engineer frontend-engineer; do
    TOTAL=$((TOTAL+1))
    if grep -q 'engineering-standards.md' "$WORKFLOW_DIR/agents/${agent}.md" && \
       grep -qi 'engineering standards' "$WORKFLOW_DIR/agents/${agent}.md"; then
        echo "  PASS  ${agent} has Engineering standards section referencing the doc"
        PASS=$((PASS+1))
    else
        echo "  FAIL  ${agent} missing Engineering standards reference"
        FAIL=$((FAIL+1))
    fi
done

# Both engineers instruct selective language loading (don't load all)
for agent in backend-engineer frontend-engineer; do
    TOTAL=$((TOTAL+1))
    if grep -qi 'load ONLY' "$WORKFLOW_DIR/agents/${agent}.md"; then
        echo "  PASS  ${agent} instructs selective (ONLY) language-sub-file loading"
        PASS=$((PASS+1))
    else
        echo "  FAIL  ${agent} missing selective-load instruction"
        FAIL=$((FAIL+1))
    fi
done

# Both reviewers reference the standards doc as a rubric
for agent in security-architect spec-sre-auditor; do
    TOTAL=$((TOTAL+1))
    if grep -q 'engineering-standards.md' "$WORKFLOW_DIR/agents/${agent}.md"; then
        echo "  PASS  ${agent} references engineering-standards.md as review rubric"
        PASS=$((PASS+1))
    else
        echo "  FAIL  ${agent} missing engineering-standards rubric reference"
        FAIL=$((FAIL+1))
    fi
done

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
echo "=== require-feature-mounted.sh (workflow-0v4 / 2026-05-31 SquashBuckler disconnected-demo-cards) ==="
# Anti-orphan gate: a @layer(ui|full-stack) feature in a >=2-UI-spec epic
# cannot reach @status(verified) unless it is in an @integration spec's
# Mount Map (or imported by the app entry). Fixtures live in their own specs/.
FM="$TMP/fmproj/specs"
mkdir -p "$FM"
# Integration spec with a Mount Map naming widget-alpha
cat > "$FM/shell.md" <<'EOF'
@status(approved)
@integration
@layer(ui)
# Feature: App Shell
## Mount Map
| Feature | Mounts as | Where |
| widget-alpha | AlphaPanel | sidebar |
EOF
printf '@status(approved)\n@layer(ui)\n# Widget Alpha\n' > "$FM/widget-alpha.md"
printf '@status(approved)\n@layer(ui)\n# Widget Beta\n'  > "$FM/widget-beta.md"
printf '@status(approved)\n@layer(api)\n# Backend Svc\n' > "$FM/backend-svc.md"

# A: orphan UI feature (not in Mount Map, not imported) -> BLOCK
got=$(mkpayload_edit "$FM/widget-beta.md" "@status(verified) @layer(ui)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1)
assert "require-feature-mounted blocks orphan UI feature" block "$got"

# B: UI feature listed in Mount Map -> ALLOW
got=$(mkpayload_edit "$FM/widget-alpha.md" "@status(verified) @layer(ui)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1)
assert "require-feature-mounted allows feature in Mount Map" allow "$got"

# C: @mount-skip override on orphan -> ALLOW
got=$(mkpayload_edit "$FM/widget-beta.md" "@status(verified) @layer(ui) @mount-skip(rendered inside widget-alpha)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1)
assert "require-feature-mounted honors @mount-skip" allow "$got"

# D: the @integration spec itself -> ALLOW (it is the host, not a mountee)
got=$(mkpayload_edit "$FM/shell.md" "@status(verified) @integration @layer(ui)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1)
assert "require-feature-mounted exempts the integration spec" allow "$got"

# E: backend (@layer api) spec -> ALLOW (not user-facing)
got=$(mkpayload_edit "$FM/backend-svc.md" "@status(verified) @layer(api)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1)
assert "require-feature-mounted ignores non-UI specs" allow "$got"

# F: no @integration spec in a >=2-UI-spec epic -> BLOCK (NO integration spec)
FM2="$TMP/fmproj2/specs"; mkdir -p "$FM2"
printf '@status(approved)\n@layer(ui)\n# Alpha\n' > "$FM2/alpha.md"
printf '@status(approved)\n@layer(ui)\n# Beta\n'  > "$FM2/beta.md"
got=$(mkpayload_edit "$FM2/beta.md" "@status(verified) @layer(ui)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1)
assert "require-feature-mounted blocks when no integration spec exists" block "$got"

# G: single-UI-spec epic (scope exempt) -> ALLOW
FM3="$TMP/fmproj3/specs"; mkdir -p "$FM3"
printf '@status(approved)\n@layer(ui)\n# Solo\n' > "$FM3/solo.md"
printf '@status(approved)\n@layer(api)\n# Api\n'  > "$FM3/api.md"
got=$(mkpayload_edit "$FM3/solo.md" "@status(verified) @layer(ui)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1)
assert "require-feature-mounted exempts single-UI-spec epic" allow "$got"

echo ""
echo "=== verifier state machine (H2/H3, T3.2) — dispatch markers + keyed inflight state ==="
VH_TMP="$TMP/verifier-home"; VH_PROJ="$TMP/verifier-proj"
VH_SID="vh-sess"
mkdir -p "$VH_TMP" "$VH_PROJ/specs"
VH_STATE="$VH_TMP/.claude/hooks/state/$(skey "$VH_PROJ")/$VH_SID"
VH_PROMPT='You are the CONTINUOUS VERIFIER for Checkout.

SPEC: specs/checkout.md
TASK: workflow-4f2a
EPIC: workflow-8o6

## Context
- Spec: (pasted contents)'

# Dispatch: machine markers extracted into the inflight record (real ID shapes)
mkpayload_agent_s "hyperpowers:code-reviewer" "$VH_PROMPT" "$VH_SID" "$VH_PROJ" "PreToolUse" \
    | (HOME="$VH_TMP" bash "$HOOK_DIR/verifier-dispatch.sh" > /dev/null 2>&1) || true
TOTAL=$((TOTAL+1))
if grep -q '^workflow-4f2a|workflow-8o6|checkout$' "$VH_STATE/verifier-inflight.txt" 2>/dev/null; then
    echo "  PASS  verifier-dispatch extracts SPEC:/TASK:/EPIC: markers into inflight record (H2)"
    PASS=$((PASS+1))
else
    echo "  FAIL  inflight record wrong: $(cat "$VH_STATE/verifier-inflight.txt" 2>/dev/null)"
    FAIL=$((FAIL+1))
fi

# @status(verified) write on the inflight spec blocks
got=$(mkpayload_edit_s "$VH_PROJ/specs/checkout.md" "@status(verified)" "$VH_SID" "$VH_PROJ" | (HOME="$VH_TMP" bash "$HOOK_DIR/block-status-during-verification.sh" 2>&1) || true)
assert "status write blocked while verifier in-flight" "block" "$got"

# A DIFFERENT spec is not blocked
got=$(mkpayload_edit_s "$VH_PROJ/specs/other.md" "@status(verified)" "$VH_SID" "$VH_PROJ" | (HOME="$VH_TMP" bash "$HOOK_DIR/block-status-during-verification.sh" 2>&1) || true)
assert "unrelated spec status write allowed" "allow" "$got"

# bd close with a 4-char-suffix real ID blocks ({3,} fix, H3)
got=$(mkpayload_bash_s "bd close workflow-4f2a" "$VH_SID" "$VH_PROJ" | (HOME="$VH_TMP" bash "$HOOK_DIR/block-status-during-verification.sh" 2>&1) || true)
assert "bd close of inflight 4-char-suffix task blocks (H3)" "block" "$got"

# Mention inside echo does not block (H15 command-position)
got=$(mkpayload_bash_s "echo \"then run bd close workflow-4f2a\"" "$VH_SID" "$VH_PROJ" | (HOME="$VH_TMP" bash "$HOOK_DIR/block-status-during-verification.sh" 2>&1) || true)
assert "echo-mention of bd close does not block (H15)" "allow" "$got"

# Return (tool_response field, fact 8) clears the inflight record
mkpayload_agent_s "hyperpowers:code-reviewer" "$VH_PROMPT" "$VH_SID" "$VH_PROJ" "PostToolUse" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); d["tool_response"]="VERIFIER checkout: PASS"; print(json.dumps(d))' \
    | (cd "$VH_PROJ" && HOME="$VH_TMP" bash "$HOOK_DIR/verifier-return.sh" > /dev/null 2>&1) || true
TOTAL=$((TOTAL+1))
if [ ! -s "$VH_STATE/verifier-inflight.txt" ]; then
    echo "  PASS  verifier-return clears the inflight record (tool_response read)"
    PASS=$((PASS+1))
else
    echo "  FAIL  inflight record not cleared: $(cat "$VH_STATE/verifier-inflight.txt")"
    FAIL=$((FAIL+1))
fi

got=$(mkpayload_edit_s "$VH_PROJ/specs/checkout.md" "@status(verified)" "$VH_SID" "$VH_PROJ" | (HOME="$VH_TMP" bash "$HOOK_DIR/block-status-during-verification.sh" 2>&1) || true)
assert "status write allowed after verifier returned" "allow" "$got"

echo ""
echo "=== clear-session-reads (H5) — compact retains, startup truncates own key only ==="
CS_TMP="$TMP/clear-home"; CS_PROJ="$TMP/clear-proj"; CS_SID="cs-sess"
mkdir -p "$CS_PROJ"
CS_STATE="$CS_TMP/.claude/hooks/state/$(skey "$CS_PROJ")/$CS_SID"
mkdir -p "$CS_STATE"
echo "evidence" > "$CS_STATE/session-agents.log"

SRC=compact SID="$CS_SID" CW="$CS_PROJ" python3 -c 'import json,os; print(json.dumps({"hook_event_name":"SessionStart","source":os.environ["SRC"],"session_id":os.environ["SID"],"cwd":os.environ["CW"]}))' \
    | (HOME="$CS_TMP" bash "$HOOK_DIR/clear-session-reads.sh" > /dev/null 2>&1) || true
TOTAL=$((TOTAL+1))
if [ -s "$CS_STATE/session-agents.log" ]; then
    echo "  PASS  SessionStart source=compact RETAINS state (H5)"
    PASS=$((PASS+1))
else
    echo "  FAIL  compaction wiped session state"
    FAIL=$((FAIL+1))
fi

SRC=startup SID="$CS_SID" CW="$CS_PROJ" python3 -c 'import json,os; print(json.dumps({"hook_event_name":"SessionStart","source":os.environ["SRC"],"session_id":os.environ["SID"],"cwd":os.environ["CW"]}))' \
    | (HOME="$CS_TMP" bash "$HOOK_DIR/clear-session-reads.sh" > /dev/null 2>&1) || true
TOTAL=$((TOTAL+1))
if [ ! -s "$CS_STATE/session-agents.log" ]; then
    echo "  PASS  SessionStart source=startup truncates own session state"
    PASS=$((PASS+1))
else
    echo "  FAIL  startup did not truncate own session state"
    FAIL=$((FAIL+1))
fi

# Another session's state is untouched by this session's startup
CS_OTHER="$CS_TMP/.claude/hooks/state/$(skey "$CS_PROJ")/other-sess"
mkdir -p "$CS_OTHER"; echo "other evidence" > "$CS_OTHER/session-agents.log"
SRC=startup SID="$CS_SID" CW="$CS_PROJ" python3 -c 'import json,os; print(json.dumps({"hook_event_name":"SessionStart","source":os.environ["SRC"],"session_id":os.environ["SID"],"cwd":os.environ["CW"]}))' \
    | (HOME="$CS_TMP" bash "$HOOK_DIR/clear-session-reads.sh" > /dev/null 2>&1) || true
TOTAL=$((TOTAL+1))
if [ -s "$CS_OTHER/session-agents.log" ]; then
    echo "  PASS  startup leaves OTHER sessions' state intact (H5 isolation)"
    PASS=$((PASS+1))
else
    echo "  FAIL  startup wiped another session's state"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== block-unread-edits (H12) — exact-path matching + new-file ordering ==="
BU_TMP="$TMP/bu-home"; BU_PROJ="$TMP/bu-proj"; BU_SID="bu-sess"
mkdir -p "$BU_PROJ/src"
BU_STATE="$BU_TMP/.claude/hooks/state/$(skey "$BU_PROJ")/$BU_SID"
mkdir -p "$BU_STATE"
echo "x" > "$BU_PROJ/src/b.ts"
echo "x" > "$BU_PROJ/src/b.tsx"

# New file + NO reads log at all -> allow (ordering fix)
got=$(mkpayload_edit_s "$BU_PROJ/src/brand-new.ts" "content" "bu-fresh" "$BU_PROJ" | (HOME="$BU_TMP" bash "$HOOK_DIR/block-unread-edits.sh" 2>&1) || true)
assert "new-file creation allowed even with no reads log (H12)" "allow" "$got"

# b.tsx read must NOT satisfy an edit of b.ts (substring fix)
echo "$BU_PROJ/src/b.tsx" > "$BU_STATE/session-reads.txt"
got=$(mkpayload_edit_s "$BU_PROJ/src/b.ts" "content" "$BU_SID" "$BU_PROJ" | (HOME="$BU_TMP" bash "$HOOK_DIR/block-unread-edits.sh" 2>&1) || true)
assert "read of b.tsx does not unlock b.ts (H12)" "block" "$got"

# exact file read -> allow
echo "$BU_PROJ/src/b.ts" >> "$BU_STATE/session-reads.txt"
got=$(mkpayload_edit_s "$BU_PROJ/src/b.ts" "content" "$BU_SID" "$BU_PROJ" | (HOME="$BU_TMP" bash "$HOOK_DIR/block-unread-edits.sh" 2>&1) || true)
assert "exact-path read unlocks the file" "allow" "$got"

# exact parent-dir Grep/Glob entry unlocks files in that dir
echo "y" > "$BU_PROJ/src/c.ts"
echo "$BU_PROJ/src" > "$BU_STATE/session-reads.txt"
got=$(mkpayload_edit_s "$BU_PROJ/src/c.ts" "content" "$BU_SID" "$BU_PROJ" | (HOME="$BU_TMP" bash "$HOOK_DIR/block-unread-edits.sh" 2>&1) || true)
assert "exact parent-dir entry unlocks contained file" "allow" "$got"

echo ""
echo "=== require-bead-description (H15) — command-position matching ==="
got=$(mkpayload_bash 'bd create --title="x"' | bash "$HOOK_DIR/require-bead-description.sh" 2>&1 || true)
assert "bd create without --description blocks" "block" "$got"
got=$(mkpayload_bash 'bd create --title="x" --description="why and what"' | bash "$HOOK_DIR/require-bead-description.sh" 2>&1 || true)
assert "bd create with --description allows" "allow" "$got"
got=$(mkpayload_bash 'echo "next run bd create for this"' | bash "$HOOK_DIR/require-bead-description.sh" 2>&1 || true)
assert "echo-mention of bd create allows (H15)" "allow" "$got"
got=$(mkpayload_bash 'cd proj && bd create --title="x"' | bash "$HOOK_DIR/require-bead-description.sh" 2>&1 || true)
assert "bd create after && still gated" "block" "$got"

echo ""
echo "=== require-investigation-findings (H16) — refs + Decision required ==="
IV_TMP="$TMP/iv-proj"; mkdir -p "$IV_TMP/specs"
IV_SPEC="$IV_TMP/specs/thing.md"
IV_FILLER='@layer(api) @status(implemented)

## Investigation Findings
- looked around the codebase
- everything seems reasonable
- no surprises found'
got=$(mkpayload_edit "$IV_SPEC" "$IV_FILLER" | bash "$HOOK_DIR/require-investigation-findings.sh" 2>&1 || true)
assert "3 lines of filler no longer pass (H16)" "block" "$got"

IV_GOOD='@layer(api) @status(implemented)

## Investigation Findings
- src/auth/middleware.ts:42 — session validation via verifyJwt()
- src/routes/index.ts:17 — consistent error shape
Decision: extend middleware.ts rather than a parallel auth path.'
got=$(mkpayload_edit "$IV_SPEC" "$IV_GOOD" | bash "$HOOK_DIR/require-investigation-findings.sh" 2>&1 || true)
assert "2 file:line refs + Decision line pass" "allow" "$got"

IV_NODEC='@layer(api) @status(implemented)

## Investigation Findings
- src/auth/middleware.ts:42 — session validation
- src/routes/index.ts:17 — error shape'
got=$(mkpayload_edit "$IV_SPEC" "$IV_NODEC" | bash "$HOOK_DIR/require-investigation-findings.sh" 2>&1 || true)
assert "refs without Decision line block" "block" "$got"

got=$(mkpayload_edit "$IV_SPEC" '@layer(api) @status(implemented) @investigation-skip(covered by prior spike in specs/thing-spike.md)' | bash "$HOOK_DIR/require-investigation-findings.sh" 2>&1 || true)
assert "@investigation-skip override allows" "allow" "$got"

echo ""
echo "=== check-open-beads (H14) — clean project produces no integer-expression error ==="
CB_TMP="$TMP/cb-clean"; mkdir -p "$CB_TMP"
cb_out=$( (cd "$CB_TMP" && bash "$HOOK_DIR/check-open-beads.sh" < /dev/null 2>&1); echo "rc=$?" )
TOTAL=$((TOTAL+1))
if ! echo "$cb_out" | grep -q "integer expression" && echo "$cb_out" | grep -q "rc=0"; then
    echo "  PASS  check-open-beads runs clean in an empty project (H14)"
    PASS=$((PASS+1))
else
    echo "  FAIL  check-open-beads errored: ${cb_out:0:200}"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== require-design-ui (M1) — @layer vocabulary escape hatch ==="
DU_TMP="$TMP/du-proj"; mkdir -p "$DU_TMP/specs"
DU_SPEC="$DU_TMP/specs/widget.md"
got=$(mkpayload_edit "$DU_SPEC" '@status(approved) Feature with a button and a form view' | bash "$HOOK_DIR/require-design-ui.sh" 2>&1 || true)
assert "UI-facing spec without design artifacts blocks" "block" "$got"
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q '@layer(' ; then
    echo "  PASS  block message names @layer(...) (not retired tags)"
    PASS=$((PASS+1))
else
    echo "  FAIL  block message does not mention @layer(...): ${got:0:160}"
    FAIL=$((FAIL+1))
fi

got=$(mkpayload_edit "$DU_SPEC" '@status(approved) @layer(api) endpoint returning a list view payload' | bash "$HOOK_DIR/require-design-ui.sh" 2>&1 || true)
assert "@layer(api) skips the design-ui gate (M1)" "allow" "$got"

# Legacy backend-only tag still accepted, with a deprecation nudge
LEG_TAG='@backend'; LEG_TAG="${LEG_TAG}-only"
got=$(mkpayload_edit "$DU_SPEC" "@status(approved) $LEG_TAG endpoint with a form payload" | bash "$HOOK_DIR/require-design-ui.sh" 2>&1 || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q 'hookSpecificOutput' && echo "$got" | grep -q 'DEPRECATED TAG'; then
    echo "  PASS  legacy backend-only tag allowed with deprecation nudge"
    PASS=$((PASS+1))
else
    echo "  FAIL  legacy tag handling wrong: ${got:0:160}"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== require-ui-tests (H6) — single-extension config detection ==="
UT_TMP="$TMP/ut-proj"; mkdir -p "$UT_TMP/specs" "$UT_TMP/tests"
echo "export default {};" > "$UT_TMP/playwright.config.ts"   # ONLY .ts — old ls-brace pipeline failed here
echo "test('checkout-flow renders', () => {})" > "$UT_TMP/tests/checkout-flow.spec.ts"
UT_SPEC="$UT_TMP/specs/checkout-flow.md"
got=$(mkpayload_edit "$UT_SPEC" '@status(verified) @layer(ui)' | bash "$HOOK_DIR/require-ui-tests.sh" 2>&1 || true)
assert "playwright.config.ts alone is detected (H6) and test evidence found" "allow" "$got"

rm -f "$UT_TMP/tests/checkout-flow.spec.ts"
got=$(mkpayload_edit "$UT_SPEC" '@status(verified) @layer(ui)' | bash "$HOOK_DIR/require-ui-tests.sh" 2>&1 || true)
assert "no test evidence blocks" "block" "$got"

got=$(mkpayload_edit "$UT_SPEC" '@status(verified) @layer(ui) @ui-test-skip(covered by e2e in tests/checkout.e2e.ts of parent epic)' | bash "$HOOK_DIR/require-ui-tests.sh" 2>&1 || true)
assert "@ui-test-skip override allows" "allow" "$got"

echo ""
echo "=== require-feature-mounted (H7) — skip-tag misclassification + word-boundary Mount Map ==="
# H7.1: a sibling spec carrying only @integration-skip must NOT count as the
# integration host — the epic has NO integration spec and blocks accordingly
FM4="$TMP/fmproj4/specs"; mkdir -p "$FM4"
printf '@status(approved)\n@layer(ui)\n# Alpha\n' > "$FM4/alpha.md"
printf '@status(approved)\n@layer(ui)\n# Beta\n'  > "$FM4/beta.md"
printf '@status(approved)\n@layer(ui)\n@integration-skip(epic assembled by external shell repo per specs/notes.md)\n# Gamma\n' > "$FM4/gamma.md"
got=$(mkpayload_edit "$FM4/beta.md" "@status(verified) @layer(ui)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1 || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q "NO integration spec"; then
    echo "  PASS  @integration-skip sibling not misread as integration host (H7.1)"
    PASS=$((PASS+1))
else
    echo "  FAIL  expected 'NO integration spec' block, got: ${got:0:160}"
    FAIL=$((FAIL+1))
fi

# H7.2: Mount-Map membership is whole-word — slug 'chat' must not ride on 'chat-window'
FM5="$TMP/fmproj5/specs"; mkdir -p "$FM5"
cat > "$FM5/shell.md" <<'EOF'
@status(approved)
@integration
@layer(ui)
# Feature: App Shell
## Mount Map
| Feature | Mounts as | Where |
| chat-window | ChatWindow | sidebar |
EOF
printf '@status(approved)\n@layer(ui)\n# Chat\n' > "$FM5/chat.md"
printf '@status(approved)\n@layer(ui)\n# Chat Window\n' > "$FM5/chat-window.md"
got=$(mkpayload_edit "$FM5/chat.md" "@status(verified) @layer(ui)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1 || true)
assert "slug 'chat' does not match 'chat-window' Mount Map row (H7.2)" "block" "$got"
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q "NOTE:"; then
    echo "  PASS  whole-dir fallback warning present when bd/epic scoping unavailable (H7.3)"
    PASS=$((PASS+1))
else
    echo "  FAIL  fallback scope warning missing from block message"
    FAIL=$((FAIL+1))
fi
got=$(mkpayload_edit "$FM5/chat-window.md" "@status(verified) @layer(ui)" | bash "$HOOK_DIR/require-feature-mounted.sh" 2>&1 || true)
assert "exact slug 'chat-window' matches its Mount Map row" "allow" "$got"

echo ""
echo "=== require-handoff-artifact (M10/D2) — data-architect gates on @touches-data only ==="
# The api-feature fixture (no @touches-data) must pass WITHOUT a data-architect handoff
rm -f "$TMP/specs/handoffs/step-3.3-api-feature-data-architect.html"
got=$(mkpayload_edit "$TMP/specs/api-feature.md" '@status(verified)' | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1 || true)
assert "@layer(api) without @touches-data needs no data-architect (M10)" "allow" "$got"

# Advisory: DB terms in Technical Context without the tag -> block message
# (missing other handoffs) carries the one-line @touches-data suggestion
ADV_SPEC="$TMP/specs/dbish.md"
cat > "$ADV_SPEC" <<'EOF'
@status(approved)
@layer(api)

## Technical Context
Persists orders to the postgres database via a new table and migration.
EOF
got=$(mkpayload_edit "$ADV_SPEC" '@status(verified)' | bash "$HOOK_DIR/require-handoff-artifact.sh" 2>&1 || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q "BLOCKED" && echo "$got" | grep -q "ADVISORY" && echo "$got" | grep -q "@touches-data"; then
    echo "  PASS  DB terms without @touches-data produce the advisory line (D2)"
    PASS=$((PASS+1))
else
    echo "  FAIL  advisory missing: ${got:0:200}"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== _validate_handoff.py (T3.4) — verdict + severity + route-to vocabulary ==="
VD_TMP="$TMP/vd-proj"; mkdir -p "$VD_TMP/specs/handoffs"

vd_fixture() {  # path role head_extra body_extra
    local path="$1" role="$2" head_extra="$3" body_extra="$4"
    cat > "$path" <<HOFF
<!DOCTYPE html>
<html lang="en" data-handoff-version="1">
<head>
<meta charset="utf-8">
<meta data-from-role="${role}">
<meta data-spec-slug="vd-spec">
<meta data-step="3.3">
<meta data-produced-at="2026-07-05T00:00:00Z">
<meta data-input-references="">
${head_extra}
<title>x</title>
</head>
<body>
<section data-role="summary"><p>x</p></section>
<section data-role="findings">${body_extra}</section>
<section data-role="acceptance-criteria"><dl><dt data-id="a">x</dt><dd>x</dd></dl></section>
<section data-role="open-questions"><ul></ul></section>
</body>
</html>
HOFF
}

VD_F="$VD_TMP/specs/handoffs/step-3.3-vd-spec-qa-engineer.html"
vd_fixture "$VD_F" "qa-engineer" "" ""
TOTAL=$((TOTAL+1))
out=$(python3 "$HOOK_DIR/_validate_handoff.py" "$VD_F" "vd-spec" "qa-engineer" 2>&1)
if echo "$out" | grep -q "missing <meta data-verdict"; then
    echo "  PASS  reviewer handoff without data-verdict is an error (registry §4)"
    PASS=$((PASS+1))
else
    echo "  FAIL  missing data-verdict not flagged (got: ${out:0:160})"
    FAIL=$((FAIL+1))
fi

vd_fixture "$VD_F" "qa-engineer" '<meta data-verdict="MAYBE">' ""
TOTAL=$((TOTAL+1))
out=$(python3 "$HOOK_DIR/_validate_handoff.py" "$VD_F" "vd-spec" "qa-engineer" 2>&1)
if echo "$out" | grep -q "not legal for qa-engineer"; then
    echo "  PASS  illegal verdict value flagged"
    PASS=$((PASS+1))
else
    echo "  FAIL  illegal verdict not flagged (got: ${out:0:160})"
    FAIL=$((FAIL+1))
fi

vd_fixture "$VD_F" "qa-engineer" '<meta data-verdict="FAIL-SPEC-DRIFT">' ""
TOTAL=$((TOTAL+1))
out=$(python3 "$HOOK_DIR/_validate_handoff.py" "$VD_F" "vd-spec" "qa-engineer" 2>&1)
if [ -z "$out" ]; then
    echo "  PASS  FAIL-SPEC-DRIFT is legal for qa-engineer"
    PASS=$((PASS+1))
else
    echo "  FAIL  legal verdict rejected (got: ${out:0:160})"
    FAIL=$((FAIL+1))
fi

VD_P="$VD_TMP/specs/handoffs/step-3.2-vd-spec-backend-engineer.html"
vd_fixture "$VD_P" "backend-engineer" "" ""
TOTAL=$((TOTAL+1))
out=$(python3 "$HOOK_DIR/_validate_handoff.py" "$VD_P" "vd-spec" "backend-engineer" 2>&1)
if [ -z "$out" ]; then
    echo "  PASS  producer role exempt from data-verdict"
    PASS=$((PASS+1))
else
    echo "  FAIL  producer wrongly required to carry verdict (got: ${out:0:160})"
    FAIL=$((FAIL+1))
fi

# Severity vocabulary + route-to requirements
vd_fixture "$VD_P" "backend-engineer" "" '<aside data-severity="major" data-route-to="backend-engineer"><p>x</p></aside>'
TOTAL=$((TOTAL+1))
out=$(python3 "$HOOK_DIR/_validate_handoff.py" "$VD_P" "vd-spec" "backend-engineer" 2>&1)
if echo "$out" | grep -q "not legal"; then
    echo "  PASS  illegal data-severity flagged (registry §5)"
    PASS=$((PASS+1))
else
    echo "  FAIL  illegal severity not flagged (got: ${out:0:160})"
    FAIL=$((FAIL+1))
fi

vd_fixture "$VD_P" "backend-engineer" "" '<aside data-severity="important"><p>no route</p></aside>'
TOTAL=$((TOTAL+1))
out=$(python3 "$HOOK_DIR/_validate_handoff.py" "$VD_P" "vd-spec" "backend-engineer" 2>&1)
if echo "$out" | grep -q "missing data-route-to"; then
    echo "  PASS  important aside without data-route-to flagged"
    PASS=$((PASS+1))
else
    echo "  FAIL  route-to requirement not enforced (got: ${out:0:160})"
    FAIL=$((FAIL+1))
fi

vd_fixture "$VD_P" "backend-engineer" "" '<aside data-severity="spec-drift"><p>drift note</p></aside>'
TOTAL=$((TOTAL+1))
out=$(python3 "$HOOK_DIR/_validate_handoff.py" "$VD_P" "vd-spec" "backend-engineer" 2>&1)
if [ -z "$out" ]; then
    echo "  PASS  spec-drift severity legal; no route-to required"
    PASS=$((PASS+1))
else
    echo "  FAIL  spec-drift aside wrongly flagged (got: ${out:0:160})"
    FAIL=$((FAIL+1))
fi

echo ""
echo "=== UserPromptSubmit hooks (H8) — .prompt field + hookSpecificOutput wrapper ==="
UP_TMP="$TMP/ups-proj"; mkdir -p "$UP_TMP"

got=$( (cd "$UP_TMP" && echo '{"prompt":"please add a new endpoint to the api"}' | bash "$HOOK_DIR/workflow-reminder.sh" 2>&1) || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q 'hookSpecificOutput' && echo "$got" | grep -q '/design'; then
    echo "  PASS  workflow-reminder reads .prompt and emits wrapped context (H8)"
    PASS=$((PASS+1))
else
    echo "  FAIL  workflow-reminder output wrong: ${got:0:160}"
    FAIL=$((FAIL+1))
fi

got=$( (cd "$UP_TMP" && echo '{"prompt":"why did you delete the tests? this is wrong"}' | bash "$HOOK_DIR/detect-correction.sh" 2>&1) || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q 'hookSpecificOutput' && echo "$got" | grep -q 'WORKFLOW INCIDENT'; then
    echo "  PASS  detect-correction reads .prompt and detects corrections (H8)"
    PASS=$((PASS+1))
else
    echo "  FAIL  detect-correction output wrong: ${got:0:160}"
    FAIL=$((FAIL+1))
fi

got=$( (cd "$UP_TMP" && echo '{"prompt":"just a normal question"}' | bash "$HOOK_DIR/wwiwo.sh" 2>&1) || true)
assert "wwiwo without trigger word stays silent (fact 5 — matcher is decorative)" "allow" "$got"

got=$( (cd "$UP_TMP" && echo '{"prompt":"wwiwo?"}' | bash "$HOOK_DIR/wwiwo.sh" 2>&1) || true)
TOTAL=$((TOTAL+1))
if echo "$got" | grep -q 'hookSpecificOutput'; then
    echo "  PASS  wwiwo trigger word in prompt fires the hook"
    PASS=$((PASS+1))
else
    echo "  FAIL  wwiwo trigger did not fire: ${got:0:160}"
    FAIL=$((FAIL+1))
fi

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
    "require-feature-mounted.sh"
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
echo "Total: $TOTAL  Pass: $PASS  Fail: $FAIL  Skip: $SKIP"
echo "=========================================="
# NOT `exit $FAIL`: exit codes are mod 256, so 256 failures would wrap to 0.
exit $((FAIL > 0 ? 1 : 0))
