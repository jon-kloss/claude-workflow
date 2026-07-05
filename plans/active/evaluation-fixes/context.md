# Context — evaluation-fixes

## Key files
- `EVALUATION-2026-07-04.md` — the findings this plan closes; IDs (A/H/M/I/P/R) are cited per task. READ before each task.
- `plans/active/evaluation-fixes/plan.md` — approved intent + acceptance contract.
- `docs/role-agent-handoff-schema.md` — becomes downstream of the new `docs/registry.md` after T2.1.
- `install.sh` / `uninstall.sh` — Phase 1 rewrite targets; uninstall becomes manifest-driven.
- `tests/role-agent-smoke.sh` — acceptance vehicle for Phase 3 hook fixes; gets sandboxed in T5.3.

## Discovery log
- 2026-07-04: Evaluation completed. Two harness behaviors are UNVERIFIED and gate the architecture: (1) do settings.json PreToolUse hooks fire for subagent tool calls; (2) is AskUserQuestion available in subagents. Docs say no to both (subagents doc, v2.1.172+), but the hooks audit's H1 deadlock finding assumes yes to (1). Phase 0 resolves empirically — do not start Phase 3/4 before it.
- Branch state: `experiment/role-agents`, uncommitted Mount-Map rollout + untracked `hooks/require-feature-mounted.sh`. Commit before any sweep touches the same files (T1.1).
- The smoke suite currently passes 151/151 but pollutes the real bd db and override-audit log on every run — do not treat green runs as free until T5.3.

## Constraints
- No behavior changes without a corresponding smoke/e2e assertion (the evaluation's core lesson: composition was never tested).
- All vocabulary changes flow through `docs/registry.md` + `tools/lint-consistency.sh`; no direct one-off renames.
- Ten user decisions (D1–D10) are tabled in plan.md; only their marked tasks block on them.
