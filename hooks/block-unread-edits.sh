#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write on files that haven't been Read/Grep/Glob'd first.
# Enforces the workflow rule: investigate before writing.
# Companion to track-reads.sh which maintains the reads log.
#
# Matching is EXACT-PATH (evaluation H12): a read of b.tsx no longer
# satisfies an edit of b.ts, and a read of one file no longer unlocks its
# whole directory. Directory unlock requires a Grep/Glob logged against the
# exact parent directory path. New files (target does not exist) are always
# allowed — there is nothing to investigate.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# The reads log is written by an advisory tracker that fails open without
# python — blocking here with no python would block every edit forever.
if [ -z "${PYTHON:-}" ]; then
    exit 0
fi

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

# Extract the file path being edited (try multiple JSON shapes)
file_path=$(json_get "$tool_use_json" ".tool.input.file_path" "null")
if [ "$file_path" = "null" ] || [ -z "$file_path" ]; then
    file_path=$(json_get "$tool_use_json" ".tool_input.file_path" "null")
fi

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

# Allow new files FIRST (file doesn't exist yet - nothing to investigate).
# This must precede the reads-file existence check: with no reads log yet,
# creating the very first new file used to be blocked (evaluation H12).
if [ ! -e "$abs_path" ]; then
    echo '{}'
    exit 0
fi

READS_FILE="$(state_dir "$tool_use_json")/session-reads.txt"

# If reads file doesn't exist, no reads have happened this session -> block
if [ ! -f "$READS_FILE" ]; then
    cat >&2 <<'EOF'
BLOCKED: You must Read, Grep, or Glob the target file before editing it. Investigate existing code first.
EOF
    exit 2
fi

# Exact-path match: this file was read
if grep -qxF "$abs_path" "$READS_FILE" 2>/dev/null; then
    echo '{}'
    exit 0
fi

# Exact-path match: the file's parent directory was Grep/Glob'd
file_dir=$(dirname "$abs_path")
if grep -qxF "$file_dir" "$READS_FILE" 2>/dev/null; then
    echo '{}'
    exit 0
fi

# Block: file exists but wasn't read first
cat >&2 <<EOF
BLOCKED: You must Read, Grep, or Glob '$(basename "$abs_path")' before editing it. Investigate existing code first. File: $abs_path
EOF
exit 2
