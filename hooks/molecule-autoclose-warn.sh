#!/usr/bin/env bash
set -euo pipefail

# PostToolUse Bash hook — detects when a bd close on a child task triggered
# beads' "Auto-closed completed molecule" promotion, which closes the parent
# epic INTERNALLY without going through the Bash tool. That bypasses
# require-release-handoff.sh (a PreToolUse Bash matcher) and silently skips
# the release-coordinator gate.
#
# This hook can't PREVENT the auto-close (it fires after), but it can SURFACE
# what happened so the user/orchestrator notices the bypass and produces
# a release-coordinator handoff retroactively if needed.
#
# To fully prevent the bypass, beads' molecule auto-close behavior would need
# to be disabled at the beads config level — beyond what a Claude Code hook
# can enforce.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Advisory hook: exit quietly when python is unavailable (fail-open per E6).
if [ -z "${PYTHON:-}" ]; then
    exit 0
fi

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

# Extract the command and its output. tool_result format varies; try common paths.
cmd=$(json_get "$tool_use_json" ".tool.input.command" "")
[ -z "$cmd" ] && cmd=$(json_get "$tool_use_json" ".tool_input.command" "")

if [ -z "$cmd" ]; then
    echo '{}'
    exit 0
fi

# Only care about bd close commands
if ! echo "$cmd" | grep -qE '\bbd\s+close\b'; then
    echo '{}'
    exit 0
fi

# Extract the tool's stdout — the auto-close message lives there.
# Documented PostToolUse field is `tool_response`; for Bash it is a dict and
# the message is in `.stdout` (docs/harness-behavior.md fact 8). Legacy field
# names kept as fallback for older harness versions.
output=$("$PYTHON" -c "
import json, sys
try:
    d = json.load(sys.stdin)
    tr = d.get('tool_response')
    if isinstance(tr, dict):
        out = str(tr.get('stdout') or '') + '\n' + str(tr.get('stderr') or '')
        if out.strip():
            print(out)
            sys.exit(0)
    elif tr:
        print(tr if isinstance(tr, str) else json.dumps(tr))
        sys.exit(0)
    for path in [
        lambda x: x['tool_result'],
        lambda x: x['tool']['result'],
        lambda x: x['result'],
        lambda x: x.get('output', ''),
    ]:
        try:
            v = path(d)
            if v:
                print(v if isinstance(v, str) else json.dumps(v))
                sys.exit(0)
        except (KeyError, TypeError):
            continue
    print('')
except Exception:
    print('')
" <<< "$tool_use_json" 2>/dev/null)

# Look for the beads auto-close marker. Current beads emits:
#   ✓ Auto-closed completed molecule <epic-id>
# Be tolerant of small wording variations.
if echo "$output" | grep -qiE "auto-closed.*molecule|molecule.*auto-closed"; then
    epic_id=$(echo "$output" | grep -oE '[a-z]+-[a-z0-9]{3,}' | tail -1)
    if [ -n "$epic_id" ]; then
        msg="WARNING: beads auto-closed epic ${epic_id} as a side-effect of this bd close. This bypassed the require-release-handoff.sh gate. If you intended for release-coordinator to gate this epic, dispatch it now and produce specs/handoffs/step-4.2-${epic_id}-release-coordinator.html before any downstream work depends on the epic being closed. To disable beads' auto-close, configure beads to not promote-close molecules, or close child tasks individually + run 'bd epic close-eligible' manually after the release-coordinator gate."
        json_encode_context "$msg" "PostToolUse"
        exit 0
    fi
fi

echo '{}'
