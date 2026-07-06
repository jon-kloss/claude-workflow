#!/usr/bin/env bash
set -euo pipefail

# Detect user corrections to Claude's approach and prompt incident logging.
# Matches correction phrases in user messages and injects context telling
# Claude to ask about logging a workflow incident for the next retrospective.
# Runs on UserPromptSubmit.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Advisory hook: exit quietly when python is unavailable (fail-open per E6).
if [ -z "${PYTHON:-}" ]; then
    exit 0
fi

# Read prompt from stdin
if ! read -t 2 -r prompt_json; then
    echo '{}'
    exit 0
fi

# Extract prompt text. UserPromptSubmit payload field is `prompt`
# (docs/harness-behavior.md fact 4); `.text` kept as legacy fallback.
prompt_text=$(json_get "$prompt_json" ".prompt")
[ -z "$prompt_text" ] && prompt_text=$(json_get "$prompt_json" ".text")

if [ -z "$prompt_text" ]; then
    echo '{}'
    exit 0
fi

# Convert to lowercase for matching
lower_text=$(echo "$prompt_text" | tr '[:upper:]' '[:lower:]')

# Skip slash commands, confirmations, and skill invocations
if echo "$lower_text" | grep -qE '^(/|continue|yes|go|ok|proceed|looks good|lgtm|y$|ready|build|design|wwiwo)'; then
    echo '{}'
    exit 0
fi

# Detect correction patterns
is_correction=false

# Explicit correction phrases
if echo "$lower_text" | grep -qE '(this should(n.t| not| never) happen|should never happen|don.t do that|stop doing|that.s wrong|that is wrong|no,? (don.t|stop|never|not like)|you should(n.t| not) have|why did you|why are you|i told you|i said (don.t|not to|stop)|this is wrong|that.s not (right|correct|what)|never do (this|that))'; then
    is_correction=true
fi

# Negation + action patterns (user rejecting Claude's approach)
if echo "$lower_text" | grep -qE '(no[,.]? (we|you|it|that|this) (should|need|must|can.t|shouldn.t|don.t)|wrong approach|not what i (asked|meant|wanted)|that.s not how|you (missed|skipped|forgot|ignored)|this (breaks|broke|fails|failed))'; then
    is_correction=true
fi

if [ "$is_correction" = true ]; then
    # Check if beads is initialized (needed for logging)
    has_beads=false
    if [ -d ".beads" ]; then
        has_beads=true
    fi

    # Find active epic for logging target
    epic_id=""
    if [ "$has_beads" = true ]; then
        epic_line=$(bd list --status open --type epic 2>/dev/null | head -1 || true)
        if [ -n "$epic_line" ]; then
            epic_id=$(echo "$epic_line" | awk '{print $2}')
        fi
        # Also check in_progress epics
        if [ -z "$epic_id" ]; then
            epic_line=$(bd list --status in_progress --type epic 2>/dev/null | head -1 || true)
            if [ -n "$epic_line" ]; then
                epic_id=$(echo "$epic_line" | awk '{print $2}')
            fi
        fi
    fi

    msg="[WORKFLOW INCIDENT DETECTED] The user's message looks like a correction to your approach. This may be a workflow incident worth logging for the next retrospective.

**Action required:** After addressing the user's correction, ask via AskUserQuestion:
\"Should I log this as a workflow incident for the next retro?\"

If the user confirms, log a structured comment using:
\`\`\`
bd comments add ${epic_id:-<epic-id>} \"WORKFLOW INCIDENT: [short description]

Category: [skill-gap | missing-rule | wrong-default | edge-case | process-violation]
Skill: [design | build | retrospective | hook-name | none]
What happened: [what you did wrong]
What should have happened: [correct behavior]
User correction: [what the user said]
Proposed fix: [optional — if the fix is obvious]\"
\`\`\`"

    if [ -z "$epic_id" ] && [ "$has_beads" = true ]; then
        msg+="

**No active epic found.** If the user confirms logging, create or reuse a dedicated \`workflow-incidents\` issue:
\`bd create --title=\"Workflow Incidents\" --type=task --description=\"Collects workflow incidents when no epic is active. Retrospective reads these.\"\`"
    fi

    if [ "$has_beads" != true ]; then
        msg+="

**Beads not initialized.** Cannot log incident. Note the correction and suggest the user run \`bd init\` if they want incident tracking."
    fi

    json_encode_context "$msg" "UserPromptSubmit"
else
    echo '{}'
fi
