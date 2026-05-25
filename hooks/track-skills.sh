#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook for Skill tool.
# Logs every Skill invocation (skill name + args) to a session-state file
# so other hooks can verify that claimed skill calls actually happened.
# Companion to claim-vs-call-audit.sh.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

SKILLS_DIR="${HOME}/.claude/hooks/state"
SKILLS_FILE="${SKILLS_DIR}/session-skills.log"

mkdir -p "$SKILLS_DIR"
touch "$SKILLS_FILE"

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

skill=$(json_get "$tool_use_json" ".tool.input.skill" "")
[ -z "$skill" ] && skill=$(json_get "$tool_use_json" ".tool_input.skill" "")

args=$(json_get "$tool_use_json" ".tool.input.args" "")
[ -z "$args" ] && args=$(json_get "$tool_use_json" ".tool_input.args" "")

if [ -z "$skill" ]; then
    echo '{}'
    exit 0
fi

# Flatten args to one line; keep first 1000 chars
args_oneline=$("$PYTHON" -c "
import sys
a = sys.stdin.read().replace('\n', ' ').replace('\r', ' ')
print(a[:1000])
" <<< "$args" 2>/dev/null)

timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s|%s|%s\n' "$timestamp" "$skill" "$args_oneline" >> "$SKILLS_FILE"

echo '{}'
