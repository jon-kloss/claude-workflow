@status(verified)
@depends-on(decomposition-heuristics)
@parallel-risk(standalone-decompose)

# Feature: Design Decomposition Step

As a workflow user
I want /design to automatically decompose work into multiple specs at natural seams
So that I get well-sized, parallelizable specs instead of one overloaded spec

## Technical Context

- **Modified file**: `skills/design/SKILL.md`
- **Where in the flow**: New step between Step 2 (Socratic Questioning) and Step 3 (Generate Specs)
- **Inputs**: Answers from Socratic questioning
- **Outputs**: A decomposition map — list of specs to generate with their dependency relationships
- **Parallel risk**: standalone-decompose also modifies `/design/SKILL.md`

## Background

- Given the /design skill exists with Steps 1-6
- And Socratic questioning (Step 2) has been completed

## Rule: Decomposition happens before spec generation

### Scenario: Single-behavior work produces one spec

- Given the user's request is a single cohesive behavior
- When the decomposition step runs
- Then the decomposition map contains one spec
- And spec generation proceeds as before (no change in behavior)

### Scenario: Multi-behavior work produces multiple specs

- Given the user's request involves adding a CLI command and an API endpoint
- When the decomposition step applies the independence test
- Then the decomposition map contains two specs with no `@depends-on`
- And a dependency graph is shown to the user as part of the reality check
- And spec generation creates separate files for each

### Scenario: Decomposition identifies a shared dependency

- Given the user's request involves two features that both need a new data model
- When the decomposition step applies the independence test
- Then the decomposition map contains three specs: data model, feature A, feature B
- And features A and B both `@depends-on(data-model)`
- And features A and B are parallel (no dependency between them)

## Rule: The decomposition map is presented during reality check

### Scenario: Reality check shows dependency graph with parallel lanes

- Given decomposition produced 4 specs with dependencies
- When the reality check (Step 4) is presented to the user
- Then the graph shows which specs are sequential (have `@depends-on`) and which are parallel
- And the user can request re-decomposition ("these two should be one spec" or "this should be split further")

## Rule: Simple work is not over-decomposed

### Scenario: Typo fix is not decomposed

- Given the user's request is "fix a typo in the README"
- When the decomposition step runs
- Then the decomposition map contains one spec
- And no seam analysis is performed (the work is trivially single-behavior)
