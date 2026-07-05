# Benchmark 01: Fix a Typo

## Task Description
"Fix the typo in README.md - 'recieve' should be 'receive'"

## Expected Shape
Single spec, `@trivial` + `@layer(infra)` set at decomposition. This benchmark scores the
**`@trivial` path**: verification scales down to the floor and no further. Per the D1
decision (evaluation-fixes plan, 2026-07-04) and build SKILL.md rule 4 ("Verification
never scales below the @trivial floor"), `@trivial` is the ONLY verification-scaling knob
and it is set at decomposition, never during build. The floor skips the 3.3d/3.3e/3.3g
reviewer dispatches — everything else (spec, TDD, test suite, code review, 3.3h
sre-intent-audit, release gate) still runs.

## Setup
Create a git repo with a README.md containing the typo "recieve" in 3 locations:
- Line 5: "Users recieve a confirmation email"
- Line 12: "You will recieve a notification"
- Also in CONTRIBUTING.md line 8: "Contributors recieve credit"

Commit, and record `BASE=$(git rev-parse HEAD)`.

## Scoring Variables

```bash
BASE="<starter commit sha>"                                          # noted at setup
SLUG=$(basename "$(ls specs/*.md | grep -v system.md | head -1)" .md)
EPIC="<epic id>"                                                 # from: bd list --type=epic --all
```

## Rubric — Outcome (both sessions)

**O1. All 3 instances fixed, across both files** — did anyone look past the one instance
mentioned?
```bash
test "$(cat README.md CONTRIBUTING.md | grep -ci 'recieve')" -eq 0
```
PASS iff exit 0.

**O2. Nothing else modified.**
```bash
git diff "$BASE"..HEAD -- README.md CONTRIBUTING.md | grep -E '^[+-][^+-]' | grep -viE 'rec(ie|ei)ve' | wc -l
```
PASS iff prints `0` (every changed content line is a typo-fix line).

**O3. A regression check exists** (the TDD floor: a test asserting no 'recieve' remains —
see the typo example in build SKILL.md).
```bash
grep -rl 'recieve' tests/ test/ scripts/ 2>/dev/null | wc -l
```
PASS iff prints ≥1 (some test/check file asserts the absence of the misspelling).

## Rubric — Adherence (Session A; artifacts on disk)

**A1. Spec exists and reached verified.**
```bash
grep -l '@status(verified)' "specs/$SLUG.md"
```
PASS iff exit 0.

**A2. `@trivial` was set at decomposition, not added during build** (the D1 rule).
```bash
git show "$(git log --reverse --format=%H -- "specs/$SLUG.md" | head -1):specs/$SLUG.md" | grep -q '@trivial'
```
PASS iff exit 0 (the first committed version of the spec already carries the tag).

**A3. `@layer` tag present (registry §8).**
```bash
grep -qE '@layer\((api|ui|full-stack|cli|infra|gameplay)\)' "specs/$SLUG.md"
```
PASS iff exit 0.

**A4. Status progression draft→approved→implemented→verified visible in git history.**
```bash
git log --reverse -p -- "specs/$SLUG.md" | grep -oE '^\+.*@status\([a-z]+\)' | grep -oE 'draft|approved|implemented|verified' | uniq | tr '\n' ' '
```
PASS iff output is `draft approved implemented verified ` (a batched commit may collapse
adjacent states — accept a strictly-ordered subsequence that includes `approved` and ends
in `verified`; note any collapse).

**A5. ≥1 Scenario with Given/When/Then steps.**
```bash
test "$(grep -c '^### Scenario' "specs/$SLUG.md")" -ge 1 && grep -qE '^[[:space:]]*-[[:space:]]*Given' "specs/$SLUG.md" && grep -qE '^[[:space:]]*-[[:space:]]*When' "specs/$SLUG.md" && grep -qE '^[[:space:]]*-[[:space:]]*Then' "specs/$SLUG.md"
```
PASS iff exit 0.

**A6. Verification floor respected — 3.3h ran even for `@trivial`** (build SKILL.md:
"Do not skip this step. It runs for every spec").
```bash
ls "specs/handoffs/step-3.3-$SLUG-spec-sre-auditor.html" && grep -o 'data-verdict="[A-Z-]*"' "specs/handoffs/step-3.3-$SLUG-spec-sre-auditor.html"
```
PASS iff the file exists and the verdict is `PASS`. (Absence of security/devops/qa
handoffs is CORRECT here — that is the floor, not a failure. Their presence is not
penalized either.)

**A7. Beads epic + Tests gate exist and are closed, gate before epic.**
```bash
bd list --type=epic --all; bd list --all | grep -i 'Tests:'; bd show "$EPIC"
```
PASS iff both exist, both closed, and the Tests-gate close precedes the epic close
(scorer reads the two timestamps from `bd show`).

**A8. VERIFICATION comment logged on the epic.**
```bash
bd comments "$EPIC" | grep -c 'VERIFICATION'
```
PASS iff prints ≥1.

**A9. Release gate: release-coordinator handoff with a closing verdict (registry §1, §4).**
```bash
ls specs/handoffs/step-4.2-*-release-coordinator.html && grep -o 'data-verdict="[A-Z-]*"' specs/handoffs/step-4.2-*-release-coordinator.html
```
PASS iff the file exists and the verdict is `READY-TO-CLOSE` or `READY-WITH-CAVEATS`.

**A10. Override-audit delta empty or justified.**
```bash
diff ./.override-baseline ~/.claude/hooks/state/override-audit.log
```
PASS iff no new lines, or every added line's reason concretely justifies a bypass in THIS
run (the reason text is in the line; scorer reads it).

## Score Sheet

| ID | PASS/FAIL/N-A | Check run | Notes |
|----|---------------|-----------|-------|
| O1 | | grep -ci recieve | |
| O2 | | git diff filter | |
| O3 | | regression check exists | |
| A1 | | @status(verified) | |
| A2 | | @trivial in first commit | |
| A3 | | @layer tag | |
| A4 | | status progression | |
| A5 | | scenario G/W/T | |
| A6 | | sre-auditor handoff PASS | |
| A7 | | epic + Tests gate order | |
| A8 | | VERIFICATION comment | |
| A9 | | release-coordinator verdict | |
| A10 | | override-audit delta | |

**Outcome: /3 · Adherence: /10.**
**Key differentiator: O1 (finding the other 2 instances), and whether the `@trivial` path
stayed cheap (compare wall-clock) while A1–A10 still hold.**
