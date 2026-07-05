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
- [ ] T3.1 Enforcement architecture per decision record (A2/H1)
- [ ] T3.2 Verifier state machine: template markers + session-keyed state + compact retention
- [ ] T3.3 Per-hook correctness fixes (one commit per hook; smoke test each: block/allow/override)
- [ ] T3.4 _validate_handoff.py: empty input-refs, data-verdict, spec-drift severity, route-to required

## Later
- [ ] T4.1 Orchestrator-mediated questioning protocol (design/respec/build/agents)
- [ ] T4.2 Semantic contradiction resolutions (needs D1, D2, D3, D5)
- [ ] T4.3 Registry-driven drift sweep across skills/agents/schema
- [ ] T4.4 De-scaffolding pass (boilerplate, rationalizations, data-check examples, context economy, model pins per D4, announce lines per D6)
- [ ] T5.1 Retrospective repair (build Phase 4 trigger, bd types, override-ledger analysis, taxonomy)
- [ ] T5.2 README/AGENTS truth pass + "when a hook blocks you" section
- [ ] T5.3 Smoke-test sandboxing + Linux portability + behavior coverage for Phase 3 fixes
- [ ] T5.4 Benchmarks refresh or retire (needs D10)
- [ ] T6.1 e2e-workflow harness (artifact-replay first)
- [ ] T6.2 CI wiring (lint + smoke + e2e on Linux/macOS)
- [ ] T6.3 Close-out checklist vs evaluation; delete this plan dir
