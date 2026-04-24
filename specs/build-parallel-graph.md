@status(verified)
@depends-on(decomposition-heuristics)

# Feature: Build Parallel Graph Visualization

As a workflow user
I want /build to show me the dependency graph with parallel lanes before executing
So that I can confirm the build order and parallel dispatch plan

## Technical Context

- **Modified file**: `skills/build/SKILL.md`
- **Where in the flow**: After entry validation (Step 1), before per-spec iteration (Step 3)
- **Inputs**: All specs in `specs/` with their `@depends-on` and `@parallel-risk` tags
- **Outputs**: Visual dependency graph presented via AskUserQuestion, user confirms before execution
- **Graph format**: Text-based lanes showing parallel and sequential specs

## Background

- Given multiple specs exist in `specs/` with `@status(approved)`
- And some specs have `@depends-on` relationships
- And /build has completed entry validation

## Rule: The dependency graph is shown before execution begins

### Scenario: Specs with parallel and sequential relationships

- Given specs A (no deps), B (no deps), C (depends-on A), D (depends-on A and B)
- When /build presents the dependency graph
- Then it shows:
  - Lane 1: A and B in parallel
  - Lane 2: C (after A)
  - Lane 3: D (after both A and B)
- And /build asks the user to confirm before dispatching

### Scenario: All specs are independent

- Given specs A, B, and C with no `@depends-on` relationships
- When /build presents the dependency graph
- Then it shows all three as parallel
- And /build asks the user to confirm parallel dispatch

### Scenario: Purely sequential chain

- Given specs A, B (depends-on A), C (depends-on B)
- When /build presents the dependency graph
- Then it shows a single sequential chain: A -> B -> C
- And /build proceeds without asking (no parallel decision to make)

## Rule: Parallel-risk specs get warnings

### Scenario: Two parallel specs share file overlap

- Given specs A and B are parallel (no `@depends-on`)
- And both have `@parallel-risk` tags referencing each other
- When /build presents the dependency graph
- Then the graph shows A and B as parallel with a warning: "file overlap — potential merge conflicts"
- And /build recommends building the smaller spec first

## Rule: User can override the execution plan

### Scenario: User requests sequential execution of parallel specs

- Given /build presents specs A and B as parallel
- When the user says "run these sequentially"
- Then /build executes A then B (or B then A, user's choice)
- And no `@depends-on` tags are modified (the specs remain logically independent)
