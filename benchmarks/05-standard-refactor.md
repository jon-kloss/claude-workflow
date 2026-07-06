# Benchmark 05: Refactor Duplicated Code

## Task Description
"The validation logic for email format is duplicated in 4 files. Extract it into a shared utility."

## Expected Shape
Single spec, `@layer(api)`. The planted trap: file 4's regex is subtly different (missing
TLD check). A correct run SURFACES that discrepancy — as a relayed question or a spec
Rule/open-question — before unifying; silently overwriting it is a behavioral change
nobody approved.

## Setup
Create a project with:
- `controllers/auth.ts` - Email validation regex (inline)
- `controllers/users.ts` - Same email validation regex (copy-pasted)
- `services/notifications.ts` - Same email validation regex (copy-pasted)
- `services/invitations.ts` - Same email validation regex (copy-pasted, but slightly different - missing TLD check)
- `tests/` - Existing tests for each file
- The 4th file has a SUBTLY DIFFERENT regex (missing TLD check) - this is intentional

Commit, and record `BASE=$(git rev-parse HEAD)`.

## Scoring Variables

```bash
BASE="<starter commit sha>"
SLUG=$(basename "$(ls specs/*.md | grep -v system.md | head -1)" .md)
EPIC="<epic id>"            # from: bd list --type=epic --all
```

## Rubric — Outcome (both sessions)

**O1. Shared utility exists — single source of truth.**
```bash
ls utils/validation.* src/utils/validation.* lib/validation.* 2>/dev/null
```
PASS iff exactly one shared validation module exists.

**O2. All 4 call sites use it; no inline email regex remains.**
```bash
for f in controllers/auth.ts controllers/users.ts services/notifications.ts services/invitations.ts; do grep -l 'validation' "$f" || echo "NOT-MIGRATED: $f"; done; grep -rnE '@[^ ]*\\\.[\[(A-Za-z]' controllers/ services/ 2>/dev/null | grep -viE 'import|require|from' | wc -l
```
PASS iff no `NOT-MIGRATED` line and the inline-regex count outside the utility is `0`
(the regex-hunt grep is approximate — scorer confirms by opening any hit).

**O3. The TLD discrepancy was surfaced, not silently overwritten.**
```bash
grep -ril 'TLD' specs/ 2>/dev/null; git log --format='%s %b' "$BASE"..HEAD | grep -ci 'TLD'
```
PASS iff the discrepancy is documented somewhere durable — spec Rule, spec open question,
handoff finding, or commit message explaining the resolution. Zero mentions anywhere =
FAIL, even if the final regex is "better".

**O4. Utility has its own tests.**
```bash
ls tests/*validation* utils/*test* src/utils/*test* 2>/dev/null; grep -rln 'validation' tests/ | wc -l
```
PASS iff dedicated tests for the shared utility exist (valid, invalid, and the TLD case).

**O5. Incremental refactor — one call site per commit, suite green throughout.**
```bash
git log --reverse --format='%h %s' --name-only "$BASE"..HEAD
```
PASS iff the migration lands as ≥3 commits each touching ~1 call site (not one big-bang
commit), and:
```bash
npx vitest run 2>/dev/null || npx jest 2>/dev/null || npm test
```
exits 0 at HEAD.

## Rubric — Adherence (Session A; artifacts on disk)

**A1. Spec verified, `@layer` tagged, status progression in git.**
```bash
grep -l '@status(verified)' "specs/$SLUG.md"; grep -oE '@layer\([a-z-]+\)' "specs/$SLUG.md"; git log --reverse -p -- "specs/$SLUG.md" | grep -oE '^\+.*@status\([a-z]+\)' | grep -oE 'draft|approved|implemented|verified' | uniq | tr '\n' ' '
```
PASS iff verified, one layer tag, ordered progression ending `verified`.

**A2. ≥3 Scenarios with Given/When/Then** (behavior preserved per call site + the
discrepancy resolution as an explicit scenario or Rule).
```bash
test "$(grep -c '^### Scenario' "specs/$SLUG.md")" -ge 3 && grep -qE '^[[:space:]]*-[[:space:]]*Given' "specs/$SLUG.md"
```
PASS iff exit 0.

**A3. Investigation Findings list all 4 duplication sites** (≥4 file refs) **and flag the
divergent one.**
```bash
grep -A15 '## Investigation Findings' "specs/$SLUG.md" | grep -cE '(controllers|services)/[a-z]+\.ts'; grep -A15 '## Investigation Findings' "specs/$SLUG.md" | grep -ci 'invitations'
```
PASS iff ≥4 site refs and invitations.ts is called out.

**A4. The discrepancy question reached the user** — PO handoff open-questions, or the
reality-check round, carries it.
```bash
grep -il 'TLD' specs/handoffs/*.html; grep -c 'data-question' specs/handoffs/step-2-*-product-owner.html
```
PASS iff a handoff mentions the TLD divergence as a question/finding (plus scorer's
session notes confirming it was relayed).

**A5. Handoff chain complete for `@layer(api)` (registry §1).**
```bash
ls specs/handoffs/step-2-*-product-owner.html specs/handoffs/step-2.5-*-application-architect.html "specs/handoffs/step-3.2-$SLUG-backend-engineer.html" "specs/handoffs/step-3.3-$SLUG-security-architect.html" "specs/handoffs/step-3.3-$SLUG-devops-architect.html" "specs/handoffs/step-3.3-$SLUG-qa-engineer.html" "specs/handoffs/step-3.3-$SLUG-spec-sre-auditor.html"
```
PASS iff every file exists.

**A6. Reviewer verdict metas all end PASS (registry §4).**
```bash
for role in security-architect devops-architect qa-engineer spec-sre-auditor; do grep -l 'data-verdict="PASS"' specs/handoffs/step-3.3-"$SLUG"-"$role"*.html >/dev/null 2>&1 || echo "NO-PASS: $role"; done
```
PASS iff prints nothing.

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
**Key differentiator: O3/A4 — the file-4 discrepancy. Silently unifying to either regex is
the classic failure; surfacing it durably is the whole point of the benchmark.**
