---
name: workflow-retrospective
description: Use after completing an epic or periodically to analyze workflow effectiveness - queries beads for incident logs and metrics, triages incidents by pattern frequency, drafts actual skill file edits for recurring patterns, saves findings to memory
---

<skill_overview>
Analyze workflow effectiveness by querying beads history for both incident logs and quantitative metrics. Triage incidents by pattern frequency — recurring patterns (2+ incidents of the same category+skill) get drafted skill file edits, one-offs get prose proposals. Data-driven feedback loop for continuous workflow improvement.
</skill_overview>

<rigidity_level>
HIGH FREEDOM - Adapt analysis depth to available data. The 5-step process (Gather, Analyze/Triage, Report, Propose, Save) is mandatory, but what you find and recommend varies by project history.
</rigidity_level>

<quick_reference>
| Step | Action | Output |
|------|--------|--------|
| 1. Gather | Query beads for closed epics, tasks, incident + verification comments | Raw data (metrics + incidents) |
| 2. Analyze/Triage | Calculate metrics, triage incidents by category+skill frequency | Findings + triage results |
| 3. Report | Present structured metrics report + incident triage | Dashboard + triage table |
| 4. Propose | Draft skill edits for recurring patterns, prose for one-offs | Drafted edits + proposals |
| 5. Save | Persist key findings to auto-memory | Cross-session awareness |

**Metrics tracked:**
- First-pass verification rate (target: >80%)
- Rework rate (target: <20%)
- Error type distribution (pattern, edge case, integration, stale assumption)
- Phase effectiveness (which /build steps catch which errors)

**Incident triage:**
- Recurring (2+ same category+skill) → drafted SKILL.md edits
- One-off → prose proposal + "monitor — may become a pattern"
</quick_reference>

<when_to_use>
- After completing any epic (as part of /build Phase 4: Close)
- On demand when you want to review workflow effectiveness
- Periodically during active use (suggested: weekly)
- When noticing recurring error patterns across projects

**Don't use when:**
- No completed epics exist yet (no data to analyze)
- Mid-epic execution (wait until epic closes)
- For debugging a specific issue (use debugging-with-tools)
</when_to_use>

<the_process>

## Step 1: Gather Data

**Announce:** "I'm using the workflow-retrospective skill to analyze workflow effectiveness."

### Query beads for completed work and incidents

```bash
# List all closed epics
bd list --status closed --type epic

# For each epic, show details and comments
bd show [epic-id]
bd comments [epic-id]

# List all closed tasks with their epic parents
bd list --status closed --type feature

# Check for a workflow-incidents issue (incidents logged outside of epics)
bd search "Workflow Incidents"
# If found, read its comments too:
bd comments [workflow-incidents-id]
```

### Data points to collect per epic

For each closed epic, record:
- **Epic ID and name**
- **Task count** — how many tasks were created
- **Verification failures** — count of `VERIFICATION FAILURE:` comments
- **Workflow incidents** — count of `WORKFLOW INCIDENT:` comments, with full text
- **Rework instances** — tasks that were reopened or had multiple fix-verify cycles
- **Error types found** — categorize from review comments:
  - Pattern mismatch (code doesn't match existing codebase conventions)
  - Edge case (boundary conditions, null handling, error states)
  - Integration failure (pieces don't connect correctly)
  - Stale assumption (based on outdated information)
- **Step that caught the error** — investigation, TDD, verification, code review

### Parse incident comments

For each `WORKFLOW INCIDENT:` comment, extract the structured fields:
- **Category**: skill-gap | missing-rule | wrong-default | edge-case | process-violation
- **Skill**: design | build | retrospective | hook-name | none
- **What happened**: what Claude did wrong
- **What should have happened**: correct behavior
- **User correction**: what the user said
- **Proposed fix**: optional suggestion

### Handle missing data gracefully

- If no `WORKFLOW INCIDENT:` comments exist: note it — either no incidents occurred (good!) or incident logging wasn't active yet. Recommend using the detect-correction hook going forward.
- If no `VERIFICATION FAILURE:` comments exist: either verification always passed first try or failures weren't logged.
- If no comments at all: recommend enabling incident logging and verification failure comments.

---

## Step 2: Analyze and Triage

### Calculate quantitative metrics

```markdown
## Metrics Calculation

**First-Pass Verification Rate:**
= (epics with 0 verification failures) / (total closed epics) * 100
Target: >80%

**Rework Rate:**
= (tasks with rework) / (total closed tasks) * 100
Target: <20%

**Error Type Distribution:**
Count each error type across all epics. Present as percentage:
- Pattern mismatch: X%
- Edge cases: X%
- Integration: X%
- Stale assumptions: X%

**Step Effectiveness:**
For each error caught, which /build step caught it?
- Step 3.1 (Investigate): X errors
- Step 3.2 (TDD): X errors
- Step 3.3 (Verify): X errors
- Code Review Agent: X errors
```

### Triage incidents by pattern frequency

Group all `WORKFLOW INCIDENT:` comments by **category + skill** pair:

```markdown
## Incident Triage

| Category + Skill | Count | Classification | Action |
|---|---|---|---|
| missing-rule + build | 3 | RECURRING | Draft skill edit |
| edge-case + design | 2 | RECURRING | Draft skill edit |
| skill-gap + build | 1 | ONE-OFF | Prose proposal + monitor |
| process-violation + none | 1 | ONE-OFF | Prose proposal + monitor |
```

**Classification rules:**
- **RECURRING** (2+ incidents of same category+skill) → flagged for drafted skill edits in Step 4
- **ONE-OFF** (1 incident) → prose proposal only, noted as "monitor — may become a pattern"

### Identify trends

Look for:
- **Improving metrics** — verification rate going up? Note what's working.
- **Declining metrics** — rework rate increasing? Identify why.
- **Recurring incident patterns** — same category+skill keeps appearing? The skill needs updating.
- **Step gaps** — if code review catches most errors, earlier steps need strengthening.
- **Incident vs. metric correlation** — do incident categories match error type distribution?

---

## Step 3: Generate Report

Present findings in this structured format:

```markdown
## Workflow Retrospective Report
**Date:** [current date]
**Project:** [project name]
**Period:** [first closed epic date] to [last closed epic date]
**Epics analyzed:** [count]

### Key Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| First-pass verification rate | X% | >80% | [MET/BELOW] |
| Rework rate | X% | <20% | [MET/ABOVE] |
| Avg tasks per epic | X | - | - |
| Most common error type | [type] | - | - |
| Workflow incidents logged | X | - | - |

### Error Type Distribution

| Error Type | Count | % | Trend |
|-----------|-------|---|-------|
| Pattern mismatch | X | X% | [UP/DOWN/STABLE] |
| Edge cases | X | X% | [UP/DOWN/STABLE] |
| Integration | X | X% | [UP/DOWN/STABLE] |
| Stale assumptions | X | X% | [UP/DOWN/STABLE] |

### Step Effectiveness

| Step | Errors Caught | % of Total |
|------|--------------|------------|
| Step 3.1: Investigate | X | X% |
| Step 3.2: TDD | X | X% |
| Step 3.3: Verify | X | X% |
| Code Review Agent | X | X% |

### Incident Triage

| Category + Skill | Count | Status | Incidents |
|---|---|---|---|
| [category] + [skill] | X | RECURRING / ONE-OFF | [brief descriptions] |

### Strengths
- [What's working well, with evidence]

### Areas for Improvement
- [What needs attention, with evidence]
```

---

## Step 4: Propose Adjustments

Based on the data, propose **specific, actionable** adjustments. Two tracks: **incident-driven** (from triage) and **metrics-driven** (from quantitative analysis).

### Track 1: Incident-Driven Proposals (from triage)

#### Recurring patterns (2+ incidents) → Draft actual skill edits

For each RECURRING incident pattern, draft the actual text that would be added to the relevant skill file. Map the incident category to the type of edit:

| Category | Edit Type | Where in SKILL.md |
|---|---|---|
| skill-gap | New step, section, or guidance | `<the_process>` section |
| missing-rule | New critical rule + rationalization | `<critical_rules>` section |
| wrong-default | Modify existing behavior/rule | Relevant section |
| edge-case | New edge case entry | `<edge_cases>` section |
| process-violation | New rationalization or strengthened enforcement | `<critical_rules>` rationalizations |

**Draft format:**

```markdown
### Drafted Edit: [skill]/SKILL.md — [section]

**Based on:** [N] incidents of [category] for /[skill]
**Incidents:**
- [incident 1 short description]
- [incident 2 short description]

**Proposed addition:**
```
[The actual text to add to the SKILL.md file]
```

**Rationale:** [Why this addition addresses the recurring pattern]
```

Present ALL drafts to the user for review before any changes are applied.

#### One-off incidents → Prose proposals

For each ONE-OFF incident, describe the incident and suggest monitoring:

```markdown
### One-Off: [short description]

**Category:** [category], **Skill:** [skill]
**What happened:** [what went wrong]
**Proposed action:** Monitor — may become a pattern. No skill edit recommended yet (insufficient signal).
```

### Track 2: Metrics-Driven Proposals

| Finding | Proposed Adjustment |
|---------|-------------------|
| Pattern mismatches >30% of errors | Strengthen investigation: require codebase-investigator for all specs |
| Edge cases >30% of errors | Strengthen SRE refinement coverage |
| Integration failures >20% of errors | Add integration test requirement to Tests task template |
| Stale assumptions >10% of errors | Add memory verification step: check memory claims against current code before using |
| First-pass verification <60% | TDD not catching enough: review test quality |
| Rework rate >30% | Tasks too vague: increase SRE refinement coverage |
| Code review catches >50% of errors | Earlier steps need strengthening — errors should be caught sooner |
| Verification always passes first try | Either process is excellent OR verification is too lenient — check test quality |

### Present combined proposals

```markdown
## Proposed Adjustments

### Priority 1: Drafted Skill Edits (Recurring Patterns)
[Each drafted edit from Track 1, with full text]

### Priority 2: Metrics-Driven Adjustments
- [ ] [Specific adjustment with data-backed reasoning]

### Priority 3: Monitor (One-Off Incidents)
- [ ] [One-off incident description — watch for recurrence]
```

**CRITICAL:** Do NOT modify skill files directly. Present all proposals (including drafted edits) for user approval first.

---

## Step 5: Save to Memory

Save key findings to auto-memory for cross-session awareness:

```markdown
# Memory entry: workflow-retrospective-[date]

## What to save:
- Current verification pass rate
- Top error type and trend
- Recurring incident patterns found (category+skill pairs)
- Any approved workflow adjustments (drafted edits that user approved)

## What NOT to save:
- Raw data (query beads fresh next time)
- Detailed metrics (recalculate from current data)
- Unapproved proposals (may become stale)
- One-off incidents (they're in beads comments — query fresh)
```

Write to the auto-memory system:
- Type: `project`
- Name: `workflow-retrospective-[date]`
- Description: "Workflow effectiveness analysis from [date] - [key finding]"

</the_process>

<examples>

<example>
<scenario>First retrospective with limited data (2 completed epics)</scenario>

<code>
bd list --status closed --type epic
# Returns: 2 closed epics

Claude: "Only 2 completed epics. Metrics will have wide confidence intervals."
# Skips trend analysis (not enough data points)
# Still generates report with available data
# Notes: "Insufficient data for trends. Run again after 5+ epics."
</code>

<why_it_fails>
This is actually correct behavior. The skill adapts to available data rather than
fabricating trends from insufficient data points.
</why_it_fails>

<correction>
No correction needed. This demonstrates the HIGH FREEDOM rigidity level -
the 5-step process runs, but analysis depth adapts to data availability.
Report clearly notes data limitations and recommends when to re-run.
</correction>
</example>

<example>
<scenario>Retrospective finds recurring missing-rule incidents for /build</scenario>

<code>
# Step 1: Gather — finds 3 WORKFLOW INCIDENT comments
# All have Category: missing-rule, Skill: build

# Step 2: Triage — groups as RECURRING (3 of same category+skill)

# Step 4: Propose — drafts actual critical rule text:
### Drafted Edit: build/SKILL.md — critical_rules

**Based on:** 3 incidents of missing-rule for /build
**Incidents:**
- "Closed task while verification agents were still running"
- "Updated @status before code review returned"
- "Said 'I'll wait' then proceeded anyway"

**Proposed addition:**
14. **Never update status while verification is in flight** -> Do NOT update
`@status` or close beads tasks while verification agents are still running.

**Rationalization to add:**
- "I'll update the status while waiting for verification" -> NO. Status
updates depend on verification results. Wait.

**Rationale:** All 3 incidents show the same pattern of acting before
verification completes. A critical rule with rationalization prevents this.
</code>

<why_it_fails>
N/A - this is the correct analysis. The recurring pattern is identified,
actual rule text is drafted, and it's presented for user approval.
</why_it_fails>

<correction>
No correction needed. The drafted edit is specific, the rationalization
addresses the observed pattern, and the user reviews before application.
</correction>
</example>

<example>
<scenario>Retrospective finds a mix of recurring and one-off incidents</scenario>

<code>
# Step 2 Triage:
# - missing-rule + build: 2 incidents → RECURRING
# - edge-case + design: 2 incidents → RECURRING
# - skill-gap + build: 1 incident → ONE-OFF

# Step 4 output:
## Priority 1: Drafted Skill Edits

### Drafted Edit: build/SKILL.md — critical_rules
**Based on:** 2 incidents of missing-rule for /build
**Proposed addition:**
15. **Always log investigation findings** -> Even if findings seem
obvious, the log is for post-mortem later, not for you now.
**Rationalization:**
- "Investigation findings are obvious" -> The log is for future
  retrospectives and session recovery, not for you in the moment.

### Drafted Edit: design/SKILL.md — edge_cases
**Based on:** 2 incidents of edge-case for /design
**Proposed addition:**
## Existing spec has mixed statuses
When decomposing a spec that is partially implemented (@status(implemented)),
assign status per-scenario: completed behaviors get @status(implemented),
incomplete behaviors get @status(approved). Ask the user to confirm via
AskUserQuestion before finalizing status assignments.

## Priority 3: Monitor
- skill-gap + build: "No guidance for handling flaky tests during
  verification." Monitor — may become a pattern.
  No skill edit yet (insufficient signal).
</code>

<why_it_fails>
N/A - this correctly separates recurring patterns (draft edits) from
one-offs (prose + monitor). The edge-case draft maps to the edge_cases
section with concrete text, while the one-off gets only a prose note.
</why_it_fails>

<correction>
No correction needed. The threshold of 2+ incidents before drafting edits
prevents overreacting to one-time issues while still tracking them.
Both critical_rules and edge_cases draft formats are demonstrated.
</correction>
</example>

</examples>

<critical_rules>
## Rules That Have No Exceptions

1. **All 5 steps must run** — Gather, Analyze/Triage, Report, Propose, Save. No skipping.
2. **Data-driven only** — Every finding must reference specific beads data. No subjective assessments.
3. **Don't modify skills directly** — Propose adjustments (including drafted edits) for user approval. Never auto-apply changes to /design, /build, or hook files.
4. **Adapt to data availability** — Limited data = limited conclusions. Don't fabricate trends from 2 data points.
5. **Save to memory** — Findings without persistence have no lasting impact.
6. **No hardcoded paths** — Must work in any project with beads initialized.
7. **Recurring = 2+ incidents** — Only draft skill edits for patterns with 2+ incidents of the same category+skill. One-offs get prose proposals only.
8. **Read both incident types** — Always collect both `WORKFLOW INCIDENT:` and `VERIFICATION FAILURE:` comments. Also check for a `workflow-incidents` issue.
9. **Drafted edits must be complete** — When drafting a skill edit, include the actual text, not just a description. "Add a rule about X" is not a drafted edit; the rule text itself is.

## Common Rationalizations

- "Not enough data to run retrospective" → Run with available data, note limitations, set target for re-run.
- "Everything seems fine, skip the analysis" → Metrics may reveal hidden issues. Run the numbers.
- "I'll save to memory later" → Save now. Later doesn't happen.
- "This adjustment is obviously right, I'll just apply it" → Propose, don't apply. User approves changes.
- "One incident is enough to draft a rule" → No. One-offs get prose proposals. Wait for the pattern to recur.
- "No incidents logged, so skip the triage" → Still run the triage step — note the absence and recommend enabling incident logging.
</critical_rules>

<verification_checklist>
Before completing retrospective:

- [ ] Step 1: Queried beads for closed epics, tasks, and comments
- [ ] Step 1: Collected all `WORKFLOW INCIDENT:` comments (from epics and workflow-incidents issue)
- [ ] Step 1: Collected all `VERIFICATION FAILURE:` comments
- [ ] Step 2: Calculated quantitative metrics (pass rate, rework rate, error distribution, step effectiveness)
- [ ] Step 2: Triaged incidents by category+skill frequency
- [ ] Step 2: Classified as RECURRING (2+) or ONE-OFF
- [ ] Step 3: Generated structured report with metrics tables AND incident triage table
- [ ] Step 4: Drafted actual skill edit text for each recurring pattern
- [ ] Step 4: Wrote prose proposals for one-off incidents
- [ ] Step 4: Presented all proposals to user for approval (not auto-applied)
- [ ] Step 5: Saved key findings to auto-memory
- [ ] No subjective claims without data evidence
- [ ] No direct modifications to skill files or hooks
- [ ] Data limitations clearly noted if insufficient history
</verification_checklist>

<integration>
**This skill is called by:**
- /build Phase 4 (Close) — after epic completion
- User on demand (periodic review)

**This skill reads:**
- `bd comments [epic-id]` — for `WORKFLOW INCIDENT:` and `VERIFICATION FAILURE:` comments
- `bd search "Workflow Incidents"` — for incidents logged outside of epics
- `bd list`, `bd show` — for quantitative data on closed epics and tasks

**This skill proposes changes to:**
- skills/design/SKILL.md (new rules, edge cases, steps)
- skills/build/SKILL.md (new rules, rationalizations, edge cases)
- skills/workflow-retrospective/SKILL.md (self-improvement)
- Hook configurations (enforcement rules)

**Changes are PROPOSED, not applied.** User must approve before implementation.

**This skill works with:**
- `detect-correction.sh` hook — logs `WORKFLOW INCIDENT:` comments that this skill reads
- /build skill — logs `VERIFICATION FAILURE:` comments that this skill reads

**Recommended cadence:**
- After every epic completion (lightweight, 5 min)
- Weekly during active use (full analysis, 15 min)
- Monthly for trend analysis across projects (comprehensive, 30 min)
</integration>
