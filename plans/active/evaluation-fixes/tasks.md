# Tasks — evaluation-fixes

## Now (parallel-safe: Phases 1, 2)
- [x] T0.1 Subagent hook-firing experiment → hooks DO fire in subagents (Outcome A; H1 confirmed real)
- [x] T0.2 Subagent AskUserQuestion experiment → unavailable, hard error (E3 protocol required)
- [x] T0.3 Harness field-shape checks (nested headless sessions) → docs/harness-behavior.md (v2.1.201)
- [x] T0.4 Decision record → docs/decisions/0001-enforcement-architecture.md (E1–E6)
- [ ] T1.1 Commit Mount-Map rollout + untracked hook + dogfood specs; fresh-clone install test
- [ ] T1.2 .gitignore, delete package-lock.json, resolve vendor/ (needs D7, D8)
- [ ] T2.1 Author docs/registry.md (step IDs, filenames, verdicts, severities, tags, routing)
- [ ] T2.2 tools/lint-consistency.sh — must initially FAIL reproducing M3/M4/M7

## Next (after Now)
- [ ] T1.3 install.sh: resources/ linking, bd check, --yes, is_our_file fix, settings-merge hardening
- [ ] T1.4 Manifest-driven uninstall rewrite + round-trip test
- [ ] T1.5 Agent memory/bootstrap path sweep (absolute paths)
- [ ] T2.3 Shared agent-protocol.md boilerplate extraction (+ generator if frontmatter hooks chosen)
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
