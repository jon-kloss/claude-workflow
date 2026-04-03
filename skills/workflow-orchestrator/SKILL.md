---
name: workflow-orchestrator
description: Use for ANY task - classifies complexity into Quick/Standard/Complex tiers, chains phases (Classify, Plan, Investigate, Implement, Verify, Close), always creates beads, always runs full verification. Replaces ad-hoc skill selection with enforced adaptive workflow.
---

<skill_overview>
Adaptive developer workflow that classifies every task into Quick/Standard/Complex tiers and chains 6 mandatory phases. Planning depth scales with complexity; verification never does. Every task gets beads tracking, TDD, and full verification suite + code review agent.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: Phase 0 (Classify), Phase 1 (Plan), and Phase 4 (Verify) are mandatory and identical across all tiers. Never skip, never scale down.
- **RIGID**: Every epic MUST have a mandatory Tests task. Epic cannot close without it.
- **RIGID**: Tier classification defaults UP when uncertain.
- **FLEXIBLE**: Planning depth, investigation scope, and review checkpoints scale with tier.
</rigidity_level>

<quick_reference>
## Tier Comparison

| | **Quick** | **Standard** | **Complex** |
|---|---|---|---|
| **Scope** | 1-2 files, <50 lines | Multi-file, clear scope | New feature, epic-level |
| **Planning** | Beads epic + task + Tests task | Brainstorm (light, 1-2 Qs via AskUserQuestion, BLOCKS) + SRE refinement + beads epic + tasks + Tests task | Full brainstorm (multi-round Qs via AskUserQuestion, BLOCKS) + SRE refinement + beads epic + Tests task |
| **Investigation** | codebase-investigator agent | codebase-investigator agent (AFTER brainstorm answers received) | codebase-investigator + internet-researcher (AFTER brainstorm answers received) |
| **Implementation** | TDD cycle | TDD per task via executing-plans + continuous verifier agent (gates task closure) | TDD per task via executing-plans + continuous verifier agent (gates task closure) |
| **Verification** | **Full suite + code review + test-effectiveness-analyst agents** | **Full suite + code review + test-effectiveness-analyst agents** | **Full suite + code review + test-effectiveness-analyst agents** |

## Phase Chain

```
User request
  -> Phase 0: CLASSIFY tier (Quick / Standard / Complex)
  -> Phase 1: PLAN + brainstorm via AskUserQuestion (BLOCKS until user answers) + create beads epic with Tests task
  -> Phase 2: INVESTIGATE codebase (depth scales with tier) — ONLY after Phase 1 questions answered
  -> Phase 3: IMPLEMENT with TDD (review rigor scales with tier)
  -> Phase 4: VERIFY full suite + code review agent (NEVER scales down)
  -> Phase 5: CLOSE beads + update memory
```

## Hard Constraints (every tier, no exceptions)

1. Beads epic created with plan
2. Mandatory Tests task in every epic
3. Codebase investigated before writing code; findings logged as bd comments (Standard+)
4. TDD: tests before implementation
5. Full verification suite + code review agent
6. Epic cannot close with open Tests task
7. **Always use subagents** for investigation, code review, test running, and test analysis — never do manually what an agent can do in parallel
8. SRE refinement on all Standard+ tasks (boundary conditions, error paths, concurrency, environment)
9. Continuous verifier agent gates task closure on Standard+ epics
10. VERIFICATION comment logged on every epic before closing
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
  --description "[WHY this epic exists and WHAT it accomplishes]" \
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
  --description "[WHY this task exists and WHAT needs to be done]" \
  --design "[Implementation details with file paths]"
bd dep add [task-id] [epic-id] --type parent-child

bd create "Tests: [Epic name]" --type feature --priority 2 \
  --description "Verification gate for [Epic name] - ensures all tests pass and edge cases are covered before epic closes" \
  --design "## Goal
VERIFICATION GATE - This task prevents epic auto-close.
NEVER close this task during Phase 3 (Implementation).
Only close in Phase 4 (Verify) after ALL verification passes.

Beads auto-closes epics when all children are closed. This task
stays open to block that until verification is complete.

## Success Criteria
- [ ] Test files created/modified for all implementation tasks
- [ ] All tests pass
- [ ] Edge cases covered (empty input, error states, boundary conditions)
- [ ] No tautological tests (each test catches a specific bug)
- [ ] Test coverage adequate for changed code
- [ ] Full verification suite passed (Phase 4)
- [ ] Code review agent found no CRITICAL/IMPORTANT issues"
bd dep add [tests-id] [epic-id] --type parent-child
```

### Standard Tier Planning

Use brainstorming skill in lightweight mode (1-2 clarifying questions, not full Socratic deep-dive):

```
Use Skill tool: hyperpowers:brainstorming
```

**BLOCKING REQUIREMENT: Brainstorming MUST ask questions and WAIT for answers before proceeding.**

Enforcement rules for brainstorming:
1. **Use AskUserQuestion tool** — Do NOT print questions as text. The AskUserQuestion tool blocks execution until the user responds. Text questions do not block and lead to proceeding without answers.
2. **Do NOT dispatch investigation agents "while waiting"** — Investigation happens in Phase 2, AFTER the user has answered brainstorming questions. Dispatching codebase-investigator during brainstorming leads to the agent rationalizing that it has "enough context" to skip the user's answers.
3. **Do NOT proceed until answers are received** — If you asked a question, you must receive and incorporate the answer before moving forward. "Making reasonable defaults for ambiguous parts" is not acceptable — if something is ambiguous, that's exactly what brainstorming questions are for.
4. **Phase 1 is complete ONLY when the user has answered all CRITICAL questions** — The epic cannot be created until the user has confirmed the design.

Brainstorming will create the beads epic with requirements, anti-patterns, and first task. After brainstorming completes, verify the epic has a Tests task. If not, create one.

After tasks are created, run SRE refinement on each task:

```
Use Skill tool: hyperpowers:sre-task-refinement
```

SRE refinement must explicitly address:
- **Boundary conditions**: empty inputs, first-time state, fresh/uninitialized environments
- **Error paths**: what happens on failure mid-operation? Resource/handle cleanup?
- **Concurrent/async edge cases**: race conditions, ordering assumptions, lifecycle timing
- **Environment differences**: paths, OS behavior, missing config, subprocess availability

**Quality minimum:** SRE refinement output must identify at least 1 edge case NOT already present in the user's description or the pattern being followed. The edge case must be specific to THIS task's domain entities and operations — not a generic infrastructure concern (database failure, network timeout, large input) that could be pasted into any SRE output. Name the specific entity, the specific state, and the specific incorrect behavior that would result. "Same as existing endpoint" is not valid SRE output. Example of a phoned-in edge case: "What if the database is unavailable?" Example of a real edge case: "What if the user has no activity yet — does the endpoint return an empty array or 404?" If SRE refinement cannot find a domain-specific novel edge case, the task scope is likely under-specified.

### Complex Tier Planning

Use full brainstorming skill (Socratic questions, research agents, approach comparison):

```
Use Skill tool: hyperpowers:brainstorming
```

**BLOCKING REQUIREMENT: Full Socratic questioning is mandatory for Complex tier.**

Enforcement rules (same as Standard, plus additional rigor):
1. **Use AskUserQuestion tool** — Do NOT print questions as text. AskUserQuestion blocks execution until the user responds.
2. **Do NOT dispatch investigation agents "while waiting"** — Investigation happens in Phase 2, AFTER brainstorming questions are answered. Premature investigation causes the agent to skip user answers.
3. **Do NOT proceed until answers are received** — Every CRITICAL question must be answered. "Making reasonable defaults" is forbidden.
4. **Multiple rounds of questions are expected** — Complex tasks have hidden constraints. If you only asked one round of questions, you probably missed something.
5. **Research agents during brainstorming are for informing questions, not replacing them** — If codebase-investigator reveals the project uses passport.js, that informs what to ask the user, it doesn't eliminate the need to ask.

After brainstorming creates epic and first task, run SRE refinement on each task:

```
Use Skill tool: hyperpowers:sre-task-refinement
```

SRE refinement must explicitly address:
- **Boundary conditions**: empty inputs, first-time state, fresh/uninitialized environments
- **Error paths**: what happens on failure mid-operation? Resource/handle cleanup?
- **Concurrent/async edge cases**: race conditions, ordering assumptions, lifecycle timing
- **Environment differences**: paths, OS behavior, missing config, subprocess availability

**Quality minimum:** SRE refinement output must identify at least 1 edge case NOT already present in the user's description or the pattern being followed. "Same as existing endpoint" is not valid SRE output.

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
Dispatch a codebase-investigator subagent (even for small changes):
```
Agent tool (subagent_type: hyperpowers:codebase-investigator):
"Read [target file(s)] and find similar patterns in nearby files.
Check: naming conventions, error handling, imports, and any existing code
that does something similar to [description].
Report file paths, line numbers, and patterns to follow."
```
This keeps investigation out of your main context and ensures consistent pattern discovery.

### Standard Tier Investigation
Dispatch a codebase-investigator subagent. If the task involves external libraries, APIs, or unfamiliar patterns, also dispatch internet-researcher in parallel:
```
Agent tool (subagent_type: hyperpowers:codebase-investigator):
"Find existing patterns for [what we're building].
Check: similar implementations, naming conventions, error handling patterns,
test patterns, and any existing code that does something like [description].
Report file paths, line numbers, and patterns to follow."

# If task involves external APIs, libraries, or unfamiliar patterns:
Agent tool (subagent_type: hyperpowers:internet-researcher):
"Research [library/API/pattern] usage.
Find: current documentation, best practices, common pitfalls,
and code examples relevant to [what we're building]."
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

### MANDATORY for Standard+ Epics: Log Investigation Findings (Enforcement 3)

For Standard and Complex tier epics, investigation findings MUST be logged as bd comments on the epic before proceeding to Phase 3. This creates an auditable trail of what was known before implementation began.

```bash
bd comment [epic-id] "INVESTIGATION FINDING: [what was learned]

Patterns discovered:
- [Existing patterns for the same concern — e.g., how does other code handle output, logging, error reporting?]
- [Current conventions for naming, error handling, event emission, styling, configuration]
- [Integration points with existing code — what interfaces does the consumer expect? What types/formats?]

Decision: [How findings will influence implementation approach]"
```

**Quality minimum:** Investigation findings must reference at least 2 specific file paths with line numbers and at least 1 concrete convention or pattern discovered (not just "will follow existing pattern"). The act of writing the finding forces you to articulate what you actually learned — vague findings mean vague understanding, which leads to pattern mismatches during implementation.

**Why this must be a separate artifact (not just "I investigated in my head"):** When a verification failure occurs later, the investigation log lets you distinguish three cases: (1) a known risk that was accepted, (2) an unknown the investigation missed, or (3) a known finding the implementation failed to address. Without the log, you cannot tell which failure mode occurred during post-mortem, and the retrospective cannot improve the investigation process. The code shows what you built; the log shows what you knew when you built it.

**Why:** Pattern mismatches are 12% of all errors. These happen when new code uses a different convention than existing code — writing to a different output stream, matching by name when existing code matches by ID, hardcoding values when a config/theme system exists. All preventable by reading existing code first and documenting what was found.

---

## Phase 3: IMPLEMENT (TDD always. Review rigor scales.)

**CRITICAL: Do NOT close the Tests task during this phase.** The Tests task is a verification gate that prevents beads from auto-closing the epic. It stays open until Phase 4 verification passes. Closing it prematurely will auto-close the epic and skip verification.

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

### Standard and Complex Tier Implementation

Use executing-plans to work through tasks iteratively:

```
Use Skill tool: hyperpowers:executing-plans
```

Executing-plans will:
- Execute tasks one at a time with TDD
- Review learnings after each task
- Create next task based on reality
- Run SRE refinement on new tasks (Enforcement 2)
- STOP after each task for user review

#### Continuous Verifier Agent (Enforcement 7)

**When the first implementation task moves to `in_progress`, spawn a background verifier agent.** The verifier persists for the duration of the epic and gates task closure.

**Spawn timing:** When the first Standard+ implementation task moves to `in_progress`.

**Per-task review cycle:** After writing code for a task but BEFORE `bd close`, send the verifier the following context:
1. The git diff of all files changed by this task
2. The bd task description and acceptance criteria (`bd show [task-id]`)
3. The bd epic description for broader context (`bd show [epic-id]`)

```
Agent tool (subagent_type: hyperpowers:code-reviewer, run_in_background: false):
"You are the CONTINUOUS VERIFIER for epic [epic-id].

## Context
- Task: [task-id] — [task title]
- Epic: [epic-id] — [epic title]
- Task description: [paste from bd show]
- Epic requirements: [paste from bd show]

## Git diff to review
[paste git diff]

## Review these 5 dimensions IN ORDER:

### 1. Correctness against spec
Does the code actually implement what the task description says? Are all acceptance criteria met, or are any silently skipped or stubbed?

### 2. Consistency with codebase
Does the new code follow the same patterns as existing code? Check: naming conventions, error handling style, output targets (stdout vs stderr vs logging), ID vs name usage, configuration approach (hardcoded vs config/theme system).
Read 2-3 existing files that do similar things to compare.

### 3. Edge cases and error paths
For each new function or branch:
- What happens with empty/nil/zero input?
- What happens if this is called twice?
- What happens on failure mid-operation (resource cleanup)?
- What happens in a fresh/uninitialized environment?
- Are error returns checked, or silently discarded?

### 4. Integration soundness
For code that connects to other components:
- Are events/callbacks emitted at the right lifecycle point?
- Does the consumer handle all variants the producer can emit?
- Are there ordering assumptions that could break under concurrency?
- Are there capacity limits (queues, buffers) that could silently drop data?

### 5. Dead weight
Is there any code in this diff that:
- Is declared but never called?
- Accepts config/options it doesn't act on?
- Stubs out behavior that's exposed as functional?

## For test-only or documentation-only changes
If this task only modifies tests or documentation (no production code), skip the 5 dimensions and instead check test quality:
- Are any tests tautological (cannot fail regardless of implementation)?
- Do assertions check correctness, not just existence?
- Are edge cases covered?

## Output format
Return a structured verdict:

VERIFIER [task-id]: PASS | PASS_WITH_NOTES | FAIL

Findings:
- [CRITICAL] C1: <description>. Recommendation: <fix>
- [IMPORTANT] I1: <description>. Recommendation: <fix>
- [MINOR] M1: <description>. Recommendation: <fix>

## Rules
- Do NOT write code or make changes. Only read and review.
- Do NOT second-guess architectural decisions from the epic design phase.
- Do NOT block on style preferences. Findings must be tied to: correctness, consistency, edge case, integration, or dead weight.
- Only review the diff, not the entire codebase."
```

**Log each finding as a bd comment on the task:**
```bash
bd comment [task-id] "VERIFIER [task-id]: [PASS|PASS_WITH_NOTES|FAIL]

- [CRITICAL] C1: <description>. Recommendation: <fix>
- [IMPORTANT] I1: <description>. Recommendation: <fix>
- [MINOR] M1: <description>. Recommendation: <fix>"
```

#### What blocks task closure

| Severity | Action Required |
|---|---|
| **CRITICAL** | Task CANNOT be closed. Fix the issue, then re-submit the diff to the verifier. Loop until no CRITICALs remain. |
| **IMPORTANT** | Task can be closed IF the implementing agent addresses the finding OR logs a justification for deferral as a bd comment. The verifier must acknowledge the response. |
| **MINOR** | Logged for the record. Does not block closure. |

#### Verifier efficiency rules
- Only reviews the diff per task, not the entire codebase on each pass
- For consistency checks (dimension 2), reads at most 3 existing reference files
- Does NOT re-review files already approved unless they were modified again
- For Quick tier epics, the verifier is optional — the standard Phase 4 review at epic close is sufficient

**Why the verifier runs during Phase 3, not Phase 4:** Catching errors after all tasks are complete means rework cascades across dependent tasks; catching them per-task bounds the blast radius to one task. The verifier is not "verification in the wrong phase" — it is a quality gate on implementation output, analogous to a compiler error: you fix it before proceeding, not at the end. Phase 4 serves a different purpose: it reviews the composed whole, not the individual parts.

**Why (multi-task epics):** Code review catches 97% of errors but only at epic close, after all tasks are done. By then, early mistakes compound: later tasks build on flawed code. A continuous verifier catches issues at the task boundary, when the fix is one function not a cascade.

**Why (single-task epics):** Yes, the diff is the same for a single-task epic. No, the reviews are not redundant. The verifier runs BEFORE the Tests task is written — its findings inform what tests to write. Phase 4 runs AFTER the Tests task — it checks whether those tests are adequate. They see the same code at different points in the workflow, which means they catch different classes of issues: the verifier catches implementation bugs before tests exist; Phase 4 catches test-quality bugs after tests exist. Additionally: (1) the verifier gates task closure so that test-writing is informed by review findings, not written against potentially flawed code; (2) the verifier's 5-dimension structured review is more rigorous than the Phase 4 general review — it forces systematic per-function checking; (3) findings logged on the task create a per-task audit trail that Phase 4's epic-level comments cannot provide. Do not skip the verifier for single-task epics.

**SRE re-run on modified tasks:** If a task's scope changes materially during Phase 3 (new acceptance criteria added, approach changed, scope expanded beyond original description), SRE refinement must re-run on the modified task before continuing implementation. "Material change" = the task description was updated via `bd update`.

---

## Phase 4: VERIFY (Full suite. EVERY tier. NEVER scales down.)

This phase is IDENTICAL regardless of tier. No exceptions.

**Phase 4 is NOT redundant with the continuous verifier (Enforcement 7).** The verifier reviews each task's diff in isolation during Phase 3. Phase 4's code reviewer sees the full epic diff and catches cross-task issues: naming inconsistencies between tasks, integration assumptions that hold per-task but break when composed, dead code left by earlier tasks that later tasks obsoleted, and emergent patterns visible only at epic scope. Both are required. If the verifier already caught everything, Phase 4 will be fast — that's a feature, not a reason to skip it.

### MANDATORY: Log ALL verification failures as bd comments

**Every verification failure in Phase 4 MUST be logged as a bd comment on the epic before returning to fix it.** This is non-negotiable — these comments are the data quality foundation that the workflow-retrospective skill depends on to measure phase effectiveness, rework rates, and error type distribution.

**Format:**
```bash
bd comment [epic-id] "VERIFICATION FAILURE [step]: [category] - [description]

Source: [which verification step caught it]
Category: [test-failure | test-quality | code-review | criteria-gap]
Severity: [CRITICAL | IMPORTANT | MINOR]
Action: [returning to Phase 3 | fixing inline | deferring]"
```

**Examples:**
```bash
bd comment bd-42 "VERIFICATION FAILURE Step 1: test-failure - 3 unit tests failing in auth/token.test.ts

Source: test-runner agent
Category: test-failure
Severity: CRITICAL
Action: returning to Phase 3"

bd comment bd-42 "VERIFICATION FAILURE Step 2: test-quality - tautological test in auth/login.test.ts (asserts mock returns what mock was told to return)

Source: test-effectiveness-analyst agent
Category: test-quality
Severity: CRITICAL
Action: returning to Phase 3"

bd comment bd-42 "VERIFICATION FAILURE Step 3: code-review - endpoint missing input validation for radius parameter, allows negative values

Source: code-reviewer agent
Category: code-review
Severity: IMPORTANT
Action: fixing inline"
```

**Why this matters:** Without structured failure comments, the workflow-retrospective has no data to analyze. It cannot tell you which phases catch errors, what types of errors recur, or whether rework rates are improving. Log every failure, every time.

---

### Step 1: Run full test suite
```
Agent tool (subagent_type: hyperpowers:test-runner):
"Run the full test suite for this project. Report only failures and summary."
```

If tests fail: **log as bd comment** (category: `test-failure`), then return to Phase 3 to fix. Do NOT proceed.

### Step 2: Run test effectiveness analysis
```
Agent tool (subagent_type: hyperpowers:test-effectiveness-analyst):
"Analyze all test files changed or created in this epic.
Check for: tautological tests, coverage gaming, weak assertions,
missing corner cases, and tests that don't actually catch bugs.
Report issues categorized as CRITICAL / IMPORTANT / MINOR."
```

If CRITICAL issues found: **log each as bd comment** (category: `test-quality`), then fix before proceeding.

#### Test Quality Gate (Enforcement 6)

In addition to the test-effectiveness-analyst agent, apply these specific thresholds:

**Tautological test** = a test that cannot fail regardless of implementation correctness:
- Testing that a constant is non-empty
- Testing that a builder/constructor returns a value
- Testing that an object has the fields you just set on it
- Testing that a function doesn't throw when called with valid input (with no assertion on the result)

**Weak assertion** = checks existence or type but not correctness (e.g., `!= nil` instead of `== expectedValue`)

**Manual review procedure (required even when agent finds 0 issues):**
Open each test file changed in this epic and spot-check at least 3 test functions against the tautological/weak-assertion definitions above. For each, ask: "What specific bug would this catch? Could production code break while this test passes?" If you cannot name a specific failure mode, the test is suspect. The test-effectiveness-analyst agent catches patterns; manual review catches individual tests the agent may have classified too generously.

**Output requirement:** Log the manual review as a bd comment on the epic. For each spot-checked test, name the test function, the specific bug it would catch, and your verdict (PASS/SUSPECT). Example: `test_nearby_returns_empty_for_zero_radius` — catches: radius=0 returns empty instead of all results — PASS. If any test is SUSPECT, it becomes a test-quality finding.

**Thresholds:**
- **3+ tautological tests in one epic = CRITICAL** `test-quality` finding
- Log with structured format:
```bash
bd comment [epic-id] "VERIFICATION Phase 4: test-quality - [count] tautological tests (RED): [list]. [count] YELLOW tests with weak assertions.

Source: test-effectiveness-analyst agent + manual review
Category: test-quality
Severity: CRITICAL
Action: returning to Phase 3 to replace tautological tests with meaningful ones"
```

### Step 3: Run code review agent
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

If CRITICAL issues found: **log as bd comment** (category: `code-review`), return to Phase 3 to fix. Do NOT proceed.
If IMPORTANT issues found: **log as bd comment** (category: `code-review`), fix before proceeding.
MINOR issues: **log as bd comment** (category: `code-review`), note for future improvement but can proceed.

#### Integration Point Verification (Enforcement 4)

When the epic touches multiple modules/packages/services or connects components that communicate via events, channels, callbacks, or shared interfaces, the code review agent prompt MUST include this explicit integration checklist:

```
Additionally, check these integration points:
- Events/signals are emitted at the correct lifecycle point (not before preconditions are met)
- Buffers, queues, and channels have sufficient capacity or overflow behavior is documented and acceptable
- Consumer code handles all variants/states the producer can emit
- State transitions are complete (no dead variables that promise behavior they don't deliver)
```

Any integration finding gets logged with category `integration`.

**Why:** Integration failures are 15% of all errors. Examples: events firing before preconditions were met, bounded queues silently dropping messages, state clearing that breaks downstream consumers, displays that render once but never update.

#### Dead Code / Stale Assumption Check (Enforcement 5)

During Phase 4 verification, explicitly scan for dead code, unused variables, and config/API surface that promises behavior it doesn't deliver:

1. Run the project's linter with all warnings enabled and treat warnings as findings
2. Specifically look for:
   - Config fields, options, or parameters that are parsed/accepted but never acted on
   - Variables assigned but never used in the intended way
   - Stub implementations that are exposed as if functional (e.g., a handler that accepts input but does nothing)
   - Public API surface that implies capabilities that aren't wired up

**Dead config/API that promises safety or correctness behavior it doesn't deliver is CRITICAL severity.**

```bash
bd comment [epic-id] "VERIFICATION Phase 4: code-review - Dead config: [field/option] is accepted but never acted on. Users may rely on behavior that doesn't exist.

Source: dead code scan (Phase 4)
Category: code-review
Severity: CRITICAL
Action: [wire up the behavior | remove the config surface | document as not-yet-implemented]"
```

**Note: Enforcement 5 is NOT satisfied by the continuous verifier's Dimension 5.** The verifier checks dead weight per-task diff. But cross-task dead code — a function added in task 1 whose usage is removed or changed in task 3, or config surface that was wired up in one task but silently unwired by a later task — is only visible in a full-project scan at epic scope. Both are required; they catch different things.

**Why:** Stale assumptions / dead code account for 9% of errors. The worst case is a config option or API parameter that promises behavior (like error cancellation or resource limits) but is never wired up. This applies equally to new code: new features often implement the data model before the behavior, leaving config surface that promises functionality it doesn't yet deliver.

**Note:** Steps 1, 2, and 3 (test-runner, test-effectiveness-analyst, and code-reviewer) should be dispatched as parallel subagents when possible, since they are independent of each other. Log all failures as bd comments AFTER agents return results.

### Step 4: Verify Tests task complete
```bash
bd show [tests-task-id]  # Must be status: closed
```

If Tests task is not closed: close it only if ALL test criteria are met (test files exist, tests pass, edge cases covered, no tautological tests).

### Step 5: Check epic success criteria
```bash
bd show [epic-id]  # Read success criteria
```

Walk through EVERY success criterion. For each one:
- Verify it is objectively met (not "probably" or "should be")
- Note the evidence (test output, file exists, command output)

If ANY criterion is not met: **log as bd comment** (category: `criteria-gap`), return to Phase 3.

### Step 6: Final verification skill
```
Use Skill tool: hyperpowers:verification-before-completion
```

**If verification-before-completion reveals any issue not already logged, log it as a bd comment:**
```bash
bd comment [epic-id] "VERIFICATION FAILURE Step 6: [category] - [description]

Source: verification-before-completion skill
Category: [test-failure | test-quality | code-review | criteria-gap]
Severity: [CRITICAL | IMPORTANT | MINOR]
Action: [returning to Phase 3 | fixing inline]"
```

### Verification Failure Handling
- Maximum 3 fix-verify cycles before escalating to user
- Every failure is already logged as a bd comment (from steps above)
- If stuck after 3 cycles: present the issue to user with full context and link to the failure comments

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

### MANDATORY: Log Verification Comment Before Closing (Enforcement 1)

Before closing the epic, verify that at least one bd comment containing the word "VERIFICATION" exists on the epic. If Phase 4 found issues, each should already be logged. If Phase 4 found NO issues, you MUST add a pass comment:

```bash
bd comment [epic-id] "VERIFICATION Phase 4: PASSED — no issues found"
```

If verification found issues, each finding should already have its own comment with this format:
```bash
bd comment [epic-id] "VERIFICATION Phase 4: [category] - [SEVERITY] [ID]: [description]. Action: [action taken]"
```

Categories: `code-review`, `test-quality`, `integration`
Severities: `CRITICAL`, `IMPORTANT`, `MINOR`

**This is non-negotiable.** Without verification comments, retrospectives have no data. 67% of past epics had no verification comments logged.

### Close beads
```bash
bd close [tests-task-id]   # Tests task first (if not already closed)
bd close [epic-id]          # Then epic (ONLY after verification comment exists)
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
bd create "Epic: Fix typo in README" --type epic --priority 3 --description "README has a misspelling that needs correcting"
bd create "Task: Fix 'recieve' -> 'receive' in README.md" --type feature --description "Fix the 'recieve' typo in README.md"
bd create "Tests: Fix typo in README" --type feature --description "Verification gate for typo fix epic"  # Mandatory
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
6. **Tests task is a verification gate** -> NEVER close it during Phase 3. Beads auto-closes epics when all children close. The Tests task stays open to prevent this until Phase 4 verification passes.
7. **Default UP on tier uncertainty** -> When unsure: Quick->Standard, Standard->Complex.
8. **User override affects planning, not verification** -> "Just a quick fix" reduces brainstorming depth but verification stays full.
9. **Always use subagents** -> If an operation can run in a subagent (investigation, code review, test running, test analysis), it MUST run in a subagent. Never do manually what an agent can do. This protects context, enables parallelism, and ensures consistent quality.
10. **Brainstorming MUST block on user answers** -> Use AskUserQuestion tool (not text). Do NOT proceed past Phase 1 until the user has answered all CRITICAL questions. Do NOT dispatch investigation agents "while waiting for answers" — that causes the agent to skip the user's input entirely.
11. **Log every verification failure as a bd comment** -> Before returning to Phase 3 to fix anything, log a structured comment on the epic (category, severity, source, action). This is the data foundation the retrospective depends on. No comment = no data = blind optimization.
12. **Log a VERIFICATION comment on every epic close** (Enforcement 1) -> Even when verification passes with no issues, log "VERIFICATION Phase 4: PASSED — no issues found" before closing. 67% of past epics had no verification comments — retrospectives are blind without this trail.
13. **SRE refinement on all Standard+ tasks** (Enforcement 2) -> Run `hyperpowers:sre-task-refinement` on every task in Standard and Complex tier epics. Must address: boundary conditions, error paths, concurrent/async edge cases, environment differences. Edge cases are 30% of all errors.
14. **Log investigation findings on Standard+ epics** (Enforcement 3) -> Before implementation, log `INVESTIGATION FINDING:` comments on the epic documenting patterns, conventions, and integration points discovered. Pattern mismatches are 12% of all errors.
15. **Integration point checklist for cross-module tasks** (Enforcement 4) -> Phase 4 code review must explicitly check: event lifecycle timing, buffer/queue capacity, consumer-producer variant coverage, and state transition completeness. Integration failures are 15% of all errors.
16. **Dead code / stale assumption scan** (Enforcement 5) -> Phase 4 must scan for config/API surface that promises behavior it doesn't deliver. Dead config promising nonexistent safety behavior = CRITICAL. Stale assumptions are 9% of errors.
17. **Test quality gate with thresholds** (Enforcement 6) -> 3+ tautological tests in one epic = CRITICAL. Flag weak assertions that check existence but not correctness.
18. **Continuous verifier agent for Standard+ epics** (Enforcement 7) -> Spawn background verifier when first implementation task starts. Reviews 5 dimensions per task. CRITICAL findings block task closure. Catches errors at task boundary instead of at epic close.

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "It's just a typo" -> Quick tier exists for this. Still gets beads + verification.
- "I know this codebase" -> Investigation prevents pattern drift. Still investigate.
- "Tests aren't needed for this" -> Tests task is mandatory. Create it.
- "Verification is overkill" -> Verification never scales down. Run the full suite.
- "Let me just make this one change first" -> Classify first. Plan first. Always.
- "The user is in a hurry" -> Skipping process creates bugs that cost more time later.
- "This is a trivial change" -> Trivial changes with subtle bugs cause production incidents.
- "I already know which tier this is" -> Still announce and document the classification signals.
- "I can just read this file quickly myself" -> Use a codebase-investigator agent. Protects your context window and is more thorough.
- "I'll review the code myself instead of dispatching an agent" -> Code review agent catches things you'll miss. Always dispatch it.
- "I'll investigate while waiting for answers" -> NO. This leads to skipping answers entirely. Investigation is Phase 2, after brainstorming questions are answered in Phase 1.
- "I'll make reasonable defaults for the ambiguous parts" -> NO. Ambiguity is exactly what brainstorming questions resolve. Use AskUserQuestion and wait.
- "The user's description is detailed enough" -> Detailed descriptions still have hidden constraints. Always ask CRITICAL questions via AskUserQuestion.
- "I have enough context from the codebase" -> Codebase context informs what to ask, it doesn't replace asking. The user's intent matters.
- "The old workflow worked fine without these enforcements" -> Those epics may have had undetected errors the retrospective couldn't measure BECAUSE E1-E3 were not in place. Prior success without enforcement does not validate skipping enforcement — it means you were flying blind.
- "The user says this component is well-tested" -> User assertions about existing code quality do not reduce verification requirements for new integration code. The user is telling you about THEIR code; you are verifying YOUR code's interaction with it.
- "These enforcements were written for a specific project" -> The error categories (pattern mismatch, edge case, integration, stale assumption, test quality) are universal. The specific percentages come from retrospective data, but every codebase has these failure modes. The enforcements apply to all projects.
- "The continuous verifier already covered this in Phase 3" -> The verifier checks per-task diffs in isolation. Phase 4 checks the full epic diff and cross-task interactions. A function added in task 1 and silently broken by task 3 is invisible to the verifier but visible to Phase 4. Both are required; they catch different things.
- "SRE refinement will just say 'same as existing pattern'" -> That is not valid SRE output. Even pattern-following tasks have unique edge cases. If SRE cannot find a novel edge case, the task is under-specified, not over-refined.
- "Investigation findings are obvious, logging them is ceremony" -> The log is not for you now — it is for post-mortem later. When a verification failure occurs, the log lets you distinguish: was this a known risk, an investigation miss, or an implementation failure? Without the log, you cannot tell. If findings feel obvious, they should be fast to write — not a reason to skip.
</critical_rules>

<verification_checklist>
Before claiming ANY task is complete:

**Phase 0 (Classify):**
- [ ] Tier announced with specific signal that matched
- [ ] User override respected if given

**Phase 1 (Plan):**
- [ ] Brainstorming questions asked via AskUserQuestion tool (not printed as text) — for Standard/Complex tiers
- [ ] User answered all CRITICAL questions before proceeding
- [ ] No investigation agents dispatched until after user answered brainstorming questions
- [ ] Beads epic created with plan
- [ ] Mandatory Tests task exists in epic
- [ ] Success criteria defined and measurable
- [ ] Anti-patterns defined (for Standard/Complex)
- [ ] SRE refinement run on all tasks (Standard/Complex — Enforcement 2)

**Phase 2 (Investigate):**
- [ ] Target files read before any edits
- [ ] Existing patterns identified
- [ ] Investigation findings noted
- [ ] Investigation findings logged as bd comments on epic (Standard/Complex — Enforcement 3)

**Phase 3 (Implement):**
- [ ] Tests written before implementation (TDD)
- [ ] Changes committed
- [ ] Beads tasks updated/closed
- [ ] Continuous verifier agent spawned for Standard/Complex (Enforcement 7)
- [ ] Each task reviewed by verifier BEFORE bd close — CRITICAL findings block closure
- [ ] Verifier findings logged as bd comments on tasks

**Phase 4 (Verify):**
- [ ] Full test suite passed (via test-runner agent)
- [ ] Test effectiveness analyzed (via test-effectiveness-analyst agent)
- [ ] Test quality gate applied: 3+ tautological tests = CRITICAL (Enforcement 6)
- [ ] Code review agent dispatched and findings addressed
- [ ] Integration point checklist included for cross-module tasks (Enforcement 4)
- [ ] Dead code / stale assumption scan completed (Enforcement 5)
- [ ] All three verification agents dispatched in parallel where possible
- [ ] **Every failure logged as structured bd comment on epic** (category, severity, source, action)
- [ ] Tests task closed with evidence
- [ ] All epic success criteria verified with evidence
- [ ] verification-before-completion skill used

**Phase 5 (Close):**
- [ ] VERIFICATION comment logged on epic — either PASSED or structured findings (Enforcement 1)
- [ ] README updated if epic changed features, API, UI, dependencies, or usage (or confirmed skip with reason)
- [ ] Epic closed (Tests task already closed in Phase 4)
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
| hyperpowers:sre-task-refinement | - | Yes (Enforcement 2) | Yes |
| hyperpowers:test-driven-development | Yes | Via executing-plans | Via executing-plans |
| hyperpowers:executing-plans | - | Yes | Yes |
| hyperpowers:verification-before-completion | Yes | Yes | Yes |
| hyperpowers:finishing-a-development-branch | - | Yes | Yes |
| codebase-investigator agent | Yes | Yes | Yes |
| internet-researcher agent | - | Yes (if external APIs, libraries, or unfamiliar patterns) | Yes |
| code-reviewer agent | Yes (verify only) | Yes (continuous verifier + verify) | Yes (continuous verifier + verify) |
| test-runner agent | Yes | Yes | Yes |
| test-effectiveness-analyst agent | Yes | Yes | Yes |

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
