# Design-Build Split — Context

## Key Files

- `skills/workflow-orchestrator/SKILL.md` — Current monolithic skill (~1600 lines). Source material for the split. Will be renamed to `.deprecated`.
- `skills/design/SKILL.md` — NEW. /design skill for Socratic questioning + spec generation + reality check.
- `skills/build/SKILL.md` — NEW. /build skill for spec-driven investigation + TDD + verification + closing.
- `hooks/workflow-reminder.sh` — Needs update to reference /design and /build.
- `hooks/beads-auto-resume.sh` — Needs update to also scan specs/ for non-verified specs.
- `hooks/wwiwo.sh` — Needs update to show spec statuses.
- `hooks/check-open-beads.sh` — Needs update to warn about non-verified specs.
- `install.sh` — Needs update to link new skills, deprecate old one.
- `README.md` — Needs update to document the two-skill model.

## Decisions

1. **Approach A: Clean split** — Two standalone skills, spec files as the handoff contract. Accept ~150 lines Gherkin reference duplication.
2. **No explicit tier classification** — Complexity inferred from spec count/structure.
3. **Auto-iterate in /build** — Process all specs in @depends-on topological order without re-triggering.
4. **Pause on spec drift** — /build stops and directs to /design for fundamental spec changes. Does not silently fix.
5. **Reality check = both** — Agent pre-checks for gaps, then user confirms via AskUserQuestion.
6. **Beads = sub-task only** — Specs own feature-level status (@status tags) and dependencies (@depends-on). Beads handles implementation sub-tasks within features.
7. **Deprecate, don't delete** — workflow-orchestrator renamed to SKILL.md.deprecated.
8. **Naming** — /design and /build.

## Codebase Analysis (from investigation)

### Current SKILL.md Phase-to-Line Mapping

| Phase | Lines | Owner |
|-------|-------|-------|
| Metadata + overview | 1-16 | Both |
| Quick reference tables | 18-53 | Both |
| Gherkin spec reference | 55-346 | Both (trimmed per skill) |
| Phase 0: Classify | 364-400 | Design (removed — tier inferred) |
| Phase 1: Plan | 403-623 | Design |
| Phase 2: Investigate | 625-722 | Build |
| Phase 3: Implement | 725-986 | Build |
| Phase 4: Verify | 988-1212 | Build |
| Phase 5: Close | 1214-1289 | Build |
| Examples | 1292-1489 | Split (design examples / build examples) |
| Critical rules | 1492-1548 | Split (design rules / build rules) |
| Verification checklist | 1550-1613 | Split (design checks / build checks) |
| Integration | 1615-1645 | Both |
| Edge cases | 1647-1681 | Split |

### External Skills Invoked

| Skill | /design | /build |
|-------|---------|--------|
| hyperpowers:brainstorming | Yes | No |
| hyperpowers:sre-task-refinement | Yes | No |
| hyperpowers:executing-plans | No | Yes |
| hyperpowers:test-driven-development | No | Yes |
| hyperpowers:verification-before-completion | No | Yes |
| hyperpowers:finishing-a-development-branch | No | Yes |

### Agents Used

| Agent | /design | /build |
|-------|---------|--------|
| codebase-investigator | No | Yes |
| internet-researcher | No | Yes (conditional) |
| code-reviewer | No | Yes |
| test-runner | No | Yes |
| test-effectiveness-analyst | No | Yes |

### Hook Ownership

| Hook | Owner | Changes Needed |
|------|-------|----------------|
| workflow-reminder.sh | Both | Update to reference /design + /build |
| beads-auto-resume.sh | Build | Add specs/ scanning |
| wwiwo.sh | Build | Add spec status display |
| check-open-beads.sh | Build | Add non-verified spec warnings |
| block-unread-edits.sh | Build | No change |
| track-reads.sh | Build | No change |
| clear-session-reads.sh | Both | No change |
| require-bead-description.sh | Design | No change |
| remind-integration-tests.sh | Build | No change |
| verifier-dispatch.sh | Build | No change |
| verifier-return.sh | Build | No change |

## Slice 1 Discoveries

- User suggested moving beads task creation from /design to /build (after investigation). This is better because tasks created after investigation have real codebase context — file paths, patterns, integration points — instead of guesswork.
- Updated flow: /design creates epic + Tests gate only. /build creates per-spec implementation tasks after codebase investigation.
- /design's entry validation only checks for beads epic (not per-spec tasks).
- SRE refinement moved to /build (runs on tasks after they're created post-investigation).

## Slice 2 Discoveries

- workflow-orchestrator SKILL.md replaced with a deprecation redirect pointing to /design and /build. Original preserved as SKILL.md.deprecated.
- workflow-reminder.sh now detects whether approved specs exist — suggests /build if specs found, /design if not.
- beads-auto-resume.sh scans specs/ for @status tags and groups by status (in-progress, approved, draft).
- wwiwo.sh now shows full spec status breakdown (in-progress, approved, draft, verified) alongside beads tasks.
- check-open-beads.sh warns about non-verified specs on session stop in addition to open beads tasks.
- All hooks pass bash syntax check.

## Slice 3 Discoveries

- install.sh updated: links skills/design/ and skills/build/, updated manifest, updated summary output.
- README.md fully rewritten for two-skill model: updated file tree, Usage, Hooks table, Design Principles (12 principles), replaced tier classification with "Spec Complexity (Inferred)" table.

## Slice 4 Discoveries (Pressure Testing)

- Both skills passed RED/GREEN/REFACTOR pressure testing (6 subagent scenarios total).
- RED baselines: /design agent skipped questioning/specs/reality-check entirely. /build agent did "tests alongside" instead of RED-first TDD, no investigation agents, no verification suite.
- GREEN: Both skills corrected all baseline failures. Agents explicitly cited constraints and refused rationalizations.
- REFACTOR (meta-rationalizations): 4/4 rejected for each skill. Most dangerous pressure: "user gave me the file paths" — feels like completed investigation but isn't. Skill counter holds: "reading a path is not reading a file."
- No skill edits needed after pressure testing — both are bulletproof against tested scenarios.

## Research Sources

1. BDD 101: Writing Good Gherkin (automationpanda.com) — Discovery/Formulation before Automation
2. Gherkin Best Practices (github.com/andredesousa) — Business layer first, technical layer second
3. Gherkin BDD Cucumber Guide (testquality.com) — Three-phase BDD cycle
4. Agent Skills (datacamp.com) — Avoid God Skills, use chainable units
5. Superpowers Framework (aitoolly.com) — Composable skills with sequential/parallel execution
6. Agent Skills Architecture (waduclay.com) — Focused domain, high precision per skill
7. GitHub Spec Kit (developer.microsoft.com) — /specify → /plan → /tasks sequential structure
8. Spec-Driven Brownfield (augmentcode.com) — Scope specs at subdirectory level
9. SDD Practitioner's Guide (augmentcode.com) — Coordinator → Implementor → Verifier pattern
10. SDD vs BDD (medium.com/@cheparsky) — AI loop pattern for spec-driven development
11. Living Documentation (serenity-bdd.github.io) — BDD scenarios fail when behavior changes
12. BDD Guide 2026 (monday.com) — Acceptance approach: freeze then provisional adjustment
