#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write of @status(verified) on UI-bearing specs unless the
# /impeccable quality gates (critique, audit, harden, clarify, adapt) were
# actually invoked via the Skill tool in this session for this spec slug.
#
# Enforces design-ui/SKILL.md:14 ("If you did not type Skill(impeccable,
# '<gate> <slug>'), the gate did not run") deterministically. Prevents the
# documented 2026-05-21 incident pattern where gate claims appeared in the
# spec but no corresponding Skill calls were logged.
#
# Required gates per UI-bearing spec:
#   critique, audit, harden, clarify, adapt
#
# Escape hatch: @gate-skip(<gate>: <reason>) tags in spec content, one per
# gate to skip. Reason persists in the file.
#
# Runs as PreToolUse hook on Edit/Write targeting specs/*.md files.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

SKILLS_FILE="${HOME}/.claude/hooks/state/session-skills.log"

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

# Only trigger on @status(verified)
if ! echo "$new_content" | grep -q "@status(verified)"; then
    echo '{}'
    exit 0
fi

# Build full spec view
if [ -f "$file_path" ]; then
    spec_content="$(cat "$file_path" 2>/dev/null || echo "") $new_content"
else
    spec_content="$new_content"
fi

# Only UI-bearing specs
is_ui_spec="no"
if echo "$spec_content" | grep -qE "@layer\((ui|full-stack)\)"; then
    is_ui_spec="yes"
elif echo "$spec_content" | grep -q "^## UI Design"; then
    is_ui_spec="yes"
fi

if [ "$is_ui_spec" != "yes" ]; then
    echo '{}'
    exit 0
fi

slug="${basename_file%.md}"

# Required gates
required_gates=(critique audit harden clarify adapt)

# Build a set of skipped gates from @gate-skip(<gate>: ...) tags
skipped_gates=$(echo "$spec_content" | grep -oE "@gate-skip\([a-z]+:" | sed 's/@gate-skip(//; s/://' || true)

missing_gates=""
for gate in "${required_gates[@]}"; do
    # Was this gate explicitly skipped via @gate-skip(<gate>: ...) ?
    if echo "$skipped_gates" | grep -qw "$gate"; then
        continue
    fi
    # Was the Skill called for impeccable with this gate + slug?
    # Skills log format: timestamp|skill|args-oneline
    # We expect args to contain "<gate> <slug>" or "<gate>" with slug elsewhere
    fired="no"
    if [ -f "$SKILLS_FILE" ]; then
        if awk -F'|' -v gate="$gate" -v slug="$slug" '
            ($2 == "impeccable" || $2 ~ /:impeccable$/) {
                if (index($3, gate) > 0 && index($3, slug) > 0) { print; exit 0 }
            }
        ' "$SKILLS_FILE" 2>/dev/null | grep -q .; then
            fired="yes"
        fi
    fi
    if [ "$fired" = "no" ]; then
        missing_gates="${missing_gates}${gate} "
    fi
done

missing_gates="${missing_gates% }"

if [ -z "$missing_gates" ]; then
    echo '{}'
    exit 0
fi

cat <<EOF
{"error": "BLOCKED: specs/${slug}.md is UI-bearing and being marked @status(verified), but these /impeccable gates were not invoked via the Skill tool in this session for '${slug}': ${missing_gates}\n\ndesign-ui/SKILL.md:14: 'If you did not type Skill(impeccable, \"<gate> <slug>\"), the gate did not run.'\n\nThis hook reads ~/.claude/hooks/state/session-skills.log. Run the missing gates:\n$(for g in $missing_gates; do printf '  Skill(impeccable, \"%s %s\")\\n' "$g" "$slug"; done)\n\nThen retry the edit.\n\nTo skip a specific gate (rare, document the reason), add to the spec:\n  @gate-skip(<gate>: <concise reason>)\n  e.g. @gate-skip(adapt: covered by parent dashboard spec's adapt run)"}
EOF
