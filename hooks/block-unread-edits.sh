#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write on files that haven't been Read/Grep/Glob'd first.
# Enforces the workflow rule: investigate before writing.
# Companion to track-reads.sh which maintains the reads log.

READS_DIR="${HOME}/.claude/hooks/state"
READS_FILE="${READS_DIR}/session-reads.txt"

# If reads file doesn't exist, block (no reads have happened)
if [ ! -f "$READS_FILE" ]; then
    echo '{"error": "BLOCKED: You must Read, Grep, or Glob the target file before editing it. Investigate existing code first."}'
    exit 0
fi

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

# Extract the file path being edited
file_path=$(echo "$tool_use_json" | jq -r '.tool.input.file_path // .tool_input.file_path // "null"' 2>/dev/null || echo "null")

if [ "$file_path" = "null" ] || [ -z "$file_path" ]; then
    # Can't determine file - allow (don't block on parse failures)
    echo '{}'
    exit 0
fi

# Normalize to absolute path
if [ -e "$file_path" ]; then
    abs_path=$(cd "$(dirname "$file_path")" 2>/dev/null && echo "$(pwd)/$(basename "$file_path")" || echo "$file_path")
else
    abs_path="$file_path"
fi

# Check if this exact file was read
if grep -qF "$abs_path" "$READS_FILE" 2>/dev/null; then
    echo '{}'
    exit 0
fi

# Check if the file's directory was read (via Grep/Glob on parent dir)
file_dir=$(dirname "$abs_path")
if grep -qF "$file_dir" "$READS_FILE" 2>/dev/null; then
    echo '{}'
    exit 0
fi

# Allow new files (file doesn't exist yet - nothing to investigate)
if [ ! -e "$abs_path" ]; then
    echo '{}'
    exit 0
fi

# Block: file exists but wasn't read first
echo "{\"error\": \"BLOCKED: You must Read, Grep, or Glob '$(basename "$abs_path")' before editing it. Investigate existing code first. File: $abs_path\"}"
