@status(verified)
@depends-on(incident-logging)

# Feature: Retrospective Overhaul

As a workflow user
I want the retrospective to read incident logs, triage them by pattern frequency, and draft actual skill file edits
So that the workflow continuously improves based on real pain points, not just quantitative metrics

## Technical Context

- **Modified file**: `skills/workflow-retrospective/SKILL.md`
- **Inputs**: Beads comments (incident logs + verification failures), closed epics/tasks
- **Outputs**: Triage report, drafted SKILL.md edits for recurring patterns (2+ incidents), prose proposals for one-offs
- **Stale references to update**: workflow-orchestrator (now /design + /build), tier classification (now inferred), old phase numbers

### Incident Categories → Skill Update Types

| Category | Update Type | Example |
|----------|------------|---------|
| skill-gap | New step or section in SKILL.md | "No guidance for decomposing specs" → add decomposition step |
| missing-rule | New critical rule or rationalization | "Closed during verification" → add rule 14 |
| wrong-default | Change existing behavior | "Bans all research during design" → narrow to codebase-only |
| edge-case | New edge case entry | "Existing spec is too large" → add decompose edge case |
| process-violation | Strengthen enforcement | "Said 'I'll wait' then acted anyway" → add rationalization |

## Background

- Given the workflow-retrospective skill exists with 5 steps (Gather, Analyze, Report, Propose, Save)
- And incidents are logged as structured beads comments during workflow execution
- And the current retro only analyzes quantitative metrics (pass rates, rework rates)

## Rule: The retro reads both incidents and metrics

### Scenario: Retro gathers incident comments alongside quantitative data

- Given closed epics have both verification failure comments and workflow incident comments
- When Step 1 (Gather) runs
- Then it collects all `WORKFLOW INCIDENT:` comments from epics and the workflow-incidents issue
- And it collects quantitative data (pass rates, rework, error types) as before
- And both data sources feed into analysis

## Rule: Incidents are triaged by pattern frequency

### Scenario: Same incident category + skill appears 2+ times

- Given two incidents both say "Category: missing-rule, Skill: build"
- When Step 2 (Analyze/Triage) runs
- Then these are grouped as a recurring pattern
- And flagged for drafted skill edits (not just prose proposals)

### Scenario: One-off incident with no pattern

- Given an incident appears only once
- When Step 2 (Analyze/Triage) runs
- Then it is reported as a one-off observation
- And gets a prose proposal (not a drafted edit)
- And is noted as "monitor — may become a pattern"

## Rule: Recurring patterns get drafted skill edits

### Scenario: Retro drafts a new critical rule

- Given 2+ incidents of category "missing-rule" for the /build skill
- When Step 4 (Propose) runs
- Then the retro drafts the actual text for a new critical rule in build/SKILL.md
- And drafts a corresponding rationalization entry
- And presents the draft to the user for review before any changes are applied

### Scenario: Retro drafts a new edge case

- Given 2+ incidents of category "edge-case" for the /design skill
- When Step 4 (Propose) runs
- Then the retro drafts the actual edge case section text for design/SKILL.md
- And presents the draft to the user for review

### Scenario: Retro presents one-off proposals as prose

- Given a one-off incident with no recurring pattern
- When Step 4 (Propose) runs
- Then it describes the incident and suggests monitoring
- And does NOT draft skill edits (insufficient signal)

## Rule: Stale references are updated

### Scenario: Retro skill no longer references deprecated concepts

- Given the retrospective skill is overhauled
- When the skill file is updated
- Then all references to "workflow-orchestrator" are replaced with "/design" and "/build"
- And tier classification references are removed (tiers are inferred)
- And phase numbers reflect the current /design and /build step numbering
- And the integration section references the current skill names
