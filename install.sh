#!/usr/bin/env bash
set -euo pipefail

# Install the Adaptive Developer Workflow for Claude Code
# Usage: ./install.sh
#
# This script:
# 1. Symlinks skills to ~/.claude/skills/ (backs up existing files first)
# 2. Symlinks hooks to ~/.claude/hooks/ (backs up existing files first)
# 3. Merges hook configuration into ~/.claude/settings.json (backs up first)
# 4. Creates hook state directory
# 5. Optionally disables superpowers plugin
#
# All originals are backed up with .pre-workflow suffix.
# Run uninstall.sh to restore them.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
BACKUP_SUFFIX=".pre-workflow"

echo "=== Adaptive Developer Workflow Installer ==="
echo ""

# Check prerequisites
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "ERROR: ~/.claude/ directory not found. Is Claude Code installed?"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required for settings.json manipulation."
    echo "Install with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

# Helper: back up a file before replacing it with a symlink
# Skips if file is already a symlink (idempotent re-install)
backup_and_link() {
    local source="$1"
    local target="$2"

    if [ -f "$target" ] && [ ! -L "$target" ]; then
        mv "$target" "${target}${BACKUP_SUFFIX}"
        echo "    backed up $(basename "$target")"
    fi
    ln -sf "$source" "$target"
}

# 1. Install skills (symlinked so repo edits are instantly live)
echo "[1/5] Installing skills..."
mkdir -p "$CLAUDE_DIR/skills/workflow-orchestrator"
mkdir -p "$CLAUDE_DIR/skills/workflow-retrospective"
backup_and_link "$SCRIPT_DIR/skills/workflow-orchestrator/SKILL.md" "$CLAUDE_DIR/skills/workflow-orchestrator/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/workflow-retrospective/SKILL.md" "$CLAUDE_DIR/skills/workflow-retrospective/SKILL.md"
echo "  - workflow-orchestrator symlinked"
echo "  - workflow-retrospective symlinked"

# 2. Install hooks (symlinked so repo edits are instantly live)
echo "[2/5] Installing hooks..."
mkdir -p "$CLAUDE_DIR/hooks"
for hook in "$SCRIPT_DIR"/hooks/*.sh; do
    backup_and_link "$hook" "$CLAUDE_DIR/hooks/$(basename "$hook")"
done
echo "  - $(ls "$SCRIPT_DIR"/hooks/*.sh | wc -l | tr -d ' ') hook scripts symlinked"

# 3. Create hook state directory
echo "[3/5] Creating hook state directory..."
mkdir -p "$CLAUDE_DIR/hooks/state"
touch "$CLAUDE_DIR/hooks/state/session-reads.txt"
echo "  - State directory ready"

# 4. Merge hooks into settings.json
echo "[4/5] Configuring hooks in settings.json..."

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "  - No settings.json found, creating one..."
    echo '{}' > "$SETTINGS_FILE"
fi

# Back up settings.json (always a copy, not a rename - we still need the file)
if [ ! -f "${SETTINGS_FILE}${BACKUP_SUFFIX}" ]; then
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}${BACKUP_SUFFIX}"
    echo "  - Backed up settings.json"
else
    echo "  - settings.json backup already exists (previous install), skipping"
fi

# Define the hooks to add
HOOKS_JSON=$(cat <<'HOOKS_EOF'
{
  "SessionStart": [
    {
      "matcher": "startup|clear|compact",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/clear-session-reads.sh"
        }
      ]
    },
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/beads-auto-resume.sh"
        }
      ]
    }
  ],
  "PreToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/block-unread-edits.sh"
        }
      ]
    },
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/require-bead-description.sh"
        }
      ]
    }
  ],
  "PostToolUse": [
    {
      "matcher": "Read|Grep|Glob",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/track-reads.sh"
        }
      ]
    }
  ],
  "UserPromptSubmit": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/workflow-reminder.sh"
        }
      ]
    },
    {
      "matcher": "wwiwo",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/wwiwo.sh"
        }
      ]
    }
  ],
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/check-open-beads.sh"
        }
      ]
    }
  ]
}
HOOKS_EOF
)

# Merge hooks into settings (preserves existing hooks, adds ours)
if jq -e '.hooks' "$SETTINGS_FILE" > /dev/null 2>&1; then
    echo "  - Existing hooks found. Merging (existing hooks preserved)..."
    # Deep merge: for each event, concatenate arrays
    jq --argjson new_hooks "$HOOKS_JSON" '
      .hooks as $existing |
      reduce ($new_hooks | keys[]) as $event (
        .;
        .hooks[$event] = (($existing[$event] // []) + $new_hooks[$event])
      )
    ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
else
    echo "  - No existing hooks. Adding hook configuration..."
    jq --argjson hooks "$HOOKS_JSON" '.hooks = $hooks' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
fi
echo "  - Hooks configured"

# 5. Optionally disable superpowers
echo ""
read -p "[5/5] Disable superpowers plugin? (Recommended - hyperpowers covers all features) [y/N]: " disable_sp
if [[ "$disable_sp" =~ ^[Yy]$ ]]; then
    jq '.enabledPlugins["superpowers@claude-plugins-official"] = false' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    echo "  - Superpowers disabled"
else
    echo "  - Superpowers left as-is"
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "What was installed:"
echo "  Skills:     ~/.claude/skills/workflow-orchestrator/SKILL.md (symlink)"
echo "              ~/.claude/skills/workflow-retrospective/SKILL.md (symlink)"
echo "  Hooks:      ~/.claude/hooks/ (7 symlinked scripts)"
echo "  Config:     ~/.claude/settings.json (hooks added)"
echo "  Benchmarks: $(pwd)/benchmarks/ (6 benchmarks + A/B protocol)"
echo ""
echo "Any existing files were backed up with a $BACKUP_SUFFIX suffix."
echo "Run ./uninstall.sh to remove workflow and restore originals."
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (or /clear) so hooks take effect"
echo "  2. Start any task - the workflow-orchestrator skill will activate"
echo "  3. After 3 completed epics, run /workflow-retrospective"
