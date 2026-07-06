# Decision 0002 — Per-dispatch model tiering for mechanical stages

Date: 2026-07-05 · Status: accepted · Supersedes part of D4 (agent-frontmatter model pins).

## Context

The workflow's dominant token cost is the per-spec agent fan-out: a full-stack spec
dispatches ~13 subagents, and the /build verify pass (3.3a–3.3i) is the largest sink.
Decision D4 deleted the `model:` frontmatter pins from all 16 agents because those pins
were **stale and inverted** (qa-engineer on sonnet while narrative-designer got opus) and
drifted from the session model. D4 was correct for what it removed.

D4 left a real lever unused: several stages are **mechanical** — they locate files, run a
test suite, or pattern-match weak assertions — and do not benefit from frontier reasoning,
yet they now inherit the (expensive) session model like every judgment stage.

## Decision

Tier the model **per dispatch**, chosen by the orchestrator from context, not pinned in
agent frontmatter:

- **Mechanical (one tier below the session model):** 3.3a test-runner, 3.3b
  test-effectiveness, Step 3.1 codebase-investigator, Step 3.2.6 dead-UI scan.
- **Judgment (session model):** 3.3c code-review, 3.3d security, 3.3e devops, 3.3f data,
  3.3g qa, 3.3h sre-audit, application-architect decomposition, product-owner questioning,
  and the design/respec reasoning steps.

Expressed as a `model:` hint on the `Agent` dispatch in `skills/build/SKILL.md`, plus the
"Cost discipline" guidance at the verify-pass header.

## Why this is not a reversal of D4

D4 removed **static, per-agent, drift-prone** pins. This is **dynamic, per-call, context-
chosen** tiering: the same agent can run at a cheap tier for a routine mechanical pass and
be re-dispatched at the session model when it surfaces something ambiguous. The frontmatter
stays pin-free (D4 holds); the tier is a property of the dispatch, not the role.

## Guardrails

- Tiering never applies to a **gate's judgment** — only to stages whose output is a
  mechanical report (test pass/fail, file locations, weak-assertion flags).
- Any mechanical stage that returns something surprising is re-dispatched at the session
  model before its finding is trusted.
- Companion levers (summary-first handoff reads, one-message parallel fan-out) are in the
  same "Cost discipline" block and are pure wins (no quality tradeoff).
