#!/usr/bin/env bash
set -euo pipefail

# PreToolUse + PostToolUse hook for the Agent tool (registered on BOTH events
# in install.sh — decision E2, docs/decisions/0001-enforcement-architecture.md).
#
# Logs every agent dispatch AND return to the session-state file so other
# hooks can check whether required agents fired:
#   PreToolUse  -> <ts>|<role>|dispatched|<prompt-first-4k-one-line>
#   PostToolUse -> <ts>|<role>|returned|<prompt-first-4k-one-line>
#
# Logging at PreToolUse (dispatch time) fixes evaluation H1: the dispatched
# role agent writes its handoff DURING the run, and guard-handoff-owner.sh
# must see the dispatch record before that write — a PostToolUse-only log
# deadlocked the first dispatch of every role.
#
# The event is read from the payload's hook_event_name field. Payloads
# without it (legacy fixtures) are recorded as "dispatched" — the
# enforcement-relevant record.
#
# Companions: guard-handoff-owner.sh, require-verifier-agents.sh.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Advisory tracker: exit quietly when python is unavailable (fail-open per E6).
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

STATE_DIR="$(state_dir "$tool_use_json")"
AGENTS_FILE="${STATE_DIR}/session-agents.log"
touch "$AGENTS_FILE"

# dispatched (PreToolUse) vs returned (PostToolUse)
event=$(json_get "$tool_use_json" ".hook_event_name" "")
case "$event" in
    PostToolUse) record="returned" ;;
    *)           record="dispatched" ;;
esac

# Extract subagent_type and prompt — try the documented paths
subagent_type=$(json_get "$tool_use_json" ".tool.input.subagent_type" "")
if [ -z "$subagent_type" ]; then
    subagent_type=$(json_get "$tool_use_json" ".tool_input.subagent_type" "")
fi

prompt=$(json_get "$tool_use_json" ".tool.input.prompt" "")
if [ -z "$prompt" ]; then
    prompt=$(json_get "$tool_use_json" ".tool_input.prompt" "")
fi

# Default subagent_type when omitted is "general-purpose"
[ -z "$subagent_type" ] && subagent_type="general-purpose"

# Skip if we couldn't extract a prompt — nothing meaningful to log
if [ -z "$prompt" ]; then
    echo '{}'
    exit 0
fi

# Compact the prompt to one line for grep-friendly storage
# Keep first 4000 chars so spec slugs and key identifiers survive
prompt_oneline=$("$PYTHON" -c "
import sys
p = sys.stdin.read().replace('\n', ' ').replace('\r', ' ')
print(p[:4000])
" <<< "$prompt" 2>/dev/null)

# Append: timestamp|subagent_type|dispatched-or-returned|prompt-one-line
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s|%s|%s|%s\n' "$timestamp" "$subagent_type" "$record" "$prompt_oneline" >> "$AGENTS_FILE"

echo '{}'
