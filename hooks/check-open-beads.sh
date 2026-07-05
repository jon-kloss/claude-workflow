#!/usr/bin/env bash
set -euo pipefail

# Check for open beads tasks and non-verified specs on session stop.
# Warns if there are in-progress tasks or specs that haven't been verified.
# Runs on Stop event.

has_warnings=false

# Check beads tasks
beads_present=false
if [ -d ".beads" ]; then
    beads_present=true
else
    git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    if [ -n "$git_root" ] && [ -d "$git_root/.beads" ]; then
        beads_present=true
    fi
fi

if [ "$beads_present" = true ] && command -v bd >/dev/null 2>&1; then
    # `grep -c` prints a count AND exits 1 on zero matches; the old
    # `|| echo 0` therefore appended a second line ("0\n0") and broke the
    # -gt comparisons on every Stop in a clean project (evaluation H14).
    in_progress=$(bd list --status in_progress 2>/dev/null | grep -c "◐" || true)
    in_progress=${in_progress:-0}
    open_tasks=$(bd list --status open --type feature 2>/dev/null | grep -c "○" || true)
    open_tasks=${open_tasks:-0}

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

# Check non-verified specs. Skipped entirely when specs/ doesn't exist; the
# per-file grep -q stops at the first match (no full recursive scan — this
# runs on every Stop event, so it's kept cheap).
if [ -d "specs" ]; then
    non_verified=0
    for f in specs/*.md specs/*/*.md; do
        [ -f "$f" ] || continue
        if grep -q '@status(draft)\|@status(approved)\|@status(implemented)' "$f" 2>/dev/null; then
            non_verified=$((non_verified + 1))
        fi
    done
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
