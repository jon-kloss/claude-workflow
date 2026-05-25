---
name: respec
description: Use when an approved/implemented/verified spec needs changes - traces dependency blast radius, propagates contract changes to upstream/downstream specs, regresses statuses, and updates beads. Triggered by bug discovery, requirement change, or edge case too large for /build's living-doc updates.
---

<skill_overview>
Respec modifies existing Gherkin specs when requirements change, bugs surface, or edge cases outgrow /build's inline updates. It traces the dependency graph, classifies the change, propagates contract changes to affected specs, regresses statuses, and leaves all affected specs at `@status(approved)` for /build to resume.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: Must find spec from beads issue — no guessing which spec to edit.
- **RIGID**: Blast radius analysis before editing any spec — trace ALL @depends-on and @blocks relationships.
- **RIGID**: Contract-breaking changes propagate to downstream specs. No silent edits.
- **RIGID**: Status regression is mandatory for changed specs. No leaving stale statuses.
- **RIGID**: Reality check with user before finalizing — same as /design.
- **FLEXIBLE**: Questioning depth scales with change complexity — a typo fix needs 0 questions, a contract change needs several.
</rigidity_level>

<quick_reference>
## Respec Flow

```
/respec <beads-issue-id>
  -> Find spec: bd show <id> -> extract spec path from design field
  -> Understand change: Socratic questioning via AskUserQuestion
  -> Blast radius: read target spec + all @depends-on/@blocks chain
  -> Classify: additive | corrective | contract-breaking
  -> Edit target spec
  -> Propagate to downstream specs (contract-breaking only)
  -> Regress statuses: affected specs -> @status(approved)
  -> Update beads: reopen/flag tasks, add change comments
  -> Present specs: show full updated spec content to user
  -> Acceptance: user approves via AskUserQuestion (BLOCKS)
  -> If rejected: incorporate feedback, re-edit, re-present
  -> If accepted: update all affected specs to @status(approved)
  -> Auto-invoke /build on affected specs
```

## Change Classification

| Type | What changed | Propagation |
|------|-------------|-------------|
| **Additive** | New scenario, no existing behavior changes | Target spec only |
| **Corrective** | Fix wrong scenario, behavior changes | Target + check downstream for reliance on old behavior |
| **Contract-breaking** | Technical Context changes (data shapes, API contracts, error formats) | Target + ALL downstream specs referencing the changed contract |

## Status Regression Rules

| Prior Status | After Respec | Why |
|---|---|---|
| `@status(verified)` | `@status(approved)` | Needs re-implementation and re-verification |
| `@status(implemented)` | `@status(approved)` | Implementation is now wrong |
| `@status(approved)` | `@status(approved)` | No change — not yet built |
| `@status(draft)` | `@status(draft)` | Still in design |

## Hard Constraints

1. Find spec via beads issue — do not assume which spec to edit
2. Blast radius analysis BEFORE any edits
3. Contract-breaking changes propagate to downstream specs
4. Status regression is mandatory for all changed specs
5. Reality check with user before finalizing
6. All questions via AskUserQuestion (blocks execution)
7. Existing tests for regressed specs will need updating — note this in beads comments
</quick_reference>

<when_to_use>
**Use /respec when an existing spec needs modification:**

- Bug discovered that requires spec changes (not just a code fix)
- New requirement or feature addition to an existing spec
- Edge case discovered during /build that is too large for a living-doc update
- Stakeholder changes requirements after spec was approved
- /build detects fundamental spec drift and directs here

**Don't use /respec for:**

- New work with no existing spec — use `/design`
- Decomposing a too-large spec into multiple specs — use `/design` (edge case: decomposing)
- Minor scenario additions during /build — /build handles these as living-doc updates
- Implementation details (file paths, variable names) — those aren't in specs

**Distinction from /build living-doc updates:**
/build can add a scenario or fix minor Technical Context details inline. /respec is needed when:
- The change affects the spec's contract (data shapes, API format, error responses)
- Multiple specs are affected via dependency chain
- A spec at `@status(verified)` needs changes (re-verification required)
- The change is large enough that /build should pause and come back after respec
</when_to_use>

<the_process>

## Step 1: Announce and Find Spec

"I'm using the /respec skill to modify an existing spec."

### Find spec from beads issue

```bash
bd show <issue-id>
```

Extract the spec path from the issue's `design` field (e.g., `Spec: specs/user-registration.md`).

**If the issue has no spec reference:**
1. Check the parent epic's design field for spec references
2. Search issue title/description for spec-related keywords
3. Search `specs/` filenames for matches
4. If still not found: ask the user via AskUserQuestion which spec this issue relates to

**If the spec file doesn't exist:** STOP. "The spec referenced by this issue doesn't exist. Run `/design` to create it."

### Read the spec

Read the target spec file. Note:
- Current `@status`
- All `@depends-on` and `@blocks` tags
- Technical Context section (data shapes, API contracts, error formats)
- Existing scenarios and rules

## Step 2: Understand the Change

Ask focused questions via AskUserQuestion until the change is fully specified. Scale with complexity:

- **Simple additive** (new scenario, no contract change): 0-1 questions — the issue description may be sufficient
- **Corrective** (wrong behavior): 1-2 questions — confirm what the correct behavior should be
- **Contract-breaking** (data shapes, error formats, API changes): 2-5 questions — scope, downstream intent, migration path

**Questions to stabilize:**
- **What** — What specifically needs to change in this spec?
- **Why** — Bug, new requirement, discovered edge case?
- **Scope** — Does this change apply only to this feature, or system-wide?
- **Contract** — Does the Technical Context (data shapes, API format, error responses) change?
- **Downstream intent** — Should downstream specs adopt the same change, or handle it differently?

**BLOCKING REQUIREMENT: All questions via AskUserQuestion.** Do not proceed until answers are received.

## Step 3: Blast Radius Analysis

Before editing anything, trace the full dependency graph.

### Read all related specs

```bash
# Read the target spec (already done in Step 1)
# Read all specs this one @blocks (downstream dependents)
# Read all specs this one @depends-on (upstream dependencies)
# For contract-breaking changes: read the full chain recursively
```

### Check for informal references

Beyond `@depends-on`/`@blocks` tags, grep `specs/` for references to the target spec's contracts (endpoint paths, data shapes, type names). Specs may consume a contract without a formal dependency tag.

```bash
# Example: if target spec defines POST /api/auth/register
grep -r "register" specs/ --include="*.md"
grep -r "error.*string" specs/ --include="*.md"  # if error shape is changing
```

If informal references are found, treat them as downstream dependencies for blast radius purposes.

### Classify the change

Based on the user's answers and your spec reading:

**Additive:** New scenario added. No existing scenarios modified. Technical Context may expand (e.g., new enum value in a union type) but existing contracts are not broken.
- Blast radius: target spec only
- Downstream impact: none (expanding a type union is additive, changing a type shape is contract-breaking)
- Status regression still required if spec was verified/implemented

**Corrective:** Existing scenario modified. Behavior changes.
- Blast radius: target spec + downstream specs that reference the corrected behavior
- Check each downstream spec's scenarios and Technical Context for references to the old behavior

**Contract-breaking:** Technical Context changes — data shapes, API contracts, error response formats, interface signatures.
- Blast radius: target spec + ALL downstream specs in the `@blocks` chain
- Every downstream spec's Technical Context and scenarios must be audited for references to the changed contract

### Present blast radius to user

Via AskUserQuestion, present:
```
"Blast radius analysis for [change description]:

Change type: [additive | corrective | contract-breaking]

Target spec: specs/<target>.md (@status(current) -> @status(approved))

Downstream specs affected:
- specs/<downstream-1>.md — [what changes and why] (@status(current) -> @status(approved))
- specs/<downstream-2>.md — [no changes needed, contract not referenced]

Upstream specs: [not affected — changes flow downstream only]

Beads tasks that will be affected:
- beads-XXX (closed) — will be reopened
- beads-YYY (in_progress) — work partially invalidated, will be flagged

Existing tests: [N] test files for regressed specs will need updating during /build

Confirm this is the correct scope?"
```

**BLOCK until user confirms.** If user narrows or widens scope, adjust and re-present.

## Step 4: Edit Specs

### Edit target spec

1. Add/modify/correct scenarios as specified
2. Update Technical Context if contract changes
3. Update `@status` tag:
   - `@status(verified)` or `@status(implemented)` -> `@status(approved)`
   - `@status(approved)` stays `@status(approved)`
4. Add a change note below the status tags:

```markdown
@respec(YYYY-MM-DD): [brief description of change and why]
```

### Propagate to downstream specs (contract-breaking only)

For each downstream spec in the `@blocks` chain that references the changed contract:

1. Update Technical Context to reflect new contract (data shapes, error formats, etc.)
2. Update scenarios that reference old behavior (Given/When/Then steps using old formats)
3. Regress `@status` -> `@status(approved)`
4. Add `@respec` change note

**Do NOT propagate when ALL three deterministic checks pass:**
- **Additive change**: The diff to the upstream spec adds new `### Scenario:` blocks but modifies no existing scenario, no `## Technical Context` API entries, and no `## Interaction Map` entries. Verify with `git diff specs/<upstream-slug>.md` — look for `-` lines on existing scenario/contract sections.
- **No reference in downstream**: `grep -qE '<changed-contract-symbol>|<changed-endpoint>' specs/<downstream-slug>.md` returns no match. List the specific symbols/paths/endpoints the diff changed and grep each. "Doesn't seem to reference" without running grep is not sufficient.
- **Downstream is draft**: `grep -q '@status(draft)' specs/<downstream-slug>.md`. /design handles draft specs — they will pick up the new contract when next approved.

If any check is false, propagate.

### Upstream specs

Upstream specs (`@depends-on` targets) are generally NOT affected by downstream changes. Exception: if the change reveals that the upstream spec's contract was wrong, note this but do NOT edit — tell user to run `/respec` on the upstream spec separately.

## Step 5: Update Beads

### For each regressed spec:

```bash
# Find the beads task for this spec
bd search "<spec-slug>"

# If task is closed (was @status(verified)):
bd reopen <task-id>
bd comments add <task-id> "RESPEC: spec regressed from @status(verified) to @status(approved).

Change: [what changed]
Reason: [why]
Impact: [what needs to be re-implemented]
Tests: existing tests for this spec will need updating"

# If task is in_progress (was @status(implemented)):
bd comments add <task-id> "RESPEC: spec modified while implementation in progress.

Change: [what changed]
Reason: [why]
Impact: [what implementation work is invalidated]
Action: pause /build, review updated spec before continuing"

# If task is open (was @status(approved)):
bd comments add <task-id> "RESPEC: spec updated before implementation.

Change: [what changed]
Reason: [why]
Impact: none — implementation hasn't started"
```

### Log on epic

```bash
bd comments add <epic-id> "RESPEC: [target spec] modified

Change type: [additive | corrective | contract-breaking]
Specs affected: [list]
Status regressions: [list of spec -> new status]
Tasks affected: [list of task IDs and actions taken]
Trigger: [beads issue ID that triggered this respec]"
```

## Step 6: Present Specs and Get Acceptance

Present the **full updated spec content** to the user — not just a summary. This mirrors /design's reality check: the user sees exactly what was changed and approves or rejects.

### Part 1: Show the specs

For each modified spec, present:
1. The complete updated spec file content (so the user can read every scenario, Technical Context change, and tag)
2. A diff summary highlighting what changed from the previous version

Via AskUserQuestion:
```
"Here are the updated specs after respec:

---
## specs/<target>.md (changed from @status(verified) to @status(approved))

[FULL SPEC CONTENT — paste the entire file]

**Changes from previous version:**
- Added: [new scenarios]
- Modified: [changed scenarios or Technical Context]
- Unchanged: [scenarios that stayed the same]

---
## specs/<downstream>.md (changed from @status(implemented) to @status(approved))

[FULL SPEC CONTENT]

**Changes from previous version:**
- Modified: [propagated contract changes]

---

Build order after acceptance:
  1. specs/<target>.md (no dependencies among changed specs)
  2. specs/<downstream>.md (depends on: <target>)

Beads tasks affected:
- beads-XXX — reopened
- beads-YYY — flagged (in-progress work partially invalidated)

Existing tests: [N] test files will need updating during /build

Do you approve these specs?"
```

### Part 2: Get acceptance

**BLOCK until user responds.** Three outcomes:

- **"Yes, approve"** -> Proceed to Step 7
- **"No, needs changes"** -> Ask what's wrong via AskUserQuestion, return to Step 4 with feedback
- **Specific feedback** ("change X to Y", "this scenario is wrong") -> Incorporate, re-edit affected specs, re-present

**Do NOT proceed to /build with unapproved specs.** Acceptance is the gate.

## Step 7: Invoke /build

After the user accepts the updated specs:

1. Confirm all affected specs are `@status(approved)` (set during Step 4, validated here)
2. Announce the handoff:

```
"Specs approved. Invoking /build to implement the changes."
```

3. Hand off to /build:

**REQUIRED SUB-SKILL:** Invoke the `build` skill via the Skill tool. /build will pick up the regressed specs at `@status(approved)` and resume from where /respec stopped.

/build will:
- Detect the `@status(approved)` specs (including ones regressed by /respec)
- Build in dependency order
- Follow its full process (investigate, TDD, verify)

**The /respec -> /build handoff is automatic.** The user does not need to manually run `/build`.

## Exit State

/respec is complete when:
- All affected specs are edited with correct changes
- User has accepted the updated specs (seen full content, approved)
- All affected specs have `@status(approved)`
- `@respec` change notes added to each modified spec
- Beads tasks reopened/flagged/commented as appropriate
- Epic has a RESPEC comment documenting the change
- /build has been invoked automatically

</the_process>

<examples>

<example>
<scenario>Additive change — new scenario, no contract change</scenario>

<why_it_fails>
Without /respec, "just adding a scenario" looks like: edit the file, add the scenario, done. But the spec was at `@status(verified)` — meaning /build closed the beads task and the existing test suite says the feature is complete. Adding a scenario doesn't trigger a status regression, so the new scenario silently has no test, no implementation, and no beads tracking. The verified spec now contains behavior that doesn't exist in code, and nobody knows. Status regression is mandatory because *change to the spec = change to what "verified" means*; the workflow needs the spec to drop back to `@status(approved)` so /build picks it up again.
</why_it_fails>

<correction>
**Step 1:** `bd show beads-042` — finds `specs/user-registration.md`.

**Step 2:** User says "add email format validation before uniqueness check." No questions needed — change is fully specified and additive.

**Step 3:** Blast radius:
- Change type: additive (new scenario, no Technical Context change)
- Target: `specs/user-registration.md` (@status(verified) -> @status(approved))
- Downstream: none affected (new scenario doesn't change existing contract)
- Beads: beads-043 (closed) will be reopened

**Step 4:** Add new scenario to spec:
```markdown
### Scenario: Reject registration with malformed email
- Given a user submits registration with email "not-an-email"
- When the registration is processed
- Then it is rejected before uniqueness check
- And the error indicates invalid email format
```
Regress `@status(verified)` -> `@status(approved)`.

**Step 5:** Reopen beads-043, add RESPEC comment.

**Step 6:** Present full updated spec to user via AskUserQuestion — shows complete spec content with the new scenario, highlights the addition. User approves.

**Step 7:** "Specs approved. Invoking /build." -> /build picks up `user-registration.md` at `@status(approved)`.
</correction>
</example>

<example>
<scenario>Contract-breaking change — error response shape changes</scenario>

<why_it_fails>
Without blast-radius analysis, the agent edits `user-registration.md`'s Technical Context to use the new error shape and stops there. The change propagates exactly nowhere — but `user-authentication.md` and `payment-processing.md` both reference the old shape in their scenarios and Technical Context. Those specs stay `@status(verified)` against contracts that no longer exist, and their test suites still pass because they're asserting the old format that was never updated. Production code starts emitting the new shape from registration, the old shape from auth and payments, and consumers see a mixed bag. The blast radius IS the contract — silent edits to a contract-bearing spec are how systems silently fracture.
</why_it_fails>

<correction>
**Step 1:** `bd show beads-042` — finds `specs/user-registration.md`.

**Step 2:** AskUserQuestion: "The error response shape is changing from `{ error: string }` to `{ errors: [{ field, message }] }`. Does this new shape apply only to registration, or system-wide to all validation errors?" User confirms: system-wide.

**Step 3:** Blast radius:
- Change type: contract-breaking (error response shape in Technical Context)
- Target: `specs/user-registration.md` (@status(verified) -> @status(approved))
- Downstream: `specs/user-authentication.md` references error format in login failure scenarios (@status(implemented) -> @status(approved))
- Downstream: `specs/payment-processing.md` references error format (@status(approved) stays @status(approved), but Technical Context updated)
- Beads: beads-043 reopened, beads-044 flagged (in-progress work invalidated)

User confirms scope.

**Step 4:** Edit all three specs — update Technical Context error shapes, update scenarios referencing old format, regress statuses, add `@respec` notes.

**Step 5:** Reopen beads-043, flag beads-044 with RESPEC comment, comment on beads-045, log on epic.

**Step 6:** Present all three updated specs in full to user via AskUserQuestion. Shows complete content of each spec with diff summary. User reviews error shape changes across all three specs. User says "approve."

**Step 7:** "Specs approved. Invoking /build." -> /build picks up all 3 specs at `@status(approved)` in dependency order.
</correction>
</example>

<example>
<scenario>/build pauses due to fundamental spec drift</scenario>

<why_it_fails>
Without /respec, /build's natural instinct under pressure is to "just make it work" — rewrite the spec inline to match what the payment provider actually supports, then continue implementing. The spec now contains webhook scenarios but the design rationale, dependency tags, and downstream specs were never reconsidered. The user never approved the new approach. Anyone reading the spec later sees fully-formed webhook scenarios and assumes they were intentional from day one, with no record that the original sync assumption was wrong. /respec exists because contract-level changes need user approval and downstream propagation — silent in-build rewrites bypass both.
</why_it_fails>

<correction>
/build discovers during implementation that `specs/payment-processing.md` assumes synchronous payment confirmation, but the payment provider only supports webhooks (async).

/build says: "Spec is fundamentally wrong. Run `/respec` to fix."

**Step 1:** `bd show beads-045` — finds `specs/payment-processing.md`.

**Step 2:** AskUserQuestion: "The payment provider only supports async webhooks, but the spec assumes synchronous confirmation. Should we redesign around webhooks, or use a polling fallback?" User chooses webhooks.

**Step 3:** Blast radius:
- Change type: contract-breaking (confirmation mechanism changes from sync to async)
- Target: `specs/payment-processing.md` (@status(approved) stays @status(approved))
- Upstream: check if `specs/user-authentication.md` is affected (likely not — auth doesn't depend on payment confirmation mechanism)
- No downstream specs

**Step 4:** Rewrite payment-processing scenarios for webhook-based confirmation. Add new scenarios for webhook timeout, retry, and idempotency.

**Step 5:** Update beads-045 with RESPEC comment.

**Step 6:** Present full updated spec to user. Shows the rewritten scenarios for webhooks, new timeout/retry/idempotency scenarios. User reviews and approves.

**Step 7:** "Specs approved. Invoking /build." -> /build resumes with updated `payment-processing.md`.
</correction>
</example>

</examples>

<critical_rules>
## Rules That Have No Exceptions

1. **Find spec from beads issue** -> Do not guess. Look up the issue, find the spec reference.
2. **Blast radius before editing** -> Trace the FULL dependency chain. Every @depends-on and @blocks relationship.
3. **Classify before propagating** -> Additive changes don't propagate. Contract-breaking changes MUST propagate.
4. **Status regression is mandatory** -> Changed specs regress to @status(approved). No stale statuses.
5. **Present full spec content for acceptance** -> Show the complete updated spec, not just a summary. User must see every scenario and Technical Context change.
6. **Acceptance gates /build** -> Do NOT invoke /build until user explicitly approves the updated specs.
7. **All questions via AskUserQuestion** -> Blocks execution until answered.
8. **No implementation during respec** -> Respec edits specs. /build implements them. Do not write code.
9. **Auto-invoke /build after acceptance** -> Once user approves, invoke /build automatically. The user does not manually run /build.
10. **Note existing test impact** -> Regressed specs with existing tests need those tests updated during /build. Always note this.

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "It's just adding a scenario" -> Classify first. Even additive changes need status regression if the spec was verified.
- "The downstream specs are probably fine" -> "Probably" is not analysis. Read them. Check Technical Context references.
- "I'll just fix this one spec quickly" -> Quick edits without blast radius analysis cause cascading failures.
- "The status can stay as verified since the change is small" -> Size doesn't matter. Changed spec = regressed status. Period.
- "I don't need to check beads for this" -> Every respec touches beads. Reopening/flagging tasks is mandatory.
- "The user knows which spec to edit" -> The user knows the ISSUE. The skill's job is to trace it to the spec.
- "I'll propagate later" -> Propagation happens NOW or downstream specs silently diverge.
- "This is too small for /respec, I'll just edit inline" -> If the spec's contract changes or status needs to regress, it's not "too small."
- "The user already saw the blast radius, they don't need to see the full spec" -> Blast radius is scope confirmation. Acceptance requires seeing the actual spec content — every scenario, every Technical Context field.
- "I'll let the user run /build when they're ready" -> No. /build invocation is automatic after acceptance. The handoff is seamless.
</critical_rules>

<verification_checklist>
Before claiming /respec is complete:

- [ ] Spec found from beads issue (not assumed)
- [ ] All questions asked via AskUserQuestion
- [ ] User answered all questions before proceeding
- [ ] Target spec read in full
- [ ] All @depends-on and @blocks specs identified and read
- [ ] Change classified as additive / corrective / contract-breaking
- [ ] Blast radius presented to user and confirmed
- [ ] Target spec edited with correct changes
- [ ] Downstream specs propagated (contract-breaking changes only)
- [ ] @respec change notes added to all modified specs
- [ ] Status regression applied to all changed specs
- [ ] Beads tasks reopened/flagged/commented
- [ ] RESPEC comment logged on epic
- [ ] Existing test impact noted in beads comments
- [ ] Full spec content presented to user (not just a summary)
- [ ] User explicitly accepted the updated specs
- [ ] No implementation code written (that's /build's job)
- [ ] /build invoked automatically after acceptance

**Cannot check all boxes? Do not claim respec is complete.**
</verification_checklist>

<integration>
**This skill calls:**

| Skill / Tool | When |
|---|---|
| AskUserQuestion | Understanding change + blast radius confirmation + spec acceptance |
| bd show / bd search | Finding spec from beads issue |
| bd comments add | Logging changes on tasks and epic |
| bd reopen | Reopening closed tasks for regressed specs |
| /build | Automatically after user accepts updated specs |

**This skill produces (consumed by /build):**
- Modified `specs/*.md` files with `@status(approved)` and `@respec` change notes
- Reopened/flagged beads tasks ready for /build to pick up
- RESPEC comments on epic documenting what changed
- Automatic /build invocation (user does not need to manually run /build)

**This skill is triggered by:**
- User typing `/respec <beads-issue-id>`
- /build detecting fundamental spec drift and directing here
- User discovering a requirement change or bug in a spec

**Related skills:**
- `/design` — creates specs from scratch. Use /design for new work or spec decomposition.
- `/build` — implements specs. /build resumes after /respec finishes.
- `/design` edge case "Decomposing an existing spec" — for splitting one spec into multiple. /respec is for modifying behavior within existing spec boundaries.
</integration>

<edge_cases>

## Beads issue has no spec reference
1. Check parent epic's design field
2. Search `specs/` for filename matching issue keywords
3. Ask user via AskUserQuestion: "Which spec does this issue relate to?"

## Spec is @status(draft)
The spec hasn't been approved yet. Direct to /design: "This spec is still in draft. Run `/design` to complete the design process before modifying it."

## Change requires a NEW spec (not modification of existing)
If the change introduces entirely new functionality that doesn't belong in any existing spec:
"This change requires a new spec, not a modification. Run `/design` to create it."

## Circular dependency discovered during propagation
If propagating changes reveals a circular dependency (A depends on B depends on A):
STOP. "Circular dependency discovered during propagation. Run `/design` to restructure the dependency graph."

## Multiple specs need independent changes
If the beads issue maps to changes across multiple unrelated specs (no dependency relationship):
Run /respec once per spec. Do not batch unrelated changes.

## Spec was partially implemented (@status(implemented))
The implementation is partially done. After respec:
- Spec regresses to `@status(approved)`
- Beads task flagged with what implementation work is invalidated
- /build resumes and may need to undo or rework existing code

## No beads issue provided
Ask: "Which beads issue triggered this respec? I need the issue ID to find the relevant spec." If user provides a spec path directly, use it — but still log changes on the appropriate beads issue.

</edge_cases>
