# Role-Agent Protocol

Shared exit, questioning, memory, and tool rules for every role agent in `~/.claude/agents/`.
Each agent's prompt file defines its role-specific handoff path(s) in its "Exit protocol"
section; everything else about how a dispatch starts and ends is defined here, once.

## 1. The handoff is the deliverable

Your dispatch is complete when your handoff file exists on disk — not when you compose a
verbal reply. Before returning, in order:

1. **Write your handoff file** to the path documented in your prompt's "Exit protocol"
   section (or the fix-cycle variant below). Required sections per
   `~/.claude/workflow/docs/role-agent-handoff-schema.md`.
2. **Verify it exists on disk** — open it via Read or `ls`. Do not trust that a write
   succeeded without checking.
3. **Update your memory file** (section 3 below).
4. **Return a short confirmation** (≤ 100 words) naming (a) the handoff path you wrote and
   (b) the memory entries you added. The verbal return is a receipt, not the deliverable.
   Returning without the handoff on disk is an incomplete dispatch; the orchestrator will
   re-dispatch you.

**Fix-cycle dispatches.** When the orchestrator dispatches you in a fix cycle (its prompt
names the cycle number N):

- Implementers write `specs/handoffs/step-3.2-<slug>-<role>-fix-cycle-<N>.html`.
- Reviewers re-verifying fixes write `specs/handoffs/step-3.3-<slug>-<role>-fix-cycle-<N>.html`.

The `require-fix-cycle-handoff.sh` hook blocks `@status(verified)` on specs with asymmetric
fix-cycle handoffs (e.g. a reviewer wrote a re-verify but the implementer skipped its
handoff). The hook is a downstream backstop; the responsibility to write the artifact is
yours, in this dispatch, before you return.

*Why this rule exists:* in the 2026-05-26 SquashBuckler dogfood, implementer agents
dispatched in fix mode twice did the code work but returned without writing the fix-cycle
handoff or updating memory, forcing the orchestrator to either synthesize a fake artifact or
skip the cycle. Treat the handoff write as the last thing you do, not a step to drop under
pressure.

## 2. You cannot ask the user questions

`AskUserQuestion` is unavailable inside subagents — empirically verified, not a style
preference (see `~/.claude/workflow/docs/harness-behavior.md`). When user input is required:

- Add each question to your handoff's `open-questions` section as
  `<li data-question data-blocking="true|false">`.
- Give 2–4 proposed options with concrete tradeoffs, and state your recommendation.
- Mark `data-blocking="true"` only when you cannot responsibly proceed without the answer.
- Then return. The orchestrator relays blocking questions to the user via AskUserQuestion
  and re-dispatches you with the answers.

**Never fabricate an answer to a blocking question.** A wrong guess propagates through every
downstream handoff; a relayed question costs one round trip.

## 3. Memory protocol

Your memory file is `.claude/agent-memory/<role>.md` in the project. It is committed to git
and accumulates project-level context that compounds across dispatches (the per-spec
codebase-investigator augments it for the current task; both are referenced from handoffs
via `data-input-references`).

- **At dispatch start, before any other work:** read it. If it does not exist, `/onboard`
  has not run — bootstrap it from
  `~/.claude/skills/onboard/resources/memory-template-<role>.md`.
- **Before returning:** append durable learnings — a Recent changes entry (rolling cap
  of 5; trim oldest), updates to your role's primary section (named in your prompt), Known
  issues entries for anything flagged for follow-up, and `last-updated` /
  `last-commit-sha` frontmatter set to HEAD at seconds precision (never `T00:00:00Z`).
- **Never store secrets, tokens, or PII.** Use pointers (env var names, file paths, beads
  IDs) — never values. The `guard-agent-memory-secrets.sh` hook scans memory writes and
  blocks secret-shaped content.

## 4. No sleep-polling

Never poll background work with `sleep` (e.g. `sleep 60 && tail log`) — launch it with
`run_in_background: true` and let the harness notify you on completion, or use Monitor.

## 5. Read only what you need (context economy)

Handoffs accumulate through a spec, and every reviewer that reads all of them in full pays
for the whole pile. Default to the cheap read; escalate only when your task needs the detail.

- **Upstream handoffs:** read the `data-role="summary"` and `data-role="acceptance-criteria"`
  sections first (5–15 lines). Open the full `findings` section ONLY when your job needs a
  specific artifact in it — e.g. the architect's decomposition table, the engineer's wiring
  evidence, a reviewer's exact file:line finding you are re-verifying. Naming which handoff
  detail you opened (and why) in your own findings is good practice.
- **The spec and the diff are your primary inputs** — read those fully. The handoffs are
  context around them, not a substitute for reading the code you are judging.
- **Memory:** read Summary + Conventions + your role's primary section always; drill into
  Pointers only when the current task references something there (per section 3).
- **Do not re-read what you already have.** If the dispatch prompt pasted the spec or a diff,
  don't re-open the file. If two upstream handoffs cover the same fact, read one.

This is a floor on cost, never on rigor: if a summary is ambiguous or a finding smells wrong,
read the full source. Skipping a detail you needed is a worse failure than a few extra tokens.
