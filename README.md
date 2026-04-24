# Adaptive Developer Workflow for Claude Code

An enforced, spec-driven developer workflow with two skills: `/design` for Socratic planning and Gherkin spec generation, `/build` for spec-driven TDD implementation with dependency ordering and full verification.

## What It Does

Every task flows through two phases:

### /design — Shape the Work
1. **Socratic Questioning** — Ask focused questions via AskUserQuestion (blocks until answered). Internet research (`internet-researcher`) allowed to inform questions and validate feasibility.
2. **Decompose** — Apply independence test and seam analysis to break work into well-sized specs. Produces a decomposition map with `@depends-on` and `@parallel-risk` relationships.
3. **Validate Feasibility** — For external APIs/libraries, dispatch `internet-researcher` to verify technical claims before writing specs.
4. **Spec Generation** — Generate Gherkin-style Markdown spec files in `specs/`, one per entry in the decomposition map.
5. **Reality Check** — Agent pre-checks specs for gaps, shows dependency graph with parallel lanes, user confirms (can request re-decomposition).
6. **Beads Setup** — Create epic + Tests gate task referencing spec files.

### /build — Implement the Specs
1. **Entry Validation** — Verify specs exist with `@status(approved)`, check beads for open work
2. **Dependency Graph** — Parse `@depends-on` and `@parallel-risk` tags, topological sort for build order. Show graph with parallel lanes, user confirms execution plan.
3. **Per-Spec Iteration** (auto-iterates all specs in order):
   - **Investigate** — Codebase analysis, create informed beads task with real file paths
   - **TDD** — RED: failing tests from spec scenarios. GREEN: implement. REFACTOR.
   - **Verify** — Full test suite + code review + spec coverage + test effectiveness (NEVER scales down). Status updates blocked until verification agents return and pass.
   - **Update** — `@status(verified)`, close beads task
4. **Close** — Close epic, update README, save learnings

## What's Included

```
.
├── install.sh                          # One-command installer (symlinks + backup)
├── uninstall.sh                        # Restores originals and removes symlinks
├── skills/
│   ├── design/SKILL.md                 # /design — Socratic questioning + spec generation
│   ├── build/SKILL.md                  # /build — Spec-driven TDD + verification
│   ├── workflow-orchestrator/SKILL.md  # Deprecated — redirects to /design + /build
│   └── workflow-retrospective/SKILL.md # Metrics analysis skill
├── hooks/
│   ├── beads-auto-resume.sh            # Surfaces in-progress work + spec statuses on session start
│   ├── track-reads.sh                  # Tracks Read/Grep/Glob calls
│   ├── block-unread-edits.sh           # Blocks edits on unread files
│   ├── clear-session-reads.sh          # Resets read tracking per session
│   ├── require-bead-description.sh     # Enforces --description on bd create
│   ├── remind-integration-tests.sh     # Reminds to write integration tests after code review
│   ├── verifier-dispatch.sh            # Tracks verification agent dispatch
│   ├── verifier-return.sh              # Tracks verification results, blocks premature closure
│   ├── wwiwo.sh                        # "What Was I Working On?" — beads + spec status
│   ├── workflow-reminder.sh            # Context-aware reminder (/design vs /build)
│   └── check-open-beads.sh            # Warns about open tasks + non-verified specs on session end
├── specs/                              # Gherkin spec files (per-project, not shipped)
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
- `python3` available (used by installer and beads-auto-resume hook)
- A bash-compatible shell (bash on macOS/Linux, Git Bash on Windows)

## Installation

```bash
git clone <this-repo> ~/.claude/workflow
cd ~/.claude/workflow
./install.sh
```

The installer:
- Links skills to `~/.claude/skills/` (edits in the repo are instantly live)
- Links hooks to `~/.claude/hooks/` (same - no manual sync needed)
- Merges hook config into `~/.claude/settings.json` (backs up first)
- Optionally disables the superpowers plugin (recommended)

On macOS/Linux, symlinks are used. On Windows, hard links are used (no
Developer Mode or Admin prompt required, but source and target must be on
the same drive).

## Usage

After installation, restart Claude Code (or `/clear`). Then:

1. **`/design`** — Start new work. Socratic questioning shapes the design, Gherkin specs are generated, reality check confirms with you, beads epic is created.
2. **`/build`** — Implement approved specs. Auto-iterates through specs in dependency order: investigate, TDD, verify.
3. **Auto-resume** — On session start, you'll see in-progress beads work AND spec statuses
4. **Type `wwiwo?`** — Shows beads tasks + spec statuses at any time
5. **After 3+ completed epics** — Run `/workflow-retrospective` to analyze effectiveness
6. **Run benchmarks** — Use `benchmarks/AB-TESTING-PROTOCOL.md` for quantitative comparison

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

| Hook | Event | What It Does |
|------|-------|-------------|
| `beads-auto-resume.sh` | SessionStart | Checks for in-progress beads work + Gherkin spec statuses |
| `clear-session-reads.sh` | SessionStart | Resets file read tracking so each session starts fresh |
| `block-unread-edits.sh` | PreToolUse (Edit/Write) | Blocks edits on files that haven't been read first |
| `require-bead-description.sh` | PreToolUse (Bash) | Enforces `--description` flag on `bd create` commands |
| `track-reads.sh` | PostToolUse (Read/Grep/Glob) | Tracks which files have been read (used by block-unread-edits) |
| `remind-integration-tests.sh` | PostToolUse (Agent) | Reminds to write integration tests after code review agents return |
| `verifier-dispatch.sh` | PreToolUse (Agent) | Tracks when verification agents are dispatched |
| `verifier-return.sh` | PostToolUse (Agent) | Tracks verification agent results; blocks premature task closure |
| `wwiwo.sh` | UserPromptSubmit (matcher: `wwiwo`) | Shows beads tasks + Gherkin spec statuses |
| `workflow-reminder.sh` | UserPromptSubmit | Context-aware: suggests `/build` if approved specs exist, `/design` if not |
| `check-open-beads.sh` | Stop | Warns about open beads tasks + non-verified specs on session end |

## Workflow Retrospective

The **workflow-retrospective** skill provides a data-driven feedback loop for continuous improvement. It analyzes your completed work to find what's working and what needs tuning.

### What It Measures

| Metric | Target | What It Reveals |
|--------|--------|-----------------|
| First-pass verification rate | >80% | How often code passes verification without rework |
| Rework rate | <20% | How often tasks need fix-verify cycles |
| Error type distribution | - | Pattern mismatches vs edge cases vs integration failures |
| Phase effectiveness | - | Which phases catch errors (earlier = cheaper to fix) |

### How to Run

```
/workflow-retrospective
```

The skill runs a 5-step process:
1. **Gather** - Queries beads for closed epics, tasks, and verification failure comments
2. **Analyze** - Calculates metrics and identifies trends
3. **Report** - Presents a structured dashboard with tables
4. **Propose** - Recommends specific workflow adjustments based on the data
5. **Save** - Persists key findings to memory for cross-session awareness

### When to Run

- **After every epic** - quick metrics capture (5 min)
- **Weekly during active use** - full analysis with trend detection (15 min)
- **Monthly** - comprehensive cross-project trend analysis (30 min)

### Getting Started on a New Machine

The retrospective needs completed beads epics to analyze. After a fresh install:
1. Work through 3+ epics using /design + /build
2. Run `/workflow-retrospective` for your first analysis
3. The skill handles limited data gracefully - it notes data limitations and tells you when to re-run

## Design Principles

- **Two skills, one workflow** — /design shapes work through questioning and specs; /build implements through TDD and verification. Clear separation of concerns.
- **Specs are the source of truth** — Gherkin spec files in `specs/` define what to build; beads tracks sub-task progress
- **Specs enable full rebuild** — For greenfield projects, specs capture enough detail to reconstruct the entire app
- **Specs are living documents** — Updated during implementation as edge cases are discovered, not frozen after planning
- **Decompose at natural seams** — Work is split into multiple specs using the independence test: if you can test it without the other thing existing, it's a separate spec. No arbitrary thresholds.
- **Parallelism is first-class** — Independent specs can be built in parallel. `@parallel-risk` flags file overlap without blocking. /build shows the dependency graph and asks before dispatching.
- **Research informs, never replaces asking** — Internet research during /design makes questions sharper and validates feasibility, but findings become questions to the user, not silent assumptions.
- **Spec-driven TDD** — Tests are generated FROM spec scenarios before implementation. No exceptions.
- **Verification never scales down** — Full suite + code review agent + spec coverage check on every spec
- **Verification gates completion** — Status updates and task closures are blocked until verification agents return results and pass. No "updating while waiting."
- **Questioning blocks on user answers** — AskUserQuestion tool required, no proceeding without answers
- **Tasks created after investigation** — /build creates beads tasks with real codebase context, not guesswork
- **Pause on spec drift** — Fundamental spec changes require /design, not silent fixes during /build
- **Dependency-ordered execution** — /build processes specs in `@depends-on` topological order
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
