#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook for Agent tool.
# Detects when the Continuous Verifier agent is dispatched and
# injects a visible context message so the user knows it's running.

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

# Extract the agent prompt
prompt=$("$PYTHON" -c "
import json, sys
try:
    data = json.load(sys.stdin)
    # Try multiple paths for the prompt field
    for path in [
        lambda d: d['tool']['input']['prompt'],
        lambda d: d['tool_input']['prompt'],
        lambda d: d.get('input', {}).get('prompt', ''),
    ]:
        try:
            val = path(data)
            if val:
                print(val)
                sys.exit(0)
        except (KeyError, TypeError):
            continue
    print('')
except:
    print('')
" <<< "$tool_use_json" 2>/dev/null)

# Only fire for Continuous Verifier prompts
if ! echo "$prompt" | grep -q "CONTINUOUS VERIFIER"; then
    echo '{}'
    exit 0
fi

# Extract task and epic IDs from the prompt
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

json_encode_context "CONTINUOUS VERIFIER DISPATCHED for task ${task_id} (epic ${epic_id}). Review of 5 dimensions in progress: correctness, consistency, edge cases, integration, dead weight."
