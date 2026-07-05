#!/usr/bin/env bash
set -euo pipefail

# Install the Adaptive Developer Workflow for Claude Code
# Usage: ./install.sh [--yes]
#
#   --yes / -y   Non-interactive mode: assume "yes" for optional prompts
#                (currently: disabling the superpowers plugin).
#
# This script:
# 1. Validates ~/.claude/settings.json is parseable JSON (before touching anything)
# 2. Links skills (SKILL.md + resources/) to ~/.claude/skills/
# 3. Links agents to ~/.claude/agents/
# 4. Links hooks to ~/.claude/hooks/
# 5. Merges hook configuration into ~/.claude/settings.json (backs up first)
# 6. Optionally disables superpowers plugin
# 7. Writes ~/.claude/workflow-install-manifest.json recording everything it did
#    (uninstall.sh consumes this manifest)
#
# On macOS/Linux: uses symlinks (repo edits are instantly live)
# On Windows: uses hard links (repo edits are instantly live, same drive required)
#
# All pre-existing user files are backed up with .pre-workflow suffix.
# Run uninstall.sh to remove exactly what was installed and restore backups.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
BACKUP_SUFFIX=".pre-workflow"
MANIFEST_JSON="$CLAUDE_DIR/workflow-install-manifest.json"
LEGACY_MANIFEST="$CLAUDE_DIR/.workflow-manifest"

# --- Argument parsing ---------------------------------------------------------
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=1 ;;
        -h|--help)
            echo "Usage: ./install.sh [--yes]"
            echo "  --yes   non-interactive: assume yes for optional prompts"
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $arg (supported: --yes)" >&2
            exit 1
            ;;
    esac
done

echo "=== Adaptive Developer Workflow Installer ==="
echo ""

# --- Prerequisites --------------------------------------------------------------
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

if ! command -v git &> /dev/null; then
    echo "ERROR: git is required but not found."
    echo "The workflow's hooks and skills assume a git repository per project."
    echo "Install git and re-run install.sh."
    exit 1
fi

if ! command -v bd &> /dev/null; then
    echo "!!! WARNING: 'bd' (beads task tracker) was not found on PATH. !!!"
    echo ""
    echo "  The workflow still installs, but NINE hooks degrade without bd:"
    echo "    beads-auto-resume.sh, block-status-during-verification.sh,"
    echo "    check-open-beads.sh, detect-correction.sh, molecule-autoclose-warn.sh,"
    echo "    require-bead-description.sh, require-release-handoff.sh,"
    echo "    verifier-return.sh, wwiwo.sh"
    echo ""
    echo "  In particular, require-release-handoff.sh exits PERMISSIVE without bd:"
    echo "  the epic-close gate silently stops gating. Install beads to get full"
    echo "  enforcement: https://github.com/steveyegge/beads"
    echo ""
fi

# Check for the hyperpowers plugin (decision D7: warn-only).
# Several role agents dispatch hyperpowers:* subagents and degrade without it.
HYPER_FOUND=0
if ls -d "$CLAUDE_DIR"/plugins/cache/*/hyperpowers > /dev/null 2>&1; then
    HYPER_FOUND=1
elif ls -d "$CLAUDE_DIR"/plugins/*hyperpowers* > /dev/null 2>&1; then
    HYPER_FOUND=1
elif [ -f "$CLAUDE_DIR/plugins/installed_plugins.json" ] \
     && grep -q "hyperpowers" "$CLAUDE_DIR/plugins/installed_plugins.json" 2>/dev/null; then
    HYPER_FOUND=1
elif ls -d "$CLAUDE_DIR"/plugins/marketplaces/*hyper* > /dev/null 2>&1; then
    HYPER_FOUND=1
fi
if [ "$HYPER_FOUND" -eq 0 ]; then
    echo "!!! WARNING: hyperpowers plugin not found under ~/.claude/plugins/. !!!"
    echo ""
    echo "  These agents hard-depend on hyperpowers:* subagents and will degrade:"
    echo "    backend-engineer, frontend-engineer, data-architect, game-ui-designer"
    echo ""
    echo "  Install it via the Claude Code plugin marketplace (withzombies-hyper)"
    echo "  before running /build for full verification coverage."
    echo ""
fi

# --- Validate settings.json BEFORE creating any links --------------------------
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    if ! "$PYTHON" -c "import json,sys; json.load(open(sys.argv[1]))" "$SETTINGS_FILE" 2>/dev/null; then
        echo "ERROR: $SETTINGS_FILE is not valid JSON, so the hook configuration"
        echo "cannot be merged safely. Nothing has been installed or modified."
        echo "Fix the JSON (a linter like 'python3 -m json.tool $SETTINGS_FILE'"
        echo "will show the exact parse error), or move the file aside, then"
        echo "re-run install.sh."
        exit 1
    fi
fi

# --- Platform detection ---------------------------------------------------------
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

# --- Install-state scratch files (feed the manifest at the end) -----------------
STATE_TMP="$(mktemp -d)"
trap 'rm -rf "$STATE_TMP"' EXIT
LINKS_TMP="$STATE_TMP/links.txt"          # dest<TAB>source per link created
BACKUPS_TMP="$STATE_TMP/backups.txt"      # backup file path per backup created
OWNED_CMDS_TMP="$STATE_TMP/cmds.txt"      # event<TAB>matcher<TAB>command per settings hook
: > "$LINKS_TMP"
: > "$BACKUPS_TMP"
: > "$OWNED_CMDS_TMP"

# --- Helpers ---------------------------------------------------------------------

# Print the absolute resolved target of a symlink (one level; we only create
# direct absolute links, and one level is enough for the ownership check).
resolve_link() {
    local raw
    raw="$(readlink "$1")"
    case "$raw" in
        /*) printf '%s\n' "$raw" ;;
        *)  printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd)" "$raw" ;;
    esac
}

# Create a link (symlink on unix, hard link on windows)
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

# Was this file installed by us?
# - a symlink is ours ONLY if its resolved target lives inside this repo
# - a regular file is ours only if it is the same inode as our source
#   (windows hard-link installs), or listed in a legacy install manifest
# Anything else is the user's and must be backed up, never deleted.
is_our_file() {
    local target="$1"
    local source="$2"
    if [ -L "$target" ]; then
        local resolved
        resolved="$(resolve_link "$target")"
        case "$resolved" in
            "$SCRIPT_DIR"/*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    if [ -f "$target" ] && [ "$target" -ef "$source" ]; then
        return 0
    fi
    if [ -f "$LEGACY_MANIFEST" ] && grep -qFx "$target" "$LEGACY_MANIFEST" 2>/dev/null; then
        return 0
    fi
    return 1
}

record_link() {
    printf '%s\t%s\n' "$1" "$2" >> "$LINKS_TMP"
}

record_backup() {
    printf '%s\n' "$1" >> "$BACKUPS_TMP"
}

# Back up a file before replacing it with a link.
# Skips backup if file is already one of ours (idempotent re-install).
backup_and_link() {
    local source="$1"
    local target="$2"

    if [ -e "$target" ] || [ -L "$target" ]; then
        if is_our_file "$target" "$source"; then
            # Previous install - remove old link before re-creating
            rm -f "$target"
        else
            # User's own file - back it up
            mv "$target" "${target}${BACKUP_SUFFIX}"
            record_backup "${target}${BACKUP_SUFFIX}"
            echo "    backed up $(basename "$target")"
        fi
    fi
    make_link "$source" "$target"
    record_link "$target" "$source"
}

# Link a skill's resources/ directory.
# Unix: one directory symlink (new repo files are live without re-install).
# Windows: per-file hard links.
# Migration: the old layout left ~/.claude/skills/<name>/ as a real directory
# containing only a SKILL.md symlink — that upgrades cleanly because we only
# add a resources/ entry inside it. A pre-existing REAL resources/ directory
# (user's own) is backed up, never deleted.
link_resources() {
    local source_dir="$1"
    local target_dir="$2"

    if [ -L "$target_dir" ]; then
        local resolved
        resolved="$(resolve_link "$target_dir")"
        case "$resolved" in
            "$SCRIPT_DIR"/*)
                rm -f "$target_dir"
                ;;
            *)
                mv "$target_dir" "${target_dir}${BACKUP_SUFFIX}"
                record_backup "${target_dir}${BACKUP_SUFFIX}"
                echo "    backed up $(basename "$(dirname "$target_dir")")/resources (foreign symlink)"
                ;;
        esac
    elif [ -d "$target_dir" ]; then
        if [ "$PLATFORM" != "windows" ]; then
            local backup_dest="${target_dir}${BACKUP_SUFFIX}"
            if [ -e "$backup_dest" ]; then
                backup_dest="${backup_dest}.$(date +%s)"
            fi
            mv "$target_dir" "$backup_dest"
            record_backup "$backup_dest"
            echo "    backed up $(basename "$(dirname "$target_dir")")/resources directory"
        fi
    fi

    if [ "$PLATFORM" = "windows" ]; then
        mkdir -p "$target_dir"
        local f
        for f in "$source_dir"/*; do
            [ -f "$f" ] || continue
            backup_and_link "$f" "$target_dir/$(basename "$f")"
        done
    else
        ln -s "$source_dir" "$target_dir"
        record_link "$target_dir" "$source_dir"
    fi
}

# 1. Install skills (SKILL.md + resources/)
echo "[1/6] Installing skills..."
skill_count=0
for skill_src in "$SCRIPT_DIR"/skills/*/; do
    skill_src="${skill_src%/}"
    [ -f "$skill_src/SKILL.md" ] || continue
    skill_name="$(basename "$skill_src")"
    mkdir -p "$CLAUDE_DIR/skills/$skill_name"
    backup_and_link "$skill_src/SKILL.md" "$CLAUDE_DIR/skills/$skill_name/SKILL.md"
    if [ -d "$skill_src/resources" ]; then
        link_resources "$skill_src/resources" "$CLAUDE_DIR/skills/$skill_name/resources"
        echo "  - /$skill_name linked (SKILL.md + resources/)"
    else
        echo "  - /$skill_name linked"
    fi
    skill_count=$((skill_count + 1))
done
echo "  - $skill_count skills linked"

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

# 4. Create hook state directory
echo "[4/6] Creating hook state directory..."
mkdir -p "$CLAUDE_DIR/hooks/state"
touch "$CLAUDE_DIR/hooks/state/session-reads.txt"
echo "  - State directory ready"

# 5. Merge hooks into settings.json
echo "[5/6] Configuring hooks in settings.json..."

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
          "command": "bash ${HOME}/.claude/hooks/require-feature-mounted.sh"
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
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/track-agent-memory-baseline.sh"
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/track-agents.sh"
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
        },
        {
          "type": "command",
          "command": "bash ${HOME}/.claude/hooks/warn-agent-memory-not-updated.sh"
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
# Also writes every workflow-owned (event, matcher, command) tuple to a file
# so the manifest records exactly which settings commands are ours.
"$PYTHON" -c "
import json, sys

settings_path = sys.argv[1]
new_hooks = json.loads(sys.argv[2])
owned_out = sys.argv[3]

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
owned = []
for event, new_entries in new_hooks.items():
    existing_entries = existing_hooks.get(event, [])
    for new_entry in new_entries:
        new_matcher = new_entry.get('matcher', '')
        for h in new_entry.get('hooks', []):
            owned.append((event, new_matcher, h.get('command', '')))
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

with open(owned_out, 'w') as f:
    for event, matcher, cmd in owned:
        f.write('%s\t%s\t%s\n' % (event, matcher, cmd))
" "$SETTINGS_FILE" "$HOOKS_JSON" "$OWNED_CMDS_TMP"

echo "  - Hooks configured"

# 6. Optionally disable superpowers
echo ""
disable_sp="n"
if [ "$ASSUME_YES" -eq 1 ]; then
    disable_sp="y"
    echo "[6/6] --yes given: disabling superpowers plugin (hyperpowers covers all features)"
elif [ -t 0 ]; then
    read -r -p "[6/6] Disable superpowers plugin? (Recommended - hyperpowers covers all features) [y/N]: " disable_sp || disable_sp="n"
else
    echo "[6/6] Non-interactive install without --yes: leaving superpowers plugin as-is."
    echo "      (Re-run with --yes, or run interactively, to disable it.)"
fi

SP_DISABLED_BY_US="false"
SP_PRIOR="absent"
if [[ "$disable_sp" =~ ^[Yy]$ ]]; then
    SP_RESULT="$("$PYTHON" -c "
import json, sys
path = sys.argv[1]
key = 'superpowers@claude-plugins-official'
with open(path, 'r') as f:
    settings = json.load(f)
plugins = settings.get('enabledPlugins', {})
if key in plugins and plugins[key] is False:
    print('unchanged\tfalse')
else:
    prior = 'absent' if key not in plugins else json.dumps(plugins[key])
    plugins[key] = False
    settings['enabledPlugins'] = plugins
    with open(path, 'w') as f:
        json.dump(settings, f, indent=2)
    print('changed\t' + prior)
" "$SETTINGS_FILE")"
    SP_STATE="$(printf '%s\n' "$SP_RESULT" | cut -f1)"
    SP_PRIOR="$(printf '%s\n' "$SP_RESULT" | cut -f2)"
    if [ "$SP_STATE" = "changed" ]; then
        SP_DISABLED_BY_US="true"
        echo "  - Superpowers disabled"
    else
        SP_PRIOR="absent"
        echo "  - Superpowers already disabled, left as-is"
    fi
else
    echo "  - Superpowers left as-is"
fi

# 7. Write the install manifest (consumed by uninstall.sh)
"$PYTHON" -c "
import json, sys, datetime

(manifest_path, repo, link_type, settings_file,
 links_f, backups_f, cmds_f, sp_disabled, sp_prior) = sys.argv[1:10]

links = []
with open(links_f) as f:
    for line in f:
        line = line.rstrip('\n')
        if not line:
            continue
        dest, source = line.split('\t', 1)
        links.append({'dest': dest, 'source': source})

backups = []
with open(backups_f) as f:
    for line in f:
        line = line.rstrip('\n')
        if line:
            backups.append(line)

cmds = []
with open(cmds_f) as f:
    for line in f:
        line = line.rstrip('\n')
        if not line:
            continue
        event, matcher, command = line.split('\t', 2)
        cmds.append({'event': event, 'matcher': matcher, 'command': command})

superpowers = {'disabled_by_us': sp_disabled == 'true'}
if superpowers['disabled_by_us']:
    superpowers['prior_value'] = None if sp_prior == 'absent' else json.loads(sp_prior)

manifest = {
    'schema_version': 1,
    'installed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'repo': repo,
    'link_type': link_type,
    'settings_file': settings_file,
    'links': links,
    'backups_created': backups,
    'settings_hooks': cmds,
    'superpowers': superpowers,
}

with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)
    f.write('\n')
" "$MANIFEST_JSON" "$SCRIPT_DIR" "$LINK_TYPE" "$SETTINGS_FILE" \
  "$LINKS_TMP" "$BACKUPS_TMP" "$OWNED_CMDS_TMP" "$SP_DISABLED_BY_US" "$SP_PRIOR"

# The legacy line-per-path manifest is superseded by the JSON manifest.
rm -f "$LEGACY_MANIFEST"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "What was installed:"
echo "  Skills:     ~/.claude/skills/design/ (SKILL.md + resources/, $LINK_TYPE)"
echo "              ~/.claude/skills/design-arch/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/design-ui/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/build/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/respec/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/workflow-retrospective/SKILL.md ($LINK_TYPE)"
echo "              ~/.claude/skills/onboard/ (SKILL.md + resources/, $LINK_TYPE)"
echo "  Agents:     ~/.claude/agents/ ($agent_count files, $LINK_TYPE)"
echo "  Hooks:      ~/.claude/hooks/ ($hook_count scripts, $LINK_TYPE)"
echo "  Config:     ~/.claude/settings.json (hooks added)"
echo "  Manifest:   $MANIFEST_JSON (consumed by uninstall.sh)"
echo "  Benchmarks: $SCRIPT_DIR/benchmarks/ (6 benchmarks + A/B protocol)"
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
