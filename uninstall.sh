#!/usr/bin/env bash
set -euo pipefail

# Uninstall the Adaptive Developer Workflow for Claude Code
# Usage: ./uninstall.sh
#
# Manifest-driven: consumes ~/.claude/workflow-install-manifest.json written by
# install.sh and reverses exactly what it recorded:
# 1. Removes every link the manifest lists (only if it still points into the
#    repo the manifest names), restoring any .pre-workflow backup next to it
# 2. Surgically removes exactly the settings hook commands install added
#    (command-level: a matcher entry that still contains non-workflow commands
#    is preserved with those commands intact)
# 3. Reverses the superpowers-disable step if the manifest says we did it
# 4. Deletes the manifest

CLAUDE_DIR="${HOME}/.claude"
BACKUP_SUFFIX=".pre-workflow"
MANIFEST_JSON="$CLAUDE_DIR/workflow-install-manifest.json"
LEGACY_MANIFEST="$CLAUDE_DIR/.workflow-manifest"

echo "=== Adaptive Developer Workflow Uninstaller ==="
echo ""

if [ ! -f "$MANIFEST_JSON" ]; then
    echo "no manifest — run install.sh once (it is idempotent) to generate one, then uninstall"
    exit 1
fi

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

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python 3 is required to uninstall safely and was not found."
    echo "Uninstall must parse the JSON manifest and surgically edit"
    echo "~/.claude/settings.json; doing that without a JSON parser risks"
    echo "deleting your own hooks or files. Refusing to guess."
    echo "Install Python 3 (https://www.python.org/downloads/) and re-run."
    exit 1
fi

# Validate the manifest itself before acting on it
if ! "$PYTHON" -c "import json,sys; json.load(open(sys.argv[1]))" "$MANIFEST_JSON" 2>/dev/null; then
    echo "ERROR: $MANIFEST_JSON is not valid JSON. Refusing to act on a corrupt"
    echo "manifest. Re-run install.sh (it is idempotent and rewrites the"
    echo "manifest), then run uninstall.sh again."
    exit 1
fi

REPO="$("$PYTHON" -c "import json,sys; print(json.load(open(sys.argv[1]))['repo'])" "$MANIFEST_JSON")"
echo "Manifest found. Install source repo: $REPO"
echo ""

STATE_TMP="$(mktemp -d)"
trap 'rm -rf "$STATE_TMP"' EXIT

# Print the absolute resolved target of a symlink (one level; install creates
# direct absolute links).
resolve_link() {
    local raw
    raw="$(readlink "$1")"
    case "$raw" in
        /*) printf '%s\n' "$raw" ;;
        *)  printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd)" "$raw" ;;
    esac
}

# 1. Remove links listed in the manifest
echo "[1/4] Removing installed links..."
LINKS_FILE="$STATE_TMP/links.txt"
"$PYTHON" -c "
import json, sys
m = json.load(open(sys.argv[1]))
for l in m.get('links', []):
    print('%s\t%s' % (l['dest'], l['source']))
" "$MANIFEST_JSON" > "$LINKS_FILE"

removed=0
skipped=0
restored=0
while IFS="$(printf '\t')" read -r dest source; do
    [ -n "$dest" ] || continue
    if [ -L "$dest" ]; then
        resolved="$(resolve_link "$dest")"
        case "$resolved" in
            "$REPO"/*)
                rm -f "$dest"
                removed=$((removed + 1))
                ;;
            *)
                echo "  - skipping $dest (symlink no longer points into $REPO — not ours)"
                skipped=$((skipped + 1))
                ;;
        esac
    elif [ -e "$dest" ] && [ -e "$source" ] && [ "$dest" -ef "$source" ]; then
        # Windows hard-link install: same inode as the repo source
        rm -f "$dest"
        removed=$((removed + 1))
    elif [ -e "$dest" ]; then
        echo "  - skipping $dest (regular file, not a link into the repo — not ours)"
        skipped=$((skipped + 1))
    fi
    # Restore a backup install made, but only into a now-vacant slot
    if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
        if [ -e "${dest}${BACKUP_SUFFIX}" ] || [ -L "${dest}${BACKUP_SUFFIX}" ]; then
            mv -f "${dest}${BACKUP_SUFFIX}" "$dest"
            restored=$((restored + 1))
            echo "  - restored $(basename "$dest") from backup"
        fi
    fi
done < "$LINKS_FILE"
echo "  - $removed links removed, $restored backups restored, $skipped skipped"

# 2. Clean up directories install created, if now empty (deepest first)
echo "[2/4] Cleaning up empty directories..."
cut -f1 "$LINKS_FILE" | while read -r dest; do
    [ -n "$dest" ] || continue
    dirname "$dest"
done | sort -ur | while read -r d; do
    case "$d" in
        "$CLAUDE_DIR"/skills/*|"$CLAUDE_DIR"/agents|"$CLAUDE_DIR"/hooks)
            rmdir "$d" 2>/dev/null || true
            ;;
    esac
done
echo "  - Done"

# 3. Remove exactly our hook commands from settings.json + reverse superpowers
echo "[3/4] Removing workflow hook commands from settings.json..."
SETTINGS_FILE="$("$PYTHON" -c "import json,sys; print(json.load(open(sys.argv[1])).get('settings_file',''))" "$MANIFEST_JSON")"
if [ -z "$SETTINGS_FILE" ]; then
    SETTINGS_FILE="$CLAUDE_DIR/settings.json"
fi

if [ ! -f "$SETTINGS_FILE" ]; then
    echo "  - No settings.json found, nothing to clean up"
else
    if ! "$PYTHON" -c "import json,sys; json.load(open(sys.argv[1]))" "$SETTINGS_FILE" 2>/dev/null; then
        echo "ERROR: $SETTINGS_FILE is not valid JSON, so the workflow hook"
        echo "commands cannot be removed safely. Links have already been removed."
        echo "Fix the JSON, then re-run uninstall.sh (the manifest was kept so"
        echo "the settings cleanup can complete)."
        exit 1
    fi
    "$PYTHON" -c "
import json, sys

settings_path, manifest_path = sys.argv[1], sys.argv[2]

with open(manifest_path) as f:
    manifest = json.load(f)
with open(settings_path) as f:
    settings = json.load(f)

# --- Command-level surgery: remove exactly the commands install added. ---
# Never delete a whole matcher entry that still contains non-workflow commands.
targets = {}
for c in manifest.get('settings_hooks', []):
    targets.setdefault((c['event'], c.get('matcher', '')), set()).add(c['command'])

hooks = settings.get('hooks', {})
removed = 0
for event in list(hooks.keys()):
    kept_entries = []
    for entry in hooks[event]:
        cmds = targets.get((event, entry.get('matcher', '')))
        if cmds:
            before = entry.get('hooks', [])
            after = [h for h in before if h.get('command', '') not in cmds]
            removed += len(before) - len(after)
            entry['hooks'] = after
        if entry.get('hooks'):
            kept_entries.append(entry)
    if kept_entries:
        hooks[event] = kept_entries
    else:
        del hooks[event]

if hooks:
    settings['hooks'] = hooks
elif 'hooks' in settings:
    del settings['hooks']

print('  - Removed %d workflow hook commands from settings.json' % removed)
print('  - User hooks preserved')

# --- Reverse the superpowers-disable step if we performed it. ---
sp = manifest.get('superpowers', {})
if sp.get('disabled_by_us'):
    key = 'superpowers@claude-plugins-official'
    plugins = settings.get('enabledPlugins', {})
    if plugins.get(key) is False:  # only touch it if still as we left it
        prior = sp.get('prior_value', None)
        if prior is None:
            del plugins[key]
        else:
            plugins[key] = prior
        if plugins:
            settings['enabledPlugins'] = plugins
        elif 'enabledPlugins' in settings:
            del settings['enabledPlugins']
        print('  - Reversed superpowers-disable (restored to pre-install state)')
    else:
        print('  - Superpowers setting changed since install, leaving as-is')

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
" "$SETTINGS_FILE" "$MANIFEST_JSON"

    if [ -f "${SETTINGS_FILE}${BACKUP_SUFFIX}" ]; then
        echo "  - Pre-workflow settings backup kept at ${SETTINGS_FILE}${BACKUP_SUFFIX}"
        echo "    (settings were surgically cleaned instead of restored wholesale;"
        echo "    the backup is safe to delete)"
    fi
fi

# 4. Delete the manifest (and any legacy manifest from older installs)
echo "[4/4] Removing manifest..."
rm -f "$MANIFEST_JSON" "$LEGACY_MANIFEST"
echo "  - Done"

echo ""
echo "=== Uninstall Complete ==="
echo ""
echo "Restart Claude Code (or /clear) for changes to take effect."
