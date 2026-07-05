# Benchmark 03: Add an API Endpoint

## Task Description
"Add a GET /api/users/:id/activity endpoint that returns the user's recent activity log"

## Expected Shape
Single spec (one cohesive behavior), `@layer(api)`, full Standard structure (As/I want/
So that, Technical Context, Rules, ≥4 Scenarios). Full 3.3a–3.3i verify pass. The design
phase should surface at least one relayed question (pagination? auth? how recent is
"recent"?) rather than silently defaulting.

## Setup
Create a project with:
- `routes/users.ts` - Existing user routes (GET /api/users, GET /api/users/:id)
- `controllers/users.ts` - Existing controller with consistent error handling pattern
- `models/user.ts` - User model
- `models/activity.ts` - Activity model (already exists, has userId foreign key)
- `tests/users.test.ts` - Existing endpoint tests following consistent pattern
- Existing pattern: all endpoints use `asyncHandler`, return `{ data: ... }`, validate params with Joi

Commit, and record `BASE=$(git rev-parse HEAD)`.

## Scoring Variables

```bash
BASE="<starter commit sha>"
SLUG=$(basename "$(ls specs/*.md | grep -v system.md | head -1)" .md)
EPIC="<epic id>"            # from: bd list --type=epic --all
```

## Rubric — Outcome (both sessions)

**O1. Route exists and follows the route pattern (asyncHandler).**
```bash
grep -n 'activity' routes/users.ts && grep -n 'asyncHandler' routes/users.ts | grep -i 'activity'
```
PASS iff the new route registers via `asyncHandler` like its neighbors.

**O2. Controller follows the error-handling + response-format pattern.**
```bash
grep -n -A15 'activity' controllers/users.ts | grep -nE 'data:|\{ data'
```
PASS iff the new controller method returns `{ data: ... }` and its error path matches the
existing controllers (scorer compares the printed block with an existing method).

**O3. Param validation via Joi for `:id`.**
```bash
grep -rn 'Joi' routes/users.ts controllers/users.ts | grep -i -B2 -A2 'activity'
```
PASS iff the `:id` param is Joi-validated on the new endpoint.

**O4. Edge cases tested: invalid id, user not found, empty activity.**
```bash
grep -n 'activity' tests/*.test.ts | wc -l; grep -inE 'invalid|not found|404|400|empty' tests/*.test.ts | grep -ic 'activity'
```
PASS iff there are activity tests covering happy path plus all three edge cases (scorer
confirms each of the three appears).

**O5. Full test suite passes.**
```bash
npx vitest run 2>/dev/null || npx jest 2>/dev/null || npm test
```
PASS iff exit 0.

**O6. No N+1 query shape.**
```bash
grep -n -A20 'activity' controllers/users.ts services/*.ts 2>/dev/null | grep -nE 'for|map|forEach' 
```
PASS iff no per-row query loop around the activity fetch (scorer eyeball on the printed
lines; a single filtered/paginated query is the expected shape).

## Rubric — Adherence (Session A; artifacts on disk)

**A1. Spec verified, `@layer` tagged, status progression in git.**
```bash
grep -l '@status(verified)' "specs/$SLUG.md"; grep -oE '@layer\([a-z-]+\)' "specs/$SLUG.md"; git log --reverse -p -- "specs/$SLUG.md" | grep -oE '^\+.*@status\([a-z]+\)' | grep -oE 'draft|approved|implemented|verified' | uniq | tr '\n' ' '
```
PASS iff verified, exactly one layer tag, ordered progression ending `verified`.

**A2. ≥4 Scenarios with Given/When/Then + Technical Context.**
```bash
test "$(grep -c '^### Scenario' "specs/$SLUG.md")" -ge 4 && grep -q 'Technical Context' "specs/$SLUG.md" && grep -qE '^[[:space:]]*-[[:space:]]*Given' "specs/$SLUG.md"
```
PASS iff exit 0.

**A3. A blocking question was relayed** — the PO handoff's open-questions carry at least
one `data-question` item (orchestrator-relayed questioning; agents cannot ask directly).
```bash
grep -c 'data-question' specs/handoffs/step-2-*-product-owner.html
```
PASS iff prints ≥1 (and the scorer's own session notes confirm an AskUserQuestion round).

**A4. Investigation Findings cite the existing pattern (≥2 file:line refs + Decision).**
```bash
grep -A12 '## Investigation Findings' "specs/$SLUG.md" | grep -cE '\.[a-z]+:[0-9]+'; grep -A12 '## Investigation Findings' "specs/$SLUG.md" | grep -c 'Decision:'
```
PASS iff ≥2 and ≥1.

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

**A7. Tests reference the spec slug** (scenario→test traceability).
```bash
grep -rl "$SLUG" tests/ 2>/dev/null | wc -l
```
PASS iff prints ≥1.

**A8. Fix cycles symmetric.** **N/A-when** no fix-cycle files exist.
```bash
for f in specs/handoffs/step-3.3-"$SLUG"-*-fix-cycle-*.html; do [ -e "$f" ] || continue; n="${f##*fix-cycle-}"; n="${n%.html}"; ls specs/handoffs/step-3.2-"$SLUG"-*-fix-cycle-"$n".html || echo "ASYMMETRIC cycle $n"; done
```
PASS iff no `ASYMMETRIC` line.

**A9. Beads epic + Tests gate closed in order; VERIFICATION comment.**
```bash
bd list --type=epic --all; bd list --all | grep -i 'Tests:'; bd show "$EPIC"; bd comments "$EPIC" | grep -c 'VERIFICATION'
```
PASS iff both closed in order and count ≥1.

**A10. Release-coordinator verdict READY-*; override-audit delta clean.**
```bash
grep -o 'data-verdict="[A-Z-]*"' specs/handoffs/step-4.2-*-release-coordinator.html; diff ./.override-baseline ~/.claude/hooks/state/override-audit.log
```
PASS iff READY-TO-CLOSE/READY-WITH-CAVEATS and empty (or justified) diff.

## Score Sheet

| ID | PASS/FAIL/N-A | Notes |
|----|---------------|-------|
| O1–O6 | | |
| A1–A10 | | |

**Outcome: /6 · Adherence: /10 (minus N/A).**
**Key differentiator: O1–O3 pattern consistency with the existing codebase; A3/A4 show
whether questions and investigation drove it, or luck did.**
