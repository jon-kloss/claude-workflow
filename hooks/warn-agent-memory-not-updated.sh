#!/usr/bin/env bash
set -euo pipefail

# PostToolUse Agent hook: when a role-agent dispatch returns, compare the
# memory file's current mtime to the baseline recorded by
# track-agent-memory-baseline.sh. If unchanged, emit a warning via
# json_encode_context so the next conversation turn sees that the agent
# returned without completing its Exit checklist step 2 (update memory).
#
# WARN mode (not block). Memory has legitimate "nothing new" cases — a
# trivial spec or one-line fix might produce no real delta. Surfacing the
# gap inline lets the orchestrator decide whether to re-dispatch or accept.
# If warns are routinely ignored over time, this can be escalated to block
# at the @status(verified) edit point.
#
# Override: @memory-update-skip(<role>: <reason>) anywhere in the dispatched
# agent's prompt. Documents the intentional no-update case as audit trail.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Advisory hook (WARN mode): exit quietly when python is unavailable.
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

subagent_type=$(json_get "$tool_use_json" ".tool.input.subagent_type" "")
if [ -z "$subagent_type" ]; then
    subagent_type=$(json_get "$tool_use_json" ".tool_input.subagent_type" "")
fi

if [ -z "$subagent_type" ]; then
    echo '{}'
    exit 0
fi

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

memory_file="${PWD}/.claude/agent-memory/${subagent_type}.md"

if [ ! -f "$memory_file" ]; then
    # No memory file at all → /onboard not run for this role. Skip silently.
    echo '{}'
    exit 0
fi

# Session+project-keyed state (evaluation H5) — same key as the PreToolUse
# baseline hook, since subagents inherit the parent session_id (fact 11).
baseline_file="$(state_dir "$tool_use_json")/agent-memory-baseline-${subagent_type}.txt"

if [ ! -f "$baseline_file" ]; then
    # No baseline recorded (PreToolUse hook didn't fire, or first dispatch
    # before the hook landed) — skip silently rather than false-warn.
    echo '{}'
    exit 0
fi

baseline_mtime=$(cat "$baseline_file" 2>/dev/null || echo "")
current_mtime=$(stat -f '%m' "$memory_file" 2>/dev/null || stat -c '%Y' "$memory_file" 2>/dev/null || echo "")

if [ -z "$baseline_mtime" ] || [ -z "$current_mtime" ]; then
    echo '{}'
    exit 0
fi

if [ "$current_mtime" != "$baseline_mtime" ]; then
    # Memory was updated — happy path
    echo '{}'
    exit 0
fi

# Memory unchanged. Check override.
prompt=$(json_get "$tool_use_json" ".tool.input.prompt" "")
if [ -z "$prompt" ]; then
    prompt=$(json_get "$tool_use_json" ".tool_input.prompt" "")
fi

if echo "$prompt" | grep -qE "@memory-update-skip\(${subagent_type}:[^)]+\)"; then
    # Validate the override reason quality
    override_reason=$(echo "$prompt" | grep -oE "@memory-update-skip\(${subagent_type}:[^)]+\)" | head -1 | sed -E "s/@memory-update-skip\(${subagent_type}:[[:space:]]*//; s/\)$//")
    VALIDATOR="$HOOK_DIR/_validate_override_reason.py"
    if [ -f "$VALIDATOR" ]; then
        if ! validation_error=$("$PYTHON" "$VALIDATOR" "warn-agent-memory-not-updated" "@memory-update-skip" "$subagent_type" "$override_reason" 2>&1); then
            # WARN mode: don't block; surface the bad-override attempt as a warning
            msg="WARNING: ${subagent_type} dispatch returned without updating memory AND the @memory-update-skip override reason did not meet quality requirements.

Override validation error: ${validation_error}

Provided reason: '${override_reason}'

Either update the memory file per the Exit checklist, or re-dispatch with a more specific @memory-update-skip reason (must include a concrete artifact reference — beads ID, commit SHA, file path, URL, or user authorization)."
            json_encode_context "$msg" "PostToolUse"
            exit 0
        fi
    fi
    # Documented skip with a valid reason
    echo '{}'
    exit 0
fi

# Build the warning context
msg="WARNING: ${subagent_type} dispatch returned but .claude/agent-memory/${subagent_type}.md was not modified during this dispatch. The Exit checklist in agents/${subagent_type}.md names memory-update as a TERMINAL step (after writing the handoff, before returning the verbal confirmation). Minimum required per dispatch: one Recent-changes entry + bumped last-updated / last-commit-sha frontmatter.

If the dispatch genuinely had no memory delta (e.g. @trivial spec, one-line fix the role has already documented), re-dispatch this agent with @memory-update-skip(${subagent_type}: <reason>) in the prompt to document the intentional no-update — that suppresses this warning AND preserves the audit trail.

Otherwise: re-dispatch the agent with: 'Your prior dispatch returned without updating .claude/agent-memory/${subagent_type}.md. Per your Exit checklist step 2, append to Recent changes and bump frontmatter timestamps. The verbal confirmation is not the deliverable — the artifact is.'"

json_encode_context "$msg" "PostToolUse"
exit 0
