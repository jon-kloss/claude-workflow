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

# require_python_or_block <hook-name>
# Fail-closed policy for gate hooks (decision D9 / E6 in
# docs/decisions/0001-enforcement-architecture.md): when no Python 3 is
# available, a require-*/guard-* hook cannot parse its payload or validate
# override reasons — allowing the tool call would silently disarm enforcement.
# Block with a readable message instead. Advisory hooks should NOT call this;
# they exit 0 quietly when $PYTHON is empty.
require_python_or_block() {
    if [ -z "${PYTHON:-}" ]; then
        cat >&2 <<EOF
BLOCKED: ${1:-workflow gate hook} cannot run — no working Python 3 interpreter found (tried: python3, python).

This is an enforcement (require-*/guard-*) hook. Running without Python would silently disable the gate, so it fails CLOSED by policy (docs/decisions/0001-enforcement-architecture.md, E6).

Fix: install Python 3 or repair PATH, then retry the tool call.
EOF
        exit 2
    fi
}

# state_dir <hook-payload-json>
# Print (and create) the session+project-keyed hook state directory:
#   ~/.claude/hooks/state/<12-hex sha1 of cwd>/<session_id>/
# Keying rationale (docs/harness-behavior.md facts 9-11): session_id and cwd
# are present in every hook payload, and subagents INHERIT the parent
# session's session_id (verified 2026-07-05, fact 11) — so state written by
# orchestrator-side hooks is visible to hooks firing inside subagent tool
# calls, and concurrent sessions / different projects can no longer clobber
# each other (evaluation H5).
# Fallbacks: cwd -> $PWD; session_id -> "no-session".
# NOTE: override-audit.log intentionally does NOT live here — it is a
# cross-session ledger by design and stays global at ~/.claude/hooks/state/.
state_dir() {
    local payload="${1:-}"
    local base="${HOME}/.claude/hooks/state"
    local cwd="" session="" hash=""
    if [ -n "$payload" ] && [ -n "${PYTHON:-}" ]; then
        cwd=$(json_get "$payload" ".cwd" "")
        session=$(json_get "$payload" ".session_id" "")
    fi
    [ -z "$cwd" ] && cwd="${PWD:-/}"
    [ -z "$session" ] && session="no-session"
    if [ -n "${PYTHON:-}" ]; then
        hash=$("$PYTHON" -c "import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode('utf-8')).hexdigest()[:12])" "$cwd" 2>/dev/null || echo "nohash")
        [ -z "$hash" ] && hash="nohash"
    else
        hash="nohash"
    fi
    local dir="${base}/${hash}/${session}"
    mkdir -p "$dir" 2>/dev/null || true
    printf '%s\n' "$dir"
}

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

# json_get_text <json_string> <dotted-key> [fallback]
# Like json_get, but when the resolved value is a dict or list it prints it
# as JSON text (json_get would print a Python repr, which breaks grep-based
# whole-value searches). Use for dict-valued payload fields — notably the
# PostToolUse `tool_response` field, which for Bash is a dict
# {stdout, stderr, interrupted, isImage, noOutputExpected}
# (docs/harness-behavior.md fact 8). Dotted paths also extract subfields:
#   json_get_text "$json" ".tool_response.stdout"
json_get_text() {
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
    elif isinstance(val, (dict, list)):
        print(json.dumps(val))
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

# json_encode_context <message> <hook_event_name>
# Outputs {"hookSpecificOutput": {"hookEventName": ..., "additionalContext": ...}}
# with proper JSON escaping. The wrapper is REQUIRED: a top-level
# {"additionalContext": ...} object is silently dropped by the harness
# (docs/harness-behavior.md fact 6). Pass the event this hook is registered
# on: UserPromptSubmit, PreToolUse, PostToolUse, SessionStart, Stop.
json_encode_context() {
    local event="${2:-UserPromptSubmit}"
    "$PYTHON" -c "
import json, sys
msg = sys.stdin.read()
print(json.dumps({'hookSpecificOutput': {'hookEventName': sys.argv[1], 'additionalContext': msg}}))
" "$event" <<< "$1"
}
