@status(verified)
@blocks(design-decomposition-step)
@blocks(build-parallel-graph)
@blocks(standalone-decompose)

# Feature: Decomposition Heuristics

As a workflow designer
I want a clear framework for identifying when work should be split into multiple specs
So that /design produces well-sized, independently-buildable specs instead of monolithic ones

## Technical Context

- **Where it lives**: Embedded as a reference section in `/design/SKILL.md` and reused by standalone decompose
- **Core principle**: Work is decomposable when its pieces are independently testable
- **Trigger**: Applied during /design after Socratic questioning, before spec generation
- **Not a threshold**: No "more than N scenarios = split". Decomposition follows natural functional seams.

### The Independence Test

A piece of work is independent from another if:
1. You can write tests for it without the other piece existing
2. It has its own inputs and outputs (even if they share a file)
3. Removing it doesn't break the other piece's tests

### Seam Types

| Seam | Example | Signal |
|------|---------|--------|
| Data boundary | API endpoint vs. CLI command — different input sources, same DB | Different entry points to the system |
| Lifecycle boundary | User registration vs. user authentication — different user journeys | Different "when" triggers |
| Consumer boundary | Admin dashboard vs. public API — different audiences | Different "who" uses it |
| Layer boundary | Database schema vs. API routes vs. UI components | Can be built bottom-up independently |
| Rule boundary | Validation rules vs. business logic vs. formatting | Different "what kind" of behavior |

### Parallel Risk: File Overlap

When two independent specs will modify the same file:
- Tag with `@parallel-risk(other-spec-slug)` on both specs
- They remain parallel (not sequenced) but /build warns about potential merge conflicts
- /build should build the smaller/simpler spec first when file overlap is flagged

## Background

- Given a user request that involves multiple behaviors
- And the Socratic questioning phase is complete

## Rule: Work that passes the independence test gets separate specs

### Scenario: Two behaviors with no test coupling

- Given a request to "add a CLI command and an API endpoint for the same resource"
- When the independence test is applied
- Then the CLI command and API endpoint become separate specs
- And neither spec has `@depends-on` on the other
- Because tests for the CLI command don't need the API endpoint to exist (and vice versa)

### Scenario: Two behaviors with shared data dependency

- Given a request to "add user registration and user authentication"
- When the independence test is applied
- Then registration and authentication become separate specs
- And authentication gets `@depends-on(user-registration)`
- Because authentication tests need a registered user to exist

### Scenario: Two behaviors that are truly one thing

- Given a request to "add input validation to the registration endpoint"
- When the independence test is applied
- Then validation stays in the registration spec as scenarios under a Rule
- Because validation tests require the endpoint to exist — they are not independently testable

## Rule: Seams are identified by asking "what changes independently?"

### Scenario: Different entry points to the same data

- Given a feature that exposes data through both API and CLI
- When checking for the data boundary seam
- Then the API and CLI are separate specs
- And both may `@depends-on` a shared data-layer spec if the schema doesn't exist yet

### Scenario: Different user journeys through the same system

- Given a feature with admin and end-user workflows
- When checking for the consumer boundary seam
- Then admin workflows and end-user workflows are separate specs
- And they may share `@depends-on` on a common data or auth spec

### Scenario: No natural seam exists

- Given a feature that is a single cohesive behavior (e.g., "sort search results by relevance")
- When checking for seams
- Then no decomposition is applied
- And the work remains a single spec

## Rule: File overlap is flagged, not blocked

### Scenario: Two independent specs will modify the same file

- Given spec A (CLI command) and spec B (API endpoint) are independent
- And both will add code to server.ts
- When decomposition is applied
- Then both specs get `@parallel-risk(other-slug)` tags
- And they remain parallel (no `@depends-on` added)
- And /build is informed to expect potential merge conflicts
