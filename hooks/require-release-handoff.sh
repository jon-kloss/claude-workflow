#!/usr/bin/env bash
set -euo pipefail

# Block `bd close <epic-id>` commands when the release-coordinator handoff is
# missing or its verdict is BLOCKED.
#
# Pairs with the role-agent system from docs/role-agent-handoff-schema.md.
# Looks for: specs/handoffs/step-4.2-<epic-id>-release-coordinator.html
#
# ID extraction (evaluation H9): IDs are taken from the ARGUMENT POSITIONS
# after `close` — `cd my-project && bd close epic-123` gates epic-123, not
# my-project. Multi-ID closes (`bd close a b c`) gate EVERY id.
#
# Verdict (evaluation H10): parsed from <meta data-verdict="..."> per
# docs/registry.md §4. The old first-token text search runs only as fallback
# when no data-verdict meta exists at all.
#
# Overrides (evaluation H4), honored in BOTH the missing-handoff and
# BLOCKED-verdict branches, reasons validated by _validate_override_reason.py:
#   - a comment on the epic (bd comments add) whose body contains "RELEASE-SKIP: <reason>"
#   - @release-skip(<reason>) tag inside any spec under specs/
#
# Heuristic for "is this an epic close?":
#   bd close <id> where `bd show <id>` title line contains "[epic]"
#
# Runs as PreToolUse hook on Bash.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"
require_python_or_block "require-release-handoff.sh"

VALIDATOR="$HOOK_DIR/_validate_override_reason.py"

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

cmd=$(json_get "$tool_use_json" ".tool.input.command" "")
[ -z "$cmd" ] && cmd=$(json_get "$tool_use_json" ".tool_input.command" "")

if [ -z "$cmd" ]; then
    echo '{}'
    exit 0
fi

# Only intercept bd close in command position (start, or after && ; | or an
# opening paren) — a mention inside an echo string must not fire.
if ! echo "$cmd" | grep -qE '(^|[;&|(])[[:space:]]*bd[[:space:]]+close([[:space:]]|$)'; then
    echo '{}'
    exit 0
fi

# Extract ids from the argument positions after `close`: take the text of
# each `bd close ...` segment up to the next command separator, then keep
# id-shaped tokens (skips flags like --reason=...).
target_ids=$(echo "$cmd" \
    | grep -oE 'bd[[:space:]]+close[[:space:]]+[^;&|]*' \
    | sed -E 's/^bd[[:space:]]+close[[:space:]]+//' \
    | tr '[:space:]' '\n' \
    | grep -E '^[a-z]+-[a-z0-9]{2,}$' \
    | sort -u || true)

if [ -z "$target_ids" ]; then
    echo '{}'
    exit 0
fi

# Needs bd in PATH for the epic check
if ! command -v bd >/dev/null 2>&1; then
    echo '{}'
    exit 0
fi

# has_release_override <epic-id>
# Returns 0 when a QUALITY-VALIDATED override exists for this epic:
#   1. an epic comment (bd comments) containing "RELEASE-SKIP: <reason>"
#   2. @release-skip(<reason>) tag in any spec under a specs/ dir
# Sets $override_hint to a diagnostic when an override was FOUND but its
# reason failed quality validation (so the block message can explain).
override_hint=""
has_release_override() {
    local id="$1"
    local comments reason tag spec_file sd

    comments=$(bd comments "$id" 2>/dev/null || echo "")
    # Accept if ANY RELEASE-SKIP comment carries a quality-validated reason
    # (a rejected earlier attempt must not shadow a later valid one).
    while IFS= read -r skip_line; do
        [ -z "$skip_line" ] && continue
        reason=$(echo "$skip_line" | sed -E 's/^RELEASE-SKIP:[[:space:]]*//')
        [ -z "$reason" ] && continue
        if [ -f "$VALIDATOR" ]; then
            if "$PYTHON" "$VALIDATOR" "require-release-handoff" "RELEASE-SKIP" "$id" "$reason" >/dev/null 2>&1; then
                return 0
            fi
            override_hint="A RELEASE-SKIP comment exists on ${id} but its reason failed quality validation (needs >=30 chars + a concrete reference: commit SHA, beads ID, file path, URL, or user authorization). Reason was: '${reason}'"
        else
            return 0
        fi
    done <<EOF
$(echo "$comments" | grep -oE 'RELEASE-SKIP:.*' || true)
EOF

    for sd in $(find . -maxdepth 4 -type d -name specs 2>/dev/null); do
        for spec_file in "$sd"/*.md; do
            [ -f "$spec_file" ] || continue
            while IFS= read -r tag; do
                [ -z "$tag" ] && continue
                reason=$(echo "$tag" | sed -E 's/^@release-skip\([[:space:]]*//; s/\)$//')
                if [ -f "$VALIDATOR" ]; then
                    if "$PYTHON" "$VALIDATOR" "require-release-handoff" "@release-skip" "$id" "$reason" >/dev/null 2>&1; then
                        return 0
                    fi
                    override_hint="An @release-skip tag exists in ${spec_file} but its reason failed quality validation (needs >=30 chars + a concrete reference). Reason was: '${reason}'"
                else
                    return 0
                fi
            done <<TAGEOF
$(grep -oE '@release-skip\([^)]+\)' "$spec_file" 2>/dev/null || true)
TAGEOF
        done
    done
    return 1
}

# gate_epic <epic-id> [trigger-note]
# Applies the release gate to one epic. trigger-note, when set, explains that
# the close command named a child, not the epic (molecule auto-close case).
# Returns 0 to allow; prints a block message and exits 2 to block.
gate_epic() {
    target_id="$1"
    trigger_note="${2:-}"
    intro="bd close ${target_id} (epic)"
    [ -n "$trigger_note" ] && intro="$trigger_note"

    # Check for handoff file. Look in any specs/handoffs/ under cwd.
    handoff_path=""
    for candidate in $(find . -maxdepth 4 -type d -name handoffs 2>/dev/null); do
        f="${candidate}/step-4.2-${target_id}-release-coordinator.html"
        if [ -f "$f" ]; then
            handoff_path="$f"
            break
        fi
    done

    if [ -z "$handoff_path" ]; then
        if has_release_override "$target_id"; then
            return 0
        fi
        cat >&2 <<EOF
BLOCKED: ${intro} requires a release-coordinator handoff at specs/handoffs/step-4.2-${target_id}-release-coordinator.html

Dispatch the release-coordinator role agent before closing the epic:
  Agent(subagent_type: release-coordinator, prompt: 'You are running Step 4.2 (final verification) for epic ${target_id}. Verify all spec @status(verified), all handoff chains, all CUJ tests, rollback plan. Produce handoff at specs/handoffs/step-4.2-${target_id}-release-coordinator.html with <meta data-verdict> READY-TO-CLOSE / READY-WITH-CAVEATS / BLOCKED.')

To override (rare — the reason is quality-validated and must include a concrete reference):
  bd comments add ${target_id} 'RELEASE-SKIP: <reason>'
  or add @release-skip(<reason>) to a spec in specs/.
${override_hint}
EOF
        exit 2
    fi

    # Handoff exists — read the verdict from <meta data-verdict="..."> per
    # registry §4; fall back to a first-token text search ONLY when no
    # data-verdict meta exists (legacy handoffs).
    verdict=$("$PYTHON" -c "
import sys, re
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    content = f.read()
m = re.search(r'<meta[^>]*data-verdict\s*=\s*[\"\']([^\"\']*)[\"\']', content, re.I)
if m:
    print(m.group(1).strip().upper() or 'MISSING')
else:
    m = re.search(r'\bREADY-TO-CLOSE\b|\bREADY-WITH-CAVEATS\b|\bBLOCKED\b', content)
    print(m.group(0) if m else 'MISSING')
" "$handoff_path" 2>/dev/null) || verdict="MISSING"

    case "$verdict" in
        "READY-TO-CLOSE"|"READY-WITH-CAVEATS")
            return 0
            ;;
        "BLOCKED")
            if has_release_override "$target_id"; then
                return 0
            fi
            cat >&2 <<EOF
BLOCKED: ${intro} — release-coordinator verdict for epic ${target_id} is BLOCKED.

Handoff: ${handoff_path}

Resolve the blockers documented in the handoff's findings section before closing the epic. To override (rare — the reason is quality-validated and must include a concrete reference):
  bd comments add ${target_id} 'RELEASE-SKIP: <reason>'
  or add @release-skip(<reason>) to a spec in specs/.
${override_hint}
EOF
            exit 2
            ;;
        *)
            cat >&2 <<EOF
BLOCKED: release-coordinator handoff at ${handoff_path} has no legal verdict (expected <meta data-verdict="READY-TO-CLOSE|READY-WITH-CAVEATS|BLOCKED"> per docs/registry.md §4).

Either the dispatch was incomplete or the handoff was hand-edited. Re-dispatch the release-coordinator or restore the verdict meta.
EOF
            exit 2
            ;;
    esac
}

# Build the set of epics whose release gate this close must satisfy:
#   - direct: `bd close <epic>`
#   - indirect (workflow-fx8r): closing the LAST open child of an epic triggers
#     beads' molecule auto-close, which promotes the epic to closed WITHOUT a
#     `bd close <epic>` command — so the PreToolUse gate never sees the epic id.
#     Detect it here and gate the parent before the child close is allowed.
# gated_epics accumulates ids already handled so a multi-id command doesn't
# gate the same epic twice.
gated_epics=""
already_gated() { case " $gated_epics " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

for target_id in $target_ids; do
    show_out=$(bd show "$target_id" 2>/dev/null || echo "")
    [ -z "$show_out" ] && continue

    # Direct epic close. Match "[epic]" in the TITLE line only (the PARENT /
    # CHILDREN sections list related epics that would false-positive a
    # whole-output grep).
    if echo "$show_out" | head -n 1 | grep -qiE '\[epic\]'; then
        already_gated "$target_id" || { gate_epic "$target_id"; gated_epics="$gated_epics $target_id"; }
        continue
    fi

    # Non-epic: find its parent epic (PARENT section) and decide whether
    # closing this id (together with any sibling ids in the same command)
    # completes the epic and triggers auto-promotion.
    parent=$(echo "$show_out" | awk '/^PARENT/{p=1;next} p&&/↑/{print;exit}' \
             | grep -oE '[a-z]+-[a-z0-9]{3,}' | head -1)
    [ -z "$parent" ] && continue
    already_gated "$parent" && continue

    pshow=$(bd show "$parent" 2>/dev/null || echo "")
    # Open (non-closed, glyph not ✓) child ids under the epic's CHILDREN block.
    open_children=$(echo "$pshow" | awk '/CHILDREN/{c=1;next} c&&/↳/{if ($0 !~ /✓/) print}' \
                    | grep -oE '[a-z]+-[a-z0-9]{3,}')
    # Would any open child remain OPEN after this close command runs?
    remaining=""
    for oc in $open_children; do
        case " $target_ids " in *" $oc "*) : ;; *) remaining="$remaining $oc" ;; esac
    done
    # No open child remains => this close completes the epic => it auto-promotes.
    if [ -z "$(echo $remaining | tr -d '[:space:]')" ]; then
        note="Closing ${target_id} completes epic ${parent}, which beads will auto-close (molecule promotion). That epic close"
        gate_epic "$parent" "$note"
        gated_epics="$gated_epics $parent"
    fi
done

echo '{}'
