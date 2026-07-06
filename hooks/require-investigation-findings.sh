#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write of @status(implemented) on specs/*.md unless the spec has
# an `## Investigation Findings` section with what the build SKILL.md's
# investigation step actually promises (see 'Step 3.1: investigation'):
#   - at least 2 file:line-shaped references (path.ext:NN), and
#   - a `Decision:` line
# inside the section (evaluation H16 — a 3-non-blank-lines check let three
# lines of filler pass). Co-locating findings with the spec keeps the
# evidence checkable by grep without iterating bd.
#
# Escape hatch: @investigation-skip(reason) tag in spec content.
#
# Runs as PreToolUse hook on Edit/Write targeting specs/*.md files.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"
require_python_or_block "require-investigation-findings.sh"

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

# Primary check: ## Investigation Findings section exists AND contains what
# the build skill promises (evaluation H16):
#   - >= 2 references shaped like [A-Za-z0-9_./-]+\.[a-z]+:[0-9]+ (file.ext:line)
#   - a `Decision:` line
findings_result=$("$PYTHON" <(cat <<'PYEOF'
import sys, re
content = sys.stdin.read()
m = re.search(r'^## Investigation Findings\s*\n(.*?)(?=^##\s|\Z)', content, re.MULTILINE | re.DOTALL)
if not m:
    print("no-section")
    sys.exit(0)
body = m.group(1)
refs = re.findall(r'[A-Za-z0-9_./-]+\.[a-z]+:[0-9]+', body)
has_decision = re.search(r'^\s*(?:[-*]\s*)?Decision:', body, re.MULTILINE) is not None
problems = []
if len(refs) < 2:
    problems.append(f"only {len(refs)} file:line reference(s) — need >= 2")
if not has_decision:
    problems.append("no 'Decision:' line")
print("ok" if not problems else "; ".join(problems))
PYEOF
) <<< "$spec_content" 2>/dev/null || echo "parse-error")

if [ "$findings_result" = "ok" ]; then
    echo '{}'
    exit 0
fi

cat >&2 <<EOF
BLOCKED: Writing @status(implemented) to specs/${slug}.md but the ## Investigation Findings section is missing or too thin (${findings_result}).

The build SKILL.md investigation step ('Step 3.1') requires, inside the section:
  - at least 2 concrete file:line references (e.g. src/auth/middleware.ts:42)
  - a 'Decision:' line stating how the findings shape the implementation

Example:
  ## Investigation Findings
  - src/auth/middleware.ts:42 — existing session validation uses verifyJwt() with iss/aud claims
  - src/routes/index.ts:17 — all routes use the consistent { error: { code, message } } response shape
  - specs/user-data-model.md (@depends-on) — user.id is UUID v4, not bigint
  Decision: extend middleware.ts rather than creating a parallel auth path.

To skip (rare — typo fixes use @trivial instead): add @investigation-skip(<reason>) to the spec.
EOF
exit 2
