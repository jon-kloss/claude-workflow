# Decision 0001 — Enforcement architecture after Phase 0 ground truth

Date: 2026-07-04 · Status: accepted · Inputs: `docs/harness-behavior.md` (v2.1.201), `EVALUATION-2026-07-04.md`, decisions D1–D10 (accepted per recommendations, recorded on epic workflow-8b2).

## Facts established (see harness-behavior.md for evidence)

1. settings.json PreToolUse hooks **fire inside subagents** on the installed version.
2. `AskUserQuestion` is **unavailable** inside subagents (hard error). `Skill` works.
3. UserPromptSubmit field is `prompt`; UserPromptSubmit matchers are ignored; only the `hookSpecificOutput` wrapper delivers context; PostToolUse field is `tool_response`; `session_id` + `cwd` are present in every payload; cross-session state clobbering is real and observed.

## Decisions

**E1 — Keep gates at the settings.json level (Outcome A).** No per-agent frontmatter hook duplication and no generator needed. The gates genuinely bind role agents today. T2.3 shrinks to boilerplate extraction only.

**E2 — Fix H1 by logging dispatches at PreToolUse.** Register `track-agents.sh` (or a small `track-agents-pre.sh`) on **PreToolUse** matcher `Agent` to append `<timestamp>|<role>|dispatched` at dispatch time; keep the PostToolUse entry to append the return record. `guard-handoff-owner.sh` then sees the dispatch before the agent's first handoff write. Add a smoke test: first-dispatch handoff write must be ALLOWED, non-dispatched role write must be BLOCKED.

**E3 — Orchestrator-mediated questioning protocol (A1).** Role agents never call AskUserQuestion. Protocol (implemented in T4.1):
- Agent prompts gain one standard paragraph: "You cannot ask the user questions. When user input is required, write each question into your handoff's `open-questions` section as `<li data-question data-blocking="true|false">` with 2–4 proposed options, then return."
- The orchestrator, after each dispatch: if any `data-blocking="true"` question exists, relay via AskUserQuestion, then re-dispatch the same role with the answers. Cap: 3 question rounds per step, then escalate.
- Applies to: design Steps 2/2.3/4, respec Steps 2/3/6, build 3.3h escalation and Step 3.4, all game agents. The inline-synthesis fallback text updates to match.

**E4 — Status writes stay agent-writable; state becomes session-keyed.** Because gates bind subagents (fact 1), we do NOT need orchestrator-only status writes for enforcement. Per accepted D5, /respec spec edits still move to the orchestrator (role-clarity reasons, not enforcement). T3.2 keys all state under `~/.claude/hooks/state/<sha1(cwd)>/<session_id>/`; SessionStart truncates only its own directory; `compact` retains state. Cross-referencing between the orchestrator's session and its subagents' payloads must be verified during T3.2 (subagents may carry the parent session_id or their own — test then; if they differ, key by `<sha1(cwd)>` + parent-discoverable marker).

**E5 — Advisory-channel repair (from fact 3), scheduled in T3.3:**
- `_common.sh` emit helper switches to the `hookSpecificOutput` wrapper (parameterized by `hook_event_name`).
- `detect-correction.sh` / `workflow-reminder.sh` read `.prompt` (keep `.text` as fallback).
- `wwiwo.sh` checks the prompt itself for the `wwiwo` trigger word (matcher is decorative; remove it from install.sh or keep as documentation).
- `molecule-autoclose-warn.sh` / `verifier-return.sh` read `tool_response` (extract `.stdout` for Bash; whole-dict search for Agent results), keeping legacy names as fallbacks.
- Block messages: replace literal `\n` escapes with real newlines.

**E6 — Fail-closed policy (accepted D9).** `require-*`/`guard-*` hooks block with a clear message when python is unavailable; advisory hooks exit quietly. All five hardcoded `python3` call sites switch to `_common.sh`'s `$PYTHON`.

## Consequences for the plan

- T3.1 = E2 (small, well-defined). The larger "move gates" branch is dead — delete from plan scope.
- T3.2 gains the session_id keying design (E4) and one open sub-question (subagent session_id inheritance) to resolve empirically during implementation.
- T4.1 = E3 as specified here.
- Phase 6's e2e harness must include regression assertions for facts 1, 2, 5, 6, 8 so a future Claude Code upgrade that changes any of them fails loudly instead of silently disarming the workflow.
