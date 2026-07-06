#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: reset THIS session's hook state directory.
#
# State is keyed by <sha1(cwd)>/<session_id> (see _common.sh state_dir), so
# one session's start can no longer wipe another session's evidence
# (evaluation H5 / harness-behavior.md fact 10 — the old global files were
# truncated by ANY session start, erasing verifier/dispatch records mid-epic).
#
# Source handling (payload `source` field, per docs/harness-behavior.md):
#   startup | clear -> truncate this session's state dir (fresh session)
#   compact         -> RETAIN state. Compaction is not a new session; wiping
#                      here erased the record that verifier agents ran and
#                      falsely blocked the next @status(verified) write.
#   anything else   -> retain (conservative).

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Advisory hook: exit quietly when python is unavailable (fail-open per E6).
if [ -z "${PYTHON:-}" ]; then
    exit 0
fi

if ! read -t 2 -r payload_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$payload_json"; then
    echo '{}'
    exit 0
fi

source_val=$(json_get "$payload_json" ".source" "")

case "$source_val" in
    startup|clear)
        STATE_DIR="$(state_dir "$payload_json")"
        # Truncate only files inside THIS session's keyed directory.
        for f in "$STATE_DIR"/*; do
            [ -f "$f" ] && > "$f"
        done
        ;;
    *)
        # compact (or unknown): retain state.
        ;;
esac

echo '{}'
