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
echo "[1/6] Installing skills..."
mkdir -p "$CLAUDE_DIR/skills/design"
mkdir -p "$CLAUDE_DIR/skills/design-arch"
mkdir -p "$CLAUDE_DIR/skills/design-ui"
mkdir -p "$CLAUDE_DIR/skills/build"
mkdir -p "$CLAUDE_DIR/skills/respec"
mkdir -p "$CLAUDE_DIR/skills/workflow-retrospective"
mkdir -p "$CLAUDE_DIR/skills/onboard"
backup_and_link "$SCRIPT_DIR/skills/design/SKILL.md" "$CLAUDE_DIR/skills/design/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/design-arch/SKILL.md" "$CLAUDE_DIR/skills/design-arch/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/design-ui/SKILL.md" "$CLAUDE_DIR/skills/design-ui/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/build/SKILL.md" "$CLAUDE_DIR/skills/build/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/respec/SKILL.md" "$CLAUDE_DIR/skills/respec/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/workflow-retrospective/SKILL.md" "$CLAUDE_DIR/skills/workflow-retrospective/SKILL.md"
backup_and_link "$SCRIPT_DIR/skills/onboard/SKILL.md" "$CLAUDE_DIR/skills/onboard/SKILL.md"
echo "  - /design linked"
echo "  - /design-arch linked"
echo "  - /design-ui linked"
echo "  - /build linked"
echo "  - /respec linked"
echo "  - workflow-retrospective linked"
echo "  - /onboard linked"

# 2. Install agents
echo "[2/6] Installing agents..."
mkdir -p "$CLAUDE_DIR/agents"
agent_count=0
if [ -d "$SCRIPT_DIR/agents" ]; then
    for agent in "$SCRIPT_DIR"/agents/*.md; do
        [ -f "$agent" ] || continue
        backup_and_link "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")"
        agent_count=$((agent_count + 1))
    done
fi
echo "  - $agent_count agent files linked"

# 3. Install hooks
# Includes both *.sh entry points AND *.py helpers (e.g. _validate_handoff.py
# which require-handoff-artifact.sh invokes). Missing .py helpers caused a
# critical bug where the entire handoff-artifact gate false-positive blocked
# every @status(verified) write under set -euo pipefail.
echo "[3/6] Installing hooks..."
mkdir -p "$CLAUDE_DIR/hooks"
hook_count=0
for hook in "$SCRIPT_DIR"/hooks/*.sh "$SCRIPT_DIR"/hooks/*.py; do
    [ -f "$hook" ] || continue   # skip if a glob expanded to nothing
    backup_and_link "$hook" "$CLAUDE_DIR/hooks/$(basename "$hook")"
    hook_count=$((hook_count + 1))
done
echo "  - $hook_count hook files linked (.sh + .py)"

# Write manifest of installed files (used by uninstall to identify our files)
echo "# Workflow install manifest - do not edit" > "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/design/SKILL.md" >> "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/design-arch/SKILL.md" >> "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/design-ui/SKILL.md" >> "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/build/SKILL.md" >> "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/respec/SKILL.md" >> "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/workflow-retrospective/SKILL.md" >> "$MANIFEST_FILE"
echo "$CLAUDE_DIR/skills/onboard/SKILL.md" >> "$MANIFEST_FILE"
if [ -d "$SCRIPT_DIR/agents" ]; then
    for agent in "$SCRIPT_DIR"/agents/*.md; do
        [ -f "$agent" ] || continue
        echo "$CLAUDE_DIR/agents/$(basename "$agent")" >> "$MANIFEST_FILE"
    done
fi
for hook in "$SCRIPT_DIR"/hooks/*.sh "$SCRIPT_DIR"/hooks/*.py; do
    [ -f "$hook" ] || continue
    echo "$CLAUDE_DIR/hooks/$(basename "$hook")" >> "$MANIFEST_FILE"
done

# 4. Create hook state directory
echo "[4/6] Creating hook state directory..."
mkdir -p "$CLAUDE_DIR/hooks/state"
touch "$CLAUDE_DIR/hooks/state/session-reads.txt"
echo "  - State directory ready"

# 5. Merge hooks into settings.json
echo "[5/6] Configuring hooks in settings.json..."

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
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/require-design-ui.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/require-verifier-agents.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/block-status-during-verification.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/require-ui-tests.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/require-investigation-findings.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/claim-vs-call-audit.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/require-layer-tag.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/require-handoff-artifact.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/require-fix-cycle-handoff.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/guard-handoff-owner.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/guard-agent-memory-secrets.sh"
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
    },
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/block-status-during-verification.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/guard-spec-bash-writes.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/require-release-handoff.sh"
        }
      ]
    },
    {
      "matcher": "Agent",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/verifier-dispatch.sh"
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
    },
    {
      "matcher": "Agent",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/verifier-return.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/track-agents.sh"
        }
      ]
    },
    {
      "matcher": "Skill",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/track-skills.sh"
        }
      ]
    },
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/molecule-autoclose-warn.sh"
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
      "hooks": [
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/detect-correction.sh"
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
# Deduplicates AT THE COMMAND LEVEL within matching (event, matcher) entries.
# This avoids the prior bug where adding a new hook to an existing entry block
# (e.g. new require-verifier-agents.sh into the Edit|Write entry that already
# contains block-unread-edits.sh) caused the whole entry to be skipped because
# *some* commands matched existing ones.
"$PYTHON" -c "
import json, sys

settings_path = sys.argv[1]
new_hooks = json.loads(sys.argv[2])

with open(settings_path, 'r') as f:
    settings = json.load(f)

existing_hooks = settings.get('hooks', {})

def find_matching_entry(entries, matcher):
    for e in entries:
        if e.get('matcher', '') == matcher:
            return e
    return None

# For each event:
#   For each new entry (a {matcher, hooks[]} block):
#     If an existing entry has the same matcher, merge command-by-command (skip
#     any new command whose string already appears in the existing entry's hooks).
#     If no existing entry has that matcher, append the new entry whole.
for event, new_entries in new_hooks.items():
    existing_entries = existing_hooks.get(event, [])
    for new_entry in new_entries:
        new_matcher = new_entry.get('matcher', '')
        match = find_matching_entry(existing_entries, new_matcher)
        if match is None:
            existing_entries.append(new_entry)
            continue
        existing_cmds = {h.get('command', '') for h in match.get('hooks', [])}
        for h in new_entry.get('hooks', []):
            if h.get('command', '') not in existing_cmds:
                match.setdefault('hooks', []).append(h)
                existing_cmds.add(h.get('command', ''))
    existing_hooks[event] = existing_entries

settings['hooks'] = existing_hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
" "$SETTINGS_FILE" "$HOOKS_JSON"

echo "  - Hooks configured"

# 6. Optionally disable superpowers
echo ""
read -p "[6/6] Disable superpowers plugin? (Recommended - hyperpowers covers all features) [y/N]: " disable_sp
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
echo "              ~/.claude/skills/design-arch/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/design-ui/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/build/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/respec/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/workflow-retrospective/SKILL.md ($LINK_TYPE)"
echo "  Agents:     ~/.claude/agents/ ($agent_count files, $LINK_TYPE)"
echo "  Hooks:      ~/.claude/hooks/ ($hook_count scripts, $LINK_TYPE)"
echo "  Config:     ~/.claude/settings.json (hooks added)"
echo "  Benchmarks: $(pwd)/benchmarks/ (6 benchmarks + A/B protocol)"
echo ""
echo "Any existing files were backed up with a $BACKUP_SUFFIX suffix."
echo "Run ./uninstall.sh to remove workflow and restore originals."
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (or /clear) so hooks AND new agents take effect."
echo "     Important: Claude Code loads its subagent registry at session start,"
echo "     so newly-installed role agents (product-owner, application-architect,"
echo "     security-architect, devops-architect, data-architect, uiux-designer,"
echo "     backend-engineer, frontend-engineer, qa-engineer, release-coordinator)"
echo "     won't be dispatchable until you start a fresh session."
echo "  2. Use /design to start new work (Socratic questioning + Gherkin specs)"
echo "  3. Use /build to implement approved specs (TDD + verification)"
echo "  4. After 3 completed epics, run /workflow-retrospective"
