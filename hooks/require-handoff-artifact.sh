#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write of @status(verified) on specs/*.md unless the expected
# role-agent handoff files exist and are schema-compliant.
#
# Schema reference: docs/role-agent-handoff-schema.md
# Path convention: specs/handoffs/<step>-<spec-slug>-<role>.html
#
# Expected handoffs per spec layer:
#   All specs (except @trivial):
#     step-2-<slug>-product-owner.html
#     step-2.5-<slug>-application-architect.html
#     step-3.3-<slug>-security-architect.html
#     step-3.3-<slug>-qa-engineer.html
#   @layer(ui), @layer(full-stack):
#     step-2.85-<slug>-uiux-designer.html
#     step-3.2-<slug>-frontend-engineer.html
#   @layer(api), @layer(full-stack):
#     step-3.2-<slug>-backend-engineer.html
#   @layer(cli) or @layer(infra):
#     step-3.2-<slug>-backend-engineer.html  (the closest match — generic implementer)
#   @touches-data ONLY (decision D2, evaluation M10):
#     step-3.3-<slug>-data-architect.html
#     (@layer(api|full-stack) alone no longer forces the data gate — a DB-free
#     proxy endpoint shouldn't pay a validated override. When the Technical
#     Context mentions DB terms but the tag is missing, a one-line advisory
#     suggests adding @touches-data instead of blocking.)
#
# Escape hatch: @handoff-skip(role: reason) tag in spec content, one per role
# to skip. Reason persists.
#
# Runs as PreToolUse hook on Edit/Write targeting specs/*.md files.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"
require_python_or_block "require-handoff-artifact.sh"

# Defensive: if the Python validator isn't installed (e.g. install.sh ran on
# an older version that only symlinked *.sh, or the file was manually removed),
# degrade gracefully. Without this guard, set -euo pipefail propagates the
# [Errno 2] from Python and aborts the script with exit 2, which the harness
# interprets as an empty block — a silent over-block that's hard to debug.
VALIDATOR="$HOOK_DIR/_validate_handoff.py"
if [ ! -f "$VALIDATOR" ]; then
    echo >&2 "require-handoff-artifact: validator not found at $VALIDATOR — allowing edit (run install.sh to restore)"
    echo '{}'
    exit 0
fi

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

# Build full spec view for tag detection
if [ -f "$file_path" ]; then
    spec_content="$(cat "$file_path" 2>/dev/null || echo "") $new_content"
else
    spec_content="$new_content"
fi

# Skip @trivial specs — typo fixes / renames don't need full handoff chain
if echo "$spec_content" | grep -q "@trivial"; then
    echo '{}'
    exit 0
fi

slug="${basename_file%.md}"
spec_dir="$(dirname "$file_path")"
project_root="$(dirname "$spec_dir")"
handoff_dir="$spec_dir/handoffs"

# Detect layer
layer=""
if echo "$spec_content" | grep -qE "@layer\(api\)"; then
    layer="api"
elif echo "$spec_content" | grep -qE "@layer\(ui\)"; then
    layer="ui"
elif echo "$spec_content" | grep -qE "@layer\(full-stack\)"; then
    layer="full-stack"
elif echo "$spec_content" | grep -qE "@layer\(cli\)"; then
    layer="cli"
elif echo "$spec_content" | grep -qE "@layer\(infra\)"; then
    layer="infra"
elif echo "$spec_content" | grep -qE "@layer\(gameplay\)"; then
    layer="gameplay"
fi

# Detect game project
# A game project has .claude/game-context.md at the project root. Any spec in
# such a project triggers the game-designer handoff requirement. UI specs that
# additionally carry @surface(game) route through game-ui-designer instead of
# uiux-designer.
is_game_project="no"
if [ -f "$project_root/.claude/game-context.md" ]; then
    is_game_project="yes"
fi

is_game_ui_spec="no"
if echo "$spec_content" | grep -qE "@surface\(game\)"; then
    is_game_ui_spec="yes"
fi

# Build list of expected handoffs based on layer + data tag + game-context
expected=()
expected+=("step-2-${slug}-product-owner.html")

# Game-designer slot at step-2.3 (after PO, before app-architect)
# Required when the project is a game project.
if [ "$is_game_project" = "yes" ]; then
    expected+=("step-2.3-${slug}-game-designer.html")
fi

expected+=("step-2.5-${slug}-application-architect.html")

# Level / narrative / systems designers at step-2.7 (parallel, after game-designer)
# Required when the project is a game project AND the spec is not @trivial.
if [ "$is_game_project" = "yes" ]; then
    expected+=("step-2.7-${slug}-level-designer.html")
    expected+=("step-2.7-${slug}-narrative-designer.html")
    expected+=("step-2.7-${slug}-systems-designer.html")
fi

expected+=("step-3.3-${slug}-security-architect.html")
expected+=("step-3.3-${slug}-devops-architect.html")
expected+=("step-3.3-${slug}-qa-engineer.html")

case "$layer" in
    "ui"|"full-stack")
        # @surface(game) routes through game-ui-designer; default uiux-designer
        if [ "$is_game_ui_spec" = "yes" ]; then
            expected+=("step-2.85-${slug}-game-ui-designer.html")
        else
            expected+=("step-2.85-${slug}-uiux-designer.html")
        fi
        expected+=("step-3.2-${slug}-frontend-engineer.html")
        ;;
esac
case "$layer" in
    "api"|"full-stack"|"cli"|"infra"|"gameplay")
        expected+=("step-3.2-${slug}-backend-engineer.html")
        ;;
esac

# data-architect required ONLY when the spec is tagged @touches-data
# (decision D2 / evaluation M10 — @layer(api|full-stack) alone no longer
# forces the gate). When the tag is absent but the Technical Context section
# mentions DB terms, emit a one-line advisory suggesting the tag.
touches_data="no"
data_advisory=""
if echo "$spec_content" | grep -q "@touches-data"; then
    touches_data="yes"
elif [ "$layer" = "api" ] || [ "$layer" = "full-stack" ]; then
    tech_context=$(echo "$spec_content" | sed -n '/^## Technical Context/,/^## /p' 2>/dev/null || echo "")
    if echo "$tech_context" | grep -qiE '(database|migration|schema|sql|postgres|mysql|sqlite|mongo|redis|dynamodb| orm |query plan|table[s]? |index(es)? )'; then
        data_advisory="ADVISORY: specs/${slug}.md (@layer ${layer}) has no @touches-data tag but its Technical Context mentions database terms — if it touches persistent data, add @touches-data so the data-architect gate applies (registry §8)."
    fi
fi
if [ "$touches_data" = "yes" ]; then
    expected+=("step-3.3-${slug}-data-architect.html")
fi

# Collect skipped roles via @handoff-skip(role: reason); validate each reason
# via the shared override-reason validator. A trivial reason like
# "@handoff-skip(security-architect: n/a)" gets rejected.
skipped_roles=""
REASON_VALIDATOR="$HOOK_DIR/_validate_override_reason.py"

while IFS= read -r match; do
    [ -z "$match" ] && continue
    role_match=$(echo "$match" | sed -E "s/@handoff-skip\(([a-z-]+):.*/\1/")
    reason_match=$(echo "$match" | sed -E "s/@handoff-skip\([a-z-]+:[[:space:]]*(.*)\)$/\1/")
    if [ -f "$REASON_VALIDATOR" ]; then
        if ! validation_error=$("$PYTHON" "$REASON_VALIDATOR" "require-handoff-artifact" "@handoff-skip" "$role_match" "$reason_match" 2>&1); then
            cat >&2 <<EOF
BLOCKED: @handoff-skip(${role_match}: ...) override reason failed quality validation.

${validation_error}

Provided reason: '${reason_match}'

Override reasons must include a concrete artifact reference (commit SHA, beads ID, file path, URL, or user authorization). The skip persists in the spec as audit trail — make it auditable. Per docs/role-agent-handoff-schema.md, vague reasons like 'n/a' or 'covered elsewhere' are rejected.
EOF
            exit 2
        fi
    fi
    skipped_roles="${skipped_roles}${role_match} "
done < <(echo "$spec_content" | grep -oE "@handoff-skip\([a-z-]+:[^)]+\)" || true)

# Check each expected handoff
missing=()
malformed=()
for handoff_filename in "${expected[@]}"; do
    # Extract role from filename: step-X-slug-role.html → role
    # We stripped step-X- prefix and -slug- prefix; remainder before .html is role
    role=$(echo "$handoff_filename" | sed -E "s/^step-[0-9.]+-${slug}-//" | sed 's/\.html$//')
    if echo "$skipped_roles" | grep -qw "$role"; then
        continue
    fi
    handoff_path="$handoff_dir/$handoff_filename"
    if [ ! -f "$handoff_path" ]; then
        missing+=("$handoff_filename")
        continue
    fi
    # Validate schema via Python helper
    validation_result=$("$PYTHON" "$VALIDATOR" "$handoff_path" "$slug" "$role" 2>/dev/null || true)
    if [ -n "$validation_result" ]; then
        malformed+=("$handoff_filename: $validation_result")
    fi
done

# Build response
if [ ${#missing[@]} -eq 0 ] && [ ${#malformed[@]} -eq 0 ]; then
    if [ -n "$data_advisory" ]; then
        json_encode_context "$data_advisory" "PreToolUse"
    else
        echo '{}'
    fi
    exit 0
fi

# Real newlines (not literal \n escapes — the harness renders those as raw
# backslash-n text in the error the model sees; harness-behavior.md).
NL='
'
err_body=""
if [ ${#missing[@]} -gt 0 ]; then
    err_body="${err_body}${NL}Missing handoff files (specs/handoffs/):${NL}"
    for m in "${missing[@]}"; do
        err_body="${err_body}  - ${m}${NL}"
    done
fi
if [ ${#malformed[@]} -gt 0 ]; then
    err_body="${err_body}${NL}Schema violations:${NL}"
    for m in "${malformed[@]}"; do
        err_body="${err_body}  - ${m}${NL}"
    done
fi

cat >&2 <<EOF
BLOCKED: specs/${slug}.md is being marked @status(verified), but its role-agent handoff chain is incomplete.

Detected @layer: ${layer:-(none — add @layer tag first)}
${err_body}
Dispatch the missing role agents and produce their handoff files per docs/role-agent-handoff-schema.md. To skip a specific role (rare — document the reason), add to the spec content:
  @handoff-skip(<role-slug>: <concise reason>)
  e.g. @handoff-skip(security-architect: spec is a UI text-only copy change, no security surface)
${data_advisory}
EOF
exit 2
