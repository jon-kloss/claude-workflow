#!/usr/bin/env bash
set -euo pipefail

# Block @status(verified) writes and bd close/update --status commands while a
# CONTINUOUS VERIFIER is in-flight (dispatched but not yet returned).
#
# Enforces the build SKILL.md rule "Never update status while verification is
# in flight" (see the Continuous Verifier section) deterministically. Prevents
# the "credit pressure → just write the status before the verifier returns"
# rationalization.
#
# Paired with: verifier-dispatch.sh (appends to <state>/verifier-inflight.txt)
# and verifier-return.sh (removes from <state>/verifier-inflight.txt), where
# <state> is the session+project-keyed directory from _common.sh state_dir().
#
# Runs as PreToolUse hook on Edit/Write and Bash.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Gate hook, but its state is written by advisory trackers that fail open —
# with no python there can be no tracked in-flight verifier, so exit quietly.
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

INFLIGHT_FILE="$(state_dir "$tool_use_json")/verifier-inflight.txt"

# Fast path: no in-flight file or it's empty → nothing to enforce
if [ ! -s "$INFLIGHT_FILE" ]; then
    echo '{}'
    exit 0
fi

tool_name=$(json_get "$tool_use_json" ".tool.name" "")
if [ -z "$tool_name" ]; then
    tool_name=$(json_get "$tool_use_json" ".tool_name" "")
fi

# Build a human-readable summary of in-flight verifiers for error messages
inflight_summary=$(awk -F'|' '{ printf "  task=%s epic=%s spec=%s\n", $1, $2, $3 }' "$INFLIGHT_FILE")

case "$tool_name" in
    "Edit"|"Write")
        file_path=$(json_get "$tool_use_json" ".tool.input.file_path" "")
        [ -z "$file_path" ] && file_path=$(json_get "$tool_use_json" ".tool_input.file_path" "")

        # Only care about spec files
        if [[ "$file_path" != */specs/*.md ]]; then
            echo '{}'
            exit 0
        fi

        new_content=$(json_get "$tool_use_json" ".tool.input.new_string" "")
        [ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.new_string" "")
        [ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool.input.content" "")
        [ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.content" "")

        # Only block @status(verified) writes
        if ! echo "$new_content" | grep -q "@status(verified)"; then
            echo '{}'
            exit 0
        fi

        basename_file=$(basename "$file_path")
        slug="${basename_file%.md}"

        # If this spec has an in-flight verifier, block. If a different spec is
        # in flight, allow — that's a separate concern.
        if grep -q "|${slug}\$" "$INFLIGHT_FILE" 2>/dev/null; then
            cat >&2 <<EOF
BLOCKED: Writing @status(verified) to specs/${slug}.md while a CONTINUOUS VERIFIER for this spec is in-flight (dispatched but not returned).

In-flight verifiers:
${inflight_summary}

Wait for the verifier to return before updating status. If the verifier returns FAIL, do not write @status(verified) — fix the failure first.
EOF
            exit 2
        fi
        ;;

    "Bash")
        cmd=$(json_get "$tool_use_json" ".tool.input.command" "")
        [ -z "$cmd" ] && cmd=$(json_get "$tool_use_json" ".tool_input.command" "")

        # Match bd close / bd update ... --status only in COMMAND position
        # (start of command, or after && ; | or a subshell open paren) — a
        # mention inside an echo string must not fire (evaluation H15).
        if ! echo "$cmd" | grep -qE '(^|[;&|(])[[:space:]]*bd[[:space:]]+(close[[:space:]]|close$|update[[:space:]]+[^[:space:]]+[[:space:]]+--status)'; then
            echo '{}'
            exit 0
        fi

        # Extract task IDs from the command. {3,} not {3}: IDs are 3+ chars
        # after the prefix (workflow-4f2a) — an exactly-3 match truncated
        # real IDs and never matched the inflight file (evaluation H3).
        task_ids=$(echo "$cmd" | grep -oE '[a-z]+-[a-z0-9]{3,}' | sort -u || true)

        # For each task id in the command, check if it has an in-flight verifier
        blocked_ids=""
        for tid in $task_ids; do
            if grep -q "^${tid}|" "$INFLIGHT_FILE" 2>/dev/null; then
                blocked_ids="${blocked_ids}${tid} "
            fi
        done

        if [ -n "$blocked_ids" ]; then
            cat >&2 <<EOF
BLOCKED: Cannot close or update --status on tasks with in-flight CONTINUOUS VERIFIER: ${blocked_ids}

In-flight verifiers:
${inflight_summary}

Wait for the verifier to return before closing or updating status. Status writes before verification completes are the documented 'credit pressure' failure pattern this hook exists to catch.
EOF
            exit 2
        fi
        ;;
esac

echo '{}'
