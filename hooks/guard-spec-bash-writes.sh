#!/usr/bin/env bash
set -euo pipefail

# Block Bash commands that write/modify files under specs/*.md.
#
# The require-verifier-agents, require-ui-tests, require-investigation-findings,
# claim-vs-call-audit, and require-design-ui hooks all fire on Edit|Write
# PreToolUse only. Writing the same content via Bash (`cat > specs/foo.md`,
# `sed -i`, `perl -pi`, `echo > ...`, `printf > ...`, `tee`, redirects, etc.)
# bypasses all of them. This hook closes that loophole by blocking any Bash
# command that targets a path matching */specs/*.md.
#
# The block is unconditional — there is no override at the Bash level. Spec
# edits must go through the Edit or Write tools so the gate hooks can audit
# them. The legitimate exceptions (creating mockup directories, running tests,
# searching specs) don't write to specs/*.md.
#
# Runs as PreToolUse hook on Bash.

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

cmd=$(json_get "$tool_use_json" ".tool.input.command" "")
[ -z "$cmd" ] && cmd=$(json_get "$tool_use_json" ".tool_input.command" "")

if [ -z "$cmd" ]; then
    echo '{}'
    exit 0
fi

# Quick scan: does the command even mention specs/ ?
if ! echo "$cmd" | grep -qE 'specs/[a-zA-Z0-9_.-]+\.md'; then
    echo '{}'
    exit 0
fi

# Identify write-shaped patterns targeting specs/*.md.
# The patterns are loose by design — covering legitimate variations is more
# important than ruling out false positives. Bash already escapes redirects
# inside quoted strings so the simpler patterns suffice for the common cases.
write_pattern_found=""

# 1. Stream redirection targeting a spec file: > specs/foo.md, >> specs/foo.md
#    (also catches `cat >`, `echo >`, `printf >`, etc.)
if echo "$cmd" | grep -qE '>>?\s*[^|&;]*specs/[a-zA-Z0-9_.-]+\.md'; then
    write_pattern_found="redirect"
fi

# 2. tee writing to a spec file
if echo "$cmd" | grep -qE '\btee(\s+-[a-zA-Z]+)?\s+[^|&;]*specs/[a-zA-Z0-9_.-]+\.md'; then
    write_pattern_found="tee"
fi

# 3. In-place editors: sed -i, perl -pi, perl -i, awk -i inplace, ruby -pi
if echo "$cmd" | grep -qE '\b(sed|gsed)\s+(-[a-zA-Z]+\s+)*-[a-zA-Z]*i[a-zA-Z]*\b'; then
    if echo "$cmd" | grep -qE 'specs/[a-zA-Z0-9_.-]+\.md'; then
        write_pattern_found="sed -i"
    fi
fi
if echo "$cmd" | grep -qE '\b(perl|ruby)\s+(-[a-zA-Z]*)*-[a-zA-Z]*i[a-zA-Z]*\b'; then
    if echo "$cmd" | grep -qE 'specs/[a-zA-Z0-9_.-]+\.md'; then
        write_pattern_found="perl/ruby -i"
    fi
fi
if echo "$cmd" | grep -qE '\bawk\s+(-[a-zA-Z]+\s+)*-i\s+inplace'; then
    if echo "$cmd" | grep -qE 'specs/[a-zA-Z0-9_.-]+\.md'; then
        write_pattern_found="awk -i inplace"
    fi
fi

# 4. mv or cp into a spec file
if echo "$cmd" | grep -qE '\b(mv|cp|rsync|install)\s+[^|&;]+specs/[a-zA-Z0-9_.-]+\.md(\s|$)'; then
    write_pattern_found="mv/cp/rsync into spec"
fi

# 5. Python/Node/Ruby/Perl one-liners that write a spec
if echo "$cmd" | grep -qE '(python|python3|node|ruby|perl)\s+-[ec]'; then
    if echo "$cmd" | grep -qE 'specs/[a-zA-Z0-9_.-]+\.md'; then
        if echo "$cmd" | grep -qE 'write_text|write\s*\(|writeFileSync|fs\.write|File\.write|>>?\s*[^|&;]*\.md|open\s*\([^)]*[\"'\'']w[\"'\'']'; then
            write_pattern_found="scripted write"
        fi
    fi
fi

# 6. Heredoc patterns (cat <<EOF, cat <<-EOF, etc.) — already caught by
#    pattern 1 via the trailing redirect, but make this explicit for clarity.
if echo "$cmd" | grep -qE '<<-?\s*[A-Z_]+'; then
    if echo "$cmd" | grep -qE 'specs/[a-zA-Z0-9_.-]+\.md'; then
        # Make sure this is a write-shaped heredoc (has > or |) rather than a
        # heredoc into a different command (e.g. `gh pr create --body "$(cat <<EOF`)
        if echo "$cmd" | grep -qE '>\s*[^|&;]*specs/'; then
            write_pattern_found="heredoc -> spec"
        fi
    fi
fi

if [ -z "$write_pattern_found" ]; then
    echo '{}'
    exit 0
fi

# Permit a few obviously-read-shaped commands that mention specs but don't write:
# grep, find, cat (without redirect), ls, head, tail, less, diff, git log
# These are caught by the patterns above being write-shaped, so we only need
# to allow them through when no write pattern matched — already handled.

# Extract the spec target for a clearer message
spec_target=$(echo "$cmd" | grep -oE 'specs/[a-zA-Z0-9_.-]+\.md' | head -1)

cat >&2 <<EOF
BLOCKED: Bash command appears to write to ${spec_target} (pattern: ${write_pattern_found}).

Spec edits MUST go through the Edit or Write tool. Bash file writes bypass workflow verification hooks (require-verifier-agents, require-ui-tests, require-investigation-findings, claim-vs-call-audit, require-design-ui) and would let unverified specs reach @status(verified) silently.

Use:
  Edit  — replace specific text in an existing spec
  Write — replace the entire spec file

If this Bash command is NOT meant to modify the spec (false positive — e.g. you're piping spec contents to another tool), restructure the command so it doesn't redirect into the spec file. The hook keys on '>specs/<slug>.md', 'sed -i', and similar write-shaped patterns.

No override is offered at the Bash level — by design. Spec edits go through audited tools.
EOF
exit 2
