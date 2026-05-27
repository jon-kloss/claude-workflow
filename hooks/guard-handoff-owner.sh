#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write of specs/handoffs/<step>-<slug>-<role>.html when no dispatch
# to <role> has been logged in this session (~/.claude/hooks/state/session-agents.log).
#
# 2026-05-27 SquashBuckler dogfood caught: when require-handoff-artifact.sh
# blocked on a missing frontend-engineer handoff, the orchestrator wrote the
# handoff itself ("creating the missing consolidated frontend handoff") instead
# of dispatching the agent. The handoff file is the role agent's deliverable,
# not the orchestrator's — the agent's reasoning is the load-bearing artifact.
#
# track-agents.sh (PostToolUse Agent hook) logs every dispatch to the same
# session log this hook reads; if a dispatch fired, this hook allows the write.
#
# Override: @handoff-author-skip(<role>: <reason>) in the handoff content.
# Legitimate use case: subagent inline-synthesis fallback when running without
# the Agent tool (per CLAUDE.md role-agent-system note).
#
# Runs as PreToolUse hook on Edit/Write.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

AGENTS_FILE="${HOME}/.claude/hooks/state/session-agents.log"

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

# Only intercept specs/handoffs/*.html
if [[ "$file_path" != */specs/handoffs/*.html ]]; then
    echo '{}'
    exit 0
fi

basename_file=$(basename "$file_path")

# Extract role from filename. Filename convention:
#   step-<step>-<slug>-<role>.html
#   step-<step>-<slug>-<role>-fix-cycle-N.html
#   step-<step>-<slug>-<role>-cycle-N.html
#
# Roles can contain hyphens (e.g. "backend-engineer"), so we can't just take
# the last hyphen-separated component. We match the known role set.

KNOWN_ROLES="product-owner application-architect security-architect devops-architect data-architect uiux-designer backend-engineer frontend-engineer qa-engineer release-coordinator spec-sre-auditor game-designer level-designer narrative-designer systems-designer game-ui-designer"

stripped="${basename_file%.html}"
# Strip cycle suffix (-fix-cycle-N or -cycle-N)
stripped=$(echo "$stripped" | sed -E 's/-(fix-cycle|cycle)-[0-9]+$//')

role=""
for r in $KNOWN_ROLES; do
    if [[ "$stripped" == *"-${r}" ]]; then
        role="$r"
        break
    fi
done

if [ -z "$role" ]; then
    # Unknown role — handoff might use a new role not yet registered. Allow.
    echo '{}'
    exit 0
fi

# Override check: @handoff-author-skip(<role>: ...) in new content OR existing file
new_content=$(json_get "$tool_use_json" ".tool.input.new_string" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.new_string" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool.input.content" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.content" "")

existing_content=""
if [ -f "$file_path" ]; then
    existing_content="$(cat "$file_path" 2>/dev/null || echo "")"
fi
combined="${existing_content} ${new_content}"

if echo "$combined" | grep -qE "@handoff-author-skip\(${role}:[^)]+\)"; then
    echo '{}'
    exit 0
fi

# Check session log for a dispatch to this role
dispatch_found="no"
if [ -f "$AGENTS_FILE" ]; then
    if awk -F'|' -v r="$role" '$2 == r {print; exit}' "$AGENTS_FILE" 2>/dev/null | grep -q .; then
        dispatch_found="yes"
    fi
fi

if [ "$dispatch_found" = "yes" ]; then
    echo '{}'
    exit 0
fi

# No dispatch logged + no override => block
project_relative="${file_path}"
if [ -n "${PWD:-}" ] && [[ "$file_path" == "$PWD"/* ]]; then
    project_relative="${file_path#$PWD/}"
fi

cat >&2 <<EOF
BLOCKED: ${project_relative} belongs to the '${role}' agent, but no dispatch to that agent has been logged in this session.

The handoff file is the role agent's DELIVERABLE, not the orchestrator's. The agent's reasoning is the load-bearing artifact; orchestrator-synthesized handoffs reproduce structure without substance. This is the recurring failure mode (2026-05-27 dogfood — orchestrator wrote a missing handoff itself after require-handoff-artifact.sh blocked on it).

Correct response:
  Agent(subagent_type: ${role}, prompt: 'You are running [step] for spec [slug]. Read [inputs]. Produce handoff at ${project_relative}. Per your Exit checklist, write the handoff as your terminal step.')

The agent's Exit checklist makes handoff-write its last action; the parent session's track-agents.sh hook logs the dispatch, after which this hook allows the write.

To override (legitimate inline-synthesis fallback — e.g. you ARE running as a subagent that lacks the Agent tool):
  Include @handoff-author-skip(${role}: <concise reason>) in the handoff content. Reason persists as audit trail.
EOF
exit 2
