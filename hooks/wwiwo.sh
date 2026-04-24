#!/usr/bin/env bash
set -euo pipefail

# "What Was I Working On?" — triggered by typing "wwiwo?" in the prompt.
# Shows in-progress, ready, and recently closed beads work + Gherkin spec statuses.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Skip if beads not initialized
if [ ! -d ".beads" ]; then
  json_encode_context 'No .beads/ directory in this project. Run `bd init` to set up issue tracking.'
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

# Check Gherkin spec statuses
spec_section=""
if [ -d "specs" ]; then
  approved=$(grep -rl '@status(approved)' specs/ 2>/dev/null | sort || true)
  implemented=$(grep -rl '@status(implemented)' specs/ 2>/dev/null | sort || true)
  draft=$(grep -rl '@status(draft)' specs/ 2>/dev/null | sort || true)
  verified=$(grep -rl '@status(verified)' specs/ 2>/dev/null | sort || true)

  if [ -n "$approved" ] || [ -n "$implemented" ] || [ -n "$draft" ] || [ -n "$verified" ]; then
    spec_section="
## Gherkin Specs
"
    if [ -n "$implemented" ]; then
      spec_section+="**In Progress:**
"
      while IFS= read -r f; do
        [ -n "$f" ] && spec_section+="- $f
"
      done <<< "$implemented"
      spec_section+="
"
    fi
    if [ -n "$approved" ]; then
      spec_section+="**Approved (ready for /build):**
"
      while IFS= read -r f; do
        [ -n "$f" ] && spec_section+="- $f
"
      done <<< "$approved"
      spec_section+="
"
    fi
    if [ -n "$draft" ]; then
      spec_section+="**Draft (needs /design):**
"
      while IFS= read -r f; do
        [ -n "$f" ] && spec_section+="- $f
"
      done <<< "$draft"
      spec_section+="
"
    fi
    if [ -n "$verified" ]; then
      spec_section+="**Verified (complete):**
"
      while IFS= read -r f; do
        [ -n "$f" ] && spec_section+="- $f
"
      done <<< "$verified"
      spec_section+="
"
    fi
  fi
fi

if [ -n "$spec_section" ]; then
  msg+="$spec_section"
fi

if [ -z "$in_progress" ] && [ -z "$ready" ] && [ -z "$recent" ] && [ -z "$spec_section" ]; then
  msg+="
No in-progress, ready, or recently closed work found in this project.
"
fi

msg+="
**Present this to the user in a clear, readable format. If there is in-progress or ready work, ask which one they want to pick up.**"

json_encode_context "$msg"
