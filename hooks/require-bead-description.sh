#!/usr/bin/env bash
set -euo pipefail

# Block `bd create` commands that are missing --description.
# Every bead needs context about WHY it exists and WHAT needs to be done.
# Runs as PreToolUse hook on Bash commands.

# Read tool use event from stdin
if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

# Validate JSON
if ! echo "$tool_use_json" | jq empty 2>/dev/null; then
    echo '{}'
    exit 0
fi

# Extract the bash command
command=$(echo "$tool_use_json" | jq -r '.tool.input.command // .tool_input.command // "null"' 2>/dev/null || echo "null")

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
