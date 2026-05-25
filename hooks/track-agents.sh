#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook for Agent tool.
# Logs every agent dispatch (subagent_type + prompt) to a session-state file
# so other hooks can check whether required verification agents fired.
# Companion to require-verifier-agents.sh.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

AGENTS_DIR="${HOME}/.claude/hooks/state"
AGENTS_FILE="${AGENTS_DIR}/session-agents.log"

mkdir -p "$AGENTS_DIR"
touch "$AGENTS_FILE"

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

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

# Append: timestamp|subagent_type|prompt-first-4k-chars-on-one-line
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s|%s|%s\n' "$timestamp" "$subagent_type" "$prompt_oneline" >> "$AGENTS_FILE"

echo '{}'
