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

### Format

Specs use Markdown Gherkin: `#` headings for Gherkin keywords, `- ` bullet lists for steps, `@tags` at the top of the file.

### Tags

- `@status(draft|approved|implemented|verified)` — lifecycle tracking (required on every spec)
- `@depends-on(feature-slug)` — this feature requires another feature to be implemented first
- `@blocks(feature-slug)` — another feature depends on this one
- `@parallel-risk(feature-slug)` — this spec modifies the same files as another independent spec. Both specs remain parallel (no `@depends-on` added). /build warns about potential merge conflicts and builds the smaller spec first.
- Custom domain tags: `@auth`, `@api`, `@ui`, `@security`, etc. — categorization

### Greenfield Rebuild Principle

For greenfield projects, the complete set of specs in `specs/` must be **sufficient to rebuild the entire application from scratch**. An agent or developer reading only the specs should understand:
- What the system is and why it exists (system spec)
- The tech stack, data model, and architecture (system spec)
- Every feature's behavior, edge cases, and integration points (feature specs)
- The build order via `@depends-on` dependency chains

This is achieved through two spec types:

1. **System spec** (`specs/system.md`) — Required for greenfield and major architectural changes. Describes the application as a whole: purpose, tech stack, data model, deployment, and a feature map showing how all features relate.

2. **Feature specs** (`specs/<feature-slug>.md`) — One per feature. Self-contained but linked via `@depends-on`/`@blocks` tags. Must include enough technical detail (data shapes, API contracts, integration points) that someone could implement the feature given only the spec and the system spec.

### System Spec Template (Greenfield / Architectural Changes)

```markdown
@status(draft)
@system

# System: [Application Name]

[What this application is and why it exists — 2-3 sentences]

## Tech Stack

- **Runtime**: [e.g., Node.js 20, Python 3.12]
- **Framework**: [e.g., Express, FastAPI, Next.js]
- **Database**: [e.g., PostgreSQL 16, SQLite]
- **Auth**: [e.g., JWT, session-based, OAuth2]
- **Deployment**: [e.g., Docker, Vercel, bare metal]
- **Testing**: [e.g., Jest, pytest, Go test]

## Data Model

### [Entity Name]

| Field | Type | Constraints |
|-------|------|-------------|
| id | UUID | primary key |
| name | string | required, max 255 |
| created_at | timestamp | default now() |

### Relationships

- [Entity A] has many [Entity B]
- [Entity B] belongs to [Entity A]

## Feature Map

| Feature | Spec | Dependencies | Priority |
|---------|------|--------------|----------|
| User Registration | user-registration.md | (none) | P0 |
| User Authentication | user-authentication.md | user-registration | P0 |

## API Overview

- Base URL: `/api/v1`
- Auth: Bearer token in Authorization header
- Response format: JSON with `{ data, error, meta }` envelope
- Error format: `{ error: { code, message, details } }`

## Non-Functional Requirements

### Scenario: Response time under load

- Given 100 concurrent users
- When they make API requests
- Then 95th percentile response time is under 200ms
```

### Feature Spec Templates

**Simple** — Feature + 1-3 Scenarios. No Rules, no Background.

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

**Standard** — Feature + As/I want/So that + Technical Context + Rules + Background + Scenarios.

```markdown
@status(draft)
@api @breweries

# Feature: Nearby Breweries Endpoint

As an API consumer
I want to query breweries by location
So that I can find nearby breweries for a given coordinate

## Technical Context

- **Endpoint**: GET /api/breweries/nearby
- **Parameters**: lat (float, required), lng (float, required), radius (integer, miles, default 10, max 100)
- **Response**: Array of Brewery objects sorted by distance ascending

### Response Shape

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Brewery identifier |
| name | string | Brewery name |
| distance | float | Miles from query point |

## Background

- Given the brewery database is populated
- And the API server is running

## Rule: Valid coordinates return nearby results

### Scenario: Successful nearby query

- Given breweries exist within 10 miles of coordinates 40.7128, -74.0060
- When I GET /api/breweries/nearby?lat=40.7128&lng=-74.0060&radius=10
- Then I receive a 200 response
- And the response contains breweries sorted by distance

## Rule: Invalid input is rejected

### Scenario: Missing required parameters

- Given I omit the lat parameter
- When I GET /api/breweries/nearby?lng=-74.0060&radius=10
- Then I receive a 400 response
- And the error message indicates lat is required
```

**Complex** — Multiple spec files with `@depends-on`/`@blocks`. Full Gherkin structure.

```markdown
@status(draft)
@auth @security @mvp
@depends-on(user-registration)
@blocks(payment-processing)

# Feature: User Authentication

As a registered user
I want to log in securely
So that I can access my account

## Technical Context

- **Endpoint**: POST /api/auth/login
- **Request Body**: `{ email: string, password: string }`
- **Response**: `{ token: string, expiresIn: number, user: UserSummary }`
- **Token**: JWT signed with RS256, 1-hour expiry
- **Dependencies**: User table from user-registration feature

### Data Structures

| Field | Type | Description |
|-------|------|-------------|
| token | JWT | Access token, 1h TTL |
| refreshToken | UUID | Stored in DB, 30d TTL |

## Background

- Given the authentication service is running
- And the user database is available

## Rule: Valid credentials grant access

### Scenario: Successful login with email

- Given a registered user with email "user@test.com"
- When they submit valid credentials
- Then they receive a session token

## Rule: Invalid credentials are rejected

### Scenario Outline: Rate limiting after failures

- Given a registered user
- When they fail to log in <attempts> times
- Then their account is locked for <duration>

#### Examples

| attempts | duration   |
|----------|------------|
| 3        | 5 minutes  |
| 5        | 30 minutes |
| 10       | 24 hours   |
```

### Lifecycle

Specs are **living documents**:
1. **Draft** — Generated during /design. `@status(draft)`
2. **Approved** — After user confirms design (reality check passes). `@status(approved)`
3. **Implemented** — Updated during /build as edge cases are discovered. `@status(implemented)`
4. **Verified** — After /build verification passes. `@status(verified)`

### File Naming

`specs/<feature-slug>.md` where `<feature-slug>` is kebab-case derived from the feature name.
Examples: `specs/user-authentication.md`, `specs/nearby-breweries-endpoint.md`, `specs/fix-readme-typo.md`.

### Directory Structure

```
project/
  specs/
    system.md                     # @system — greenfield only
    user-registration.md
    user-authentication.md        # @depends-on(user-registration)
    payment-processing.md         # @depends-on(user-authentication)
  src/
  tests/
```

### Decomposition Heuristics

When generating multiple specs, use these heuristics to decide what should be a separate spec vs. scenarios within one spec.

#### The Independence Test

A piece of work is independent from another if:
1. You can write tests for it without the other piece existing
2. It has its own inputs and outputs (even if they share a file)
3. Removing it doesn't break the other piece's tests

If all three hold, the pieces should be **separate specs**. If any fail, they belong in the **same spec** (as scenarios under different Rules).

#### Seam Types

Look for these natural boundaries when decomposing:

| Seam | Example | Signal |
|------|---------|--------|
| Data boundary | API endpoint vs. CLI command — different input sources, same DB | Different entry points to the system |
| Lifecycle boundary | User registration vs. user authentication — different user journeys | Different "when" triggers |
| Consumer boundary | Admin dashboard vs. public API — different audiences | Different "who" uses it |
| Layer boundary | Database schema vs. API routes vs. UI components | Can be built bottom-up independently |
| Rule boundary | Validation rules vs. business logic vs. formatting | Different "what kind" of behavior |

#### Parallel Risk: File Overlap

When two independent specs will modify the same file:
- Tag both specs with `@parallel-risk(other-spec-slug)`
- They remain parallel (do NOT add `@depends-on`)
- /build warns about potential merge conflicts and builds the smaller spec first
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
2. **Do NOT dispatch investigation agents** — Investigation is /build's job. Dispatching codebase-investigator during design leads to the agent rationalizing that it has "enough context" to skip the user's answers.
3. **Do NOT proceed until answers are received** — If you asked a question, you must receive and incorporate the answer before moving forward. "Making reasonable defaults for ambiguous parts" is not acceptable.
4. **Multiple rounds are expected for complex work** — If the work involves new features, integrations, or architectural decisions, one round of questions is probably insufficient.
5. **Research agents during questioning inform questions, not replace them** — If you learn the project uses passport.js, that informs what to ask, it doesn't eliminate the need to ask.

Questions to stabilize:
- **What** — What is being built/changed/fixed?
- **Why** — What problem does this solve?
- **Where** — Which parts of the system are affected?
- **Constraints** — What must NOT change? What are the boundaries?
- **Dependencies** — Does this depend on other features? Do other features depend on this?
- **Edge cases** — What happens with empty/invalid/unexpected input?

For simple changes (typo, rename, config), 0-1 questions may suffice — the request itself may be fully specified. Don't ask questions for the sake of asking.

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

## Step 3: Generate Gherkin Spec Files

After decomposition, generate one spec file per entry in the decomposition map:

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

**BLOCK until user confirms.** Do not proceed to beads setup with unapproved specs.

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
- Beads epic created referencing spec files
- Tests gate task created in epic
- User has confirmed specs via reality check
- Task docs (if brainstorming was used) reference specs

**Tell the user:** "Design complete. Specs approved. Run `/build` when ready to implement."

</the_process>

<examples>

<example>
<scenario>User asks to fix a typo</scenario>

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

<critical_rules>
## Rules That Have No Exceptions

1. **All questions via AskUserQuestion** -> Blocks execution until user responds. Text questions do not block.
2. **No investigation during design** -> Investigation is /build's job. Dispatching agents during questioning leads to skipping user answers.
3. **No proceeding without answers** -> "Making reasonable defaults for ambiguous parts" is not acceptable.
4. **Every design produces spec files** -> All work gets specs in `specs/`. Simple work gets simple specs (Feature + 1-3 Scenarios). Complex work gets multiple specs with dependencies.
5. **Reality check before approval** -> Agent pre-checks for gaps, then user confirms. Both parts required.
6. **Specs are the source of truth** -> Beads epic descriptions reference spec files, not inline requirements.
7. **Every epic has a Tests gate task** -> Prevents beads auto-close before verification.
8. **Greenfield requires system spec** -> `specs/system.md` is mandatory for greenfield projects.
9. **Dependency integrity** -> Every `@depends-on(x)` and `@blocks(x)` must reference an existing spec file. No circular dependencies.

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "It's just a typo" -> Simple work gets simple specs. Still gets a spec file.
- "The user is in a hurry" -> Skipping design creates bugs that cost more time later.
- "I know this codebase well enough" -> Your knowledge doesn't replace user intent. Ask questions.
- "I'll investigate while waiting for answers" -> NO. Investigation is /build's job. This leads to skipping user answers entirely.
- "I'll make reasonable defaults for the ambiguous parts" -> NO. Ambiguity is exactly what questions resolve.
- "The user's description is detailed enough" -> Detailed descriptions still have hidden constraints. Ask critical questions.
- "I have enough context from the codebase" -> Codebase context informs what to ask, it doesn't replace asking.
- "A spec is overkill for this change" -> Simple specs are 5-10 lines. If that's too much, the change is probably a no-op.
- "I'll write the spec after I implement it" -> Specs are design documents, not documentation. They capture intent BEFORE code.
- "The spec scenarios are obvious from the code" -> Specs exist so someone can rebuild the app without reading the code.
- "I don't need a system spec for this project" -> If it's greenfield, `specs/system.md` is required.
- "The spec is getting too long" -> Split into multiple specs with `@depends-on` relationships.
- "The @depends-on tags aren't important" -> The dependency graph IS the build order for /build.
</critical_rules>

<verification_checklist>
Before claiming /design is complete:

- [ ] All critical questions asked via AskUserQuestion (not text)
- [ ] User answered all critical questions before proceeding
- [ ] No investigation agents dispatched during design
- [ ] Decomposition heuristics applied (independence test, seam scan) — or skipped for trivially single-behavior work
- [ ] Decomposition map produced before spec generation
- [ ] Gherkin spec file(s) generated in `specs/`
- [ ] System spec generated for greenfield projects
- [ ] All specs tagged with `@status(approved)` (after reality check)
- [ ] Dependency integrity verified (all @depends-on/@blocks/@parallel-risk reference existing specs)
- [ ] Reality check passed: agent pre-checked for gaps, showed dependency graph, offered re-decomposition, AND user confirmed via AskUserQuestion
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
| hyperpowers:brainstorming | For complex work requiring approach comparison |
| hyperpowers:sre-task-refinement | On non-trivial implementation tasks |

**This skill produces (consumed by /build):**
- `specs/*.md` files with `@status(approved)`
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
