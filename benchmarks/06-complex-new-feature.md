# Benchmark 06: Build a New Feature with External Integration

## Task Description
"Add webhook notifications - when a user completes an action, send a POST to their configured webhook URL"

## Expected Shape
Multiple ordered specs — this benchmark scores **decomposition quality**. A reasonable
map: `webhook-data-model` (`@layer(api)`, `@touches-data`) ← `webhook-delivery-service`
(`@layer(api)`, retry/timeout/isolation) ← `action-integration` (`@layer(api)`), with
`@depends-on` ordering and the independence test evidenced in the application-architect
handoff. Design should relay questions about retry policy, timeout, auth/signing, payload
format, and failure handling instead of defaulting. If the session decomposes a webhook
configuration UI out of "their configured webhook URL", the UI-conditional criteria below
activate.

## Setup
Create a project with:
- `models/user.ts` - User model (no webhook field yet)
- `services/actions.ts` - Action completion service
- `config/` - Configuration directory with existing patterns
- `tests/` - Test suite with existing integration test patterns
- Existing pattern: services use dependency injection, errors logged to console

Commit, and record `BASE=$(git rev-parse HEAD)`.

## Scoring Variables

```bash
BASE="<starter commit sha>"
EPIC="<epic id>"                                   # from: bd list --type=epic --all
SPECS=$(ls specs/*.md | grep -v system.md)       # all feature specs
```

## Rubric — Outcome (both sessions)

**O1. Webhook URL storage added to the user model.**
```bash
grep -n -i 'webhook' models/user.ts
```
PASS iff ≥1 hit.

**O2. Delivery has a configurable timeout.**
```bash
grep -rni 'timeout' services/ src/ config/ 2>/dev/null | grep -i webhook
```
PASS iff the webhook HTTP call carries a timeout sourced from config, not hardcoded-only.

**O3. Retry with backoff, bounded.**
```bash
grep -rniE 'backoff|retry' services/ src/ 2>/dev/null | grep -vi test
```
PASS iff retries are bounded (max attempts) with growing delay — scorer opens the
implementation and confirms no infinite retry.

**O4. Failure isolation — webhook failure does NOT fail the user action.**
```bash
grep -rln 'webhook' tests/ | xargs grep -lniE '5xx|500|fail|timeout|unreachable' 2>/dev/null
```
PASS iff a test exists asserting the action still succeeds when delivery fails/times out
(scorer opens the matched test and confirms the assertion direction).

**O5. Edge cases tested: invalid URL, timeout, 5xx, user without webhook.**
```bash
for pat in 'invalid' 'timeout' '5..\|500' 'no.*webhook\|without.*webhook\|null'; do grep -rliE "$pat" tests/ >/dev/null 2>&1 || echo "MISSING: $pat"; done
```
PASS iff no `MISSING` line (scorer confirms each hit is a webhook test, not noise).

**O6. Full suite passes.**
```bash
npx vitest run 2>/dev/null || npx jest 2>/dev/null || npm test
```
PASS iff exit 0.

## Rubric — Adherence (Session A; artifacts on disk)

**A1. Real decomposition: ≥2 feature specs, all verified, each with exactly one `@layer`.**
```bash
test "$(echo "$SPECS" | wc -w)" -ge 2; for s in $SPECS; do grep -l '@status(verified)' "$s" >/dev/null || echo "NOT-VERIFIED: $s"; test "$(grep -c '@layer(' "$s")" -eq 1 || echo "LAYER: $s"; done
```
PASS iff ≥2 specs and no complaint lines.

**A2. Dependency graph valid: every `@depends-on` target exists; no cycle.**
```bash
for dep in $(grep -ho '@depends-on([a-z0-9-]*)' specs/*.md | sed 's/@depends-on(//;s/)//' | sort -u); do ls "specs/$dep.md" >/dev/null || echo "DANGLING: $dep"; done
```
PASS iff no `DANGLING` line (cycle check: scorer walks the printed graph — 2–4 specs is
eyeball-tractable).

**A3. Independence test evidenced in the architect handoff** — the decomposition table
plus seam rationale (why THIS cut), not just a spec list.
```bash
ls specs/handoffs/step-2.5-*-application-architect.html; grep -ciE 'independen|seam' specs/handoffs/step-2.5-*-application-architect.html
```
PASS iff the handoff exists, contains a per-spec decomposition table in `findings`, and
≥1 independence/seam justification (scorer opens it in a browser).

**A4. Socratic depth: retry, timeout, auth/signing, payload, and failure handling were
asked, not defaulted.**
```bash
grep -oiE 'retry|timeout|auth|sign|payload|failure' specs/handoffs/step-2-*-product-owner.html | sort | uniq -c
```
PASS iff ≥4 of the 5 topics appear in the PO handoff's resolved questions/open-questions
(and the scorer's session notes confirm relayed AskUserQuestion rounds).

**A5. Status progression per spec (draft→approved→implemented→verified).**
```bash
for s in $SPECS; do echo "== $s"; git log --reverse -p -- "$s" | grep -oE '^\+.*@status\([a-z]+\)' | grep -oE 'draft|approved|implemented|verified' | uniq | tr '\n' ' '; echo; done
```
PASS iff every spec shows an ordered progression including `approved`, ending `verified`.

**A6. Scenario depth: every non-`@trivial` spec has ≥3 Scenarios with Given/When/Then.**
```bash
for s in $SPECS; do grep -q '@trivial' "$s" && continue; test "$(grep -c '^### Scenario' "$s")" -ge 3 || echo "THIN: $s"; done
```
PASS iff no `THIN` line.

**A7. Handoff chain complete per spec (registry §1, §2)** — implementer + the four
reviewer/auditor handoffs for every non-`@trivial` spec; data-architect where
`@touches-data`.
```bash
for s in $SPECS; do slug=$(basename "$s" .md); grep -q '@trivial' "$s" && continue; ls "specs/handoffs/step-3.2-$slug-backend-engineer.html" specs/handoffs/step-3.2-"$slug"-frontend-engineer.html 2>/dev/null | head -1; for role in security-architect devops-architect qa-engineer spec-sre-auditor; do ls "specs/handoffs/step-3.3-$slug-$role.html" >/dev/null 2>&1 || echo "MISSING: $slug $role"; done; grep -q '@touches-data' "$s" && { ls "specs/handoffs/step-3.3-$slug-data-architect.html" >/dev/null 2>&1 || echo "MISSING: $slug data-architect"; }; done
```
PASS iff no `MISSING` line and each spec has ≥1 implementer handoff.

**A8. Verdict metas all end PASS (registry §4), fix cycles symmetric.**
```bash
for s in $SPECS; do slug=$(basename "$s" .md); grep -q '@trivial' "$s" && continue; for role in security-architect devops-architect qa-engineer spec-sre-auditor; do grep -l 'data-verdict="PASS"' specs/handoffs/step-3.3-"$slug"-"$role"*.html >/dev/null 2>&1 || echo "NO-PASS: $slug $role"; done; done; for f in specs/handoffs/step-3.3-*-fix-cycle-*.html; do [ -e "$f" ] || continue; n="${f##*fix-cycle-}"; n="${n%.html}"; ls specs/handoffs/step-3.2-*-fix-cycle-"$n".html >/dev/null 2>&1 || echo "ASYMMETRIC: $f"; done
```
PASS iff prints nothing.

**A9. Build order respected dependencies** — no spec reached `@status(implemented)`
before its `@depends-on` prerequisites reached `@status(verified)`.
```bash
git log --reverse --format='%h %ad %s' --date=format:'%H:%M' -p -- specs/*.md | grep -E '^(commit|[0-9a-f]{7} |\+.*@status)' | head -60
```
PASS iff, reading commit order, each dependent spec's `implemented` write comes after its
prerequisite's `verified` write (scorer walks the printed sequence).

**A10. UI-conditional: mockups, Mount Map, no dead handlers.** **N/A-when** no spec is
`@layer(ui|full-stack)`.
```bash
UISPECS=$(grep -lE '@layer\((ui|full-stack)\)' specs/*.md 2>/dev/null); echo "$UISPECS"; for s in $UISPECS; do slug=$(basename "$s" .md); ls specs/mockups/"$slug"* >/dev/null 2>&1 || echo "NO-MOCKUP: $slug"; done
```
And if `$UISPECS` has ≥2 entries (design rule 16):
```bash
INTEG=$(grep -l '@integration' specs/*.md | grep -v 'integration-skip'); echo "$INTEG"; grep -A20 '## Mount Map' $INTEG; for s in $UISPECS; do [ "$s" = "$INTEG" ] && continue; grep -q '@mounts-in(' "$s" || grep -q '@mount-skip(' "$s" || echo "ORPHAN: $s"; done; bd comments "$EPIC" | grep 'DEAD UI SCAN'
```
PASS iff every UI spec has a mockup; with ≥2 UI specs, exactly one `@integration` spec
with a `## Mount Map` covering each feature, no `ORPHAN` line, and the dead-UI-scan
comment reads `Verdict: PASS`.

**A11. CUJ e2e exists and drives the real entry point.** **N/A-when** no
`@layer(ui|full-stack)` spec (build Step 4.1 skip rule).
```bash
ls tests/e2e/cuj-*.spec.* tests/e2e/mount-map-reachability.spec.* 2>/dev/null; ls specs/handoffs/step-4.1-*-qa-engineer.html && grep -o 'data-verdict="[A-Z-]*"' specs/handoffs/step-4.1-*-qa-engineer.html
```
PASS iff ≥1 `cuj-*` e2e file per `## Critical User Journeys` journey, the reachability
spec exists, and the step-4.1 handoff verdict is `PASS`.

**A12. Epic close discipline: Tests gate + epic closed in order, VERIFICATION comment,
release-coordinator READY-*, override-audit delta clean.**
```bash
bd list --type=epic --all; bd list --all | grep -i 'Tests:'; bd show "$EPIC"; bd comments "$EPIC" | grep -c 'VERIFICATION'; grep -o 'data-verdict="[A-Z-]*"' specs/handoffs/step-4.2-*-release-coordinator.html; diff ./.override-baseline ~/.claude/hooks/state/override-audit.log
```
PASS iff gate closed before epic, ≥1 VERIFICATION comment, verdict
`READY-TO-CLOSE`/`READY-WITH-CAVEATS`, and empty (or per-line justified) override delta.

## Score Sheet

| ID | PASS/FAIL/N-A | Notes |
|----|---------------|-------|
| O1–O6 | | |
| A1–A12 | | |

**Outcome: /6 · Adherence: /12 (minus N/A).**
**Key differentiator: O4 (failure isolation) and A3 (decomposition justified by the
independence test, with dependency order actually honored — A9).**
