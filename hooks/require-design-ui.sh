#!/usr/bin/env bash
set -euo pipefail

# Block @status(approved) on UI-facing specs that are missing design artifacts.
# Prevents the pattern where /design-ui is skipped and specs get approved
# without PRODUCT.md, DESIGN.md, or mockups.
#
# Escape hatch: add @backend-only tag to a spec to skip this check.
#
# Runs as PreToolUse hook on Edit/Write commands targeting specs/*.md files.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Read tool use event from stdin
if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

# Validate JSON
if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

# Extract file path (Edit and Write both use file_path)
file_path=$(json_get "$tool_use_json" ".tool.input.file_path" "null")
if [ "$file_path" = "null" ] || [ -z "$file_path" ]; then
    file_path=$(json_get "$tool_use_json" ".tool_input.file_path" "null")
fi

if [ "$file_path" = "null" ] || [ -z "$file_path" ]; then
    echo '{}'
    exit 0
fi

# Only care about spec files
if [[ "$file_path" != */specs/*.md ]]; then
    echo '{}'
    exit 0
fi

# Skip system.md and arch.md — these are not feature specs
basename_file=$(basename "$file_path")
if [[ "$basename_file" == "system.md" ]] || [[ "$basename_file" == "arch.md" ]]; then
    echo '{}'
    exit 0
fi

# Check if this edit/write includes @status(approved)
# For Edit: check new_string. For Write: check content.
new_content=$(json_get "$tool_use_json" ".tool.input.new_string" "")
if [ -z "$new_content" ]; then
    new_content=$(json_get "$tool_use_json" ".tool_input.new_string" "")
fi
if [ -z "$new_content" ]; then
    new_content=$(json_get "$tool_use_json" ".tool.input.content" "")
fi
if [ -z "$new_content" ]; then
    new_content=$(json_get "$tool_use_json" ".tool_input.content" "")
fi

# Only trigger when @status(approved) is being written
if ! echo "$new_content" | grep -q "@status(approved)"; then
    echo '{}'
    exit 0
fi

# Read the full spec content (existing file or new content)
if [ -f "$file_path" ]; then
    spec_content=$(cat "$file_path" 2>/dev/null || echo "")
    # Combine with new content for full picture
    spec_content="$spec_content $new_content"
else
    spec_content="$new_content"
fi

# Check for @backend-only escape hatch
if echo "$spec_content" | grep -qi "@backend-only\|@api-only\|@cli\|@infra"; then
    echo '{}'
    exit 0
fi

# Detect UI-facing signals in the spec
# These are words that indicate the spec describes user-visible interface elements
UI_PATTERNS="screen\|page\|button\|form\|dashboard\|tab\|navigate\|click\|tap\|press\|modal\|sidebar\|layout\|component\|view\|toggle\|input\|dropdown\|menu\|card\|list view\|grid view\|progress bar\|chart\|calendar\|search bar\|notification\|toast\|dialog\|popover\|tooltip\|slider\|checkbox\|radio\|select\|switch"

if ! echo "$spec_content" | grep -qi "$UI_PATTERNS"; then
    # Not UI-facing, let it through
    echo '{}'
    exit 0
fi

# It's UI-facing — check for required design artifacts
# Find the project root (where specs/ lives)
spec_dir=$(dirname "$file_path")
project_root=$(dirname "$spec_dir")

missing=""

if [ ! -f "$project_root/PRODUCT.md" ]; then
    missing="${missing}PRODUCT.md, "
fi

if [ ! -f "$project_root/DESIGN.md" ]; then
    missing="${missing}DESIGN.md, "
fi

# Check for mockup (directory or HTML file)
slug="${basename_file%.md}"
if [ ! -d "$spec_dir/mockups/$slug" ] && [ ! -f "$spec_dir/mockups/${slug}.html" ]; then
    missing="${missing}specs/mockups/${slug} (mockup), "
fi

# If nothing missing, allow
if [ -z "$missing" ]; then
    echo '{}'
    exit 0
fi

# Remove trailing comma+space
missing="${missing%, }"

echo "{\"error\": \"BLOCKED: This spec is UI-facing but /design-ui was not run.\\n\\nMissing: ${missing}\\n\\nRun /design-ui before approving UI-facing specs.\\nIf this spec is NOT UI-facing, add @backend-only tag to skip this check.\"}"
