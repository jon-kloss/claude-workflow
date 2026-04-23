# Gherkin Spec Design — Plan

## Problem

The workflow currently stores design intent as unstructured Markdown in beads epic descriptions (Requirements, Success Criteria, Anti-Patterns, Approach). This format is freeform, inconsistent across projects, and doesn't express behavior in a way that maps directly to implementation or verification. There's no standard structure for capturing what a feature *does* — only what it *is*.

## Goals

- Generate `.md` spec files following Gherkin syntax during the design/planning phase of the workflow
- Each spec is a self-contained feature file in `specs/` within the project being worked on
- Specs use Markdown Gherkin format: `#` headings for keywords, `- ` bullet lists for steps, `@tags` for metadata and dependencies
- Specs replace beads epic descriptions as the source of truth for design intent
- Specs are living documents — updated as implementation reveals new scenarios and edge cases
- All tiers (Quick, Standard, Complex) generate specs, scaled by complexity
- Cross-feature dependencies expressed via `@depends-on(feature-name)` and `@blocks(feature-name)` tags
- **Greenfield rebuild capability**: For greenfield projects, the complete set of specs in `specs/` must be sufficient to rebuild the entire application from scratch. This means specs collectively capture architecture, data models, API contracts, and all feature behaviors — not just isolated scenarios

## Anti-Goals

- **Not a test framework.** These are design specs, not executable Cucumber tests. No step definitions, no test runner, no automation layer. The Gherkin structure is used for its clarity as a specification language, not for test execution.
- Specs do not replace beads for task tracking (who, when, status). Beads tracks work; specs define what to build.
- No YAML frontmatter — pure Gherkin tags handle all metadata and dependencies.

## Constraints

- Must integrate with the existing 6-phase workflow-orchestrator (Classify → Plan → Investigate → Implement → Verify → Close)
- Beads epics must link to spec files (not duplicate their content)
- Quick tier specs must be lightweight enough to not slow down trivial fixes
- Spec format must render cleanly in GitHub, VS Code, and terminal Markdown viewers
- install.sh must handle any new files/hooks

## Research Notes

1. **Cucumber Gherkin Reference** (cucumber.io/docs/gherkin/reference) — Gherkin 6 added the `Rule` keyword for grouping scenarios under business rules. Tags inherit Feature → Rule → Scenario. Descriptions support Markdown.
2. **Cucumber Markdown with Gherkin** (github.com/cucumber/gherkin/blob/main/MARKDOWN_WITH_GHERKIN.md) — Official `.feature.md` format uses Markdown headings for Gherkin keywords. Steps as `* ` or `- ` list items. Validates that Markdown rendering of Gherkin is a recognized approach.
3. **BDD Best Practices** (automationpanda.com, cucumber.io/blog) — One behavior per scenario. Declarative over procedural. Features organized by functional area. Cardinal rule: each Scenario covers ONE behavior. Scenarios >7 steps likely cover multiple behaviors and should be split.

## Chosen Approach

**Modify workflow-orchestrator to generate Markdown Gherkin spec files during brainstorming/planning.**

The spec file format:

```markdown
@tag1 @tag2
@depends-on(other-feature)
@blocks(downstream-feature)

# Feature: Feature Name

As a [role]
I want [capability]
So that [benefit]

## Background

- Given [shared precondition]

## Rule: Business rule description

### Scenario: Concrete example of the rule

- Given [context]
- When [action]
- Then [outcome]

### Scenario Outline: Parameterized example

- Given [context]
- When [action with <param>]
- Then [expected result for <param>]

#### Examples

| param | expected |
|-------|----------|
| val1  | result1  |
| val2  | result2  |
```

**How it integrates with the workflow:**

1. **Classify phase** — unchanged. Determines tier.
2. **Plan phase (brainstorming)** — instead of writing Requirements/Success Criteria into beads epic description, generate one or more `.md` spec files in `specs/`. Beads epic description becomes a link: `Spec: specs/feature-name.md`
3. **Investigate phase** — read existing `specs/` to understand related features and dependencies. Use `@depends-on` tags to identify prerequisite features.
4. **Implement phase** — specs are living docs. New scenarios added as edge cases are discovered. The continuous verifier checks implementation against spec scenarios.
5. **Verify phase** — code review validates that every scenario in the spec has been addressed. Spec file gets a `@status(verified)` tag.
6. **Close phase** — beads epic closed. Spec remains as living documentation.

**Tier scaling:**

- **Quick** — Single Feature + 1-3 Scenarios. No Rules, no Background. Minimal.
- **Standard** — Feature + Rules + multiple Scenarios. Background if shared setup exists.
- **Complex** — Multiple spec files (one per feature). Dependencies between them. Full Gherkin structure with Scenario Outlines, Examples tables, Background.

## Rejected Alternatives

1. **Pure .feature files** — Correct to the Gherkin spec but renders poorly in Markdown viewers. The workflow is Markdown-native; fighting that creates friction.
2. **.feature.md hybrid** — Official Cucumber format but less standardized. Places tags after the `# Feature:` heading, which is less scannable for dependency graphs.
3. **YAML frontmatter + Gherkin body** — Mixes two formats. Adds parsing complexity. Tags-only is cleaner and more consistent with Gherkin conventions.
4. **Supplement beads instead of replace** — Creates two sources of truth. Specs would drift from epic descriptions. Single source is clearer.

## Acceptance Checks

- [ ] workflow-orchestrator generates spec files in `specs/` during brainstorming
- [ ] Beads epic descriptions reference spec files instead of containing inline requirements
- [ ] Quick tier generates minimal specs (Feature + 1-3 Scenarios)
- [ ] Standard/Complex tiers generate full Gherkin specs (Rules, Background, Scenario Outlines)
- [ ] Complex tier generates multiple spec files with `@depends-on` / `@blocks` tags
- [ ] Specs are updated during implementation as new scenarios are discovered
- [ ] Verify phase checks implementation coverage against spec scenarios
- [ ] Spec files render correctly as Markdown in GitHub/editors
- [ ] install.sh updated if any new hooks or files are needed
