#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook on Edit/Write targeting .claude/agent-memory/*.md files.
#
# Blocks writes that contain secret-shaped strings (Bearer tokens, AWS access
# keys, sk_live keys, PEM private keys, etc.). Agent memory is committed to
# git by default — this is belt-and-suspenders against accidentally writing
# real secrets into memory.
#
# Override (rare, document the reason): include the literal token
# `@memory-allow-secret(<concise reason>)` in the new content.
#
# Runs as PreToolUse hook on Edit/Write.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Defensive: if the Python detector isn't installed (e.g. install.sh ran on an
# older version that only symlinked *.sh), degrade gracefully.
DETECTOR="$HOOK_DIR/_detect_memory_secrets.py"
if [ ! -f "$DETECTOR" ]; then
    echo >&2 "guard-agent-memory-secrets: detector not found at $DETECTOR — allowing edit (run install.sh to restore)"
    echo '{}'
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

file_path=$(json_get "$tool_use_json" ".tool.input.file_path" "")
[ -z "$file_path" ] && file_path=$(json_get "$tool_use_json" ".tool_input.file_path" "")

if [ -z "$file_path" ]; then
    echo '{}'
    exit 0
fi

# Only care about agent-memory files
case "$file_path" in
    */.claude/agent-memory/*.md|*.claude/agent-memory/*.md) ;;
    *) echo '{}'; exit 0 ;;
esac

# Extract new content (Edit: new_string, Write: content)
new_content=$(json_get "$tool_use_json" ".tool.input.new_string" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.new_string" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool.input.content" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.content" "")

if [ -z "$new_content" ]; then
    echo '{}'
    exit 0
fi

# Escape hatch
if echo "$new_content" | grep -qE '@memory-allow-secret\([^)]+\)'; then
    echo '{}'
    exit 0
fi

# Run detector
detection=$(printf '%s' "$new_content" | "$PYTHON" "$DETECTOR" 2>/dev/null || true)

if [ -z "$detection" ]; then
    echo '{}'
    exit 0
fi

basename_file=$(basename "$file_path")

# Build escaped detection lines for the error JSON
detection_lines=""
while IFS= read -r line; do
    [ -z "$line" ] && continue
    detection_lines="${detection_lines}\n  - ${line}"
done <<< "$detection"

cat <<EOF
{"error": "BLOCKED: Write to ${basename_file} contains secret-shaped content. Agent memory files are committed to git by default; secrets MUST NOT be written into memory.\n\nDetected:${detection_lines}\n\nRemediation:\n  1. Remove the secret-shaped strings from the write.\n  2. If the memory needs to reference where secrets live, use a POINTER instead — name the env var, secret manager path, or doc location, never the value.\n  3. If this is a genuine false positive (e.g. you're documenting a known-public test fixture), add the literal token to the new_string:\n       @memory-allow-secret(<concise reason>)\n     The override persists in the memory file as documentation.\n\nReference: skills/onboard/SKILL.md critical_rules #1."}
EOF
