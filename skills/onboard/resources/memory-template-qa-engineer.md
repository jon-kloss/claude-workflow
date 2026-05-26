---
agent: qa-engineer
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# qa-engineer — project memory

<!--
BOOTSTRAP SCOPE (read before seeding via /onboard):

EAGER (capture at bootstrap, keep current):
- Framework selection by layer (Vitest / Playwright / cargo test / etc.)
- Suite shape table (which layer runs which command, watch-OK?, parallelism)
- Visual-fidelity approach (structural-diff helper path, comparison axes, mockup paths)
- Known flakiness patterns (high-leverage — prevents re-creating the same flake)
- Test conventions (selectors, fixtures, client-injection vs vi.mock, network interception)

LAZY (defer to first real QA dispatch — DO NOT capture at bootstrap):
- Per-spec test inventories ("which tests cover which spec")
- Per-cluster coverage matrices
- Test counts per surface

The lazy content goes stale fast AND isn't useful until a specific QA dispatch runs against
a specific spec. Including it at bootstrap is what overruns the 3,500-word soft cap. When QA
is dispatched against a spec, IT updates the per-spec mapping then.

Use the stub section below for "Test inventory" and leave it terse at bootstrap.
-->

## Summary

<1-2 paragraph orientation: test framework(s) in use, what's tested at which layer, suite shape (smoke vs full), CI integration. 100-200 words.>

## Conventions (canonical — always observe)

- Unit framework: <Vitest | Jest | Mocha — where unit tests live>
- E2E framework: <Playwright | Cypress | Detox — where e2e tests live + naming>
- Test file naming: `<feature>.test.ts` (unit) / `<feature>.spec.ts` (e2e)
- Selectors: `data-testid` attribute; avoid fragile CSS class selectors
- Network interception in e2e: `page.route('**/api/**', ...)` with assertion on request payload
- Visual fidelity: structural diff (mandatory) via `tests/lib/structural-diff.ts`; pixel-diff opt-in via `@visual-pixel-diff` spec tag
- Fixtures: per-test in `tests/fixtures/`; never share mutable fixtures across tests
- Test DB: ephemeral via `tests/lib/db-fixture.ts`; `DATABASE_URL=memory://e2e` for fast in-memory mode

## Suite shape

| Layer | Framework | Path | Run command | Watch-OK? |
|---|---|---|---|---|
| Unit | Vitest | src/**/*.test.ts | `npm test` | yes |
| E2E | Playwright | tests/e2e/*.spec.ts | `npx playwright test` | no (slow) |
| Smoke | Playwright | tests/e2e/cuj-*.spec.ts | `npx playwright test cuj-` | no |

## Test inventory (lazy — populated per-spec on real dispatch)

At bootstrap, this section is intentionally empty. Per-spec test mappings are written by each real QA dispatch against a specific spec — not by /onboard. If you find yourself authoring a multi-row "which tests cover which spec" table here at bootstrap, stop: that content overruns the soft cap AND goes stale fast. Capture framework + conventions + flakiness patterns instead.

Format when this section populates (one row per QA dispatch):

| Spec slug | Tests added/touched | Notes |
|---|---|---|
| <slug> | <test file paths> | <coverage gaps, follow-ups> |

## Known flakiness patterns (this codebase)

<accumulated flaky-test patterns and their resolutions. Worth remembering so future tests don't re-create them.>

- **Parallel-worker race on in-memory store** (F-1, step-3.3-dark-mode-qa-engineer.html) — singleton state shared across Playwright workers; use `--workers=1` until fixed OR refactor store to per-worker
- **Theme flash on hard reload** — set viewport BEFORE goto; otherwise prefers-color-scheme media query resolves late

## Visual-fidelity testing

- Helper: `tests/lib/structural-diff.ts` (per-axis computed-style diff)
- Comparison axes: typography (font-family, size, weight, line-height), color (computed RGB → OKLCH equivalence), spacing (padding/margin/gap), layout (display/flex/grid), state coverage (hover/focus/active/disabled)
- Mockup paths: `specs/mockups/<slug>.html` rendered via `page.goto('file://<abs path>')`
- Pixel-diff: opt-in only via `@visual-pixel-diff` spec tag

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec> — <test infra change>

## Known issues / test tech debt

- <flaky tests, missing coverage, framework-version concerns. Source, severity, fix path.>

## Pointers

<a id="pointer-fixtures"></a>
### Fixture conventions
See `tests/fixtures/` directory + `tests/lib/db-fixture.ts`. Per-test ephemeral DB seeded fresh; no cross-test state leakage. The `memory://e2e` DB URL signals in-memory mode for Playwright runs.

<a id="pointer-playwright-config"></a>
### Playwright config
`playwright.config.ts` at project root. WebServer config auto-starts `next dev` with `DATABASE_URL=memory://e2e`. Default workers = 1 currently (see flakiness pattern above).

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This agent is the AUTHORITATIVE verification gate (per agents/qa-engineer.md). Findings route to implementers.
- Known flakiness patterns are HIGH-LEVERAGE memory — they prevent re-creating the same flake.
- Don't memorize per-spec test counts (those move) — memorize the FRAMEWORK + CONVENTIONS.
-->
