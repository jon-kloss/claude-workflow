#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write writing @status(verified) to a spec unless the
# hyperpowers:code-reviewer agent was dispatched in this session with a
# prompt referencing this spec's slug.
#
# Enforces build/SKILL.md:14 ("Verification never scales down") deterministically.
#
# Escape hatch: add @verifier-skip(reason) tag to the spec content. The reason
# stays in the spec file as documentation of why this verification was skipped.
#
# Runs as PreToolUse hook on Edit/Write targeting specs/*.md files.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

AGENTS_FILE="${HOME}/.claude/hooks/state/session-agents.log"

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

# Extract target file path
file_path=$(json_get "$tool_use_json" ".tool.input.file_path" "null")
if [ "$file_path" = "null" ] || [ -z "$file_path" ]; then
    file_path=$(json_get "$tool_use_json" ".tool_input.file_path" "null")
fi

if [ "$file_path" = "null" ] || [ -z "$file_path" ]; then
    echo '{}'
    exit 0
fi

# Only care about spec files (skip system.md and arch.md — not verified specs)
if [[ "$file_path" != */specs/*.md ]]; then
    echo '{}'
    exit 0
fi

basename_file=$(basename "$file_path")
if [[ "$basename_file" == "system.md" ]] || [[ "$basename_file" == "arch.md" ]]; then
    echo '{}'
    exit 0
fi

# Extract the new content (Edit: new_string, Write: content)
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

# Only trigger when @status(verified) is being written
if ! echo "$new_content" | grep -q "@status(verified)"; then
    echo '{}'
    exit 0
fi

# Read full spec content (existing file + new content) for tag checks
if [ -f "$file_path" ]; then
    spec_content=$(cat "$file_path" 2>/dev/null || echo "")
    spec_content="$spec_content $new_content"
else
    spec_content="$new_content"
fi

# Escape hatch: @verifier-skip(<reason>) tag
if echo "$spec_content" | grep -qE "@verifier-skip\([^)]+\)"; then
    echo '{}'
    exit 0
fi

# Derive the spec slug from the filename
slug="${basename_file%.md}"

# If no session agents log exists, nothing has been dispatched
if [ ! -f "$AGENTS_FILE" ]; then
    cat <<EOF
{"error": "BLOCKED: Writing @status(verified) to specs/${slug}.md but no code-reviewer agent has been dispatched in this session.\n\nbuild/SKILL.md Step 3.3c requires:\n  Agent(subagent_type: hyperpowers:code-reviewer, prompt referencing '${slug}')\n\nDispatch the agent, then retry the edit. To override (rare — document the reason), add this tag to the spec:\n  @verifier-skip(<reason>)"}
EOF
    exit 0
fi

# Look for a code-reviewer dispatch whose prompt mentions this slug or spec path.
# The session-agents.log format is: timestamp|subagent_type|prompt-oneline
# We match the subagent_type column exactly, then check the prompt for the slug.
match=$(awk -F'|' -v slug="$slug" '
    $2 == "hyperpowers:code-reviewer" {
        if (index($3, slug) > 0) { print; exit }
    }
' "$AGENTS_FILE" 2>/dev/null || echo "")

if [ -z "$match" ]; then
    cat <<EOF
{"error": "BLOCKED: Writing @status(verified) to specs/${slug}.md but no hyperpowers:code-reviewer agent was dispatched in this session with a prompt mentioning '${slug}'.\n\nbuild/SKILL.md Step 3.3c requires (full text):\n  Agent(subagent_type: hyperpowers:code-reviewer, prompt: 'Review ALL files changed for this spec. 1. Read specs/${slug}.md — verify EVERY scenario has code and tests ...')\n\nThis hook is reading ~/.claude/hooks/state/session-agents.log to determine whether the agent ran. Dispatch the agent (or re-dispatch with the slug clearly in the prompt) and retry.\n\nTo skip this check (rare — document the reason), add the following tag to the spec content:\n  @verifier-skip(<concise reason>)\n\nDo NOT silently self-verify: this is the documented failure mode this hook exists to catch."}
EOF
    exit 0
fi

# Code reviewer fired — allow the edit
echo '{}'
