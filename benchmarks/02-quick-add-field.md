# Benchmark 02: Add a Field to a Model

## Task Description
"Add a 'nickname' field to the User model"

## Expected Shape
Single spec, `@layer(api)` (no UI in this repo), NOT `@trivial` — a new field with
validation is a behavioral change, so the full 3.3a–3.3i verify pass applies. If the model
is persisted, the spec should carry `@touches-data` (set at decomposition), which triggers
the data-architect gates (build Steps 3.1 + 3.3f).

## Setup
Create a project with:
- `models/user.ts` - User class with fields: id, name, email, createdAt
- `models/user.test.ts` - Existing tests for User model
- Existing pattern: all fields have validation (name: min 1 char, email: valid format)

Commit, and record `BASE=$(git rev-parse HEAD)`.

## Scoring Variables

```bash
BASE="<starter commit sha>"
SLUG=$(basename "$(ls specs/*.md | grep -v system.md | head -1)" .md)
EPIC="<epic id>"            # from: bd list --type=epic --all
```

## Rubric — Outcome (both sessions)

**O1. nickname field exists on the model.**
```bash
grep -n 'nickname' models/user.ts
```
PASS iff ≥1 hit in the field declarations.

**O2. Validation follows the existing pattern.**
```bash
grep -n -A3 'nickname' models/user.ts | grep -iE 'valid|min|max|length'
```
PASS iff the nickname field has validation in the same style as name/email (scorer
compares the printed lines against the name/email validators).

**O3. New test(s) for nickname exist.**
```bash
grep -c 'nickname' models/user.test.ts
```
PASS iff prints ≥1.

**O4. Full test suite passes.**
```bash
npx vitest run 2>/dev/null || npx jest 2>/dev/null || npm test
```
PASS iff the project's test command exits 0 (no regressions).

## Rubric — Adherence (Session A; artifacts on disk)

**A1. Spec exists, `@status(verified)`, `@layer` tag present.**
```bash
grep -l '@status(verified)' "specs/$SLUG.md" && grep -oE '@layer\([a-z-]+\)' "specs/$SLUG.md"
```
PASS iff exit 0 and exactly one `@layer(...)` prints.

**A2. Status progression draft→approved→implemented→verified in git history.**
```bash
git log --reverse -p -- "specs/$SLUG.md" | grep -oE '^\+.*@status\([a-z]+\)' | grep -oE 'draft|approved|implemented|verified' | uniq | tr '\n' ' '
```
PASS iff ordered subsequence including `approved`, ending `verified`.

**A3. ≥2 Scenarios with Given/When/Then** (at minimum: valid nickname accepted, invalid
rejected).
```bash
test "$(grep -c '^### Scenario' "specs/$SLUG.md")" -ge 2 && grep -qE '^[[:space:]]*-[[:space:]]*Given' "specs/$SLUG.md" && grep -qE '^[[:space:]]*-[[:space:]]*When' "specs/$SLUG.md" && grep -qE '^[[:space:]]*-[[:space:]]*Then' "specs/$SLUG.md"
```
PASS iff exit 0.

**A4. Investigation Findings logged in the spec** (build Step 3.1: ≥2 file:line refs +
a Decision line — the existing-validation pattern must be cited).
```bash
grep -A10 '## Investigation Findings' "specs/$SLUG.md" | grep -cE '\.[a-z]+:[0-9]+' ; grep -A10 '## Investigation Findings' "specs/$SLUG.md" | grep -c 'Decision:'
```
PASS iff first count ≥2 and second ≥1.

**A5. Handoff chain complete for `@layer(api)` (registry §1, §2).**
```bash
ls specs/handoffs/step-2-*-product-owner.html specs/handoffs/step-2.5-*-application-architect.html "specs/handoffs/step-3.2-$SLUG-backend-engineer.html" "specs/handoffs/step-3.3-$SLUG-security-architect.html" "specs/handoffs/step-3.3-$SLUG-devops-architect.html" "specs/handoffs/step-3.3-$SLUG-qa-engineer.html" "specs/handoffs/step-3.3-$SLUG-spec-sre-auditor.html"
```
PASS iff every listed file exists.

**A6. Reviewer verdict metas all PASS (registry §4)** — base handoff, or a fix-cycle
re-verify that ends PASS.
```bash
for role in security-architect devops-architect qa-engineer spec-sre-auditor; do grep -l 'data-verdict="PASS"' specs/handoffs/step-3.3-"$SLUG"-"$role"*.html >/dev/null 2>&1 || echo "NO-PASS: $role"; done
```
PASS iff prints nothing.

**A7. Data gates ran iff `@touches-data`.** **N/A-when** the spec is not tagged (and the
model is genuinely non-persisted — note which).
```bash
grep -q '@touches-data' "specs/$SLUG.md" && ls "specs/handoffs/step-3.1-$SLUG-data-architect.html" "specs/handoffs/step-3.3-$SLUG-data-architect.html"
```
PASS iff tag present AND both handoffs exist; N/A iff tag absent (record whether that was
reasonable).

**A8. Fix cycles symmetric (registry §1)** — for every reviewer re-verify cycle N there is
an implementer fix handoff N. **N/A-when** no fix-cycle files exist.
```bash
for f in specs/handoffs/step-3.3-"$SLUG"-*-fix-cycle-*.html; do [ -e "$f" ] || continue; n="${f##*fix-cycle-}"; n="${n%.html}"; ls specs/handoffs/step-3.2-"$SLUG"-*-fix-cycle-"$n".html || echo "ASYMMETRIC cycle $n"; done
```
PASS iff prints no `ASYMMETRIC` line.

**A9. Beads epic + Tests gate closed in order; VERIFICATION comment logged.**
```bash
bd list --type=epic --all; bd list --all | grep -i 'Tests:'; bd show "$EPIC"; bd comments "$EPIC" | grep -c 'VERIFICATION'
```
PASS iff epic + gate exist and are closed, gate close precedes epic close, and the
comment count is ≥1.

**A10. Release-coordinator handoff verdict READY-* ; override-audit delta clean.**
```bash
grep -o 'data-verdict="[A-Z-]*"' specs/handoffs/step-4.2-*-release-coordinator.html; diff ./.override-baseline ~/.claude/hooks/state/override-audit.log
```
PASS iff verdict is `READY-TO-CLOSE`/`READY-WITH-CAVEATS` AND the diff is empty (or every
new override line is concretely justified).

## Score Sheet

| ID | PASS/FAIL/N-A | Notes |
|----|---------------|-------|
| O1–O4 | | |
| A1–A10 | | |

**Outcome: /4 · Adherence: /10 (minus N/A).**
**Key differentiator: O2 — does the new field follow the existing validation pattern? For
Session A, A4 shows whether investigation actually cited that pattern before coding.**
