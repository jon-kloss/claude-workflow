@status(verified)
@blocks(retrospective-overhaul)

# Feature: Workflow Incident Logging

As a workflow user
I want pain points and corrections to be captured as structured beads comments when they happen
So that the retrospective has real incident data to drive skill improvements

## Technical Context

- **Storage**: Beads comments on the active epic (or a dedicated `workflow-incidents` issue if no epic is active)
- **Format**: Structured comment with category, what happened, what should have happened, which skill/rule was insufficient
- **Detection**: Claude auto-detects when user corrects its approach and asks to confirm logging
- **Trigger phrases**: "no", "don't do that", "stop", "this should never happen", "that's wrong", corrections to approach
- **Confirmation**: Claude asks "Should I log this as a workflow incident for the next retro?" — user confirms or dismisses

### Incident Comment Format

```
WORKFLOW INCIDENT: [short description]

Category: [skill-gap | missing-rule | wrong-default | edge-case | process-violation]
Skill: [design | build | retrospective | hook-name | none]
What happened: [what Claude did wrong]
What should have happened: [correct behavior]
User correction: [what the user said]
Proposed fix: [optional — if the fix is obvious, note it]
```

## Background

- Given the workflow has skills (/design, /build) with rules and rationalizations
- And Claude sometimes violates rules or lacks guidance for edge cases
- And the user corrects Claude's approach during the conversation

## Rule: Corrections are detected and logging is offered

### Scenario: User explicitly corrects Claude's approach

- Given Claude is executing a workflow step
- When the user says "this should never happen" or "don't do that" or provides a correction
- Then Claude recognizes this as a potential workflow incident
- And asks via AskUserQuestion: "Should I log this as a workflow incident for the next retro?"
- And the user can confirm or dismiss

### Scenario: User confirms logging

- Given Claude detected a correction and asked to log it
- When the user confirms
- Then Claude logs a structured comment on the active epic
- And the comment follows the incident format (category, skill, what happened, what should have happened)
- And Claude continues with the corrected approach

### Scenario: User dismisses logging

- Given Claude detected a correction and asked to log it
- When the user dismisses (normal conversation correction, not a workflow issue)
- Then no incident is logged
- And Claude continues normally

## Rule: Incidents are logged on the active epic

### Scenario: Epic is active during incident

- Given an epic is in progress (open or in_progress)
- When an incident is logged
- Then the comment is added to the active epic
- And the comment uses the structured incident format

### Scenario: No epic is active during incident

- Given no epic is currently active
- When an incident needs to be logged
- Then Claude creates or reuses a dedicated `workflow-incidents` issue
- And logs the comment there
- And the retrospective knows to check this issue for incidents

## Rule: Incidents capture enough context for the retro to act on

### Scenario: Incident includes actionable context

- Given an incident is being logged
- When the comment is written
- Then it includes which skill was insufficient (or "none" if it's a general gap)
- And what Claude did vs. what it should have done
- And the user's correction verbatim (or paraphrased)
- And optionally a proposed fix if the correction implies one
