# Tasks — evaluation-fixes

## Now (parallel-safe: Phases 1, 2)
- [x] T0.1 Subagent hook-firing experiment → hooks DO fire in subagents (Outcome A; H1 confirmed real)
- [x] T0.2 Subagent AskUserQuestion experiment → unavailable, hard error (E3 protocol required)
- [x] T0.3 Harness field-shape checks (nested headless sessions) → docs/harness-behavior.md (v2.1.201)
- [x] T0.4 Decision record → docs/decisions/0001-enforcement-architecture.md (E1–E6)
- [x] T1.1 Committed (ef982f9 Mount-Map, 77d6195 dogfood specs); fresh-clone test lives in tests/install-roundtrip.sh
- [x] T1.2 Hygiene done (1d2e602): gitignore, package-lock deleted, vendor/hyperpowers deleted per D7 (install warns if plugin absent)
- [x] T2.1 docs/registry.md authored (040a040)
- [x] T2.2 tools/lint-consistency.sh — initial RED: 62 violations (R1:45 R4:17) reproducing M1/M3/M4/M7/M13/H4; that list = Phase 4 worklist

## Next (after Now)
- [x] T1.3 install.sh reworked (71b2291); reinstalled against real HOME — resources resolve, manifest written (60 links, 32 settings tuples)
- [x] T1.4 Manifest-driven uninstall + tests/install-roundtrip.sh (21/21 green, verified independently)
- [x] T1.5 Agent paths absolute (d74e490)
- [x] T2.3 docs/agent-protocol.md extraction (d74e490): agents 1910→1694 lines; smoke 151/151 after re-pointing 3 shape checks
- [x] T3.1 PreToolUse dispatch logging live (e611a67); H1 deadlock fixed; verified in live settings
- [x] T3.2 Verifier markers + sha(cwd)/session_id state keying (subagents inherit session_id — fact 11); compact retains
- [x] T3.3 All per-hook fixes (e611a67, one chunked commit rather than per-hook); smoke 151→216 checks, green
- [x] T3.4 _validate_handoff.py upgraded (empty input-refs, spec-drift, route-to, per-role data-verdict)

## Later
- [x] T4.1 Orchestrator-mediated questioning landed in design/respec + agents (671e74f, 9025e32); design-ui fallback conditionals added
- [x] T4.2 D1/D2/D3/D5/D6 resolved in core skills (671e74f)
- [x] T4.3 Registry sweep complete — repo-wide lint: 0 violations (671e74f, 9025e32, 157cbec)
- [x] T4.4 De-scaffolding: build 1181→902, design 752→624, respec 565→477, qa-engineer 222→192; model pins gone; announce lines gone; docs/incidents.md ledger
- [x] T5.1 Retrospective repair (a9c8402): Step 4.8 trigger, correct bd types, override-ledger analysis, registry-ID taxonomy, role tie-breaks
- [x] T5.2 README/AGENTS truth pass (e555183): 16 agents, 35 hooks, "When a Hook Blocks You", manifest reality, live link fixes
- [x] T5.3 Smoke sandboxed + portable (059b219): zero real side effects proven, bash 3.2, --installed flag, 216 checks
- [x] T5.4 Benchmarks refreshed per D10 (29ae01f): artifact-predicate rubrics, A/B vs vanilla, benchmarks/README
- [x] T6.1 e2e-workflow harness (c57d982): 76-check composition test, sandboxed, harness-fact regressions
- [x] T6.2 CI wiring (c57d982): .github/workflows/ci.yml, ubuntu+macos, bd-absent skip path verified
- [x] T6.3 Close-out checklist green (lint 0, all 5 suites pass); epic close + plan-dir delete next
