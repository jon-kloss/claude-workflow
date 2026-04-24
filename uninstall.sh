#!/usr/bin/env bash
set -euo pipefail

# Uninstall the Adaptive Developer Workflow for Claude Code
# Usage: ./uninstall.sh
#
# This script:
# 1. Removes skill links and restores any backed-up originals
# 2. Removes hook links and restores any backed-up originals
# 3. Restores settings.json from pre-workflow backup

CLAUDE_DIR="${HOME}/.claude"
BACKUP_SUFFIX=".pre-workflow"
MANIFEST_FILE="$CLAUDE_DIR/.workflow-manifest"

echo "=== Adaptive Developer Workflow Uninstaller ==="
echo ""

# Helper: check if a file was installed by us (via manifest, symlink, or hard link)
is_our_file() {
    local target="$1"
    # Symlink is always ours
    if [ -L "$target" ]; then
        return 0
    fi
    # Check manifest from install
    if [ -f "$MANIFEST_FILE" ] && grep -qF "$target" "$MANIFEST_FILE" 2>/dev/null; then
        return 0
    fi
    # Hard link check - file has more than 1 link count
    if [ -f "$target" ]; then
        local link_count
        link_count="$(stat -c '%h' "$target" 2>/dev/null || stat -f '%l' "$target" 2>/dev/null || echo 1)"
        if [ "$link_count" -gt 1 ]; then
            return 0
        fi
    fi
    return 1
}

# Helper: remove installed file and restore backup if it exists
restore_or_remove() {
    local target="$1"

    if is_our_file "$target"; then
        rm "$target"
        if [ -f "${target}${BACKUP_SUFFIX}" ]; then
            mv "${target}${BACKUP_SUFFIX}" "$target"
            echo "  - Restored $(basename "$target") from backup"
        else
            echo "  - Removed $(basename "$target") (no backup to restore)"
        fi
    elif [ -f "$target" ]; then
        echo "  - $(basename "$target") not found in manifest, skipping (not ours)"
    fi
}

# 1. Remove skills
echo "[1/3] Removing skills..."
restore_or_remove "$CLAUDE_DIR/skills/design/SKILL.md"
restore_or_remove "$CLAUDE_DIR/skills/build/SKILL.md"
restore_or_remove "$CLAUDE_DIR/skills/workflow-orchestrator/SKILL.md"
restore_or_remove "$CLAUDE_DIR/skills/workflow-retrospective/SKILL.md"

# Clean up empty skill directories
rmdir "$CLAUDE_DIR/skills/design" 2>/dev/null || true
rmdir "$CLAUDE_DIR/skills/build" 2>/dev/null || true
rmdir "$CLAUDE_DIR/skills/workflow-orchestrator" 2>/dev/null || true
rmdir "$CLAUDE_DIR/skills/workflow-retrospective" 2>/dev/null || true

# 2. Remove hooks
echo "[2/3] Removing hooks..."
for hook in _common.sh beads-auto-resume.sh block-unread-edits.sh check-open-beads.sh \
            clear-session-reads.sh remind-integration-tests.sh require-bead-description.sh \
            track-reads.sh verifier-dispatch.sh verifier-return.sh \
            wwiwo.sh workflow-reminder.sh; do
    restore_or_remove "$CLAUDE_DIR/hooks/$hook"
done

# 3. Remove our hook entries from settings.json (preserves user's own hooks)
echo "[3/3] Removing workflow hooks from settings.json..."
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    # Find a working Python 3 interpreter
    PYTHON=""
    for candidate in python3 python; do
        if command -v "$candidate" &> /dev/null; then
            if "$candidate" -c "import sys; assert sys.version_info[0] >= 3" 2>/dev/null; then
                PYTHON="$candidate"
                break
            fi
        fi
    done

    if [ -n "$PYTHON" ]; then
        # Surgically remove only our hook entries (identified by ~/.claude/hooks/ commands)
        "$PYTHON" -c "
import json, sys

settings_path = sys.argv[1]

with open(settings_path, 'r') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
if not hooks:
    sys.exit(0)

# Our hooks all reference scripts in ~/.claude/hooks/
our_scripts = {
    'beads-auto-resume.sh', 'block-unread-edits.sh', 'check-open-beads.sh',
    'clear-session-reads.sh', 'remind-integration-tests.sh',
    'require-bead-description.sh', 'track-reads.sh',
    'verifier-dispatch.sh', 'verifier-return.sh',
    'workflow-reminder.sh', 'wwiwo.sh'
}

def is_our_entry(entry):
    for h in entry.get('hooks', []):
        cmd = h.get('command', '')
        for script in our_scripts:
            if script in cmd:
                return True
    return False

removed = 0
for event in list(hooks.keys()):
    original_len = len(hooks[event])
    hooks[event] = [e for e in hooks[event] if not is_our_entry(e)]
    removed += original_len - len(hooks[event])
    # Remove empty event arrays
    if not hooks[event]:
        del hooks[event]

# Remove hooks key entirely if empty
if not hooks:
    del settings['hooks']
else:
    settings['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print(f'  - Removed {removed} workflow hook entries from settings.json')
print('  - User hooks preserved')
" "$SETTINGS_FILE"
    else
        echo "  - WARNING: python3/python not found, cannot edit settings.json"
        if [ -f "${SETTINGS_FILE}${BACKUP_SUFFIX}" ]; then
            echo "  - Falling back to restoring pre-workflow backup"
            cp "${SETTINGS_FILE}${BACKUP_SUFFIX}" "$SETTINGS_FILE"
        else
            echo "  - You may need to manually remove workflow hooks from settings.json"
        fi
    fi
else
    echo "  - No settings.json found, nothing to clean up"
fi

# Clean up settings backup if it exists
if [ -f "${SETTINGS_FILE}${BACKUP_SUFFIX}" ]; then
    echo "  - Pre-workflow backup kept at ${SETTINGS_FILE}${BACKUP_SUFFIX} (safe to delete)"
fi

# Clean up manifest if it exists
rm -f "$CLAUDE_DIR/.workflow-manifest"

echo ""
echo "=== Uninstall Complete ==="
echo ""
echo "Restart Claude Code (or /clear) for changes to take effect."
