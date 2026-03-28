#!/usr/bin/env bash
set -euo pipefail

# Track files that have been Read/Grep/Glob'd in this session.
# Companion to block-unread-edits.sh - this tracks reads,
# that script blocks edits on files not tracked here.

READS_DIR="${HOME}/.claude/hooks/state"
READS_FILE="${READS_DIR}/session-reads.txt"

mkdir -p "$READS_DIR"
touch "$READS_FILE"

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

tool_name=$(echo "$tool_use_json" | jq -r '.tool.name // .tool_name // "unknown"' 2>/dev/null || echo "unknown")

# Extract file path based on tool type
file_path=""
case "$tool_name" in
    "Read")
        file_path=$(echo "$tool_use_json" | jq -r '.tool.input.file_path // .tool_input.file_path // "null"' 2>/dev/null || echo "null")
        ;;
    "Grep")
        file_path=$(echo "$tool_use_json" | jq -r '.tool.input.path // .tool_input.path // "null"' 2>/dev/null || echo "null")
        ;;
    "Glob")
        file_path=$(echo "$tool_use_json" | jq -r '.tool.input.path // .tool_input.path // "null"' 2>/dev/null || echo "null")
        ;;
esac

# Log the read path (file or directory)
if [ -n "$file_path" ] && [ "$file_path" != "null" ]; then
    # Normalize: resolve to absolute path if possible
    if [ -e "$file_path" ]; then
        abs_path=$(cd "$(dirname "$file_path")" 2>/dev/null && echo "$(pwd)/$(basename "$file_path")" || echo "$file_path")
    else
        abs_path="$file_path"
    fi
    echo "$abs_path" >> "$READS_FILE"
fi

echo '{}'
