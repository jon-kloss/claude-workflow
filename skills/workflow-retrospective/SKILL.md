---
name: workflow-retrospective
description: Use after completing an epic or periodically to analyze workflow effectiveness - queries beads for incident logs and metrics, reads the gate override ledger, triages incidents by pattern frequency, drafts actual skill file edits for recurring patterns, saves findings to memory
---

<skill_overview>
Analyze workflow effectiveness from three data sources: beads history (closed epics, tasks, structured comments), `WORKFLOW INCIDENT:` / `VERIFICATION FAILURE:` comments, and the gate override ledger at `~/.claude/hooks/state/override-audit.log`. Triage incidents by pattern frequency — recurring patterns (2+ of the same category+skill) get drafted skill file edits, one-offs get prose proposals — and cluster overrides by gate: any gate overridden ≥3 times in the analysis window is automatically a finding. Data-driven feedback loop for continuous workflow improvement.
</skill_overview>

<rigidity_level>
HIGH FREEDOM - Adapt analysis depth to available data. The 5-step process (Gather, Analyze/Triage, Report, Propose, Save) is mandatory, but what you find and recommend varies by project history.
</rigidity_level>

<quick_reference>
| Step | Action | Output |
|------|--------|--------|
| 1. Gather | Query beads (epics, tasks, incident + verification comments) AND read the override ledger | Raw data |
| 2. Analyze/Triage | Metrics, incident triage by category+skill, override clustering by hook+tag | Findings + triage results |
| 3. Report | Structured metrics report + incident triage + override pressure | Dashboard + triage tables |
| 4. Propose | Draft skill edits for recurring patterns, prose for one-offs | Drafted edits + proposals |
| 5. Save | `bd remember` durable insights + log the `RETROSPECTIVE:` marker comment | Cross-session awareness + next-retro baseline |

**Metrics (one line each):**
- First-pass verification rate = epics with zero `VERIFICATION FAILURE:` comments ÷ closed epics. Target >80%.
- Rework rate = implementation tasks with ≥1 fix-cycle or reopen ÷ closed `--type task` beads. Target <20%.
- Error type distribution = `VERIFICATION FAILURE:` comments bucketed by `Category:`.
- Step effectiveness = failures bucketed by `Source:` step (registry §2 IDs — see the attribution table in Step 2).
- Override pressure = ledger lines in the window clustered by hook+tag; ≥3 for one gate = automatic finding.

**Triage thresholds:**
- Incidents: 2+ of same category+skill → RECURRING → drafted SKILL.md edit. 1 → ONE-OFF → prose + monitor.
- Overrides: ≥3 of same hook+tag in the window → automatic finding (either the gate is wrong or the process is).
</quick_reference>

<when_to_use>
- /build Phase 4 (Step 4.8: Retrospective Check) invokes this when EITHER (a) ≥3 epics have closed since the last retro — the `bd list --status closed --type epic` count vs. the closed-epic count recorded in the last `RETROSPECTIVE:` comment — or (b) ≥10 `WORKFLOW INCIDENT:` comments have accumulated since the last retro. Under `--auto`, /build does not run it: it notes the pending retro in its closing summary; run this skill manually then.
- On demand when you want to review workflow effectiveness
- When noticing recurring error patterns across projects

**Don't use when:**
- No completed epics exist yet (no data to analyze)
- Mid-epic execution (wait until epic closes)
- For debugging a specific issue (use debugging-with-tools)
</when_to_use>

<the_process>

## Step 1: Gather Data

### Query beads for completed work and incidents

```bash
# Closed epics (bd list hides closed by default; --status closed shows them)
bd list --status closed --type epic

# For each epic: details and comments (WORKFLOW INCIDENT / VERIFICATION FAILURE / FIX CYCLE)
bd show <epic-id>
bd comments <epic-id>

# Closed work items. The pipeline creates TWO bead types — count both, correctly labeled:
bd list --status closed --type task      # implementation tasks (/build Step 3.1) — the rework denominator
bd list --status closed --type feature   # Tests-gate beads (/design, one per epic) — completeness check, NOT work items

# The workflow-incidents issue (incidents logged with no active epic).
# --status all is required: bd search excludes closed issues by default.
bd search "Workflow Incidents" --status all
bd comments <workflow-incidents-id>      # includes prior RETROSPECTIVE: markers
```

### Read the override ledger

`~/.claude/hooks/state/override-audit.log` records every validated gate override the system has allowed — pipe-delimited, one per line:

```
timestamp | hook | tag | role | matched-kind | reason
```

This is the highest-signal bypass record the system keeps: every line is a moment a deterministic gate was told "no" with a reason that passed validation. The log is global across projects by design (the hook layer lives in `~/.claude/hooks/`) — filter to the analysis window by timestamp, attribute lines to this project via the reason text and role field where possible, and note unattributable lines rather than silently dropping them.

### Data points to collect per epic

For each closed epic, record:
- **Epic ID and name**
- **Task count** — implementation tasks created (plus the one Tests-gate bead)
- **Verification failures** — count of `VERIFICATION FAILURE:` comments
- **Workflow incidents** — count of `WORKFLOW INCIDENT:` comments, with full text
- **Rework instances** — tasks reopened or with fix-cycle handoffs (`FIX CYCLE` comments / `-fix-cycle-<N>` handoff files)
- **Error types found** — from the `Category:` field: test-failure, test-quality, code-review, spec-coverage, criteria-gap, integration, sre-intent-audit
- **Step that caught the error** — from the `Source:` field, mapped to registry §2 step IDs (attribution table in Step 2)

### Parse incident comments

For each `WORKFLOW INCIDENT:` comment, extract the structured fields:
- **Category**: skill-gap | missing-rule | wrong-default | edge-case | process-violation
- **Skill**: design | build | retrospective | hook-name | none
- **What happened**: what Claude did wrong
- **What should have happened**: correct behavior
- **User correction**: what the user said
- **Proposed fix**: optional suggestion

### Handle missing data gracefully

- No `WORKFLOW INCIDENT:` comments: either no corrections happened, or they weren't confirmed for logging. The `detect-correction.sh` hook only DETECTS correction-shaped user messages and prompts for logging — Claude writes the comment via `bd comments add` after the user confirms, so a declined prompt leaves no trace here.
- No `VERIFICATION FAILURE:` comments: either verification always passed first try or failures weren't logged.
- Empty override ledger for the window: no gate pressure — itself a data point (the gates aren't being fought).
- No comments at all: recommend enabling incident logging and verification failure comments.

---

## Step 2: Analyze and Triage

### Calculate quantitative metrics

One line each — see quick_reference for the formulas: first-pass verification rate (>80%), rework rate (<20%, denominator is `--type task` beads only — the Tests-gate `feature` beads never rework and inflate nothing but the illusion of health), error type distribution, step effectiveness, override pressure.

### Step effectiveness — attribute to the current pipeline

Bucket each failure by its `Source:` field using registry §2 step IDs, so errors are attributable to the role that caught them (and the roles that should have caught them earlier):

| Step | Name | Owner |
|---|---|---|
| 3.1 | investigation | codebase-investigator (+ data-architect when `@touches-data`) |
| 3.2 | TDD | backend-engineer / frontend-engineer + continuous verifier |
| 3.3a–3.3c | test-suite / test-effectiveness / code-review | hyperpowers mechanical agents |
| 3.3d | security-review | security-architect |
| 3.3e | devops-review | devops-architect |
| 3.3f | data-review | data-architect |
| 3.3g | qa-verification | qa-engineer |
| 3.3h | sre-intent-audit | spec-sre-auditor |
| 3.3i | fix-cycle | implementers + re-verifying reviewers |
| 3.4 | user sign-off | user |
| 4.1 | epic e2e | qa-engineer |
| 4.2 | release coordination | release-coordinator |

"Verification" is not one bucket. A failure caught at 3.3g that 3.3b should have caught is attributable — say so. The point of per-step attribution is knowing which reviewer earns its dispatch and which upstream step is leaking.

### Cluster the override ledger

Group the window's ledger lines by hook+tag. **Any gate overridden ≥3 times in the analysis window is automatically a retro finding** — no judgment call. The reasons column usually tells you which diagnosis applies:

- **Near-identical reasons** → the gate is wrong: it misfires on a legitimate pattern. Draft the hook/rule fix.
- **Varied reasons** → the process is wrong: the legitimate path routinely requires a bypass. Draft the skill edit that makes the path legal without an override.

Also flag any single spec or epic that accounts for most of the window's overrides — that's a work-item smell, not a gate smell.

### Triage incidents by pattern frequency

Group all `WORKFLOW INCIDENT:` comments by **category + skill** pair:

```markdown
## Incident Triage

| Category + Skill | Count | Classification | Action |
|---|---|---|---|
| missing-rule + build | 3 | RECURRING | Draft skill edit |
| edge-case + design | 2 | RECURRING | Draft skill edit |
| skill-gap + build | 1 | ONE-OFF | Prose proposal + monitor |
```

**Classification rules:**
- **RECURRING** (2+ incidents of same category+skill) → flagged for drafted skill edits in Step 4
- **ONE-OFF** (1 incident) → prose proposal only, noted as "monitor — may become a pattern"

### Identify trends

- **Improving/declining metrics** — verification rate and rework rate against the previous retro's numbers (in the last `RETROSPECTIVE:` marker and memory).
- **Recurring incident patterns** — same category+skill keeps appearing? The skill needs updating.
- **Step gaps** — if late steps (3.3g–3.3i, 4.1) catch most errors, earlier steps need strengthening.
- **Override pressure trend** — a gate newly under pressure, or pressure that vanished after a fix, is direct evidence about a rule's fit.
- **Incident vs. metric correlation** — do incident categories match the error type distribution?

---

## Step 3: Generate Report

Present findings in this structured format:

```markdown
## Workflow Retrospective Report
**Date:** [current date]
**Project:** [project name]
**Period:** [last RETROSPECTIVE: marker date (or first closed epic)] to [now]
**Epics analyzed:** [count]

### Key Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| First-pass verification rate | X% | >80% | [MET/BELOW] |
| Rework rate | X% | <20% | [MET/ABOVE] |
| Avg tasks per epic | X | - | - |
| Most common error type | [type] | - | - |
| Workflow incidents logged | X | - | - |
| Gate overrides in window | X | - | - |

### Error Type Distribution

| Error Type | Count | % | Trend |
|-----------|-------|---|-------|
| [category from VERIFICATION FAILURE comments] | X | X% | [UP/DOWN/STABLE] |

### Step Effectiveness

| Step | Owner | Errors Caught | % of Total |
|------|-------|--------------|------------|
| 3.1 investigation | codebase-investigator | X | X% |
| 3.2 TDD | engineers + continuous verifier | X | X% |
| 3.3a–3.3c mechanical | hyperpowers agents | X | X% |
| 3.3d security-review | security-architect | X | X% |
| 3.3e devops-review | devops-architect | X | X% |
| 3.3f data-review | data-architect | X | X% |
| 3.3g qa-verification | qa-engineer | X | X% |
| 3.3h sre-intent-audit | spec-sre-auditor | X | X% |
| 3.3i fix-cycle | implementers + re-verifiers | X | X% |
| 4.1 epic e2e | qa-engineer | X | X% |
| 4.2 release coordination | release-coordinator | X | X% |

### Override Pressure

| Hook + Tag | Count | Reason pattern | Diagnosis |
|---|---|---|---|
| [hook + tag] | X | [near-identical / varied — summarize] | [gate is wrong / process is wrong] |

### Incident Triage

| Category + Skill | Count | Status | Incidents |
|---|---|---|---|
| [category] + [skill] | X | RECURRING / ONE-OFF | [brief descriptions] |

### Strengths
- [What's working well, with evidence]

### Areas for Improvement
- [What needs attention, with evidence]
```

---

## Step 4: Propose Adjustments

Based on the data, propose **specific, actionable** adjustments. Two tracks: **incident-driven** (from triage + override clustering) and **metrics-driven** (from quantitative analysis).

### Track 1: Incident-Driven Proposals (from triage)

#### Recurring patterns (2+ incidents) → Draft actual skill edits

For each RECURRING incident pattern — and each gate at ≥3 overrides — draft the actual text that would be added to (or removed from) the relevant skill or hook. Map the incident category to the type of edit:

| Category | Edit Type | Where in SKILL.md |
|---|---|---|
| skill-gap | New step, section, or guidance | `<the_process>` section |
| missing-rule | New critical rule | `<critical_rules>` section |
| wrong-default | Modify existing behavior/rule | Relevant section |
| edge-case | New edge case entry | `<edge_cases>` section |
| process-violation | Strengthened enforcement (usually a hook change) | `<critical_rules>` / hook |
| override pressure (≥3 on one gate) | Hook fix (gate is wrong) OR skill edit (process is wrong) | Per the Step 2 diagnosis |

**Draft format:**

```markdown
### Drafted Edit: [skill]/SKILL.md — [section]

**Based on:** [N] incidents of [category] for /[skill]  (or: [N] overrides of [tag] on [hook])
**Incidents:**
- [incident 1 short description]
- [incident 2 short description]

**Proposed addition:**
```
[The actual text to add to the SKILL.md file]
```

**Rationale:** [Why this addresses the recurring pattern]
```

Present ALL drafts to the user for review before any changes are applied.

#### One-off incidents → Prose proposals

```markdown
### One-Off: [short description]

**Category:** [category], **Skill:** [skill]
**What happened:** [what went wrong]
**Proposed action:** Monitor — may become a pattern. No skill edit recommended yet (insufficient signal).
```

### Track 2: Metrics-Driven Proposals

| Finding | Proposed Adjustment |
|---------|-------------------|
| Pattern mismatches >30% of errors | Strengthen investigation: require codebase-investigator for all specs |
| Edge cases >30% of errors | Strengthen SRE refinement coverage |
| Integration failures >20% of errors | Strengthen connectivity/e2e coverage (3.3g matrices, 4.1 CUJs) |
| Stale assumptions >10% of errors | Verify agent-memory claims against current code before use |
| First-pass verification <60% | TDD not catching enough: review test quality (3.3b findings) |
| Rework rate >30% | Tasks too vague: increase SRE refinement coverage |
| Late steps (3.3g–3.3i, 4.1) catch >50% of errors | Earlier steps are leaking — errors should die sooner; strengthen 3.1/3.2/3.3a–3.3c |
| One gate overridden ≥3 times | Automatic finding: draft the hook fix or the skill edit — never "try harder next time" |
| Verification always passes first try | Either process is excellent OR verification is too lenient — check test quality |

### Present combined proposals

```markdown
## Proposed Adjustments

### Priority 1: Drafted Skill Edits (Recurring Patterns + Override Pressure)
[Each drafted edit from Track 1, with full text]

### Priority 2: Metrics-Driven Adjustments
- [ ] [Specific adjustment with data-backed reasoning]

### Priority 3: Monitor (One-Off Incidents)
- [ ] [One-off incident description — watch for recurrence]
```

**CRITICAL:** Do NOT modify skill files directly. Present all proposals (including drafted edits) for user approval first.

---

## Step 5: Save to Memory and Log the Marker

**1. Persist durable insights** via `bd remember` (the SessionStart memory policy):

```bash
bd remember "<insight>"                      # auto-generated key
bd remember "<insight>" --key <stable-key>   # when the next retro should update it in place
```

Save: current verification pass rate + trend, top error type, recurring category+skill pairs, gates under override pressure, approved adjustments. Do NOT save: raw data, detailed metrics, unapproved proposals, one-off incidents — query fresh next time.

**2. Log the `RETROSPECTIVE:` marker** — this is what /build Step 4.8 reads to decide when the next retro is due:

```bash
bd comments add <workflow-incidents-id> "RETROSPECTIVE: [date] — closed-epic count at retro: [M]; epics analyzed: [N]; incidents triaged: [K]; override findings: [J]"
```

If no `workflow-incidents` issue exists yet, create it first (the same issue the incident logger uses):

```bash
bd create --title="Workflow Incidents" --type=task --description="Collects workflow incidents when no epic is active. Retrospective reads these and logs RETROSPECTIVE: markers here."
```

</the_process>

<examples>

<example>
<scenario>Rework rate computed against the wrong denominator</scenario>

<code>
bd list --status closed --type feature
# Returns 3 beads — the one Tests-gate bead per epic. Rework rate: 0/3 = 0% → "MET"
# Report ships: "TDD is working; no action needed."
</code>

<why_it_fails>
The pipeline creates implementation work items with `--type task` (/build Step 3.1); `--type feature` matches only the one-per-epic Tests-gate beads, which never rework. The denominator is 3 gate beads instead of the ~20 implementation tasks, five of which went through multiple fix-cycles — so the metric reads 0% while the true rate is ~24%, and every downstream conclusion is built on a measurement of the wrong population. Bonus failure in the same session: `bd search "Workflow Incidents"` without `--status all` returned nothing because the issue had been closed, so the incident triage ran on zero incidents and reported "no patterns."
</why_it_fails>

<correction>
Query both types, labeled: `bd list --status closed --type task` for implementation tasks (the rework denominator) and `bd list --status closed --type feature` for Tests gates (a per-epic completeness check, not a rework population). Recompute: 5/21 = 24% → ABOVE target → check which reviewers' findings drove the fix-cycles via the Step Effectiveness table. And always `bd search "Workflow Incidents" --status all` — closed issues are excluded by default.
</correction>
</example>

</examples>

<critical_rules>
## Rules That Have No Exceptions

1. **All 5 steps must run** — Gather, Analyze/Triage, Report, Propose, Save. No skipping.
2. **Data-driven only** — Every finding must reference specific beads data or ledger lines. No subjective assessments.
3. **Don't modify skills directly** — Propose adjustments (including drafted edits) for user approval. Never auto-apply changes to /design, /build, or hook files.
4. **Adapt to data availability** — Limited data = limited conclusions. Don't fabricate trends from 2 data points.
5. **Recurring = 2+ incidents** — Only draft skill edits for patterns with 2+ incidents of the same category+skill (or a gate at ≥3 overrides). One-offs get prose proposals only.
6. **Read all three sources** — `WORKFLOW INCIDENT:` comments (epics + the workflow-incidents issue), `VERIFICATION FAILURE:` comments, AND the override ledger. Skipping the ledger discards the system's most honest record of where its gates chafe.
7. **Drafted edits must be complete** — Include the actual text, not just a description. "Add a rule about X" is not a drafted edit; the rule text is.
8. **Always log the `RETROSPECTIVE:` marker** — Without it, /build Step 4.8 cannot compute "epics since last retro" and the trigger degrades to firing on every closed epic.

## Common Rationalizations

- "One incident is enough to draft a rule" → No. One-offs get prose proposals. Wait for the pattern to recur.
- "This adjustment is obviously right, I'll just apply it" → Propose, don't apply. User approves changes.
- "Not enough data to run retrospective" → Run with available data, note limitations, set a re-run target.
- "The override ledger is mostly other projects' noise" → It is global by design. Filter by window and attribute lines; don't skip the read.
- "No incidents logged, so skip the triage" → Run it anyway — note the absence and check whether detect-correction prompts are being declined.
</critical_rules>

<verification_checklist>
Before completing retrospective:

- [ ] Step 1: Queried closed epics, `--type task` implementation tasks, AND `--type feature` Tests gates (labeled separately)
- [ ] Step 1: Collected `WORKFLOW INCIDENT:` comments from epics and the workflow-incidents issue (`bd search "Workflow Incidents" --status all`)
- [ ] Step 1: Collected all `VERIFICATION FAILURE:` comments
- [ ] Step 1: Read the override ledger, filtered to the analysis window
- [ ] Step 2: Calculated the five metrics; attributed failures to registry §2 steps/roles
- [ ] Step 2: Triaged incidents by category+skill; clustered overrides by hook+tag (≥3 = automatic finding)
- [ ] Step 3: Report includes metrics, step effectiveness, override pressure, and incident triage tables
- [ ] Step 4: Drafted actual edit text for each recurring pattern and each over-pressured gate; prose for one-offs
- [ ] Step 4: Presented all proposals for approval (not auto-applied)
- [ ] Step 5: Saved insights via `bd remember`; logged the `RETROSPECTIVE:` marker comment
- [ ] No subjective claims without data evidence; data limitations noted if history is thin
</verification_checklist>

<integration>
**This skill is called by:**
- /build Phase 4 (Step 4.8: Retrospective Check) — when EITHER ≥3 epics have closed since the last `RETROSPECTIVE:` comment or ≥10 `WORKFLOW INCIDENT:` comments have accumulated. Under `--auto`, /build notes the pending retro in its closing summary instead of running it.
- User on demand (periodic review)

**This skill reads:**
- `bd comments <epic-id>` — `WORKFLOW INCIDENT:` and `VERIFICATION FAILURE:` comments
- `bd search "Workflow Incidents" --status all` — the cross-epic incident issue (closed issues are excluded without `--status all`)
- `bd list --status closed --type epic|task|feature`, `bd show` — quantitative data
- `~/.claude/hooks/state/override-audit.log` — the gate override ledger

**This skill proposes changes to:**
- skills/design/SKILL.md, skills/build/SKILL.md, skills/workflow-retrospective/SKILL.md (self-improvement)
- Hook configurations (enforcement rules — especially gates under override pressure)

**Changes are PROPOSED, not applied.** User must approve before implementation.

**This skill works with:**
- `detect-correction.sh` hook — detects correction-shaped user messages and prompts; Claude logs the `WORKFLOW INCIDENT:` comment via `bd comments add` after the user confirms
- /build skill — logs `VERIFICATION FAILURE:` comments and reads this skill's `RETROSPECTIVE:` markers in Step 4.8
- The gate hooks + `hooks/_validate_override_reason.py` — append the override-ledger lines this skill clusters
</integration>
