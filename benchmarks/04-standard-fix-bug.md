# Benchmark 04: Fix a Bug with Misleading Symptoms

## Task Description
"Users report that search results are empty when searching for items with special characters like '&' or '+'"

## Expected Shape
Single spec, `@layer(api)`. The scored skill is investigation: the fix must land in the
route layer (URL decoding), not the search service — and git history must show the failing
regression test before (or with) the fix, never after.

## Setup
Create a project with:
- `routes/search.ts` - Search endpoint that accepts query parameter `q`
- `services/search.ts` - Search service that queries database
- `tests/search.test.ts` - Existing tests (all pass, but none test special characters)
- The actual bug: query parameter is not URL-decoded before database query
- Red herring: the database query itself handles special chars fine - the issue is in the route layer

Commit, and record `BASE=$(git rev-parse HEAD)`.

## Scoring Variables

```bash
BASE="<starter commit sha>"
SLUG=$(basename "$(ls specs/*.md | grep -v system.md | head -1)" .md)
EPIC="<epic id>"            # from: bd list --type=epic --all
```

## Rubric — Outcome (both sessions)

**O1. Fix landed in the route layer, not the service** (root cause, not symptom).
```bash
git log --format= --name-only "$BASE"..HEAD | sort -u | grep -v '^$'
```
PASS iff `routes/search.ts` (or middleware) is in the changed set AND `services/search.ts`
has no behavioral change:
```bash
git diff "$BASE"..HEAD -- services/search.ts | wc -l
```
(prints `0`, or only comment/whitespace lines — scorer eyeball if nonzero).

**O2. Not a workaround** — no character escaping/stripping added in the service layer.
```bash
grep -nE 'replace\(|escape|encodeURI' services/search.ts | wc -l
```
PASS iff prints `0` (relative to base: `git diff "$BASE"..HEAD -- services/ | grep -cE '^\+.*(replace\(|escape|encodeURI)'` also prints `0`).

**O3. Regression tests cover '&', '+', '%', and quotes.**
```bash
for c in '&' '+' '%' "'" ; do grep -l -- "$c" tests/search.test.ts >/dev/null || echo "MISSING: $c"; done; grep -cinE 'special|decode|%26|%2B' tests/search.test.ts
```
PASS iff no `MISSING` line and the special-character tests are real assertions (scorer
opens the matched tests).

**O4. Failing test came first (TDD).**
```bash
git log --reverse --format='%h %s' --name-only "$BASE"..HEAD
```
PASS iff the commit introducing the special-char test precedes (or is the same commit as)
the route fix — never a later "add tests" commit.

**O5. Full suite passes (no regressions).**
```bash
npx vitest run 2>/dev/null || npx jest 2>/dev/null || npm test
```
PASS iff exit 0.

## Rubric — Adherence (Session A; artifacts on disk)

**A1. Spec verified, `@layer` tagged, status progression in git.**
```bash
grep -l '@status(verified)' "specs/$SLUG.md"; grep -oE '@layer\([a-z-]+\)' "specs/$SLUG.md"; git log --reverse -p -- "specs/$SLUG.md" | grep -oE '^\+.*@status\([a-z]+\)' | grep -oE 'draft|approved|implemented|verified' | uniq | tr '\n' ' '
```
PASS iff verified, one layer tag, ordered progression ending `verified`.

**A2. ≥3 Scenarios with Given/When/Then** (reproduction, fix behavior, no-regression).
```bash
test "$(grep -c '^### Scenario' "specs/$SLUG.md")" -ge 3 && grep -qE '^[[:space:]]*-[[:space:]]*Given' "specs/$SLUG.md"
```
PASS iff exit 0.

**A3. Investigation Findings name the real root cause** (≥2 file:line refs + Decision
line identifying the route layer).
```bash
grep -A12 '## Investigation Findings' "specs/$SLUG.md" | grep -cE '\.[a-z]+:[0-9]+'; grep -A12 '## Investigation Findings' "specs/$SLUG.md" | grep -i 'Decision:'
```
PASS iff ≥2 refs and the Decision line names URL decoding / the route layer (not the DB).

**A4. Handoff chain complete for `@layer(api)` (registry §1).**
```bash
ls specs/handoffs/step-2-*-product-owner.html specs/handoffs/step-2.5-*-application-architect.html "specs/handoffs/step-3.2-$SLUG-backend-engineer.html" "specs/handoffs/step-3.3-$SLUG-security-architect.html" "specs/handoffs/step-3.3-$SLUG-devops-architect.html" "specs/handoffs/step-3.3-$SLUG-qa-engineer.html" "specs/handoffs/step-3.3-$SLUG-spec-sre-auditor.html"
```
PASS iff every file exists.

**A5. Reviewer verdict metas all end PASS (registry §4).**
```bash
for role in security-architect devops-architect qa-engineer spec-sre-auditor; do grep -l 'data-verdict="PASS"' specs/handoffs/step-3.3-"$SLUG"-"$role"*.html >/dev/null 2>&1 || echo "NO-PASS: $role"; done
```
PASS iff prints nothing.

**A6. Tests reference the spec slug.**
```bash
grep -rl "$SLUG" tests/ 2>/dev/null | wc -l
```
PASS iff ≥1.

**A7. Fix cycles symmetric.** **N/A-when** no fix-cycle files exist.
```bash
for f in specs/handoffs/step-3.3-"$SLUG"-*-fix-cycle-*.html; do [ -e "$f" ] || continue; n="${f##*fix-cycle-}"; n="${n%.html}"; ls specs/handoffs/step-3.2-"$SLUG"-*-fix-cycle-"$n".html || echo "ASYMMETRIC cycle $n"; done
```
PASS iff no `ASYMMETRIC` line.

**A8. Beads epic + Tests gate closed in order; VERIFICATION comment.**
```bash
bd list --type=epic --all; bd list --all | grep -i 'Tests:'; bd show "$EPIC"; bd comments "$EPIC" | grep -c 'VERIFICATION'
```
PASS iff both closed in order and count ≥1.

**A9. Release-coordinator verdict READY-*; override-audit delta clean.**
```bash
grep -o 'data-verdict="[A-Z-]*"' specs/handoffs/step-4.2-*-release-coordinator.html; diff ./.override-baseline ~/.claude/hooks/state/override-audit.log
```
PASS iff READY-TO-CLOSE/READY-WITH-CAVEATS and empty (or justified) diff.

## Score Sheet

| ID | PASS/FAIL/N-A | Notes |
|----|---------------|-------|
| O1–O5 | | |
| A1–A9 | | |

**Outcome: /5 · Adherence: /9 (minus N/A).**
**Key differentiator: O1/O2 — root cause in the route layer vs escaping the symptom in
the service. A3 shows whether logged investigation, or trial-and-error, got there.**
