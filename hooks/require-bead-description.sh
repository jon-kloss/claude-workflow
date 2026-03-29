#!/usr/bin/env bash
set -euo pipefail

# Block `bd create` commands that are missing --description.
# Every bead needs context about WHY it exists and WHAT needs to be done.
# Runs as PreToolUse hook on Bash commands.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Read tool use event from stdin
if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

# Validate JSON
if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

# Extract the bash command (try multiple JSON shapes)
command=$(json_get "$tool_use_json" ".tool.input.command" "null")
if [ "$command" = "null" ] || [ -z "$command" ]; then
    command=$(json_get "$tool_use_json" ".tool_input.command" "null")
fi

if [ "$command" = "null" ] || [ -z "$command" ]; then
    echo '{}'
    exit 0
fi

# Only check bd create commands
if ! echo "$command" | grep -qE '\bbd\s+create\b'; then
    echo '{}'
    exit 0
fi

# Check if --description is present
if echo "$command" | grep -q -- '--description'; then
    echo '{}'
    exit 0
fi

# Block: bd create without --description
echo '{"error": "BLOCKED: bd create requires --description flag. Every bead must have a description explaining WHY this issue exists and WHAT needs to be done. Add --description=\"...\" to your command."}'
