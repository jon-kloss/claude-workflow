#!/usr/bin/env bash
set -euo pipefail

# Clear the session reads tracking file on session start/clear/compact.
# This ensures each session starts fresh - reads from previous sessions
# don't carry over.

READS_DIR="${HOME}/.claude/hooks/state"
READS_FILE="${READS_DIR}/session-reads.txt"

mkdir -p "$READS_DIR"

# Clear the file (truncate, don't delete - avoids race conditions)
> "$READS_FILE"

echo '{}'
