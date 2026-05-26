#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write of @status(implemented) on specs/*.md unless the spec has
# an `## Investigation Findings` section (with concrete content beneath it).
#
# Enforces build/SKILL.md:62 ("Investigation findings logged") and :313-327
# (the investigation-finding format) deterministically. Co-locating findings
# with the spec keeps the evidence checkable by grep without iterating bd.
#
# Escape hatch: @investigation-skip(reason) tag in spec content.
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

# Only trigger when @status(implemented) is being written
if ! echo "$new_content" | grep -q "@status(implemented)"; then
    echo '{}'
    exit 0
fi

# Build full spec view (existing file + new content)
if [ -f "$file_path" ]; then
    spec_content="$(cat "$file_path" 2>/dev/null || echo "") $new_content"
else
    spec_content="$new_content"
fi

# Escape hatch
if echo "$spec_content" | grep -qE "@investigation-skip\([^)]+\)"; then
    echo '{}'
    exit 0
fi

# Skip @trivial specs — typo fixes and renames don't need codebase investigation
if echo "$spec_content" | grep -q "@trivial"; then
    echo '{}'
    exit 0
fi

slug="${basename_file%.md}"

# Primary check: ## Investigation Findings section exists with non-trivial content
# "Non-trivial" = at least 3 non-blank lines under the heading before the next ## header.
findings_present="no"
if echo "$spec_content" | grep -qE "^## Investigation Findings"; then
    body_lines=$("$PYTHON" <(cat <<'PYEOF'
import sys, re
content = sys.stdin.read()
m = re.search(r'^## Investigation Findings\s*\n(.*?)(?=^##\s|\Z)', content, re.MULTILINE | re.DOTALL)
if not m:
    print(0)
else:
    body = m.group(1)
    lines = [l for l in body.splitlines() if l.strip() and not l.strip().startswith('<!--')]
    print(len(lines))
PYEOF
) <<< "$spec_content" 2>/dev/null || echo "0")
    if [ "${body_lines:-0}" -ge 3 ]; then
        findings_present="yes"
    fi
fi

if [ "$findings_present" = "yes" ]; then
    echo '{}'
    exit 0
fi

cat >&2 <<EOF
BLOCKED: Writing @status(implemented) to specs/${slug}.md but no ## Investigation Findings section with content exists.

build/SKILL.md Step 3.1 requires investigation before implementation. Add an ## Investigation Findings section to the spec with at least 3 lines of content covering:

  - Patterns discovered (file:line references)
  - Conventions to follow (naming, error handling, response format)
  - Integration points from dependency specs
  - Decision: how the findings influence implementation

Example:
  ## Investigation Findings
  - src/auth/middleware.ts:42 — existing session validation uses verifyJwt() with iss/aud claims
  - src/routes/*.ts — all routes use the consistent { error: { code, message } } response shape
  - specs/user-data-model.md (@depends-on) — user.id is UUID v4, not bigint
  Decision: extend middleware.ts rather than creating a parallel auth path.

To skip (rare — typo fixes use @trivial instead): add @investigation-skip(<reason>) to the spec.
EOF
exit 2
