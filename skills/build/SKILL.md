---
name: build
description: Use after /design to implement approved specs - validates specs exist, builds dependency graph, auto-iterates through specs in @depends-on order with codebase analysis, spec-driven TDD, full verification, and spec status updates. Pauses for /respec if spec drift detected.
---

<skill_overview>
Build skill that consumes `@status(approved)` Gherkin specs produced by `/design` and implements them in dependency order. For each spec: investigates codebase, runs spec-driven TDD (RED/GREEN/REFACTOR), verifies with full suite + code review + spec coverage, and updates `@status(verified)`. Auto-iterates through all specs. Pauses and directs to `/respec` if a spec needs modification, or `/design` if the work needs entirely new specs.

**Role-agent orchestration (experimental branch).** This skill is the orchestrator. The deep procedural work is delegated to specialized role agents in `agents/`:
- `backend-engineer` / `frontend-engineer` — Step 3.2 TDD
- `security-architect` — Step 3.3c.1 threat-model review
- `qa-engineer` — Step 4.1 e2e CUJs
- (`spec-sre-auditor` already exists — Step 3.3g intent audit)

Each role agent produces an HTML handoff at `specs/handoffs/<step>-<slug>-<role>.html`. The `require-handoff-artifact.sh` hook blocks `@status(verified)` writes if any required handoff is missing or schema-invalid. See `docs/role-agent-handoff-schema.md`.

**Parallel-dispatch pattern.** To dispatch multiple role agents concurrently (e.g. `security-architect` + `devops-architect` + `data-architect` for Step 3.3's review pass), include MULTIPLE `Agent` tool calls in a SINGLE message. The harness fans them out in parallel. Splitting calls across separate messages serializes them and wall-clock grows linearly. After dispatching, verify parallelism by reading `data-produced-at` timestamps in the handoffs — they should overlap.

**Inline-synthesis fallback.** If the `Agent` tool is not available in your toolset (i.e. you are yourself a dispatched subagent and cannot dispatch further), fall back to inline synthesis: read each role's `agents/<role>.md` prompt, perform the role's work yourself, produce the same handoff file at the same path, and mark it with `<note data-synthesized="true">This handoff was synthesized inline because the Agent tool was unavailable.</note>` in the `findings` section. The audit trail stays schema-compliant; what's lost is diversity-of-perspective.

**Known limitation: TaskCreate reminders.** The Claude Code harness emits `system-reminder` messages suggesting `TaskCreate` periodically. They come from the harness itself, not our hooks, and cannot be silenced from the workflow side. Beads is the canonical task tracker (per the SessionStart hook); ignore the TaskCreate reminders.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: Entry validation — specs must exist with associated beads tasks. No specs = no build.
- **RIGID**: Spec-driven TDD — failing tests from scenarios BEFORE implementation. Every spec, no exceptions.
- **RIGID**: Verification never scales down — full suite + code review + spec coverage on every spec.
- **RIGID**: Pause on spec drift — fundamental spec changes require /respec (modify existing spec) or /design (new specs), not silent fixes.
- **FLEXIBLE**: Investigation depth scales with spec complexity.
- **FLEXIBLE**: Per-task review checkpoints via executing-plans for multi-scenario specs.
</rigidity_level>

<quick_reference>
## Usage

```
/build              # Interactive — pauses for user sign-off after each spec
/build --auto       # Autonomous — skips user sign-off checkpoints, runs end-to-end
```

## Build Flow

```
/build [--auto]
  -> Entry validation: scan specs/ for @status(approved|implemented), check beads for open tasks
  -> Parse @depends-on/@parallel-risk graph, topological sort for build order
  -> Show dependency graph with parallel lanes, user confirms execution plan
  -> For each spec in order:
     -> Validate prerequisites @status(verified)
     -> Investigate codebase for this spec's requirements
     -> Spec-driven TDD: RED (failing tests from scenarios) -> GREEN -> REFACTOR
     -> API Wiring Checkpoint: replace all mock/hardcoded data with real API calls (full-stack)
     -> Dead UI Scan: every button/form/toggle has a real handler (no empty/placeholder)
     -> Verify: full test suite + code review + spec coverage + test effectiveness
     -> API integration check: verify wiring is correct (not stubs)
     -> USER SIGN-OFF: pause for user to confirm work matches expectations (unless --auto)
     -> Update spec @status(verified), close beads task
  -> Auto-iterate to next spec
  -> Phase 4: Epic close
     -> Playwright e2e tests for all CUJs (multi-spec UI epics)
     -> Final verification
     -> Close Tests gate task, close epic
```

## Hard Constraints (every spec, no exceptions)

1. Specs must exist in `specs/` with `@status(approved)` or `@status(implemented)`
2. Codebase investigated before writing code
3. Failing tests generated FROM spec scenarios before implementation (TDD)
4. Full verification suite + code review agent + spec coverage check
5. API integration check: every UI button/form/nav wired to real API calls — not stubs (UI specs with API endpoints)
6. Layer awareness: full-stack specs require ALL layers (API + UI + wiring) before @status(verified)
7. API wiring checkpoint (Step 3.2.5): full-stack UI must be wired to real data layer before verification
8. Spec @status updated after verification passes
9. Investigation findings logged as bd comments on epic
10. Every verification failure logged as structured bd comment
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

### Worked example — scenario to failing test

Spec:
```markdown
### Scenario: Missing required parameters
- Given I omit the lat parameter
- When I GET /api/breweries/nearby?lng=-74.0060&radius=10
- Then I receive a 400 response
- And the error message indicates lat is required
```

Generated failing test:
```javascript
test("Missing required parameters - omitting lat returns 400", async () => {
  // Given: omit the lat parameter (no setup needed)
  // When
  const response = await request(app).get("/api/breweries/nearby?lng=-74.0060&radius=10");
  // Then
  expect(response.status).toBe(400);
  expect(response.body.error.message).toContain("lat");
});
```

This test MUST fail before implementation. Implementation makes it pass.

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
**Use /build when approved specs exist and you're ready to implement.**

- Specs exist in `specs/` with `@status(approved)` or `@status(implemented)`
- Beads epic and tasks exist for the work
- /design has been run and user has confirmed specs

**Don't use /build for:**
- New work with no specs — use `/design` first
- Pure questions/explanations (no code changes)
- Work that needs design decisions — run `/design` to shape it first
</when_to_use>

<the_process>

## Phase 1: Entry Validation

**Announce:** "I'm using the /build skill to implement approved specs."

### Parse flags
Check if `--auto` was passed as an argument to `/build`:
- `--auto`: Skip user sign-off checkpoints after each spec (Step 3.4). All verification agents still run — this only skips the interactive pause.
- Default (no flag): Pause after each spec for user to confirm the work matches expectations.

### Check for specs
```bash
ls specs/ 2>/dev/null
```

If no `specs/` directory or no spec files:
- "No specs found. Run `/design` first to generate Gherkin spec files."
- STOP. Do not proceed.

### Check spec statuses
Read each spec file and check `@status` tags:
- `@status(approved)` — ready to implement
- `@status(implemented)` — in progress, resume
- `@status(verified)` — complete, skip
- `@status(draft)` — not approved, skip (tell user to run /design)

If ALL specs are `@status(verified)`:
- "All specs are verified. Nothing to build."
- STOP.

If ALL non-verified specs are `@status(draft)`:
- "Specs exist but none are approved. Run `/design` to complete the reality check."
- STOP.

### Check beads epic
```bash
bd list --status=open --type=epic 2>/dev/null
```

If no open beads epic referencing the specs:
- "No beads epic found. Run `/design` to set up tracking."
- STOP.

Note: Per-spec implementation tasks are created by /build after investigation (Step 3.1), not by /design. Only the epic and Tests gate task need to exist at entry.

## Phase 2: Dependency Graph

Parse `@depends-on` and `@parallel-risk` tags from all spec files to build the build order:

1. Read all spec files in `specs/`
2. Extract `@depends-on(feature-slug)` and `@parallel-risk(feature-slug)` tags from each
3. Build a directed dependency graph
4. Topological sort for build order (no dependencies first, then dependents)
5. Validate: no circular dependencies, all referenced specs exist, all `@parallel-risk` tags reference existing specs

### Parallel Risk Analysis

For specs with `@parallel-risk` tags:
1. Identify pairs of specs with mutual `@parallel-risk` tags
2. Note: parallel-risk specs remain parallel — they are NOT sequenced by `@depends-on`
3. Recommendation: build smaller/simpler spec first to minimize merge conflict resolution
4. Warn about file overlap when announcing build order

### Graph Visualization and Confirmation

Present the dependency graph to the user via AskUserQuestion, showing parallel lanes and sequential chains:

**When parallel specs exist** (any specs at the same dependency level with no `@depends-on` between them), present the graph and ask the user to confirm:

```
"Here is the build order based on spec dependencies:

Lane 1 (parallel):
  ├── specs/user-registration.md (no dependencies)
  └── specs/email-service.md (no dependencies)

Lane 2 (after Lane 1):
  └── specs/user-authentication.md (depends on: user-registration)

⚠ Parallel-risk: user-registration.md and email-service.md share file overlap (user-routes.ts)
  → Recommend building email-service.md first (smaller/simpler)

Confirm this execution plan? You can request sequential execution for any parallel specs."
```

**When all specs are independent** (no `@depends-on` between any), all appear in a single parallel lane:

```
"All 3 specs are independent — can be built in parallel:

  ├── specs/cli-export.md
  ├── specs/api-export.md
  └── specs/config-validation.md

Confirm parallel execution?"
```

**When all specs are purely sequential** (a single chain with no parallel lanes), announce the build order as a printed message (not via AskUserQuestion) and proceed immediately — there is no parallel decision to make.

**User overrides:**
- User can request sequential execution of parallel specs (e.g., "run these in order")
- User can reorder within a lane
- No `@depends-on` tags are modified — the specs remain logically independent

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
| `api` | backend-engineer | security + devops + data |
| `ui` | frontend-engineer | security + devops + (data if `@touches-data`) |
| `full-stack` | backend-engineer then frontend-engineer | security + devops + data |
| `cli` | backend-engineer | security + devops |
| `infra` | backend-engineer | security + devops |

For full-stack specs, `@status(verified)` requires BOTH layers implemented and wired. `require-handoff-artifact.sh` enforces this.

For `@layer(ui|full-stack)` specs in an epic with ≥2 user-facing specs, `@status(verified)` ALSO requires the feature to be **mounted in the product** — listed in the `@integration` spec's `## Mount Map` (or imported by the app entry). A feature whose component exists and whose own tests pass but which the running app never mounts is a disconnected demo card, not a verified feature (the SquashBuckler failure). `require-feature-mounted.sh` enforces this at the `@status(verified)` write; the frontend-engineer must wire the feature into the shell as part of implementation, not leave it standalone. Override (sub-component mounted by another feature): `@mount-skip(reason)`.

**Dispatch codebase-investigator:**

```
Agent tool (subagent_type: hyperpowers:codebase-investigator):
"Find existing patterns for specs/<slug>.md. Report file paths, line numbers, conventions. Read the
PO handoff (step-2-<slug>-product-owner.html) and application-architect handoff (step-2.5-...) for
context. If the spec has a ## UI Design section, also read PRODUCT.md, DESIGN.md, and the mockup."
```

For specs involving external APIs/libraries/unfamiliar patterns, also dispatch `hyperpowers:internet-researcher` in parallel.

**Log findings into the spec.** Add a `## Investigation Findings` section with ≥3 lines including ≥2 file:line refs and a Decision: line. `hooks/require-investigation-findings.sh` blocks `@status(implemented)` writes without this section. Also log a summary as a bd comment on the epic for the audit trail.

**Refinement.** Invoke `hyperpowers:sre-task-refinement` to surface boundary conditions, error paths, and at least 1 domain edge case not in the spec.

**Skip the investigation findings section when:** Spec is `@trivial`. Otherwise use `@investigation-skip(reason)` only when the work is so derivative that codebase investigation adds nothing — rare.

#### Step 3.1.1: Data Architect Investigation (when applicable)

**Dispatch the data-architect role agent** when the spec touches persistent data. This runs as a focused augment to the general investigation: schema context, existing query patterns near the spec's surface, integrity invariants, recent migrations.

**Trigger condition:** Spec is tagged `@touches-data` OR `@layer(api|full-stack)` with Technical Context that mentions DB operations.

```
Agent tool (subagent_type: data-architect, run_in_background: false):
"You are running Step 3.1.1 (data investigation) for specs/<slug>.md. Read the application-architect
handoff, the spec's Technical Context, and the schema definition files. Produce a Step 3.1
investigation handoff augment at:
  specs/handoffs/step-3.1-<slug>-data-architect.html
covering: tables/columns touched, existing query patterns, invariants (FKs, unique, soft-delete),
recent migrations, indexes near the spec's surface."
```

(The Step 3.3 data safety REVIEW is a separate dispatch — see Step 3.3.3 below.)

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

Step 3.3f (API Integration Check) verifies the same surface independently from the reviewer's side.

### Step 3.2.6: Dead UI Scan (All UI-facing specs)

**BLOCKING GATE.** Scan implementation files for interactive elements with no handler (buttons without `onPress`/`onClick`, empty `() => {}` handlers, `Alert('TODO')`, navigation that doesn't navigate, forms without `onSubmit`). This catches mockup-to-implementation handoff failures.

The frontend-engineer agent SHOULD have caught these during REFACTOR; this is the orchestrator's belt-and-suspenders check. Cross-reference the spec's `## Interaction Map` — every row needs a functional handler in the implementation.

Log a `DEAD UI SCAN: ... Verdict: PASS|FAIL` bd comment with element counts. Any dead element = CRITICAL. Decorative elements (icons, labels, dividers) are fine.

**Skip when:** `@layer(api|cli|infra)`.

### Step 3.3: Verify

**Full verification. NEVER scales down. Identical for every spec.**

Dispatch these three agents in parallel:

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

**Manual spot-check:** Open each test file, spot-check 3+ tests: "What specific bug would this catch?" Log as bd comment.

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

#### Step 3.3c.1: Security Architecture Review

**Dispatch the security-architect role agent** between code-review (3.3c) and visual-fidelity (3.3d). It threat-models the diff, walks trust boundaries, and flags injection / SSRF / IDOR / CSRF / XSS / secrets / authz / authn issues.

```
Agent tool (subagent_type: security-architect, run_in_background: false):
"You are running Step 3.3c.1 (security review) for specs/<slug>.md. Read the application-architect
handoff (step-2.5) for data-flow context, the spec, and the implementation diff. Apply the OWASP-style
checklist in your prompt. Produce your handoff at:
  specs/handoffs/step-3.3-<slug>-security-architect.html
Each CRITICAL or IMPORTANT finding must cite a file:line in the implementation. Do not invent threats."
```

When the agent returns: if it produced an `<aside data-severity="critical" data-blocks-next-step="true">`, do NOT proceed to 3.3d. Fix the CRITICAL findings first, then re-dispatch.

**Skip when:** Spec is `@trivial` (no functional change to security surface).

#### Step 3.3c.2: DevOps / Operability Review

**Dispatch the devops-architect role agent.** Reviews the diff for deployment delta (new env vars, secrets, infra), migration safety, feature-flag posture, observability (logs/metrics/traces), resource budgets, rate-limits/timeouts, health checks, rollback story, and cost.

```
Agent tool (subagent_type: devops-architect, run_in_background: false):
"You are running Step 3.3c.2 (operability review) for specs/<slug>.md. Read the application-architect
handoff, the implementation diff, and any infra files. Walk the operability checklist in your prompt.
Cite file:line for every finding. Produce your handoff at:
  specs/handoffs/step-3.3-<slug>-devops-architect.html"
```

**Skip when:** Spec is `@trivial`.

#### Step 3.3c.3: Data Safety Review (when applicable)

**Dispatch the data-architect role agent** when the spec touches persistent data (same trigger as Step 3.1.1). Reviews the implementation diff for schema-change safety, migration locking risk, index posture, query shapes (N+1, SELECT *), transactions, concurrent-write hazards, soft-delete consistency, PII handling.

```
Agent tool (subagent_type: data-architect, run_in_background: false):
"You are running Step 3.3c.3 (data safety review) for specs/<slug>.md. Read the backend-engineer
handoff (the diff), the schema files, and the recent migrations. Produce your handoff at:
  specs/handoffs/step-3.3-<slug>-data-architect.html
Include EXPLAIN output for new queries; cite file:line for every concern."
```

**Trigger:** `@touches-data` tag OR `@layer(api|full-stack)` with DB operations in Technical Context.

#### Step 3.3d: QA Engineer per-spec verification (authoritative)

**Dispatch the qa-engineer role agent.** This step CONSOLIDATES three checks that used to be orchestrator-inline (visual fidelity, scenario coverage, API integration) under a single dispatch. The QA agent runs the actual test framework against the actual running app — spins up the dev server, drives a real browser, screenshots both implementation and mockup, intercepts network traffic to verify every Interaction Map row fires its declared API call.

```
Agent tool (subagent_type: qa-engineer, run_in_background: false):
"You are running Step 3.3d (per-spec QA) for specs/<slug>.md. Read the engineers' handoffs, the
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

#### Step 3.3g: SRE + Intent Audit

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
   from your system prompt, then a single Verdict line."
   ```

3. **Route findings by severity:**

   - **CRITICAL** → log via `bd comments add` with category `sre-intent-audit` and severity CRITICAL. Feed into the existing fix-verify loop in "Verification Failure Handling" below (max 3 cycles). Spec cannot reach `@status(verified)` until cleared.
   - **IMPORTANT** → create a follow-up beads task per finding:
     ```bash
     NEW_ID=$(bd create --title="<finding summary>" \
       --description="From SRE+Intent audit of specs/<feature-slug>.md. Location: <file:line>. Finding: <details>. Why it matters: <spec-tie>. Recommendation: <fix>." \
       --type=task --priority=2 | grep -oE 'workflow-[a-z0-9]+' | head -1)
     bd dep add "$NEW_ID" <this-spec-task-id>
     ```
     Spec can proceed to Step 3.4 once CRITICAL/SPEC-DRIFT findings are clear.
   - **SUGGESTION** → log via `bd comments add` only. No task created.
   - **SPEC-DRIFT** → **STOP.** Do not flip status to verified. Surface the finding to the user and recommend running `/respec` against the affected spec(s). The auditor's `Recommendation` line becomes input to `/respec`. Do not enter the fix-verify loop — code fixes cannot resolve a spec-drift finding.

4. **Log the audit:**

   ```bash
   bd comments add [epic-id] "SRE + INTENT AUDIT: specs/<feature-slug>.md

   Intent source: Why/Outcome + scenarios + parent epic + upstream specs
   Findings:
     CRITICAL:   [N] — [brief list of locations]
     IMPORTANT:  [N] — created follow-up tasks [ids]
     SUGGESTION: [N]
     SPEC-DRIFT: [N] — [affected specs, if any]

   Verdict: PASS | FAIL (critical) | FAIL (spec-drift)"
   ```

**Severity escalation:**
- `Verdict: FAIL (critical)` → enter fix-verify loop. Max 3 cycles.
- `Verdict: FAIL (spec-drift)` → halt and surface to user; recommend `/respec`. Do not enter the fix loop.
- `Verdict: PASS` → proceed to Step 3.4.

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

#### Step 3.3h: Fix-Cycle (run after any reviewer returns CRITICAL/IMPORTANT findings)

**Reviewers (QA, security-architect, devops-architect, data-architect, code-reviewer, sre-auditor) flag — implementers fix — finders re-verify.** This is the explicit orchestration of that loop. Each finding in a reviewer handoff carries `data-route-to="<role>"` per `docs/role-agent-handoff-schema.md`; this step reads those attributes and dispatches the right implementer.

**Process per cycle:**

1. **Aggregate findings.** Across every reviewer handoff produced in Step 3.3a–3.3g, collect every `<aside data-severity="critical|important">` and every findings-table row with `data-route-to`. Don't drop SUGGESTION findings — they go into open-questions, not the fix queue.
2. **Group by `data-route-to`.** Build a per-implementer queue:
   ```
   backend-engineer:    [finding-1, finding-3, finding-7]
   frontend-engineer:   [finding-2, finding-5]
   uiux-designer:       [finding-4]
   ```
3. **Dispatch implementers in parallel.** Independent implementers can fix in parallel — include multiple `Agent` tool calls in a SINGLE message (per the parallel-dispatch pattern in this skill's header). Each dispatch includes that implementer's findings list and the source-handoff paths:

   ```
   Agent tool (subagent_type: backend-engineer, run_in_background: false):
   "You are running Step 3.3h fix-cycle N for specs/<slug>.md. Findings routed to you:
   - finding-1 from specs/handoffs/step-3.3-<slug>-security-architect.html (CRITICAL: missing CSRF on PATCH /api/preferences/theme:24)
   - finding-3 from specs/handoffs/step-3.3-<slug>-data-architect.html (IMPORTANT: schema/migration drift)
   ...
   Per your fix-mode protocol: fix narrowly, add regression tests, re-run affected tests. Produce
   follow-up handoff at specs/handoffs/step-3.2-<slug>-backend-engineer-fix-cycle-N.html."
   ```

4. **Re-dispatch the original finders.** When all implementers have returned, re-dispatch each reviewer whose findings were addressed, with the prior cycle's handoff path so they can re-verify only the previously-flagged findings (not the whole spec). Re-dispatched reviewers produce new handoffs at `specs/handoffs/step-3.3-<slug>-<role>-cycle-N.html`.

5. **Re-aggregate.** Read the new reviewer handoffs. If any CRITICAL or IMPORTANT findings remain (new or unaddressed), go to cycle N+1.

6. **Cap at 3 cycles.** After cycle 3, if CRITICAL findings still exist, do NOT write `@status(verified)`. Pause and escalate to the user via AskUserQuestion with the remaining findings + recommended disposition (override / defer to follow-up beads task / `/respec` the spec).

**Routing exceptions:**
- `data-route-to="product-owner"` — does NOT enter the fix-cycle. Escalate to user via AskUserQuestion. Likely needs `/respec` or scope decision.
- `data-route-to="application-architect"` — does NOT enter the fix-cycle. Pause and run a focused `/respec` slice (blast radius + propagation) before resuming /build on the affected specs.

**Logging:**

```bash
bd comments add [epic-id] "FIX CYCLE $N for specs/<slug>.md:
Findings addressed: [N CRITICAL, M IMPORTANT, K SUGGESTION-deferred]
Routed to:
  backend-engineer: [N1 findings, handoff: step-3.2-<slug>-backend-engineer-fix-cycle-$N.html]
  frontend-engineer: [N2 findings, handoff: ...]
Reviewer verdicts (after fix):
  qa-engineer: PASS | FAIL (M remaining)
  security-architect: PASS | FAIL
  ...
Next: proceed to Step 3.4 | run cycle $((N+1)) | escalate to user (cycle cap reached)"
```

The fix-cycle is the single most important orchestration step. Without it, reviewers' findings become advisory text nobody acts on; with it, every CRITICAL has a deterministic path to resolution.

**Backstop hook: `require-fix-cycle-handoff.sh`** (PreToolUse on Edit/Write of `@status(verified)`). For each cycle number N detected under `specs/handoffs/`, both sides must exist on disk: at least one `step-3.2-<slug>-<role>-fix-cycle-N.html` (implementer) AND at least one `step-3.3-<slug>-<role>-cycle-N.html` (reviewer). Asymmetric cycles block. This catches the recurring failure mode where an implementer agent does the fix work but returns without writing its handoff — by the time you try to verify the spec, the asymmetry surfaces and you can re-dispatch with stronger language. Override per cycle via `@fix-cycle-skip(<N>: <reason>)`.

**Post-dispatch sanity check** (after each agent returns in a fix-cycle): immediately confirm the expected handoff file exists on disk (`ls specs/handoffs/step-3.2-<slug>-<role>-fix-cycle-${N}.html`). If missing, re-dispatch the same agent with: *"Your prior dispatch returned without writing `<expected-path>`. That handoff IS the deliverable, not the verbal confirmation. Per your Exit checklist section, write it now."* The Exit checklist section in every agent prompt names this as a TERMINAL step.

**Do not sleep-poll background work.** If a test-runner or fix-mode dispatch is long-running, use `run_in_background: true` and let the harness notify on completion, or `Monitor` to stream events. `sleep 60 && tail X` either wastes time or misses the result. Recurring anti-pattern; the Bash tool description forbids it.

### Step 3.4: User Sign-Off Checkpoint

**Unless `--auto` flag was passed**, pause and present a summary to the user for final sign-off before marking the spec as verified.

Use AskUserQuestion:

```
"Spec `specs/<feature-slug>.md` implementation complete. Here's what was built:

**Scenarios implemented:** [N/N]
**Tests:** [N passing, 0 failing]
**Verification:** All agents returned PASS
[If UI-facing:] **Visual fidelity:** PASS — matches mockup

Key implementation decisions:
- [Decision 1 — e.g., chose X pattern over Y because of codebase convention]
- [Decision 2 — e.g., added edge case scenario for Z]

Files changed:
- [file1.ts — what changed]
- [file2.test.ts — what changed]

Does this match your expectations? (yes / no / concerns)"
```

**If user says no or raises concerns:**
- Address the concerns (fix code, adjust approach)
- Re-run verification if changes were made
- Present updated summary and ask again
- Maximum 3 sign-off cycles before escalating with full context

**If user says yes:** Proceed to Step 3.5.

**If `--auto` flag was passed:** Skip this step entirely and proceed directly to Step 3.5.

### Step 3.5: Complete This Spec

After verification passes (including Step 3.3g SRE + Intent Audit with `Verdict: PASS`) and user sign-off (unless `--auto`):

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

**Dispatch the qa-engineer role agent (second dispatch — distinct from Step 3.3d).** Step 3.3d covered per-spec verification (visual fidelity, connectivity, scenario coverage). Step 4.1 covers the journeys that SPAN multiple specs — the integration tests per-spec QA can't see because they exist only when several features are wired together (e.g. "register → log in → create list → add task → mark done → view history").

The agent collects every `## Critical User Journeys` row across the epic's specs, authors one e2e test per unique journey, runs the suite against the running app, and reports cross-spec coverage. Same framework detection logic as Step 3.3d.

**The assembled-app rule.** Every e2e test MUST start from the application's **real entry point** (the integration spec's app shell / entry route) and reach each feature through **real navigation** — clicking the actual nav, opening the actual route. Tests that deep-link straight to a feature page or mount a feature component in isolation do NOT count: they re-verify the demo card, not the assembled product. This is the gap that let SquashBuckler ship 40 features that each passed in isolation while the app reached none of them. The QA agent must also assert **Mount Map reachability**: for the epic's `@integration` spec, every row in its `## Mount Map` is reachable from the entry point. Any Mount Map row that cannot be reached = CRITICAL orphan.

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

Log a `E2E PLAYWRIGHT TESTS: CUJ Coverage ... Verdict: PASS|FAIL` bd comment on the epic with per-journey verdicts copied from the qa-engineer handoff.

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
```bash
bd show [tests-task-id]  # Verify all criteria met
bd close [tests-task-id]
```

### Step 4.4: Log Final Verification Comment
```bash
bd comments add [epic-id] "VERIFICATION Phase 4: PASSED — all specs verified
Specs verified: [list]
Total scenarios: [N]
All unit tests passing.
Playwright e2e: [N] CUJs tested, all passing. (or: N/A — backend-only / CLI-only / single-spec with no UI)"
```

### Step 4.5: Close Epic
```bash
bd close [epic-id]
```

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
Without /build's discipline, "it's just a typo" reads as permission to skip TDD, code review, and the spec-coverage check. The agent fixes the misspelling, runs no tests, and marks the spec verified. Then a `grep` misses one occurrence in a comment, or the test suite has nothing asserting the absence of the old spelling, and the typo regresses in the next change. Verification doesn't scale down — every spec gets the same gates because "trivial" is the exact word that turns into "we didn't check."
</why_it_fails>

<correction>
**Phase 1:** Entry validation — `specs/fix-readme-typo.md` exists with `@status(approved)`. Beads task exists.

**Phase 2:** No dependencies.

**Phase 3:**
- Investigate: Read spec, grep for typo instances across project
- TDD RED: Write test asserting no instances of 'recieve' remain
- TDD GREEN: Fix all instances
- TDD REFACTOR: (nothing to refactor)
- Verify: Run tests, code review, spec coverage (1/1 scenario covered)
- Update: `@status(verified)`, close beads task

**Phase 4:** Close Tests task, close epic, offer commit.
</correction>
</example>

<example>
<scenario>Standard spec — new API endpoint (4+ scenarios)</scenario>

<why_it_fails>
Without spec-driven TDD, the agent writes the endpoint first and bolts tests on after. The tests look at the implementation, mirror its branches, and pass because they were written to match what the code does — not to assert what the spec says. A scenario like "radius=0" might be in the spec but the agent doesn't notice it because the implementation never crossed that path. Spec coverage check fails or, worse, it's not run. The endpoint ships missing an edge case the spec explicitly required. TDD from the scenario list is what guarantees the test asserts the spec, not the code.
</why_it_fails>

<correction>
**Phase 1:** Entry validation — `specs/nearby-breweries-endpoint.md` exists with `@status(approved)`. Beads task exists.

**Phase 2:** No dependencies. Build order: 1 spec.

**Phase 3:**
- Investigate: Read spec, dispatch codebase-investigator (existing endpoint patterns, validation, response format). Log findings.
- TDD via executing-plans:
  - RED: Write failing tests for all 4+ scenarios
  - GREEN: Implement endpoint following discovered patterns, one scenario at a time
  - REFACTOR: Clean up
  - Discover edge case: radius=0. Add scenario to spec, write failing test, implement.
- Continuous verifier reviews each task's diff
- Verify: Full suite + code review (with spec) + spec coverage check (5/5 scenarios) + API integration check (N/A — backend-only spec)
- User sign-off: present summary, user confirms
- Update: `@status(verified)`, close beads task

**Phase 4:** Playwright e2e (N/A — single-spec). Close Tests task, close epic, offer PR.
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

**Phase 3 — Spec 1 (user-registration):**
- Investigate: Read spec + system.md. Dispatch codebase-investigator + internet-researcher.
- TDD: RED for all registration scenarios → GREEN → REFACTOR
- Continuous verifier per task
- Verify: Full suite + code review + spec coverage + API integration check (all form submissions wired)
- User sign-off: present summary, user confirms
- Update: `@status(verified)`, close beads task

**Phase 3 — Spec 2 (user-authentication):**
- Prerequisite check: user-registration is `@status(verified)` — proceed
- Investigate: Read spec + system.md + user-registration.md (now implemented — understand User model, registration API)
- TDD: RED for auth scenarios (including Scenario Outline rate limiting — 3 parameterized tests) → GREEN → REFACTOR
- Continuous verifier per task
- Verify: Full suite + code review + spec coverage + API integration check (login/logout wired)
- User sign-off: present summary, user confirms
- Update: `@status(verified)`, close beads task

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

### Incident Categories

| Category | When to Use |
|---|---|
| skill-gap | No guidance existed for this situation |
| missing-rule | A rule should exist but doesn't |
| wrong-default | An existing behavior/default is wrong |
| edge-case | Existing rules don't cover this scenario |
| process-violation | You violated an existing rule |

### No Active Epic

If no epic is active, create or reuse a dedicated `workflow-incidents` issue:
```bash
bd create --title="Workflow Incidents" --type=task --description="Collects workflow incidents when no epic is active. Retrospective reads these."
```
</incident_logging>

<critical_rules>
## Rules That Have No Exceptions

1. **Specs required** -> No specs = no build. Run /design first.
2. **Always investigate before writing** -> Read target files minimum. Dispatch agents. Log findings.
3. **Always spec-driven TDD** -> Tests generated FROM spec scenarios before implementation. RED → GREEN → REFACTOR. Every spec. No exceptions.
4. **Never scale down verification** -> Full suite + code review + spec coverage. Simple specs get same verification as complex ones.
5. **Tests gate task is sacred** -> NEVER close during implementation. Only close after ALL verification passes.
6. **Log every verification failure** -> Structured bd comment (via `bd comments add`) with category, severity, source, action.
7. **Log a VERIFICATION comment before closing** -> Even when all passes: "VERIFICATION: PASSED — no issues found."
8. **Dependency order is mandatory** -> Verify prerequisites are `@status(verified)` before starting dependents.
9. **Parallel-risk is a warning, not a blocker** -> `@parallel-risk` specs have no `@depends-on` relationship. They are not sequenced relative to each other. /build warns about file overlap but does not add sequencing.
10. **Pause on fundamental spec drift** -> Wrong approach, missing feature, incorrect data model, contract changes = STOP, direct to /respec (modify existing spec) or /design (new specs needed). Do NOT silently rewrite specs.
11. **Always use subagents** -> Investigation, code review, test running, test analysis = subagents. Never do manually what an agent can do.
12. **Continuous verifier for multi-scenario specs** -> Spawn when first task starts. Reviews 5 dimensions per task. CRITICAL blocks closure.
13. **New spec scenarios get failing tests FIRST** -> If you add a scenario during implementation, write its failing test before implementing it.
14. **Never update status while verification is in flight** -> Do NOT update `@status` or close beads tasks while verification agents are still running. Verification results MUST be received and passed BEFORE any status change or closure. "While waiting for verification" is never a valid reason to update status — that is the one thing that depends on the results.
15. **UI-facing specs: start from mockup, not from scratch** -> If `specs/mockups/<feature-slug>/` or `.html` exists, the mockup component IS the starting point for implementation. Copy it, wire in real data. Do not implement UI from scratch and ignore the mockup. Tests passing with ugly/unstyled UI is a CRITICAL failure.
16. **Visual fidelity is part of verification** -> For UI-facing specs, the visual fidelity check (Step 3.3d) is mandatory. Typography, color, layout, and CSS tokens must match the `## UI Design` section. "It works" is not enough — it must also look right.
17. **Browser iteration during TDD for UI specs** -> After each scenario group passes (GREEN), view the implementation in a browser across viewports (desktop, tablet, mobile). Compare against the mockup. Fix visual issues immediately — do not batch them for "later."
18. **Critique + detect + polish quality pipeline for UI specs** -> After visual fidelity check, run `/impeccable critique` (design review + 27 anti-pattern rules), `/impeccable detect` (deterministic scanner on source), and `/impeccable polish` (final quality pass). All three are mandatory for UI-facing specs. Enhancement commands (`/bolder`, `/colorize`, `/typeset`, etc.) when critique finds blandness.
19. **Read PRODUCT.md + DESIGN.md during UI implementation** -> The design system tokens and brand context are the source of truth for visual decisions. Read them during investigation (Step 3.1) and reference them during visual verification (Step 3.3d). Do not implement UI without loading the design system.
20. **API integration check for UI-facing specs** -> Every interactive UI element (button, form, navigation) that implies backend communication must be wired to a real API call — not a TODO, stub, or local-state-only dispatch. Step 3.3f is mandatory for UI specs with API endpoints.
21. **Playwright e2e tests before epic close** -> For multi-spec UI epics, Playwright e2e tests covering every CUJ from the specs must pass before Phase 4 can close the epic. This is the cross-spec integration gate. Unit tests verify features in isolation; e2e tests verify the assembled application.
22. **Layer awareness for full-stack specs** -> When a spec describes both API endpoints AND UI screens, BOTH layers must be implemented and tested before `@status(verified)`. Building only the API and marking verified is a process violation. Layer detection is mandatory in Step 3.1; layer-aware coverage is mandatory in Step 3.3e.
23. **API wiring checkpoint before verification** -> For full-stack specs, Step 3.2.5 is a BLOCKING gate. Every UI component must be wired to the real data layer (no hardcoded/mock data remaining) before verification (Step 3.3) can begin. This is "do the wiring" — Step 3.3f is "verify the wiring." Both required.
24. **Follow the project's API client pattern** -> Components must use the API client pattern defined in the system spec or arch.md (centralized service layer, Supabase client, etc.). No ad-hoc fetch calls that bypass the established architecture.
25. **UI tests must assert behavior, not just rendering** -> A test that only checks "button exists" is not a UI test. Every interactive element (button, form, toggle, nav) needs a behavior assertion: press triggers handler, submit dispatches data, toggle updates state. Render-only tests are insufficient for GREEN.
26. **Dead UI scan before verification** -> Step 3.2.6 scans for buttons with no handlers, forms with no submission, empty onPress callbacks, and console.log placeholders. Any dead interactive element is CRITICAL. Mockup code carried into implementation without functionality is a broken feature.
27. **A UI feature is not verified until it is mounted in the product** -> In an epic with ≥2 user-facing specs, `@status(verified)` on a `@layer(ui|full-stack)` spec requires the feature to be in the `@integration` spec's `## Mount Map` and reachable from the app entry — not just passing its own tests in isolation. Wiring the feature into the shell is part of implementation. `require-feature-mounted.sh` blocks orphans; the Step 4.1 e2e drives the real entry point; the release-coordinator runs the orphan check at close. SquashBuckler shipped ~40 features verified as isolated demo cards because none of these existed — a mockup is a build step, not a deliverable.

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "I know this codebase" -> Investigation prevents pattern drift. Still investigate.
- "Tests aren't needed for this" -> Tests gate task is mandatory.
- "Verification is overkill" -> Verification never scales down.
- "I'll investigate while coding" -> Investigate FIRST, log findings, THEN code.
- "I'll review the code myself" -> Code review agent catches things you'll miss. Always dispatch.
- "The continuous verifier already covered this" -> Verifier checks per-task diffs. Final verification checks full epic. Both required.
- "I'll update the status while waiting for verification" -> NO. Status updates and task closures depend on verification results. Wait for agents to return, confirm they passed, THEN update. Doing it early defeats the entire purpose of verification as a gate.
- "SRE refinement will just say 'same as pattern'" -> Not valid output. Every task has unique edge cases.
- "Investigation findings are obvious" -> The log is for post-mortem later, not for you now.
- "I'll write tests without reading the spec" -> Tests MUST come from spec scenarios. No freelancing.
- "I'll implement first and test after" -> Opposite of TDD. Tests fail BEFORE implementation.
- "The spec only has 1 scenario" -> Still gets 1 failing test before implementation.
- "I'll update the spec later" -> Update NOW when you discover edge cases. "Later" means never.
- "This dependency isn't verified yet but I can start anyway" -> NO. Dependency order exists for a reason. Build on verified foundations.
- "The spec is fundamentally wrong but I can work around it" -> NO. Stop and direct to /respec (or /design if new specs needed). Working around a bad spec produces bad code.
- "The mockup is just a reference, I'll implement my own way" -> NO. The mockup IS the starting point. Copy it, wire in real data. It was designed with Impeccable + frontend-design for a reason.
- "The UI works, styling can come later" -> NO. "Works but ugly" is a CRITICAL failure. The design phase produced specific typography, color, and layout decisions — implement them now, not later.
- "CSS variables aren't resolving but the layout is correct" -> STOP. Unresolved CSS tokens mean the design system isn't wired up. Fix the token definitions before proceeding.
- "Tests pass so the component is done" -> Tests verify behavior. Visual fidelity verifies appearance. Both must pass for UI-facing specs.
- "Browser iteration across viewports is overkill" -> Mobile breakpoints catch 80% of visual bugs. If you don't check tablet/mobile, the user will — and they'll send you back. 30 seconds per viewport prevents hours of rework.
- "I'll run critique/detect/polish in one batch at the end" -> Each catches different problems. Critique after each major change; detect on source files; polish as final pass. Batching at the end means fixing issues that compound on each other.
- "The design looks fine without running critique" -> Your aesthetic judgment has blind spots. Critique's 27 deterministic rules catch patterns humans normalize (generic cards, template shadows, default spacing). Run it — it takes seconds.
- "PRODUCT.md/DESIGN.md aren't needed during build" -> The design tokens in DESIGN.md are the source of truth for colors, typography, and spacing. Building UI without reading them means guessing at values that are already defined. Read them.
- "Enhancement commands are for design, not build" -> If critique finds the implementation lost personality from the mockup, enhancement commands (`/bolder`, `/colorize`, `/typeset`) restore it. The mockup was the target — if implementation drifted, fix it.
- "Polish is redundant with the visual fidelity check" -> Visual fidelity checks mockup fidelity. Polish checks design system alignment — spacing consistency, typography hierarchy, interaction states, motion, responsive behavior. Different dimensions.
- "User sign-off slows things down" -> Sign-off catches misalignment BEFORE it compounds across dependent specs. Fixing one spec is cheaper than unwinding three. Use `--auto` only when you're confident the specs are well-defined and no ambiguity exists.
- "I'll get sign-off at the end for all specs" -> No. Sign-off is per-spec, not per-epic. Each spec checkpoint catches drift early. The epic close (Phase 4) has its own final verification — that is not a substitute for per-spec sign-off.
- "API integration is a separate concern from the UI spec" -> No. If the spec scenario says "client starts a workout" and the button calls a TODO function, the scenario is NOT implemented. UI specs that imply backend persistence are not done until the API calls are real.
- "Unit tests pass so the buttons work" -> Unit tests that don't assert API calls were made are testing the wrong thing. Green tests on stub implementations prove nothing. Step 3.3f catches exactly this.
- "E2e tests are overkill — unit tests cover everything" -> Unit tests verify each feature in isolation. E2e tests verify the assembled application. FitConnect's launch had every unit test green but no feature actually worked end-to-end. Playwright CUJ tests are MANDATORY for multi-spec UI epics.
- "The feature's tests pass and it looks right, so it's verified" -> Not if the running app never mounts it. A component that passes its own tests but isn't reachable from the app entry is a disconnected demo card. Wire it into the `@integration` spec's shell and add it to the Mount Map before `@status(verified)`. This is the SquashBuckler failure — 40 features verified, none assembled.
- "The e2e test renders the feature component directly, that's enough" -> No. Mounting a component in a test harness re-verifies the demo card. The Step 4.1 e2e must launch the REAL app entry and navigate to the feature the way a user does. If you can't reach it that way, it isn't in the product.
- "We'll build the app shell that ties it together at the end" -> The shell is the `@integration` spec and it must exist from decomposition so every feature declares `@mounts-in` it and wires into it during build. "At the end" is how SquashBuckler ended up retrofitting the shell under a separate slug after 40 features were already verified in isolation.
- "I'll write e2e tests after the epic closes" -> No. E2e tests are a Phase 4 gate. The epic cannot close without passing Playwright CUJ tests. "After" means never.
- "The API isn't ready so I can't test integration" -> If the API is in this epic, it should be built first (spec dependencies). If it's external, mock the API at the network layer (MSW), not in the component. Either way, the integration must be verified.
- "The API tests pass so the spec is implemented" -> If the spec describes UI scenarios ("client taps Start Workout", "trainer sees client list"), API tests alone are NOT implementation. The UI layer is missing. Check the layer detection from Step 3.1.
- "I'll build the mobile UI in the next session" -> Then don't mark `@status(verified)`. Mark `@status(implemented)` at most, with a note that the UI layer is pending. Verified means ALL layers are done.
- "The spec is full-stack but I can verify API separately" -> No. For full-stack specs, verification gates on ALL layers. Build API-first if you want, but don't close the loop until UI exists and is wired to the API. The trainr project marked 15 full-stack specs verified with zero mobile code.
- "Mobile apps can't be Playwright-tested" -> Use Detox, Maestro, or Appium for mobile e2e. If no mobile e2e framework is available, the UI layer still needs component tests and manual verification in a simulator. "Can't e2e test" is never an excuse to skip UI implementation entirely.
- "I'll wire the API calls after the UI is rendering" -> That IS Step 3.2.5. You cannot skip it. After GREEN (renders correctly), BEFORE verification (Step 3.3), you MUST wire every component. This is not optional polish — it's a blocking gate.
- "The component works with mock data for now" -> Mock data is for the RED/GREEN TDD cycle. Step 3.2.5 replaces ALL mock data with real data layer calls. Components with hardcoded data cannot proceed to verification.
- "I'll use ad-hoc fetch calls since they're simpler" -> No. Read the system spec / arch.md for the project's API client pattern. All components use it. Consistency is not optional — it's how the project stays maintainable.
- "The button renders, so the component works" -> Rendering is not working. A button that renders but does nothing on press is a dead element. UI tests MUST assert behavior: `fireEvent.press(button)` → state change / handler called. Render-only tests are insufficient for GREEN.
- "I'll add the handlers later" -> No. Handlers are part of implementation, not polish. Step 3.2.6 (Dead UI Scan) will block you if any interactive element has no handler. Add them during GREEN, not "later."
- "The onPress is empty because I'm waiting for the API" -> Use Step 3.2's build order: API-first, then UI, then wire. By the time you build the UI component, the API already exists. There is no reason for empty handlers.
- "Console.log is fine for now" -> `console.log` is a placeholder, not a handler. Step 3.2.6 catches these explicitly. Replace with real functionality.
</critical_rules>

<verification_checklist>
Before claiming /build is complete for a spec:

**Investigation:**
- [ ] Layer detection completed: API, UI, or Full-stack (Step 3.1)
- [ ] Layer detection logged as bd comment on epic
- [ ] Spec file read before investigation
- [ ] `## UI Design` section read (if present) — mockup path, typography, color, layout decisions noted
- [ ] Component mockup read from `specs/mockups/` (if UI-facing spec) — this is the implementation starting point
- [ ] @depends-on specs read for interface context
- [ ] @parallel-risk specs identified and flagged in build order announcement
- [ ] specs/system.md read (if exists) for conventions
- [ ] Investigation agents dispatched (with UI Design context for UI-facing specs)
- [ ] Findings logged as bd comments with file paths and conventions
- [ ] Beads implementation task created with investigation context (file paths, patterns, integration points)
- [ ] SRE refinement run on task (must find at least 1 domain-specific edge case)

**Implementation:**
- [ ] Failing tests generated FROM spec scenarios for ALL detected layers (API, UI, integration)
- [ ] Each Scenario has tests per layer; each Scenario Outline row has parameterized tests per layer
- [ ] Tests failed first (RED), then implementation passed them (GREEN)
- [ ] UI-facing specs: implementation started FROM mockup component code (not from scratch) — or N/A (no UI)
- [ ] UI-facing specs: typography, color, layout, CSS tokens match `## UI Design` section — or N/A (no UI)
- [ ] Spec updated as living doc (new scenarios, corrected Technical Context)
- [ ] New spec scenarios got failing tests BEFORE implementation
- [ ] Spec @status updated to @status(implemented)
- [ ] Continuous verifier spawned for multi-scenario specs
- [ ] API Wiring Checkpoint passed (Step 3.2.5): all components wired, no hardcoded data, correct API pattern — or N/A (single-layer spec)
- [ ] Dead UI Scan passed (Step 3.2.6): no buttons/forms/toggles without handlers — or N/A (no UI)
- [ ] Verifier findings logged on tasks; CRITICAL findings fixed before closing

**Verification:**
- [ ] Full test suite passed (test-runner agent)
- [ ] Test effectiveness analyzed (test-effectiveness-analyst agent)
- [ ] Test quality gate applied (3+ tautological = CRITICAL)
- [ ] Manual test spot-check completed and logged
- [ ] Code review agent dispatched with spec file as reference
- [ ] Spec scenario coverage check completed — per layer (every scenario implemented + tested in ALL detected layers)
- [ ] Integration point checklist included (cross-module specs)
- [ ] Dead code scan completed
- [ ] Browser iteration completed across viewports (desktop, tablet, mobile) during TDD — or N/A (no UI)
- [ ] Visual fidelity check passed (mockup fidelity, CSS tokens, key states) — or N/A (no UI)
- [ ] `/impeccable critique` quality gate passed — or N/A (no UI)
- [ ] `/impeccable detect` anti-pattern scan passed — or N/A (no UI)
- [ ] Enhancement commands applied if critique found blandness — or N/A (no UI / critique passed clean)
- [ ] `/impeccable polish` final quality pass completed — or N/A (no UI)
- [ ] Every failure logged as structured bd comment
- [ ] API integration check passed: all interactive UI elements wired to real API calls (Step 3.3f) — or N/A (backend-only / no API)
- [ ] Feature mounted in the product: listed in the `@integration` spec's `## Mount Map` and wired into the app entry (`require-feature-mounted.sh`) — or N/A (<2 user-facing specs) / `@mount-skip(reason)`
- [ ] User sign-off obtained (Step 3.4) — or N/A (--auto flag)
- [ ] Spec @status updated to @status(verified)
- [ ] Beads task closed

**Epic Close:**
- [ ] All specs @status(verified)
- [ ] Playwright e2e tests written for all CUJs from specs (Step 4.1) — or N/A (backend-only / CLI-only / single-spec with no UI)
- [ ] Epic e2e drives the REAL app entry point and every `## Mount Map` row is reachable from it (Step 4.1) — or N/A (<2 user-facing specs)
- [ ] Orphan-feature check passed: every `@layer(ui|full-stack)` spec is in the `@integration` spec's Mount Map (release-coordinator, Step 4.2) — or N/A (<2 user-facing specs)
- [ ] Playwright e2e tests all passing
- [ ] VERIFICATION comment logged on epic (including e2e results)
- [ ] Tests gate task closed
- [ ] Epic closed
- [ ] README updated (if applicable)
- [ ] Memory updated (if learnings exist)

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
| impeccable (critique) | UI verification — design quality review (Step 3.3d D2) |
| impeccable (audit) | UI verification — a11y, performance, responsive checks (Step 3.3d D3) |
| impeccable (harden) | UI verification — error/empty/edge states (Step 3.3d D4) |
| impeccable (clarify) | UI verification — UX copy, labels, messages (Step 3.3d D6) |
| impeccable (adapt) | UI verification — responsive across viewports (Step 3.3d D7) |
| impeccable (polish) | UI verification — final design system alignment (Step 3.3d D8) |
| impeccable (optimize) | UI verification — performance diagnostics (Step 3.3d D9) |
| impeccable (bolder/overdrive/colorize/typeset/delight/animate/layout/quieter/distill) | UI verification — targeted enhancement (Step 3.3d D5) |
| Playwright | E2E CUJ testing — cross-spec integration gate before epic close (Step 4.1) |

**This skill directs to:**

| Skill | When |
|---|---|
| /respec | Spec needs modification (wrong behavior, contract change, missing scenarios) |
| /design | No specs exist, or entirely new specs needed |

**This skill consumes (produced by /design or /respec):**
- `specs/*.md` files with `@status(approved)`
- Beads epic with per-spec tasks
- Task docs with spec references (if brainstorming was used)

**This skill is triggered by:**
- User typing `/build`
- After /design or /respec completes
</integration>

<edge_cases>

## No specs found
"No specs found in `specs/`. Run `/design` first." STOP.

## All specs verified
"All specs are `@status(verified)`. Nothing to build." STOP.

## Specs exist but no beads epic
Warn user, then create epic + Tests gate:
```bash
bd init  # If needed
# Create epic referencing specs + Tests gate task
# Implementation tasks will be created after investigation
```

## Dependency cycle detected
"Circular dependency detected: A depends on B depends on A. Run `/design` to fix the dependency graph." STOP.

## Prerequisite not verified
Skip the blocked spec, try the next unblocked one. If all remaining are blocked:
"All remaining specs are blocked on unverified prerequisites: [list]. Complete those first."

## Spec is fundamentally wrong during implementation
STOP implementation. Do NOT silently rewrite:
"The spec `specs/<name>.md` needs fundamental changes: [describe what's wrong]. Run `/respec` to modify the spec (traces dependencies, propagates changes, regresses statuses). If entirely new specs are needed, run `/design` instead."

## Verification fails repeatedly
1. First failure: fix and re-verify
2. Second failure: review approach, check if spec is wrong
3. Third failure: escalate to user with full context

## User asks to skip verification
REFUSE. Verification is non-negotiable. "Every spec gets full verification regardless of complexity."

## Resuming after session break
Read `specs/` directory. Specs at `@status(verified)` are done. `@status(implemented)` is in progress — resume from there. `@status(approved)` is next. Rebuild dependency graph and continue.

</edge_cases>
