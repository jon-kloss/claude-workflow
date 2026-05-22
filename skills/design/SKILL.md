---
name: design
description: Use when starting new work - Socratic questioning via AskUserQuestion, Gherkin spec generation in specs/, reality check with user confirmation, beads task creation. Produces approved specs that /build consumes.
---

<skill_overview>
Design skill that shapes work through Socratic questioning, generates Gherkin spec files as the source of truth for design intent, performs a reality check against the original request, and sets up beads for sub-task tracking. Produces `@status(approved)` specs in `specs/` that the `/build` skill consumes.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: Socratic questioning via AskUserQuestion is mandatory. No proceeding without user answers.
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

1. All questions asked via AskUserQuestion tool (blocks execution)
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
- `@depends-on(feature-slug)` — this feature requires another feature to be implemented first
- `@blocks(feature-slug)` — another feature depends on this one
- `@parallel-risk(feature-slug)` — this spec modifies the same files as another independent spec. Both specs remain parallel (no `@depends-on` added). /build warns about potential merge conflicts and builds the smaller spec first.
- Custom domain tags: `@auth`, `@api`, `@ui`, `@security`, etc. — categorization

### Greenfield Rebuild Principle (summary)

For greenfield projects, the complete set of specs in `specs/` must be **sufficient to rebuild the entire application from scratch**. Achieved via two spec types:

1. **System spec** (`specs/system.md`) — Required for greenfield. Purpose, tech stack, data model, feature map, API conventions.
2. **Feature specs** (`specs/<feature-slug>.md`) — One per feature, linked via `@depends-on`/`@blocks`.

### Spec complexity tiers (summary)

- **Simple** — Feature + 1-3 Scenarios. No Rules, no Background. (Typo fix, rename, config.)
- **Standard** — Feature + As/I want/So that + Critical User Journeys + Technical Context + Rules + Background + Scenarios. (New endpoint, new component.)
- **Complex** — Multiple spec files with `@depends-on`/`@blocks`. Full Gherkin structure including Scenario Outlines. (New feature, integration, architectural change.)

Full templates and worked examples for each tier are in [resources/gherkin-spec-reference.md](resources/gherkin-spec-reference.md). Load it before writing a spec you haven't written this session.

### Lifecycle (summary)

`@status(draft)` → `@status(approved)` (after reality check) → `@status(implemented)` (during /build) → `@status(verified)` (after /build verification).

### Decomposition (summary)

Independence test: a piece of work is independent if (1) you can write tests for it without the other existing, (2) it has its own inputs/outputs, (3) removing it doesn't break the other's tests. If all three hold → separate specs. Otherwise → scenarios within one spec.

Look for **seams** when splitting: data boundaries, lifecycle boundaries, consumer boundaries, layer boundaries, rule boundaries. Full seam types table is in [resources/gherkin-spec-reference.md](resources/gherkin-spec-reference.md).

Parallel risk: when two independent specs will modify the same file, tag both with `@parallel-risk(other-slug)`. They remain parallel — no `@depends-on` added.
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

## Step 1: Announce

"I'm using the /design skill to shape this work through Socratic questioning and Gherkin spec generation."

## Step 2: Socratic Questioning

Ask focused questions using AskUserQuestion until you can fully define the work. The number of questions scales naturally with complexity — a typo fix needs 0-1 questions, a new feature needs 3-5+.

**BLOCKING REQUIREMENT: All questions MUST use AskUserQuestion tool.**

Enforcement rules:
1. **Use AskUserQuestion tool** — Do NOT print questions as text. AskUserQuestion blocks execution until the user responds. Text questions do not block and lead to proceeding without answers.
2. **Do NOT dispatch codebase investigation agents** — Codebase investigation is /build's job. Dispatching codebase-investigator during design leads to the agent rationalizing that it has "enough context" to skip the user's answers.
3. **Internet research IS allowed** — Dispatch `hyperpowers:internet-researcher` to research the user's domain, tech choices, API capabilities, and library constraints. This makes questions sharper. If research reveals a problem or constraint, surface it as a new question to the user — do NOT silently assume or skip asking.
4. **Do NOT proceed until answers are received** — If you asked a question, you must receive and incorporate the answer before moving forward. "Making reasonable defaults for ambiguous parts" is not acceptable.
5. **Multiple rounds are expected for complex work** — If the work involves new features, integrations, or architectural decisions, one round of questions is probably insufficient.
6. **Research informs and validates — it never replaces asking** — If you learn the project uses passport.js, that informs what to ask, it doesn't eliminate the need to ask. If research shows an API doesn't support webhooks, that becomes a question ("The Stripe API doesn't support X — how should we handle this?"), not a silent design decision.
7. **Drill down relentlessly** — Every answer the user gives should spawn follow-up questions that dig deeper. "React Native" → "Expo or bare RN? What minimum OS versions? Which navigation library?" Surface-level answers produce surface-level specs. Push until you have enough detail to write code.
8. **Never accept vague answers** — If the user says "standard auth" or "normal CRUD," that is NOT an answer. Push: "Standard auth meaning email/password only? Social login? MFA? Password reset flow? Session or token-based?" Vagueness is where bugs hide.

Questions to stabilize:
- **What** — What is being built/changed/fixed?
- **Why** — What problem does this solve?
- **Where** — Which parts of the system are affected?
- **User Journeys** — What end-to-end journeys does this feature participate in? What does the user do before arriving here? What do they do after? (e.g., "User logs in → navigates to workouts → starts workout → logs sets → completes → views history") (skip for Simple specs and non-user-facing work)
- **Constraints** — What must NOT change? What are the boundaries?
- **Dependencies** — Does this depend on other features? Do other features depend on this?
- **Edge cases** — What happens with empty/invalid/unexpected input?

For simple changes (typo, rename, config), 0-1 questions may suffice — the request itself may be fully specified. Don't ask questions for the sake of asking.

### Greenfield Questioning Protocol

**For greenfield projects (no existing codebase, building from scratch), questioning intensity increases dramatically.** A greenfield project cannot be fully spec'd from a single round of questions. The user's initial description is a starting point, not a specification.

**Minimum 3 rounds of questions are required.** Each round drills deeper based on the previous answers.

**Round 1 — Scope & Architecture** (broad strokes):
- Platform, tech stack, deployment target
- User roles and access model
- Core feature list (what's MVP vs. later?)
- Data ownership and privacy model
- Third-party integrations

**Round 2 — Feature Deep-Dive** (for each major feature area from Round 1):
- Data model: What fields? What types? What's required vs. optional?
- User interactions: What does the user click/tap/type? What do they see in response?
- Permissions: Who can see/edit/delete what? What about shared data?
- Error states: What happens when it fails? What does the user see?
- Edge cases: Empty states, max limits, concurrent access

**Round 3 — Integration & Flows** (connecting the pieces):
- CUJs: Walk through every major user journey end-to-end, step by step
- Cross-feature dependencies: How does feature A hand off to feature B?
- Notification model: When does the app reach out to the user?
- Onboarding: What does a brand-new user experience?
- Settings & configuration: What can users control?

**Completeness Gate:** Before proceeding to decomposition, verify you have answers covering ALL of these categories. If any category has gaps, ask another round. Do NOT proceed with assumptions.

| Category | Covered? |
|----------|----------|
| Platform & tech stack | |
| User roles & permissions | |
| Data model per feature | |
| API contracts (endpoints, request/response shapes) | |
| User journeys (end-to-end flows) | |
| Error handling & edge cases | |
| Third-party integrations | |
| Onboarding & first-run experience | |
| Notification model | |
| Settings & user preferences | |
| Monetization / billing (if applicable) | |
| Offline behavior (if applicable) | |

## Step 2.5: Decompose

Before generating specs, apply the decomposition heuristics (see Decomposition Heuristics in gherkin_spec_reference) to identify how the work should be split.

**Inputs:** Answers from Socratic questioning.
**Outputs:** A decomposition map — list of specs to generate with their `@depends-on` and `@parallel-risk` relationships.

### Process

1. **Apply the independence test** to the work: can each piece be tested without the others existing? Does each have its own inputs/outputs? Would removing one break the other's tests?
2. **Scan for seams** — look for data boundaries, lifecycle boundaries, consumer boundaries, layer boundaries, and rule boundaries (see Seam Types table).
3. **Build the decomposition map** — list each spec to generate, with:
   - Feature name and slug
   - `@depends-on` relationships (pieces that fail the independence test)
   - `@parallel-risk` relationships (independent pieces that modify the same file)
4. **Skip for trivially single-behavior work** — typo fixes, renames, config changes. If the request maps to one cohesive behavior with no seams, the decomposition map is one entry. No seam analysis needed.

### Example Decomposition Maps

**Single behavior (no decomposition):**
```
Decomposition map:
1. fix-readme-typo (no dependencies)
```

**Two independent behaviors:**
```
Decomposition map:
1. cli-export-command (no dependencies)
2. api-export-endpoint (no dependencies, @parallel-risk: cli-export-command — both modify exports.ts)
```

**Behaviors with shared dependency:**
```
Decomposition map:
1. user-data-model (no dependencies)
2. user-registration (@depends-on: user-data-model)
3. user-authentication (@depends-on: user-data-model, @parallel-risk: user-registration — both modify user-routes.ts)
```

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

**Skip this step for:** Work that doesn't involve external dependencies, well-understood internal changes, typo fixes, config changes.

## Step 2.85: UI/UX Design (when applicable)

**REQUIRED SUB-SKILL:** Invoke `design-ui` via the Skill tool. It handles the full UI/UX design pipeline and produces:
- `PRODUCT.md` + `DESIGN.md` (if missing — via `/impeccable teach`)
- Component mockups in `specs/mockups/` for all UI-facing specs
- `## UI Design` sections ready to incorporate into specs
- Quality-checked designs (critique + detect + enhancement)

### When to trigger

Any decomposition map entry that involves:
- New pages, views, or screens
- New UI components or widgets
- Significant visual changes to existing interfaces
- User-facing interactions (forms, dashboards, data visualization)

**BLOCKING REQUIREMENT**: If ANY entry in the decomposition map is UI-facing, `/design-ui` MUST be invoked before proceeding to Step 3 (spec generation). A UI-facing spec without a mockup CANNOT be approved.

The `/design-ui` skill handles its own gate checks, batching strategy, quality gates, and user confirmation. When it returns, all UI-facing specs have mockups and UI Design content.

**Skip for:** Decomposition maps with zero UI-facing entries (backend-only, CLI, API-only, infra).

## Step 3: Generate Gherkin Spec Files

After decomposition, feasibility validation, and UI/UX design (if applicable), generate one spec file per entry in the decomposition map:

```bash
# 1. Ensure specs/ directory exists
mkdir -p specs

# 2. For greenfield projects: ALWAYS generate specs/system.md first
# System spec: purpose, tech stack, data model, feature map, API overview

# 3. Generate feature spec(s) from questioning output
# Complexity scales naturally:
#   - Simple change: Feature + 1-3 Scenarios
#   - Standard feature: Feature + As/I want/So that + Technical Context + Rules + Scenarios
#   - Complex/multi-feature: Multiple spec files with @depends-on/@blocks/@parallel-risk

# 4. For multi-spec designs, verify dependency integrity
# Every @depends-on(x) must have a corresponding specs/x.md
# Every @blocks(x) must have a corresponding specs/x.md
# Every @parallel-risk(x) must reference another existing spec
# No circular dependencies
```

**Spec generation rules:**
- One spec file per feature
- `@status(draft)` on all new specs
- `## Critical User Journeys` section required on all user-facing Standard and Complex specs — lists which end-to-end journeys this feature participates in, the steps within this feature, and the full journey path. Exempt: Simple specs (typo fixes, renames) and non-user-facing work (pure API-only with no UI consumer in this epic, CLI tools, cron jobs, infra).
- `## Interaction Map` section required on all full-stack specs (specs with BOTH API endpoints AND UI elements) — maps every interactive UI element (button, form, toggle, nav) to its API endpoint, HTTP method, and expected result. This table becomes the wiring checklist for /build Steps 3.2.5 and 3.2.6. Exempt: API-only specs, UI-only specs with no backend, Simple specs.
- Technical Context section with API contracts, data structures, integration points (for non-trivial features)
- Scenarios cover happy path, error cases, and edge cases discovered during questioning
- For greenfield: the complete set of specs must be sufficient to rebuild the entire application

## Step 4: Reality Check

Two-part verification that specs match the original request:

### Part 1: Agent Pre-Check

Mentally compare the generated specs against the user's original request:
- Does every requirement from the original ask have at least one spec scenario?
- Are there specs that address things the user didn't ask for? (scope creep)
- Are the `@depends-on` relationships correct?
- Are `@parallel-risk` tags consistent? (mutual references, no phantom slugs)
- For greenfield: does the system spec + feature specs cover the entire application?
- **For UI-facing specs**: does a component mockup exist for each one? Run `ls specs/mockups/` to verify. If any UI-facing spec is missing its mockup, STOP — go back to Step 2.85C and generate it before continuing.

### Part 1.5: CUJ Coverage Analysis (MANDATORY for multi-spec designs)

Trace every Critical User Journey across ALL specs to find gaps. This is the systematic tool for catching missing specs that logical reasoning misses.

**Process:**

1. **Collect CUJs** — Read the `## Critical User Journeys` section from every spec. For each CUJ, combine the "Full Journey" column with the spec slug to build a master CUJ table:

```
| CUJ | Steps in This Feature | Specs Covering Each Step |
|-----|----------------------|--------------------------|
| New user onboarding | Landing → Register → Verify → Login → Role select → Dashboard | auth.md, user-profiles.md, ??? (dashboard has no spec!) |
| Log a workout | Open app → Navigate → Start workout → Log sets → Complete → History | auth.md, workout-tracking.md (navigation has no spec!) |
```

2. **Trace each journey end-to-end** — For every step in every CUJ, verify:
   - A spec exists that covers this step
   - The spec has scenarios for the user action at this step
   - The spec's Technical Context includes the API endpoint or navigation target needed

3. **Flag gaps** — Any CUJ step with no covering spec is a MISSING SPEC. Present these gaps to the user:
   ```
   "CUJ gap analysis found missing coverage:
   
   Journey: 'Log a workout'
   Missing: No spec covers navigation from dashboard to workout screen
   Missing: No spec covers the workout selection screen (user picks which workout to start)
   
   Journey: 'Trainer reviews client'
   Missing: No spec covers the client detail view (trainer drills into one client)"
   ```

4. **Generate missing specs** — For each gap, generate a new spec (with its own `## Critical User Journeys` section per the spec generation rules) and re-run the CUJ trace. Repeat until all journeys are fully covered.

**Skip for:** Single-spec designs, non-user-facing work (CLI tools, API-only, infra).

### Part 2: User Confirmation

Present the specs to the user via AskUserQuestion:

```
"Here are the Gherkin specs I generated for your request:

[List each spec file with a 1-line summary]
- specs/feature-a.md — [summary] (X scenarios)
- specs/feature-b.md — [summary] (Y scenarios, depends on feature-a)

[Dependency graph showing build order and parallel lanes]
Build order:
  feature-a          (no dependencies)
  feature-b          (depends on: feature-a)
  feature-c          (no dependencies) ▐ parallel with feature-a
  ⚠ feature-a and feature-c: @parallel-risk — both modify server.ts

[Note any gaps or assumptions identified in Part 1]

Do these specs capture what you asked for? You can also request re-decomposition
('these two should be one spec' or 'this should be split further')."
```

Options:
- "Yes, approve these specs" → Update all specs to `@status(approved)`, proceed to beads setup
- "No, needs changes" → Ask clarifying questions about what's wrong, regenerate affected specs, re-check
- User provides specific feedback → Incorporate, regenerate, re-check

**BLOCK until user confirms.** Do not proceed to architecture documentation with unapproved specs.

## Step 4.5: Architecture Documentation

**REQUIRED SUB-SKILL:** Invoke `design-arch` via the Skill tool. It generates architecture documentation from the approved specs and produces:
- `specs/arch.md` — architecture document (component map, data flow, design decisions)
- `specs/diagrams/*.drawio` — architecture diagrams (system, data flow, deployment)
- `specs/overview.html` — visual design overview page for non-technical stakeholders

The `/design-arch` skill handles its own gate checks and user confirmation. When it returns, architecture documentation is confirmed and complete.

**Skip for:** Trivial changes (typo fixes, renames, config changes) where there is no meaningful architecture to document. If the decomposition map has only one simple-spec entry with no dependencies, skip this step.

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

If the brainstorming skill created `plans/active/<slug>/` task docs, update them so they reference the specs:

1. **plan.md acceptance checks** should reference specs rather than duplicating behavioral criteria:
   ```markdown
   ## Acceptance Checks
   - [ ] All scenarios in specs/<feature-slug>.md implemented and passing
   - [ ] Spec coverage check passes (every scenario has code + test)
   - [ ] [Non-behavioral criteria only]
   ```

2. **context.md** should list spec files as Key Files:
   ```markdown
   ## Key Files
   - `specs/<feature-slug>.md` — Gherkin spec. READ before each task.
   - `specs/system.md` — (if exists) System conventions, data model, API format.
   ```

3. **tasks.md** items should reference which spec scenarios they address:
   ```markdown
   ## Now
   - [ ] Implement Rule: Valid coordinates return nearby results (specs/nearby-breweries.md — 2 scenarios)
   ```

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
**Step 1:** "I'm using the /design skill."

**Step 2:** No questions needed — request is fully specified.

**Step 2.5:** Single behavior, no seams — decomposition map: one entry (fix-readme-typo, no dependencies). Seam analysis skipped.

**Step 3:** Generate `specs/fix-readme-typo.md`:
```markdown
@status(draft)

# Feature: Fix typo in README

Correct the misspelling 'recieve' to 'receive' across the project.

## Scenario: All instances are corrected

- Given the project contains the misspelling 'recieve'
- When the fix is applied
- Then all instances of 'recieve' are replaced with 'receive'
- And no other text is modified
```

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
**Step 1:** "I'm using the /design skill."

**Step 2:** Ask via AskUserQuestion:
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
**Step 1:** "I'm using the /design skill."

**Step 2:** Multiple rounds of AskUserQuestion:
- Round 1: Provider (Google? GitHub?), token storage, session handling
- Round 2: User model fields, role-based access, refresh token strategy

**Step 2.5:** Three behaviors identified via independence test — registration and authentication fail the test (auth needs a registered user), so auth `@depends-on(user-registration)`. System spec is a shared foundation.
Decomposition map:
1. system (no dependencies)
2. user-registration (@depends-on: system)
3. user-authentication (@depends-on: user-registration)

**Step 3:** Generate multiple specs (one per decomposition map entry):
- `specs/system.md` — tech stack, data model (User entity), API conventions
- `specs/user-registration.md` — @blocks(user-authentication)
- `specs/user-authentication.md` — @depends-on(user-registration), @blocks(payment-processing)
Each with full Technical Context, Rules, Scenario Outlines with Examples tables.

**Step 4:** Reality check:
- Agent pre-check: system spec covers full rebuild, dependency graph is valid
- User confirmation: "Here are 3 specs (system + 2 features). The auth spec depends on registration and blocks payment. 12 total scenarios. Does this capture what you asked for?"

**Step 5:** Create beads epic + Tests gate. (/build creates per-spec tasks after codebase investigation.)

**Step 6:** Reconcile brainstorming task docs with spec references.

**Exit:** "Design complete. 3 specs approved. Run `/build` when ready."
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
</incident_logging>

<critical_rules>
## Rules That Have No Exceptions

1. **All questions via AskUserQuestion** -> Blocks execution until user responds. Text questions do not block.
2. **No codebase investigation during design** -> Codebase investigation is /build's job. Internet research (hyperpowers:internet-researcher) IS allowed — it informs questions and validates feasibility, but never replaces asking the user.
3. **No proceeding without answers** -> "Making reasonable defaults for ambiguous parts" is not acceptable.
4. **Every design produces spec files** -> All work gets specs in `specs/`. Simple work gets simple specs (Feature + 1-3 Scenarios). Complex work gets multiple specs with dependencies.
5. **Reality check before approval** -> Agent pre-checks for gaps, then user confirms. Both parts required.
6. **Specs are the source of truth** -> Beads epic descriptions reference spec files, not inline requirements.
7. **Every epic has a Tests gate task** -> Prevents beads auto-close before verification.
8. **Greenfield requires system spec** -> `specs/system.md` is mandatory for greenfield projects.
9. **Dependency integrity** -> Every `@depends-on(x)` and `@blocks(x)` must reference an existing spec file. No circular dependencies.
10. **Invoke /design-ui for UI-facing work** -> If ANY decomposition map entry is UI-facing, invoke `/design-ui` before generating specs. This is a named skill invocation — not optional, not deferrable. `/design-ui` handles PRODUCT.md, DESIGN.md, craft pipeline, mockups, and quality gates. A UI-facing spec without a mockup CANNOT be approved.
11. **Architecture documentation after approval** -> After specs are approved (for non-trivial work), invoke `/design-arch` to generate architecture docs. Do not proceed to Beads Setup until `/design-arch` completes and user confirms.
14. **CUJs required on user-facing Standard and Complex specs** -> Every user-facing non-trivial spec must have a `## Critical User Journeys` section listing which end-to-end journeys the feature participates in. This is how /design systematically catches missing specs and how /build generates Playwright e2e tests (Step 4.1).
15. **CUJ coverage analysis for multi-spec user-facing designs** -> After generating specs (when there are multiple user-facing specs), trace every CUJ end-to-end across all specs. Any journey step without a covering spec is a MISSING SPEC. Generate it before proceeding to reality check.
16. **Greenfield requires minimum 3 questioning rounds** -> A greenfield project description is a starting point, not a specification. Scope & Architecture → Feature Deep-Dive → Integration & Flows. All completeness gate categories must be covered before generating specs.
17. **Drill down relentlessly** -> Every answer spawns follow-up questions. "Standard auth" is not an answer. "React Native" is not an answer. Push until you have enough detail to write code. Vague answers produce vague specs that produce broken implementations.

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "It's just a typo" -> Simple work gets simple specs. Still gets a spec file.
- "The user is in a hurry" -> Skipping design creates bugs that cost more time later.
- "I know this codebase well enough" -> Your knowledge doesn't replace user intent. Ask questions.
- "I'll investigate the codebase while waiting for answers" -> NO. Codebase investigation is /build's job. This leads to skipping user answers entirely. Internet research is fine — it makes questions better.
- "I'll make reasonable defaults for the ambiguous parts" -> NO. Ambiguity is exactly what questions resolve.
- "The user's description is detailed enough" -> Detailed descriptions still have hidden constraints. Ask critical questions.
- "I have enough context from the codebase" -> Codebase context informs what to ask, it doesn't replace asking.
- "A spec is overkill for this change" -> Simple specs are 5-10 lines. If that's too much, the change is probably a no-op.
- "I'll write the spec after I implement it" -> Specs are design documents, not documentation. They capture intent BEFORE code.
- "The spec scenarios are obvious from the code" -> Specs exist so someone can rebuild the app without reading the code.
- "I don't need a system spec for this project" -> If it's greenfield, `specs/system.md` is required.
- "The spec is getting too long" -> Split into multiple specs with `@depends-on` relationships.
- "The @depends-on tags aren't important" -> The dependency graph IS the build order for /build.
- "The UI is simple enough to skip /design-ui" -> Simple UIs still get mockups. `/design-ui` handles batching efficiently. No UI-facing spec is approved without a mockup.
- "I'll do the UI design later / during build" -> Mockups are design artifacts. They capture intent BEFORE code. The trainr project shipped 15 specs with no mockups — every screen had to be redesigned.
- "I can just describe the UI in the spec" -> Text descriptions do not replace visual mockups. Users cannot review a layout from prose. Invoke the `design-ui` skill.
- "PRODUCT.md/DESIGN.md aren't needed" -> Every project with UI needs them. 5 minutes of `/impeccable teach` prevents hours of bland redesign.
- "I'll invoke /design-ui after generating specs" -> No. `/design-ui` runs BEFORE spec generation (Step 2.85). Its output feeds into the specs. Generating specs first means backfilling design into already-written specs.
- "The architecture is obvious from the specs" -> Specs define behavior. Architecture defines structure. They serve different audiences and purposes.
- "CUJs are obvious from the feature description" -> CUJs trace the FULL journey across multiple specs. A feature description only covers one spec's scope. CUJ analysis is how you find missing specs.
- "We have enough specs, the user described 4 features" -> CUJ tracing might reveal 3 missing specs that connect those features. "Enough specs" is determined by CUJ coverage, not by counting features.
- "CUJ analysis is overkill for this project" -> The FitConnect launch had buttons that did nothing because no one traced the full user journey. 5 minutes of CUJ analysis prevents hours of rework.
- "I'll trace the journeys mentally" -> Write them down. Mental tracing misses non-obvious steps (navigation, loading states, error recovery). The CUJ table is the tool.
- "The user's description is detailed enough for greenfield" -> No greenfield description is ever detailed enough. The user describes the VISION, not the SPECIFICATION. 3+ rounds of drilling converts vision into spec-ready detail.
- "One round of questions is sufficient" -> For a typo fix, yes. For greenfield, one round produces specs with 30% of the needed detail. Round 2 catches data model gaps. Round 3 catches integration gaps. All three are required.
- "I don't want to annoy the user with too many questions" -> Users are far more annoyed by broken implementations than by thorough questioning. 10 minutes of questions prevents 10 hours of rework.
- "I can infer the answer from context" -> You probably can't. "Standard auth" could mean email/password, social login, SSO, MFA, magic links, or passkeys. Each produces a radically different spec. Ask.
- "The user will tell me if I'm missing something" -> Users don't know what they don't know. That's YOUR job. Push on error states, edge cases, permissions, and cross-feature flows — the user won't volunteer these.
- "I have enough to start generating specs" -> Check the completeness gate. If any category has gaps, you don't have enough. Generating specs with gaps means generating wrong specs.
- "The overview page is overkill" -> The overview page takes 5 minutes to generate and saves hours of explanation to stakeholders.
- "I'll do the architecture docs during build" -> Architecture is a design artifact. Documenting it after implementation is documentation, not design.
</critical_rules>

<verification_checklist>
Before claiming /design is complete:

- [ ] All critical questions asked via AskUserQuestion (not text)
- [ ] User answered all critical questions before proceeding
- [ ] Greenfield: minimum 3 questioning rounds completed (Scope → Deep-Dive → Integration) — or N/A (not greenfield)
- [ ] Greenfield: completeness gate passed (all categories covered) — or N/A (not greenfield)
- [ ] Drill-down applied: vague answers received follow-up questions, not assumptions
- [ ] No codebase investigation agents dispatched during design (internet research is allowed)
- [ ] Feasibility validated via internet-researcher (when external APIs/libraries involved) — or skipped for internal-only changes
- [ ] Decomposition heuristics applied (independence test, seam scan) — or skipped for trivially single-behavior work
- [ ] Decomposition map produced before spec generation
- [ ] `/design-ui` invoked and completed for all UI-facing specs (mockups exist, quality gates passed, user confirmed) — or skipped (no UI-facing entries in decomposition map)
- [ ] `## Interaction Map` section present on all full-stack specs (both API endpoints and UI elements) — or skipped (API-only / UI-only / Simple spec)
- [ ] Gherkin spec file(s) generated in `specs/`
- [ ] `## Critical User Journeys` section present on all user-facing Standard/Complex specs — or skipped (Simple spec / non-user-facing)
- [ ] System spec generated for greenfield projects
- [ ] All specs tagged with `@status(approved)` (after reality check)
- [ ] Dependency integrity verified (all @depends-on/@blocks/@parallel-risk reference existing specs)
- [ ] CUJ coverage analysis completed: every journey step has a covering spec — or skipped (single-spec / non-user-facing)
- [ ] Reality check passed: agent pre-checked for gaps, showed dependency graph, offered re-decomposition, AND user confirmed via AskUserQuestion
- [ ] `/design-arch` invoked and completed (arch.md + diagrams + overview.html confirmed by user) — or skipped (trivial single-spec change)
- [ ] Beads epic created referencing spec files
- [ ] Mandatory Tests gate task exists in epic
- [ ] Task docs (if brainstorming used) reconciled with spec references

**Cannot check all boxes? Do not claim design is complete.**
</verification_checklist>

<integration>
**This skill calls:**

| Skill / Tool | When |
|---|---|
| AskUserQuestion | Socratic questioning + reality check confirmation |
| hyperpowers:internet-researcher | During questioning (inform better questions) + feasibility validation (Step 2.75) |
| /design-ui | UI/UX design — PRODUCT.md, DESIGN.md, craft pipeline, mockups, quality gates (Step 2.85) |
| /design-arch | Architecture documentation — arch.md, draw.io diagrams, overview.html (Step 4.5) |
| hyperpowers:brainstorming | For complex work requiring approach comparison |
| hyperpowers:sre-task-refinement | On non-trivial implementation tasks |

**This skill produces (consumed by /build):**
- `specs/*.md` files with `@status(approved)`
- `specs/mockups/` — component mockups for UI-facing specs (via `/design-ui`)
- `PRODUCT.md` + `DESIGN.md` — design system files (via `/design-ui`)
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

When a user asks to decompose/split an existing spec that turns out to be too large (often discovered during /build):

1. **Read the existing spec** — understand its scenarios, rules, and dependencies
2. **Apply decomposition heuristics** — use the independence test and seam types from the Decomposition Heuristics reference to identify natural split points
3. **Generate replacement specs** — create one spec per independent piece, with correct `@depends-on` and `@parallel-risk` tags
4. **Preserve and refine dependencies:**
   - If the original spec had `@blocks(X)` or was referenced as `@depends-on` by other specs, ask the user via AskUserQuestion which replacement spec is the real dependency
   - Edit each dependent spec file to update its `@depends-on` tag from the original slug to the correct replacement slug
5. **Preserve status:**
   - If original was `@status(approved)` → all replacements get `@status(approved)`
   - If original was `@status(implemented)` → completed behaviors get `@status(implemented)`, incomplete get `@status(approved)`
6. **Confirm status assignments via AskUserQuestion** (mandatory for partially-implemented specs) — present the proposed status for each replacement spec and block until the user confirms
7. **Update beads:**
   - Close the original beads task that referenced the old spec
   - Create new beads tasks for each replacement spec
   - Preserve the Tests gate task (do not duplicate it)
8. **Remove the original spec file** — the replacements fully supersede it

**No full Socratic re-questioning needed.** The design was already confirmed — this is a structural refactor of the spec, not a re-design.

</edge_cases>
