#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write of @status(verified) on a spec when its fix-cycle handoffs
# are asymmetric — i.e., for any cycle N, an implementer fix handoff exists
# without a reviewer re-verification handoff (or vice versa).
#
# Symmetry rule: for each cycle N detected under specs/handoffs/, both must
# be true:
#   - at least one step-3.2-<slug>-<role>-fix-cycle-N.html (implementer fixed)
#   - at least one step-3.3-<slug>-<role>-cycle-N.html (reviewer re-verified)
#
# Catches the recurring failure mode (2026-05-26 SquashBuckler dogfood): an
# implementer agent dispatched in fix mode does the work but returns without
# writing its handoff, and the orchestrator synthesizes a fake artifact or
# moves on without re-verification. By the time @status(verified) is written,
# the asymmetry is detectable.
#
# Escape hatch: @fix-cycle-skip(N: reason) tag in spec content. Reason persists.
#
# Runs as PreToolUse hook on Edit/Write targeting specs/*.md files.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

file_path=$(json_get "$tool_use_json" ".tool.input.file_path" "")
[ -z "$file_path" ] && file_path=$(json_get "$tool_use_json" ".tool_input.file_path" "")

if [ -z "$file_path" ]; then
    echo '{}'
    exit 0
fi

if [[ "$file_path" != */specs/*.md ]]; then
    echo '{}'
    exit 0
fi

basename_file=$(basename "$file_path")
if [[ "$basename_file" == "system.md" ]] || [[ "$basename_file" == "arch.md" ]]; then
    echo '{}'
    exit 0
fi

new_content=$(json_get "$tool_use_json" ".tool.input.new_string" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.new_string" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool.input.content" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.content" "")

# Only trigger when @status(verified) is being written
if ! echo "$new_content" | grep -q "@status(verified)"; then
    echo '{}'
    exit 0
fi

# Build full spec view for skip-tag detection
if [ -f "$file_path" ]; then
    spec_content="$(cat "$file_path" 2>/dev/null || echo "") $new_content"
else
    spec_content="$new_content"
fi

# @trivial specs don't run fix-cycles
if echo "$spec_content" | grep -q "@trivial"; then
    echo '{}'
    exit 0
fi

slug="${basename_file%.md}"
spec_dir="$(dirname "$file_path")"
handoff_dir="$spec_dir/handoffs"

# No handoff dir => no fix-cycle ran (or first build) — let other hooks gate
if [ ! -d "$handoff_dir" ]; then
    echo '{}'
    exit 0
fi

# Discover the set of cycle numbers present for this slug
# Patterns examined:
#   step-3.2-<slug>-<role>-fix-cycle-N.html   (implementer fix output)
#   step-3.3-<slug>-<role>-cycle-N.html       (reviewer re-verify output)
cycles=$(ls "$handoff_dir" 2>/dev/null \
    | grep -E "^step-3\.[23]-${slug}-.+-(fix-)?cycle-[0-9]+\.html$" \
    | sed -E "s/.*-cycle-([0-9]+)\.html$/\1/" \
    | sort -u)

if [ -z "$cycles" ]; then
    # No fix-cycle handoffs at all — base-handoff hook handles non-cycle artifacts
    echo '{}'
    exit 0
fi

# Collect skipped cycles via @fix-cycle-skip(N: reason)
skipped_cycles=$(echo "$spec_content" | grep -oE "@fix-cycle-skip\([0-9]+:" | sed 's/@fix-cycle-skip(//; s/://' || true)

missing_pairs=()
for n in $cycles; do
    if echo "$skipped_cycles" | grep -qw "$n"; then
        continue
    fi
    impl_count=$(ls "$handoff_dir" 2>/dev/null \
        | grep -cE "^step-3\.2-${slug}-.+-fix-cycle-${n}\.html$" \
        || true)
    rev_count=$(ls "$handoff_dir" 2>/dev/null \
        | grep -cE "^step-3\.3-${slug}-.+-cycle-${n}\.html$" \
        || true)
    if [ "$impl_count" -eq 0 ]; then
        missing_pairs+=("cycle ${n}: reviewer re-verify handoff(s) exist but NO implementer fix handoff (step-3.2-${slug}-<role>-fix-cycle-${n}.html). Either the implementer agent skipped writing it (common failure mode) or the cycle wasn't actually run.")
    fi
    if [ "$rev_count" -eq 0 ]; then
        missing_pairs+=("cycle ${n}: implementer fix handoff(s) exist but NO reviewer re-verify handoff (step-3.3-${slug}-<reviewer>-cycle-${n}.html). The orchestrator must re-dispatch the original finders to confirm fixes.")
    fi
done

if [ ${#missing_pairs[@]} -eq 0 ]; then
    echo '{}'
    exit 0
fi

err_body=""
for m in "${missing_pairs[@]}"; do
    err_body="${err_body}  - ${m}\n"
done

cat >&2 <<EOF
BLOCKED: specs/${slug}.md is being marked @status(verified), but its fix-cycle handoff chain is asymmetric.

Detected cycles: $(echo $cycles | tr '\n' ' ')
Missing pairs:
${err_body}
Fix-cycle protocol (build/SKILL.md Step 3.3h):
  1. Implementer writes step-3.2-<slug>-<role>-fix-cycle-N.html
  2. Orchestrator re-dispatches original finders
  3. Reviewer writes step-3.3-<slug>-<role>-cycle-N.html

If the implementer agent returned without writing its handoff (recurring failure
mode caught here), re-dispatch it with: "Your prior dispatch returned without
writing specs/handoffs/step-3.2-${slug}-<role>-fix-cycle-N.html. That handoff
is the deliverable, not the verbal confirmation. Write it now."

To skip a specific cycle (rare — document why), add to the spec:
  @fix-cycle-skip(<N>: <reason>)
  e.g. @fix-cycle-skip(2: reviewer findings were withdrawn after re-investigation)
EOF
exit 2
