#!/usr/bin/env bash
set -euo pipefail

# Detect code-change requests and inject workflow-orchestrator reminder.
# Uses simple keyword matching - fast and deterministic.
# Runs on UserPromptSubmit.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Read prompt from stdin
if ! read -t 2 -r prompt_json; then
    echo '{}'
    exit 0
fi

# Extract prompt text
prompt_text=$(json_get "$prompt_json" ".text")

if [ -z "$prompt_text" ]; then
    echo '{}'
    exit 0
fi

# Convert to lowercase for matching
lower_text=$(echo "$prompt_text" | tr '[:upper:]' '[:lower:]')

# Skip if this is a slash command or continuation command
if echo "$lower_text" | grep -qE '^(/|continue|yes|go|ok|proceed|looks good|lgtm|y$)'; then
    echo '{}'
    exit 0
fi

# Detect code-change intent via keywords
is_code_change=false

# Action verbs that indicate code changes
if echo "$lower_text" | grep -qE '(add|create|build|implement|fix|refactor|update|change|modify|remove|delete|rename|move|extract|write|develop|make|set up|integrate|configure|migrate|convert|upgrade|replace|rewrite)'; then
    # Confirm it's about code/features (not questions)
    if echo "$lower_text" | grep -qE '(feature|function|endpoint|component|page|module|class|method|api|route|test|bug|error|issue|service|model|schema|database|config|hook|skill|file|code|app|button|form|table|view|controller|middleware|plugin|server|client)'; then
        is_code_change=true
    fi
fi

# Direct indicators
if echo "$lower_text" | grep -qE '(can you (add|create|fix|build|implement|write|make)|i need|i want|please (add|create|fix|build)|let.s (add|create|fix|build))'; then
    is_code_change=true
fi

if [ "$is_code_change" = true ]; then
    echo '{"additionalContext": "\n[WORKFLOW] Use the workflow-orchestrator skill to classify this task (Quick/Standard/Complex) and follow the 5-phase workflow: Classify -> Plan (beads) -> Investigate -> Implement (TDD) -> Verify (full suite).\n"}'
else
    echo '{}'
fi
