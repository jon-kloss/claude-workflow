# A/B Testing Protocol: Workflow vs Vanilla Claude

## Purpose
Compare the adaptive workflow against vanilla Claude (no skills, no workflow) on identical benchmark tasks to measure correctness improvement.

## Setup

### Session A: With Workflow
- All plugins enabled (hyperpowers, beads, workflow-orchestrator)
- All hooks active (read-tracking, workflow-reminder, verification gate)
- CLAUDE.md with workflow instructions
- Run benchmark task and follow the workflow-orchestrator skill

### Session B: Vanilla Claude
- Disable all plugins: set all to `false` in settings.json
- Remove hooks section from settings.json
- No CLAUDE.md (or minimal CLAUDE.md without workflow instructions)
- Give the same benchmark task as a plain prompt
- Let Claude handle it however it naturally would

### Important Controls
- Use the SAME benchmark task for both sessions
- Use the SAME model (Opus)
- Start each session fresh (`/clear`)
- Do NOT give hints in Session B about what the workflow would do
- Record wall-clock time for both sessions

## Execution Steps

1. **Select benchmark** - Pick one from `benchmarks/` directory
2. **Prepare starter repo** - Set up the git repo described in the benchmark's Setup section
3. **Run Session A** (Workflow):
   - Start fresh Claude session in the starter repo
   - Give the task description exactly as written
   - Let the workflow-orchestrator skill drive the process
   - Record: time, actions taken, final output
4. **Reset repo** - `git checkout .` to restore starter state
5. **Run Session B** (Vanilla):
   - Disable plugins, remove hooks
   - Start fresh Claude session in the same repo
   - Give the SAME task description
   - Let Claude handle it naturally
   - Record: time, actions taken, final output
6. **Score both** - Apply the benchmark's rubric to each session's output
7. **Record results** in the results template below

## Scoring Template

```markdown
## A/B Test Results: [Benchmark Name]
**Date:** [date]
**Benchmark:** [benchmark file]

### Session A (Workflow)
**Time:** [minutes]
**Score:** [X/Y]

| Criterion | Points | Notes |
|-----------|--------|-------|
| [criterion 1] | [0-N] | [observation] |
| ... | ... | ... |

**Observations:**
- [What the workflow did well]
- [Where the workflow added overhead]
- [Errors caught by workflow that vanilla might miss]

### Session B (Vanilla)
**Time:** [minutes]
**Score:** [X/Y]

| Criterion | Points | Notes |
|-----------|--------|-------|
| [criterion 1] | [0-N] | [observation] |
| ... | ... | ... |

**Observations:**
- [What vanilla Claude did well]
- [What vanilla Claude missed]
- [Errors that would have been caught by workflow]

### Comparison
| Metric | Workflow | Vanilla | Delta |
|--------|---------|---------|-------|
| Score | X/Y | X/Y | +/- N |
| Time | Xm | Xm | +/- Nm |
| Beads created | Y/N | N/A | - |
| Investigation done | Y/N | Y/N | - |
| Tests written | Y/N | Y/N | - |
| Pattern adherence | [0-5] | [0-5] | +/- N |
| Edge cases caught | [count] | [count] | +/- N |

### Verdict
[Workflow better / Vanilla better / Tie]
**Key insight:** [What the comparison reveals about workflow value]
```

## Recommended Test Order

Run benchmarks in this order to build understanding progressively:

1. **01-quick-fix-typo** - Baseline: does workflow add value for trivial tasks?
2. **04-standard-fix-bug** - Investigation quality: does workflow find root cause better?
3. **06-complex-new-feature** - Full workflow: does brainstorming + SRE refinement improve outcomes?
4. **05-standard-refactor** - Pattern awareness: does investigation catch subtle differences?
5. **03-standard-add-endpoint** - Pattern consistency: does codebase investigation improve adherence?
6. **02-quick-add-field** - Validation patterns: does investigation help follow conventions?

## Statistical Considerations

- With 6 benchmarks, you won't have statistical significance. This is qualitative comparison.
- Focus on PATTERNS: does the workflow consistently score higher on specific rubric categories?
- The most informative result is WHICH criteria differ, not the total score.
- Run each benchmark once initially. Re-run any where results are ambiguous.
- After 10+ A/B tests across real projects, trends become meaningful.

## When to Re-run

- After any workflow adjustment (to measure impact)
- After adding/changing hooks
- Monthly during active dogfooding
- When retrospective identifies a phase that might be underperforming
