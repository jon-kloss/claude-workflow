#!/usr/bin/env bash
set -euo pipefail

# Check for open beads tasks on session stop.
# Warns if there are in-progress or open tasks that haven't been closed.
# Runs on Stop event.

# Check if we're in a git repo with beads initialized
if [ ! -d ".beads" ] && [ ! -d "$(git rev-parse --show-toplevel 2>/dev/null)/.beads" 2>/dev/null ]; then
    # No beads in this project - nothing to check
    exit 0
fi

# Check for in-progress tasks
in_progress=$(bd list --status in_progress 2>/dev/null | grep -c "◐" || echo "0")

# Check for open tasks (not epics)
open_tasks=$(bd list --status open --type feature 2>/dev/null | grep -c "○" || echo "0")

if [ "$in_progress" -gt 0 ] || [ "$open_tasks" -gt 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  OPEN BEADS TASKS DETECTED"

    if [ "$in_progress" -gt 0 ]; then
        echo "   $in_progress task(s) still in progress"
    fi
    if [ "$open_tasks" -gt 0 ]; then
        echo "   $open_tasks task(s) still open"
    fi

    echo ""
    echo "   Have you run verification? (Phase 4)"
    echo "   Have you closed completed tasks?"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
