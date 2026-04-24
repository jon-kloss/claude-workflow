@status(verified)
@depends-on(decomposition-heuristics)
@parallel-risk(design-decomposition-step)

# Feature: Standalone Spec Decomposition

As a workflow user
I want to decompose an existing too-large spec into smaller specs after it's already been approved
So that I can fix overloaded specs discovered during /build without re-running the full /design flow

## Technical Context

- **Invocation**: User points at a spec and asks to decompose it (no specific slash command needed — /design handles it)
- **Modified file**: `skills/design/SKILL.md` (edge case section)
- **Inputs**: An existing spec file in `specs/` (any status)
- **Outputs**: Multiple smaller spec files replacing the original, with correct `@depends-on` and `@parallel-risk` tags
- **Parallel risk**: design-decomposition-step also modifies `/design/SKILL.md`
- **Beads update**: If beads tasks reference the original spec, they must be updated to reference the new specs

## Background

- Given an existing spec file in `specs/` that is too large or overloaded
- And the user wants to split it without re-running full Socratic questioning

## Rule: Decomposition applies the same heuristics as /design

### Scenario: Existing spec has multiple independent behaviors

- Given `specs/user-management.md` has scenarios for registration, authentication, and profile editing
- When the user asks to decompose it
- Then /design applies the independence test from decomposition-heuristics
- And produces `specs/user-registration.md`, `specs/user-authentication.md`, `specs/user-profile.md`
- And authentication gets `@depends-on(user-registration)`
- And profile editing gets `@depends-on(user-registration)`
- And the original `specs/user-management.md` is removed

## Rule: Existing dependency relationships are preserved and refined

### Scenario: Original spec had dependents

- Given `specs/user-management.md` is `@blocks(payment-processing)`
- When it is decomposed into registration, authentication, and profile specs
- Then only the spec that payment-processing actually depends on gets `@blocks(payment-processing)`
- And the user is asked to confirm which decomposed spec is the real dependency

## Rule: Beads tasks are updated to match new specs

### Scenario: Beads task referenced the original spec

- Given a beads task references `specs/user-management.md`
- When the spec is decomposed into three specs
- Then the original beads task is closed
- And new beads tasks are created for each new spec
- And the Tests gate task is preserved (not duplicated)

## Rule: Status is preserved or reset appropriately

### Scenario: Decomposing an approved spec

- Given `specs/user-management.md` has `@status(approved)`
- When it is decomposed
- Then all resulting specs get `@status(approved)` (design was already confirmed)

### Scenario: Decomposing a partially-implemented spec

- Given `specs/user-management.md` has `@status(implemented)` but only some behaviors are done
- When it is decomposed
- Then completed behaviors get `@status(implemented)`
- And incomplete behaviors get `@status(approved)`
- And the user confirms the status assignments
