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

Each file is committed. Each is ≤ ~2000 words; agents prune when over cap.
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

**Dispatch parallelism.** Agents 1–4 must serialize (later ones read earlier memory). Agents 5–10 can run in parallel (independent surfaces). To dispatch in parallel, include MULTIPLE Agent tool calls in a SINGLE message (per the parallel-dispatch pattern in build/SKILL.md and design/SKILL.md).

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
- Stay under ~2000 words total — use the Pointers section to link to deeper docs/code

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
in frontmatter to HEAD."
```

## Step 6: Validate each memory file

For each `.claude/agent-memory/<role>.md` produced:

1. **Frontmatter present** — `agent`, `project-root`, `last-updated`, `last-commit-sha`, `schema-version`.
2. **Required sections** — `## Summary`, `## Conventions`, `## Recent changes`, `## Known issues`, `## Pointers`. Role-specific sections vary (Component map, Routes, Tables, Tokens, etc.) — at least one role-specific section per memory.
3. **Word count** — total words ≤ 2000 (`wc -w`). Over cap → re-dispatch the agent with "compress to ~1500 words" prompt.
4. **No secret-shaped strings** — `guard-agent-memory-secrets.sh` enforces this on write, but also re-validate on read: `grep -E '(Bearer\s+eyJ|sk_live_|AKIA[0-9A-Z]{16}|-----BEGIN.*PRIVATE KEY)' .claude/agent-memory/*.md` returns empty.

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

</integration>

<critical_rules>
1. **Secrets and PII never go into memory.** Memory is committed; treat every line as if it's in a screenshot on Twitter. Use pointers to where secrets live (env var names, secret manager keys), not the values.
2. **Memory is HIERARCHICAL, not exhaustive.** Summary + Conventions + Component-map cap at ~500 words. Drill-down content goes in Pointers as references to existing docs/code paths/beads tasks. If you find yourself writing a 3rd paragraph in Summary, you're doing memory wrong — push detail into pointers.
3. **Dispatch order matters in bootstrap.** application-architect must run before data-architect must run before backend-engineer must run before frontend-engineer. UIUX, security, devops, QA, PO, release can parallelize. Spec-sre-auditor is deferred.
4. **Memory is committed by default.** The skill's final step offers commit; the secret-guard hook protects against bad-content commits. If the user wants memory NOT committed, they edit .gitignore — that's their call, not the skill's default.
5. **Refresh mode is delta-only.** Don't rewrite memory from scratch on `--refresh`; preserve unrelated content and update only what the diff implicates.
6. **`/onboard` doesn't write specs.** Memory is about the EXISTING code, not future work. Specs come from /design after /onboard runs.
</critical_rules>

<verification_checklist>
Before declaring /onboard complete:

- [ ] `.claude/agent-memory/` directory exists with 10 files (spec-sre-auditor deferred)
- [ ] Each file has valid YAML frontmatter (agent, project-root, last-updated, last-commit-sha, schema-version)
- [ ] Each file has the required sections (Summary, Conventions, Recent changes, Known issues, Pointers, plus ≥1 role-specific section)
- [ ] No file contains secret-shaped strings (`grep` validation passes)
- [ ] No file exceeds 2000 words
- [ ] `git diff .claude/agent-memory/` shows reviewable, sensible content (not garbage dumps)
- [ ] User has been offered the commit option via AskUserQuestion
</verification_checklist>
