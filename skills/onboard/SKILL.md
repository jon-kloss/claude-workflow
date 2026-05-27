---
name: onboard
description: Use when starting workflow on an existing codebase (brownfield) OR when accumulated codebase changes have outpaced agent memory. Bootstraps or refreshes per-agent memory files at .claude/agent-memory/<role>.md so role agents have project context before /design or /build. Three modes - full bootstrap, --refresh delta, single-agent refresh.
---

<skill_overview>
Brownfield-work primer for the role-agent workflow. Walks the existing codebase and dispatches each role agent to write its own memory file at `.claude/agent-memory/<role>.md`. Memory is hierarchical (~500-word summary + pointers to deeper docs/code paths) and committed to git so the team shares it. Each agent's role prompt is already set up to read memory at dispatch (Phase 1) and write to it at end of dispatch (final Phase) — `/onboard` performs the *initial seeding* and *bulk refresh*.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: Memory files NEVER contain actual secrets, tokens, or PII. The `guard-agent-memory-secrets.sh` hook blocks writes that match secret-shaped patterns; the agent prompts forbid it; you must as well.
- **RIGID**: Memory is committed (per-project, `.claude/agent-memory/`). The skill produces sensible, reviewable diffs — not dumps.
- **RIGID**: Bootstrap dispatches agents in dependency order. Later agents read earlier agents' just-written memory as context.
- **FLEXIBLE**: Memory file content is whatever the agent decides is worth remembering, within the template's section scaffold.
- **FLEXIBLE**: Refresh mode can be partial (single agent) or full delta (all agents that touched changed files).
</rigidity_level>

<quick_reference>
## Usage

```
/onboard                  # Full bootstrap — first time on a codebase
/onboard --refresh        # Delta refresh — re-scan after manual changes
/onboard <role-slug>      # Single-agent refresh (e.g. /onboard frontend-engineer)
```

## Output

```
<project-root>/
└── .claude/
    └── agent-memory/
        ├── product-owner.md
        ├── application-architect.md
        ├── security-architect.md
        ├── devops-architect.md
        ├── data-architect.md
        ├── uiux-designer.md
        ├── backend-engineer.md
        ├── frontend-engineer.md
        ├── qa-engineer.md
        ├── release-coordinator.md
        └── spec-sre-auditor.md
```

Each file is committed. **Soft cap ~3,500 words; hard cap ~6,000 words.** Agents prune to the soft cap during normal updates. Above the hard cap, content overflows into sub-files under `.claude/agent-memory/<role>/` — see [Multi-file overflow](#multi-file-overflow) below.
</quick_reference>

<when_to_use>
- Starting workflow runs (/design, /build) on a codebase that already has code
- After a significant chunk of manual work (refactor, new feature outside workflow runs) that the agents haven't seen yet
- When agent dispatches feel "fresh" each time despite the project being weeks old — that's the signal memory has decayed
- When a new role agent has been added and needs to be seeded for an existing project
</when_to_use>

<the_process>

## Step 1: Announce

"I'm using the /onboard skill to seed/refresh per-agent memory of this codebase."

## Step 2: Sanity check

```bash
# Project has code
[ -d src ] || [ -d app ] || [ -d lib ] || [ -d backend ] || [ -d frontend ] || echo "WARN: no obvious source directory found"

# beads initialized
[ -d .beads ] || echo "WARN: .beads/ not found — initialize beads before /onboard"

# git initialized
[ -d .git ] || (echo "FATAL: git not initialized — /onboard requires git for SHA tracking" && exit 1)

# Capture bootstrap baseline
BOOTSTRAP_SHA=$(git rev-parse HEAD)
echo "bootstrap SHA: $BOOTSTRAP_SHA"
```

If any sanity check fails, surface to user via AskUserQuestion before proceeding.

## Step 3: Mode selection

| Invocation | Mode | What happens |
|---|---|---|
| `/onboard` | **full bootstrap** | All 11 memory files (re)written from scratch. Existing files are backed up to `.claude/agent-memory/.backup-<timestamp>/`. |
| `/onboard --refresh` | **delta refresh** | `git diff <last-recorded-SHA>..HEAD --name-only` → identify changed paths → dispatch only the agents whose memory's Pointers reference those paths. Each agent reads its current memory + the diff, updates targeted sections. |
| `/onboard <role-slug>` | **single-agent refresh** | Dispatch one agent. Useful after a major refactor that touched its surface. |

If memory files already exist and full bootstrap is requested, AskUserQuestion: "Existing memory files found. Back up and rewrite (full bootstrap), or did you mean --refresh (delta update)?"

## Step 4: Create memory directory

```bash
mkdir -p .claude/agent-memory
```

## Step 5: Dispatch agents in dependency order

Order matters because later agents benefit from earlier agents' just-written memory. Each dispatch passes the prior agents' memory paths as context in the prompt.

```
1. application-architect → component map, seams, dep graph
2. data-architect → schema overview, indexes, FK convention, migrations
3. backend-engineer → routes, middleware, error shape, API client pattern
4. frontend-engineer → components, state-mgmt, design tokens, routing
5. uiux-designer → PRODUCT.md/DESIGN.md inventory, register, established patterns
6. security-architect → trust boundaries, auth model, secrets handling convention
7. devops-architect → deployment topology, observability stack, IaC patterns
8. qa-engineer → test framework, conventions, flakiness patterns
9. product-owner → README, CHANGELOG, accumulated scope decisions
10. release-coordinator → deployment history, git tags, known incidents
11. spec-sre-auditor → DEFERRED (seed on first real audit, not at bootstrap)
```

**Game-design agents (conditional).** When `.claude/game-context.md` exists in the project root, seed an additional 5 memory files. If the context file does NOT exist, skip the game agents entirely (this is a non-game project).

```
Game agents (only when .claude/game-context.md exists):
12. game-designer → core loop, verbs, win/loss, ten fun things, anti-features
13. level-designer → zone archetypes, pacing principles, anti-patterns dodged
14. narrative-designer → tone, lore-bible index, character voice index, branching shape
15. systems-designer → progression axes, balance principles, established constants, economy shape
16. game-ui-designer → diegesis posture, HUD pattern library, input model, accessibility commitments
```

If `.claude/game-context.md` is missing on a project the user identifies as a game, copy `skills/onboard/resources/game-context-template.md` to `.claude/game-context.md`, AskUserQuestion to confirm the fields, then proceed with the game-agent dispatches.

**Dispatch parallelism.** Agents 1–4 must serialize (later ones read earlier memory). Agents 5–10 can run in parallel. Game agents 12–16 also parallelize after agent 11 (or alongside 5–10 — they're independent). To dispatch in parallel, include MULTIPLE Agent tool calls in a SINGLE message (per the parallel-dispatch pattern in build/SKILL.md and design/SKILL.md).

**Per-role bootstrap scope (eager vs lazy).**

Some content is naturally bootstrap-eager (conventions, framework choices, topology) and stays in memory long-term. Other content is bootstrap-LAZY: it's tempting to capture at seed time but it goes stale fast AND isn't useful until the role is actually dispatched against a specific surface. Defer lazy content to first-use; populate it incrementally on real dispatches.

| Role | Bootstrap-LAZY (defer to first dispatch — stub only) |
|---|---|
| `qa-engineer` | Per-spec / per-cluster test inventory tables (which tests cover which spec). The bootstrap captures **framework, conventions, suite shape, flakiness patterns, visual-fidelity helpers**; per-spec mappings populate during real QA dispatches. |
| `backend-engineer` | Full route/method dispatch inventories beyond ~30 entries — capture the *namespace map* + ownership at bootstrap; per-method per-spec annotations populate during real implementer dispatches. |
| `frontend-engineer` | Per-component prop-shape annotations beyond the component map itself. Capture the inventory + ownership conventions; detailed prop docs accrete during real implementer dispatches. |
| `data-architect` | Per-table column-level annotations beyond ~20 tables. Capture the schema graph + migration conventions + index strategy; per-column constraints accrete during real data dispatches. |

All other roles bootstrap eagerly — their natural cap is well below 3,500 words.

**Dispatch prompt template:**

```
Agent tool (subagent_type: <role>, run_in_background: false):
"You are seeding your project memory at .claude/agent-memory/<role-slug>.md via the /onboard
skill (full bootstrap mode).

Read the project at its current state on disk. Read prior agents' memory in dispatch order:
<list of prior memory file paths>

Produce your memory file using the template structure at
skills/onboard/resources/memory-template-<role-slug>.md.

CRITICAL constraints:
- NEVER write actual secrets, tokens, API keys, passwords, PII, or real user data
- Use pointers to where secrets live (env file names, secret manager keys) — never values
- Memory is COMMITTED to git; treat every line as code review-visible by the team
- Stay under ~3,500 words total (soft cap). If a section grows beyond that, prefer Pointers to existing docs/code over inline content. Hard cap is 6,000 words; above that, follow the multi-file overflow protocol below.

Bootstrap-LAZY content for your role (defer — stub-only at bootstrap, populate on real dispatch):
<inserted per role from the table above. Empty for roles with nothing to defer.>

Frontmatter timestamp precision: set `last-updated` to the CURRENT timestamp at seconds
precision. Run `date -u +%Y-%m-%dT%H:%M:%SZ` (or equivalent) — do NOT write a date-stub
like 2026-05-26T00:00:00Z. The seconds-precision stamp is what /onboard --refresh's delta
detection compares against.

Cap memory at ~500 words for Summary + Conventions + Component map. Pointers section can
go to ~1500 words across all entries. If you have more to memorize than fits, prefer pointers
to your existing docs/code over verbose summaries.

Once written, return a SHORT confirmation (≤ 100 words): what you covered, what you skipped,
any sections that need follow-up dispatch."
```

For refresh mode, the dispatch prompt instead says:

```
"You are REFRESHING your memory at .claude/agent-memory/<role-slug>.md. Your current memory
file is below. The git diff since your last-recorded-SHA (<sha>) is below. Update only the
sections affected by the diff. Preserve unrelated content. Update last-updated and last-commit-sha
in frontmatter to HEAD. Set last-updated to the CURRENT timestamp at seconds precision
(date -u +%Y-%m-%dT%H:%M:%SZ) — never a date-stub like T00:00:00Z."
```

## Step 6: Validate each memory file

For each `.claude/agent-memory/<role>.md` produced:

1. **Frontmatter present** — `agent`, `project-root`, `last-updated`, `last-commit-sha`, `schema-version`.
2. **Frontmatter timestamp precision** — `last-updated` is a full ISO 8601 UTC timestamp at seconds precision (e.g. `2026-05-26T17:53:15Z`), NOT a date-stub (`2026-05-26T00:00:00Z`). Validate: `grep -L 'T00:00:00Z' .claude/agent-memory/*.md` should equal the full file list. Any file with `T00:00:00Z` → re-dispatch that single agent with "set last-updated to current `date -u +%Y-%m-%dT%H:%M:%SZ`" instruction. Rationale: `/onboard --refresh` delta detection compares timestamps, and a batch of files all stamped midnight UTC on the same day is indistinguishable from a manual edit.
3. **Required sections** — vary by role. Always required across all roles: `## Summary`, `## Recent changes`, `## Pointers`. Roles that hold conventions also require `## Conventions` (everyone EXCEPT `product-owner`, whose equivalents are scope decisions + open questions). Roles that surface deferred items also require `## Known issues` (everyone EXCEPT `product-owner`, whose deferred items are documented in scope-decisions + open-questions sections). Look up each role's expected sections from its template at `skills/onboard/resources/memory-template-<role>.md` — that's the canonical schema per role. At least one role-specific primary section per memory (Component map / Routes / Tables / Tokens / Personas / etc.).
4. **Word count** — total words ≤ 3,500 soft cap (`wc -w`). 3,500–6,000 is a warning (prune on next update). Above 6,000 (hard cap) → re-dispatch the agent with "compress to ~3,000 words or move overflow content into sub-files under `.claude/agent-memory/<role>/` per the multi-file overflow protocol" prompt.
5. **Bootstrap-LAZY guard for qa-engineer** — if `qa-engineer.md` contains a multi-row "Test inventory" / "Per-spec coverage" / "Tests by cluster" table at bootstrap, that's eager-inventory creep. The table belongs in lazy content (populated by real QA dispatches). Re-dispatch with "replace eager per-spec test inventory with a stub section; per-spec mappings populate during real QA dispatches" instruction.
6. **No secret-shaped strings** — `guard-agent-memory-secrets.sh` enforces this on write, but also re-validate on read: `grep -E '(Bearer\s+eyJ|sk_live_|AKIA[0-9A-Z]{16}|-----BEGIN.*PRIVATE KEY)' .claude/agent-memory/*.md` returns empty.

## Step 7: Present and offer commit

Show the user:
- Which agents successfully wrote memory
- Any that failed validation (and the failure reason)
- A `git diff .claude/agent-memory/` summary

AskUserQuestion: "Commit the memory files? (Yes / Review first / No)"

If yes: `git add .claude/agent-memory/ && git commit -m "chore: bootstrap agent memory via /onboard"`

</the_process>

<integration>

## How memory plugs into /design and /build

**Agent dispatch Phase 1** (every role agent's prompt has this):
1. Read `.claude/agent-memory/<your-role>.md` — internalize Summary + Conventions + Recent changes
2. Drill into Pointers section only if the current task references something in there
3. Then read the spec, prior handoffs, etc.

**Agent dispatch final Phase** (every role agent's prompt has this):
1. Identify what changed during this dispatch that future-you should know
2. Edit `.claude/agent-memory/<your-role>.md` — update Recent changes (rolling cap of 5), update Component map / Routes / Tables / Tokens with new entries, update Conventions if you established new patterns, update Known issues with deferred items
3. Update `last-updated` and `last-commit-sha` frontmatter to HEAD
4. NEVER write actual secrets

**Handoff `data-input-references`** can include memory paths:

```html
<meta data-input-references="specs/handoffs/step-2-foo-product-owner.html .claude/agent-memory/backend-engineer.md">
```

This makes the audit trail include "this dispatch built on accumulated memory" — not just on the immediate prior handoff.

## How memory interacts with hyperpowers:codebase-investigator

Memory and the investigator coexist with distinct scopes:

| | Memory | codebase-investigator |
|---|---|---|
| Scope | **Project-level** (conventions, structure) | **Spec-level** (patterns relevant to this spec) |
| Lifespan | Persists across sessions | Fresh per spec |
| Updated by | Each role agent at dispatch end | Each /build investigation step |
| Audience | All role agents on this project | The specific agent implementing this spec |

The investigator's output gets folded into the relevant role agent's memory at the end of /build (the agent's "update memory" final phase reads the Investigation Findings and adds anything project-level to memory).

## Multi-file overflow

<a id="multi-file-overflow"></a>

For agents working in medium-or-larger codebases, certain sections grow naturally beyond the soft 3,500-word cap:

- `backend-engineer` Routes table — easily 50+ routes × ~25 words = 1,250+ words of just that section
- `frontend-engineer` Component map — 30-50 components
- `data-architect` Schema overview — 15-30 tables + indexes

When the main `.claude/agent-memory/<role>.md` file approaches the 6,000-word hard cap, the agent splits content into role-scoped sub-files:

```
.claude/agent-memory/
├── backend-engineer.md             # main: ≤ 3,500 words, TOC + Summary + Conventions + Recent + Pointers
└── backend-engineer/
    ├── routes.md                   # overflow: the full Routes inventory
    └── middleware.md               # overflow: full middleware-stack detail
```

**Protocol when a section overflows:**

1. Move the overflowing section's body into `.claude/agent-memory/<role>/<section>.md` (lowercase-hyphenated section name).
2. In the main file, replace the body with a 1-paragraph summary + a pointer to the sub-file:

   ```markdown
   ## Routes

   50 server routes across 8 feature areas (auth, lists, tasks, search, export, prefs, health, admin). Full inventory at [`backend-engineer/routes.md`](backend-engineer/routes.md). Add new routes there; update the count + feature-area list here.
   ```

3. Sub-files have their own short frontmatter (just `agent` + `last-updated`) so they're identifiable.
4. The agent reads the main file at Phase 1 always; reads sub-files ONLY when the current task references that section's content (e.g., a route addition reads `routes.md`; a token change does not).

**Why not split eagerly?** Small codebases don't need it; small files are easier to scan. Wait until a section legitimately exceeds the cap.

</integration>

<critical_rules>
1. **Secrets and PII never go into memory.** Memory is committed; treat every line as if it's in a screenshot on Twitter. Use pointers to where secrets live (env var names, secret manager keys), not the values.
2. **Memory is HIERARCHICAL, not exhaustive.** Summary + Conventions cap at ~500 words. Role-specific sections (Routes / Component map / Tables / Tokens) can grow toward the soft 3,500-word total cap. Beyond that, push detail into Pointers (links to existing docs/code/beads). Beyond the 6,000-word hard cap, follow the multi-file overflow protocol. If you find yourself writing a 3rd paragraph in Summary, you're doing memory wrong — push detail into pointers or overflow files.
3. **Dispatch order matters in bootstrap.** application-architect must run before data-architect must run before backend-engineer must run before frontend-engineer. UIUX, security, devops, QA, PO, release can parallelize. Spec-sre-auditor is deferred.
4. **Memory is committed by default.** The skill's final step offers commit; the secret-guard hook protects against bad-content commits. If the user wants memory NOT committed, they edit .gitignore — that's their call, not the skill's default.
5. **Refresh mode is delta-only.** Don't rewrite memory from scratch on `--refresh`; preserve unrelated content and update only what the diff implicates.
6. **`/onboard` doesn't write specs.** Memory is about the EXISTING code, not future work. Specs come from /design after /onboard runs.
</critical_rules>

<verification_checklist>
Before declaring /onboard complete:

- [ ] `.claude/agent-memory/` directory exists with 10 files (spec-sre-auditor deferred) — PLUS 5 game-design files (game-designer, level-designer, narrative-designer, systems-designer, game-ui-designer) when `.claude/game-context.md` exists
- [ ] Each file has valid YAML frontmatter (agent, project-root, last-updated, last-commit-sha, schema-version)
- [ ] `last-updated` timestamps are seconds-precision (NOT `T00:00:00Z` date-stubs)
- [ ] Each file has the required sections (Summary, Conventions, Recent changes, Known issues, Pointers, plus ≥1 role-specific section)
- [ ] `qa-engineer.md` does NOT contain an eager per-spec / per-cluster test inventory table (bootstrap-lazy content)
- [ ] No file contains secret-shaped strings (`grep` validation passes)
- [ ] No file exceeds the 6,000-word hard cap; any over the 3,500-word soft cap has a follow-up to prune or split via multi-file overflow
- [ ] `git diff .claude/agent-memory/` shows reviewable, sensible content (not garbage dumps)
- [ ] User has been offered the commit option via AskUserQuestion
</verification_checklist>
