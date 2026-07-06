---
name: design
description: Use when starting new work - Socratic questioning via AskUserQuestion, Gherkin spec generation in specs/, reality check with user confirmation, beads task creation. Produces approved specs that /build consumes.
---

<skill_overview>
Design skill that shapes work through Socratic questioning, generates Gherkin spec files as the source of truth for design intent, performs a reality check against the original request, and sets up beads for sub-task tracking. Produces `@status(approved)` specs in `specs/` that the `/build` skill consumes.

**Role-agent orchestration (experimental branch).** This skill is the orchestrator. Deep procedural work is delegated to specialized role agents in `agents/`:
- `product-owner` — Step 2 Socratic + Step 4 reality check
- `application-architect` — Step 2.5 decomposition (and Step 4.5 architecture docs)
- `uiux-designer` — Step 2.85 UI/UX (wraps `/design-ui`)

Each role agent produces an HTML handoff at `specs/handoffs/<step>-<slug>-<role>.html` per `docs/role-agent-handoff-schema.md`.

**Parallel-dispatch pattern.** To dispatch multiple role agents concurrently (e.g. `application-architect` + `devops-architect` for Step 4.5 arch docs), include MULTIPLE `Agent` tool calls in a SINGLE message. The harness fans them out in parallel; the tool result confirms concurrent launch. Splitting calls across separate messages serializes them.

**Dispatched agents cannot ask the user questions.** Per `docs/agent-protocol.md` §2, `AskUserQuestion` errors inside subagents. Agents write questions into their handoff's `open-questions` section as `<li data-question data-blocking="true|false">`; the ORCHESTRATOR relays blocking questions to the user via AskUserQuestion and re-dispatches the same role with the answers. Cap: 3 question rounds per step, then escalate with a written summary.

**Inline-synthesis fallback.** If the `Agent` tool is not available in your toolset (i.e. you are yourself a dispatched subagent and cannot dispatch further), fall back to inline synthesis: read each role's `agents/<role>.md` prompt, perform the role's work yourself, produce the same handoff file at the same path, and mark it with `<note data-synthesized="true">This handoff was synthesized inline because the Agent tool was unavailable.</note>` in the `findings` section. In inline mode, ask the user directly via AskUserQuestion when it is available in your toolset; when it is not (you are a dispatched subagent), record questions in the handoff's `open-questions` section and return them to your dispatcher per `docs/agent-protocol.md` §2. The audit trail stays schema-compliant; what's lost is diversity-of-perspective.

**Known limitation: TaskCreate reminders.** The Claude Code harness emits `system-reminder` messages suggesting `TaskCreate` periodically. They come from the harness itself, not our hooks, and cannot be silenced from the workflow side. Beads is the canonical task tracker (per the SessionStart hook); ignore the TaskCreate reminders.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: Socratic questioning via AskUserQuestion is mandatory — asked by the orchestrator, sourced from the product-owner agent's question set. No proceeding without user answers.
- **RIGID**: Every design produces Gherkin spec files in `specs/`. No exceptions.
- **RIGID**: Reality check (agent pre-check + user confirmation) must pass before specs are approved.
- **FLEXIBLE**: Questioning depth and spec complexity scale naturally with the work — simple fixes get fewer questions and simpler specs.
</rigidity_level>

<quick_reference>
## Design Flow

```
User request
  -> Socratic questioning via AskUserQuestion (BLOCKS until answered)
  -> Decompose: apply independence test, identify seams, produce decomposition map
  -> Generate Gherkin spec files in specs/ (one per entry in decomposition map)
  -> Reality check: agent pre-checks for gaps, shows dependency graph, user confirms
  -> If gaps found: ask more questions, re-decompose, regenerate specs
  -> Create beads epic + Tests gate task
  -> SRE refinement on tasks (when specs have multiple scenarios/rules)
  -> Exit: all specs @status(approved), beads tasks created
```

## Spec Complexity (Inferred, Not Classified)

| Signal | Spec Style |
|---|---|
| 1-2 files, <50 lines change, typo/rename/config | Feature + 1-3 Scenarios. No Rules, no Background. |
| Multi-file, new endpoint/component, clear pattern | Feature + As/I want/So that + Technical Context + Rules + Background + Scenarios |
| New feature/integration, architectural change, greenfield | Multiple spec files with `@depends-on`/`@blocks`. System spec required for greenfield. Scenario Outlines with Examples tables. |

## Hard Constraints

1. All questions asked via AskUserQuestion tool, by the ORCHESTRATOR (dispatched agents return question lists per `docs/agent-protocol.md` §2)
2. No investigation agents during questioning — investigation is /build's job
3. No proceeding until user answers all critical questions
4. Every design produces spec files in `specs/`
5. Reality check before specs are approved
6. Beads epic references spec files (not inline requirements)
7. Every epic has a mandatory Tests gate task
8. Per-spec implementation tasks are created by /build (after investigation), not /design
</quick_reference>

<gherkin_spec_reference>
## Gherkin Spec Files

Every design produces Gherkin-style Markdown spec files in the project's `specs/` directory. These specs are the **source of truth** for design intent — beads epics link to specs, they do not contain inline requirements.

**Detailed reference** (templates, tag list, decomposition heuristics, lifecycle, directory layout, scenario→test mapping): [resources/gherkin-spec-reference.md](resources/gherkin-spec-reference.md). Read it when generating specs or when /build needs to interpret them.

### Format (at a glance)

Specs use Markdown Gherkin: `#` headings for Gherkin keywords, `- ` bullet lists for steps, `@tags` at the top of the file.

### Tags (at a glance)

- `@status(draft|approved|implemented|verified)` — lifecycle tracking (required on every spec)
- `@layer(api|ui|full-stack|cli|infra)` — required on every spec. Deterministic skip signal that hooks and verification steps key on. Set during decomposition.
- `@trivial` — optional. Typo fix, rename, or config-only change. The single verification-scaling knob: set here at decomposition, never during /build. Permits skipping architecture docs, external feasibility research, and the tagged reviewer steps in /build.
- `@touches-data` — optional. Spec adds, modifies, or migrates persistent data. This tag is THE trigger for the data-architect role agent during /build (Step 3.1 investigation and Step 3.3f data-review). The hook warns — does not block — on `@layer(api|full-stack)` specs missing it; set it explicitly at decomposition for ANY spec that touches persistent data, whatever its layer (e.g., a CLI tool that writes to a shared DB).
- `@depends-on(feature-slug)` — this feature requires another feature to be implemented first
- `@blocks(feature-slug)` — another feature depends on this one
- `@parallel-risk(feature-slug)` — this spec modifies the same files as another independent spec. Both specs remain parallel (no `@depends-on` added). /build warns about potential merge conflicts and builds the smaller spec first.
- Custom domain tags: `@auth`, `@security`, `@onboarding`, etc. — categorization

See full tag reference and `@layer` value definitions in [resources/gherkin-spec-reference.md](resources/gherkin-spec-reference.md).

### Greenfield, tiers, lifecycle, decomposition (summaries)

- **Greenfield rebuild principle:** the complete spec set must be sufficient to rebuild the application from scratch — a **system spec** (`specs/system.md`: purpose, stack, data model, feature map, API conventions) plus one **feature spec** per feature linked via `@depends-on`/`@blocks`.
- **Complexity tiers:** Simple (Feature + 1-3 Scenarios) / Standard (+ As-I-want-So-that, CUJs, Technical Context, Rules, Background) / Complex (multiple spec files, Scenario Outlines). Full templates in the resource above — load it before writing a spec you haven't written this session.
- **Lifecycle:** `@status(draft)` → `approved` (reality check) → `implemented` (during /build) → `verified` (after /build verification).
- **Decomposition:** independence test — separate specs only if (1) testable without the other, (2) own inputs/outputs, (3) removing one doesn't break the other's tests; otherwise scenarios in one spec. Split along seams (data / lifecycle / consumer / layer / rule boundaries — table in the resource). Two independent specs touching the same file: tag both `@parallel-risk(other-slug)`, no `@depends-on`.
</gherkin_spec_reference>

<when_to_use>
**Use /design when starting new work.** This is the entry point for any task that involves code changes.

- User asks to implement a feature (any size)
- User asks to fix a bug
- User asks to refactor code
- User asks to add/change functionality
- User describes a problem to solve
- User provides requirements to implement

**Don't use /design for:**
- Pure questions/explanations (no code changes)
- Work that already has approved specs — use `/build` instead
- Continuing an in-progress /build cycle
</when_to_use>

<the_process>

## Step 2: Socratic Questioning

**Dispatch the product-owner role agent; the ORCHESTRATOR asks the questions.** The PO agent generates and refines the question set each round — the drill-down heuristics, greenfield protocol, and completeness gate categories live in `agents/product-owner.md`. It cannot ask the user anything itself (`docs/agent-protocol.md` §2); you are its mouth. The Socratic character is preserved as an orchestrator-driven loop:

1. **Dispatch** with the user's request (round 1) or the accumulated Q&A transcript (later rounds):

```
Agent tool (subagent_type: product-owner, run_in_background: false):
"You are running Step 2 (Socratic questioning) for a new design session. Generate the question set
that must be answered before decomposition can start. You cannot ask the user questions — write each
question into your handoff's open-questions section as <li data-question data-blocking="true|false">
with 2-4 proposed options and your recommendation, per docs/agent-protocol.md §2. Produce your
handoff at:
  specs/handoffs/step-2-<spec-slug>-product-owner.html

User's request: <paste the user's original message>
[Rounds 2+:] Answers so far: <paste the Q&A transcript>"
```

2. **Relay.** Read the handoff's `open-questions`. Ask every `data-blocking="true"` question to the user via AskUserQuestion, presenting the agent's options and recommendation.
3. **Re-dispatch** the same agent with the answers appended. It refines: drills into vague answers, generates follow-ups, or declares the completeness gate passed.
4. **Cap: 3 question rounds.** If blocking questions remain after round 3, escalate to the user with a written summary of what is unresolved and why.

When the agent declares completeness, verify: the handoff exists at the expected path; the `acceptance-criteria` section has at least one machine-checkable item; `open-questions` contains no unanswered `data-blocking="true"` items. If acceptance is incomplete (open questions outstanding, vague answers), do NOT proceed to Step 2.5 — dispatch again with the gaps surfaced.

## Step 2.3: Game Design (when applicable)

**Dispatch the game-designer role agent.** Run only when `.claude/game-context.md` exists — that's the deterministic signal this is a game project. Skip silently otherwise.

```bash
# Detect
[ -f .claude/game-context.md ] && echo "GAME PROJECT — dispatch game-designer"
```

```
Agent tool (subagent_type: game-designer, run_in_background: false):
"You are running Step 2.3 (game design) for this session. Read .claude/game-context.md and
specs/handoffs/step-2-<spec-slug>-product-owner.html. Produce the core loop, player verbs,
win/loss conditions, ten fun things, and anti-features. You cannot ask the user questions —
write blocking questions into your handoff's open-questions section per docs/agent-protocol.md §2.
Handoff at:
  specs/handoffs/step-2.3-<spec-slug>-game-designer.html"
```

When the agent returns, verify the handoff exists and the core loop / verbs / ten fun things sections have substantive content. Relay any `data-blocking="true"` open-questions to the user via AskUserQuestion and re-dispatch with the answers (cap 3 rounds, then escalate with a written summary — same protocol as Step 2).

**BLOCKING REQUIREMENT.** When `.claude/game-context.md` exists, the game-designer MUST run before Step 2.5. The application-architect's decomposition reads game-designer's verbs to slice the implementation.

## Step 2.5: Decompose

**Dispatch the application-architect role agent.** This step is run by `agents/application-architect.md` — the independence test, seam scan, and decomposition heuristics live there.

```
Agent tool (subagent_type: application-architect, run_in_background: false):
"You are running Step 2.5 (decomposition) for this design session. Read the product-owner handoff at
specs/handoffs/step-2-<spec-slug>-product-owner.html and produce a decomposition map. Tag every spec
with @layer(api|ui|full-stack|cli|infra) and @trivial where applicable. Produce your handoff at:
  specs/handoffs/step-2.5-<spec-slug>-application-architect.html"
```

When the agent returns, read its handoff. Verify:
- The decomposition table in `findings` lists every spec with `@layer`, `@depends-on`, `@parallel-risk`.
- The `acceptance-criteria` items are machine-checkable (greps, file counts, dependency-cycle check).
- The `data-input-references` meta tag points to the PO handoff.

If the decomposition has issues (cycles, missing tags, unclear seams), dispatch again with the specific concern — do NOT proceed.

**On rule 2 (no codebase investigation during design):** decomposing brownfield work means finding seams in an existing codebase, and that tension is real. The resolution: the application-architect MAY read structural context from `.claude/agent-memory/` (built by `/onboard`) — module layout, layer boundaries, existing feature seams — but MUST NOT read implementation details (function bodies, file-level patterns, line-level conventions). Structure informs where to cut; implementation investigation remains /build's job (Step 3.1), where it produces logged, auditable findings.

### Integration spec (BLOCKING for multi-feature user-facing products)

Decomposition optimizes for **independence** — that is the right instinct for seams, and the wrong instinct for the product. Independent features that no spec ever assembles ship as a launchpad of disconnected demo cards: each one builds, tests, and verifies in isolation, and the running app reaches none of them. This is the SquashBuckler dogfood failure (2026-05-31): ~40 UI features all reached `@status(verified)` and the app shell that mounts them was bolted on afterwards under a separate slug — a rescue, not a plan.

**Rule.** When the decomposition contains **≥2 specs tagged `@layer(ui|full-stack)`**, it MUST include exactly one **integration spec**:

- Tagged `@integration` (and `@layer(ui)` or `@layer(full-stack)`).
- `@depends-on` **every** user-facing feature spec.
- Carries a `## Mount Map` section — a table with one row per UI feature: `| Feature spec | Mounts as (component) | Where (route / region / nav entry) |`. This is the assembly contract: every feature has a declared home in the running product.
- Owns the application's single entry point and primary navigation.

And **every** `@layer(ui|full-stack)` feature spec MUST carry `@mounts-in(<integration-spec-slug>)` (or, for a sub-component another feature mounts, `@mount-skip(mounted by <feature>: reason)`).

A UI feature with no row in the Mount Map and no `@mounts-in` is an **orphan** — a decomposition error, not an acceptable outcome. The `require-feature-mounted.sh` hook blocks `@status(verified)` on orphan UI features during /build; catching it here, at decomposition, is far cheaper.

**Exempt (no integration spec, no skip tag needed):** epics with <2 user-facing specs (single-UI-feature, CLI-only, API-only, library, infra-only). For VS Code-extension-style products where independent commands *are* the product, the extension host IS the integration spec — commands `@mounts-in(extension-shell)`.

**Override (rare — document why this epic has no single assembly owner):** `@integration-skip(<reason>)` on the affected specs.

## Step 2.7: Per-spec Game Design (when applicable)

**Dispatch level-designer, narrative-designer, and systems-designer in PARALLEL** for each spec, when `.claude/game-context.md` exists. These three designers all read the game-designer handoff and produce orthogonal deliverables (space, story, math).

```
# Parallel: include multiple Agent tool calls in a SINGLE message
Agent tool (subagent_type: level-designer): "Step 2.7 for spec <slug>: spatial layout, encounter pacing, difficulty curve. Read the game-designer handoff. Handoff at specs/handoffs/step-2.7-<slug>-level-designer.html"

Agent tool (subagent_type: narrative-designer): "Step 2.7 for spec <slug>: story arc, characters, dialogue, branching, tone. Read the game-designer handoff. Handoff at specs/handoffs/step-2.7-<slug>-narrative-designer.html"

Agent tool (subagent_type: systems-designer): "Step 2.7 for spec <slug>: progression math, economy graph, drop tables, balance, anti-degenerate defenses. Read the game-designer handoff. Handoff at specs/handoffs/step-2.7-<slug>-systems-designer.html"
```

All three read the game-designer handoff ONLY — they run in parallel, so cross-reading each other's in-flight handoffs would be race-dependent. Tensions between their outputs (e.g. "pacing wants combat, narrative wants dialogue") surface via each handoff's `open-questions` and get a single resolution from the orchestrator.

When all three return, read their handoffs. Verify:
- Per-axis sections (topology / story-arc / progression-curves / etc.) are substantive — not placeholder text
- Cross-references resolve (level-designer references game-designer's verbs; narrative-designer references game-designer's core loop)
- `open-questions` from each are surfaced together — common tensions ("pacing wants combat, narrative wants dialogue") get a single resolution

**BLOCKING REQUIREMENT.** When `.claude/game-context.md` exists AND the spec is not `@trivial`, all three must run before Step 2.75 / Step 2.85. The `require-handoff-artifact.sh` hook will block `@status(verified)` later if any are missing.

**Skip when:** Spec is `@trivial`, OR `.claude/game-context.md` is absent (non-game project).

## Step 2.75: Validate Feasibility (when applicable)

For work involving external APIs, third-party libraries, unfamiliar protocols, or technical claims from the user, dispatch `hyperpowers:internet-researcher` to verify:

- **API contracts** — Does the API actually support the operations the user described? What are the real request/response shapes?
- **Library capabilities** — Does the library handle the use case? Are there version constraints or known limitations?
- **Protocol/standard compliance** — Is the approach compatible with the relevant standards (OAuth2, JWT, WebSocket, etc.)?

```
Agent tool (subagent_type: hyperpowers:internet-researcher):
"Verify technical feasibility for [feature description].
Check: [specific claims to validate — API capabilities, library support, etc.]
Report: confirmed capabilities, limitations, and anything that contradicts the current design assumptions."
```

**If research reveals problems:** Surface them as new questions to the user via AskUserQuestion. Do NOT silently adjust the design. Example: "Research shows the Stripe API doesn't support partial refunds on ACH transfers. Should we handle this differently?"

**Skip this step when:** Every entry in the decomposition map is tagged `@trivial`, OR the request is entirely internal to the codebase with no third-party APIs/libraries/protocols. The deterministic signal is `@trivial` — claims of "well-understood" without that tag are not sufficient.

## Step 2.85: UI/UX Design (when applicable)

**Dispatch the uiux-designer role agent — OR game-ui-designer when the spec carries `@surface(game)`.** This step is run by `agents/uiux-designer.md` (base discipline) or `agents/game-ui-designer.md` (game-UI extension — inherits uiux-designer's discipline + adds HUD / diegesis / input affordances / juice / accessibility-at-speed axes).

**Routing decision per spec:**

```bash
# For each UI-bearing spec, check @surface(game)
for spec in $(grep -lE '@layer\((ui|full-stack)\)' specs/*.md); do
    if grep -q '@surface(game)' "$spec"; then
        echo "ROUTE: game-ui-designer  $spec"
    else
        echo "ROUTE: uiux-designer     $spec"
    fi
done
```

For specs routed to **uiux-designer**:

```
Agent tool (subagent_type: uiux-designer, run_in_background: false):
"You are running Step 2.85 (UI/UX design) for the UI-facing specs in this decomposition. Read the
application-architect handoff. For each, ensure PRODUCT.md and DESIGN.md exist, generate mockups
in specs/mockups/, invoke all 5 /impeccable gates per spec, and add ## UI Design sections. Produce
your handoff at:
  specs/handoffs/step-2.85-<spec-slug>-uiux-designer.html"
```

For specs routed to **game-ui-designer**: same dispatch shape, but the agent additionally reads `.claude/game-context.md` and all four game-design handoffs, inherits uiux-designer discipline, and adds the game axes (HUD inventory, diegesis posture, input affordances, juice/feedback, readability at speed, accessibility commitments). Handoff at `specs/handoffs/step-2.85-<slug>-game-ui-designer.html`.

When agents return, verify each UI-facing spec has a mockup at `specs/mockups/<slug>/` (or `.html`) AND a `## UI Design` section listing the gate Skill invocations. `claim-vs-call-audit.sh` catches false claims at `@status(verified)` time; checking now saves a round-trip.

**BLOCKING REQUIREMENT.** If any decomposition entry is `@layer(ui|full-stack)`, exactly one of uiux-designer OR game-ui-designer MUST run for that spec (chosen by `@surface(game)` tag) before Step 3.

**Skip when:** `grep -lE '@layer\((ui|full-stack)\)' specs/*.md` returns no results.

## Step 3: Generate Gherkin Spec Files

After decomposition, feasibility validation, and UI/UX design (if applicable): `mkdir -p specs`, generate `specs/system.md` FIRST for greenfield, then one feature spec per decomposition-map entry (complexity scales per the tiers above), then verify dependency integrity — every `@depends-on(x)` / `@blocks(x)` / `@parallel-risk(x)` references an existing `specs/x.md`, no circular dependencies.

**Spec generation rules:**
- One spec file per feature
- `@status(draft)` on all new specs
- `## Critical User Journeys` section required on all user-facing Standard and Complex specs — lists which end-to-end journeys this feature participates in, the steps within this feature, and the full journey path. Exempt: Simple specs (typo fixes, renames) and non-user-facing work (pure API-only with no UI consumer in this epic, CLI tools, cron jobs, infra).
- `## Interaction Map` section required on all full-stack specs (specs with BOTH API endpoints AND UI elements) — maps every interactive UI element (button, form, toggle, nav) to its API endpoint, HTTP method, and expected result. This table becomes the wiring checklist for /build Steps 3.2.5 and 3.2.6. Exempt: API-only specs, UI-only specs with no backend, Simple specs.
- **Integration spec required for ≥2 user-facing specs** (see Step 2.5 "Integration spec"). Exactly one spec tagged `@integration`, depending on every UI feature, carrying a `## Mount Map`; every UI feature tagged `@mounts-in(<integration-slug>)`. Without it, features ship as disconnected demo cards. Exempt: <2 user-facing specs.
- Technical Context section with API contracts, data structures, integration points (for non-trivial features)
- Scenarios cover happy path, error cases, and edge cases discovered during questioning
- For greenfield: the complete set of specs must be sufficient to rebuild the entire application

## Step 4: Reality Check

**Dispatch the product-owner role agent for the pre-check; the ORCHESTRATOR presents to the user.** The PO agent compares generated specs against the original request, flags scope creep, and traces CUJ coverage across all specs — it cannot present anything to the user itself (`docs/agent-protocol.md` §2).

```
Agent tool (subagent_type: product-owner, run_in_background: false):
"You are running the Step 4 reality check. Read the user's original ask (your Step 2 handoff has the
resolved questions), every spec generated in Step 3, and the application-architect handoff. Verify:
every requirement maps to a scenario; no scope creep; @depends-on/@parallel-risk integrity; UI specs
have mockups; CUJ coverage if multi-spec. You cannot ask the user questions — record your verdict
(PASS or BLOCKED + affected specs), a presentation summary (per-spec scenario counts, dependency
graph, anything the user must weigh in on), and any blocking questions in open-questions, updating
your phase handoff at:
  specs/handoffs/step-2-<spec-slug>-product-owner.html
per docs/agent-protocol.md §2."
```

When the agent returns: relay any `data-blocking="true"` open-questions via AskUserQuestion and re-dispatch with answers (cap 3 rounds). On the agent's PASS, YOU present the specs to the user via AskUserQuestion — spec list, scenario counts, dependency graph, the PO's summary — and BLOCK until the user confirms. On user confirmation, mark all specs `@status(approved)` and proceed to architecture documentation. On BLOCKED (from agent or user), regenerate affected specs and re-dispatch.

**Orchestrator-level gates that don't require dispatch:**
- For UI-facing specs: `ls specs/mockups/` must show a mockup per spec. If missing, STOP — return to Step 2.85.
- For greenfield: confirm `specs/system.md` exists.

**BLOCK until user confirms.** Do not proceed to architecture documentation with unapproved specs.

## Step 4.5: Architecture Documentation

**REQUIRED SUB-SKILL:** Invoke `design-arch` via the Skill tool. It generates architecture documentation from the approved specs and produces:
- `specs/arch.md` — architecture document (component map, data flow, design decisions)
- `specs/diagrams/*.drawio` — architecture diagrams (system, data flow, deployment)
- `specs/overview.html` — visual design overview page for non-technical stakeholders

The `/design-arch` skill handles its own gate checks and user confirmation. When it returns, architecture documentation is confirmed and complete.

**Skip when ALL three are true:** (1) decomposition has exactly one spec entry, (2) that entry has no `@depends-on(...)` or `@blocks(...)`, AND (3) that entry is tagged `@trivial`. Deterministic: count spec files in `specs/` (excluding `system.md`), grep for `@depends-on\|@blocks`, grep for `@trivial`. If any condition is false, run `/design-arch`.

## Step 5: Beads Setup

After specs are approved:

### Pre-check: Beads initialized?
```bash
ls .beads/ 2>/dev/null
```
- If `.beads/` exists: proceed
- If not: run `bd init` first
- If `bd init` fails (not a git repo): prompt user to initialize git

### Create epic + Tests gate

```bash
# 1. Create epic referencing spec files
bd create "Epic: [Brief description]" \
  --type epic \
  --priority 2 \
  --description "[WHY this epic exists]" \
  --design "Specs:
- specs/<feature-1>.md
- specs/<feature-2>.md (if multiple)"

# 2. Create mandatory Tests gate task
# NOTE: Per-spec implementation tasks are NOT created here.
# /build creates them AFTER codebase investigation, when it has real context
# (file paths, patterns to follow, specific changes needed).
bd create "Tests: [Epic name]" --type feature --priority 2 \
  --description "Verification gate - ensures all tests pass and specs are covered" \
  --design "## Goal
VERIFICATION GATE - prevents epic auto-close.
NEVER close during implementation. Only close after ALL verification passes.

## Success Criteria
- [ ] Tests exist for all spec scenarios
- [ ] All tests pass
- [ ] No tautological tests
- [ ] Spec coverage check passes
- [ ] Code review agent found no CRITICAL issues"
bd dep add [tests-id] [epic-id] --type parent-child
```

**Why no per-spec tasks here:** Implementation tasks benefit from codebase investigation context that only /build has. Creating tasks before investigation means guessing at file paths, patterns, and implementation details. /build creates informed tasks after it understands the codebase.

## Step 6: Reconcile with Brainstorming Task Docs

If the brainstorming skill created `plans/active/<slug>/` task docs, update them so they reference the specs instead of duplicating them:

1. **plan.md acceptance checks** reference specs ("All scenarios in specs/<slug>.md implemented and passing; spec coverage check passes") plus non-behavioral criteria only.
2. **context.md** lists spec files under Key Files (`specs/<slug>.md` — READ before each task; `specs/system.md` if it exists).
3. **tasks.md** items name the spec scenarios they address (e.g. "Implement Rule: Valid coordinates return nearby results (specs/nearby-breweries.md — 2 scenarios)").

This ensures the /build skill (which uses executing-plans) naturally reads spec context.

## Exit State

/design is complete when:
- All spec files exist in `specs/` with `@status(approved)`
- `/design-ui` completed: mockups exist for all UI-facing specs (in `specs/mockups/`), PRODUCT.md + DESIGN.md exist — or skipped (no UI-facing specs)
- Architecture documentation generated and confirmed (`specs/arch.md`, `specs/diagrams/`, `specs/overview.html`) — or skipped for trivial changes
- Beads epic created referencing spec files
- Tests gate task created in epic
- User has confirmed specs via reality check
- User has confirmed architecture documentation
- Task docs (if brainstorming was used) reference specs

**Tell the user:** "Design complete. Specs approved. Architecture documented. Run `/build` when ready to implement. Open `specs/overview.html` in your browser for a visual summary you can share with stakeholders."

</the_process>

<examples>

<example>
<scenario>User asks to fix a typo</scenario>

<why_it_fails>
Without /design, the natural path is: open the file, fix the typo, commit. No spec, no beads epic, no Tests gate task. That looks fine for a one-line change, but it breaks the invariant the rest of the workflow depends on: every change goes through specs/. /build won't pick it up because there's no `@status(approved)` file. Retrospectives can't analyze the change. And it sets a precedent — once one change skips the spec because "it's trivial," the bar drops.
</why_it_fails>

<correction>
**Step 2:** No questions needed — request is fully specified.

**Step 2.5:** Single behavior, no seams — decomposition map: one entry (fix-readme-typo, no dependencies). Seam analysis skipped.

**Step 3:** Generate `specs/fix-readme-typo.md` — `@status(draft)`, `@layer(infra)`, `@trivial`, one Feature line, one Scenario ("all instances of 'recieve' are replaced; no other text modified"). The `@trivial` tag set HERE is what lets /build skip reviewer steps later.

**Step 4:** Reality check — present to user, confirm.

**Step 5:** Create beads epic + Tests gate. (/build creates implementation tasks after investigation.)

**Exit:** "Design complete. Run `/build` when ready."
</correction>
</example>

<example>
<scenario>User asks to add a new API endpoint</scenario>

<why_it_fails>
Without /design, the agent reads the existing routes, picks "reasonable defaults" for units, max radius, and auth, and writes the spec inline in a beads description. Three defaults made silently. Each one is a contract decision the user could have made differently — radius in km vs miles, public vs auth-required, max 50 vs 100 — and now the user finds out about them in code review. Defaults are where bugs hide. The spec exists to surface them as questions instead of swallowing them as assumptions.
</why_it_fails>

<correction>
**Step 2:** The PO agent's handoff returns three blocking questions; the orchestrator relays via AskUserQuestion:
- "What units should radius use? Miles, kilometers, or configurable?"
- "Should there be a max radius? What's a reasonable upper bound?"
- "Should the endpoint require authentication or be public?"

**Step 2.5:** One cohesive behavior — decomposition map: one entry (nearby-breweries-endpoint, no dependencies).

**Step 3:** Generate `specs/nearby-breweries-endpoint.md` with full Standard structure (As/I want/So that, Technical Context, Rules, Scenarios for happy path + error cases).

**Step 4:** Reality check:
- Agent pre-check: All requirements covered, no scope creep
- User confirmation: "Here's the spec — 4 scenarios covering success, empty results, missing params, invalid radius. Does this capture what you asked for?"

**Step 5:** Create beads epic + Tests gate. (/build creates implementation tasks after investigation with real codebase context.)

**Exit:** "Design complete. Run `/build` when ready."
</correction>
</example>

<example>
<scenario>User asks to add OAuth to a greenfield app</scenario>

<why_it_fails>
Without /design's greenfield protocol, the agent asks one round of questions ("Google or GitHub? session or JWT?") and generates a single spec. No system.md, no decomposition into registration vs. authentication, no CUJ trace. /build then implements the auth flow but registration is a half-thought-through prerequisite, payment-processing has no upstream contract to depend on, and there's no document anyone can read to rebuild the app from scratch. Greenfield is where one-round shortcuts compound fastest — three rounds and a system spec are not optional, they're the difference between an app and a pile of partially-connected features.
</why_it_fails>

<correction>
**Step 2:** Multiple rounds of AskUserQuestion:
- Round 1: Provider (Google? GitHub?), token storage, session handling
- Round 2: User model fields, role-based access, refresh token strategy

**Step 2.5:** Three behaviors identified via independence test — registration and authentication fail the test (auth needs a registered user), so auth `@depends-on(user-registration)`. System spec is a shared foundation.
Decomposition map:
1. system (no dependencies)
2. user-registration (@depends-on: system)
3. user-authentication (@depends-on: user-registration)

**Step 3:** Generate `specs/system.md` (stack, User data model, API conventions) + `specs/user-registration.md` (@blocks user-authentication) + `specs/user-authentication.md` (@depends-on user-registration, @blocks payment-processing), each with full Technical Context, Rules, and Scenario Outlines.

**Step 4:** PO pre-check PASS (system spec covers full rebuild, graph valid); orchestrator presents: "3 specs, auth depends on registration and blocks payment, 12 scenarios — does this capture what you asked for?" User confirms.

**Steps 5-6:** Beads epic + Tests gate; reconcile brainstorming task docs. **Exit:** "Design complete. 3 specs approved. Run `/build` when ready."
</correction>
</example>

</examples>

<incident_logging>
## Workflow Incident Logging

When the user corrects your approach during /design, the `detect-correction.sh` hook will fire and prompt you to offer incident logging. Follow its instructions:

1. **Address the correction first** — fix whatever you did wrong
2. **Ask to log** — use AskUserQuestion: "Should I log this as a workflow incident for the next retro?"
3. **If confirmed**, log a structured comment on the active epic (or `workflow-incidents` issue):

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

Categories and the no-active-epic fallback are documented in build SKILL.md's incident-logging section — the same protocol applies here.
</incident_logging>

<critical_rules>
## Rules That Have No Exceptions

1. **All questions via AskUserQuestion** -> Blocks execution until user responds. Text questions do not block. The orchestrator asks; dispatched agents return question lists (`docs/agent-protocol.md` §2).
2. **No codebase investigation during design** -> Codebase investigation is /build's job. Internet research (hyperpowers:internet-researcher) IS allowed — it informs questions and validates feasibility, but never replaces asking the user. Exception scoped in Step 2.5: the application-architect may read STRUCTURE from `.claude/agent-memory/` to find seams, never implementation details.
3. **No proceeding without answers** -> "Making reasonable defaults for ambiguous parts" is not acceptable.
4. **Every design produces spec files** -> All work gets specs in `specs/`. Simple work gets simple specs (Feature + 1-3 Scenarios; 5-10 lines). Complex work gets multiple specs with dependencies. Specs capture intent BEFORE code.
5. **Reality check before approval** -> Agent pre-checks for gaps, then user confirms. Both parts required.
6. **Specs are the source of truth** -> Beads epic descriptions reference spec files, not inline requirements.
7. **Every epic has a Tests gate task** -> Prevents beads auto-close before verification.
8. **Greenfield requires system spec** -> `specs/system.md` is mandatory for greenfield projects.
9. **Dependency integrity** -> Every `@depends-on(x)` and `@blocks(x)` must reference an existing spec file. No circular dependencies.
10. **Dispatch uiux-designer (or game-ui-designer) for UI-facing work** -> If ANY decomposition map entry is UI-facing, the Step 2.85 agent dispatch MUST run before spec generation — the uiux-designer agent invokes `/design-ui` (PRODUCT.md, DESIGN.md, craft pipeline, mockups, quality gates). Not optional, not deferrable. A UI-facing spec without a mockup CANNOT be approved.
11. **Architecture documentation after approval** -> After specs are approved (for non-trivial work), invoke `/design-arch` to generate architecture docs. Do not proceed to Beads Setup until `/design-arch` completes and user confirms.
12. **CUJs required on user-facing Standard and Complex specs** -> Every user-facing non-trivial spec must have a `## Critical User Journeys` section listing which end-to-end journeys the feature participates in. This is how /design systematically catches missing specs and how /build generates Playwright e2e tests (Step 4.1).
13. **CUJ coverage analysis for multi-spec user-facing designs** -> After generating specs (when there are multiple user-facing specs), trace every CUJ end-to-end across all specs, in writing — mental tracing misses navigation, loading states, and error recovery. Any journey step without a covering spec is a MISSING SPEC. Generate it before proceeding to reality check.
14. **Greenfield requires minimum 3 questioning rounds** -> A greenfield project description is a vision, not a specification. Scope & Architecture → Feature Deep-Dive → Integration & Flows. All completeness gate categories must be covered before generating specs.
15. **Drill down relentlessly** -> Every answer spawns follow-up questions. "Standard auth" is not an answer. "React Native" is not an answer. Push until you have enough detail to write code. Vague answers produce vague specs that produce broken implementations.
16. **Integration spec required for multi-feature user-facing products** -> When decomposition has ≥2 `@layer(ui|full-stack)` specs, exactly one spec tagged `@integration` must own assembly: it depends-on every UI feature, carries a `## Mount Map`, and owns the app entry + nav. Every UI feature is tagged `@mounts-in(<integration-slug>)`. CUJ coverage (rule 13) finds missing *journey-step* specs; the integration spec guarantees the found specs are actually *assembled into one reachable product*. Plan it at decomposition, not as a rescue (see `docs/incidents.md#squashbuckler-2026-05-31`).

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "I'll make reasonable defaults for the ambiguous parts" -> Ambiguity is exactly what questions resolve (rule 3).
- "I'll investigate the codebase while waiting for answers" -> Codebase investigation is /build's job; it leads to skipping user answers entirely (rule 2). Internet research is fine — it makes questions better.
- "A spec is overkill for this change" -> Simple specs are 5-10 lines (rule 4). If that's too much, the change is probably a no-op.
- "I'll write the spec after I implement it" -> Specs capture intent BEFORE code (rule 4); afterwards they're just documentation.
- "I'll do the UI design later / during build" -> Mockups capture intent BEFORE code (rule 10). The trainr project shipped 15 specs with no mockups — every screen had to be redesigned (see `docs/incidents.md#trainr`).
- "One round of questions is sufficient" -> For a typo fix, yes. For greenfield, round 2 catches data-model gaps and round 3 catches integration gaps — all three required (rule 14).
- "I can infer the answer from context" -> "Standard auth" could mean email/password, social login, SSO, MFA, magic links, or passkeys — each is a radically different spec (rule 15). Ask.
- "CUJ analysis is overkill for this project" -> FitConnect launched with buttons that did nothing because no one traced the full journey (rule 13; see `docs/incidents.md#fitconnect`).
- "Each feature is independent, so no integration spec is needed" -> Independence is a seam property, not a product property. ≥2 UI features ⇒ one `@integration` spec with a Mount Map, or you ship demo cards (rule 16; see `docs/incidents.md#squashbuckler-2026-05-31`).
- "We have a system.md feature map, that covers assembly" -> system.md *describes*; the Mount Map is *checked* — by a hook at `@status(verified)` and by e2e at epic close (rule 16). Prose is not a gate.
</critical_rules>

<verification_checklist>
Before claiming /design is complete:

- [ ] All critical questions asked via AskUserQuestion (orchestrator-relayed from the PO handoff) and answered; vague answers got follow-ups, not assumptions
- [ ] Greenfield: 3+ questioning rounds (Scope → Deep-Dive → Integration) and completeness gate passed — or N/A
- [ ] No codebase investigation agents dispatched (internet research allowed; architect structure-reads from agent-memory allowed per rule 2)
- [ ] Feasibility validated via internet-researcher — or N/A (internal-only change)
- [ ] Decomposition map produced before spec generation (independence test + seam scan applied)
- [ ] Step 2.85 agent dispatch completed for all UI-facing specs: mockups exist in `specs/mockups/`, quality gates passed — or N/A (no UI-facing entries)
- [ ] Spec files generated in `specs/`: `## Critical User Journeys` on user-facing Standard/Complex specs, `## Interaction Map` on full-stack specs, system spec for greenfield — or documented exemptions
- [ ] Dependency integrity verified (all @depends-on/@blocks/@parallel-risk reference existing specs; no cycles)
- [ ] CUJ coverage traced in writing: every journey step has a covering spec — or N/A (single-spec / non-user-facing)
- [ ] Integration spec present for ≥2 user-facing specs (exactly one `@integration` + `## Mount Map`; every UI feature `@mounts-in(...)`) — or N/A / `@integration-skip(reason)`
- [ ] Reality check passed: PO pre-check verdict PASS AND user confirmed via AskUserQuestion; all specs `@status(approved)`
- [ ] `/design-arch` completed (arch.md + diagrams + overview.html confirmed by user) — or skipped (trivial single-spec change)
- [ ] Beads epic (referencing spec files) + mandatory Tests gate task created; brainstorming task docs reconciled (if used)

**Cannot check all boxes? Do not claim design is complete.**
</verification_checklist>

<integration>
**This skill calls:**

| Skill / Tool | When |
|---|---|
| AskUserQuestion | Socratic questioning + reality check confirmation |
| hyperpowers:internet-researcher | During questioning (inform better questions) + feasibility validation (Step 2.75) |
| uiux-designer / game-ui-designer agent (invokes `/design-ui`) | UI/UX design — PRODUCT.md, DESIGN.md, craft pipeline, mockups, quality gates (Step 2.85) |
| /design-arch | Architecture documentation — arch.md, draw.io diagrams, overview.html (Step 4.5) |
| hyperpowers:brainstorming | For complex work requiring approach comparison |
| hyperpowers:sre-task-refinement | On non-trivial implementation tasks |

**This skill produces (consumed by /build):**
- `specs/*.md` files with `@status(approved)`
- `specs/mockups/` — component mockups for UI-facing specs (via the uiux-designer dispatch)
- `PRODUCT.md` + `DESIGN.md` — design system files (via the uiux-designer dispatch)
- Architecture docs via `/design-arch`: `specs/arch.md`, `specs/diagrams/*.drawio`, `specs/overview.html`
- Beads epic with tasks referencing specs
- Task docs with spec references (if brainstorming used)

**This skill is triggered by:**
- User typing `/design`
- Any new work request that involves code changes
</integration>

<edge_cases>

## Non-git directory
Beads requires git. If not in a git repo:
1. Ask user: "This directory isn't a git repository. Should I initialize one?"
2. If yes: `git init`, then `bd init`
3. If no: create specs but skip beads setup. Inform user that /build needs beads.

## No test framework in project
Note in the spec's Technical Context that a test framework needs to be set up. /build handles this during implementation.

## Beads not initialized
If git exists but beads doesn't:
1. Run `bd init`
2. If fails: create specs but skip beads. Inform user.

## User wants to skip design
REFUSE. Design is non-negotiable. Explain: "Specs are required for /build to work. Even simple changes get simple specs (5-10 lines)."

## Existing specs in project
Read existing specs to understand context and dependencies. New specs should integrate with the existing dependency graph via `@depends-on`/`@blocks` tags.

## Decomposing an existing spec

When a user asks to split a too-large spec (often discovered during /build):

1. Read the existing spec; apply the independence test + seam types to find split points.
2. Generate one replacement spec per independent piece with correct `@depends-on`/`@parallel-risk` tags.
3. Dependencies: if the original had `@blocks(X)` or was a `@depends-on` target, ask the user via AskUserQuestion which replacement is the real dependency, then update each dependent spec's tag to the correct replacement slug.
4. Status: `approved` original → all replacements `approved`; `implemented` original → completed behaviors `implemented`, incomplete `approved`. Confirm status assignments via AskUserQuestion (mandatory for partially-implemented specs) and block until confirmed.
5. Beads: close the original task, create tasks per replacement, preserve the Tests gate (never duplicate it).
6. Remove the original spec file — the replacements fully supersede it.

**No full Socratic re-questioning needed.** The design was already confirmed — this is a structural refactor of the spec, not a re-design.

</edge_cases>
