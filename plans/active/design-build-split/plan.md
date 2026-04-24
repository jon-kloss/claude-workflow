# Design-Build Split — Plan

## Problem

The workflow-orchestrator is a monolithic ~1600-line skill that handles all 6 phases (Classify → Plan → Investigate → Implement → Verify → Close). This creates several problems:

1. **Context bloat** — The entire skill loads into every conversation, even when only planning or only executing
2. **No natural pause point** — The monolith encourages running straight through all phases without review checkpoints
3. **Mismatched mental models** — Design (Socratic questioning, spec writing) and execution (TDD, verification) are fundamentally different activities that benefit from separate invocation
4. **Rigid tier classification** — The Quick/Standard/Complex tiers add a classification step that can be inferred from the specs themselves

## Goals

- Split workflow-orchestrator into two standalone skills: `/design` and `/build`
- `/design` handles Socratic questioning, Gherkin spec generation, reality check, and beads task creation
- `/build` handles spec-driven investigation, TDD implementation, verification, and closing — auto-iterating through all specs in `@depends-on` order
- Specs are the source of truth for feature-level status (`@status` tags) and dependencies (`@depends-on`/`@blocks`)
- Beads handles sub-task-level tracking within features only
- Tier complexity is inferred from spec count/structure, not explicitly classified
- Each skill is self-contained and independently invocable
- Reality check after spec generation: agent pre-checks for gaps, then user confirms via AskUserQuestion
- If `/build` discovers a spec is fundamentally wrong, it pauses and directs user to `/design`
- Update hooks to reference the two new skills

## Anti-Goals

- **Not a test framework** — Gherkin specs are design documents, not executable Cucumber tests
- **Not removing beads entirely** — Beads stays for sub-task tracking; specs own feature-level status
- **Not creating a shared reference skill** — Accept ~150 lines of Gherkin reference duplication to keep skills independent
- **Not auto-fixing spec drift** — When a spec is wrong, /build pauses for human re-design, it does not silently update
- **Not keeping the old tier classification step** — Complexity is inferred, not asked

## Constraints

- Must work with existing hyperpowers skills (brainstorming, executing-plans, sre-task-refinement, test-driven-development, verification-before-completion)
- Must not modify hyperpowers plugin skills — only invoke them
- Hooks must be updated to reference /design and /build instead of workflow-orchestrator
- install.sh must handle linking new skills and deprecating old one
- Each skill must render cleanly in GitHub, VS Code, and terminal Markdown viewers
- Existing spec format (Markdown Gherkin with @tags) is unchanged

## Research Notes

1. **BDD Discovery → Formulation → Automation cycle** (automationpanda.com, testquality.com) — BDD separates spec writing from implementation. The conversation about behavior (Discovery/Formulation) happens before step definitions (Automation). Maps directly to /design → /build split.

2. **Agent skill decomposition** (datacamp.com/blog/agent-skills) — "Avoid God Skills by breaking workflows into smaller, chainable units with high semantic specificity." Use Discovery Layer (metadata) + Execution Layer (reasoning). Skills load conditionally, not persist.

3. **Spec-driven build ordering** (developer.microsoft.com/blog/spec-driven-development-spec-kit) — Microsoft's Spec Kit enforces sequential: `/specify` → `/plan` → `/tasks`. Task ordering emerges from spec breakdown, not separate dependency graph. Maps to our @depends-on topological sort.

4. **Living specification patterns** (medium.com/@cheparsky) — The AI loop pattern: define → refine → generate → validate → update → repeat. "The spec serves as an input to a repeating loop rather than a locked handoff document." Supports our pause-and-replan model.

5. **Augment Code scope guidelines** (augmentcode.com/guides/spec-driven-development-brownfield-codebases) — "Scope specs at subdirectory or change level to avoid massive global rule files." Each execution task gets scoped context containing only its feature spec.

## Chosen Approach

**Approach A: Clean Split — Spec Files as Contract**

Two standalone skills with the spec file as the handoff artifact:

```
skills/
  design/SKILL.md     (~400-500 lines) — Socratic + spec gen + reality check
  build/SKILL.md      (~500-700 lines) — investigate + TDD + verify + close
  workflow-orchestrator/SKILL.md → renamed to SKILL.md.deprecated
```

### /design Skill

**Invocation**: User types `/design`

**Process**:
1. **Socratic questioning** — Ask as many questions as needed using AskUserQuestion. No tier-based depth limits. Block until all critical questions answered.
2. **Spec generation** — Generate Gherkin specs in `specs/`. System spec for greenfield projects. One feature spec per feature.
3. **Reality check** — Agent pre-checks specs against original request for gaps. Present specs to user via AskUserQuestion: "Do these specs capture what you asked for?" If no, ask more clarifying questions and regenerate.
4. **Beads setup** — Create one beads task per spec file + Tests gate task. Epic description references spec files.
5. **SRE refinement** — Run sre-task-refinement on beads tasks (for Standard/Complex-equivalent work).

**Exit state**: All specs at `@status(approved)`, beads tasks created, user confirmed design.

**Contains**:
- Gherkin spec reference (generation-focused: templates, format, tags, system spec template)
- Socratic questioning rules and enforcement
- Reality check procedure
- Beads epic/task creation instructions
- Spec generation examples per complexity level
- Design-specific rationalizations and rules

### /build Skill

**Invocation**: User types `/build`

**Process**:
1. **Entry validation** — Scan `specs/` for files with `@status(approved)` or `@status(implemented)`. Check beads for uncompleted tasks. If nothing to work on, inform user.
2. **Dependency graph** — Parse `@depends-on` tags from all specs. Topological sort for build order. Validate prerequisites are `@status(verified)` before starting dependents. Skip blocked specs, work on unblocked ones.
3. **Per-spec iteration** (auto-iterates all specs in dependency order):
   a. **Investigate** — Codebase analysis. Check completed specs for context (data models, APIs already built). Dispatch codebase-investigator agent.
   b. **Spec-driven TDD** — RED: Generate failing tests from spec scenarios. GREEN: Implement minimal code. REFACTOR. Use executing-plans for multi-task specs.
   c. **Verify** — Full test suite + code review agent + spec coverage check + test-effectiveness-analyst. NEVER scales down.
   d. **Update status** — Set `@status(verified)` on spec. Close beads task.
4. **Pause on drift** — If spec is fundamentally wrong (wrong approach, missing feature, incorrect data model), stop iteration. Inform user to run `/design` to revise.
5. **Next spec** — Move to next spec in dependency order. Repeat from 3a.

**Exit state**: All specs `@status(verified)`, all beads tasks closed, epic closed, memory saved.

**Contains**:
- Gherkin spec reference (reading-focused: format, mapping scenarios to tests, status lifecycle)
- Entry validation and dependency graph parsing
- Investigation procedure (codebase analysis, dependency context)
- Spec-driven TDD procedure with scenario-to-test mapping table
- Verification procedure (test suite, code review, spec coverage, test effectiveness)
- Closing procedure (spec status, beads, memory)
- Build-specific rationalizations and rules
- Continuous verifier agent integration

### Hook Changes

| Hook | Current | After |
|------|---------|-------|
| `workflow-reminder.sh` | References workflow-orchestrator | Reference /design for new work, /build for existing specs |
| `beads-auto-resume.sh` | Checks beads only | Also scan specs/ for non-verified specs |
| `wwiwo.sh` | Shows beads status | Also show spec statuses |
| `check-open-beads.sh` | Warns about open beads | Also warn about non-verified specs |

### install.sh Changes

- Link `skills/design/` to `~/.claude/skills/design/`
- Link `skills/build/` to `~/.claude/skills/build/`
- Rename `skills/workflow-orchestrator/SKILL.md` to `SKILL.md.deprecated`
- Remove old workflow-orchestrator symlink
- Update hook symlinks if any hooks change

## Rejected Alternatives

1. **Three skills with shared reference** — Adds a workflow-reference skill containing Gherkin format, rules, rationalizations shared by both. Rejected: adds coupling and a third file to maintain. ~150 lines of duplication is acceptable for independence.

2. **Single skill with mode switch** — Keep one skill, add `/workflow design` vs `/workflow build` modes. Rejected: still monolithic (~1600 lines loaded every time), user explicitly wanted separate skills.

3. **Auto-fix spec drift in /build** — Let /build update specs silently when discoveries are made. Rejected: fundamental spec changes need human review. The spec is a design contract, not an auto-generated artifact.

4. **Keep explicit tier classification** — Quick/Standard/Complex step before planning. Rejected: with full Socratic questioning always available, tier adds no value. Complexity is evident from the specs produced.

## Acceptance Checks

- [ ] `/design` skill generates Gherkin specs in `specs/` with full Socratic questioning
- [ ] `/design` performs reality check (agent pre-check + user confirmation via AskUserQuestion)
- [ ] `/design` creates beads tasks (one per spec + Tests gate) referencing spec files
- [ ] `/build` validates entry: checks for specs with `@status(approved)`, informs if nothing to do
- [ ] `/build` parses `@depends-on` graph and iterates specs in topological order
- [ ] `/build` validates prerequisites are `@status(verified)` before starting dependent specs
- [ ] `/build` performs codebase investigation before each spec's implementation
- [ ] `/build` follows spec-driven TDD: failing tests from scenarios before implementation
- [ ] `/build` runs full verification (test suite + code review + spec coverage + test effectiveness)
- [ ] `/build` updates `@status(verified)` and closes beads task after each spec passes verification
- [ ] `/build` pauses and directs to `/design` when spec is fundamentally wrong
- [ ] `/build` auto-iterates to next spec after verification passes
- [ ] workflow-orchestrator SKILL.md renamed to SKILL.md.deprecated
- [ ] Hooks updated to reference /design and /build
- [ ] install.sh links new skills and handles deprecation
- [ ] Both skills render cleanly as Markdown
- [ ] Pressure-tested with subagent scenarios (RED/GREEN/REFACTOR)
