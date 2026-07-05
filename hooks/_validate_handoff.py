#!/usr/bin/env python3
"""
Validate a role-agent handoff HTML file against the schema in
docs/role-agent-handoff-schema.md.

Usage: _validate_handoff.py <path> <expected-slug> <expected-role>

Prints a pipe-separated list of errors to stdout (empty stdout = pass).
Exit code is always 0 — the calling hook reads stdout to decide.
"""
import os
import sys
import re

# Reuse the shared override-reason validator. Same-directory import.
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)
try:
    from _validate_override_reason import validate_reason as _validate_reason
    from _validate_override_reason import log_override as _log_override
except ImportError:
    _validate_reason = None
    _log_override = None

if len(sys.argv) != 4:
    print("usage error")
    sys.exit(0)

path, expected_slug, expected_role = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
except Exception as e:
    print(f"unreadable: {e}")
    sys.exit(0)

errors = []
Q = r"[\"']"

# 1. <html data-handoff-version="1">
if not re.search(r"<html[^>]*\bdata-handoff-version\s*=\s*" + Q + r"1" + Q, content, re.I):
    errors.append("missing <html data-handoff-version='1'>")

# 2. Required <meta> attributes.
# NOTE: data-input-references must be PRESENT but may be EMPTY — the first
# handoff in a chain has no prior handoffs to reference (registry / schema
# reconciliation, evaluation M8; the old "present and non-empty" prose in the
# schema doc was self-contradictory and the table wins).
required_meta = [
    "data-from-role",
    "data-spec-slug",
    "data-step",
    "data-produced-at",
    "data-input-references",
]
for attr in required_meta:
    pat = r"<meta[^>]*\b" + re.escape(attr) + r"\s*=\s*" + Q + r"[^\"']*" + Q
    if not re.search(pat, content, re.I):
        errors.append(f"missing <meta {attr}=...>")

# 2b. Verdict vocabulary (docs/registry.md §4, evaluation M9): reviewer /
# coordinator roles MUST carry <meta data-verdict="..."> with a legal value.
# Producer/designer roles are exempt.
VERDICTS_BY_ROLE = {
    "security-architect": ("PASS", "FAIL-CRITICAL", "FAIL-SPEC-DRIFT"),
    "devops-architect": ("PASS", "FAIL-CRITICAL", "FAIL-SPEC-DRIFT"),
    "data-architect": ("PASS", "FAIL-CRITICAL", "FAIL-SPEC-DRIFT"),
    "qa-engineer": ("PASS", "FAIL-CRITICAL", "FAIL-SPEC-DRIFT"),
    "spec-sre-auditor": ("PASS", "FAIL-CRITICAL", "FAIL-SPEC-DRIFT"),
    "release-coordinator": ("READY-TO-CLOSE", "READY-WITH-CAVEATS", "BLOCKED"),
}
if expected_role in VERDICTS_BY_ROLE:
    legal = VERDICTS_BY_ROLE[expected_role]
    vm = re.search(
        r"<meta[^>]*\bdata-verdict\s*=\s*" + Q + r"\s*([^\"']*?)\s*" + Q,
        content,
        re.I,
    )
    if not vm:
        errors.append(
            f"missing <meta data-verdict=...> — registry §4: 'Every reviewer/"
            f"auditor/coordinator handoff MUST carry <meta data-verdict=\"...\">' "
            f"(legal values for {expected_role}: {' | '.join(legal)})"
        )
    elif vm.group(1).upper() not in legal:
        errors.append(
            f"data-verdict='{vm.group(1)}' is not legal for {expected_role} "
            f"(registry §4 allows: {' | '.join(legal)})"
        )

# 2c. Severity vocabulary (registry §5): data-severity must be one of
# critical | important | suggestion | spec-drift, and data-route-to is
# REQUIRED on critical and important asides (schema promise, evaluation M8).
LEGAL_SEVERITIES = {"critical", "important", "suggestion", "spec-drift"}
for _m in re.finditer(r"<aside\b[^>]*?>", content, re.I):
    _tag = _m.group(0)
    _sev_m = re.search(r"\bdata-severity\s*=\s*[\"']([^\"']*)[\"']", _tag, re.I)
    if not _sev_m:
        continue
    _sev = _sev_m.group(1).strip().lower()
    if _sev not in LEGAL_SEVERITIES:
        errors.append(
            f"data-severity='{_sev_m.group(1)}' is not legal "
            f"(registry §5: critical | important | suggestion | spec-drift)"
        )
        continue
    if _sev in ("critical", "important"):
        if not re.search(r"\bdata-route-to\s*=\s*[\"'][^\"']+[\"']", _tag, re.I):
            errors.append(
                f"{_sev} aside is missing data-route-to — registry §5 requires "
                f"a routing target on critical and important findings"
            )

# 3. Required <section data-role> blocks
for s in ("summary", "findings", "acceptance-criteria", "open-questions"):
    pat = r"<section[^>]*\bdata-role\s*=\s*" + Q + r"\s*" + re.escape(s) + r"\s*" + Q
    if not re.search(pat, content, re.I):
        errors.append(f"missing <section data-role=\"{s}\">")

# 4. data-spec-slug matches filename slug
m = re.search(
    r"<meta[^>]*\bdata-spec-slug\s*=\s*" + Q + r"\s*([a-z0-9_-]+)\s*" + Q,
    content,
    re.I,
)
if m and m.group(1) != expected_slug:
    errors.append(
        f"data-spec-slug='{m.group(1)}' but filename slug is '{expected_slug}'"
    )

# 5. data-from-role matches role expected by filename
m = re.search(
    r"<meta[^>]*\bdata-from-role\s*=\s*" + Q + r"\s*([a-z0-9_-]+)\s*" + Q,
    content,
    re.I,
)
if m and m.group(1) != expected_role:
    errors.append(
        f"data-from-role='{m.group(1)}' but filename role is '{expected_role}'"
    )

# 6. Critical unresolved <aside data-severity="critical" data-blocks-next-step="true">
critical_blockers = re.findall(
    r"<aside[^>]*\bdata-severity\s*=\s*"
    + Q
    + r"critical"
    + Q
    + r"[^>]*\bdata-blocks-next-step\s*=\s*"
    + Q
    + r"true"
    + Q,
    content,
    re.I,
)
if critical_blockers:
    errors.append(
        f"contains {len(critical_blockers)} unresolved critical-blocking <aside> — handoff says next step must not proceed"
    )


# 7. Resolution-pointer validation for asides flipped to blocks-next-step="false"
#
# 2026-05-27 dogfood caught: orchestrator flipped data-blocks-next-step="true"
# to "false" on a critical aside to bypass section 6, adding data-resolved-in /
# data-resolved-by / data-re-verified-in pointers that may or may not refer to
# real files. This section validates those pointers actually exist on disk and
# that the re-verify file doesn't carry its own unresolved critical-blocker on
# the same route.
#
# Override path: data-resolution-skip="<reason>" attribute on the aside.
def _attr(tag_str, attr):
    m = re.search(r"\b" + re.escape(attr) + r"\s*=\s*[\"']([^\"']*)[\"']", tag_str, re.I)
    return m.group(1) if m else None


# Resolve project root: handoff lives at <root>/specs/handoffs/<step>-<slug>-<role>.html
abs_handoff = os.path.abspath(path)
project_root = os.path.dirname(os.path.dirname(os.path.dirname(abs_handoff)))

# Match every <aside ...> opening tag (not just the regex from section 6 which
# only matches blocks-next-step=true)
aside_open = re.compile(r"<aside\b([^>]*?)>", re.I)
for m in aside_open.finditer(content):
    tag_attrs = m.group(0)
    severity = _attr(tag_attrs, "data-severity")
    if not severity or severity.lower() != "critical":
        continue
    blocks = _attr(tag_attrs, "data-blocks-next-step")
    if not blocks or blocks.lower() == "true":
        # blocks-next-step="true" already handled by section 6; missing attribute
        # is ambiguous — leave it alone.
        continue

    # blocks-next-step is "false" (or other non-true value) — validate resolution
    skip_reason = _attr(tag_attrs, "data-resolution-skip")
    if skip_reason is not None:
        # Override path — but only valid if the reason passes quality
        # validation. Prevents the "data-resolution-skip='documented'" bypass.
        if _validate_reason is not None:
            ok, info = _validate_reason(skip_reason)
            if not ok:
                errors.append(
                    f"data-resolution-skip reason failed quality check: {info}. Reason was: '{skip_reason[:200]}'"
                )
                continue
            if _log_override is not None:
                _log_override(
                    "_validate_handoff",
                    "data-resolution-skip",
                    "-",
                    skip_reason,
                    matched_kind=info,
                )
        # Valid override; preserved as audit trail in the file
        continue

    resolved_in = _attr(tag_attrs, "data-resolved-in")
    re_verified_in = _attr(tag_attrs, "data-re-verified-in")
    route = _attr(tag_attrs, "data-route-to") or ""

    if not resolved_in:
        errors.append(
            "critical aside flipped to data-blocks-next-step='false' is missing data-resolved-in pointer (cannot verify resolution)"
        )
        continue
    if not re_verified_in:
        errors.append(
            "critical aside flipped to data-blocks-next-step='false' is missing data-re-verified-in pointer (cannot verify the fix was reviewed)"
        )
        continue

    resolved_path = (
        resolved_in
        if os.path.isabs(resolved_in)
        else os.path.join(project_root, resolved_in)
    )
    if not os.path.isfile(resolved_path):
        errors.append(
            f"data-resolved-in='{resolved_in}' does not exist on disk (orphan pointer)"
        )
        continue

    rv_path = (
        re_verified_in
        if os.path.isabs(re_verified_in)
        else os.path.join(project_root, re_verified_in)
    )
    if not os.path.isfile(rv_path):
        errors.append(
            f"data-re-verified-in='{re_verified_in}' does not exist on disk (orphan pointer)"
        )
        continue

    # Re-verify file MUST NOT contain its own unresolved critical-blocker on
    # the same route. (Different routes = different findings = OK.)
    try:
        with open(rv_path, "r", encoding="utf-8") as rf:
            rv_content = rf.read()
    except Exception as e:
        errors.append(
            f"data-re-verified-in='{re_verified_in}' is unreadable: {e}"
        )
        continue

    rv_unresolved = False
    for rv_m in aside_open.finditer(rv_content):
        rv_tag = rv_m.group(0)
        if _attr(rv_tag, "data-severity") != "critical":
            continue
        rv_blocks = _attr(rv_tag, "data-blocks-next-step")
        if not rv_blocks or rv_blocks.lower() != "true":
            continue
        rv_route = _attr(rv_tag, "data-route-to") or ""
        # Match if same route (or either side has no route)
        if not route or not rv_route or rv_route == route:
            rv_unresolved = True
            break

    if rv_unresolved:
        errors.append(
            f"data-re-verified-in='{re_verified_in}' still contains an unresolved critical-blocking aside on route '{route or '(any)'}' — the fix was not actually re-verified"
        )

if errors:
    print("|".join(errors))
