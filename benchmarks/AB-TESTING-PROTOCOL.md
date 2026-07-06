# A/B Testing Protocol: Workflow vs Vanilla Claude Code

## Purpose

Compare the adaptive workflow (`/design` → `/build`, role agents, hooks) against vanilla
Claude Code on identical benchmark tasks. Two questions, answered separately:

1. **Outcome** — is the final code better (correct, complete, pattern-consistent)?
2. **Adherence** — did Session A actually follow the current pipeline? Measured entirely
   from **artifacts on disk** (specs, handoffs, beads, git history), never from transcript
   vibes. If Session A scores well on outcome but poorly on adherence, the workflow didn't
   cause the outcome.

Every rubric criterion in `benchmarks/01-*.md` … `06-*.md` is a command or file predicate
a scorer can run. No judgment calls beyond the few explicitly marked "scorer eyeball".

## Setup

### Session A: With Workflow

- The workflow is installed (`~/.claude/workflow/install.sh` has been run): hooks active in
  settings, skills linked, role agents present in `~/.claude/agents/` (`product-owner.md`,
  `application-architect.md`, etc.).
- Fresh temp project repo built from the benchmark's Setup section; `git init` + initial
  commit; `bd init` run in the project.
- Invoke `/design` with the benchmark's Task Description verbatim. Answer the relayed
  Socratic questions as a reasonable product owner would (note your answers). Approve at
  the reality check. Then run `/build --auto`.
- Role agents are dispatched via the Agent tool; each produces an HTML handoff under
  `specs/handoffs/` per `docs/registry.md` §1 and `docs/role-agent-handoff-schema.md`.

### Session B: Vanilla Claude Code

- A machine/checkout where the workflow is **not installed** (run `uninstall.sh`, or use a
  clean environment): no workflow hooks in settings, no workflow skills, no role agents,
  no workflow section in CLAUDE.md.
- Same starter repo, rebuilt fresh (`git checkout .` is not enough if Session A created
  untracked files — re-clone or `git clean -fdx && git checkout .`).
- Give the same Task Description as a plain prompt. Let Claude handle it however it
  naturally would. Do NOT hint at specs, beads, or any workflow concept.

### Important Controls

- SAME task text, SAME starter repo state, SAME model, fresh session (`/clear`) each run.
- Append this neutral suffix to the prompt in **both** sessions:
  `"Commit your work as you go, with a descriptive message at each meaningful step."`
  This is what makes the git-history checks (status-tag progression, fix-before-test
  ordering) scoreable. It is workflow-neutral: both sessions get it.
- Before Session A, snapshot the override-audit ledger so you can score the delta:

  ```bash
  cp ~/.claude/hooks/state/override-audit.log ./.override-baseline 2>/dev/null || : > ./.override-baseline
  ```

- Record wall-clock time for both sessions.
- If Session A stalls on a blocking hook, that is DATA — record which hook, what the
  message said, and whether the session used a documented override tag. Do not hand-edit
  artifacts to unstick it.

## Execution Steps

1. **Select benchmark** — one file from `benchmarks/`.
2. **Prepare starter repo** — per the benchmark's Setup section; commit the starter state
   and note the base commit: `BASE=$(git rev-parse HEAD)`.
3. **Run Session A** — `/design` with the task text, answer questions, approve,
   `/build --auto`. Record time.
4. **Score Session A** — run every check command in the benchmark's rubric (see Scoring
   Method). Fill the score sheet.
5. **Reset repo** — re-clone or `git clean -fdx && git checkout "$BASE"`.
6. **Run Session B** — plain prompt in the vanilla environment. Record time.
7. **Score Session B** — same sheet. Adherence criteria will mostly be FAIL/N-A for
   Session B by construction; that's expected — the comparison that matters there is the
   Outcome block.
8. **Record results** in the template below.

## Scoring Method (mechanical)

Each benchmark's rubric has two blocks:

- **Outcome criteria (O-block)** — properties of the final code both sessions can earn:
  all instances fixed, root cause in the right layer, tests pass, edge cases covered.
  This is the honest A-vs-B comparison.
- **Adherence criteria (A-block)** — artifacts the current pipeline must leave on disk:
  spec files with `@status` progression, `@layer` tags, the handoff chain for the spec's
  layer (registry §1), `data-verdict` metas (registry §4), beads epic + Tests gate closed
  in order, an empty (or justified) override-audit delta. Session B is expected to score
  ~0 here; the block exists to verify Session A ran the pipeline it claims to measure.

To score: `cd` into the run's repo, set the variables the rubric names (each benchmark
tells you how to discover them):

```bash
BASE="<starter-state commit sha>"
SLUG="<spec slug>"          # from: ls specs/*.md
EPIC="<beads epic id>"                            # from: bd list --type=epic --all
```

then run each criterion's printed command. A criterion is PASS iff its stated predicate
holds (usually: the command exits 0, or prints the stated expected output). Criteria
marked **N/A-when** are scored N/A (excluded from the denominator) when their trigger
condition is absent — e.g. Mount Map checks in an epic with <2 UI specs.

Two cross-cutting observations to record for Session A (not scored, but reported):

```bash
# How much of the "multi-agent" run was actually inline-synthesized?
grep -rl 'data-synthesized' specs/handoffs/ 2>/dev/null | wc -l

# Override-audit delta (each added line must be individually justified in the write-up)
diff ./.override-baseline ~/.claude/hooks/state/override-audit.log
```

## Results Template

```markdown
## A/B Test Results: [Benchmark Name]
**Date:** [date]   **Benchmark:** [file]   **Model:** [model]   **Base commit:** [sha]

### Session A (Workflow)
**Time:** [minutes]
**Outcome score:** [X/Y]   **Adherence score:** [X/Y] ([N] N/A)
| ID | Criterion | PASS/FAIL/N-A | Notes |
|----|-----------|---------------|-------|
| O1 | ... | | |
| A1 | ... | | |

Synthesized handoffs: [N of M]   Override-audit delta: [empty / N entries, justified?]
Hooks that blocked mid-run: [list + resolution]

### Session B (Vanilla)
**Time:** [minutes]
**Outcome score:** [X/Y]   (Adherence: [X/Y], expected ≈0)
| ID | Criterion | PASS/FAIL/N-A | Notes |
|----|-----------|---------------|-------|

### Comparison
| Metric | Workflow | Vanilla | Delta |
|--------|----------|---------|-------|
| Outcome score | X/Y | X/Y | +/- N |
| Time | Xm | Xm | +/- Nm |
| Edge cases caught (O-block detail) | N | N | +/- N |

### Verdict
[Workflow better on outcome / Vanilla better / Tie] — with adherence [high/partial/low]
**Key insight:** [which specific criteria differed, and why]
```

## Recommended Test Order

1. **01-quick-fix-typo** — overhead floor: does the `@trivial` path stay cheap while the
   spec/verification floor still holds?
2. **04-standard-fix-bug** — investigation quality: root cause vs symptom.
3. **06-complex-new-feature** — full pipeline: decomposition, dependency order, failure
   isolation.
4. **05-standard-refactor** — does anyone catch the subtly-different fourth regex?
5. **03-standard-add-endpoint** — pattern consistency with the existing codebase.
6. **02-quick-add-field** — convention following on a small change.

## Statistical Considerations

- With 6 benchmarks and single runs, you have anecdotes, not statistics. Model
  nondeterminism means the same session setup can score differently tomorrow.
- Compare **distributions, not single runs**: repeat any benchmark whose result drives a
  decision at least 3 times per arm before believing a delta.
- The most informative result is WHICH criteria differ, not the total. A consistent
  Session-B failure on one O-criterion (e.g. the file-4 regex discrepancy in 05) is worth
  more than a 2-point aggregate gap.
- Adherence scores are not evidence the workflow is *good* — they are evidence the run
  actually exercised it. Only O-block deltas argue value.

## When to Re-run

- After any change to skills/, agents/, or hooks/ (measure impact).
- Monthly during active dogfooding.
- When a retrospective flags a step as underperforming — re-run the benchmark that
  exercises that step.
