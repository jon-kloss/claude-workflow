#!/usr/bin/env bash
set -euo pipefail

# Clear the session reads tracking file on session start/clear/compact.
# This ensures each session starts fresh - reads from previous sessions
# don't carry over.

READS_DIR="${HOME}/.claude/hooks/state"
READS_FILE="${READS_DIR}/session-reads.txt"
AGENTS_FILE="${READS_DIR}/session-agents.log"
SKILLS_FILE="${READS_DIR}/session-skills.log"
INFLIGHT_FILE="${READS_DIR}/verifier-inflight.txt"

mkdir -p "$READS_DIR"

# Clear the files (truncate, don't delete - avoids race conditions)
> "$READS_FILE"
> "$AGENTS_FILE"
> "$SKILLS_FILE"
> "$INFLIGHT_FILE"

echo '{}'
