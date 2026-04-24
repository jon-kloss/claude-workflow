# Gherkin Spec Design — Context

## Key Files

- `skills/workflow-orchestrator/SKILL.md` — Main workflow skill. Brainstorming/planning phase needs modification to generate spec files instead of inline beads descriptions.
- `install.sh` — May need updates if new hooks or files are added.
- `hooks/` — Existing hooks directory. Potential location for spec-related hooks (e.g., remind to update specs during implementation).

## Decisions

1. **Format**: Markdown Gherkin (`.md`) — headings for keywords, bullet lists for steps, tags at top of file.
2. **Location**: `specs/` directory in the project being worked on (not in the workflow repo itself).
3. **Beads integration**: Epic descriptions replaced with spec file references. Beads still tracks work status; specs define what to build.
4. **Dependencies**: Pure Gherkin tags — `@depends-on(feature-name)`, `@blocks(feature-name)`. No YAML frontmatter.
5. **Lifecycle**: Living documents. Updated during implementation. `@status(draft|approved|implemented|verified)` tag tracks lifecycle.
6. **Tier scaling**: All tiers generate specs. Quick = minimal (Feature + 1-3 Scenarios). Standard = full structure. Complex = multiple files with cross-references.
7. **Anti-goal**: NOT a test framework. No step definitions, no test runner. Design specs only.

## New Requirement: Greenfield Rebuild

User clarified that for greenfield projects, the complete set of specs must be enough to rebuild the entire application from scratch. This led to:
- Adding a **System spec** (`specs/system.md`) concept — captures architecture, tech stack, data model, feature map, API overview, non-functional requirements
- Adding **Technical Context** sections to Standard/Complex feature specs — API contracts, data structures, integration points
- The `@depends-on` graph doubles as a build order

## Slice 6 Discoveries

- No new hooks needed for spec enforcement. Existing `block-unread-edits.sh` already prevents editing specs without reading them. `workflow-reminder.sh` already triggers workflow-orchestrator which now includes spec generation. All spec-specific behaviors (format, lifecycle, coverage) are enforced at the skill level by the workflow-orchestrator instructions, the continuous verifier, and Phase 4's Step 3.5 coverage check.
- install.sh does not need changes — no new hooks or files to link.

## Slice 3 Discoveries

- Phase 4 needed both automated (code review agent) AND manual (Step 3.5) spec coverage checks — the agent may miss scenarios in long specs
- Added `spec-coverage` as a new verification failure category alongside existing test-failure, test-quality, code-review, criteria-gap, integration
- The `@status` tag update in Phase 5 is the final lifecycle step — it's the signal that a spec went from design intent through to verified implementation
- Partially-implemented specs (some scenarios deferred) stay at `@status(implemented)` — only fully verified specs get `@status(verified)`

## Slice 2 Discoveries

- Phase 2 needed a "Pre-Investigation" step before dispatching agents — reading existing specs first so agents have spec context in their prompts
- The continuous verifier (Enforcement 7) prompt needed the spec file as context, not just the beads epic description — this is how correctness-against-spec gets verified per-task
- Specs need a `@deprecated` convention for scenarios that are discovered to be unneeded during implementation (rather than deleting them silently)
- The `@status` tag progression is: draft → approved → implemented → verified

## Investigation Findings

- Current brainstorming phase creates beads epics with Requirements, Success Criteria, Anti-Patterns, Approach sections as freeform Markdown
- The workflow-orchestrator SKILL.md is ~1,043 lines and controls all 6 phases
- Beads epic descriptions are set via `bd update <id> --description="..."` or `bd create --description="..."`
- No separate spec/design files exist in the current workflow
- The `plans/active/` directory is used for task docs (plan.md, context.md, tasks.md) which are temporary — deleted when work completes
- Spec files in `specs/` will persist beyond task completion as living documentation
