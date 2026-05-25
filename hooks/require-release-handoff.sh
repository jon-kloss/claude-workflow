#!/usr/bin/env bash
set -euo pipefail

# Block `bd close <epic-id>` commands when the release-coordinator handoff is
# missing or its verdict is BLOCKED.
#
# Pairs with the role-agent system from docs/role-agent-handoff-schema.md.
# Looks for: specs/handoffs/step-4.2-<epic-id>-release-coordinator.html
#
# Heuristic for "is this an epic close?":
#   bd close <id> where `bd show <id>` title contains "[epic]"
#
# Override: @release-skip(reason) tag inside the spec or a bd comment on the
# epic with body starting with "RELEASE-SKIP: <reason>".
#
# Runs as PreToolUse hook on Bash.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

cmd=$(json_get "$tool_use_json" ".tool.input.command" "")
[ -z "$cmd" ] && cmd=$(json_get "$tool_use_json" ".tool_input.command" "")

if [ -z "$cmd" ]; then
    echo '{}'
    exit 0
fi

# Only intercept bd close commands
if ! echo "$cmd" | grep -qE '\bbd\s+close\b'; then
    echo '{}'
    exit 0
fi

# Extract the first id argument (e.g., workflow-abc, beads-xyz, project-123)
target_id=$(echo "$cmd" | grep -oE '\b[a-z]+-[a-z0-9]{3,}' | head -1 || true)
if [ -z "$target_id" ]; then
    echo '{}'
    exit 0
fi

# Is this an epic? Quick `bd show` check — needs bd in PATH
if ! command -v bd >/dev/null 2>&1; then
    echo '{}'
    exit 0
fi

show_out=$(bd show "$target_id" 2>/dev/null || echo "")
if [ -z "$show_out" ]; then
    echo '{}'
    exit 0
fi

# Look for "[epic]" in the title line. bd show formats: "○ id · TITLE..."
if ! echo "$show_out" | grep -qE '\[epic\]'; then
    echo '{}'
    exit 0
fi

# Check for handoff file. Look in any specs/handoffs/ under cwd.
handoff_path=""
for candidate in $(find . -maxdepth 4 -type d -name handoffs 2>/dev/null); do
    f="${candidate}/step-4.2-${target_id}-release-coordinator.html"
    if [ -f "$f" ]; then
        handoff_path="$f"
        break
    fi
done

if [ -z "$handoff_path" ]; then
    # Check for skip-via-bd-comment override
    comments=$(bd comments "$target_id" 2>/dev/null || echo "")
    if echo "$comments" | grep -qE '^RELEASE-SKIP:|RELEASE-SKIP:'; then
        echo '{}'
        exit 0
    fi
    cat <<EOF
{"error": "BLOCKED: bd close ${target_id} (epic) requires a release-coordinator handoff at specs/handoffs/step-4.2-${target_id}-release-coordinator.html\n\nDispatch the release-coordinator role agent before closing the epic:\n  Agent(subagent_type: release-coordinator, prompt: 'You are running Step 4.2 (final verification) for epic ${target_id}. Verify all spec @status(verified), all handoff chains, all CUJ tests, rollback plan. Produce handoff at specs/handoffs/step-4.2-${target_id}-release-coordinator.html with verdict READY-TO-CLOSE / BLOCKED / READY-WITH-CAVEATS.')\n\nTo override (rare — document the reason), add a bd comment:\n  bd comment ${target_id} 'RELEASE-SKIP: <concise reason>'"}
EOF
    exit 0
fi

# Handoff exists — check verdict. Look for verdict line in the document.
verdict=$("$PYTHON" - "$handoff_path" <<'PYEOF'
import sys, re
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    content = f.read()
m = re.search(r'\bREADY-TO-CLOSE\b|\bREADY-WITH-CAVEATS\b|\bBLOCKED\b', content)
print(m.group(0) if m else "MISSING")
PYEOF
2>/dev/null || echo "MISSING")

case "$verdict" in
    "READY-TO-CLOSE"|"READY-WITH-CAVEATS")
        echo '{}'
        exit 0
        ;;
    "BLOCKED")
        cat <<EOF
{"error": "BLOCKED: release-coordinator verdict for epic ${target_id} is BLOCKED.\n\nHandoff: ${handoff_path}\n\nResolve the blockers documented in the handoff's findings section before closing the epic. To override (rare):\n  bd comment ${target_id} 'RELEASE-SKIP: <concise reason>'"}
EOF
        exit 0
        ;;
    *)
        cat <<EOF
{"error": "BLOCKED: release-coordinator handoff at ${handoff_path} has no verdict line (READY-TO-CLOSE, READY-WITH-CAVEATS, or BLOCKED).\n\nThe agent's output must end with one of those verdicts. Either the dispatch was incomplete or the handoff was hand-edited. Re-dispatch the release-coordinator or restore the verdict line."}
EOF
        exit 0
        ;;
esac
