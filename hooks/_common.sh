#!/usr/bin/env bash
# Shared helpers for workflow hooks - cross-platform (macOS, Linux, Windows/Git Bash)

# Find a working Python 3 interpreter (python3 is a broken MS Store stub on Windows)
_find_python() {
    for candidate in python3 python; do
        if command -v "$candidate" &> /dev/null; then
            if "$candidate" -c "import sys; assert sys.version_info[0] >= 3" 2>/dev/null; then
                echo "$candidate"
                return 0
            fi
        fi
    done
    echo ""
    return 1
}

PYTHON="$(_find_python)"

# json_get <json_string> <key> [fallback]
# Extract a top-level or nested key from JSON. Uses dot notation for nesting.
# Examples:
#   json_get "$json" ".text"                        -> jq -r '.text // ""'
#   json_get "$json" ".tool.input.file_path" "null" -> jq -r '.tool.input.file_path // "null"'
json_get() {
    local json="$1"
    local key="$2"
    local fallback="${3:-}"
    echo "$json" | "$PYTHON" -c "
import json, sys
try:
    data = json.load(sys.stdin)
    keys = sys.argv[1].lstrip('.').split('.')
    val = data
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k)
        else:
            val = None
            break
    if val is None:
        print(sys.argv[2] if len(sys.argv) > 2 else '')
    else:
        print(val)
except:
    print(sys.argv[2] if len(sys.argv) > 2 else '')
" "$key" "$fallback" 2>/dev/null
}

# json_valid <json_string>
# Returns 0 if valid JSON, 1 otherwise.
json_valid() {
    echo "$1" | "$PYTHON" -c "import json,sys; json.load(sys.stdin)" 2>/dev/null
}

# json_encode_context <message>
# Outputs {"additionalContext": "<message>"} with proper JSON escaping.
json_encode_context() {
    "$PYTHON" -c "
import json, sys
msg = sys.stdin.read()
print(json.dumps({'additionalContext': msg}))
" <<< "$1"
}
