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
#     step-4.1-<slug>-qa-engineer.html
#   @layer(ui), @layer(full-stack):
#     step-2.85-<slug>-uiux-designer.html
#     step-3.2-<slug>-frontend-engineer.html
#   @layer(api), @layer(full-stack):
#     step-3.2-<slug>-backend-engineer.html
#   @layer(cli) or @layer(infra):
#     step-3.2-<slug>-backend-engineer.html  (the closest match — generic implementer)
#
# Escape hatch: @handoff-skip(role: reason) tag in spec content, one per role
# to skip. Reason persists.
#
# Runs as PreToolUse hook on Edit/Write targeting specs/*.md files.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

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
fi

# Build list of expected handoffs based on layer + data tag
expected=()
expected+=("step-2-${slug}-product-owner.html")
expected+=("step-2.5-${slug}-application-architect.html")
expected+=("step-3.3-${slug}-security-architect.html")
expected+=("step-3.3-${slug}-devops-architect.html")
expected+=("step-3.3-${slug}-qa-engineer.html")

case "$layer" in
    "ui"|"full-stack")
        expected+=("step-2.85-${slug}-uiux-designer.html")
        expected+=("step-3.2-${slug}-frontend-engineer.html")
        ;;
esac
case "$layer" in
    "api"|"full-stack"|"cli"|"infra")
        expected+=("step-3.2-${slug}-backend-engineer.html")
        ;;
esac

# data-architect required when:
#   - spec is explicitly tagged @touches-data, OR
#   - spec is @layer(api) or @layer(full-stack) (these implicitly touch data)
touches_data="no"
if echo "$spec_content" | grep -q "@touches-data"; then
    touches_data="yes"
elif [ "$layer" = "api" ] || [ "$layer" = "full-stack" ]; then
    touches_data="yes"
fi
if [ "$touches_data" = "yes" ]; then
    expected+=("step-3.3-${slug}-data-architect.html")
fi

# Collect skipped roles via @handoff-skip(role: reason)
skipped_roles=$(echo "$spec_content" | grep -oE "@handoff-skip\([a-z-]+:" | sed 's/@handoff-skip(//; s/://' || true)

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
    echo '{}'
    exit 0
fi

err_body=""
if [ ${#missing[@]} -gt 0 ]; then
    err_body="${err_body}\nMissing handoff files (specs/handoffs/):\n"
    for m in "${missing[@]}"; do
        err_body="${err_body}  - ${m}\n"
    done
fi
if [ ${#malformed[@]} -gt 0 ]; then
    err_body="${err_body}\nSchema violations:\n"
    for m in "${malformed[@]}"; do
        err_body="${err_body}  - ${m}\n"
    done
fi

cat >&2 <<EOF
BLOCKED: specs/${slug}.md is being marked @status(verified), but its role-agent handoff chain is incomplete.

Detected @layer: ${layer:-(none — add @layer tag first)}
${err_body}
Dispatch the missing role agents and produce their handoff files per docs/role-agent-handoff-schema.md. To skip a specific role (rare — document the reason), add to the spec content:
  @handoff-skip(<role-slug>: <concise reason>)
  e.g. @handoff-skip(security-architect: spec is a UI text-only copy change, no security surface)
EOF
exit 2
