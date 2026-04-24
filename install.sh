#!/usr/bin/env bash
set -euo pipefail

# Install the Adaptive Developer Workflow for Claude Code
# Usage: ./install.sh
#
# This script:
# 1. Links skills to ~/.claude/skills/ (backs up existing files first)
# 2. Links hooks to ~/.claude/hooks/ (backs up existing files first)
# 3. Merges hook configuration into ~/.claude/settings.json (backs up first)
# 4. Creates hook state directory
# 5. Optionally disables superpowers plugin
#
# On macOS/Linux: uses symlinks (repo edits are instantly live)
# On Windows: uses hard links (repo edits are instantly live, same drive required)
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

# Find a working Python 3 interpreter
PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" &> /dev/null; then
        # Verify it's actually Python 3 and executable
        if "$candidate" -c "import sys; assert sys.version_info[0] >= 3" 2>/dev/null; then
            PYTHON="$candidate"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python 3 is required but not found."
    echo "Install from https://www.python.org/downloads/"
    exit 1
fi

# Detect platform
is_windows() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*|*_NT*) return 0 ;;
        *) return 1 ;;
    esac
}

if is_windows; then
    PLATFORM="windows"
    LINK_TYPE="hard link"
else
    PLATFORM="unix"
    LINK_TYPE="symlink"
fi

echo "Detected platform: $(uname -s)"
echo "Link mode: $LINK_TYPE"
echo ""

# Helper: create a link (symlink on unix, hard link on windows)
make_link() {
    local source="$1"
    local target="$2"

    if [ "$PLATFORM" = "windows" ]; then
        # Use PowerShell to create hard links (no elevation required)
        local win_target win_source
        win_target="$(cygpath -w "$target")"
        win_source="$(cygpath -w "$source")"
        powershell -Command "New-Item -ItemType HardLink -Path '$win_target' -Target '$win_source'" > /dev/null 2>&1
    else
        ln -sf "$source" "$target"
    fi
}

MANIFEST_FILE="$CLAUDE_DIR/.workflow-manifest"

# Helper: check if a file was installed by us (via manifest or symlink/hard link detection)
is_our_file() {
    local target="$1"
    # Symlink is always ours
    if [ -L "$target" ]; then
        return 0
    fi
    # Check manifest from previous install
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

# Helper: back up a file before replacing it with a link
# Skips backup if file is already one of ours (idempotent re-install)
backup_and_link() {
    local source="$1"
    local target="$2"

    if [ -f "$target" ] || [ -L "$target" ]; then
        if is_our_file "$target"; then
            # Previous install - remove old file before re-creating
            rm "$target"
        else
            # User's own file - back it up
            mv "$target" "${target}${BACKUP_SUFFIX}"
            echo "    backed up $(basename "$target")"
        fi
    fi
    make_link "$source" "$target"
}

# 1. Install skills
echo "[1/5] Installing skills..."
mkdir -p "$CLAUDE_DIR/skills/design"
mkdir -p "$CLAUDE_DIR/skills/build"
mkdir -p "$CLAUDE_DIR/skills/workflow-orchestrator"
mkdir -p "$CLAUDE_DIR/skills/workflow-retrospective"
backup_and_link "$SCRIPT_DIR/skills/design/SKILL.md" "$CLAUDE_DIR/skills/design/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/build/SKILL.md" "$CLAUDE_DIR/skills/build/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/workflow-orchestrator/SKILL.md" "$CLAUDE_DIR/skills/workflow-orchestrator/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/workflow-retrospective/SKILL.md" "$CLAUDE_DIR/skills/workflow-retrospective/SKILL.md"
echo "  - /design linked"
echo "  - /build linked"
echo "  - workflow-orchestrator linked (deprecated — redirects to /design + /build)"
echo "  - workflow-retrospective linked"

# 2. Install hooks
echo "[2/5] Installing hooks..."
mkdir -p "$CLAUDE_DIR/hooks"
hook_count=0
for hook in "$SCRIPT_DIR"/hooks/*.sh; do
    backup_and_link "$hook" "$CLAUDE_DIR/hooks/$(basename "$hook")"
    hook_count=$((hook_count + 1))
done
echo "  - $hook_count hook scripts linked"

# Write manifest of installed files (used by uninstall to identify our files)
echo "# Workflow install manifest - do not edit" > "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/design/SKILL.md" >> "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/build/SKILL.md" >> "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/workflow-orchestrator/SKILL.md" >> "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/workflow-retrospective/SKILL.md" >> "$MANIFEST_FILE"
for hook in "$SCRIPT_DIR"/hooks/*.sh; do
    echo "$CLAUDE_DIR/hooks/$(basename "$hook")" >> "$MANIFEST_FILE"
done

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
    },
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/remind-integration-tests.sh"
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

# Merge hooks into settings using python3 (cross-platform, no jq dependency)
# Deduplicates on re-install: skips entries whose command already exists
"$PYTHON" -c "
import json, sys

settings_path = sys.argv[1]
new_hooks = json.loads(sys.argv[2])

with open(settings_path, 'r') as f:
    settings = json.load(f)

existing_hooks = settings.get('hooks', {})

# Collect all existing hook commands for deduplication
def get_commands(entries):
    cmds = set()
    for entry in entries:
        for h in entry.get('hooks', []):
            cmds.add(h.get('command', ''))
    return cmds

# For each event, append only entries not already present
for event, new_entries in new_hooks.items():
    existing_entries = existing_hooks.get(event, [])
    existing_cmds = get_commands(existing_entries)
    for entry in new_entries:
        entry_cmds = {h.get('command', '') for h in entry.get('hooks', [])}
        if not entry_cmds & existing_cmds:
            existing_entries.append(entry)
    existing_hooks[event] = existing_entries

settings['hooks'] = existing_hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
" "$SETTINGS_FILE" "$HOOKS_JSON"

echo "  - Hooks configured"

# 5. Optionally disable superpowers
echo ""
read -p "[5/5] Disable superpowers plugin? (Recommended - hyperpowers covers all features) [y/N]: " disable_sp
if [[ "$disable_sp" =~ ^[Yy]$ ]]; then
    "$PYTHON" -c "
import json, sys
path = sys.argv[1]
with open(path, 'r') as f:
    settings = json.load(f)
plugins = settings.get('enabledPlugins', {})
plugins['superpowers@claude-plugins-official'] = False
settings['enabledPlugins'] = plugins
with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
" "$SETTINGS_FILE"
    echo "  - Superpowers disabled"
else
    echo "  - Superpowers left as-is"
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "What was installed:"
echo "  Skills:     ~/.claude/skills/design/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/build/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/workflow-orchestrator/SKILL.md (deprecated redirect)"
echo "              ~/.claude/skills/workflow-retrospective/SKILL.md ($LINK_TYPE)"
echo "  Hooks:      ~/.claude/hooks/ ($hook_count scripts, $LINK_TYPE)"
echo "  Config:     ~/.claude/settings.json (hooks added)"
echo "  Benchmarks: $(pwd)/benchmarks/ (6 benchmarks + A/B protocol)"
echo ""
echo "Any existing files were backed up with a $BACKUP_SUFFIX suffix."
echo "Run ./uninstall.sh to remove workflow and restore originals."
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (or /clear) so hooks take effect"
echo "  2. Use /design to start new work (Socratic questioning + Gherkin specs)"
echo "  3. Use /build to implement approved specs (TDD + verification)"
echo "  4. After 3 completed epics, run /workflow-retrospective"
