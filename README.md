# Adaptive Developer Workflow for Claude Code

An enforced, spec-driven developer workflow for Claude Code with skills for Socratic design, architecture documentation, UI/UX design, TDD implementation, spec modification, and workflow retrospectives.

> **Branches at a glance.** `master` is the stable, text-driven workflow (single Claude session follows the SKILL.md prose). `experiment/role-agents` adds a layer of 11 specialized role agents (product-owner, application-architect, security-architect, devops-architect, data-architect, uiux-designer, backend-engineer, frontend-engineer, qa-engineer, release-coordinator, spec-sre-auditor) that the orchestrator dispatches via the `Agent` tool, communicating via HTML handoff files. See [Role-Agent System (experimental)](#role-agent-system-experimental).

## What It Does

Every task flows through a pipeline of skills:

### /design — Shape the Work
1. **Socratic Questioning** — Ask focused questions via AskUserQuestion (blocks until answered). Drills down relentlessly — vague answers like "standard auth" or "basic CRUD" are rejected and followed up. Internet research (`internet-researcher`) allowed to inform questions and validate feasibility.
2. **Greenfield Questioning Protocol** — For greenfield projects, minimum 3 rounds of questioning: Scope & Architecture → Feature Deep-Dive → Integration & Flows. A completeness gate verifies coverage across 12 categories before proceeding.
3. **Decompose** — Apply independence test and seam analysis to break work into well-sized specs. Produces a decomposition map with `@depends-on` and `@parallel-risk` relationships.
4. **Validate Feasibility** — For external APIs/libraries, dispatch `internet-researcher` to verify technical claims before writing specs.
5. **UI/UX Design** (when applicable) — Full Impeccable craft pipeline + frontend-design aesthetics. Produces component mockups in `specs/mockups/`. Requires `PRODUCT.md` + `DESIGN.md` (created via `/impeccable teach`).
6. **Spec Generation** — Generate Gherkin-style Markdown spec files in `specs/`, one per entry in the decomposition map. User-facing specs include a `## Critical User Journeys` section linking the feature to end-to-end user flows.
7. **Reality Check** — Agent pre-checks specs for gaps, shows dependency graph with parallel lanes, user confirms (can request re-decomposition).
8. **CUJ Coverage Analysis** — Traces every Critical User Journey across all specs. Any journey step without a covering spec is a missing spec. Generates missing specs until all journeys are fully covered.
9. **Architecture Docs** — Auto-invokes `/design-arch` to generate `specs/arch.md`, draw.io diagrams, and `specs/overview.html`.
10. **Beads Setup** — Create epic + Tests gate task referencing spec files.

### /design-ui — UI/UX Design Pipeline
Auto-invoked by `/design` for UI-facing work. Also callable independently (e.g., after `/respec`).

1. **Design System Setup** (once per project) — Gate-checks PRODUCT.md + DESIGN.md (creates via `/impeccable teach` if missing). Classifies register (brand vs product). Presents 2-3 visual direction probes, user chooses. Locks in typography, color, motion via frontend-design.
2. **Per-Screen Design** (batched by cluster) — Groups related specs into feature clusters (e.g., "Workout Flow", "Nutrition", "Settings"). Per cluster: shape interview → component mockups → critique + detect quality gates → enhancement if needed → user confirms.
3. **Incorporate** — Adds `## UI Design` sections to all UI-facing specs. Verifies all mockups exist on disk.

### /design-arch — Architecture Documentation
1. **Input** — Reads approved Gherkin specs from `specs/`
2. **Generate** — Produces `specs/arch.md` (architecture document), `specs/diagrams/*.drawio` (architecture diagrams), and `specs/overview.html` (visual overview for non-technical stakeholders)
3. **Confirm** — User reviews and confirms architecture documentation

### /build — Implement the Specs
```
/build              # Interactive — pauses for user sign-off after each spec
/build --auto       # Autonomous — skips user sign-off, runs end-to-end
```

1. **Entry Validation** — Verify specs exist with `@status(approved)`, check beads for open work. Parse `--auto` flag.
2. **Dependency Graph** — Parse `@depends-on` and `@parallel-risk` tags, topological sort for build order. Show graph with parallel lanes, user confirms execution plan.
3. **Per-Spec Iteration** (auto-iterates all specs in order):
   - **Investigate** — Codebase analysis, create informed beads task with real file paths
   - **TDD** — RED: failing tests from spec scenarios. GREEN: implement. REFACTOR. For UI-facing specs, starts from mockup code in `specs/mockups/`.
   - **Verify** — Full test suite + code review + spec coverage + test effectiveness (NEVER scales down). Status updates blocked until verification agents return and pass.
   - **Visual Fidelity** — For UI-facing specs, verifies implementation matches mockup design decisions. Full Impeccable quality pipeline (critique + detect + polish).
   - **API Integration Check** — For UI specs with backend, verifies every button/form/nav is wired to real API calls — not TODOs, stubs, or local-state-only dispatches. CRITICAL if any element is unwired.
   - **User Sign-Off** — Presents summary of implementation, asks user to confirm work matches expectations (unless `--auto`).
   - **Update** — `@status(verified)`, close beads task
4. **Playwright E2E Tests** — For multi-spec UI epics, generates Playwright tests from Critical User Journeys in specs. Walks the full user path through the running app. Catches cross-spec integration failures that per-spec unit tests miss.
5. **Close** — Close epic, update README, save learnings

### /respec — Modify Existing Specs
1. **Find Spec** — Locate spec from beads issue context
2. **Blast Radius** — Trace all `@depends-on` and `@blocks` relationships before editing
3. **Propagate** — Contract-breaking changes propagate to downstream specs
4. **Regress Status** — Changed specs regress to `@status(approved)` for /build to resume

### /workflow-retrospective — Continuous Improvement
1. **Gather** — Queries beads for closed epics, tasks, incident + verification comments
2. **Analyze/Triage** — Calculates metrics, triages incidents by category+skill frequency
3. **Report** — Presents metrics dashboard + incident triage table
4. **Propose** — Drafts skill edits for recurring patterns, prose for one-offs
5. **Save** — Persists key findings to memory for cross-session awareness

## Role-Agent System (experimental)

> **Branch: `experiment/role-agents`.** The role-agent system is an opt-in layer that decomposes each SKILL.md's procedural text into 11 specialized agent personas. The orchestrator (the parent Claude session) dispatches role agents via the `Agent` tool; each agent produces a versioned HTML handoff at a predictable path that the next agent reads. This was added because single-Claude SKILL.md runs were skipping required steps under no-interactive-user constraints — moving the procedural detail into per-role prompts forces explicit dispatch and creates a checkable artifact per step.

### Why HTML handoffs

Inspired by [Simon Willison's "unreasonable effectiveness of HTML"](https://simonwillison.net/2026/May/8/unreasonable-effectiveness-of-html/) extended to inter-agent communication. Each handoff is:

- **User-auditable** — `open specs/handoffs/foo.html` renders in a browser with proper hierarchy. The user can spot-check any session.
- **Machine-parseable** — required `<meta data-*>` and `<section data-role="...">` tags are the only contract; hooks grep for them.
- **Rich content** — inline `<svg>` for architecture diagrams, `<details>` for collapsibles, `<table>` for matrices.
- **Versionable** — `data-handoff-version` on the `<html>` element.

Full schema: [docs/role-agent-handoff-schema.md](docs/role-agent-handoff-schema.md). Path convention: `specs/handoffs/<step>-<spec-slug>-<role>.html`.

### Role agents

11 personas, each with a focused system prompt in [agents/](agents/) (~400-600 words each). The orchestrator dispatches via `Agent(subagent_type=<role>, ...)`.

| Role | Phase | What it owns |
|------|-------|--------------|
| `product-owner` | Design | Socratic questioning (Step 2), reality check + sign-off (Step 4) |
| `application-architect` | Design + Respec | Decomposition (Step 2.5), arch docs (Step 4.5), blast radius |
| `uiux-designer` | Design | Wraps `/design-ui` — PRODUCT.md, DESIGN.md, mockups, `/impeccable` gate pipeline |
| `security-architect` | Build | Step 3.3c.1 threat-model review (OWASP-style on the diff) |
| `devops-architect` | Build + Design | Deployment topology, observability, scaling, rollback (Step 3.3c.2 + Step 4.5) |
| `data-architect` | Build | Schema design (Step 3.1.1), migration safety + query review (Step 3.3c.3) — conditional on `@touches-data` or `@layer(api\|full-stack)` |
| `backend-engineer` | Build | TDD for `@layer(api\|cli\|infra)` + the API portion of `@layer(full-stack)` |
| `frontend-engineer` | Build | TDD for `@layer(ui)` + UI portion of full-stack; owns Step 3.2.5 wiring + Step 3.3d visual fidelity |
| `qa-engineer` | Build | Per-spec scenario coverage (Step 3.3e) + epic-level Playwright/Cypress/Detox e2e (Step 4.1) |
| `release-coordinator` | Build | Final cross-spec coherence check + rollback plan (Step 4.2 — gates `bd close <epic>`) |
| `spec-sre-auditor` | Build | Step 3.3g intent + SRE-rigor audit (carried over from master) |

### Required spec tags

New tags introduced by the role-agent system, documented fully in [skills/design/resources/gherkin-spec-reference.md](skills/design/resources/gherkin-spec-reference.md):

| Tag | Purpose | Required? |
|-----|---------|-----------|
| `@layer(api\|ui\|full-stack\|cli\|infra)` | Deterministic skip signal — drives which role agents apply per spec | Required on every spec |
| `@trivial` | Typo/rename/config-only change — permits skipping architecture docs + feasibility research | Optional |
| `@touches-data` | Spec adds/modifies/migrates persistent data — triggers `data-architect` even on UI specs | Optional |

### Parallel-dispatch pattern

To dispatch multiple role agents concurrently (e.g. `security-architect` + `devops-architect` + `data-architect` for Step 3.3 review), include MULTIPLE `Agent` tool calls in a SINGLE message. Calls split across separate messages serialize. Verify by reading overlapping `data-produced-at` timestamps in the resulting handoffs.

### Inline-synthesis fallback

If the `Agent` tool is unavailable in your session (e.g., the orchestrator is itself a dispatched subagent), fall back to inline synthesis: read each role's `agents/<role>.md` prompt, perform the work yourself, produce the same handoff file at the same path, and add `<note data-synthesized="true">` to the `findings` section. The audit trail stays schema-compliant; what's lost is diversity-of-perspective (independently-prompted role agents push back on the orchestrator and surface disagreements; inline synthesis cannot).

### Validation

The role-agent system was validated by two test runs on a polished full-stack todo app (`/tmp/role-test/experiment`):

- **`/design` end-to-end** — 7 real subagent dispatches, 13 approved specs, 6 schema-compliant handoffs, 4 inter-agent disagreements surfaced (PO vs devops on rate-limiting, researcher contradicting an ORM assumption, PO catching documentation drift across role boundaries, uiux-designer running unprompted extract pass).
- **`/build` on a single representative spec (dark-mode)** — 14 real subagent dispatches (~46 min, ~848k tokens), 26 passing tests, real working dark-mode implementation, 6 more inter-agent disagreements (most valuable: SRE auditor caught 2 intent bugs no mechanical reviewer saw — `next-themes` localStorage override on hydration, rapid-toggle last-write-wins).

The validation tests also surfaced 4 real defects in our own hook infrastructure, all fixed and regression-tested:
1. `install.sh` was only globbing `*.sh` and missing `_validate_handoff.py`
2. `require-release-handoff.sh` was case-sensitive `[epic]` but bd emits `[EPIC]`
3. `require-handoff-artifact.sh` lacked defensive validator-existence handling
4. Beads' molecule auto-close bypasses the `bd close <epic>` gate structurally (post-hoc warning added via `molecule-autoclose-warn.sh`)

### Smoke test

`tests/role-agent-smoke.sh` runs 18 deterministic checks: handoff-artifact schema, release-handoff hook behavior, installed-form regressions for the 4 bugs above. Run from the repo root:

```bash
bash tests/role-agent-smoke.sh
```

## What's Included

```
.
├── install.sh                          # One-command installer (symlinks + backup)
├── uninstall.sh                        # Restores originals and removes symlinks
├── AGENTS.md                           # Agent instructions (beads onboarding, shell safety)
├── skills/
│   ├── design/SKILL.md                 # /design — Socratic questioning + spec generation
│   ├── design-ui/SKILL.md              # /design-ui — UI/UX pipeline: PRODUCT.md, mockups, quality gates
│   ├── design-arch/SKILL.md            # /design-arch — Architecture docs, diagrams, overview.html
│   ├── build/SKILL.md                  # /build — Spec-driven TDD + visual fidelity + verification
│   ├── respec/SKILL.md                 # /respec — Modify specs with blast radius tracing
│   └── workflow-retrospective/SKILL.md # Incident triage + metrics analysis skill
├── agents/                             # Role-agent personas dispatched via the Agent tool
│   ├── product-owner.md                # Socratic, reality check, sign-off
│   ├── application-architect.md        # Decomposition, arch docs, blast radius
│   ├── security-architect.md           # Threat model, OWASP review (NET-NEW role)
│   ├── devops-architect.md             # Deployment, observability, scaling, rollback
│   ├── data-architect.md               # Schema, migration safety, query plans
│   ├── uiux-designer.md                # Wraps /design-ui invocation + /impeccable gates
│   ├── backend-engineer.md             # TDD on @layer(api|cli|infra) + full-stack API
│   ├── frontend-engineer.md            # TDD on @layer(ui) + full-stack UI + wiring
│   ├── qa-engineer.md                  # Scenario coverage + e2e CUJ tests
│   ├── release-coordinator.md          # Epic close + rollback plan
│   └── spec-sre-auditor.md             # Intent + SRE-grade rigor audit
├── hooks/
│   ├── _common.sh                      # Shared utilities for hooks
│   ├── _validate_handoff.py            # Python helper: HTML handoff schema validator
│   ├── beads-auto-resume.sh            # Surfaces in-progress work + spec statuses on session start
│   ├── block-unread-edits.sh           # Blocks edits on files that haven't been read first
│   ├── block-status-during-verification.sh # Blocks status writes while a verifier is in-flight
│   ├── check-open-beads.sh             # Warns about open tasks + non-verified specs on session end
│   ├── claim-vs-call-audit.sh          # Blocks UI-spec verification unless /impeccable gates actually fired
│   ├── clear-session-reads.sh          # Resets read tracking per session
│   ├── detect-correction.sh            # Detects user corrections, prompts incident logging
│   ├── guard-spec-bash-writes.sh       # Blocks Bash file writes to specs/ that bypass Edit/Write hooks
│   ├── molecule-autoclose-warn.sh      # PostToolUse: warns when beads auto-closes an epic via molecule promotion
│   ├── remind-integration-tests.sh     # Reminds to write integration tests after code review
│   ├── require-bead-description.sh     # Enforces --description on bd create
│   ├── require-design-ui.sh            # Blocks @status(approved) on UI specs without mockups
│   ├── require-handoff-artifact.sh     # Blocks @status(verified) without required role-agent handoffs
│   ├── require-investigation-findings.sh # Blocks @status(implemented) without ## Investigation Findings
│   ├── require-layer-tag.sh            # Blocks @status(approved|implemented|verified) without @layer(...)
│   ├── require-release-handoff.sh      # Blocks bd close <epic> without release-coordinator handoff
│   ├── require-ui-tests.sh             # Blocks UI-spec verification without a referencing test file
│   ├── require-verifier-agents.sh      # Blocks @status(verified) without code-reviewer dispatch
│   ├── track-agents.sh                 # PostToolUse: logs every Agent dispatch to session state
│   ├── track-reads.sh                  # Tracks Read/Grep/Glob calls
│   ├── track-skills.sh                 # PostToolUse: logs every Skill invocation to session state
│   ├── verifier-dispatch.sh            # Tracks when Continuous Verifier is dispatched
│   ├── verifier-return.sh              # Tracks verifier results, blocks premature closure
│   ├── workflow-reminder.sh            # Context-aware reminder (/design vs /build)
│   └── wwiwo.sh                        # "What Was I Working On?" — beads + spec status
├── docs/
│   └── role-agent-handoff-schema.md    # HTML handoff format reference (5 <meta> + 4 <section data-role>)
├── tests/
│   └── role-agent-smoke.sh             # 18 deterministic regressions for handoff + release hooks + install
├── specs/                              # Gherkin spec files (per-project, not shipped)
│   ├── handoffs/                       # Role-agent HTML handoffs (created by experimental branch)
│   ├── mockups/                        # UI component mockups (Storybook or HTML)
│   └── diagrams/                       # Architecture diagrams (.drawio)
├── plans/
│   └── active/                         # Local task directories for in-progress work
└── benchmarks/
    ├── 01-quick-fix-typo.md            # Quick tier benchmark
    ├── 02-quick-add-field.md           # Quick tier benchmark
    ├── 03-standard-add-endpoint.md     # Standard tier benchmark
    ├── 04-standard-fix-bug.md          # Standard tier benchmark
    ├── 05-standard-refactor.md         # Standard tier benchmark
    ├── 06-complex-new-feature.md       # Complex tier benchmark
    └── AB-TESTING-PROTOCOL.md          # A/B testing protocol
```

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [hyperpowers](https://github.com/withzombies/hyperpowers) plugin enabled
- [beads](https://github.com/beads-project/beads) plugin enabled
- [impeccable](https://github.com/impeccable-dev/impeccable) plugin enabled (for UI/UX design pipeline)
- [frontend-design](https://github.com/claude-plugins-official/frontend-design) plugin enabled (for visual aesthetics)
- `python3` available (used by installer and beads-auto-resume hook)
- A bash-compatible shell (bash on macOS/Linux, Git Bash on Windows)

## Installation

```bash
git clone <this-repo> ~/.claude/workflow
cd ~/.claude/workflow
# Stable workflow (text-driven, single Claude session):
./install.sh
# OR — experimental role-agent system:
git checkout experiment/role-agents
./install.sh
```

The installer:
- Links skills to `~/.claude/skills/` (edits in the repo are instantly live)
- Links agents to `~/.claude/agents/` (one symlink per file in `agents/`)
- Links hooks to `~/.claude/hooks/` (both `*.sh` and `*.py` helpers — same as skills, no manual sync needed)
- Merges hook config into `~/.claude/settings.json` (backs up first; idempotent — re-running is safe)
- Optionally disables the superpowers plugin (recommended)

**Switching branches.** Run `git checkout <branch>` in `~/.claude/workflow`, then `./install.sh` again. The installer is dedup-aware at the command level, so re-installation correctly refreshes symlinks without duplicating hook registrations in `settings.json`.

**Restart Claude Code after install** — the subagent registry loads at session start. Newly-installed role agents won't be dispatchable as `subagent_type=<role>` until you `/clear` or start a fresh session. Hooks reload on every tool call so they're always current, but agent types are registered once. If you try to dispatch a newly-installed agent and get `Agent type '<name>' not found`, that's the symptom — restart and retry.

**Verifying the install:**

```bash
# Smoke test all hooks against the installed form:
bash tests/role-agent-smoke.sh
# Expected: "Total: 18  Pass: 18  Fail: 0" on the experiment branch
# (Fewer applicable checks on master since role-agent hooks aren't installed.)
```

On macOS/Linux, symlinks are used. On Windows, hard links are used (no
Developer Mode or Admin prompt required, but source and target must be on
the same drive).

## Usage

After installation, restart Claude Code (or `/clear`). Then:

1. **`/design`** — Start new work. Relentless Socratic questioning shapes the design (minimum 3 rounds for greenfield), invokes `/design-ui` for UI-facing work, Gherkin specs with Critical User Journeys are generated, CUJ coverage analysis catches missing specs, architecture docs are created, beads epic is set up.
2. **`/design-ui`** — UI/UX design pipeline. Auto-invoked by `/design` for UI-facing specs, also callable independently. Creates PRODUCT.md + DESIGN.md, generates mockups in `specs/mockups/`, runs quality gates.
3. **`/design-arch`** — Generate architecture documentation independently (also auto-invoked by `/design`).
4. **`/build`** — Implement approved specs. Auto-iterates through specs in dependency order: investigate, TDD, verify, API integration check, user sign-off. Playwright e2e tests verify CUJs before epic close. Use `--auto` for autonomous runs without sign-off pauses.
5. **`/respec`** — Modify existing specs when requirements change or bugs surface. Traces blast radius and propagates changes.
6. **Auto-resume** — On session start, you'll see in-progress beads work AND spec statuses
7. **Type `wwiwo?`** — Shows beads tasks + spec statuses at any time
8. **After 3+ completed epics** — Run `/workflow-retrospective` to analyze effectiveness
9. **Run benchmarks** — Use `benchmarks/AB-TESTING-PROTOCOL.md` for quantitative comparison

## Gherkin Spec Files

Both skills generate and consume Gherkin-style Markdown spec files in `specs/`. These specs are the **source of truth** for design intent — beads epics link to them, they don't contain inline requirements.

### Format

Specs use Markdown Gherkin: `#` headings for keywords, `- ` bullet lists for steps, `@tags` for metadata.

```markdown
@status(draft)
@api @breweries

# Feature: Nearby Breweries Endpoint

As an API consumer
I want to query breweries by location
So that I can find nearby breweries for a given coordinate

## Critical User Journeys

| CUJ | Steps in This Feature | Full Journey |
|-----|----------------------|--------------|
| Find a local brewery | Search by location → View results | Open app → Allow location → Search nearby → View details → Get directions |

## Technical Context

- **Endpoint**: GET /api/breweries/nearby
- **Parameters**: lat (float), lng (float), radius (integer, miles)
- **Response**: Array of Brewery objects sorted by distance

## Rule: Valid coordinates return nearby results

### Scenario: Successful nearby query

- Given breweries exist within 10 miles of coordinates 40.7128, -74.0060
- When I GET /api/breweries/nearby?lat=40.7128&lng=-74.0060&radius=10
- Then I receive a 200 response
- And the response contains breweries sorted by distance
```

### Spec Types

| Type | File | When |
|------|------|------|
| **System spec** | `specs/system.md` | Greenfield projects and major architectural changes. Captures tech stack, data model, feature map, API conventions. |
| **Feature spec** | `specs/<feature-slug>.md` | Every feature. Self-contained with `@depends-on`/`@blocks` tags for cross-feature relationships. |

### Tags

| Tag | Purpose |
|-----|---------|
| `@status(draft\|approved\|implemented\|verified)` | Lifecycle tracking |
| `@depends-on(feature-slug)` | This feature requires another feature |
| `@blocks(feature-slug)` | Another feature depends on this one |
| `@parallel-risk(feature-slug)` | Independent specs that modify the same files — warns about merge conflicts, recommends building smaller first |
| `@system` | Marks the system-level spec |
| Custom: `@auth`, `@api`, `@ui`, etc. | Domain categorization |

### Spec Complexity (Inferred)

Spec complexity scales naturally with the work. No explicit tier classification required.

| Signal | Spec Style |
|--------|------------|
| 1-2 files, <50 lines change | Feature + 1-3 Scenarios. No Rules, no Background. |
| Multi-file, new endpoint/component | Feature + As/I want/So that + Technical Context + Rules + Scenarios. |
| New feature, greenfield, architectural | Multiple spec files with `@depends-on`/`@blocks`. System spec required. Scenario Outlines with Examples. |

### Lifecycle

1. **Draft** (`@status(draft)`) — Generated during `/design`
2. **Approved** (`@status(approved)`) — After user confirms via reality check
3. **Implemented** (`@status(implemented)`) — Updated during `/build` as edge cases discovered
4. **Verified** (`@status(verified)`) — After `/build` verification passes

### Greenfield Rebuild

For greenfield projects, the complete set of specs in `specs/` must be sufficient to **rebuild the entire application from scratch**. The system spec + feature specs + dependency graph collectively capture everything needed: architecture, data models, API contracts, and all feature behaviors.

## Hooks

Hooks are organized by event. Most are deterministic gates that block on missing prerequisites (`@status` transitions, missing handoffs, etc.). Each has a documented override path when the block is genuinely a false positive — never silently ignore an unexpected block.

### SessionStart

| Hook | What It Does |
|------|--------------|
| `beads-auto-resume.sh` | Checks for in-progress beads work + Gherkin spec statuses |
| `clear-session-reads.sh` | Resets file read tracking + session-agents/skills/inflight logs so each session starts fresh |

### PreToolUse — Edit / Write (gates spec-status transitions)

| Hook | What It Does |
|------|--------------|
| `block-unread-edits.sh` | Blocks edits on files that haven't been read first |
| `require-design-ui.sh` | Blocks `@status(approved)` on UI-facing specs missing PRODUCT.md, DESIGN.md, or mockups. Use `@backend-only` to skip. |
| `require-layer-tag.sh` | Blocks `@status(approved\|implemented\|verified)` on specs without `@layer(api\|ui\|full-stack\|cli\|infra)` |
| `require-investigation-findings.sh` | Blocks `@status(implemented)` without `## Investigation Findings` section (3+ lines). Override: `@investigation-skip(reason)`. Auto-allows `@trivial`. |
| `require-verifier-agents.sh` | Blocks `@status(verified)` without a `hyperpowers:code-reviewer` Agent dispatch in this session referencing the spec slug. Override: `@verifier-skip(reason)`. |
| `block-status-during-verification.sh` | Blocks status edits + `bd close` while a Continuous Verifier is in-flight |
| `require-ui-tests.sh` | Blocks `@status(verified)` on UI specs without a test file referencing the slug. Auto-detects Playwright/Cypress/Detox/Vitest/Jest-RTL/XCUITest. Override: `@ui-test-skip(reason)`. |
| `require-handoff-artifact.sh` | (experimental branch) Blocks `@status(verified)` without the role-agent handoff chain present + schema-compliant. Override: `@handoff-skip(role: reason)`. Auto-allows `@trivial`. |
| `claim-vs-call-audit.sh` | Blocks `@status(verified)` on UI-bearing specs unless all 5 `/impeccable` gates fired via the Skill tool in this session for that slug. Override: `@gate-skip(<gate>: reason)`. |

### PreToolUse — Bash

| Hook | What It Does |
|------|--------------|
| `require-bead-description.sh` | Enforces `--description` flag on `bd create` |
| `remind-integration-tests.sh` | Reminds to write integration tests after code review agents return |
| `guard-spec-bash-writes.sh` | Blocks Bash commands that write to `specs/*.md` (`cat >`, `sed -i`, `tee`, etc.) — spec edits must go through Edit/Write so the gate hooks audit them |
| `require-release-handoff.sh` | (experimental branch) Blocks `bd close <epic-id>` without a release-coordinator handoff with verdict `READY-TO-CLOSE` or `READY-WITH-CAVEATS`. Override: `bd comments add <epic> "RELEASE-SKIP: <reason>"`. |

### PreToolUse — Agent

| Hook | What It Does |
|------|--------------|
| `verifier-dispatch.sh` | Tracks when Continuous Verifier is dispatched (writes to `state/verifier-inflight.txt`) |

### PostToolUse

| Hook | Event | What It Does |
|------|-------|--------------|
| `track-reads.sh` | Read/Grep/Glob | Tracks which files have been read (paired with `block-unread-edits`) |
| `track-agents.sh` | Agent | Logs every Agent dispatch (timestamp, subagent_type, prompt) — consumed by `require-verifier-agents` |
| `track-skills.sh` | Skill | Logs every Skill invocation — consumed by `claim-vs-call-audit` |
| `verifier-return.sh` | Agent | Logs verifier verdict to bd, removes the in-flight marker |
| `molecule-autoclose-warn.sh` | Bash | (experimental branch) Warns when `bd close <child>` triggered beads' internal molecule auto-close on the parent epic, bypassing `require-release-handoff.sh` |

### UserPromptSubmit / Stop

| Hook | Event | What It Does |
|------|-------|--------------|
| `workflow-reminder.sh` | UserPromptSubmit | Context-aware: suggests `/build` if approved specs exist, `/design` if not |
| `detect-correction.sh` | UserPromptSubmit | Detects user corrections; prompts incident logging for the retrospective |
| `wwiwo.sh` | UserPromptSubmit (matcher: `wwiwo`) | Shows beads tasks + Gherkin spec statuses |
| `check-open-beads.sh` | Stop | Warns about open beads tasks + non-verified specs on session end |

## Workflow Incident Logging

When Claude makes a mistake during /design or /build, the `detect-correction.sh` hook detects correction phrases in your message and prompts Claude to ask: "Should I log this as a workflow incident for the next retro?" If you confirm, a structured comment is logged on the active epic:

```
WORKFLOW INCIDENT: [short description]

Category: [skill-gap | missing-rule | wrong-default | edge-case | process-violation]
Skill: [design | build | retrospective | hook-name | none]
What happened: [what Claude did wrong]
What should have happened: [correct behavior]
User correction: [what the user said]
Proposed fix: [optional]
```

These incidents feed into the retrospective for pattern-based skill improvement.

## Workflow Retrospective

The **workflow-retrospective** skill provides a data-driven feedback loop for continuous improvement. It reads both incident logs and quantitative metrics, triages incidents by pattern frequency, and drafts actual skill file edits for recurring patterns.

### What It Analyzes

| Data Source | What It Reveals |
|-------------|-----------------|
| `WORKFLOW INCIDENT:` comments | Pain points, skill gaps, missing rules, edge cases |
| `VERIFICATION FAILURE:` comments | Where verification catches issues |
| Quantitative metrics (pass rates, rework) | Overall workflow effectiveness |
| Step effectiveness | Which /build steps catch errors (earlier = cheaper) |

### Incident Triage

| Pattern | Action |
|---------|--------|
| 2+ incidents of same category+skill | **RECURRING** — draft actual SKILL.md edit text |
| 1 incident | **ONE-OFF** — prose proposal + "monitor — may become a pattern" |

### How to Run

```
/workflow-retrospective
```

The skill runs a 5-step process:
1. **Gather** — Queries beads for closed epics, tasks, incident + verification comments
2. **Analyze/Triage** — Calculates metrics, triages incidents by category+skill frequency
3. **Report** — Presents metrics dashboard + incident triage table
4. **Propose** — Drafts skill edits for recurring patterns, prose for one-offs
5. **Save** — Persists key findings to memory for cross-session awareness

### When to Run

- **After every epic** — quick metrics + incident review (5 min)
- **Weekly during active use** — full analysis with trend detection (15 min)
- **Monthly** — comprehensive cross-project trend analysis (30 min)

### Getting Started on a New Machine

The retrospective needs completed beads epics to analyze. After a fresh install:
1. Work through 3+ epics using /design + /build
2. Run `/workflow-retrospective` for your first analysis
3. The skill handles limited data gracefully — it notes data limitations and tells you when to re-run

## Design Principles

- **Pipeline of skills, clear separation** — /design shapes work; /design-arch documents architecture; /build implements through TDD; /respec handles change propagation; /workflow-retrospective drives improvement.
- **Specs are the source of truth** — Gherkin spec files in `specs/` define what to build; beads tracks sub-task progress
- **Specs enable full rebuild** — For greenfield projects, specs capture enough detail to reconstruct the entire app
- **Specs are living documents** — Updated during implementation as edge cases are discovered, not frozen after planning
- **UI design is a named skill, not a sub-step** — `/design-ui` is an explicit skill invocation (like `/design-arch`), not a decimal sub-step agents can skip. It produces PRODUCT.md, DESIGN.md, and component mockups in `specs/mockups/` before specs are generated. /build verifies visual fidelity against mockups.
- **Decompose at natural seams** — Work is split into multiple specs using the independence test: if you can test it without the other thing existing, it's a separate spec. No arbitrary thresholds.
- **Parallelism is first-class** — Independent specs can be built in parallel. `@parallel-risk` flags file overlap without blocking. /build shows the dependency graph and asks before dispatching.
- **Research informs, never replaces asking** — Internet research during /design makes questions sharper and validates feasibility, but findings become questions to the user, not silent assumptions.
- **Relentless questioning** — Vague answers are rejected. "Standard auth" spawns follow-ups about social login, MFA, token storage. Greenfield projects require minimum 3 rounds with a 12-category completeness gate.
- **Critical User Journeys connect features** — Every user-facing spec documents which end-to-end journeys it participates in. CUJ tracing catches missing specs that feature-level thinking misses. CUJs also drive Playwright e2e tests.
- **Spec-driven TDD** — Tests are generated FROM spec scenarios before implementation. No exceptions.
- **Verification never scales down** — Full suite + code review agent + spec coverage check + API integration check on every spec
- **API integration is not optional** — Every UI button/form that implies backend persistence must be wired to a real API call. Stubs, TODOs, and local-state-only dispatches are CRITICAL failures.
- **E2E tests before epic close** — Playwright tests walk Critical User Journeys through the running app. Catches cross-spec integration failures that per-spec unit tests miss.
- **User sign-off per spec** — After verification passes, user confirms work matches expectations before status update. `--auto` flag skips for autonomous runs.
- **Verification gates completion** — Status updates and task closures are blocked until verification agents return results and pass. No "updating while waiting."
- **Questioning blocks on user answers** — AskUserQuestion tool required, no proceeding without answers
- **Tasks created after investigation** — /build creates beads tasks with real codebase context, not guesswork
- **Pause on spec drift** — Fundamental spec changes require /respec, not silent fixes during /build
- **Blast radius before editing** — /respec traces dependency graphs before modifying specs; changes propagate to affected downstream specs
- **Dependency-ordered execution** — /build processes specs in `@depends-on` topological order
- **Incidents drive improvement** — User corrections are detected, logged as structured comments, and triaged in the retrospective to draft skill edits
- **Hooks enforce, skills advise** — Deterministic gates, not suggestions
- **Investigate before writing** — Hook blocks edits on files you haven't read
- **Links, not copies** — Skills and hooks are linked so repo edits are instantly live

## Uninstall

```bash
cd ~/.claude/workflow
./uninstall.sh
```

The uninstaller:
- Removes all skill and hook symlinks
- Restores any original files that were backed up during install (`.pre-workflow` suffix)
- Restores `settings.json` from its pre-workflow backup
- Leaves the repo itself untouched
