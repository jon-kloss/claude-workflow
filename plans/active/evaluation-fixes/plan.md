# Plan: Fix all findings from EVALUATION-2026-07-04

Source of truth for findings: `EVALUATION-2026-07-04.md` (IDs A1–A3, H1–H16, M1–M14, I1–I5, P1–P9, R1–R3, plus product-surface findings). Every task below cites the finding IDs it closes. Nothing is considered done until the acceptance check listed with it passes.

## Strategy

Three facts shape the ordering:

1. **Two empirical unknowns gate the architecture.** Whether settings.json hooks fire on subagent tool calls, and whether AskUserQuestion works in subagents, determine how the entire enforcement layer and the Socratic flow must be rebuilt (A1, A2, H1, H8). Guessing wrong wastes the whole hook phase. So Phase 0 is a half-day of experiments, not code.
2. **~one third of findings share one root cause: no canonical vocabulary.** Step IDs, handoff filenames, verdicts, severities, override tags, and routing targets each have 2–4 competing spellings. Fixing call sites one at a time re-creates the drift. So Phase 2 builds a single registry file plus a consistency linter, and the sweeps in Phases 3–4 conform to it. The linter is what prevents recurrence.
3. **The evaluation's closing observation is the real fix.** Almost every critical finding would have been a failing test under an end-to-end /design→/build harness. Phase 6 builds it; Phases 1–5 make it able to pass.

Phases 1 and 2 are independent of Phase 0 and can start immediately. Phases 3–4 depend on 0 and 2. Phase 5 depends on 3–4 only for accuracy of what it documents. Phase 6 scaffolding can start any time; its assertions land last.

Branch hygiene first: the current uncommitted Mount-Map rollout must be committed (with its H7 bugs fixed or immediately after, as separate commits) before any sweep rewrites the same files, or the diff becomes unreviewable.

---

## Phase 0 — Ground truth (half a day; blocks Phases 3–4 design decisions)

**T0.1 — Subagent hook-firing experiment.** (A2, H1)
Create a scratch project with a canary PreToolUse Edit|Write hook (writes a marker file). Dispatch a trivial agent that Writes `@status(verified)` into `specs/canary.md`. Also test a hook defined in an agent's frontmatter.
- Outcome A (settings hooks DO fire in subagents): keep settings-level gates; fix H1 by logging dispatches at PreToolUse.
- Outcome B (they do NOT fire): gates must move — either (a) duplicate the gate set into every role agent's frontmatter `hooks:` (generated, not hand-copied — see T2.3), or (b) make status/handoff writes orchestrator-only (agents return content; the parent writes files). Recommend (b) for status writes + (a) for handoff schema validation; decide after seeing results.

**T0.2 — Subagent AskUserQuestion experiment.** (A1)
Dispatch an agent instructed to AskUserQuestion. Observe: surfaces to user / errors / silently degrades to text.
- Expected per docs: unavailable. Then adopt the **orchestrator-mediated questioning protocol** (design in T4.1): agents never call AskUserQuestion; they return a structured question list in `open-questions`; the orchestrator relays via AskUserQuestion and re-dispatches with answers. Loop capped at 3 rounds.

**T0.3 — Harness field-shape checks.** (H8)
One `claude --debug` session in a beads project: confirm (1) UserPromptSubmit payload field (`prompt` vs `text`), (2) whether top-level `additionalContext` is honored vs `hookSpecificOutput.additionalContext`, (3) whether the `"matcher": "wwiwo"` UserPromptSubmit matcher is honored, (4) PostToolUse result field name (`tool_response` vs the four names currently tried).
Record all answers in `docs/harness-behavior.md` with the Claude Code version tested, so future drift is diagnosable.

**T0.4 — Decision record.** Write `docs/decisions/0001-enforcement-architecture.md` capturing the four answers and the chosen architecture for Phase 3/4. All later tasks reference it.

**Acceptance for Phase 0:** decision record exists; each experiment's raw evidence (marker files, debug output) is quoted in it.

---

## Phase 1 — Stop the bleeding: repo & distribution (1 session; no dependencies)

**T1.1 — Commit the live-but-untracked system.** (I1)
Commit `hooks/require-feature-mounted.sh`, `specs/incident-logging.md`, `specs/retrospective-overhaul.md`, and the current Mount-Map skill/agent/README diffs as a coherent commit series. Fresh-clone test: `git clone` to a temp dir, run install.sh, confirm no settings entry points at a missing file.

**T1.2 — Repo hygiene.** (I5)
`.gitignore`: add `__pycache__/`, decide `specs/` dogfood policy (**Decision D8**, recommend: commit dogfood specs, ignore `specs/overview.html` + `specs/diagrams/` as generated). Delete `package-lock.json` (brewery-api residue, no package.json exists). Resolve `vendor/hyperpowers` (**Decision D7**: either commit with a README explaining why vendored + make agents fall back to it when the plugin is absent, or delete and document the plugin as a hard prerequisite checked by install).

**T1.3 — install.sh: link resources/, check deps, run non-interactively.** (I2, I4)
- Link each skill's whole directory (or rsync SKILL.md + resources/) so `resources/` resolves at `~/.claude/skills/<name>/resources/`. Verify design's four relative links and onboard's 17 templates resolve post-install.
- Add dependency checks: `bd` (warn loudly + list which 9 hooks degrade), `git`. Keep python3 check; also record the resolved python into an env the hooks read (see T3.8).
- Replace `read -p` with `--yes` flag support; exit nonzero cleanly with a "rerun with --yes" message when non-interactive. Fix summary: include onboard; use `$SCRIPT_DIR/benchmarks`.
- `is_our_file`: only claim symlinks whose target resolves inside the repo (`readlink` prefix check), never arbitrary symlinks/hard links.
- Wrap the settings merge in error handling: on non-strict-JSON settings, back up, print a readable error, abort before linking hooks (reorder: validate settings first).

**T1.4 — Manifest-driven uninstall.** (I3)
install.sh writes `~/.claude/workflow-install-manifest.json` (every link created, every settings entry/command added). Rewrite uninstall.sh to consume the manifest: remove exactly what was added, command-by-command in settings (never whole entries), restore backed-up files, reverse the superpowers-disable step. Delete the hardcoded 2024-era lists. Update README's uninstall claims to match (T5.2).
Acceptance: install → uninstall on a machine with a pre-existing user hook on Edit|Write leaves that hook intact and zero workflow references in settings; `ls -l ~/.claude/{skills,agents,hooks}` shows no dangling symlinks.

**T1.5 — Agent-side path fixes.** (I2 tail, P8 partial)
Sweep all 16 agents: memory-bootstrap paths become `~/.claude/skills/onboard/resources/memory-template-<role>.md` (valid after T1.3); fix `game-ui-designer.md:18` "Re-read agents/uiux-designer.md" → `~/.claude/agents/uiux-designer.md`; fix game-designer's contradictory parenthetical.

---

## Phase 2 — Canonical vocabulary + consistency linter (1 session; blocks sweeps)

**T2.1 — Author `docs/registry.md` (single source of truth).** (M3, M7, M9, M13, M14-data-step)
One file defining, exhaustively:
- **Step IDs**: adopt exactly the build/design headings as canonical; rename the review pass to eliminate letter/dot mixing — recommend flattening to `3.3a`…`3.3h` only (security=3.3c1→ new `3.3-security`? No — keep it simple: `3.3a test-suite, 3.3b test-effectiveness, 3.3c code-review, 3.3d security, 3.3e devops, 3.3f data, 3.3g qa, 3.3h sre-audit, 3.3i fix-cycle`). Whatever is chosen: one table, step → owner → handoff filename. This also retires phantom 3.3e/3.3f by reassigning them real meanings (M4).
- **Handoff filename grammar**: `step-<id>-<spec-slug>-<role>[-fix-cycle-N].html`, one spelling for fix cycles (recommend `fix-cycle-N` for implementers AND `re-verify-N` for reviewers — visually distinct, no substring collision; update hook regex accordingly). Respec gets its own namespace: `respec-<n>-<slug>-<role>.html`, added to the schema doc as a legal second pattern (M13).
- **Verdict vocabulary**: required `<meta data-verdict="...">` in every reviewer/coordinator handoff head; enumerate legal values per role (PASS / FAIL-CRITICAL / FAIL-SPEC-DRIFT; READY-TO-CLOSE / READY-WITH-CAVEATS / BLOCKED). Add `spec-drift` to legal `data-severity` values (M9).
- **Severity + routing**: one routing table (resolving schema line-175 vs its own table — the table wins; prose deleted) (M8).
- **Override-tag registry**: every `*-skip` tag, which hook reads it, where it's documented. Kill or implement `@release-skip` (recommend: implement it in the hook, since an agent prompt already teaches it) (H4 partial, M14).
- **Tag vocabulary**: `@layer(...)` values incl. `gameplay`; retire `@backend-only/@api-only/@cli/@infra` bare tags (M1).
- **data-step meta format**: define it as identical to the filename step-id; delete the `design.2.5-decomposition` variant from the schema doc.

**T2.2 — Build `tools/lint-consistency.sh`.** (prevents recurrence of M3–M14 class)
A linter that fails on: step references not in the registry; handoff path literals not matching the grammar; override tags not in the registry; hook names referenced but absent from `hooks/`; skill/agent names referenced but absent; internal `SKILL.md:NNN`-style line citations (ban them outright — they rot; cite section names instead, fixes M14-stale-cites); `@integration\b`-style regexes flagged by a small denylist of known-bad patterns. Wire into the smoke test and Phase 6 CI.

**T2.3 — Shared boilerplate include + generation.** (P1, T0.1-Outcome-B enabler)
Extract the ×16 exit-checklist/fix-cycle/sleep boilerplate into `docs/agent-protocol.md` (referenced by one line per agent: "Follow the exit protocol in ~/.claude/workflow/docs/agent-protocol.md; your handoff path is X"). If Phase 0 chose frontmatter hooks, add a small generator (`tools/gen-agents.sh`) that stamps the shared frontmatter hook block into each agent file so it's never hand-copied.

**Acceptance for Phase 2:** linter runs clean on the registry itself and RED on the current tree (its initial failure list should reproduce M3/M4/M7 mechanically — that's the proof it works).

---

## Phase 3 — Hook layer repair (2 sessions; depends on Phase 0 + 2)

**T3.1 — Enforcement architecture per decision record.** (A2, H1)
Outcome A: move `track-agents.sh` registration to PreToolUse on Agent (log at dispatch, update at return); keep gates as-is. Outcome B: implement orchestrator-only status writes (skills instruct agents to RETURN proposed status changes; orchestrator applies them — respec Step 4 rewritten accordingly, also resolving M13's role blur) and/or generated frontmatter hooks per T2.3. Either way, add one smoke test proving a role-agent's `@status(verified)` write path hits the gate.

**T3.2 — Verifier state machine.** (H2, H3, H5)
- Rewrite `verifier-dispatch.sh` extraction to match the actual template — better: change the build template to include machine lines (`SPEC: specs/<slug>.md`, `TASK: <bead-id>`, `EPIC: <bead-id>`) and extract those; accept `workflow-[a-z0-9]+` ID shape everywhere; fix `{3}` → `{3,}` in block-status.
- Key all state files by session+project: `~/.claude/hooks/state/<project-hash>/<session-id>/...` using the session ID from hook payloads (verify field name in T0.3). Compaction handling: on SessionStart matcher `compact`, RETAIN verifier/read state (compaction is not a new session); only `clear` and `startup` truncate — and `startup` only truncates its own session's dir. Concurrent sessions stop clobbering by construction.

**T3.3 — Per-hook correctness fixes (mechanical, one commit each):**
- `require-release-handoff.sh`: honor RELEASE-SKIP (or @release-skip per registry) in the BLOCKED branch; extract the ID from the argument position after `close`, gate every ID in multi-ID closes; parse the verdict from `data-verdict` meta (per T2.1) instead of first-token-anywhere. Unify `bd comment` → `bd comments add` everywhere (H4, H9, H10).
- `require-ui-tests.sh`: replace `ls x.{a,b}` with a for-loop `[ -f ]` check (pipefail-safe); remove or use `search_pattern`; tighten first-word filename matching (H6, H13-adjacent).
- `require-feature-mounted.sh`: `@integration([^-]|$)` style negative match for the skip tag; word-boundary/table-cell match for Mount-Map membership; scope the ≥2-UI-spec count to the current epic (read epic's spec list from the bd design field, fall back to specs not yet verified) (H7).
- `require-fix-cycle-handoff.sh`: anchor slug with `-(role)` boundary so `foo` ≠ `foo-bar`; adopt registry filename grammar (H11, M7).
- `block-unread-edits.sh`: exact-path match (compare full strings, not substring); move the new-file allowance before the reads-file existence check (H12).
- `guard-spec-bash-writes.sh`: document as best-effort; add detection for `git checkout -- specs/` and `cd specs` forms; accept remaining bypasses explicitly in the header (honest scope) (H13).
- `check-open-beads.sh`: `grep -c || true` and default with `${var:-0}` (H14).
- `require-bead-description.sh` + block-status Bash arm: anchor to command position (start-of-command or after `&&`/`;`/`|`) (H15).
- `require-investigation-findings.sh`: enforce what build promises — ≥2 `file:line`-shaped refs + a `Decision:` line (H16).
- All five hardcoded `python3` call sites → `"$PYTHON"` from `_common.sh`; if `_find_python` fails, gates should BLOCK with a clear "python missing — enforcement disabled would be unsafe" message rather than silently allow (**Decision D9**: fail-closed vs fail-open; recommend fail-closed for require-*/guard-*, fail-open for advisory hooks).
- Harness field fixes per T0.3: `.prompt` fallback in detect-correction/workflow-reminder; `hookSpecificOutput` wrapper in `_common.sh`; `tool_response` in the PostToolUse extractors; wwiwo prompt-check inside the script (don't rely on the matcher).
- Perf: cache `require-feature-mounted`'s source scan per invocation target; drop `check-open-beads`'s recursive grep or gate it behind a specs-dir existence check (H16-perf).

**T3.4 — `_validate_handoff.py` upgrades.** (M8, M9, M14)
Allow empty `data-input-references` (fix check #3 vs table contradiction — and fix the schema doc text); validate `data-verdict` against the registry per role; validate `data-severity` incl. `spec-drift`; require `data-route-to` on critical/important asides (the schema already promises this); either implement the `session-agents.log` cross-reference or delete the promise from the schema doc.

**Acceptance for Phase 3:** every fixed hook gets a real-payload behavior test in the smoke suite (block case + allow case + override case); linter clean; the H2 path proven by a smoke test that dispatches with the real build template text and asserts the inflight file contains real IDs.

---

## Phase 4 — Skills & agent surgery (2–3 sessions; depends on Phases 0 + 2)

**T4.1 — Orchestrator-mediated questioning protocol.** (A1)
Per T0.2: rewrite design Step 2 / Step 4, respec Steps 2–6, build 3.3h escalation, product-owner.md, and the five game agents: agents return structured question lists; the orchestrator asks. Add the fallback sentence to every agent that previously assumed AskUserQuestion. Update the inline-synthesis sections to match.

**T4.2 — Resolve the semantic contradictions (needs your decisions):**
- **D1 — verification scaling** (M5): pick one. Recommend: verification DOES scale down for `@trivial` only, and the "never scales down" language is rewritten to "never scales down below the @trivial floor; @trivial is the only knob and it is set at decomposition, not during build." Sweep build's rigidity block, :417, the typo example, and the three Skip-when lines to agree.
- **D2 — data-architect trigger** (M10): pick hook-side (unconditional for api/full-stack) or skill-side (@touches-data only). Recommend skill-side + make the hook read `@touches-data`; `@layer(api|full-stack)` without the tag prompts a warning, not a block.
- **D3 — build parallelism** (M11): implement it (worktree-per-lane, orchestrator merges) or remove the lanes UI. Recommend: remove the confirmation theater now (announce lanes as information, don't ask), file a separate spec for true parallel builds later. Also: `--auto` must skip ALL AskUserQuestion pauses (graph confirmation, 3.3h escalation becomes "halt with written summary").
- **D5 — respec ownership** (M13): recommend orchestrator edits specs during respec (agents advise via handoffs), consistent with rule 8 and T3.1.

**T4.3 — Mechanical drift sweep (registry-driven; linter enforces):** (M2, M4, M6, M12, M14)
- spec-sre-auditor: add the missing "What you produce" section (handoff path + data-verdict + how the plaintext verdict maps into the HTML).
- build: delete/reassign every 3.3e/3.3f reference; rewrite the integration table (drop D2–D9 rows; impeccable gates belong to qa/uiux dispatches); reconcile rule 18 with 3.3d ownership; fix ":1135 consumes per-spec tasks" line; add the missing "create implementation task" instruction to Step 3.1; decide product-owner's Step 3.4 role (recommend: drop the claim from the agent registry description — sign-off is orchestrator-inline).
- qa-engineer/frontend-engineer frontmatter: one owner per step; qa's "after sre-auditor" sentences corrected to its true slot.
- design: fix rule numbering (11→14 gap); reconcile rule 10's "invoke /design-ui" with Step 2.85's agent dispatch (recommend: uiux-designer agent invokes the design-ui skill; rule 10 rephrased to name the agent); design-ui's Phase-3 epic/spec-grep gates get "when invoked standalone" guards or move post-spec-generation; add one honest paragraph resolving the "no codebase investigation" vs decomposition tension (architect may read structure via onboard memory; may not read implementation).
- design-ui: replace all five `detect` gate references with `critique` (which contains the anti-pattern scan) or add detect as an explicit critique sub-invocation; make the gate-count arithmetic consistent (or delete the counts — the linter can count); delete dangling "trainr/2026-05-21 incident" cites or add the incidents to a `docs/incidents.md` ledger (better — the corpus cites incidents constantly; give them one home).
- uiux-designer: add the fix-mode section (game-ui inherits it for real); resolve N-handoffs-per-invocation vs schema (amend schema: one handoff per (invocation × spec) is legal); align game-ui's pipeline list and activation condition with design's per-spec routing.
- level/narrative: remove the circular "read the other if available" or make dispatch explicitly two-wave.
- Schema doc: apply all registry decisions; delete the timestamps-overlap parallelism check from design/build headers (replace with "check the dispatch message contained multiple Agent calls").
- Retire announce lines from all seven skills (**D6** — your CLAUDE.md already bans the behavior; recommend deletion; keep skill-name in the first status sentence naturally).

**T4.4 — De-scaffolding pass.** (P1–P9)
- Apply T2.3 boilerplate extraction; delete fix-mode language from roles without fix modes; single SquashBuckler telling per file max (move the full story to `docs/incidents.md`).
- Rationalization lists: cut to ≤5 per file, keeping only policy-bearing bullets, each promoted into the normative rules with its incident cite. Target: build ≤10 (from 46), design ≤10 (from 37).
- qa-engineer: delete the Playwright tutorial + framework decision tree (keep the axes and the framework-detection sentence + `.claude/ui-test-framework` override); bound e2e runtime/flake policy (one new normative paragraph).
- Fix every broken `data-check` example (P6) with real runnable shell; add a linter rule that shell in `data-check` examples must pass `bash -n`.
- design-arch: collapse the five restatements to one; drop the HTML skeleton; parallelize the two dispatches (P5); tell dispatched agents to read memory files.
- design-ui: delete the self-honesty interrogation + triplicated gate rule (hook + one rigid line remain); allow parallel gate invocations across mockups; drop the font blacklist to a preference.
- Context economy (P4): rewrite release-coordinator/qa read-lists to "summary + acceptance-criteria sections of each handoff; full file only when a finding requires it."
- Model pins (**D4**): recommend deleting `model:` from all 16 (inherit session model) or pinning reviewers ≥ implementers; the devops file's own recorded Sonnet regression decides devops/qa at minimum.
- Memory-update blocks: keep the customized game versions, replace the generic 6-step block with two sentences per role naming that role's primary section.
- onboard: fix the three word-budget statements to one; fix `--refresh` rationale (SHA, not timestamps); fix checklist vs product-owner exemption; fix the subshell FATAL; fix agent-11 ordering note.
- engineering-standards: soften Makefile→C/C++ row; align sql.md migration phrasing with data-architect's.
- A3: add `data-synthesized` to the handoff schema head (not a findings note), make release-coordinator report synthesized-vs-dispatched counts in its verdict block.

**Acceptance for Phase 4:** linter clean; total corpus line count reduced ≥20%; a fresh-eyes read of build/design finds no self-contradiction on scaling, steps, or ownership (spot-audit by a review subagent with the evaluation as its checklist).

---

## Phase 5 — Close the loops: retro, docs, tests (1–2 sessions)

**T5.1 — Retrospective repair.** (R1, R2, R3-partial)
- Add the invocation to build Phase 4 (after Step 4.5, before integration options): "REQUIRED SUB-SKILL: workflow-retrospective --epic <id>" gated to every Nth epic or `--auto` runs prompting the user.
- Fix queries: `--type task` (plus feature for gates), `--status all` on the Workflow Incidents search.
- Add the override-ledger analysis step: read `override-audit.log`, cluster by hook/tag, any hook overridden ≥3 times in a period is automatically a retro finding.
- Update the Step-Effectiveness taxonomy to the current pipeline (registry step IDs + role names) so errors are attributable to qa-engineer/security/fix-cycle.
- Replace the stale memory-API step with the current mechanism (bd remember, per your SessionStart hook policy).
- Role-design cleanups (R3): add tie-break sentences (migration safety: data-architect owns correctness, devops owns operational rollout; security: security-architect owns, sre-auditor cites-not-refinds, devops checks only committed-secret hygiene); assign `specs/system.md` authoring to application-architect (design Step 2.5 output); assign runbook authoring to devops-architect at 3.3-devops when the spec introduces operational surface; delete the audio-designer reference or add a stub decision.

**T5.2 — README/AGENTS truth pass.** (product-surface findings)
16 agents documented incl. the game layer + `gameplay` + `@surface(game)`; smoke-count corrected (or better: README says "run it; it prints its own total"); all 35 hooks + override tags in the tables; a new "When a hook blocks you" section (top 5 blocks, what they mean, the override tag + the reason-quality rules); per-project bootstrap section (`bd init` first); uninstall section rewritten post-T1.4; delete or regenerate the /tmp/role-test validation claims; fix AGENTS.md QUICKSTART reference; verify or remove the three prerequisite URLs.

**T5.3 — Smoke-test isolation + portability.** 
Run in a temp sandbox project (its own git + bd db, `HOME` overridden so state/audit-log writes are sandboxed); portable sed (`sed -i.bak`); single `write_handoff` definition; `exit` with capped code; behavior tests for every hook fixed in Phase 3 (that's the acceptance vehicle); keep the grep-shape checks only for hooks with no behavior test yet, and list them as known gaps in the script header.

**T5.4 — Benchmarks: refresh or retire.** (**Decision D10**)
Recommend: rewrite the 6 rubrics against the current pipeline (specs exist, statuses transition, mockups exist, handoff chain complete, gates fired — all mechanically checkable from artifacts, which is now easy) and update AB-TESTING-PROTOCOL to /design–/build. If not worth it, move to `attic/` and delete the README/install claims. Do not leave them advertised-but-dead.

---

## Phase 6 — Integration harness + CI (1–2 sessions; scaffold early, finish last)

**T6.1 — End-to-end harness.** `tests/e2e-workflow.sh`: scripted toy project (two UI specs + integration spec), drives a headless claude session (or replays the artifact protocol directly) through design→build far enough to assert: gates block when they should (status write without verifier evidence, handoff missing, orphan feature), pass when satisfied, overrides demand valid reasons, and the artifact chain (handoffs, statuses, bd comments) is complete and schema-valid at close. Start with the artifact-protocol replay version (deterministic, no model), add a model-driven variant later.
**T6.2 — CI wiring.** GitHub Actions (or a `make check` if the repo stays local): lint-consistency + smoke (sandboxed) + e2e-replay on Linux and macOS. Linux run also proves T5.3 portability.
**T6.3 — Close out.** Re-run the evaluation's critical-findings list as a checklist against the tree; anything still open gets a bead. Delete this plan directory per the finishing convention.

---

## Decisions needed from you (blocking the marked tasks only)

| ID | Question | Recommendation | Blocks |
|---|---|---|---|
| D1 | Does verification scale down for `@trivial`? | Yes, as the only knob, set at decomposition | T4.2 |
| D2 | data-architect gate: unconditional or @touches-data? | @touches-data (+warning) | T4.2, T3.3 |
| D3 | Build parallel lanes: implement or remove? | Remove confirmation now; spec true parallelism later | T4.2 |
| D4 | Agent model pins | Delete pins; inherit session model | T4.4 |
| D5 | Who edits specs during /respec? | Orchestrator | T4.2, T3.1 |
| D6 | Keep skill announce lines? | Delete | T4.3 |
| D7 | vendor/hyperpowers | Commit + documented fallback, or delete + install check | T1.2 |
| D8 | specs/ dogfood policy | Commit specs; ignore generated outputs | T1.2 |
| D9 | Gates fail-open or fail-closed without python? | Fail-closed for require-*/guard-* | T3.3 |
| D10 | Benchmarks refresh or retire | Refresh rubrics mechanically | T5.4 |

## Sequencing summary

```
Phase 0 (experiments)  ──────────┐
Phase 1 (repo/install) ──────┐   ├──> Phase 3 (hooks) ──┐
Phase 2 (registry+linter) ───┴───┴──> Phase 4 (skills) ─┴─> Phase 5 (loops/docs) ─> Phase 6 (harness/CI)
```
Phases 0, 1, 2 can run in parallel today. Estimated total: 8–11 working sessions.

## Beads structure (to create on your approval)

Epic "Fix EVALUATION-2026-07-04 findings" + one task per phase (0–6), with T-level items in each task's design field; Tests-gate task = Phase 6 acceptance. Dependencies: 3←0,2; 4←0,2; 5←3,4; 6←5.
