#!/usr/bin/env bash
set -euo pipefail

# Require every spec going to @status(approved|implemented|verified) to have
# an explicit @layer(api|ui|full-stack|cli|infra) tag.
#
# Without this hook, an agent could remove the @layer tag (and the
# ## UI Design section) from a UI spec to evade require-ui-tests.sh and
# claim-vs-call-audit.sh, both of which only fire when a UI signal is present.
#
# The @layer tag is required by design/SKILL.md decomposition step and
# documented in gherkin-spec-reference.md.
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

# Only trigger when the edit introduces or maintains a non-draft status
if ! echo "$new_content" | grep -qE "@status\((approved|implemented|verified)\)"; then
    echo '{}'
    exit 0
fi

# Build full spec view (existing file + new content)
if [ -f "$file_path" ]; then
    spec_content="$(cat "$file_path" 2>/dev/null || echo "") $new_content"
else
    spec_content="$new_content"
fi

# Pass if @layer tag is present with a valid value
if echo "$spec_content" | grep -qE "@layer\((api|ui|full-stack|cli|infra)\)"; then
    echo '{}'
    exit 0
fi

slug="${basename_file%.md}"

# Suggest a likely value from heuristic signals (informational — agent must
# still write the tag, not the hook).
suggested="api"
if echo "$spec_content" | grep -q "^## UI Design"; then
    if echo "$spec_content" | grep -qE 'POST|GET|PUT|DELETE|PATCH'; then
        suggested="full-stack"
    else
        suggested="ui"
    fi
elif echo "$spec_content" | grep -qE 'POST\s+/|GET\s+/|PUT\s+/|DELETE\s+/|PATCH\s+/'; then
    suggested="api"
fi

cat <<EOF
{"error": "BLOCKED: specs/${slug}.md does not have a @layer(...) tag, but the edit sets @status(approved|implemented|verified).\n\nEvery spec must declare @layer with one of: api | ui | full-stack | cli | infra.\n\nThis is the deterministic signal that downstream hooks key on (require-ui-tests, claim-vs-call-audit, /build's Step 3.2.5 wiring checkpoint, etc.). Removing or omitting the tag would bypass those gates.\n\nAdd the tag near the top of the spec, after @status:\n  @status(...)\n  @layer(${suggested})\n\nSuggested value based on spec contents: @layer(${suggested}).\nReference: skills/design/resources/gherkin-spec-reference.md for tag semantics."}
EOF
