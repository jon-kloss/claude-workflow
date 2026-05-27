#!/usr/bin/env bash
set -euo pipefail

# PreToolUse Agent hook: record the pre-dispatch mtime of the dispatched role
# agent's memory file at .claude/agent-memory/<role>.md.
#
# Paired with warn-agent-memory-not-updated.sh (PostToolUse Agent) which
# compares the post-dispatch mtime to this baseline and warns if unchanged.
#
# Catches the recurring failure mode (2026-05-27): agents return without
# updating their memory file, despite the Exit checklist naming it as a
# terminal step. Same family as the handoff-skip enforcement, but for memory.
#
# State files: ~/.claude/hooks/state/agent-memory-baseline-<role>.txt
# Format: <epoch-mtime>
#
# Skip conditions: subagent_type is not in the known-role-agent set
# (general-purpose, hyperpowers:*, etc. don't have memory files); memory file
# doesn't exist (project hasn't run /onboard).

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

STATE_DIR="${HOME}/.claude/hooks/state"
mkdir -p "$STATE_DIR"

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

subagent_type=$(json_get "$tool_use_json" ".tool.input.subagent_type" "")
if [ -z "$subagent_type" ]; then
    subagent_type=$(json_get "$tool_use_json" ".tool_input.subagent_type" "")
fi

if [ -z "$subagent_type" ]; then
    echo '{}'
    exit 0
fi

# Only track role agents that have memory files
KNOWN_ROLES="product-owner application-architect security-architect devops-architect data-architect uiux-designer backend-engineer frontend-engineer qa-engineer release-coordinator spec-sre-auditor game-designer level-designer narrative-designer systems-designer game-ui-designer"

is_role="no"
for r in $KNOWN_ROLES; do
    if [ "$subagent_type" = "$r" ]; then
        is_role="yes"
        break
    fi
done

if [ "$is_role" != "yes" ]; then
    echo '{}'
    exit 0
fi

# Memory file lives in the orchestrator's cwd
memory_file="${PWD}/.claude/agent-memory/${subagent_type}.md"

if [ ! -f "$memory_file" ]; then
    # /onboard hasn't been run for this role — nothing to baseline
    echo '{}'
    exit 0
fi

# Record current mtime as the baseline. Use stat -f on macOS, stat -c on Linux.
mtime=$(stat -f '%m' "$memory_file" 2>/dev/null || stat -c '%Y' "$memory_file" 2>/dev/null || echo "")

if [ -z "$mtime" ]; then
    echo '{}'
    exit 0
fi

echo "$mtime" > "$STATE_DIR/agent-memory-baseline-${subagent_type}.txt"

echo '{}'
