#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook for Agent tool.
# Detects when the Continuous Verifier agent returns, extracts the verdict,
# logs the full result as a bd comment on the task, and injects a summary.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

# Extract prompt and result from the tool event
read_result=$("$PYTHON" -c "
import json, sys

data = json.load(sys.stdin)

# Extract prompt (try multiple paths)
prompt = ''
for path in [
    lambda d: d['tool']['input']['prompt'],
    lambda d: d['tool_input']['prompt'],
    lambda d: d.get('input', {}).get('prompt', ''),
]:
    try:
        val = path(data)
        if val:
            prompt = val
            break
    except (KeyError, TypeError):
        continue

# Extract result (try multiple paths)
result = ''
for path in [
    lambda d: d['tool_result'],
    lambda d: d['tool']['result'],
    lambda d: d['result'],
    lambda d: d.get('output', ''),
]:
    try:
        val = path(data)
        if val:
            if isinstance(val, dict):
                result = json.dumps(val)
            else:
                result = str(val)
            break
    except (KeyError, TypeError):
        continue

# Output as two-part delimiter-separated string
print(prompt)
print('---HOOK_DELIM---')
print(result)
" <<< "$tool_use_json" 2>/dev/null)

prompt="${read_result%%---HOOK_DELIM---*}"
result="${read_result#*---HOOK_DELIM---}"
# Trim leading newline from result
result="${result#$'\n'}"

# Only fire for Continuous Verifier prompts
if ! echo "$prompt" | grep -q "CONTINUOUS VERIFIER"; then
    echo '{}'
    exit 0
fi

# Extract task and epic IDs
ids=$("$PYTHON" -c "
import re, sys
prompt = sys.stdin.read()
task = re.search(r'Task:\s*(bd-\d+)', prompt)
epic = re.search(r'Epic:\s*(bd-\d+)', prompt)
task_id = task.group(1) if task else 'unknown'
epic_id = epic.group(1) if epic else 'unknown'
print(f'{task_id}|{epic_id}')
" <<< "$prompt" 2>/dev/null)

task_id="${ids%%|*}"
epic_id="${ids##*|}"

# Extract verdict from result
verdict="UNKNOWN"
if [ -n "$result" ]; then
    verdict=$("$PYTHON" -c "
import re, sys
result = sys.stdin.read()
m = re.search(r'VERIFIER\s+\S+:\s*(PASS_WITH_NOTES|PASS|FAIL)', result)
print(m.group(1) if m else 'UNKNOWN')
" <<< "$result" 2>/dev/null)
fi

# Log to bd as a comment on the task
logged="false"
if [ "$task_id" != "unknown" ] && command -v bd &> /dev/null; then
    # Truncate result for bd comment (max ~2000 chars to avoid arg length issues)
    comment=$("$PYTHON" -c "
import sys
task_id = sys.argv[1]
verdict = sys.argv[2]
result = sys.stdin.read().strip()
if len(result) > 2000:
    result = result[:2000] + '\n... (truncated)'
if not result:
    result = '(no result captured from agent)'
print(f'CONTINUOUS VERIFIER RESULT for {task_id}:\nVerdict: {verdict}\n\n{result}')
" "$task_id" "$verdict" <<< "$result" 2>/dev/null)

    if bd comment "$task_id" "$comment" 2>/dev/null; then
        logged="true"
    fi
fi

# Build context message
if [ "$logged" = "true" ]; then
    msg="CONTINUOUS VERIFIER RETURNED for task ${task_id}: ${verdict}. Full result logged as bd comment on ${task_id}."
elif [ -n "$result" ]; then
    msg="CONTINUOUS VERIFIER RETURNED for task ${task_id}: ${verdict}. WARNING: Failed to log to bd — you must manually run: bd comment ${task_id} \"<verifier result>\""
else
    msg="CONTINUOUS VERIFIER RETURNED for task ${task_id}: ${verdict}. WARNING: Could not capture agent result — you must manually log the verifier output as a bd comment on ${task_id}."
fi

json_encode_context "$msg"
