#!/usr/bin/env bash
set -euo pipefail

# On session start, check for in-progress or ready beads work and spec status.
# Surfaces both beads tasks and Gherkin spec statuses.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Skip if beads not initialized in this project
if [ ! -d ".beads" ]; then
  echo '{}'
  exit 0
fi

# Gather in-progress and ready work
in_progress=$(bd list --status in_progress 2>/dev/null || true)
ready=$(bd ready 2>/dev/null || true)

# Strip empty responses (bd outputs various "nothing here" messages)
[[ "$in_progress" == *"No issues found"* ]] && in_progress=""
[[ "$ready" == *"No open issues"* ]] && ready=""
[[ "$ready" == *"Ready: 0"* ]] && ready=""

# Check for Gherkin specs
spec_status=""
if [ -d "specs" ]; then
  approved=$(grep -rl '@status(approved)' specs/ 2>/dev/null | sort || true)
  implemented=$(grep -rl '@status(implemented)' specs/ 2>/dev/null | sort || true)
  draft=$(grep -rl '@status(draft)' specs/ 2>/dev/null | sort || true)
  if [ -n "$approved" ] || [ -n "$implemented" ] || [ -n "$draft" ]; then
    spec_status="found"
  fi
fi

# If nothing found, skip
if [ -z "$in_progress" ] && [ -z "$ready" ] && [ -z "$spec_status" ]; then
  echo '{}'
  exit 0
fi

# Build context message
msg="# Work Auto-Resume

Existing work detected in this project.
"

if [ -n "$in_progress" ]; then
  msg+="
## In-Progress Beads Tasks
\`\`\`
${in_progress}
\`\`\`
"
fi

if [ -n "$ready" ]; then
  msg+="
## Ready Beads Tasks
\`\`\`
${ready}
\`\`\`
"
fi

if [ -n "$spec_status" ]; then
  msg+="
## Gherkin Spec Status
"
  if [ -n "$implemented" ]; then
    msg+="**In Progress (use /build to continue):**
"
    while IFS= read -r f; do
      [ -n "$f" ] && msg+="- $f
"
    done <<< "$implemented"
    msg+="
"
  fi
  if [ -n "$approved" ]; then
    msg+="**Approved — Ready to Build (use /build):**
"
    while IFS= read -r f; do
      [ -n "$f" ] && msg+="- $f
"
    done <<< "$approved"
    msg+="
"
  fi
  if [ -n "$draft" ]; then
    msg+="**Draft — Needs Approval (use /design to finalize):**
"
    while IFS= read -r f; do
      [ -n "$f" ] && msg+="- $f
"
    done <<< "$draft"
    msg+="
"
  fi
fi

msg+="
**IMPORTANT:** Before starting new work, ask the user: \"Found existing work. Want to continue one of these, or start something new?\""

json_encode_context "$msg"
