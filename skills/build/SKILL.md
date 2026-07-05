---
name: build
description: Use after /design to implement approved specs - validates specs exist, builds dependency graph, auto-iterates through specs in @depends-on order with codebase analysis, spec-driven TDD, full verification, and spec status updates. Pauses for /respec if spec drift detected.
---

<skill_overview>
Build skill that consumes `@status(approved)` Gherkin specs produced by `/design` and implements them in dependency order. For each spec: investigates codebase, runs spec-driven TDD (RED/GREEN/REFACTOR), verifies with full suite + code review + spec coverage, and updates `@status(verified)`. Auto-iterates through all specs. Pauses and directs to `/respec` if a spec needs modification, or `/design` if the work needs entirely new specs.

**Role-agent orchestration (experimental branch).** This skill is the orchestrator. The deep procedural work is delegated to specialized role agents in `agents/`:
- `backend-engineer` / `frontend-engineer` — Step 3.2 TDD
- `security-architect` — Step 3.3d security-review
- `qa-engineer` — Step 3.3g per-spec verification + Step 4.1 epic e2e CUJs
- `spec-sre-auditor` — Step 3.3h sre-intent-audit

Each role agent produces an HTML handoff at `specs/handoffs/<step>-<slug>-<role>.html`. The `require-handoff-artifact.sh` hook blocks `@status(verified)` writes if any required handoff is missing or schema-invalid. See `docs/role-agent-handoff-schema.md`.

**Parallel-dispatch pattern.** To dispatch multiple role agents concurrently (e.g. `security-architect` + `devops-architect` + `data-architect` for Step 3.3's review pass), include MULTIPLE `Agent` tool calls in a SINGLE message. The harness fans them out in parallel; the tool result confirms concurrent launch. Splitting calls across separate messages serializes them and wall-clock grows linearly.

**Dispatched agents cannot ask the user questions.** Per `docs/agent-protocol.md` §2, `AskUserQuestion` errors inside subagents. Agents return questions in their handoff's `open-questions` section; after each dispatch, read that section — if any `<li data-question data-blocking="true">` exists, relay it to the user via AskUserQuestion yourself, then re-dispatch the same role with the answers appended to the prompt. Cap: 3 question rounds per step, then escalate to the user with a written summary.

**Inline-synthesis fallback.** If the `Agent` tool is not available in your toolset (i.e. you are yourself a dispatched subagent and cannot dispatch further), fall back to inline synthesis: read each role's `agents/<role>.md` prompt, perform the role's work yourself, produce the same handoff file at the same path, and mark it with `<note data-synthesized="true">This handoff was synthesized inline because the Agent tool was unavailable.</note>` in the `findings` section. In inline mode, ask the user directly via AskUserQuestion when it is available in your toolset; when it is not (you are a dispatched subagent), record questions in the handoff's `open-questions` section and return them to your dispatcher per `docs/agent-protocol.md` §2. The audit trail stays schema-compliant; what's lost is diversity-of-perspective.

**Known limitation: TaskCreate reminders.** The Claude Code harness emits `system-reminder` messages suggesting `TaskCreate` periodically. They come from the harness itself, not our hooks, and cannot be silenced from the workflow side. Beads is the canonical task tracker (per the SessionStart hook); ignore the TaskCreate reminders.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: Entry validation — specs must exist with associated beads tasks. No specs = no build.
- **RIGID**: Spec-driven TDD — failing tests from scenarios BEFORE implementation. Every spec, no exceptions.
- **RIGID**: Verification never scales below the `@trivial` floor — `@trivial` is the only scaling knob, and it is set at decomposition (/design), never during build. Non-trivial specs get the full suite + code review + spec coverage + reviewer pass, identically.
- **RIGID**: Pause on spec drift — fundamental spec changes require /respec (modify existing spec) or /design (new specs), not silent fixes.
- **FLEXIBLE**: Investigation depth scales with spec complexity.
- **FLEXIBLE**: Per-task review checkpoints via executing-plans for multi-scenario specs.
</rigidity_level>

<quick_reference>
## Usage

```
/build              # Interactive — pauses for user sign-off after each spec
/build --auto       # Autonomous — skips EVERY interactive pause: per-spec sign-off (Step 3.4)
                    # is skipped, and escalations that would use AskUserQuestion (e.g. the
                    # Step 3.3i cycle cap) instead halt with a written summary. All
                    # verification agents still run — --auto never skips verification.
```

## Build Flow

```
/build [--auto]
  -> Entry validation: specs @status(approved|implemented) + beads epic exist
  -> Dependency graph: topological sort, announce lanes + parallel-risk warnings, proceed
  -> Per spec (auto-iterates): prerequisites verified -> investigate -> spec-driven TDD
     (RED->GREEN->REFACTOR) -> API wiring checkpoint (full-stack) -> dead UI scan
     -> verify pass 3.3a-3.3i -> user sign-off (unless --auto) -> @status(verified), close task
  -> Phase 4: epic e2e CUJs (multi-spec UI) -> final verification -> close Tests gate + epic
```

## Hard Constraints (every spec, no exceptions)

1. Specs must exist in `specs/` with `@status(approved)` or `@status(implemented)`
2. Codebase investigated before writing code
3. Failing tests generated FROM spec scenarios before implementation (TDD)
4. Full verification suite + code review agent + spec coverage check (floor: `@trivial`, set at decomposition)
5. API integration check: every UI button/form/nav wired to real API calls — not stubs (UI specs with API endpoints; verified by qa-engineer in Step 3.3g)
6. Layer awareness: full-stack specs require ALL layers (API + UI + wiring) before @status(verified)
7. API wiring checkpoint (Step 3.2.5): full-stack UI must be wired to real data layer before verification
8. Spec @status updated after verification passes
9. Investigation findings logged on the epic via `bd comments add`
10. Every verification failure logged as a structured `bd comments add` entry
11. Continuous verifier agent gates task closure (multi-scenario specs)
12. Pause and direct to /respec if spec needs changes, or /design if new specs are needed
13. VERIFICATION comment logged on epic before closing
14. Playwright e2e tests for all CUJs before epic close (multi-spec UI epics)
15. Feature mounted in the product: a `@layer(ui|full-stack)` spec cannot reach `@status(verified)` unless it is in the `@integration` spec's `## Mount Map` (or imported by the app entry). Enforced by `require-feature-mounted.sh`. Override: `@mount-skip(reason)` (≥2 UI-spec epics)
16. Epic e2e drives the REAL app entry point and asserts every Mount Map row is reachable — no isolated-component or deep-link tests (Step 4.1)
</quick_reference>

<gherkin_spec_reference>
## Reading Specs for Implementation

/build reads spec files generated by /design. Understanding the format is critical for: determining build order from `@depends-on` tags, generating tests from scenarios, and checking implementation coverage.

**Detailed format reference** — tag list, decomposition heuristics, scenario→test mapping, full templates — lives in the design skill's resources: [../design/resources/gherkin-spec-reference.md](../design/resources/gherkin-spec-reference.md). Load it when you need to translate a scenario into a failing test or when interpreting an unfamiliar spec structure.

### Status Tags — /build dispatch table

| Status | /build Action |
|---|---|
| `@status(draft)` | SKIP — tell user to run /design |
| `@status(approved)` | START — this is /build's input |
| `@status(implemented)` | RESUME — continue implementation |
| `@status(verified)` | DONE — skip, prerequisite satisfied |

### Parallel-Risk Tag

`@parallel-risk(feature-slug)` indicates this spec modifies the same files as another independent spec (no `@depends-on` relationship). Both specs remain parallel. /build displays a warning about potential merge conflicts and recommends building the smaller/simpler spec first.

### Scenario → failing test

Each `### Scenario:` maps to one test: Given → arrange, When → act, Then → assert (full mapping table and a worked example are in the resource above). The test MUST fail before implementation; implementation makes it pass.

### Living Document Updates During Build

Specs are living documents. Update during implementation when:
- **New edge cases discovered** — add new Scenarios
- **A Scenario is wrong** — correct it (don't implement wrong behavior to match the spec)
- **Technical Context changes** — new fields, different data structures
- **New dependencies emerge** — add `@depends-on` tags

**What NOT to change:**
- Do not remove scenarios — mark with `@deprecated` and explain why
- Do not change the feature's core purpose (As/I want/So that) — that requires /respec or /design

**CRITICAL: If the spec needs FUNDAMENTAL changes** (wrong approach, missing feature, incorrect data model, contract changes), **STOP and tell user to run `/respec`** to modify the existing spec (traces blast radius, propagates to dependencies, regresses statuses). Use `/design` only if entirely new specs are needed. Do not silently rewrite the spec during implementation.
</gherkin_spec_reference>

<when_to_use>
**Use /build when approved specs exist and you're ready to implement** — specs at `@status(approved|implemented)`, beads epic exists, /design confirmed. **Don't use it for** new work with no specs, pure questions, or work needing design decisions — run `/design` first.
</when_to_use>

<the_process>

## Phase 1: Entry Validation

### Parse flags
Check if `--auto` was passed as an argument to `/build`:
- `--auto`: Skip EVERY interactive pause — the per-spec sign-off (Step 3.4) is skipped, and any escalation that would use AskUserQuestion (cycle cap, routing exceptions) instead halts with a written summary for the user. All verification agents still run.
- Default (no flag): Pause after each spec for user to confirm the work matches expectations.

### Check for specs and statuses
`ls specs/ 2>/dev/null` — no `specs/` directory or no spec files: "No specs found. Run `/design` first to generate Gherkin spec files." STOP.

Read each spec's `@status` tag per the dispatch table above. If ALL specs are `@status(verified)`: "All specs are verified. Nothing to build." STOP. If ALL non-verified specs are `@status(draft)`: "Specs exist but none are approved. Run `/design` to complete the reality check." STOP.

### Check beads epic
`bd list --status=open --type=epic 2>/dev/null` — if no open beads epic references the specs: "No beads epic found. Run `/design` to set up tracking." STOP.

Note: Per-spec implementation tasks are created by /build after investigation (Step 3.1), not by /design. Only the epic and Tests gate task need to exist at entry.

## Phase 2: Dependency Graph

Read all spec files, extract `@depends-on(...)` and `@parallel-risk(...)` tags, build a directed dependency graph, topological-sort for build order. Validate: no circular dependencies; every referenced spec exists.

**Parallel risk:** `@parallel-risk` pairs remain parallel (never sequenced by `@depends-on`); build the smaller/simpler spec first and warn about the file overlap in the announcement.

### Graph Announcement

Announce the build order as a printed message — lanes, sequential chains, and parallel-risk warnings — then proceed immediately. Do NOT ask the user to confirm the plan; there is no decision to gate on.

```
Build order based on spec dependencies:

Lane 1 (independent):
  ├── specs/user-registration.md (no dependencies)
  └── specs/email-service.md (no dependencies)

Lane 2 (after Lane 1):
  └── specs/user-authentication.md (depends on: user-registration)

⚠ Parallel-risk: user-registration.md and email-service.md share file overlap (user-routes.ts)
  → Building email-service.md first (smaller/simpler)

Proceeding in this order.
```

Lanes are informational: /build currently implements specs sequentially in topological order. True parallel building (worktree-per-lane with orchestrator merges) is future work — do not attempt it ad hoc. If the user interjects to reorder specs within a lane, honor it; no `@depends-on` tags are modified.

### Dependency validation before starting a spec

Before starting work on a spec, verify ALL its `@depends-on` prerequisites are `@status(verified)`:
- If a prerequisite is NOT verified: skip this spec, try the next unblocked one
- If ALL remaining specs are blocked: inform user which prerequisites are missing
- If a prerequisite doesn't exist as a spec file: STOP, tell user to run /design

## Phase 3: Per-Spec Iteration

For each spec in build order (auto-iterates):

### Step 3.1: Investigate

**Layer Detection (orchestrator's job).** Read the spec's `@layer(...)` tag — this drives which role agents you dispatch downstream.

| `@layer(...)` | Implementer | Required Step-3.3 reviewers |
|---|---|---|
| `api` | backend-engineer | security + devops + (data if `@touches-data`) |
| `ui` | frontend-engineer | security + devops + (data if `@touches-data`) |
| `full-stack` | backend-engineer then frontend-engineer | security + devops + (data if `@touches-data`) |
| `cli` | backend-engineer | security + devops |
| `infra` | backend-engineer | security + devops |

`@touches-data` is the single trigger for data-architect gates, regardless of layer. The `require-handoff-artifact.sh` hook warns — does not block — when an `@layer(api|full-stack)` spec lacks the tag; if the spec genuinely touches persistent data, add `@touches-data` to the spec (a decomposition omission) rather than overriding.

For full-stack specs, `@status(verified)` requires BOTH layers implemented and wired. `require-handoff-artifact.sh` enforces this.

For `@layer(ui|full-stack)` specs in an epic with ≥2 user-facing specs, `@status(verified)` ALSO requires the feature to be **mounted in the product** — listed in the `@integration` spec's `## Mount Map` (or imported by the app entry). A feature whose component exists and whose own tests pass but which the running app never mounts is a disconnected demo card, not a verified feature (see `docs/incidents.md#squashbuckler-2026-05-31`). `require-feature-mounted.sh` enforces this at the `@status(verified)` write; the frontend-engineer must wire the feature into the shell as part of implementation, not leave it standalone. Override (sub-component mounted by another feature): `@mount-skip(reason)`.

**Dispatch codebase-investigator:**

```
Agent tool (subagent_type: hyperpowers:codebase-investigator):
"Find existing patterns for specs/<slug>.md. Report file paths, line numbers, conventions. Read the
PO handoff (step-2-<slug>-product-owner.html) and application-architect handoff (step-2.5-...) for
context. If the spec has a ## UI Design section, also read PRODUCT.md, DESIGN.md, and the mockup."
```

For specs involving external APIs/libraries/unfamiliar patterns, also dispatch `hyperpowers:internet-researcher` in parallel.

**Log findings into the spec.** Add a `## Investigation Findings` section with ≥3 lines including ≥2 file:line refs and a Decision: line. `hooks/require-investigation-findings.sh` blocks `@status(implemented)` writes without this section. Also log a summary as a `bd comments add` entry on the epic for the audit trail.

**Create the beads implementation task.** With investigation context in hand, create this spec's implementation task now — description includes the spec path, key file paths, patterns to follow, and integration points from the findings:

```bash
bd create "Implement: <feature name>" --type task --priority 2 \
  --description "Spec: specs/<slug>.md. Files: <paths>. Patterns: <conventions>. Integration points: <from findings>."
bd dep add <new-task-id> <epic-id> --type parent-child
```

**Refinement.** Invoke `hyperpowers:sre-task-refinement` to surface boundary conditions, error paths, and at least 1 domain edge case not in the spec.

**Skip the investigation findings section when:** Spec is `@trivial`. Otherwise use `@investigation-skip(reason)` only when the work is so derivative that codebase investigation adds nothing — rare.

#### Data-Architect Investigation (when `@touches-data`)

**Dispatch the data-architect role agent** when the spec is tagged `@touches-data`. This runs as a focused augment to the general investigation: schema context, existing query patterns near the spec's surface, integrity invariants, recent migrations.

```
Agent tool (subagent_type: data-architect, run_in_background: false):
"You are running the Step 3.1 data investigation for specs/<slug>.md. Read the application-architect
handoff, the spec's Technical Context, and the schema definition files. Produce a Step 3.1
investigation handoff augment at:
  specs/handoffs/step-3.1-<slug>-data-architect.html
covering: tables/columns touched, existing query patterns, invariants (FKs, unique, soft-delete),
recent migrations, indexes near the spec's surface."
```

(The Step 3.3 data safety REVIEW is a separate dispatch — see Step 3.3f below.)

### Step 3.2: Spec-Driven TDD

**Dispatch the appropriate role-implementer agent(s) based on the spec's `@layer`.** Implementation procedure (RED/GREEN/REFACTOR, layer-aware tests, behavior-vs-render distinction, mockup-first UI build) lives in the agent prompts.

| `@layer(...)` | Agents to dispatch | Order |
|---|---|---|
| `api`, `cli`, `infra` | `backend-engineer` only | sequential |
| `ui` | `frontend-engineer` only | sequential |
| `full-stack` | `backend-engineer` THEN `frontend-engineer` | sequential — backend first so frontend wires to a real API |

```
Agent tool (subagent_type: backend-engineer, run_in_background: false):
"You are running Step 3.2 (TDD) for specs/<slug>.md (@layer=<layer>). Read the application-architect
handoff (step-2.5), product-owner handoff (step-2), and the spec's Investigation Findings section.
For every ### Scenario:, apply RED→GREEN→REFACTOR with at-least-one test per scenario. Produce your
handoff at: specs/handoffs/step-3.2-<slug>-backend-engineer.html"
```

For `@layer(full-stack)`, dispatch frontend-engineer after backend returns:

```
Agent tool (subagent_type: frontend-engineer, run_in_background: false):
"You are running Step 3.2 (TDD, UI portion) for specs/<slug>.md (@layer=full-stack). Read the
backend-engineer handoff to know what endpoints exist. Start UI implementation from the mockup at
specs/mockups/<slug>/. Wire UI to real API. Assert visual fidelity at REFACTOR. Produce your handoff
at: specs/handoffs/step-3.2-<slug>-frontend-engineer.html"
```

After the engineer agents return, verify their handoffs are at the expected paths and the test files referenced in their `acceptance-criteria` exist. The `hyperpowers:test-runner` agent will execute the tests in Step 3.3a.

#### Continuous Verifier (multi-scenario specs)

For specs with multiple rules/scenarios, spawn a verifier agent after the first implementation task:

```
Agent tool (subagent_type: hyperpowers:code-reviewer, run_in_background: false):
"You are the CONTINUOUS VERIFIER for [spec name].

SPEC: specs/<slug>.md
TASK: <bead-id>
EPIC: <bead-id>

## Context
- Spec: [paste spec file contents]
- Task: [current task description]
- Git diff: [paste diff]

## Review these 5 dimensions:
1. Correctness against spec — does code implement the Given/When/Then steps?
2. Consistency with codebase — does new code match existing patterns?
3. Edge cases and error paths — empty/nil/zero, double calls, failure cleanup
4. Integration soundness — events at right lifecycle point, consumer handles all variants
5. Dead weight — declared but never called, config accepted but not acted on

## Output
VERIFIER: PASS | PASS_WITH_NOTES | FAIL
- [CRITICAL] C1: description. Fix: recommendation
- [IMPORTANT] I1: description. Fix: recommendation
- [MINOR] M1: description"
```

| Severity | Action |
|---|---|
| **CRITICAL** | CANNOT close task. Fix and re-submit. |
| **IMPORTANT** | Address or justify deferral before closing. |
| **MINOR** | Logged. Does not block. |

#### Living Document Updates

During implementation, update the spec when new edge cases or technical corrections are discovered. For any NEW scenario added to the spec, write a failing test BEFORE implementing it.

Update spec status: `@status(approved)` → `@status(implemented)` when implementation begins.

### Step 3.2.5: API Wiring Checkpoint (Full-stack specs)

**BLOCKING GATE for full-stack specs.** The frontend-engineer agent owns the wiring procedure (its Phase 3: replace mocks with real API calls, follow the project's API client pattern, wire loading/error/empty states, no hardcoded data). The orchestrator's job is to verify the agent's handoff documents wiring evidence.

**Skip when:** Spec is `@layer(api|cli|infra)` (no UI to wire). Deterministic check: `grep -E '@layer\((api|cli|infra)\)' specs/<slug>.md`.

**Verify wiring evidence in the frontend-engineer handoff.** The `findings` section must contain a "Wiring evidence" table mapping each interactive element to the API endpoint it calls. Any UNWIRED element or remaining hardcoded mock data = CRITICAL — re-dispatch the agent.

Step 3.3g (qa-verification) verifies the same surface independently from the reviewer's side.

### Step 3.2.6: Dead UI Scan (All UI-facing specs)

**BLOCKING GATE.** Scan implementation files for interactive elements with no handler (buttons without `onPress`/`onClick`, empty `() => {}` handlers, `Alert('TODO')`, navigation that doesn't navigate, forms without `onSubmit`). This catches mockup-to-implementation handoff failures.

The frontend-engineer agent SHOULD have caught these during REFACTOR; this is the orchestrator's belt-and-suspenders check. Cross-reference the spec's `## Interaction Map` — every row needs a functional handler in the implementation.

Log a `DEAD UI SCAN: ... Verdict: PASS|FAIL` entry via `bd comments add` with element counts. Any dead element = CRITICAL. Decorative elements (icons, labels, dividers) are fine.

**Skip when:** `@layer(api|cli|infra)`.

### Step 3.3: Verify

**Full verification, identical for every non-trivial spec. It never scales below the `@trivial` floor: `@trivial` is the ONLY knob that reduces verification, and it is set at decomposition (/design Step 2.5) — never added during build.** The "Skip when: Spec is `@trivial`" lines on individual reviewer steps below are that floor, not discretion. If a spec feels trivial but isn't tagged, build it with full verification (or pause for /respec to re-tag it).

The verify pass runs Steps 3.3a–3.3i (registry §2): 3.3a test-suite, 3.3b test-effectiveness, 3.3c code-review, 3.3d security-review, 3.3e devops-review, 3.3f data-review (when `@touches-data`), 3.3g qa-verification, 3.3h sre-intent-audit, 3.3i fix-cycle. Handoff FILES for all of 3.3d–3.3h use the flat id `3.3` (`step-3.3-<slug>-<role>.html`) — the role disambiguates; the letters are prose section numbers only.

Dispatch 3.3a–3.3c in parallel:

**Step 3.3a: Test Suite**
```
Agent tool (subagent_type: hyperpowers:test-runner):
"Run the full test suite. Report only failures and summary."
```
If tests fail: log as bd comments add (category: `test-failure`), fix before proceeding.

**Step 3.3b: Test Effectiveness**
```
Agent tool (subagent_type: hyperpowers:test-effectiveness-analyst):
"Analyze test files changed or created for this spec.
Check for: tautological tests, coverage gaming, weak assertions,
missing corner cases. Report CRITICAL / IMPORTANT / MINOR."
```
If CRITICAL: log as bd comments add (category: `test-quality`), fix before proceeding.

**Test Quality Gate:** 3+ tautological tests = CRITICAL. Weak assertions (check existence not correctness) = IMPORTANT.

**Manual spot-check:** Open each test file, spot-check 3+ tests: "What specific bug would this catch?" Log via `bd comments add`.

**Step 3.3c: Code Review + Spec Coverage**
```
Agent tool (subagent_type: hyperpowers:code-reviewer):
"Review ALL files changed for this spec.
1. Read specs/<feature-slug>.md — verify EVERY scenario has code and tests
2. Pattern consistency with existing code
3. Edge case coverage (cross-reference spec scenarios)
4. Integration correctness (check specs/system.md conventions if exists)
5. Test quality — each spec scenario has at least one test
An unimplemented spec scenario is CRITICAL (spec-coverage)."
```

**Integration Point Checklist** (for cross-module specs):
```
Additionally check:
- Events/signals emitted at correct lifecycle point
- Buffers/queues have sufficient capacity
- Consumer handles all producer variants
- State transitions complete
```

**Dead Code Scan:**
- Config/options parsed but never acted on = CRITICAL
- Stubs exposed as functional = CRITICAL
- Variables assigned but unused = IMPORTANT

#### Step 3.3d: Security Review

**Dispatch the security-architect role agent** after code-review (3.3c). It threat-models the diff, walks trust boundaries, and flags injection / SSRF / IDOR / CSRF / XSS / secrets / authz / authn issues. Dispatch 3.3d, 3.3e, and 3.3f (when applicable) in parallel — one message, multiple Agent calls.

```
Agent tool (subagent_type: security-architect, run_in_background: false):
"You are running Step 3.3d (security review) for specs/<slug>.md. Read the application-architect
handoff (step-2.5) for data-flow context, the spec, and the implementation diff. Apply the OWASP-style
checklist in your prompt. Produce your handoff at:
  specs/handoffs/step-3.3-<slug>-security-architect.html
Each CRITICAL or IMPORTANT finding must cite a file:line in the implementation. Do not invent threats."
```

When the agent returns: if it produced an `<aside data-severity="critical" data-blocks-next-step="true">`, do NOT proceed past the reviewer pass. Fix the CRITICAL findings first (Step 3.3i), then re-dispatch.

**Skip when:** Spec is `@trivial` (no functional change to security surface).

#### Step 3.3e: DevOps / Operability Review

**Dispatch the devops-architect role agent.** Reviews the diff for deployment delta (new env vars, secrets, infra), migration safety, feature-flag posture, observability (logs/metrics/traces), resource budgets, rate-limits/timeouts, health checks, rollback story, and cost.

```
Agent tool (subagent_type: devops-architect, run_in_background: false):
"You are running Step 3.3e (operability review) for specs/<slug>.md. Read the application-architect
handoff, the implementation diff, and any infra files. Walk the operability checklist in your prompt.
Cite file:line for every finding. Produce your handoff at:
  specs/handoffs/step-3.3-<slug>-devops-architect.html"
```

**Skip when:** Spec is `@trivial`.

#### Step 3.3f: Data Review (when `@touches-data`)

**Dispatch the data-architect role agent** when the spec is tagged `@touches-data` (same trigger as the Step 3.1 data investigation). Reviews the implementation diff for schema-change safety, migration locking risk, index posture, query shapes (N+1, SELECT *), transactions, concurrent-write hazards, soft-delete consistency, PII handling.

```
Agent tool (subagent_type: data-architect, run_in_background: false):
"You are running Step 3.3f (data review) for specs/<slug>.md. Read the backend-engineer
handoff (the diff), the schema files, and the recent migrations. Produce your handoff at:
  specs/handoffs/step-3.3-<slug>-data-architect.html
Include EXPLAIN output for new queries; cite file:line for every concern."
```

#### Step 3.3g: QA-Verification (authoritative per-spec)

**Dispatch the qa-engineer role agent.** This step CONSOLIDATES the checks that used to be orchestrator-inline or separate sections — visual fidelity, layer coverage, scenario coverage, API integration / connectivity checking, and the impeccable quality gates — under a single dispatch. The QA agent runs the actual test framework against the actual running app — spins up the dev server, drives a real browser, screenshots both implementation and mockup, intercepts network traffic to verify every Interaction Map row fires its declared API call.

```
Agent tool (subagent_type: qa-engineer, run_in_background: false):
"You are running Step 3.3g (per-spec QA) for specs/<slug>.md. Read the engineers' handoffs, the
spec, the mockup at specs/mockups/<slug>/, and DESIGN.md. Author an independent test plan with four
matrices (scenario coverage, connectivity, visual fidelity, exploratory). Detect the test framework,
spin up the dev server, run the framework against the running app. For each visual matrix row,
structurally compare computed styles between implementation and mockup; if the spec is tagged
@visual-pixel-diff, also run pixel-diff via toHaveScreenshot. For each connectivity matrix row,
intercept the network and verify the expected request fires. Author test files in tests/e2e/ or the
framework's convention. Produce handoff at:
  specs/handoffs/step-3.3-<slug>-qa-engineer.html
Any failing scenario, missing connectivity, or visual mismatch is CRITICAL — surface as a blocking <aside>."
```

When the agent returns, verify the handoff's acceptance-criteria pass and that the test files referenced exist on disk. The `require-ui-tests.sh` hook independently checks that test files reference the spec slug.

**Visual fidelity comparison method:**
- **Structural diff (mandatory)** — for every UI surface in the spec, QA walks matched selectors in both implementation and mockup, comparing computed styles (typography axes, color, spacing, layout, state coverage). This is the binding check.
- **Pixel diff (opt-in)** — for specs tagged `@visual-pixel-diff`, QA additionally runs `toHaveScreenshot()` against a captured mockup screenshot with `maxDiffPixelRatio: 0.05`. Use this for brand surfaces or exact-recreation specs; pixel-diff is flaky on subpixel rendering otherwise.

**Frontend-engineer's REFACTOR self-check is preliminary; QA's check is authoritative.** Don't ship a frontend handoff with known visual deviations and rely on QA to catch them — fix at REFACTOR first.

**Skip when:** Spec is `@trivial`. UI checks within QA auto-skip for `@layer(api|cli|infra)` specs without a `## UI Design` section.

(The `hooks/require-ui-tests.sh` hook continues to enforce that a test file referencing the spec slug exists before `@status(verified)`. QA-engineer authors those tests.)

#### Step 3.3h: SRE-Intent-Audit

**Runs for every spec, regardless of layer.** The mechanical reviewers above check that every scenario has code and tests, dead code, integration points, and visual fidelity. This step checks something different: does the implementation actually deliver the spec's **intent**, and does it hold up under **SRE-grade rigor** (failure modes, observability, performance, operational readiness) in service of that intent?

1. **Identify context to load:**
   - Current spec file: `specs/<feature-slug>.md`
   - Parent epic (the epic ID for this spec's beads task — e.g., `bd show <spec-task-id>` to find it)
   - Every spec listed in this spec's `@depends-on` directive

2. **Dispatch the auditor:**

   ```
   Agent tool (subagent_type: spec-sre-auditor):
   "Audit the implementation of specs/<feature-slug>.md.

   Spec to audit: specs/<feature-slug>.md
   Parent epic: <epic-id>
   Upstream specs (@depends-on): [<paths>]

   Files changed for this spec:
   <list from `git diff --name-only` scoped to this spec's commits>

   Read the spec's Why/Outcome and scenarios first to internalize intent,
   then read the parent epic and any upstream specs. Audit the implementation
   against that intent with SRE rigor. Return findings in the exact format
   from your system prompt, then a single Verdict line. Produce your handoff at:
     specs/handoffs/step-3.3-<slug>-spec-sre-auditor.html"
   ```

3. **Route findings by severity:**

   - **CRITICAL** → log via `bd comments add` with category `sre-intent-audit` and severity CRITICAL. Feed into the existing fix-verify loop in "Verification Failure Handling" below (max 3 cycles). Spec cannot reach `@status(verified)` until cleared.
   - **IMPORTANT** → create a follow-up beads task per finding (`bd create --type=task --priority=2` with location, finding, spec-tie, and recommendation in the description; `bd dep add <new-id> <this-spec-task-id>`). Spec can proceed to Step 3.4 once CRITICAL/SPEC-DRIFT findings are clear.
   - **SUGGESTION** → log via `bd comments add` only. No task created.
   - **SPEC-DRIFT** → **STOP.** Do not flip status to verified. Surface the finding to the user and recommend running `/respec` against the affected spec(s). The auditor's `Recommendation` line becomes input to `/respec`. Do not enter the fix-verify loop — code fixes cannot resolve a spec-drift finding.

4. **Log the audit** via `bd comments add` on the epic: `SRE + INTENT AUDIT: specs/<slug>.md`, intent source, per-severity finding counts (with locations / follow-up task ids / affected specs), and the `Verdict:` line.

**Verdict routing:** `FAIL (critical)` → fix-verify loop, max 3 cycles · `FAIL (spec-drift)` → halt, surface to user, recommend `/respec` (never the fix loop) · `PASS` → proceed to Step 3.4.

**Do not skip this step.** It runs for every spec — backend, API, UI, CLI, full-stack — because intent fidelity applies to all layers.

#### Verification Failure Handling

Log every failure:
```bash
bd comments add [epic-id] "VERIFICATION FAILURE: [category] - [description]

Source: [which step caught it]
Category: [test-failure | test-quality | code-review | spec-coverage | criteria-gap | integration | sre-intent-audit]
Severity: [CRITICAL | IMPORTANT | MINOR]
Action: [returning to fix | fixing inline | deferring]"
```

Maximum 3 fix-verify cycles per spec before escalating to user.

#### Step 3.3i: Fix-Cycle (run after any reviewer returns CRITICAL/IMPORTANT findings)

**Reviewers (QA, security-architect, devops-architect, data-architect, code-reviewer, sre-auditor) flag — implementers fix — finders re-verify.** This is the explicit orchestration of that loop. Each finding in a reviewer handoff carries `data-route-to="<role>"` per `docs/role-agent-handoff-schema.md`; this step reads those attributes and dispatches the right implementer.

**Process per cycle:**

1. **Aggregate findings.** Across every reviewer handoff produced in Steps 3.3a–3.3h, collect every `<aside data-severity="critical|important">` and every findings-table row with `data-route-to`. Don't drop SUGGESTION findings — they go into open-questions, not the fix queue.
2. **Group by `data-route-to`.** Build a per-implementer queue:
   ```
   backend-engineer:    [finding-1, finding-3, finding-7]
   frontend-engineer:   [finding-2, finding-5]
   uiux-designer:       [finding-4]
   ```
3. **Dispatch implementers in parallel.** Independent implementers can fix in parallel — include multiple `Agent` tool calls in a SINGLE message (per the parallel-dispatch pattern in this skill's header). Each dispatch includes that implementer's findings list and the source-handoff paths:

   ```
   Agent tool (subagent_type: backend-engineer, run_in_background: false):
   "You are running Step 3.3i fix-cycle N for specs/<slug>.md. Findings routed to you:
   - finding-1 from specs/handoffs/step-3.3-<slug>-security-architect.html (CRITICAL: missing CSRF on PATCH /api/preferences/theme:24)
   - finding-3 from specs/handoffs/step-3.3-<slug>-data-architect.html (IMPORTANT: schema/migration drift)
   ...
   Per your fix-mode protocol: fix narrowly, add regression tests, re-run affected tests. Produce
   follow-up handoff at specs/handoffs/step-3.2-<slug>-backend-engineer-fix-cycle-<N>.html."
   ```

4. **Re-dispatch the original finders.** When all implementers have returned, re-dispatch each reviewer whose findings were addressed, with the prior cycle's handoff path so they can re-verify only the previously-flagged findings (not the whole spec). Re-dispatched reviewers produce new handoffs at `specs/handoffs/step-3.3-<slug>-<role>-fix-cycle-<N>.html`.

5. **Re-aggregate.** Read the new reviewer handoffs. If any CRITICAL or IMPORTANT findings remain (new or unaddressed), go to cycle N+1.

6. **Cap at 3 cycles.** After cycle 3, if CRITICAL findings still exist, do NOT write `@status(verified)`. Pause and escalate to the user via AskUserQuestion with the remaining findings + recommended disposition (override / defer to follow-up beads task / `/respec` the spec). **--auto:** halt with a written summary instead of AskUserQuestion — do not proceed past the cap autonomously.

**Routing exceptions (escalations halt with a written summary under `--auto`):**
- `data-route-to="product-owner"` — does NOT enter the fix-cycle. Escalate to user via AskUserQuestion. Likely needs `/respec` or scope decision.
- `data-route-to="application-architect"` — does NOT enter the fix-cycle. Pause and run a focused `/respec` slice (blast radius + propagation) before resuming /build on the affected specs.

**Logging:** after each cycle, `bd comments add` on the epic: `FIX CYCLE <N> for specs/<slug>.md` with findings addressed (counts by severity), per-implementer routing + handoff paths, per-reviewer verdicts after fix, and the next action (proceed to 3.4 | cycle N+1 | escalate — cap reached).

The fix-cycle is the single most important orchestration step. Without it, reviewers' findings become advisory text nobody acts on; with it, every CRITICAL has a deterministic path to resolution.

**Backstop hook: `require-fix-cycle-handoff.sh`** (PreToolUse on Edit/Write of `@status(verified)`). For each cycle number N detected under `specs/handoffs/`, both sides must exist on disk: at least one `step-3.2-<slug>-<role>-fix-cycle-<N>.html` (implementer) AND at least one `step-3.3-<slug>-<role>-fix-cycle-<N>.html` (reviewer re-verify). Asymmetric cycles block. This catches the recurring failure mode where an implementer agent does the fix work but returns without writing its handoff (see `docs/incidents.md#squashbuckler-fix-cycles-2026-05-26`) — by the time you try to verify the spec, the asymmetry surfaces and you can re-dispatch with stronger language. Override per cycle via `@fix-cycle-skip(<N>: <reason>)`.

**Post-dispatch sanity check** (after each agent returns in a fix-cycle): immediately confirm the expected handoff file exists on disk (`ls specs/handoffs/step-3.2-<slug>-<role>-fix-cycle-${N}.html`). If missing, re-dispatch the same agent with: *"Your prior dispatch returned without writing `<expected-path>`. That handoff IS the deliverable, not the verbal confirmation. Per the exit protocol in docs/agent-protocol.md, write it now."* `docs/agent-protocol.md` §1 names the handoff write as a TERMINAL step for every agent.

**Do not sleep-poll background work.** If a test-runner or fix-mode dispatch is long-running, use `run_in_background: true` and let the harness notify on completion, or `Monitor` to stream events. `sleep 60 && tail X` either wastes time or misses the result. Recurring anti-pattern; the Bash tool description forbids it.

### Step 3.4: User Sign-Off Checkpoint

**Unless `--auto` flag was passed**, pause and present a summary to the user for final sign-off before marking the spec as verified.

Use AskUserQuestion (this is orchestrator-inline — never dispatched):

```
"Spec `specs/<feature-slug>.md` implementation complete:
Scenarios implemented [N/N] · Tests [N passing, 0 failing] · Verification: all agents PASS
[If UI-facing:] Visual fidelity: PASS — matches mockup
Key implementation decisions: [decision — e.g., chose X pattern over Y per codebase convention]
Files changed: [file — what changed]
Does this match your expectations? (yes / no / concerns)"
```

**If user says no or raises concerns:** address them, re-run verification if changes were made, present the updated summary and ask again — maximum 3 sign-off cycles before escalating with full context.

**If user says yes:** Proceed to Step 3.5.

**If `--auto` flag was passed:** Skip this step entirely and proceed directly to Step 3.5.

### Step 3.5: Complete This Spec

After verification passes (including Step 3.3h sre-intent-audit with `Verdict: PASS`) and user sign-off (unless `--auto`):

1. Update spec status: `@status(implemented)` → `@status(verified)`
2. Close the beads task for this spec
3. Log verification result:
   ```bash
   bd comments add [epic-id] "VERIFICATION: specs/<feature-slug>.md PASSED — [N] scenarios implemented and tested"
   ```

### Step 3.6: Auto-Iterate

Move to the next spec in build order. Return to Step 3.1.

If the next spec has unmet `@depends-on` prerequisites, skip it and try the next unblocked spec.

Continue until all specs are processed.

## Phase 4: Close Epic

After all specs are `@status(verified)`:

### Step 4.1: Epic-level QA — Cross-spec Critical User Journeys

**Dispatch the qa-engineer role agent (second dispatch — distinct from Step 3.3g).** Step 3.3g covered per-spec verification (visual fidelity, connectivity, scenario coverage). Step 4.1 covers the journeys that SPAN multiple specs — the integration tests per-spec QA can't see because they exist only when several features are wired together (e.g. "register → log in → create list → add task → mark done → view history").

The agent collects every `## Critical User Journeys` row across the epic's specs, authors one e2e test per unique journey, runs the suite against the running app, and reports cross-spec coverage. Same framework detection logic as Step 3.3g.

**The assembled-app rule.** Every e2e test MUST start from the application's **real entry point** (the integration spec's app shell / entry route) and reach each feature through **real navigation** — clicking the actual nav, opening the actual route. Tests that deep-link straight to a feature page or mount a feature component in isolation do NOT count: they re-verify the demo card, not the assembled product (see `docs/incidents.md#squashbuckler-2026-05-31`). The QA agent must also assert **Mount Map reachability**: for the epic's `@integration` spec, every row in its `## Mount Map` is reachable from the entry point. Any Mount Map row that cannot be reached = CRITICAL orphan.

```
Agent tool (subagent_type: qa-engineer, run_in_background: false):
"You are running Step 4.1 (epic-level e2e for cross-spec CUJs) for this epic. Read every spec's
## Critical User Journeys table and build a master list of UNIQUE journeys spanning multiple specs.
Read the per-spec QA handoffs at specs/handoffs/step-3.3-*-qa-engineer.html — those cover per-spec
behavior; you cover the cross-spec wire-together. EVERY e2e test must launch the real app entry point
(the @integration spec's shell) and navigate to features the way a user would — no deep-linking to
feature pages, no isolated component mounts. Also read the @integration spec's ## Mount Map and add a
'reachability' test asserting every mapped feature is reachable from the entry point via real nav.
Author one e2e file per journey at tests/e2e/cuj-<journey-slug>.spec.ts plus
tests/e2e/mount-map-reachability.spec.ts. Spin up the dev server and run the suite. Produce handoff at:
  specs/handoffs/step-4.1-<epic-id>-qa-engineer.html
Any failing CUJ or unreachable Mount Map row is CRITICAL — surface as a blocking <aside>."
```

When the agent returns, verify the handoff's `acceptance-criteria` confirm every CUJ has ≥1 e2e test, every `## Mount Map` row is reachable from the app entry point, and all pass.

Log a `E2E PLAYWRIGHT TESTS: CUJ Coverage ... Verdict: PASS|FAIL` entry via `bd comments add` on the epic with per-journey verdicts copied from the qa-engineer handoff.

Any failing CUJ is **CRITICAL** — the journey represents what real users do, and a failing CUJ means the app is broken for the user even if every unit test passes. Re-dispatch qa-engineer after fixes.

**Skip when:** No spec in the epic is tagged `@layer(ui)` or `@layer(full-stack)`. Deterministic check: `grep -lE '@layer\((ui|full-stack)\)' specs/*.md` returns no specs in this epic. Single-spec UI/full-stack epics still run e2e — "single-spec" alone is not sufficient to skip.

### Step 4.2: Final Verification + Release Coordination

**REQUIRED SUB-SKILL:** Invoke `hyperpowers:verification-before-completion` via the Skill tool to gate epic closure on fresh verification evidence.

**Dispatch the release-coordinator role agent.** It performs the cross-spec coherence check, verifies every spec reached `@status(verified)` with full handoff chains, aggregates devops findings, confirms CUJ coverage, runs the **orphan-feature check**, and authors the explicit rollback plan that the epic needs before `bd close`.

**Orphan-feature check (blocking).** When the epic has ≥2 `@layer(ui|full-stack)` specs, exactly one must be tagged `@integration` with a `## Mount Map`, and every other UI feature must appear in that Mount Map (or carry `@mount-skip(...)`). A UI feature `@status(verified)` but absent from the Mount Map is an orphan — the epic is NOT ready to close. This is the cross-spec backstop to the per-spec `require-feature-mounted.sh` hook: the hook gates each spec at `@status(verified)`; the release-coordinator confirms the assembled set has no holes.

```
Agent tool (subagent_type: release-coordinator, run_in_background: false):
"You are running Step 4.2 (final verification) for epic <epic-id>. Verify all specs in the epic reached
@status(verified) with full handoff chains. Aggregate devops-architect findings across specs. Confirm
the qa-engineer e2e CUJ coverage is complete and passing, including the Mount Map reachability test.
Run the orphan-feature check: if ≥2 UI/full-stack specs, confirm exactly one @integration spec exists,
its ## Mount Map covers every UI feature, and the running app reaches each (per the Step 4.1 handoff);
any orphan is a BLOCKED. Author a numbered rollback plan a 3 AM oncall engineer could execute. Produce
handoff at:
  specs/handoffs/step-4.2-<epic-id>-release-coordinator.html
End with one of three verdicts: READY-TO-CLOSE, READY-WITH-CAVEATS, or BLOCKED."
```

The `require-release-handoff.sh` hook blocks `bd close <epic-id>` unless the handoff exists and the verdict is READY-TO-CLOSE or READY-WITH-CAVEATS. BLOCKED verdicts must be resolved first (or override via `bd comments add <epic-id> "RELEASE-SKIP: <reason>"`).

### Step 4.3: Close Tests Gate Task
`bd show [tests-task-id]` to verify all criteria met, then `bd close [tests-task-id]`.

### Step 4.4: Log Final Verification Comment
```bash
bd comments add [epic-id] "VERIFICATION Phase 4: PASSED — all specs verified
Specs verified: [list] · Total scenarios: [N] · All unit tests passing.
Playwright e2e: [N] CUJs tested, all passing. (or: N/A — no UI specs)"
```

### Step 4.5: Close Epic
`bd close [epic-id]`

### Step 4.6: Update README (when applicable)
If the epic added/changed features, API, UI, dependencies, or usage patterns — update README.

### Step 4.7: Update Memory
Save anything learned that would be useful in future sessions.

### Present Integration Options

**REQUIRED SUB-SKILL:** Invoke `hyperpowers:finishing-a-development-branch` via the Skill tool to clean up task docs and present integration options.

</the_process>

<examples>

<example>
<scenario>Simple spec — typo fix (1 scenario)</scenario>

<why_it_fails>
Without /build's discipline, "it's just a typo" reads as permission to skip TDD, code review, and the spec-coverage check. The agent fixes the misspelling, runs no tests, and marks the spec verified. Then a `grep` misses one occurrence in a comment, or the test suite has nothing asserting the absence of the old spelling, and the typo regresses in the next change. Verification never scales below the `@trivial` floor: if /design tagged the spec `@trivial` at decomposition, the tagged reviewer steps skip — that is the whole reduction. Nothing else scales down, and "this feels trivial" during build is never grounds to add the tag or skip a gate.
</why_it_fails>

<correction>
**Phase 1:** Entry validation — `specs/fix-readme-typo.md` exists with `@status(approved)` and `@trivial` (set at decomposition). Beads task exists.

**Phase 2:** No dependencies.

**Phase 3:**
- Investigate: Read spec, grep for typo instances across project
- TDD RED: Write test asserting no instances of 'recieve' remain
- TDD GREEN: Fix all instances
- TDD REFACTOR: (nothing to refactor)
- Verify: Run tests, code review, spec coverage (1/1 scenario covered). The `@trivial` tag skips the 3.3d/3.3e/3.3g reviewer dispatches — the floor set at decomposition, not a build-time judgment call.
- Update: `@status(verified)`, close beads task

**Phase 4:** Close Tests task, close epic, offer commit.
</correction>
</example>

<example>
<scenario>Standard spec — new API endpoint (4+ scenarios)</scenario>

<why_it_fails>
Without spec-driven TDD, the agent writes the endpoint first and bolts tests on after. The tests mirror the implementation's branches and pass because they were written to match what the code does — not what the spec says. A "radius=0" scenario in the spec goes unnoticed because the implementation never crossed that path, and the endpoint ships missing an edge case the spec explicitly required. TDD from the scenario list guarantees the test asserts the spec, not the code.
</why_it_fails>

<correction>
**Phases 1-2:** `specs/nearby-breweries-endpoint.md` `@status(approved)`, no dependencies. **Phase 3:** investigate (codebase-investigator, log findings) → RED for all 4+ scenarios → GREEN one scenario at a time → REFACTOR; edge case radius=0 discovered → added to spec with a failing test FIRST → implemented. Continuous verifier per task; full verify pass (5/5 scenarios); sign-off; `@status(verified)`. **Phase 4:** e2e N/A (single-spec); close Tests task + epic.
</correction>
</example>

<example>
<scenario>Complex — multi-spec with dependencies (OAuth)</scenario>

<why_it_fails>
Without dependency ordering, the agent picks whichever spec looks easier and starts there — often authentication, because registration feels like "boring CRUD." But authentication's tests need a registered user fixture, and the registration contract is still in flux, so the auth tests get written against a guessed shape. Then registration changes and auth tests pass against the wrong fixture, masking real breakage. CUJ-level e2e tests get skipped because "the unit tests cover it" — and the New-User-Onboarding journey never actually runs end-to-end. Dependency order isn't bureaucracy; it's the only way later specs can trust the contracts they depend on.
</why_it_fails>

<correction>
**Phase 1:** Entry validation — 3 specs exist: system.md, user-registration.md, user-authentication.md. All `@status(approved)`. Beads tasks exist.

**Phase 2:** Build order:
1. user-registration.md (no dependencies)
2. user-authentication.md (depends on: user-registration)

**Phase 3 — Spec 1 (user-registration):** investigate (spec + system.md, codebase-investigator + internet-researcher) → TDD → continuous verifier → full verify pass (connectivity: all form submissions wired) → sign-off → `@status(verified)`, close task.

**Phase 3 — Spec 2 (user-authentication):** prerequisite check passes (registration verified) → investigate with the now-real User model and registration API → TDD (Scenario Outline rate limiting = 3 parameterized tests) → full verify pass (login/logout wired) → sign-off → `@status(verified)`, close task.

**Phase 4:** Playwright e2e — CUJs: New user onboarding (PASS), Returning user session (PASS). Close Tests task, close epic, memory update, offer PR.
</correction>
</example>

</examples>

<incident_logging>
## Workflow Incident Logging

When the user corrects your approach during /build, the `detect-correction.sh` hook will fire and prompt you to offer incident logging. Follow its instructions:

1. **Address the correction first** — fix whatever you did wrong
2. **Ask to log** — use AskUserQuestion: "Should I log this as a workflow incident for the next retro?"
3. **If confirmed**, log a structured comment on the active epic:

```bash
bd comments add [epic-id] "WORKFLOW INCIDENT: [short description]

Category: [skill-gap | missing-rule | wrong-default | edge-case | process-violation]
Skill: [design | build | retrospective | hook-name | none]
What happened: [what you did wrong]
What should have happened: [correct behavior]
User correction: [what the user said]
Proposed fix: [optional — if the fix is obvious, note it]"
```

4. **If dismissed**, continue normally — not every correction is a workflow incident

Categories: `skill-gap` (no guidance existed) | `missing-rule` (a rule should exist) | `wrong-default` (existing behavior is wrong) | `edge-case` (rules don't cover this) | `process-violation` (you broke an existing rule).

**No active epic:** create or reuse a dedicated `workflow-incidents` issue: `bd create --title="Workflow Incidents" --type=task --description="Collects workflow incidents when no epic is active. Retrospective reads these."`
</incident_logging>

<critical_rules>
## Rules That Have No Exceptions

1. **Specs required** -> No specs = no build. Run /design first.
2. **Always investigate before writing** -> Read target files minimum. Dispatch agents. Log findings.
3. **Always spec-driven TDD** -> Tests generated FROM spec scenarios before implementation. RED → GREEN → REFACTOR. Every spec. No exceptions.
4. **Verification never scales below the @trivial floor** -> `@trivial` is the ONLY knob that reduces verification, and it is set at decomposition — never during build. Untagged specs get identical full verification regardless of perceived simplicity.
5. **Tests gate task is sacred** -> NEVER close during implementation. Only close after ALL verification passes.
6. **Log every verification failure** -> Structured `bd comments add` entry with category, severity, source, action.
7. **Log a VERIFICATION comment before closing** -> Even when all passes: "VERIFICATION: PASSED — no issues found."
8. **Dependency order is mandatory** -> Verify prerequisites are `@status(verified)` before starting dependents.
9. **Parallel-risk is a warning, not a blocker** -> `@parallel-risk` specs have no `@depends-on` relationship. They are not sequenced relative to each other. /build warns about file overlap but does not add sequencing.
10. **Pause on fundamental spec drift** -> Wrong approach, missing feature, incorrect data model, contract changes = STOP, direct to /respec (modify existing spec) or /design (new specs needed). Do NOT silently rewrite specs.
11. **Always use subagents** -> Investigation, code review, test running, test analysis = subagents. Never do manually what an agent can do.
12. **Continuous verifier for multi-scenario specs** -> Spawn when first task starts. Reviews 5 dimensions per task. CRITICAL blocks closure.
13. **New spec scenarios get failing tests FIRST** -> If you add a scenario during implementation, write its failing test before implementing it.
14. **Never update status while verification is in flight** -> Do NOT update `@status` or close beads tasks while verification agents are still running. Verification results MUST be received and passed BEFORE any status change or closure. "While waiting for verification" is never a valid reason to update status — that is the one thing that depends on the results.
15. **UI-facing specs: start from mockup, not from scratch** -> If `specs/mockups/<feature-slug>/` or `.html` exists, the mockup component IS the starting point for implementation. Copy it, wire in real data. Do not implement UI from scratch and ignore the mockup. Tests passing with ugly/unstyled UI is a CRITICAL failure.
16. **Visual fidelity is part of verification** -> For UI-facing specs, the visual fidelity check (Step 3.3g) is mandatory. Typography, color, layout, and CSS tokens must match the `## UI Design` section. "It works" is not enough — it must also look right.
17. **Browser iteration during TDD for UI specs** -> After each scenario group passes (GREEN), view the implementation in a browser across viewports (desktop, tablet, mobile). Compare against the mockup. Fix visual issues immediately — do not batch them for "later."
18. **Impeccable quality gates for UI specs run inside Step 3.3g** -> The qa-engineer dispatch owns the critique / anti-pattern / polish checks (design review, deterministic scanner, final quality pass), as the uiux-designer dispatch owned them at design time. The orchestrator does NOT invoke `/impeccable` itself during /build — it verifies the qa-engineer handoff documents these checks and their verdicts. Enhancement passes when QA finds blandness route back to frontend-engineer via the fix-cycle.
19. **Read PRODUCT.md + DESIGN.md during UI implementation** -> The design system tokens and brand context are the source of truth for visual decisions. Read them during investigation (Step 3.1) and reference them during visual verification (Step 3.3g). Do not implement UI without loading the design system.
20. **API integration check for UI-facing specs** -> Every interactive UI element (button, form, navigation) that implies backend communication must be wired to a real API call — not a TODO, stub, or local-state-only dispatch. The connectivity matrix in Step 3.3g is mandatory for UI specs with API endpoints.
21. **Playwright e2e tests before epic close** -> For multi-spec UI epics, Playwright e2e tests covering every CUJ from the specs must pass before Phase 4 can close the epic. This is the cross-spec integration gate. Unit tests verify features in isolation; e2e tests verify the assembled application. Mobile targets use Detox, Maestro, or Appium; when no mobile e2e framework is available, the UI layer still requires component tests plus manual simulator verification — "can't e2e test" never excuses skipping the UI layer.
22. **Layer awareness for full-stack specs** -> When a spec describes both API endpoints AND UI screens, BOTH layers must be implemented and tested before `@status(verified)`. Building only the API and marking verified is a process violation. Layer detection is mandatory in Step 3.1; layer-aware coverage is verified in Step 3.3g.
23. **API wiring checkpoint before verification** -> For full-stack specs, Step 3.2.5 is a BLOCKING gate. Every UI component must be wired to the real data layer (no hardcoded/mock data remaining) before verification (Step 3.3) can begin. This is "do the wiring" — Step 3.3g is "verify the wiring." Both required.
24. **Follow the project's API client pattern** -> Components must use the API client pattern defined in the system spec or arch.md (centralized service layer, Supabase client, etc.). No ad-hoc fetch calls that bypass the established architecture.
25. **UI tests must assert behavior, not just rendering** -> A test that only checks "button exists" is not a UI test. Every interactive element (button, form, toggle, nav) needs a behavior assertion: press triggers handler, submit dispatches data, toggle updates state. Render-only tests are insufficient for GREEN.
26. **Dead UI scan before verification** -> Step 3.2.6 scans for buttons with no handlers, forms with no submission, empty onPress callbacks, and console.log placeholders. Any dead interactive element is CRITICAL. Mockup code carried into implementation without functionality is a broken feature.
27. **A UI feature is not verified until it is mounted in the product** -> In an epic with ≥2 user-facing specs, `@status(verified)` on a `@layer(ui|full-stack)` spec requires the feature to be in the `@integration` spec's `## Mount Map` and reachable from the app entry — not just passing its own tests in isolation. Wiring the feature into the shell is part of implementation. `require-feature-mounted.sh` blocks orphans; the Step 4.1 e2e drives the real entry point; the release-coordinator runs the orphan check at close (see `docs/incidents.md#squashbuckler-2026-05-31` — a mockup is a build step, not a deliverable).

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "This spec feels trivial, verification is overkill" -> `@trivial` is the only knob and /design already turned it (or didn't) at decomposition. Never add the tag or skip a gate during build (rule 4).
- "I'll update the status while waiting for verification" -> Status updates DEPEND on verification results (rule 14). Wait for agents to return, confirm they passed, THEN update.
- "The spec is fundamentally wrong but I can work around it" -> Working around a bad spec produces bad code. STOP, direct to /respec (rule 10).
- "This dependency isn't verified yet but I can start anyway" -> Build on verified foundations only (rule 8). Later specs must be able to trust the contracts they depend on.
- "Tests pass so the component is done" -> Behavior AND appearance AND wiring: visual fidelity (rule 16), dead-UI scan (rule 26), and connectivity (rule 20) must also pass for UI-facing specs.
- "The API tests pass so the spec is implemented" -> If the spec describes UI scenarios, API tests alone are NOT implementation (rule 22). The trainr project marked 15 full-stack specs verified with zero mobile code (see `docs/incidents.md#trainr`).
- "E2e tests are overkill — unit tests cover everything" -> Unit tests verify features in isolation; e2e verifies the assembled application (rule 21). FitConnect launched with every unit test green and no feature working end-to-end (see `docs/incidents.md#fitconnect`).
- "The feature's tests pass and it looks right, so it's verified" -> Not if the running app never mounts it (rule 27). Wire it into the `@integration` shell and Mount Map first (see `docs/incidents.md#squashbuckler-2026-05-31`).
- "The mockup is just a reference, I'll implement my own way" -> The mockup IS the starting point (rule 15). Copy it, wire in real data.
- "The component works with mock data for now" -> Mock data is for the RED/GREEN cycle only. Step 3.2.5 replaces ALL of it with real data-layer calls before verification (rule 23). External APIs are mocked at the network layer (MSW), never in the component.
</critical_rules>

<verification_checklist>
Before claiming /build is complete for a spec:

**Investigation (Step 3.1):**
- [ ] Spec, `## UI Design` section + mockup (UI specs), `@depends-on` specs, and specs/system.md (if exists) read before coding
- [ ] Layer detection completed and logged via `bd comments add` on epic; @parallel-risk overlaps flagged in the build-order announcement
- [ ] Investigation agents dispatched; `## Investigation Findings` written (≥2 file:line refs + Decision: line) and summarized on the epic
- [ ] Beads implementation task created with investigation context
- [ ] SRE refinement run (≥1 domain-specific edge case found)

**Implementation (Step 3.2):**
- [ ] Failing tests generated FROM spec scenarios for ALL detected layers, RED before GREEN; Scenario Outline rows parameterized; new scenarios got failing tests first
- [ ] UI specs: implementation started FROM mockup code; typography/color/layout/CSS tokens match `## UI Design`; browser iteration across viewports during TDD — or N/A (no UI)
- [ ] Spec updated as living doc; `@status(implemented)` written
- [ ] Continuous verifier spawned (multi-scenario specs); its CRITICAL findings fixed before task close
- [ ] Step 3.2.5 API wiring passed: no mock/hardcoded data, project API client pattern followed — or N/A (single-layer)
- [ ] Step 3.2.6 dead UI scan passed: every interactive element has a real handler — or N/A (no UI)

**Verification (Step 3.3):**
- [ ] 3.3a full suite passed; 3.3b effectiveness analyzed (3+ tautological tests = CRITICAL); manual spot-check logged
- [ ] 3.3c code review + per-layer spec coverage (every scenario implemented + tested); integration-point checklist (cross-module specs); dead-code scan
- [ ] 3.3d security / 3.3e devops / 3.3f data (when `@touches-data`) handoffs exist on disk — or skipped only via the `@trivial` floor
- [ ] 3.3g qa-verification handoff: scenario coverage, connectivity, visual fidelity + impeccable gates documented, test files exist on disk — or `@trivial` floor / no UI
- [ ] 3.3h sre-intent-audit returned `Verdict: PASS`
- [ ] 3.3i fix cycles symmetric (implementer `-fix-cycle-<N>` + reviewer re-verify handoffs); every failure logged via `bd comments add`
- [ ] Feature mounted: Mount Map row + reachable from app entry (`require-feature-mounted.sh`) — or N/A (<2 user-facing specs) / `@mount-skip(reason)`
- [ ] User sign-off obtained (Step 3.4) — or N/A (`--auto`)
- [ ] `@status(verified)` written; beads task closed

**Epic Close (Phase 4):**
- [ ] All specs `@status(verified)`
- [ ] Step 4.1 e2e: every CUJ has a passing test driving the REAL app entry; Mount Map reachability asserted — or N/A (no UI specs)
- [ ] Step 4.2 release-coordinator handoff: verdict READY-TO-CLOSE / READY-WITH-CAVEATS; orphan-feature check passed
- [ ] VERIFICATION comment logged on epic; Tests gate task closed; epic closed; README + memory updated (if applicable)

**Cannot check all boxes? Do not claim completion. Return to the incomplete step.**
</verification_checklist>

<integration>
**This skill calls:**

| Skill / Agent | When |
|---|---|
| hyperpowers:executing-plans | Multi-scenario specs (iterative task execution) |
| hyperpowers:test-driven-development | Simple specs (1-3 scenarios) |
| hyperpowers:verification-before-completion | Final epic verification |
| hyperpowers:finishing-a-development-branch | Integration options after epic close |
| codebase-investigator agent | Before implementing each spec |
| internet-researcher agent | Specs involving external APIs/libraries |
| code-reviewer agent | Continuous verifier + final verification |
| test-runner agent | Verification step |
| test-effectiveness-analyst agent | Verification step |
| qa-engineer agent (runs impeccable gates internally) | Per-spec verification incl. critique/anti-pattern/polish checks (Step 3.3g) + epic e2e (Step 4.1) |
| uiux-designer agent (runs impeccable gates internally) | Fix-cycle re-design when the mockup itself is wrong (`data-route-to="uiux-designer"`) |
| Playwright | E2E CUJ testing — cross-spec integration gate before epic close (Step 4.1) |

**This skill directs to:**

| Skill | When |
|---|---|
| /respec | Spec needs modification (wrong behavior, contract change, missing scenarios) |
| /design | No specs exist, or entirely new specs needed |

**This skill consumes (produced by /design or /respec):**
- `specs/*.md` files with `@status(approved)`
- Beads epic + Tests gate task only (per-spec implementation tasks are created BY /build in Step 3.1)
- Task docs with spec references (if brainstorming was used)

**This skill is triggered by:**
- User typing `/build`
- After /design or /respec completes
</integration>

<edge_cases>

- **No specs found:** "No specs found in `specs/`. Run `/design` first." STOP.
- **All specs verified:** "All specs are `@status(verified)`. Nothing to build." STOP.
- **Specs exist but no beads epic:** warn user, then `bd init` (if needed) and create the epic referencing specs + the Tests gate task. Implementation tasks come after investigation as usual.
- **Dependency cycle detected:** "Circular dependency: A depends on B depends on A. Run `/design` to fix the dependency graph." STOP.
- **Prerequisite not verified:** skip the blocked spec, try the next unblocked one. If all remaining are blocked: "All remaining specs are blocked on unverified prerequisites: [list]. Complete those first."
- **Spec is fundamentally wrong during implementation:** STOP; do NOT silently rewrite. "The spec `specs/<name>.md` needs fundamental changes: [what's wrong]. Run `/respec` (traces dependencies, propagates changes, regresses statuses) — or `/design` if entirely new specs are needed."
- **Verification fails repeatedly:** 1st failure — fix and re-verify; 2nd — review approach, check if the spec is wrong; 3rd — escalate to user with full context.
- **User asks to skip verification:** REFUSE. "Verification never scales below the `@trivial` floor, and that tag was set at decomposition — every untagged spec gets full verification."
- **Resuming after session break:** read `specs/`; `verified` = done, `implemented` = resume there, `approved` = next. Rebuild the dependency graph and continue.

</edge_cases>
