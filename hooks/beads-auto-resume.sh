#!/usr/bin/env bash
set -euo pipefail

# On session start, check for in-progress or ready beads work and surface it.
# This replaces the auto-resume step that was in workflow-orchestrator Phase 1.

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

# If nothing found, skip
if [ -z "$in_progress" ] && [ -z "$ready" ]; then
  echo '{}'
  exit 0
fi

# Build context message
msg="# Beads Auto-Resume

Existing work detected in this project.
"

if [ -n "$in_progress" ]; then
  msg+="
## In-Progress Work
\`\`\`
${in_progress}
\`\`\`
"
fi

if [ -n "$ready" ]; then
  msg+="
## Ready to Start
\`\`\`
${ready}
\`\`\`
"
fi

msg+="
**IMPORTANT:** Before starting new work, ask the user: \"Found existing work. Want to continue one of these, or start something new?\""

# Use python to safely JSON-encode the message
python3 -c "
import json, sys
msg = sys.stdin.read()
print(json.dumps({'additionalContext': msg}))
" <<< "$msg"
