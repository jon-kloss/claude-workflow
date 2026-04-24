# Gherkin Spec Design — Tasks

## Now

(none — all work complete)

## Next

(none)

## Later

(none)

## Blocked

(none)

## Done

- [x] Define the canonical Gherkin spec file format and tier-scaled templates (Quick/Standard/Complex + System spec)
- [x] Modify workflow-orchestrator Phase 1 (Plan) to generate Gherkin spec files instead of inline beads descriptions
- [x] Add Greenfield Rebuild Principle — system spec + feature specs must be sufficient to rebuild entire app
- [x] Update Phase 2 (Investigate) to read existing specs, feed spec context into investigation agents, check dependencies
- [x] Update Phase 3 (Implement) to treat specs as living docs — update scenarios during implementation, update @status tags, update verifier prompt to check against spec scenarios
- [x] Update Phase 4 (Verify) — code review agent references spec files, new Step 3.5 for spec scenario coverage check, spec-coverage category added to verification failure format
- [x] Update Phase 5 (Close) — new "Update Spec Status" step changes @status to verified, spec-coverage added to verification categories
- [x] Update all 3 workflow examples (Quick/Standard/Complex) to show spec generation, spec updates, and spec coverage checks
- [x] Update verification checklist with spec-related checks across all 5 phases (12 new checklist items)
- [x] Add 8 spec-related rationalizations to Common Rationalizations section + 2 new numbered rules (19, 20) to critical_rules
- [x] Update README.md with Gherkin Spec Files section (format, types, tags, tier scaling, lifecycle, greenfield rebuild) + 3 new design principles
- [x] Assess hooks — determined no new hooks needed (existing hooks + skill-level enforcement cover all spec behaviors). install.sh unchanged.
- [x] Add spec-driven TDD enforcement — Phase 3 "Spec-Driven TDD" section with scenario-to-test mapping, rule #4 updated, 3 new rationalizations, verification checklist updated, README updated
