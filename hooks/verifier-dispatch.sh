#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook for Agent tool.
# Detects when the Continuous Verifier agent is dispatched and
# injects a visible context message so the user knows it's running.
#
# ID extraction (evaluation H2): the build SKILL.md dispatch template carries
# machine markers:
#   SPEC: specs/<slug>.md
#   TASK: <bead-id>
#   EPIC: <bead-id>
# where <bead-id> matches [a-z]+-[a-z0-9]{2,} (real beads IDs like
# workflow-4f2a — not the retired bd-\d+ shape). The old 'Task:'/'Epic:'
# bd-\d+ regexes are kept as fallback for legacy prompts.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Advisory hook: exit quietly when python is unavailable (fail-open per E6).
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

# Extract task and epic IDs from the machine markers (TASK:/EPIC:), falling
# back to the legacy Task:/Epic: bd-\d+ shapes.
ids=$("$PYTHON" -c "
import re, sys
prompt = sys.stdin.read()
task = re.search(r'^TASK:\s*([a-z]+-[a-z0-9]{2,})\b', prompt, re.MULTILINE) \
    or re.search(r'Task:\s*(bd-\d+)', prompt)
epic = re.search(r'^EPIC:\s*([a-z]+-[a-z0-9]{2,})\b', prompt, re.MULTILINE) \
    or re.search(r'Epic:\s*(bd-\d+)', prompt)
task_id = task.group(1) if task else 'unknown'
epic_id = epic.group(1) if epic else 'unknown'
print(f'{task_id}|{epic_id}')
" <<< "$prompt" 2>/dev/null)

task_id="${ids%%|*}"
epic_id="${ids##*|}"

# Track in-flight verifier so block-status-during-verification.sh can detect
# attempts to write @status(verified) before the verifier returns.
# State is session+project keyed (evaluation H5).
INFLIGHT_FILE="$(state_dir "$tool_use_json")/verifier-inflight.txt"
# Extract spec slug: SPEC: specs/<slug>.md machine marker first, then any
# specs/<slug>.md mention (legacy prompts pasted spec contents, not paths).
spec_slug=$("$PYTHON" -c "
import re, sys
prompt = sys.stdin.read()
m = re.search(r'^SPEC:\s*specs/([a-z0-9_-]+)\.md', prompt, re.MULTILINE) \
    or re.search(r'specs/([a-z0-9_-]+)\.md', prompt)
print(m.group(1) if m else '')
" <<< "$prompt" 2>/dev/null)
printf '%s|%s|%s\n' "$task_id" "$epic_id" "$spec_slug" >> "$INFLIGHT_FILE"

json_encode_context "CONTINUOUS VERIFIER DISPATCHED for task ${task_id} (epic ${epic_id}). Review of 5 dimensions in progress: correctness, consistency, edge cases, integration, dead weight." "PreToolUse"
