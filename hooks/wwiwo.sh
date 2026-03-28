#!/usr/bin/env bash
set -euo pipefail

# "What Was I Working On?" — triggered by typing "wwiwo?" in the prompt.
# Shows in-progress, ready, and recently closed beads work.

# Skip if beads not initialized
if [ ! -d ".beads" ]; then
  python3 -c "
import json
print(json.dumps({'additionalContext': 'No .beads/ directory in this project. Run \`bd init\` to set up issue tracking.'}))
"
  exit 0
fi

# Gather work status
in_progress=$(bd list --status in_progress 2>/dev/null || true)
ready=$(bd ready 2>/dev/null || true)
recent=$(bd list --status closed 2>/dev/null | head -10 || true)

# Strip empty responses
[[ "$in_progress" == *"No issues found"* ]] && in_progress=""
[[ "$ready" == *"No open issues"* ]] && ready=""
[[ "$ready" == *"Ready: 0"* ]] && ready=""
[[ "$recent" == *"No issues found"* ]] && recent=""

# Build context message
msg="# What Was I Working On?
"

if [ -n "$in_progress" ]; then
  msg+="
## In Progress
\`\`\`
${in_progress}
\`\`\`
"
fi

if [ -n "$ready" ]; then
  msg+="
## Ready to Start (no blockers)
\`\`\`
${ready}
\`\`\`
"
fi

if [ -n "$recent" ]; then
  msg+="
## Recently Closed
\`\`\`
${recent}
\`\`\`
"
fi

if [ -z "$in_progress" ] && [ -z "$ready" ] && [ -z "$recent" ]; then
  msg+="
No in-progress, ready, or recently closed work found in this project.
"
fi

msg+="
**Present this to the user in a clear, readable format. If there is in-progress or ready work, ask which one they want to pick up.**"

python3 -c "
import json, sys
msg = sys.stdin.read()
print(json.dumps({'additionalContext': msg}))
" <<< "$msg"
