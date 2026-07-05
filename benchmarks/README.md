# Benchmarks

Six tasks of increasing size for A/B-testing the workflow (`/design` → `/build`) against
vanilla Claude Code. Full protocol: [AB-TESTING-PROTOCOL.md](AB-TESTING-PROTOCOL.md).

## Running one benchmark (Session A)

```bash
# 1. Fresh temp repo from the benchmark's Setup section
mkdir /tmp/bench-01 && cd /tmp/bench-01
git init
# ...create the starter files per the benchmark's Setup section...
git add -A && git commit -m "starter"
BASE=$(git rev-parse HEAD)
bd init

# 2. Snapshot the override ledger (scored later)
cp ~/.claude/hooks/state/override-audit.log ./.override-baseline 2>/dev/null || : > ./.override-baseline

# 3. Fresh Claude Code session in the repo (workflow installed):
#      /design <task description verbatim> — answer relayed questions, approve at reality check
#      /build --auto
#    Both prompts get the suffix: "Commit your work as you go, with a descriptive
#    message at each meaningful step." (required for the git-history checks)
```

Session B: same starter repo rebuilt fresh, workflow NOT installed, task text as a plain
prompt, same commit-as-you-go suffix.

## Scoring

Each benchmark file prints the exact check command next to every criterion. Set the
variables at the top of the file (`BASE`, `SLUG`/`SPECS`, `EPIC`), then run each command
and mark PASS/FAIL/N-A on the score sheet.

- **O-block (Outcome)** — properties of the final code; the real A-vs-B comparison.
- **A-block (Adherence)** — pipeline artifacts on disk: spec `@status` progression in git,
  `@layer` tags, handoff chain per `docs/registry.md` §1, `data-verdict` metas per §4,
  beads epic + Tests gate order, override-audit delta. Verifies Session A actually ran
  the pipeline; expected ≈0 for Session B.

Criteria marked **N/A-when** drop out of the denominator when their trigger is absent.

## Honest caveats

- **Model nondeterminism dominates single runs.** The same setup can pass a criterion
  today and fail it tomorrow. Compare distributions (≥3 runs per arm for any decision),
  not single runs, and report which criteria differ rather than aggregate deltas.
- **Adherence ≠ value.** A-block scores only prove the pipeline executed; only O-block
  deltas argue the workflow helped. High A + no O delta is a real (negative) result.
- **Slug/structure checks are conventions, not proofs.** The session chooses spec slugs
  and decomposition; a handful of checks say "scorer eyeball" where a predicate can't
  capture reasonableness (e.g. whether a decomposition seam is sensible).
- **Interactive answers are a variable.** Your answers to relayed Socratic questions
  shape the spec. Keep a written crib of answers per benchmark and reuse it across runs.
- **The commit-as-you-go suffix is load-bearing.** Without it, the git-history criteria
  (status progression, test-before-fix) are unscoreable; note any run where the session
  batched everything into one commit.
