#!/usr/bin/env bash
# tools/lint-consistency.sh — enforce docs/registry.md vocabulary across the repo.
# Portable: macOS bash 3.2 + BSD grep. No GNU-only flags, no associative arrays.
#
# Rules (each violation prints "file:line: [RULE] message"):
#   R1  Banned tokens: SKILL.md:<NNN> line cites; 3.3c.N / "Step 3.3.N" step tokens;
#       retired tags @backend-only @api-only bare-@cli bare-@infra; 'bd comment ' (singular).
#   R2  Hook references (hooks/<name>.sh|.py paths, backticked `name.sh` / `_name.py`)
#       must exist in hooks/.
#   R3  Agent references (agents/<name>.md paths, subagent_type values) must exist in
#       agents/ (built-in types and hyperpowers:* allowed).
#   R4  specs/handoffs/ literals must match registry §1 grammar
#       (placeholders <slug> <role> <epic-id> <N> etc. and * globs / $vars allowed).
#   R5  Step letters: 3.3<letter> must be within 3.3a..3.3i (numeric forms are R1).
#   R6  @*-skip override tags must appear in docs/registry.md §7.
#
# Scanned: skills/**/*.md, agents/*.md, docs/*.md, hooks/*.{sh,py}, README.md, AGENTS.md.
# docs/registry.md gets R2+R3 only (R1/R4/R5/R6 self-trigger on its own tables).
# tests/*.sh get R2 only (fixtures intentionally contain bad input).
# Excluded: EVALUATION-*.md, plans/, benchmarks/, specs/, .git.
# Exit: 1 if any violation, 0 if clean.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

REGISTRY="docs/registry.md"
if [ ! -f "$REGISTRY" ]; then echo "FATAL: $REGISTRY missing — nothing to lint against" >&2; exit 2; fi

# Non-hook scripts legitimately referenced by bare backticked name.
SCRIPT_ALLOW="install.sh uninstall.sh lint-consistency.sh role-agent-smoke.sh e2e-workflow.sh gen-agents.sh"
BUILTIN_AGENTS="general-purpose Explore Plan claude statusline-setup claude-code-guide"

ROLES="$(ls agents/*.md 2>/dev/null | sed 's|agents/||;s|\.md$||' | tr '\n' '|' | sed 's/|$//')"
STEP_IDS='2|2\.3|2\.5|2\.7|2\.85|3\.1|3\.2|3\.3|4\.1|4\.2|4\.5'
KNOWN_SKIPS="$(grep -oE '@[a-z][a-z-]*-skip' "$REGISTRY" | sort -u)"
HANDOFF_RE="^specs/handoffs/(step-($STEP_IDS)-[a-z0-9][a-z0-9._-]*-($ROLES)(-fix-cycle-[0-9]+)?\.html|respec-3-[a-z0-9][a-z0-9._-]*-application-architect\.html|respec-4-[a-z0-9][a-z0-9._-]*-($ROLES)\.html)$"

emit() { echo "$1:$2: [$3] $4" >> "$OUT"; }

scan_pat() { # file rule regex message — one violation per matching line
  grep -nE "$3" "$1" 2>/dev/null | cut -d: -f1 | while read -r ln; do emit "$1" "$ln" "$2" "$4"; done
}

lint_r1() {
  scan_pat "$1" R1 'SKILL\.md:[0-9]' "internal line-number citation — cite the section name instead (registry §9)"
  scan_pat "$1" R1 '3\.3c\.[0-9]' "retired step token 3.3c.N — use 3.3d/3.3e/3.3f (registry §2)"
  scan_pat "$1" R1 'Step 3\.3\.[0-9]' "retired step token Step 3.3.N — use 3.3a-3.3i letters (registry §2)"
  scan_pat "$1" R1 'bd comment ' "'bd comment' is not a bd subcommand — use 'bd comments add' (registry §9)"
  scan_pat "$1" R1 '@(backend-only|api-only)' "retired tag — use @layer(api) (registry §7)"
  scan_pat "$1" R1 '@(cli|infra)([^a-z-]|$)' "retired bare tag — use @layer(cli) / @layer(infra) (registry §7)"
}

lint_r2() {
  f="$1"
  grep -noE 'hooks/[A-Za-z0-9_.-]+\.(sh|py)' "$f" 2>/dev/null | while IFS= read -r hit; do
    ln="${hit%%:*}"; ref="${hit#*:}"; base="${ref##*/}"
    [ -f "hooks/$base" ] || emit "$f" "$ln" R2 "hook '$ref' does not exist in hooks/"
  done
  grep -noE '`[A-Za-z0-9_.-]+\.(sh|py)`' "$f" 2>/dev/null | while IFS= read -r hit; do
    ln="${hit%%:*}"; base="$(echo "${hit#*:}" | tr -d '\140')"
    case " $SCRIPT_ALLOW " in *" $base "*) continue ;; esac
    case "$base" in
      _*.py) : ;;                 # underscore-prefixed python helpers live in hooks/
      *.py) continue ;;           # other .py names are out of scope
    esac
    [ -f "hooks/$base" ] || emit "$f" "$ln" R2 "backticked script '$base' not found in hooks/ (non-hook scripts allowlist: $SCRIPT_ALLOW)"
  done
}

lint_r3() {
  f="$1"
  grep -noE 'agents/[A-Za-z0-9<>*_-]+\.md' "$f" 2>/dev/null | while IFS= read -r hit; do
    ln="${hit%%:*}"; base="${hit#*:}"; base="${base##*/}"
    case "$base" in *'<'*|*'*'*) continue ;; esac
    [ -f "agents/$base" ] || emit "$f" "$ln" R3 "agent file 'agents/$base' does not exist"
  done
  grep -noE 'subagent_type["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9:<>*_-]+' "$f" 2>/dev/null | while IFS= read -r hit; do
    ln="${hit%%:*}"
    val="$(echo "${hit#*:}" | sed -E 's/^subagent_type["'"'"' ]*[:=]["'"'"' ]*//')"
    case "$val" in *'<'*|*'*'*|hyperpowers:*) continue ;; esac
    case " $BUILTIN_AGENTS " in *" $val "*) continue ;; esac
    [ -f "agents/$val.md" ] || emit "$f" "$ln" R3 "subagent_type '$val' matches no agents/*.md and no built-in type"
  done
}

lint_r4() {
  f="$1"
  grep -noE 'specs/handoffs/[][A-Za-z0-9<>${}*._-]*' "$f" 2>/dev/null | while IFS= read -r hit; do
    ln="${hit%%:*}"; ref="$(echo "${hit#*:}" | sed -E 's/[.,;:]+$//')"
    case "$ref" in
      *'$'*|*'*'*) continue ;;                          # shell vars / globs: not statically lintable
      specs/handoffs|specs/handoffs/) continue ;;       # bare directory mention
    esac
    norm="$(echo "$ref" | sed \
      -e 's/\[[^]]*\]//g' \
      -e 's/<step-id>/step-3.3/g' -e 's/<step>/step-3.3/g' -e 's/<id>/3.3/g' \
      -e 's/<spec-slug>/slug-x/g' -e 's/<epic-id>/epic-x/g' -e 's/<epic-slug>/epic-x/g' -e 's/<slug>/slug-x/g' \
      -e 's/<role-slug>/qa-engineer/g' -e 's/<role>/qa-engineer/g' \
      -e 's/<N>/1/g' -e 's/<n>/1/g')"
    echo "$norm" | grep -qE "$HANDOFF_RE" || emit "$f" "$ln" R4 "handoff path '$ref' violates registry §1 grammar"
  done
}

lint_r5() {
  scan_pat "$1" R5 '3\.3[j-z]([^a-z]|$)' "step letter out of range — verify pass is 3.3a..3.3i (registry §2)"
}

lint_r6() {
  f="$1"
  grep -noE '@[a-z][a-z-]*-skip' "$f" 2>/dev/null | while IFS= read -r hit; do
    ln="${hit%%:*}"; tag="${hit#*:}"
    echo "$KNOWN_SKIPS" | grep -qxF "$tag" || emit "$f" "$ln" R6 "override tag '$tag' not in registry §7"
  done
}

# ---- file sets -------------------------------------------------------------
MD_FILES="$( { find skills -type f -name '*.md' 2>/dev/null; \
               ls agents/*.md 2>/dev/null; \
               find docs -maxdepth 1 -type f -name '*.md' ! -name 'registry.md' 2>/dev/null; \
               [ -f README.md ] && echo README.md; \
               [ -f AGENTS.md ] && echo AGENTS.md; } )"
HOOK_FILES="$(ls hooks/*.sh hooks/*.py 2>/dev/null)"
TEST_FILES="$(ls tests/*.sh 2>/dev/null)"

for f in $MD_FILES $HOOK_FILES; do
  lint_r1 "$f"; lint_r2 "$f"; lint_r3 "$f"; lint_r4 "$f"; lint_r5 "$f"; lint_r6 "$f"
done
lint_r2 "$REGISTRY"; lint_r3 "$REGISTRY"   # registry: existence checks only
for f in $TEST_FILES; do lint_r2 "$f"; done

# ---- report ----------------------------------------------------------------
sort -t: -k1,1 -k2,2n "$OUT" | uniq
TOTAL="$(wc -l < "$OUT" | tr -d ' ')"
line="lint-consistency: $TOTAL violation(s)"
for r in R1 R2 R3 R4 R5 R6; do
  c="$(grep -c "\[$r\]" "$OUT")" || true
  line="$line  $r:$c"
done
echo "----"
echo "$line"
[ "$TOTAL" -eq 0 ] && exit 0 || exit 1
