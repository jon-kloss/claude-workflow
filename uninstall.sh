#!/usr/bin/env bash
set -euo pipefail

# Uninstall the Adaptive Developer Workflow for Claude Code
# Usage: ./uninstall.sh
#
# This script:
# 1. Removes skill symlinks and restores any backed-up originals
# 2. Removes hook symlinks and restores any backed-up originals
# 3. Restores settings.json from pre-workflow backup

CLAUDE_DIR="${HOME}/.claude"
BACKUP_SUFFIX=".pre-workflow"

echo "=== Adaptive Developer Workflow Uninstaller ==="
echo ""

# Helper: remove symlink and restore backup if it exists
restore_or_remove() {
    local target="$1"

    if [ -L "$target" ]; then
        rm "$target"
        if [ -f "${target}${BACKUP_SUFFIX}" ]; then
            mv "${target}${BACKUP_SUFFIX}" "$target"
            echo "  - Restored $(basename "$target") from backup"
        else
            echo "  - Removed $(basename "$target") (no backup to restore)"
        fi
    elif [ -f "$target" ] && [ ! -L "$target" ]; then
        echo "  - $(basename "$target") is not a symlink, skipping (not ours)"
    fi
}

# 1. Remove skills
echo "[1/3] Removing skills..."
restore_or_remove "$CLAUDE_DIR/skills/workflow-orchestrator/SKILL.md"
restore_or_remove "$CLAUDE_DIR/skills/workflow-retrospective/SKILL.md"

# Clean up empty skill directories
rmdir "$CLAUDE_DIR/skills/workflow-orchestrator" 2>/dev/null || true
rmdir "$CLAUDE_DIR/skills/workflow-retrospective" 2>/dev/null || true

# 2. Remove hooks
echo "[2/3] Removing hooks..."
for hook in beads-auto-resume.sh block-unread-edits.sh check-open-beads.sh \
            clear-session-reads.sh require-bead-description.sh track-reads.sh \
            workflow-reminder.sh; do
    restore_or_remove "$CLAUDE_DIR/hooks/$hook"
done

# 3. Restore settings.json
echo "[3/3] Restoring settings.json..."
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "${SETTINGS_FILE}${BACKUP_SUFFIX}" ]; then
    cp "${SETTINGS_FILE}${BACKUP_SUFFIX}" "$SETTINGS_FILE"
    echo "  - Restored settings.json from pre-workflow backup"
    echo "  - Backup kept at ${SETTINGS_FILE}${BACKUP_SUFFIX} (safe to delete)"
else
    echo "  - No pre-workflow backup found for settings.json"
    echo "  - You may need to manually remove workflow hooks from settings.json"
fi

echo ""
echo "=== Uninstall Complete ==="
echo ""
echo "Restart Claude Code (or /clear) for changes to take effect."
