#!/usr/bin/env python3
"""
Validate override-tag reasons across the hook system.

2026-05-27 adversarial-pressure note: every override tag in the workflow
accepts any string as its reason. An agent under pressure can write
`@handoff-author-skip(frontend-engineer: needed)` or
`data-resolution-skip="documented"` and technically satisfy the syntax
while providing zero actual justification. This validator raises the bar:
reasons must clear length, content, and concrete-reference thresholds.

Validation rules:
  1. Length >= 30 chars after .strip()
  2. Must contain at least ONE concrete reference:
     - Commit SHA (7-40 hex chars, must include a digit OR be 8+ chars)
     - Beads ID (workflow-xyz, beads-abc, project-123)
     - File path (contains '/' and ends in an extension)
     - URL (https?://...)
     - Explicit user authorization ("user authorized", "per jon:", etc.)
  3. Stop-phrase blocklist: reasons that consist ONLY of generic phrases
     after stripping punctuation are rejected even at length 30+.

Audit log: every PASS is appended to ~/.claude/hooks/state/override-audit.log
so abuse patterns can be reviewed periodically.

Usage:
    _validate_override_reason.py <hook-name> <override-tag> <role-or-dash> <reason>

Exit codes:
    0  reason passes; entry written to audit log
    1  reason fails; stdout contains the failure message
    2  argv error
"""
import os
import re
import sys
from datetime import datetime, timezone

STATE_DIR = os.path.expanduser("~/.claude/hooks/state")
AUDIT_LOG = os.path.join(STATE_DIR, "override-audit.log")

MIN_LENGTH = 30

# Reasons that consist ENTIRELY of one of these strings (after lowercasing
# and stripping punctuation) are rejected as non-substantive. The list is
# deliberately small — we're not policing prose quality, just blocking the
# trivial cases that pass length-only checks (e.g., "covered elsewhere" is
# 17 chars but if a user pads it to 30 with whitespace or repetition, it
# still says nothing).
STOP_PHRASES = {
    "nothing", "nothing changed", "n/a", "na", "tbd", "todo", "todo later",
    "later", "trivial", "fine", "ok", "okay", "none", "skip", "bypass",
    "pass", "covered", "covered elsewhere", "see above", "see below",
    "as discussed", "documented", "obvious", "self-explanatory",
    "no comment", "no reason", "intentional",
}


def validate_reason(reason):
    """Returns (is_valid, error_message). On valid, error_message is empty."""
    if reason is None or reason == "":
        return False, "reason is empty"

    trimmed = reason.strip()

    if len(trimmed) < MIN_LENGTH:
        return False, (
            f"reason is {len(trimmed)} chars; minimum is {MIN_LENGTH}. "
            f"Reasons must include enough context for a future reviewer "
            f"to understand the bypass without re-reading the surrounding spec."
        )

    lowered = trimmed.lower()

    # Stop-phrase check: preserve '/' and '-' during cleaning so "n/a" stays
    # intact (otherwise it splits to "n a" and escapes the blocklist).
    cleaned = re.sub(r"[^\w\s/-]", " ", lowered)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    if cleaned in STOP_PHRASES:
        return False, f"reason is a stop phrase: '{cleaned}'"
    # Check if cleaned reduces to a single stop phrase repeated
    words = cleaned.split()
    if words:
        unique_words = set(words)
        joined = " ".join(sorted(unique_words))
        if joined in STOP_PHRASES or all(w in STOP_PHRASES for w in unique_words):
            return False, f"reason consists only of stop-phrase words: {sorted(unique_words)}"

    # Concrete-reference check
    has_concrete = False
    matched_kind = ""

    # 1. Commit SHA: 7-40 hex chars; must contain a digit OR be 8+ chars
    # (filters short hex-shaped words like "deceased" or "facade").
    for m in re.finditer(r"\b[a-f0-9]{7,40}\b", lowered):
        s = m.group(0)
        if any(c.isdigit() for c in s) or len(s) >= 8:
            has_concrete = True
            matched_kind = "commit-sha"
            break

    # 2. Beads ID: project-prefix + alphanumeric suffix. Common prefixes
    # explicit (workflow, beads, project) plus a general kebab pattern.
    if not has_concrete:
        if re.search(r"\b(workflow|beads|project)-[a-z0-9]{3,12}\b", lowered):
            has_concrete = True
            matched_kind = "beads-id"

    # 3. File path: contains '/' and ends in an extension (one or more
    # dotted alphanumeric segments). Catches src/foo/bar.ts, specs/x.md, etc.
    if not has_concrete:
        if re.search(r"[\w./-]+/[\w.-]+\.[a-zA-Z0-9]{1,8}\b", trimmed):
            has_concrete = True
            matched_kind = "file-path"

    # 4. URL
    if not has_concrete:
        if re.search(r"https?://\S+", trimmed):
            has_concrete = True
            matched_kind = "url"

    # 5. Explicit user authorization. Several phrasings accepted.
    if not has_concrete:
        if re.search(
            r"\buser\s+(authorized|approved|signed[ -]off|confirmed|directed|asked|said|requested)\b",
            lowered,
        ):
            has_concrete = True
            matched_kind = "user-authz"

    # 6. "per <name>:" or "per <name>," — explicit citation of a person
    if not has_concrete:
        if re.search(r"\bper\s+[a-zA-Z][\w-]*\s*[,:]", trimmed):
            has_concrete = True
            matched_kind = "per-name"

    if not has_concrete:
        return False, (
            "reason has no concrete reference. Include at least ONE of:\n"
            "  - a commit SHA (7+ hex chars, e.g. 'fixed in 9c88227')\n"
            "  - a beads ID (e.g. 'see workflow-abc1')\n"
            "  - a file path with extension (e.g. 'tracked in specs/foo.md')\n"
            "  - a URL\n"
            "  - explicit user authorization ('user authorized X', 'per <name>: X')"
        )

    return True, matched_kind


def log_override(hook_name, override_tag, role, reason, matched_kind):
    """Append an audit entry. Best-effort — never fail the validation on
    log-write errors (filesystem full, permission denied, etc.)."""
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        reason_oneline = reason.replace("\n", " ").replace("|", "/").strip()[:500]
        line = f"{timestamp}|{hook_name}|{override_tag}|{role or '-'}|{matched_kind}|{reason_oneline}\n"
        with open(AUDIT_LOG, "a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        pass  # logging is best-effort


def main():
    if len(sys.argv) < 5:
        print(
            "usage: _validate_override_reason.py <hook> <tag> <role-or-dash> <reason>",
            file=sys.stderr,
        )
        sys.exit(2)

    hook_name = sys.argv[1]
    override_tag = sys.argv[2]
    role = sys.argv[3] if sys.argv[3] != "-" else ""
    reason = sys.argv[4]

    is_valid, msg = validate_reason(reason)

    if is_valid:
        log_override(hook_name, override_tag, role, reason, matched_kind=msg)
        sys.exit(0)
    else:
        print(msg)
        sys.exit(1)


if __name__ == "__main__":
    main()
