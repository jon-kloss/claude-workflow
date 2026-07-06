# Adaptive Developer Workflow for Claude Code

An enforced, spec-driven developer workflow for Claude Code with skills for Socratic design, architecture documentation, UI/UX design, TDD implementation, spec modification, and workflow retrospectives.

> **Branches at a glance.** `master` is the stable, text-driven workflow (single Claude session follows the SKILL.md prose). `experiment/role-agents` adds a layer of 16 specialized role agents — 11 core roles (product-owner, application-architect, security-architect, devops-architect, data-architect, uiux-designer, backend-engineer, frontend-engineer, qa-engineer, release-coordinator, spec-sre-auditor) plus 5 game-project roles (game-designer, level-designer, narrative-designer, systems-designer, game-ui-designer) — that the orchestrator dispatches via the `Agent` tool, communicating via HTML handoff files. See [Role-Agent System (experimental)](#role-agent-system-experimental).

## What It Does

Every task flows through a pipeline of skills:

### /design — Shape the Work
1. **Socratic Questioning** — Ask focused questions via AskUserQuestion (blocks until answered). Drills down relentlessly — vague answers like "standard auth" or "basic CRUD" are rejected and followed up. Internet research (`internet-researcher`) allowed to inform questions and validate feasibility.
2. **Greenfield Questioning Protocol** — For greenfield projects, minimum 3 rounds of questioning: Scope & Architecture → Feature Deep-Dive → Integration & Flows. A completeness gate verifies coverage across 12 categories before proceeding.
3. **Game Design** (game projects) — When `.claude/game-context.md` exists in the project root, `game-designer` shapes the core loop before decomposition (Step 2.3), and `level-designer` / `narrative-designer` / `systems-designer` run per-spec passes after it (Step 2.7).
4. **Decompose** — Apply independence test and seam analysis to break work into well-sized specs. Produces a decomposition map with `@depends-on` and `@parallel-risk` relationships.
5. **Validate Feasibility** — For external APIs/libraries, dispatch `internet-researcher` to verify technical claims before writing specs.
6. **UI/UX Design** (when applicable) — Full Impeccable craft pipeline + frontend-design aesthetics. Produces component mockups in `specs/mockups/`. Requires `PRODUCT.md` + `DESIGN.md` (created via `/impeccable teach`). Specs tagged `@surface(game)` route to `game-ui-designer` instead of `uiux-designer`.
7. **Spec Generation** — Generate Gherkin-style Markdown spec files in `specs/`, one per entry in the decomposition map. User-facing specs include a `## Critical User Journeys` section linking the feature to end-to-end user flows.
8. **Reality Check** — Agent pre-checks specs for gaps, shows dependency graph with parallel lanes, user confirms (can request re-decomposition).
9. **CUJ Coverage Analysis** — Traces every Critical User Journey across all specs. Any journey step without a covering spec is a missing spec. Generates missing specs until all journeys are fully covered.
10. **Architecture Docs** — Auto-invokes `/design-arch` to generate `specs/arch.md`, draw.io diagrams, and `specs/overview.html`.
11. **Beads Setup** — Create epic + Tests gate task referencing spec files.

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
   - **Investigate** (Step 3.1) — Codebase analysis, create informed beads task with real file paths. `data-architect` joins when the spec is `@touches-data`.
   - **TDD** (Step 3.2) — RED: failing tests from spec scenarios. GREEN: implement. REFACTOR. For UI-facing specs, starts from mockup code in `specs/mockups/`.
   - **API Wiring** (Steps 3.2.5–3.2.6) — Wiring checkpoint + dead-UI scan: every button/form/nav wired to real API calls — not TODOs, stubs, or local-state-only dispatches. CRITICAL if any element is unwired.
   - **Verify** (Step 3.3, sub-steps 3.3a–3.3i) — Test suite, test-effectiveness, code review, security review, devops review, data review (when `@touches-data`), authoritative QA verification (includes visual fidelity against mockups), SRE intent audit, and fix cycles. Verification never scales below the `@trivial` floor, and status updates are blocked until verification agents return and pass.
   - **User Sign-Off** (Step 3.4) — Presents summary of implementation, asks user to confirm work matches expectations (unless `--auto`).
   - **Update** — `@status(verified)`, close beads task
4. **Epic-Level E2E Tests** (Step 4.1) — For multi-spec UI epics, `qa-engineer` generates e2e tests (Playwright/Cypress/Detox) from Critical User Journeys in specs. Walks the full user path through the running app. Catches cross-spec integration failures that per-spec unit tests miss.
5. **Close** (Steps 4.2–4.8) — `release-coordinator` final verification (gates `bd close` on the epic), close epic, update README, save learnings, retrospective check (a retro is due after ≥3 closed epics or ≥10 accumulated incidents).

### /respec — Modify Existing Specs
1. **Find Spec** — Locate spec from beads issue context
2. **Blast Radius** — Trace all `@depends-on` and `@blocks` relationships before editing
3. **Propagate** — Contract-breaking changes propagate to downstream specs
4. **Regress Status** — Changed specs regress to `@status(approved)` for /build to resume

### /workflow-retrospective — Continuous Improvement
1. **Gather** — Queries beads for closed epics, tasks, incident + verification comments; reads the gate override ledger
2. **Analyze/Triage** — Calculates metrics, triages incidents by category+skill frequency, clusters overrides by gate
3. **Report** — Presents metrics dashboard + incident triage table
4. **Propose** — Drafts skill edits for recurring patterns, prose for one-offs
5. **Save** — Persists key findings to memory for cross-session awareness

### /onboard — Brownfield Bootstrap (experimental branch)

Use when starting workflow on an existing codebase, OR when accumulated changes have outpaced agent memory. Seeds and refreshes per-agent memory files at `.claude/agent-memory/<role>.md` so role agents have project context before `/design` or `/build`.

```
/onboard                  # Full bootstrap — first time on a codebase
/onboard --refresh        # Delta refresh — re-scan after manual changes since last update
/onboard <role-slug>      # Single-agent refresh (e.g. /onboard frontend-engineer)
```

**Memory file structure (hierarchical):** YAML frontmatter (agent, project-root, last-commit-sha) + Summary + Conventions + role-specific section (Routes / Component map / Tables / Tokens / etc.) + Recent changes (rolling cap 5) + Known issues + Pointers (drill-down references to deeper docs or code paths). **Soft cap ~3,500 words; hard cap ~6,000 words.** Agents prune to the soft cap during normal updates. Above the hard cap, sections overflow into role-scoped sub-files under `.claude/agent-memory/<role>/<section>.md` — the main file holds a summary + link, sub-files hold the inventory. Designed for medium-to-large codebases where Routes/Components/Schema can each exceed 1k words on their own.

**Read at dispatch, write at end of dispatch.** Every role agent's prompt now has a "Memory: read first, update last" section. Phase 1 reads the memory file; the final phase appends/updates it. Memory references in handoff `data-input-references` make the audit trail include "this dispatch built on accumulated memory."

**Security: memory is committed.** Per-project, `.claude/agent-memory/<role>.md` is committed to git so the team shares the memory. The `guard-agent-memory-secrets.sh` PreToolUse hook blocks writes containing JWT / AWS key / Stripe key / GitHub PAT / PEM private key / DB connection string with credentials / and ~10 other secret-shape patterns. Override (rare): `@memory-allow-secret(<reason>)` in the write content.

## Role-Agent System (experimental)

> **Branch: `experiment/role-agents`.** The role-agent system is an opt-in layer that decomposes each SKILL.md's procedural text into 16 specialized agent personas. The orchestrator (the parent Claude session) dispatches role agents via the `Agent` tool; each agent produces a versioned HTML handoff at a predictable path that the next agent reads. This was added because single-Claude SKILL.md runs were skipping required steps under no-interactive-user constraints — moving the procedural detail into per-role prompts forces explicit dispatch and creates a checkable artifact per step.

### Why HTML handoffs

Inspired by [Simon Willison's "unreasonable effectiveness of HTML"](https://simonwillison.net/2026/May/8/unreasonable-effectiveness-of-html/) extended to inter-agent communication. Each handoff is:

- **User-auditable** — `open specs/handoffs/step-2.5-user-auth-application-architect.html` renders in a browser with proper hierarchy. The user can spot-check any session.
- **Machine-parseable** — required `<meta data-*>` and `<section data-role="...">` tags are the only contract; hooks grep for them.
- **Rich content** — inline `<svg>` for architecture diagrams, `<details>` for collapsibles, `<table>` for matrices.
- **Versionable** — `data-handoff-version` on the `<html>` element.

Full schema: [docs/role-agent-handoff-schema.md](docs/role-agent-handoff-schema.md). Path convention: `specs/handoffs/<step>-<spec-slug>-<role>.html`.

### Role agents

16 personas, each with a focused system prompt in [agents/](agents/). Shared exit, questioning, memory, and tool rules live in [docs/agent-protocol.md](docs/agent-protocol.md). The orchestrator dispatches via `Agent(subagent_type=<role>, ...)`.

| Role | Phase | What it owns |
|------|-------|--------------|
| `product-owner` | Design | Socratic questioning + reality check (Step 2) |
| `game-designer` | Design (game) | Core loop, player verbs, win/loss, core fantasy (Step 2.3) |
| `application-architect` | Design + Respec | Decomposition (Step 2.5), arch docs (Step 4.5 via `/design-arch`), blast radius (respec Step 3) |
| `level-designer` | Design (game) | Zone layout, encounters, difficulty curves, pacing (Step 2.7) |
| `narrative-designer` | Design (game) | Story arc, characters, dialogue, lore, tone (Step 2.7) |
| `systems-designer` | Design (game) | Progression math, economy balance, drop tables, anti-grind (Step 2.7) |
| `uiux-designer` | Design | Wraps `/design-ui` — PRODUCT.md, DESIGN.md, mockups, `/impeccable` gate pipeline (Step 2.85) |
| `game-ui-designer` | Design (game) | Game UI (HUD, menus, diegetic, juice) — replaces `uiux-designer` at Step 2.85 for `@surface(game)` specs |
| `data-architect` | Build | Schema design at investigation (Step 3.1), migration safety + query review (Step 3.3f) — conditional on `@touches-data` |
| `backend-engineer` | Build | TDD for `@layer(api\|cli\|infra)` + the API portion of `@layer(full-stack)` (Step 3.2) |
| `frontend-engineer` | Build | TDD for `@layer(ui)` + UI portion of full-stack (Step 3.2); owns Step 3.2.5 wiring + visual-fidelity self-audit at REFACTOR |
| `security-architect` | Build | Step 3.3d threat-model review (OWASP-style on the diff) |
| `devops-architect` | Design + Build | Deployment topology, observability, scaling, rollback (Step 4.5 via `/design-arch` + Step 3.3e) |
| `qa-engineer` | Build | Per-spec authoritative verification (Step 3.3g) + epic-level Playwright/Cypress/Detox e2e (Step 4.1) |
| `spec-sre-auditor` | Build | Step 3.3h intent + SRE-rigor audit (carried over from master) |
| `release-coordinator` | Build | Final cross-spec coherence check + rollback plan (Step 4.2 — gates `bd close <epic>`) |

**Game roles activate per project, not per branch.** The five game roles wake up when `.claude/game-context.md` exists in the project root (template: `skills/onboard/resources/game-context-template.md`). Game specs use `@layer(gameplay)`; a spec tagged `@surface(game)` routes its UI design to `game-ui-designer` instead of `uiux-designer`. Routing is per-spec — on a game project, a plain settings page without `@surface(game)` still goes to `uiux-designer`.

### Required spec tags

New tags introduced by the role-agent system. The authoritative tag vocabulary is [docs/registry.md](docs/registry.md) §8 (override tags: §7); usage guidance lives in [skills/design/resources/gherkin-spec-reference.md](skills/design/resources/gherkin-spec-reference.md):

| Tag | Purpose | Required? |
|-----|---------|-----------|
| `@layer(api\|ui\|full-stack\|cli\|infra\|gameplay)` | Deterministic skip signal — drives which role agents apply per spec | Required on every spec (exactly one) |
| `@trivial` | Typo/rename/config-only change — the single verification-scaling knob, set at decomposition only | Optional |
| `@touches-data` | Spec adds/modifies/migrates persistent data — triggers `data-architect` even on UI specs | Optional |
| `@surface(game)` | Routes the spec's UI design to `game-ui-designer` instead of `uiux-designer` | Optional (game projects) |
| `@visual-pixel-diff` | Opts the spec into pixel-diff verification (structural mockup diff is always on) | Optional |
| `@integration` | Marks the one spec that assembles all features into the running product. Carries a `## Mount Map`. Required when an epic has ≥2 `@layer(ui\|full-stack)` specs | Conditional |
| `@mounts-in(<integration-slug>)` | On a UI feature: declares which `@integration` spec mounts it | Required on UI features in ≥2-UI-spec epics |
| `@mount-skip(reason)` | Override: this UI feature is mounted by another feature (not the shell), or otherwise legitimately not in the Mount Map | Optional |
| `@integration-skip(reason)` | Override: this epic legitimately has no single assembly owner despite ≥2 UI specs | Optional |

### Parallel-dispatch pattern

To dispatch multiple role agents concurrently (e.g. `security-architect` + `devops-architect` + `data-architect` for Step 3.3 review), include MULTIPLE `Agent` tool calls in a SINGLE message. Calls split across separate messages serialize. Verify by confirming the dispatching message contained multiple `Agent` calls.

### Inline-synthesis fallback

If the `Agent` tool is unavailable in your session (e.g., the orchestrator is itself a dispatched subagent), fall back to inline synthesis: read each role's `agents/<role>.md` prompt, perform the work yourself, and produce the same handoff file at the same path with `<meta data-synthesized="true">` in the head (schema doc, "Required `<meta>` attributes"). Include `@handoff-author-skip(<role>: <reason>)` in the handoff content — `guard-handoff-owner.sh` otherwise blocks handoff writes when no dispatch to that role was logged this session. The audit trail stays schema-compliant, and `release-coordinator` reports synthesized-vs-dispatched counts in its verdict block; what's lost is diversity-of-perspective (independently-prompted role agents push back on the orchestrator and surface disagreements; inline synthesis cannot).

### Validation

Three deterministic suites validate the workflow itself. Run each from the repo root:

- **`bash tests/role-agent-smoke.sh`** — exercises the hook layer with real tool-call payloads: block/allow/override behavior per gate, handoff schema validation, override-reason quality validation, and installed-form regressions from past dogfood runs (e.g. the `*.py`-helper install gap, bd's uppercase `[EPIC]` prefix, beads' molecule auto-close bypassing the epic-close gate). It runs fully sandboxed (throwaway HOME + scratch project + throwaway bd db — zero writes to your real beads db, state, or override ledger) and prints its own `Total / Pass / Fail / Skip` — currently 216 checks (213 run by default; 3 installed-form checks behind `--installed`).
- **`bash tests/install-roundtrip.sh`** — fresh `git clone` + install → uninstall inside a sandboxed `HOME`; verifies the manifest-driven settings surgery leaves pre-existing user hooks intact and no dangling symlinks behind. Never touches your real `~/.claude`.
- **`bash tools/lint-consistency.sh`** — enforces the canonical vocabulary in `docs/registry.md` (step ids, handoff filename grammar, override tags, hook/agent references, banned retired tokens) across skills, agents, hooks, docs, README, and AGENTS.md.

## What's Included

```
.
├── install.sh                          # Installer: links skills/agents/hooks, merges settings, writes manifest (--yes for non-interactive)
├── uninstall.sh                        # Manifest-driven: removes exactly what install recorded
├── AGENTS.md                           # Agent instructions (beads onboarding, shell safety)
├── EVALUATION-2026-07-04.md            # Full external evaluation that drove the current fix plan
├── skills/
│   ├── design/SKILL.md                 # /design — Socratic questioning + spec generation
│   │   └── resources/gherkin-spec-reference.md   # Spec format + tag usage guidance
│   ├── design-ui/SKILL.md              # /design-ui — UI/UX pipeline: PRODUCT.md, mockups, quality gates
│   ├── design-arch/SKILL.md            # /design-arch — Architecture docs, diagrams, overview.html
│   ├── build/SKILL.md                  # /build — Spec-driven TDD + verify pass 3.3a–3.3i
│   ├── respec/SKILL.md                 # /respec — Modify specs with blast radius tracing
│   ├── onboard/SKILL.md                # /onboard — Brownfield bootstrap of per-agent memory files
│   │   └── resources/                  # 16 per-role memory templates + game-context-template.md
│   └── workflow-retrospective/SKILL.md # Incident triage + metrics + override-ledger analysis
├── agents/                             # 16 role-agent personas dispatched via the Agent tool
│   ├── product-owner.md                # Socratic questioning, reality check
│   ├── application-architect.md        # Decomposition, arch docs, blast radius
│   ├── game-designer.md                # Core loop, player verbs (game projects, Step 2.3)
│   ├── level-designer.md               # Space, pacing, encounters (game projects, Step 2.7)
│   ├── narrative-designer.md           # Story, characters, lore (game projects, Step 2.7)
│   ├── systems-designer.md             # Progression math, economy (game projects, Step 2.7)
│   ├── uiux-designer.md                # Wraps /design-ui invocation + /impeccable gates
│   ├── game-ui-designer.md             # Game UI — replaces uiux-designer for @surface(game) specs
│   ├── security-architect.md           # Threat model, OWASP review (Step 3.3d)
│   ├── devops-architect.md             # Deployment, observability, scaling, rollback (Step 3.3e)
│   ├── data-architect.md               # Schema, migration safety, query plans (Steps 3.1 + 3.3f)
│   ├── backend-engineer.md             # TDD on @layer(api|cli|infra) + full-stack API (Step 3.2)
│   ├── frontend-engineer.md            # TDD on @layer(ui) + full-stack UI + wiring (Steps 3.2 + 3.2.5)
│   ├── qa-engineer.md                  # Authoritative per-spec verification + e2e CUJ tests (Steps 3.3g + 4.1)
│   ├── spec-sre-auditor.md             # Intent + SRE-grade rigor audit (Step 3.3h)
│   └── release-coordinator.md          # Epic close + rollback plan (Step 4.2)
├── hooks/                              # 35 files: 31 hook entry points + _common.sh + 3 Python helpers
│   ├── _common.sh                      # Shared utilities: session-keyed state dirs, python discovery, context encoding
│   ├── _validate_handoff.py            # HTML handoff schema validator (used by require-handoff-artifact.sh)
│   ├── _validate_override_reason.py    # Override-reason quality validator + override-audit.log appender
│   ├── _detect_memory_secrets.py       # Secret-shape detector (used by guard-agent-memory-secrets.sh)
│   ├── beads-auto-resume.sh            # Surfaces in-progress work + spec statuses on session start
│   ├── block-status-during-verification.sh # Blocks status writes + bd close while a verifier is in-flight
│   ├── block-unread-edits.sh           # Blocks edits on files that haven't been read first
│   ├── check-open-beads.sh             # Warns about open tasks + non-verified specs on session end
│   ├── claim-vs-call-audit.sh          # Blocks UI-spec verification unless /impeccable gates actually fired
│   ├── clear-session-reads.sh          # Resets THIS session's state dir on startup/clear (state is session-keyed)
│   ├── detect-correction.sh            # Detects user corrections, prompts incident logging
│   ├── guard-agent-memory-secrets.sh   # Blocks secret-shaped writes to .claude/agent-memory/
│   ├── guard-handoff-owner.sh          # Blocks handoff writes when the role was never dispatched this session
│   ├── guard-spec-bash-writes.sh       # Best-effort block of Bash writes to specs/*.md that bypass Edit/Write gates
│   ├── molecule-autoclose-warn.sh      # Warns when beads auto-closes an epic via molecule promotion
│   ├── remind-integration-tests.sh     # Reminds to write integration tests when committing without any
│   ├── require-bead-description.sh     # Enforces --description on bd create
│   ├── require-design-ui.sh            # Blocks @status(approved) on UI specs without design artifacts
│   ├── require-feature-mounted.sh      # Blocks UI-feature verification when not in the @integration Mount Map (anti-orphan)
│   ├── require-fix-cycle-handoff.sh    # Blocks @status(verified) when fix-cycle handoffs are asymmetric
│   ├── require-handoff-artifact.sh     # Blocks @status(verified) without the required role-agent handoff chain
│   ├── require-investigation-findings.sh # Blocks @status(implemented) without ## Investigation Findings
│   ├── require-layer-tag.sh            # Blocks @status(approved|implemented|verified) without @layer(...)
│   ├── require-release-handoff.sh      # Blocks bd close <epic> without release-coordinator handoff
│   ├── require-ui-tests.sh             # Blocks UI-spec verification without a referencing test file
│   ├── require-verifier-agents.sh      # Blocks @status(verified) without code-reviewer dispatch
│   ├── track-agent-memory-baseline.sh  # Records pre-dispatch mtime of the role's memory file
│   ├── track-agents.sh                 # Logs every Agent dispatch AND return (PreToolUse + PostToolUse)
│   ├── track-reads.sh                  # Tracks Read/Grep/Glob calls
│   ├── track-skills.sh                 # Logs every Skill invocation to session state
│   ├── verifier-dispatch.sh            # Tracks when Continuous Verifier is dispatched
│   ├── verifier-return.sh              # Tracks verifier results, blocks premature closure
│   ├── warn-agent-memory-not-updated.sh # Warns when a role agent returns without updating its memory file
│   ├── workflow-reminder.sh            # Context-aware reminder (/design vs /build)
│   └── wwiwo.sh                        # "What Was I Working On?" — beads + spec status
├── docs/
│   ├── registry.md                     # CANONICAL vocabulary: step ids, handoff grammar, verdicts, tags, override tags
│   ├── role-agent-handoff-schema.md    # HTML handoff format reference (meta attrs + section contract)
│   ├── agent-protocol.md               # Shared exit / questioning / memory / tool rules for all role agents
│   ├── harness-behavior.md             # Empirically verified Claude Code harness facts (version-stamped)
│   ├── incidents.md                    # Incident ledger — the failures that produced the rules
│   ├── engineering-standards.md        # Shared code-quality rubric for implementers + reviewers
│   ├── engineering-standards/          # Per-language idiom notes (go, rust, python, typescript-react, …)
│   └── decisions/                      # Decision records (0001: enforcement architecture)
├── tools/
│   └── lint-consistency.sh             # Registry-vocabulary linter (step ids, tags, hook/agent refs)
├── tests/
│   ├── role-agent-smoke.sh             # Hook behavior suite — run it; it prints Total/Pass/Fail
│   └── install-roundtrip.sh            # Sandboxed fresh-clone install → uninstall roundtrip
├── specs/                              # Gherkin spec files (per-project, not shipped)
│   ├── handoffs/                       # Role-agent HTML handoffs (created by experimental branch)
│   ├── mockups/                        # UI component mockups (Storybook or HTML)
│   └── diagrams/                       # Architecture diagrams (.drawio)
├── plans/
│   └── active/                         # Local task directories for in-progress work
└── benchmarks/                         # A/B benchmark tasks + testing protocol
```

## Prerequisites

**Hard requirements** (install.sh aborts without them):

- [Claude Code](https://claude.ai/code) installed
- `git` — the hooks and skills assume a git repository per project
- `python3` — used by the installer, the settings merge, and the hook validators

**Warn-only** (install proceeds, functionality degrades):

- [beads](https://github.com/steveyegge/beads) — the `bd` CLI plus its Claude Code plugin. Nine hooks degrade without `bd`; in particular `require-release-handoff.sh` exits permissive, so the epic-close gate stops gating.
- [hyperpowers](https://github.com/withzombies/hyperpowers) plugin enabled (marketplace: `withzombies-hyper`) — several role agents dispatch `hyperpowers:*` subagents
- `impeccable` plugin enabled, for the UI/UX design pipeline (installed via its Claude Code plugin marketplace; no public repo URL)
- `frontend-design` plugin enabled, for visual aesthetics (installed via the `claude-plugins-official` plugin marketplace)
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
# Non-interactive (assumes "yes" for optional prompts):
./install.sh --yes
```

The installer:
- Validates `~/.claude/settings.json` is parseable JSON before touching anything
- Links skills to `~/.claude/skills/` — `SKILL.md` plus each skill's `resources/` directory, so agent-referenced templates resolve post-install (edits in the repo are instantly live)
- Links agents to `~/.claude/agents/` (one symlink per file in `agents/`)
- Links hooks to `~/.claude/hooks/` (both `*.sh` and `*.py` helpers — same as skills, no manual sync needed)
- Merges hook config into `~/.claude/settings.json` (backs up first; deduplicates at the command level, so re-running is safe)
- Optionally disables the superpowers plugin (`--yes` assumes yes; non-interactive without `--yes` leaves it as-is)
- Writes `~/.claude/workflow-install-manifest.json` recording every link, backup, and settings command it added — `uninstall.sh` consumes this manifest

**Switching branches.** Run `git checkout <branch>` in `~/.claude/workflow`, then `./install.sh` again. The installer is dedup-aware at the command level, so re-installation correctly refreshes symlinks without duplicating hook registrations in `settings.json`.

**Restart Claude Code after install** — the subagent registry loads at session start. Newly-installed role agents won't be dispatchable as `subagent_type=<role>` until you `/clear` or start a fresh session. Hooks reload on every tool call so they're always current, but agent types are registered once. If you try to dispatch a newly-installed agent and get `Agent type '<name>' not found`, that's the symptom — restart and retry.

**Verifying the install:**

```bash
# Hook behavior suite — sandboxed; prints Total/Pass/Fail/Skip (216 checks; add --installed for the 3 installed-form checks):
bash tests/role-agent-smoke.sh
# Install → uninstall roundtrip in a sandboxed HOME (never touches your real ~/.claude):
bash tests/install-roundtrip.sh
```

On macOS/Linux, symlinks are used. On Windows, hard links are used (no
Developer Mode or Admin prompt required, but source and target must be on
the same drive).

## Starting a Project

The workflow operates per-project:

1. **Git repository required** — the hooks and specs assume one. `git init` if the directory isn't a repo yet.
2. **`bd init`** in the project root — creates the project's beads database (the task tracker every skill and nine hooks depend on).
3. **`/design`** for new work — or **`/onboard` first on an existing codebase** (brownfield), so role agents have per-project memory before designing or building.

## Usage

After installation, restart Claude Code (or `/clear`). Then:

1. **`/design`** — Start new work. Relentless Socratic questioning shapes the design (minimum 3 rounds for greenfield), invokes `/design-ui` for UI-facing work, Gherkin specs with Critical User Journeys are generated, CUJ coverage analysis catches missing specs, architecture docs are created, beads epic is set up.
2. **`/design-ui`** — UI/UX design pipeline. Auto-invoked by `/design` for UI-facing specs, also callable independently. Creates PRODUCT.md + DESIGN.md, generates mockups in `specs/mockups/`, runs quality gates.
3. **`/design-arch`** — Generate architecture documentation independently (also auto-invoked by `/design`).
4. **`/build`** — Implement approved specs. Auto-iterates through specs in dependency order: investigate, TDD, verify, API integration check, user sign-off. Playwright e2e tests verify CUJs before epic close. Use `--auto` for autonomous runs without sign-off pauses.
5. **`/respec`** — Modify existing specs when requirements change or bugs surface. Traces blast radius and propagates changes.
6. **Auto-resume** — On session start, you'll see in-progress beads work AND spec statuses
7. **Type `wwiwo?`** — Shows beads tasks + spec statuses at any time
8. **After 3+ completed epics** — Run `/workflow-retrospective` to analyze effectiveness (/build's Step 4.8 checks the trigger automatically at epic close and prompts when a retro is due)
9. **Run benchmarks** — See the `benchmarks/` directory for the A/B testing protocol and benchmark tasks

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

The authoritative tag vocabulary — including `@layer(...)`, `@surface(game)`, `@trivial`, `@touches-data`, the mount/integration tags, and every override tag — is [docs/registry.md](docs/registry.md) §7–§8.

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

Hooks are organized by event. Most are deterministic gates that block on missing prerequisites (`@status` transitions, missing handoffs, etc.). Each has a documented override path when the block is genuinely a false positive — never silently ignore an unexpected block (see [When a Hook Blocks You](#when-a-hook-blocks-you)). Hook state is keyed by project + session (`~/.claude/hooks/state/<project-hash>/<session-id>/`), so concurrent sessions no longer clobber each other's evidence. The full override-tag table is [docs/registry.md](docs/registry.md) §7.

### SessionStart

| Hook | What It Does |
|------|--------------|
| `beads-auto-resume.sh` | Checks for in-progress beads work + Gherkin spec statuses |
| `clear-session-reads.sh` | Resets THIS session's state dir (reads, agents, skills, in-flight verifiers) on `startup`/`clear`; compaction retains state — it is not a new session |

### PreToolUse — Edit / Write (gates spec-status transitions)

| Hook | What It Does |
|------|--------------|
| `block-unread-edits.sh` | Blocks edits on files that haven't been read first (new-file creation is allowed) |
| `require-design-ui.sh` | Blocks `@status(approved)` on UI-facing specs missing PRODUCT.md, DESIGN.md, or mockups. Escape hatch: `@layer(api\|cli\|infra)` specs skip automatically. |
| `require-layer-tag.sh` | Blocks `@status(approved\|implemented\|verified)` on specs without `@layer(api\|ui\|full-stack\|cli\|infra\|gameplay)`; suggests `gameplay` on game projects |
| `require-investigation-findings.sh` | Blocks `@status(implemented)` unless `## Investigation Findings` has ≥2 `file:line` references + a `Decision:` line. Override: `@investigation-skip(reason)`. Auto-allows `@trivial`. |
| `require-verifier-agents.sh` | Blocks `@status(verified)` without a `hyperpowers:code-reviewer` Agent dispatch in this session referencing the spec slug. Override: `@verifier-skip(reason)`. |
| `block-status-during-verification.sh` | Blocks status edits while a Continuous Verifier is in-flight (session-keyed in-flight markers) |
| `require-ui-tests.sh` | Blocks `@status(verified)` on `@layer(ui\|full-stack)` specs without a test file referencing the slug. Auto-detects Playwright/Cypress/Detox/Vitest/Jest-RTL/XCUITest. Override: `@ui-test-skip(reason)`. |
| `require-feature-mounted.sh` | Blocks `@status(verified)` on a `@layer(ui\|full-stack)` feature in a ≥2-UI-spec epic unless it is in an `@integration` spec's `## Mount Map` (or imported by the app entry). Prevents the disconnected-demo-cards failure. Override: `@mount-skip(reason)` / `@integration-skip(reason)`. |
| `require-handoff-artifact.sh` | (experimental branch) Blocks `@status(verified)` without the role-agent handoff chain present + schema-compliant. Expected chain follows `@layer(...)`, plus `data-architect` when `@touches-data`, plus the game roles on game projects. Override: `@handoff-skip(role: reason)`, one per skipped role. Auto-allows `@trivial`. |
| `require-fix-cycle-handoff.sh` | (experimental branch) Blocks `@status(verified)` when fix-cycle handoffs are asymmetric — an implementer `-fix-cycle-N` file without the reviewer's re-verification, or vice versa. Override: `@fix-cycle-skip(N: reason)`. |
| `guard-handoff-owner.sh` | (experimental branch) Blocks writing `specs/handoffs/<step>-<slug>-<role>.html` when no dispatch to `<role>` was logged this session — the handoff is the agent's deliverable, not the orchestrator's. Override: `@handoff-author-skip(role: reason)` (legitimate for inline synthesis). |
| `guard-agent-memory-secrets.sh` | Blocks writes to `.claude/agent-memory/*.md` containing secret-shaped strings (JWTs, AWS keys, Stripe keys, PEM blocks, …) — memory is committed to git. Override: `@memory-allow-secret(reason)`. |
| `claim-vs-call-audit.sh` | Blocks `@status(verified)` on UI-bearing specs unless all 5 `/impeccable` gates (critique, audit, harden, clarify, adapt) fired via the Skill tool in this session for that slug. Override: `@gate-skip(<gate>: reason)`. |

### PreToolUse — Bash

| Hook | What It Does |
|------|--------------|
| `require-bead-description.sh` | Enforces `--description` flag on `bd create` |
| `remind-integration-tests.sh` | Reminds to write integration tests when committing source without any staged |
| `block-status-during-verification.sh` | Also registered on Bash: blocks `bd close` / `bd update --status` while a verifier is in-flight |
| `guard-spec-bash-writes.sh` | Best-effort block of Bash commands that write to `specs/*.md` (`cat >`, `sed -i`, `tee`, etc.) — spec edits must go through Edit/Write so the gate hooks audit them |
| `require-release-handoff.sh` | (experimental branch) Blocks `bd close <epic-id>` without a release-coordinator handoff with verdict `READY-TO-CLOSE` or `READY-WITH-CAVEATS`. Override: `@release-skip(reason)` in a spec, or `bd comments add <epic> "RELEASE-SKIP: <reason>"`. |

### PreToolUse — Agent

| Hook | What It Does |
|------|--------------|
| `verifier-dispatch.sh` | Tracks when Continuous Verifier is dispatched (session-keyed in-flight marker) |
| `track-agent-memory-baseline.sh` | Records the pre-dispatch mtime of the dispatched role's `.claude/agent-memory/<role>.md` |
| `track-agents.sh` | Logs every Agent dispatch at dispatch time (consumed by `require-verifier-agents` and `guard-handoff-owner`) |

### PostToolUse

| Hook | Event | What It Does |
|------|-------|--------------|
| `track-reads.sh` | Read/Grep/Glob | Tracks which files have been read (paired with `block-unread-edits`) |
| `track-agents.sh` | Agent | Also logs every Agent return — dispatch AND return records feed the gate hooks |
| `warn-agent-memory-not-updated.sh` | Agent | Warns (does not block) when a role agent returns without touching its memory file. Override: `@memory-update-skip(role: reason)` in the dispatch prompt. |
| `track-skills.sh` | Skill | Logs every Skill invocation — consumed by `claim-vs-call-audit` |
| `verifier-return.sh` | Agent | Logs verifier verdict to bd, removes the in-flight marker |
| `molecule-autoclose-warn.sh` | Bash | (experimental branch) Warns when `bd close <child>` triggered beads' internal molecule auto-close on the parent epic, bypassing `require-release-handoff.sh` |

### UserPromptSubmit / Stop

| Hook | Event | What It Does |
|------|-------|--------------|
| `workflow-reminder.sh` | UserPromptSubmit | Context-aware: suggests `/build` if approved specs exist, `/design` if not |
| `detect-correction.sh` | UserPromptSubmit | Detects user corrections; prompts incident logging for the retrospective |
| `wwiwo.sh` | UserPromptSubmit | Shows beads tasks + Gherkin spec statuses when the prompt contains `wwiwo` (filtering happens inside the script — the harness ignores UserPromptSubmit matchers, see `docs/harness-behavior.md`) |
| `check-open-beads.sh` | Stop | Warns about open beads tasks + non-verified specs on session end |

### Python helpers (not hooks themselves)

| File | What It Does |
|------|--------------|
| `_common.sh` | Shared utilities: session-keyed state dirs, python discovery, `hookSpecificOutput` context encoding |
| `_validate_handoff.py` | HTML handoff schema validator invoked by `require-handoff-artifact.sh`. Handoff-level override: `data-resolution-skip="reason"` attribute. |
| `_validate_override_reason.py` | Quality-validates every override reason; appends passes to `~/.claude/hooks/state/override-audit.log` |
| `_detect_memory_secrets.py` | Secret-shape detector invoked by `guard-agent-memory-secrets.sh` |

## When a Hook Blocks You

A block is the workflow working as designed: it names a missing artifact, and the right response is almost always to produce that artifact, not to bypass the gate. The five most-hit gates:

| Gate | The block means | What to actually do | Override tag |
|------|-----------------|---------------------|--------------|
| `require-handoff-artifact.sh` | You wrote `@status(verified)` but a required role-agent handoff is missing or schema-invalid | Dispatch the missing role agent(s) so they produce their handoffs (or inline-synthesize per the documented fallback) | `@handoff-skip(role: reason)` in the spec |
| `require-verifier-agents.sh` | No `hyperpowers:code-reviewer` dispatch referenced this spec's slug this session | Dispatch the code-reviewer agent against the spec before writing `@status(verified)` | `@verifier-skip(reason)` in the spec |
| `require-feature-mounted.sh` | The UI feature isn't assembled into the product — not in the `@integration` spec's Mount Map, not imported by the app entry | Mount the feature: add it to the Mount Map and wire the actual import/route | `@mount-skip(reason)` / `@integration-skip(reason)` in the spec |
| `require-ui-tests.sh` | No functional UI test file references this spec's slug | Write the functional test (Playwright/Cypress/Detox/Vitest/…) that exercises the feature | `@ui-test-skip(reason)` in the spec |
| `require-release-handoff.sh` | `bd close <epic>` attempted without a release-coordinator verdict of `READY-TO-CLOSE` / `READY-WITH-CAVEATS` | Dispatch `release-coordinator` to produce the `step-4.2` handoff | `@release-skip(reason)` in a spec, or `bd comments add <epic> "RELEASE-SKIP: <reason>"` |

**Override reasons are quality-validated** by `_validate_override_reason.py`, not just syntax-checked:

- ≥30 characters after trimming
- at least one concrete reference — a commit SHA, beads ID, file path, URL, or explicit user authorization
- no stop-phrase-only reasons ("covered elsewhere", "not needed", …) — these are rejected even at length

Every override that passes validation is appended to `~/.claude/hooks/state/override-audit.log`, which `/workflow-retrospective` reads: any gate overridden ≥3 times in an analysis window automatically becomes a retro finding. The bypass persists as audit trail — that's the point. The complete tag-to-hook table is [docs/registry.md](docs/registry.md) §7.

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

The **workflow-retrospective** skill provides a data-driven feedback loop for continuous improvement. It reads incident logs, quantitative metrics, and the gate override ledger, triages incidents by pattern frequency, and drafts actual skill file edits for recurring patterns. /build's Step 4.8 checks the trigger at every epic close (≥3 closed epics or ≥10 accumulated incidents since the last retro) and prompts when one is due.

### What It Analyzes

| Data Source | What It Reveals |
|-------------|-----------------|
| `WORKFLOW INCIDENT:` comments | Pain points, skill gaps, missing rules, edge cases |
| `VERIFICATION FAILURE:` comments | Where verification catches issues |
| `~/.claude/hooks/state/override-audit.log` | Which gates get bypassed and why — any gate overridden ≥3 times in the window is automatically a finding |
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
1. **Gather** — Queries beads for closed epics, tasks, incident + verification comments, and reads the override ledger
2. **Analyze/Triage** — Calculates metrics, triages incidents by category+skill frequency, clusters overrides by gate
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

## Reference Docs

Four documents anchor the system's vocabulary and institutional memory:

- **[docs/registry.md](docs/registry.md)** — the single source of truth for machine-level vocabulary: step ids, handoff filename grammar, verdict and severity values, routing targets, spec tags, and the full override-tag table. When a skill, agent, or hook disagrees with the registry, the other file is wrong. `tools/lint-consistency.sh` enforces it mechanically across the whole repo.
- **[docs/incidents.md](docs/incidents.md)** — the incident ledger: the documented failures that produced the workflow's rules, one stable anchor per incident. Skills and hooks cite entries by anchor instead of retelling the story inline. When a rule seems arbitrary, its incident is here.
- **[docs/agent-protocol.md](docs/agent-protocol.md)** — the shared protocol every role agent follows: exit checklist (handoff first, memory update, structured return), the orchestrator-mediated questioning loop (agents can't call AskUserQuestion — they return question lists), and memory read/write rules. Defined once here instead of copied into 16 prompts.
- **[docs/harness-behavior.md](docs/harness-behavior.md)** — empirically verified Claude Code harness facts (do settings hooks fire in subagents? which payload fields exist?), stamped with the version they were tested against. Re-verify the table when Claude Code upgrades; several answers contradict the published docs of the same era.

Also in `docs/`: [engineering-standards.md](docs/engineering-standards.md) (the shared code-quality rubric implementers follow and reviewers score against, with per-language idiom notes in `docs/engineering-standards/`), [role-agent-handoff-schema.md](docs/role-agent-handoff-schema.md) (handoff content contract), and `docs/decisions/` (decision records).

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
- **Verification never scales below the `@trivial` floor** — Full suite + code review agent + spec coverage check + API integration check on every spec. `@trivial` (set at decomposition, never during build) is the single scaling knob.
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

The uninstaller is manifest-driven — it consumes `~/.claude/workflow-install-manifest.json` and reverses exactly what install.sh recorded:

- Removes every link the manifest lists (only if it still points into this repo), restoring any `.pre-workflow` backup next to it
- Surgically removes exactly the settings hook commands install added, command by command — a matcher entry that still contains your own hooks is preserved with them intact (`settings.json` is edited in place, not restored wholesale; the `.pre-workflow` backup is kept and safe to delete)
- Reverses the superpowers-disable step if install performed it
- Deletes the manifest; leaves the repo itself untouched

Without a manifest it refuses to run — re-run `install.sh` once (it is idempotent and rewrites the manifest), then uninstall. `tests/install-roundtrip.sh` verifies this whole cycle in a sandbox.
