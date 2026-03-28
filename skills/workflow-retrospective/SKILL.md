---
name: workflow-retrospective
description: Use after completing an epic or periodically to analyze workflow effectiveness - queries beads for patterns, measures verification rates, identifies which phases catch vs miss errors, proposes data-driven adjustments, saves findings to memory
---

<skill_overview>
Analyze workflow effectiveness by querying beads history, measuring verification pass rates and rework rates, identifying error pattern trends, and proposing concrete adjustments. Data-driven feedback loop for continuous workflow improvement.
</skill_overview>

<rigidity_level>
HIGH FREEDOM - Adapt analysis depth to available data. The 5-step process (Gather, Analyze, Report, Propose, Save) is mandatory, but what you find and recommend varies by project history.
</rigidity_level>

<quick_reference>
| Step | Action | Output |
|------|--------|--------|
| 1. Gather | Query beads for closed epics, tasks, comments | Raw data |
| 2. Analyze | Calculate metrics, identify patterns | Findings |
| 3. Report | Present structured metrics report | Metrics dashboard |
| 4. Propose | Recommend workflow adjustments based on data | Action items |
| 5. Save | Persist key findings to auto-memory | Cross-session awareness |

**Metrics tracked:**
- First-pass verification rate (target: >80%)
- Rework rate (target: <20%)
- Error type distribution (pattern, edge case, integration, stale assumption)
- Tier classification accuracy
- Phase effectiveness (which phases catch which errors)
</quick_reference>

<when_to_use>
- After completing any epic (as part of Phase 5: Close in workflow-orchestrator)
- On demand when you want to review workflow effectiveness
- Periodically during active dogfooding (suggested: weekly)
- When noticing recurring error patterns across projects

**Don't use when:**
- No completed epics exist yet (no data to analyze)
- Mid-epic execution (wait until epic closes)
- For debugging a specific issue (use debugging-with-tools)
</when_to_use>

<the_process>

## Step 1: Gather Data

**Announce:** "I'm using the workflow-retrospective skill to analyze workflow effectiveness."

### Query beads for completed work

```bash
# List all closed epics
bd list --status closed --type epic

# For each epic, show details (requirements, success criteria, children)
bd show [epic-id]

# List all closed tasks with their epic parents
bd list --status closed --type feature

# Check for verification failure comments
bd comments [epic-id]
```

### Data points to collect per epic

For each closed epic, record:
- **Epic ID and name**
- **Tier** (Quick/Standard/Complex) - infer from task count and planning depth
- **Task count** - how many tasks were created
- **Verification failures** - count of "Verification failure" comments (from Phase 4)
- **Rework instances** - tasks that were reopened or had multiple fix-verify cycles
- **Error types found** - categorize from review comments:
  - Pattern mismatch (code doesn't match existing codebase conventions)
  - Edge case (boundary conditions, null handling, error states)
  - Integration failure (pieces don't connect correctly)
  - Stale assumption (based on outdated information)
- **Phase that caught the error** - investigation, TDD, verification, code review

### Handle missing data gracefully

If no verification failure comments exist, note it:
- Either verification always passed first try (good!) or failures weren't logged (process gap)
- If no comments at all: recommend adding bd comments for verification failures going forward

---

## Step 2: Analyze Patterns

### Calculate metrics

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

**Tier Distribution:**
- Quick: X epics (X%)
- Standard: X epics (X%)
- Complex: X epics (X%)

**Phase Effectiveness:**
For each error caught, which phase caught it?
- Phase 2 (Investigate): X errors
- Phase 3 (TDD): X errors
- Phase 4 (Verify): X errors
- Code Review Agent: X errors
```

### Identify trends

Look for:
- **Improving metrics** - verification rate going up? Celebrate and note what's working.
- **Declining metrics** - rework rate increasing? Identify why.
- **Recurring error types** - same type keeps appearing? The responsible phase needs strengthening.
- **Tier classification accuracy** - are Quick tasks taking Standard-level effort? Recalibrate heuristics.
- **Phase gaps** - if code review catches most errors, earlier phases (investigation, TDD) may need strengthening.

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

### Error Type Distribution

| Error Type | Count | % | Trend |
|-----------|-------|---|-------|
| Pattern mismatch | X | X% | [UP/DOWN/STABLE] |
| Edge cases | X | X% | [UP/DOWN/STABLE] |
| Integration | X | X% | [UP/DOWN/STABLE] |
| Stale assumptions | X | X% | [UP/DOWN/STABLE] |

### Phase Effectiveness

| Phase | Errors Caught | % of Total |
|-------|--------------|------------|
| Phase 2: Investigate | X | X% |
| Phase 3: TDD | X | X% |
| Phase 4: Verify | X | X% |
| Code Review Agent | X | X% |

### Tier Distribution

| Tier | Epics | Accuracy |
|------|-------|----------|
| Quick | X | [correct/over-classified/under-classified] |
| Standard | X | [correct/over-classified/under-classified] |
| Complex | X | [correct/over-classified/under-classified] |

### Strengths
- [What's working well, with evidence]

### Areas for Improvement
- [What needs attention, with evidence]
```

---

## Step 4: Propose Adjustments

Based on the data, propose **specific, actionable** adjustments. Do NOT propose vague improvements.

### Decision matrix

| Finding | Proposed Adjustment |
|---------|-------------------|
| Pattern mismatches >30% of errors | Strengthen Phase 2: require codebase-investigator agent for ALL tiers (not just Standard+) |
| Edge cases >30% of errors | Strengthen SRE refinement: run on ALL tasks (not just Complex) |
| Integration failures >20% of errors | Add integration test requirement to Tests task template |
| Stale assumptions >10% of errors | Add memory verification step: check memory claims against current code before using |
| First-pass verification <60% | Phase 3 (TDD) not catching enough: review test quality with analyzing-test-effectiveness |
| Rework rate >30% | Tasks too vague: increase SRE refinement coverage |
| Code review catches >50% of errors | Earlier phases (investigate, TDD) need strengthening - errors should be caught sooner |
| Quick tier tasks taking >2 hours | Tier classification heuristics need recalibration - raise the bar for Quick |
| Verification always passes first try | Either process is excellent OR verification is too lenient - check test quality |

### Present as action items

```markdown
## Proposed Adjustments

### Priority 1 (Act Now)
- [ ] [Specific adjustment with data-backed reasoning]

### Priority 2 (Next Sprint)
- [ ] [Specific adjustment with data-backed reasoning]

### Priority 3 (Monitor)
- [ ] [Observation to track, not yet actionable]
```

**Important:** Do NOT modify the workflow-orchestrator skill directly. Present proposals for user approval first.

---

## Step 5: Save to Memory

Save key findings to auto-memory for cross-session awareness:

```markdown
# Memory entry: workflow-retrospective-[date]

## What to save:
- Current verification pass rate
- Top error type and trend
- Any approved workflow adjustments
- Tier classification accuracy notes

## What NOT to save:
- Raw data (query beads fresh next time)
- Detailed metrics (recalculate from current data)
- Unapproved proposals (may become stale)
```

Write to `/Users/jon/.claude/projects/[project-path]/memory/` using the auto-memory system:
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
<scenario>Retrospective reveals code review catches most errors</scenario>

<code>
## Phase Effectiveness
| Phase | Errors Caught | % |
|-------|--------------|---|
| Investigate | 1 | 10% |
| TDD | 2 | 20% |
| Verify | 2 | 20% |
| Code Review | 5 | 50% |

Claude proposes:
"Code review catches 50% of errors. This means Phase 2 (Investigate) and
Phase 3 (TDD) are missing issues that should be caught earlier.

Proposed adjustment: Require codebase-investigator agent for Quick tier
(currently only Standard+). This would catch pattern mismatches earlier."
</code>

<why_it_fails>
N/A - this is the correct analysis. Errors caught late (code review) are
more expensive to fix than errors caught early (investigation, TDD).
The proposal is specific, data-backed, and actionable.
</why_it_fails>

<correction>
No correction needed. The adjustment targets the right phase based on
error type analysis. Pattern mismatches should be caught during investigation,
not during code review.
</correction>
</example>

<example>
<scenario>Developer runs retrospective without saving to memory</scenario>

<code>
# Completes Steps 1-4 (gather, analyze, report, propose)
# Skips Step 5 (save to memory)

Claude: "Retrospective complete! Here are the findings..."
# Doesn't save anything to memory
# Next session has no awareness of retrospective findings
# Same issues may recur without cross-session context
</code>

<why_it_fails>
Without saving to memory, the retrospective has no lasting impact.
The next session starts fresh with no awareness of identified patterns
or approved adjustments. The feedback loop is broken.
</why_it_fails>

<correction>
Always complete Step 5. Save:
- Current pass rate and top error type
- Any approved adjustments
- Tier calibration notes

This ensures the next session can reference previous findings
and track whether adjustments are having the desired effect.
</correction>
</example>

</examples>

<critical_rules>
## Rules That Have No Exceptions

1. **All 5 steps must run** - Gather, Analyze, Report, Propose, Save. No skipping.
2. **Data-driven only** - Every finding must reference specific beads data. No subjective assessments.
3. **Don't modify workflow directly** - Propose adjustments for user approval. Never auto-apply changes to orchestrator skill or hooks.
4. **Adapt to data availability** - Limited data = limited conclusions. Don't fabricate trends from 2 data points.
5. **Save to memory** - Findings without persistence have no lasting impact.
6. **No hardcoded paths** - Must work in any project with beads initialized.

## Common Rationalizations

- "Not enough data to run retrospective" -> Run with available data, note limitations, set target for re-run.
- "Everything seems fine, skip the analysis" -> Metrics may reveal hidden issues. Run the numbers.
- "I'll save to memory later" -> Save now. Later doesn't happen.
- "This adjustment is obviously right, I'll just apply it" -> Propose, don't apply. User approves changes.
</critical_rules>

<verification_checklist>
Before completing retrospective:

- [ ] Step 1: Queried beads for closed epics and tasks
- [ ] Step 2: Calculated all metrics (pass rate, rework rate, error distribution, tier distribution, phase effectiveness)
- [ ] Step 3: Generated structured report with tables
- [ ] Step 4: Proposed specific adjustments with data-backed reasoning
- [ ] Step 5: Saved key findings to auto-memory
- [ ] No subjective claims without data evidence
- [ ] No direct modifications to workflow skills or hooks
- [ ] Data limitations clearly noted if insufficient history
</verification_checklist>

<integration>
**This skill is called by:**
- workflow-orchestrator Phase 5 (Close) - after epic completion
- User on demand (periodic review)

**This skill calls:**
- bd commands (list, show, comments) for data gathering
- Auto-memory system for persistence

**This skill proposes changes to:**
- workflow-orchestrator (tier heuristics, phase requirements)
- Hook configurations (enforcement rules)
- SRE refinement scope

**Changes are PROPOSED, not applied.** User must approve before implementation.

**Recommended cadence:**
- After every epic completion (lightweight, 5 min)
- Weekly during active dogfooding (full analysis, 15 min)
- Monthly for trend analysis across projects (comprehensive, 30 min)
</integration>
