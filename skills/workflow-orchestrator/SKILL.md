---
name: workflow-orchestrator
description: Use for ANY task - classifies complexity into Quick/Standard/Complex tiers, chains phases (Classify, Plan, Investigate, Implement, Verify, Close), always creates beads, always runs full verification. Replaces ad-hoc skill selection with enforced adaptive workflow.
---

<skill_overview>
Adaptive developer workflow that classifies every task into Quick/Standard/Complex tiers and chains 5 mandatory phases. Planning depth scales with complexity; verification never does. Every task gets beads tracking, TDD, and full verification suite + code review agent.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: Phase 1 (Plan) and Phase 4 (Verify) are mandatory and identical across all tiers. Never skip, never scale down.
- **RIGID**: Every epic MUST have a mandatory Tests task. Epic cannot close without it.
- **RIGID**: Tier classification defaults UP when uncertain.
- **FLEXIBLE**: Planning depth, investigation scope, and review checkpoints scale with tier.
</rigidity_level>

<quick_reference>
## Tier Comparison

| | **Quick** | **Standard** | **Complex** |
|---|---|---|---|
| **Scope** | 1-2 files, <50 lines | Multi-file, clear scope | New feature, epic-level |
| **Planning** | Beads epic + task + Tests task | Brainstorm (light) + beads epic + tasks + Tests task | Full brainstorm + SRE refinement + beads epic + Tests task |
| **Investigation** | Read target files + Grep | codebase-investigator agent | codebase-investigator + internet-researcher (parallel) |
| **Implementation** | TDD cycle | TDD per task via executing-plans | TDD + code-reviewer agent after each task |
| **Verification** | **Full suite + code review agent** | **Full suite + code review agent** | **Full suite + code review agent** |

## Phase Chain

```
User request
  -> Phase 0: CLASSIFY tier (Quick / Standard / Complex)
  -> Phase 1: PLAN + create beads epic with Tests task (ALWAYS)
  -> Phase 2: INVESTIGATE codebase (depth scales with tier)
  -> Phase 3: IMPLEMENT with TDD (review rigor scales with tier)
  -> Phase 4: VERIFY full suite + code review agent (NEVER scales down)
  -> Phase 5: CLOSE beads + update memory
```

## Hard Constraints (every tier, no exceptions)

1. Beads epic created with plan
2. Mandatory Tests task in every epic
3. Codebase investigated before writing code
4. TDD: tests before implementation
5. Full verification suite + code review agent
6. Epic cannot close with open Tests task
</quick_reference>

<when_to_use>
**Use for ANY task given to you.** This skill replaces ad-hoc skill selection.

- User asks to implement a feature (any size)
- User asks to fix a bug
- User asks to refactor code
- User asks to add/change functionality
- User describes a problem to solve
- User provides requirements to implement

**Don't use for:**
- Pure questions/explanations (no code changes)
- Continuing an already-in-progress executing-plans cycle (use executing-plans directly)
- Tasks where a beads epic already exists and is being worked on
</when_to_use>

<the_process>

## Auto-Resume (when .beads/ exists)

If a `.beads/` directory exists in the current working directory, check for in-progress work before classifying the new task:

1. Run `bd list --status in_progress` to find actively worked-on tasks
2. Run `bd ready` to find tasks with no blockers ready to start
3. If in-progress or ready tasks exist, present them to the user:
   - "Found in-progress work: [epic/task summary]. Want to continue this, or start on your new request?"
4. If the user wants to resume: load the epic context (`bd show [epic-id]`) and pick up from the appropriate phase
5. If the user wants to start fresh: proceed to Phase 0 with their new request

This step is skipped if no `.beads/` directory exists (new project without beads).

---

## Phase 0: CLASSIFY

**Announce:** "I'm using the workflow-orchestrator skill to classify and execute this task."

Assess the user's request against these concrete heuristics:

### Quick Tier (ALL must be true)
- Scope: 1-2 files affected
- Change size: <50 lines added/modified
- Nature: typo fix, rename, simple config change, add a field, fix an import
- No new public API surface
- No new dependencies

### Standard Tier (ANY is true)
- Scope: 3+ files affected
- Adding new endpoint/route/component with clear pattern to follow
- Modifying existing feature behavior
- Refactoring across module boundary
- Bug fix requiring investigation

### Complex Tier (ANY is true)
- New feature/capability that doesn't exist yet
- New external integration (API, service, library)
- Architectural change
- Cross-cutting concern (auth, logging, error handling)
- User explicitly requests epic-level planning

### Classification Rules
- **Default UP**: If uncertain between tiers, choose the higher tier. Quick->Standard, Standard->Complex.
- **User override**: If the user says "this is a quick fix" or "treat this as complex", respect their explicit classification. Override only affects planning depth, NEVER verification.
- **Compound requests**: If user gives multiple tasks ("add auth and fix the broken tests"), classify each independently. Create separate beads epics if different tiers. Execute sequentially.

**Announce the classification:**
"This is a **[Quick/Standard/Complex]** tier task because [specific signal that matched]."

---

## Phase 1: PLAN (Always runs. Always creates beads.)

### Pre-check: Beads initialized?
```bash
# Check if beads is initialized in this project
ls .beads/ 2>/dev/null
```
- If `.beads/` exists: proceed
- If not: run `bd init` first
- If `bd init` fails (not a git repo): prompt user to initialize git, or use TaskCreate as fallback tracking

### Quick Tier Planning

Create a beads epic with a brief plan and the mandatory Tests task:

```bash
bd create "Epic: [Brief description of change]" \
  --type epic \
  --priority 2 \
  --design "## Requirements
- [What must be true when complete]

## Success Criteria
- [ ] [Specific, measurable outcome]
- [ ] All tests passing
- [ ] Pre-commit hooks passing

## Anti-Patterns
- [Relevant forbidden patterns]

## Approach
[1-2 sentences on how to do it]"
```

Then create implementation task + mandatory Tests task:

```bash
bd create "Task: [The actual work]" --type feature --priority 2 \
  --design "[Implementation details with file paths]"
bd dep add [task-id] [epic-id] --type parent-child

bd create "Tests: [Epic name]" --type feature --priority 2 \
  --design "## Goal
MANDATORY - Epic cannot close without this task complete.

## Success Criteria
- [ ] Test files created/modified for all implementation tasks
- [ ] All tests pass
- [ ] Edge cases covered (empty input, error states, boundary conditions)
- [ ] No tautological tests (each test catches a specific bug)
- [ ] Test coverage adequate for changed code"
bd dep add [tests-id] [epic-id] --type parent-child
```

### Standard Tier Planning

Use brainstorming skill in lightweight mode (1-2 clarifying questions, not full Socratic deep-dive):

```
Use Skill tool: hyperpowers:brainstorming
```

Brainstorming will create the beads epic with requirements, anti-patterns, and first task. After brainstorming completes, verify the epic has a Tests task. If not, create one.

### Complex Tier Planning

Use full brainstorming skill (Socratic questions, research agents, approach comparison):

```
Use Skill tool: hyperpowers:brainstorming
```

After brainstorming creates epic and first task, run SRE refinement:

```
Use Skill tool: hyperpowers:sre-task-refinement
```

Verify the epic has a Tests task. If not, create one.

### Tests Task Verification (ALL TIERS)

After Phase 1 completes, verify:
```bash
bd show [epic-id]  # Check children include a Tests task
```

If no Tests task exists, create one immediately. This is non-negotiable.

---

## Phase 2: INVESTIGATE (Always runs. Depth scales.)

**Purpose:** Understand the codebase BEFORE writing any code. This prevents the #1 correctness failure: not matching existing patterns.

### Quick Tier Investigation
Read the target file(s) and their immediate context:
- Use Read tool on the file(s) you'll modify
- Use Grep to find similar patterns in nearby files
- Check for existing conventions (naming, error handling, imports)

### Standard Tier Investigation
Dispatch a codebase-investigator subagent:
```
Agent tool (subagent_type: hyperpowers:codebase-investigator):
"Find existing patterns for [what we're building].
Check: similar implementations, naming conventions, error handling patterns,
test patterns, and any existing code that does something like [description].
Report file paths, line numbers, and patterns to follow."
```

### Complex Tier Investigation
Dispatch both agents in parallel:
```
Agent tool (subagent_type: hyperpowers:codebase-investigator):
"[Codebase investigation prompt as above]"

Agent tool (subagent_type: hyperpowers:internet-researcher):
"Research [external API/library/pattern].
Find: current documentation, best practices, common pitfalls,
community recommendations, and code examples."
```

### Investigation Output
After investigation, briefly note findings before proceeding:
- "Found existing pattern at [file:line] - will follow this approach"
- "No existing pattern found - will establish new convention based on [research]"
- "Discovered [unexpected finding] - adjusting plan"

---

## Phase 3: IMPLEMENT (TDD always. Review rigor scales.)

### Quick Tier Implementation
Follow the TDD cycle directly:

```
Use Skill tool: hyperpowers:test-driven-development
```

1. Write failing test (RED)
2. Write minimal implementation (GREEN)
3. Refactor if needed
4. Commit

Update beads task to in_progress, then close when done.

### Standard Tier Implementation
Use executing-plans to work through tasks iteratively:

```
Use Skill tool: hyperpowers:executing-plans
```

Executing-plans will:
- Execute tasks one at a time with TDD
- Review learnings after each task
- Create next task based on reality
- Run SRE refinement on new tasks
- STOP after each task for user review

### Complex Tier Implementation
Same as Standard, plus dispatch code-reviewer agent after each task completes:

```
Use Skill tool: hyperpowers:executing-plans
```

After each task closes, before creating the next:
```
Agent tool (subagent_type: hyperpowers:code-reviewer):
"Review all changes made in [task-id] against:
1. Epic requirements and anti-patterns from [epic-id]
2. Codebase pattern consistency
3. Edge case coverage
4. Integration correctness
Report any issues found."
```

Address review findings before proceeding to the next task.

---

## Phase 4: VERIFY (Full suite. EVERY tier. NEVER scales down.)

This phase is IDENTICAL regardless of tier. No exceptions.

### Step 1: Run full test suite
```
Agent tool (subagent_type: hyperpowers:test-runner):
"Run the full test suite for this project. Report only failures and summary."
```

If tests fail: return to Phase 3 to fix. Do NOT proceed.

### Step 2: Run code review agent
```
Agent tool (subagent_type: hyperpowers:code-reviewer):
"Review ALL files changed in this epic against:
1. Beads epic requirements and anti-patterns (read epic [epic-id] first)
2. Codebase pattern consistency - does new code match existing patterns?
3. Edge case coverage - are boundary conditions handled?
4. Integration correctness - do pieces connect properly?
5. Test quality - are tests meaningful, not tautological?
Report any issues found, categorized as CRITICAL / IMPORTANT / MINOR."
```

If CRITICAL issues found: return to Phase 3 to fix. Do NOT proceed.
If IMPORTANT issues found: fix them before proceeding.
MINOR issues: note for future improvement but can proceed.

### Step 3: Verify Tests task complete
```bash
bd show [tests-task-id]  # Must be status: closed
```

If Tests task is not closed: close it only if ALL test criteria are met (test files exist, tests pass, edge cases covered, no tautological tests).

### Step 4: Check epic success criteria
```bash
bd show [epic-id]  # Read success criteria
```

Walk through EVERY success criterion. For each one:
- Verify it is objectively met (not "probably" or "should be")
- Note the evidence (test output, file exists, command output)

If ANY criterion is not met: return to Phase 3.

### Step 5: Final verification skill
```
Use Skill tool: hyperpowers:verification-before-completion
```

### Verification Failure Handling
- Maximum 3 fix-verify cycles before escalating to user
- Track each failure in beads comments: `bd comment [epic-id] "Verification failure: [description]"`
- If stuck after 3 cycles: present the issue to user with full context

---

## Phase 5: CLOSE

### Update README (when applicable)
If this epic added or changed any of the following, update the README before closing:
- New or changed features, capabilities, or behaviors
- API changes (new endpoints, changed request/response formats, authentication)
- UI changes (new pages, components, navigation)
- New or changed dependencies, setup steps, or configuration
- Changed usage patterns or examples

Steps:
1. Read the current `README.md` (if it exists)
2. Update it to reflect the changes made in this epic
3. If no `README.md` exists and this is a meaningful project (not a script or throwaway), create one covering: project description, setup, usage, and features

Skip this step only if the epic was purely internal with no external impact (refactor with no API change, test-only changes, internal bug fix with no behavior change).

### Close beads
```bash
bd close [tests-task-id]   # Tests task first (if not already closed)
bd close [epic-id]          # Then epic
```

### Update memory
If anything was learned during this task that would be useful in future sessions:
- New codebase pattern discovered
- Project convention identified
- User preference noted
- Gotcha or pitfall encountered

Save to memory using the auto-memory system.

### Present integration options
For Standard and Complex tiers, use:
```
Use Skill tool: hyperpowers:finishing-a-development-branch
```

For Quick tier, offer:
- Commit changes (if not already committed)
- Summary of what was done

</the_process>

<examples>

<example>
<scenario>User asks to fix a typo - Quick tier</scenario>

<code>
User: "There's a typo in the README - 'recieve' should be 'receive'"

Claude (without workflow-orchestrator):
*Immediately edits the file*
"Fixed the typo."
</code>

<why_it_fails>
- No beads tracking (change is invisible to project history)
- No verification (what if the typo appears in multiple places?)
- No investigation (are there other typos nearby?)
- Pattern of skipping process for "simple" changes builds bad habits
</why_it_fails>

<correction>
**Phase 0: Classify** -> Quick (1 file, <50 lines, typo fix)
"This is a **Quick** tier task because it's a single-file typo fix."

**Phase 1: Plan** -> Create beads epic + Tests task
```bash
bd create "Epic: Fix typo in README" --type epic --priority 3
bd create "Task: Fix 'recieve' -> 'receive' in README.md" --type feature
bd create "Tests: Fix typo in README" --type feature  # Mandatory
```

**Phase 2: Investigate** -> Read README, grep for other instances
```bash
# Read target file
Read README.md
# Check for same typo elsewhere
Grep "recieve" across project
```
Discovery: typo appears in 3 files, not just README.

**Phase 3: Implement** -> Fix all instances, verify
Fix all 3 occurrences. Commit.

**Phase 4: Verify** -> Full suite
- Run tests (verify no strings broke)
- Code review agent confirms all instances fixed
- Grep confirms no remaining instances
- Close Tests task

**Phase 5: Close** -> Close epic, note discovery
"Found and fixed 3 instances instead of 1. Beads tracked."
</correction>
</example>

<example>
<scenario>User asks to add a new API endpoint - Standard tier</scenario>

<code>
User: "Add a GET /api/breweries/nearby endpoint that returns breweries within a given radius"

Claude (without workflow-orchestrator):
"Sure, let me add that endpoint..."
*Writes endpoint without checking existing patterns*
*Uses different error handling than other endpoints*
*No tests*
</code>

<why_it_fails>
- Didn't investigate existing endpoint patterns (pattern mismatch)
- Different error handling creates inconsistency
- No tests means correctness unverified
- No beads means no tracking or success criteria
</why_it_fails>

<correction>
**Phase 0: Classify** -> Standard (multi-file, adding endpoint with clear pattern to follow)
"This is a **Standard** tier task because it adds a new endpoint to an existing API."

**Phase 1: Plan** -> Light brainstorm, create beads
Use brainstorming skill (1-2 questions about radius units, max results, etc.)
Create epic with requirements, anti-patterns, tasks, and Tests task.

**Phase 2: Investigate** -> Dispatch codebase-investigator
"Find existing API endpoint patterns: route structure, error handling,
response format, validation approach, test patterns."
Discovery: All endpoints use consistent middleware, validation, response format.

**Phase 3: Implement** -> TDD via executing-plans
RED: Write test for nearby endpoint
GREEN: Implement following discovered patterns
REFACTOR: Clean up

**Phase 4: Verify** -> Full suite + code review
- All tests pass (including new endpoint tests)
- Code review agent confirms pattern consistency
- Edge cases: no lat/lng params, invalid radius, no results
- Tests task closed with evidence

**Phase 5: Close** -> Close epic, commit, offer PR
</correction>
</example>

<example>
<scenario>User asks to add OAuth - Complex tier</scenario>

<code>
User: "Add Google OAuth authentication to the app"

Claude (without workflow-orchestrator):
"I'll add passport-google-oauth20..."
*Starts coding without investigating existing auth*
*Doesn't ask about token storage, session handling*
*No epic, no plan, no tests*
</code>

<why_it_fails>
- No brainstorming (missed critical decisions: token storage, session handling)
- No investigation (might already have auth middleware to extend)
- No plan (will discover gaps mid-implementation)
- No tests (auth bugs are security vulnerabilities)
- No beads (complex work with no tracking)
</why_it_fails>

<correction>
**Phase 0: Classify** -> Complex (new external integration, cross-cutting concern)
"This is a **Complex** tier task because it's a new external integration with cross-cutting auth concerns."

**Phase 1: Plan** -> Full brainstorm + SRE refinement
Full Socratic brainstorming: token storage, session handling, user model integration, error states.
Research: codebase-investigator (existing auth) + internet-researcher (OAuth best practices).
Create epic with immutable requirements, anti-patterns, design rationale.
SRE refinement on first task.
Mandatory Tests task created.

**Phase 2: Investigate** -> Both agents in parallel
Codebase: Find existing auth, session handling, user model.
External: Google OAuth2 docs, passport strategy options.

**Phase 3: Implement** -> TDD via executing-plans + code review per task
Each task: RED -> GREEN -> REFACTOR -> commit -> code-reviewer agent -> next task.
SRE refinement on each new task before starting.

**Phase 4: Verify** -> Full suite + code review
- All tests pass (unit + integration)
- Code review: pattern consistency, security, edge cases
- Tests task closed: auth flow tests, error state tests, token handling tests
- Every success criterion verified with evidence

**Phase 5: Close** -> Close epic, memory update, offer PR
Memory: "Project uses passport.js for auth, sessions in httpOnly cookies"
</correction>
</example>

</examples>

<critical_rules>
## Rules That Have No Exceptions

1. **Always classify before acting** -> Every task gets a tier. No "just do it" shortcuts.
2. **Always create beads** -> Every tier gets an epic with plan and mandatory Tests task. No exceptions.
3. **Always investigate before writing** -> Read target files minimum. Dispatch agents for Standard+.
4. **Always TDD** -> Tests before implementation. RED before GREEN. Every tier.
5. **Never scale down verification** -> Full suite + code review agent. Quick tier gets same verification as Complex.
6. **Epic cannot close with open Tests task** -> Tests are the gate. Always.
7. **Default UP on tier uncertainty** -> When unsure: Quick->Standard, Standard->Complex.
8. **User override affects planning, not verification** -> "Just a quick fix" reduces brainstorming depth but verification stays full.

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "It's just a typo" -> Quick tier exists for this. Still gets beads + verification.
- "I know this codebase" -> Investigation prevents pattern drift. Still investigate.
- "Tests aren't needed for this" -> Tests task is mandatory. Create it.
- "Verification is overkill" -> Verification never scales down. Run the full suite.
- "Let me just make this one change first" -> Classify first. Plan first. Always.
- "The user is in a hurry" -> Skipping process creates bugs that cost more time later.
- "This is a trivial change" -> Trivial changes with subtle bugs cause production incidents.
- "I already know which tier this is" -> Still announce and document the classification signals.
</critical_rules>

<verification_checklist>
Before claiming ANY task is complete:

**Phase 0 (Classify):**
- [ ] Tier announced with specific signal that matched
- [ ] User override respected if given

**Phase 1 (Plan):**
- [ ] Beads epic created with plan
- [ ] Mandatory Tests task exists in epic
- [ ] Success criteria defined and measurable
- [ ] Anti-patterns defined (for Standard/Complex)

**Phase 2 (Investigate):**
- [ ] Target files read before any edits
- [ ] Existing patterns identified
- [ ] Investigation findings noted

**Phase 3 (Implement):**
- [ ] Tests written before implementation (TDD)
- [ ] Changes committed
- [ ] Beads tasks updated/closed

**Phase 4 (Verify):**
- [ ] Full test suite passed (via test-runner agent)
- [ ] Code review agent dispatched and findings addressed
- [ ] Tests task closed with evidence
- [ ] All epic success criteria verified with evidence
- [ ] verification-before-completion skill used

**Phase 5 (Close):**
- [ ] Tests task closed
- [ ] Epic closed
- [ ] Memory updated if learnings exist

**Cannot check all boxes? Do not claim completion. Return to the incomplete phase.**
</verification_checklist>

<integration>
**This skill replaces:**
- Ad-hoc skill selection (no more guessing which skill to use)
- hyperpowers:using-hyper for task classification (this skill IS the entry point)

**This skill calls (by tier):**

| Skill / Agent | Quick | Standard | Complex |
|---|---|---|---|
| hyperpowers:brainstorming | - | Light | Full |
| hyperpowers:sre-task-refinement | - | - | Yes |
| hyperpowers:test-driven-development | Yes | Via executing-plans | Via executing-plans |
| hyperpowers:executing-plans | - | Yes | Yes |
| hyperpowers:verification-before-completion | Yes | Yes | Yes |
| hyperpowers:finishing-a-development-branch | - | Yes | Yes |
| codebase-investigator agent | - | Yes | Yes |
| internet-researcher agent | - | - | Yes |
| code-reviewer agent | Yes (verify only) | Yes (verify only) | Yes (per-task + verify) |
| test-runner agent | Yes | Yes | Yes |

**This skill is called by:**
- Session start (replaces using-hyper for task dispatch)
- Any user request that involves code changes

**Beads integration:**
- Phase 1 creates epic + Tests task
- Phase 3 updates task status
- Phase 4 verifies Tests task
- Phase 5 closes everything
</integration>

<edge_cases>

## Non-git directory
Beads requires git. If not in a git repo:
1. Ask user: "This directory isn't a git repository. Should I initialize one?"
2. If yes: `git init`, then `bd init`
3. If no: fall back to TaskCreate for tracking (reduced but not zero process)

## No test framework in project
If the project has no test runner:
1. The FIRST implementation step is setting up a test framework
2. Add "test framework configured" to the Tests task criteria
3. Ask user which framework they prefer if not obvious from the stack

## Beads not initialized
If git exists but beads doesn't:
1. Run `bd init`
2. If fails: fall back to TaskCreate with equivalent tracking
3. Note in memory that beads needs initialization in this project

## Verification fails repeatedly
1. First failure: fix and re-verify
2. Second failure: review epic anti-patterns, check if approach is fundamentally wrong
3. Third failure: escalate to user with full context and findings
4. Track failures: `bd comment [epic-id] "Verification failure N: [description]"`

## User explicitly asks to skip a phase
- Plan (Phase 1): REFUSE. Planning is non-negotiable. Explain why.
- Investigate (Phase 2): Allow reduced scope if user provides full context. Still read target files.
- Implement (Phase 3): Can reduce TDD scope for pure config changes. Tests task still required.
- Verify (Phase 4): REFUSE. Verification is non-negotiable. Explain why.
- Close (Phase 5): Allow if user wants to keep working in the same branch.

</edge_cases>
