#!/usr/bin/env bash
set -euo pipefail

# Check for open beads tasks and non-verified specs on session stop.
# Warns if there are in-progress tasks or specs that haven't been verified.
# Runs on Stop event.

has_warnings=false

# Check beads tasks
if [ -d ".beads" ] || [ -d "$(git rev-parse --show-toplevel 2>/dev/null)/.beads" 2>/dev/null ]; then
    in_progress=$(bd list --status in_progress 2>/dev/null | grep -c "◐" || echo "0")
    open_tasks=$(bd list --status open --type feature 2>/dev/null | grep -c "○" || echo "0")

    if [ "$in_progress" -gt 0 ] || [ "$open_tasks" -gt 0 ]; then
        has_warnings=true
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  OPEN BEADS TASKS"
        if [ "$in_progress" -gt 0 ]; then
            echo "   $in_progress task(s) still in progress"
        fi
        if [ "$open_tasks" -gt 0 ]; then
            echo "   $open_tasks task(s) still open"
        fi
    fi
fi

# Check non-verified specs
if [ -d "specs" ]; then
    non_verified=$(grep -rl '@status(draft)\|@status(approved)\|@status(implemented)' specs/ 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    if [ "$non_verified" -gt 0 ]; then
        if [ "$has_warnings" = false ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
        has_warnings=true
        echo ""
        echo "  NON-VERIFIED SPECS"
        echo "   $non_verified spec(s) not yet @status(verified)"
        echo "   Use /build to continue implementation"
    fi
fi

if [ "$has_warnings" = true ]; then
    echo ""
    echo "   Have you run verification?"
    echo "   Have you closed completed tasks?"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
