#!/usr/bin/env bash
# install-roundtrip.sh — fresh-clone install/uninstall roundtrip test.
#
# Runs entirely inside a sandbox: a fresh `git clone` of this repo (doubling as
# the T1.1 fresh-clone acceptance test) plus an isolated HOME. The real user's
# ~/.claude (settings, hooks, skills, agents) is never touched.
#
# macOS bash 3.2 compatible: no associative arrays, no GNU-only flags.
#
# Exit: 0 if every assertion passes, 1 otherwise. Prints PASS/FAIL per
# assertion and a final total.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo "PASS: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "FAIL: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# assert <description> <command...>  — PASS if command exits 0
assert() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/install-roundtrip.XXXXXX")"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

CLONE="$SANDBOX/clone"
HOME_DIR="$SANDBOX/home"
FAKE_CLAUDE="$HOME_DIR/.claude"
SETTINGS="$FAKE_CLAUDE/settings.json"
MANIFEST="$FAKE_CLAUDE/workflow-install-manifest.json"
USER_HOOK_CMD="echo user-own-hook"

PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" > /dev/null 2>&1; then
        PYTHON="$candidate"
        break
    fi
done
if [ -z "$PYTHON" ]; then
    echo "FATAL: python3 required to run this test"
    exit 1
fi

echo "=== install/uninstall roundtrip test ==="
echo "sandbox: $SANDBOX"
echo ""

# --- Setup: fresh clone (T1.1 acceptance) + uncommitted script overlay ---------
echo "--- setup: fresh clone + sandbox HOME ---"
if git clone --quiet "$REPO_ROOT" "$CLONE" 2>/dev/null; then
    pass "git clone of working tree succeeds"
else
    fail "git clone of working tree succeeds"
    echo "cannot continue without a clone"
    echo ""
    echo "TOTAL: $PASS_COUNT passed, $((FAIL_COUNT)) failed"
    exit 1
fi
# Overlay the (possibly uncommitted) scripts under test
cp -f "$REPO_ROOT/install.sh" "$CLONE/install.sh"
cp -f "$REPO_ROOT/uninstall.sh" "$CLONE/uninstall.sh"

mkdir -p "$FAKE_CLAUDE"
# Seed a settings.json with one pre-existing USER-owned hook on the same
# matcher install merges into (Edit|Write) — it must survive the roundtrip.
cat > "$SETTINGS" <<SETTINGS_EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "$USER_HOOK_CMD" }
        ]
      }
    ]
  }
}
SETTINGS_EOF

# Helper: count occurrences of the user hook command in settings
user_hook_count() {
    "$PYTHON" -c "
import json, sys
s = json.load(open(sys.argv[1]))
n = 0
for entries in s.get('hooks', {}).values():
    for e in entries:
        for h in e.get('hooks', []):
            if h.get('command') == sys.argv[2]:
                n += 1
print(n)
" "$SETTINGS" "$USER_HOOK_CMD"
}

# --- (b) First install ----------------------------------------------------------
echo ""
echo "--- install #1 (--yes, sandbox HOME) ---"
install1_log="$SANDBOX/install1.log"
HOME="$HOME_DIR" bash "$CLONE/install.sh" --yes < /dev/null > "$install1_log" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
    pass "install.sh --yes exits 0"
else
    fail "install.sh --yes exits 0 (rc=$rc)"
    sed 's/^/    | /' "$install1_log"
fi

# Every hook command registered in settings resolves to an existing file
missing_hooks="$("$PYTHON" -c "
import json, sys
s = json.load(open(sys.argv[1]))
home = sys.argv[2]
missing = []
for entries in s.get('hooks', {}).values():
    for e in entries:
        for h in e.get('hooks', []):
            cmd = h.get('command', '')
            if '/.claude/hooks/' not in cmd:
                continue
            path = cmd.split(None, 1)[1] if ' ' in cmd else cmd
            path = path.replace('\${HOME}', home).replace('\$HOME', home)
            import os
            if not os.path.isfile(path):
                missing.append(cmd)
print('\n'.join(missing))
" "$SETTINGS" "$HOME_DIR")"
if [ -z "$missing_hooks" ]; then
    pass "every hook command in settings.json resolves to an existing file"
else
    fail "every hook command in settings.json resolves to an existing file"
    echo "$missing_hooks" | sed 's/^/    missing: /'
fi

# Skills: all 7 SKILL.md links resolve
skills_ok=1
for s in build design design-arch design-ui onboard respec workflow-retrospective; do
    if [ ! -f "$FAKE_CLAUDE/skills/$s/SKILL.md" ]; then
        skills_ok=0
        echo "    missing skill: $s/SKILL.md"
    fi
done
if [ "$skills_ok" -eq 1 ]; then
    pass "all 7 skills' SKILL.md resolve post-install"
else
    fail "all 7 skills' SKILL.md resolve post-install"
fi

# Skill resources resolve at their installed paths (finding I2)
assert "design/resources/gherkin-spec-reference.md resolves" \
    test -f "$FAKE_CLAUDE/skills/design/resources/gherkin-spec-reference.md"
# onboard resources: what the installed path exposes must match the repo
repo_res_count="$(ls "$CLONE/skills/onboard/resources/" 2>/dev/null | wc -l | tr -d ' ')"
onboard_res_count="$(ls "$FAKE_CLAUDE/skills/onboard/resources/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "${onboard_res_count:-0}" -ge 17 ] && [ "$onboard_res_count" = "$repo_res_count" ]; then
    pass "onboard/resources/ resolves with all templates ($onboard_res_count files)"
else
    fail "onboard/resources/ resolves with all templates (installed ${onboard_res_count:-0}, repo ${repo_res_count:-0}, want >= 17 and equal)"
fi

# No dangling symlinks anywhere under the sandbox ~/.claude
dangling="$(find "$FAKE_CLAUDE" -type l ! -exec test -e {} \; -print 2>/dev/null)"
if [ -z "$dangling" ]; then
    pass "no dangling symlinks under sandbox ~/.claude"
else
    fail "no dangling symlinks under sandbox ~/.claude"
    echo "$dangling" | sed 's/^/    dangling: /'
fi

# All 16 agents linked
agent_count="$(ls "$FAKE_CLAUDE/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')"
if [ "${agent_count:-0}" -eq 16 ]; then
    pass "all 16 agents linked"
else
    fail "all 16 agents linked (found ${agent_count:-0})"
fi

# Manifest written and valid
if [ -f "$MANIFEST" ] && "$PYTHON" -c "
import json, sys
m = json.load(open(sys.argv[1]))
assert m['schema_version'] == 1
assert m['repo']
assert m['links']
assert m['settings_hooks']
" "$MANIFEST" 2>/dev/null; then
    pass "manifest exists, is valid JSON, and records links + settings hooks"
else
    fail "manifest exists, is valid JSON, and records links + settings hooks"
fi

# Pre-existing user hook survived the merge
if [ "$(user_hook_count)" = "1" ]; then
    pass "pre-existing user hook present exactly once after install"
else
    fail "pre-existing user hook present exactly once after install (count=$(user_hook_count))"
fi

# --- (c) Second install: idempotency ---------------------------------------------
echo ""
echo "--- install #2 (idempotency) ---"
install2_log="$SANDBOX/install2.log"
HOME="$HOME_DIR" bash "$CLONE/install.sh" --yes < /dev/null > "$install2_log" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
    pass "re-running install.sh --yes exits 0"
else
    fail "re-running install.sh --yes exits 0 (rc=$rc)"
    sed 's/^/    | /' "$install2_log"
fi

dup_cmds="$("$PYTHON" -c "
import json, sys
s = json.load(open(sys.argv[1]))
seen = set()
dups = []
for event, entries in s.get('hooks', {}).items():
    for e in entries:
        for h in e.get('hooks', []):
            key = (event, e.get('matcher', ''), h.get('command', ''))
            if key in seen:
                dups.append('%s/%s: %s' % key)
            seen.add(key)
print('\n'.join(dups))
" "$SETTINGS")"
if [ -z "$dup_cmds" ]; then
    pass "no duplicate hook commands in settings.json after re-install"
else
    fail "no duplicate hook commands in settings.json after re-install"
    echo "$dup_cmds" | sed 's/^/    dup: /'
fi

if [ "$(user_hook_count)" = "1" ]; then
    pass "user hook still present exactly once after re-install"
else
    fail "user hook still present exactly once after re-install (count=$(user_hook_count))"
fi

# No .pre-workflow backups of our own links were created on re-install
stray_backups="$(find "$FAKE_CLAUDE/skills" "$FAKE_CLAUDE/agents" "$FAKE_CLAUDE/hooks" \
    -name '*.pre-workflow*' 2>/dev/null)"
if [ -z "$stray_backups" ]; then
    pass "re-install did not back up its own links"
else
    fail "re-install did not back up its own links"
    echo "$stray_backups" | sed 's/^/    stray: /'
fi

# --- (d) Uninstall -----------------------------------------------------------------
echo ""
echo "--- uninstall ---"
uninstall_log="$SANDBOX/uninstall.log"
HOME="$HOME_DIR" bash "$CLONE/uninstall.sh" < /dev/null > "$uninstall_log" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
    pass "uninstall.sh exits 0"
else
    fail "uninstall.sh exits 0 (rc=$rc)"
    sed 's/^/    | /' "$uninstall_log"
fi

# No symlinks into the clone remain anywhere under sandbox ~/.claude
leftover=""
for link in $(find "$FAKE_CLAUDE" -type l 2>/dev/null); do
    target="$(readlink "$link")"
    case "$target" in
        "$CLONE"/*) leftover="$leftover$link -> $target
" ;;
    esac
done
if [ -z "$leftover" ]; then
    pass "no symlinks into the clone remain under sandbox ~/.claude"
else
    fail "no symlinks into the clone remain under sandbox ~/.claude"
    printf '%s' "$leftover" | sed 's/^/    leftover: /'
fi

# settings.json: user hook intact, zero workflow hook commands
if [ "$(user_hook_count)" = "1" ]; then
    pass "user hook survived uninstall"
else
    fail "user hook survived uninstall (count=$(user_hook_count))"
fi

wf_cmds="$("$PYTHON" -c "
import json, sys
s = json.load(open(sys.argv[1]))
found = []
for entries in s.get('hooks', {}).values():
    for e in entries:
        for h in e.get('hooks', []):
            if '/.claude/hooks/' in h.get('command', ''):
                found.append(h['command'])
print('\n'.join(found))
" "$SETTINGS")"
if [ -z "$wf_cmds" ]; then
    pass "zero workflow hook commands remain in settings.json"
else
    fail "zero workflow hook commands remain in settings.json"
    echo "$wf_cmds" | sed 's/^/    remains: /'
fi

assert "manifest deleted by uninstall" test ! -e "$MANIFEST"

# settings.json still valid JSON after all the surgery
assert "settings.json still valid JSON after uninstall" \
    "$PYTHON" -c "import json,sys; json.load(open(sys.argv[1]))" "$SETTINGS"

# Second uninstall must refuse cleanly (no manifest)
uninstall2_log="$SANDBOX/uninstall2.log"
HOME="$HOME_DIR" bash "$CLONE/uninstall.sh" < /dev/null > "$uninstall2_log" 2>&1
rc=$?
if [ "$rc" -ne 0 ] && grep -q "no manifest" "$uninstall2_log"; then
    pass "second uninstall refuses with 'no manifest' message and nonzero exit"
else
    fail "second uninstall refuses with 'no manifest' message and nonzero exit (rc=$rc)"
    sed 's/^/    | /' "$uninstall2_log"
fi

# --- Total ---------------------------------------------------------------------------
echo ""
echo "=== TOTAL: $PASS_COUNT passed, $FAIL_COUNT failed ==="
if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
