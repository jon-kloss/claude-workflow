---
name: design-arch
description: Use after specs are approved to generate architecture documentation — arch.md, draw.io architecture diagrams, and a visual overview.html page for non-technical stakeholders. Auto-invoked by /design, also callable independently after /respec or mid-build.
---

<skill_overview>
Generates architecture documentation from approved Gherkin specs. Produces three artifacts: `specs/arch.md` (architecture document), `specs/diagrams/*.drawio` (architecture diagrams), and `specs/overview.html` (visual design overview for non-technical audiences). Can be invoked automatically by /design after spec approval, or independently when architecture docs need updating.

**Role-agent orchestration (experimental branch).** This skill orchestrates two role agents:
- `application-architect` — owns the component map, data flow, and design decisions in `arch.md`. Authors the architecture handoff at `specs/handoffs/step-4.5-<slug>-application-architect.html`.
- `devops-architect` — owns the deployment topology, observability stack, scaling section, and failure-recovery section. Authors `specs/handoffs/step-4.5-<slug>-devops-architect.html`. The deployment diagram in `specs/diagrams/deployment.drawio` comes from this agent's `<svg>` output.

The skill's existing procedure (gate checks, draw.io format, overview.html stakeholder design) still governs how the artifacts on disk are produced — the role agents contribute the *content* via their handoffs.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: All three artifacts must be generated. No partial output.
- **RIGID**: `specs/arch.md` and `specs/diagrams/system-architecture.drawio` are always required (for non-trivial work).
- **RIGID**: `specs/overview.html` must be self-contained — no external dependencies.
- **RIGID**: User must confirm architecture documentation via AskUserQuestion before the skill exits.
- **FLEXIBLE**: Diagram count scales with complexity — simple work gets one diagram, complex work gets several.
- **FLEXIBLE**: Level of detail in arch.md scales with project complexity.
</rigidity_level>

<quick_reference>
## Architecture Documentation Flow

```
Approved specs in specs/
  -> Read all approved specs to understand the system
  -> Generate specs/arch.md (architecture document)
  -> Generate specs/diagrams/*.drawio (architecture diagrams)
  -> Generate specs/overview.html (visual overview page)
  -> Gate check: verify all artifacts exist on disk
  -> Present to user via AskUserQuestion
  -> User confirms -> Exit
  -> User requests changes -> Revise and re-present
```

## Artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| Architecture doc | `specs/arch.md` | Component map, data flow, design decisions |
| System diagram | `specs/diagrams/system-architecture.drawio` | High-level component diagram (always) |
| Data flow diagram | `specs/diagrams/data-flow.drawio` | Request/event flow (when non-trivial) |
| Deployment diagram | `specs/diagrams/deployment.drawio` | Infrastructure (when applicable) |
| Overview page | `specs/overview.html` | Visual summary for non-technical stakeholders |

## Hard Constraints

1. All three artifact types must be produced (arch.md, at least one .drawio, overview.html)
2. Gate check verifies files exist on disk before presenting to user
3. User must confirm via AskUserQuestion — no proceeding without confirmation
4. overview.html must be fully self-contained (inline CSS, no external deps)
5. Architecture docs are living artifacts — updated during /build, but initial structure must be confirmed here
</quick_reference>

<when_to_use>
**Primary trigger:** Auto-invoked by /design after specs are approved (Step 4.5).

**Independent triggers:**
- After `/respec` modifies specs — architecture may need updating
- Mid-build when implementation reveals architectural changes
- When onboarding someone new who needs to understand the system
- When stakeholders need a visual summary of the design
- User types `/design-arch` directly

**Skip ONLY when ALL three conditions are deterministically true:** (1) `ls specs/*.md | grep -v system.md | wc -l` returns 1, (2) `grep -lE '@depends-on|@blocks' specs/*.md` returns no matches, (3) the single spec is tagged `@trivial`. If any condition is false, run the skill. The third condition is now signaled by the `@trivial` tag — prose claims like "this is just a config change" without the tag are not sufficient.
</when_to_use>

<the_process>

## Step 1: Announce

"I'm using the /design-arch skill to generate architecture documentation from the approved specs."

## Step 2: Read Approved Specs

Read all `@status(approved)` or `@status(implemented)` or `@status(verified)` specs in `specs/`:

```bash
ls specs/*.md
```

Read each spec to understand:
- The system's purpose and scope
- Component relationships and dependencies (`@depends-on`, `@blocks`)
- Technical context (API contracts, data structures, tech stack)
- UI design sections (if present)
- The dependency graph / build order

If `specs/system.md` exists, read it first — it provides the foundation.

## Step 3: Generate Architecture Document

**Dispatch the application-architect role agent.** The agent reads the approved specs, the PO handoff, and `specs/system.md`, then produces the content for `specs/arch.md` — component map, data flow, tech stack rationale, numbered design decisions, and (for full-stack projects) the aggregated Interaction Contract table.

```
Agent tool (subagent_type: application-architect, run_in_background: false):
"You are running Step 4.5 (architecture documentation) for this epic. Read every approved spec, the
PO handoff if present, and specs/system.md. Produce the arch.md content (component map, data flow,
tech stack, design decisions, interaction contract aggregated from per-spec Interaction Maps).
Produce your handoff at:
  specs/handoffs/step-4.5-<epic-slug>-application-architect.html
The orchestrator (this skill) assembles specs/arch.md from your handoff's findings."
```

When the agent returns, copy its `findings` content into `specs/arch.md`. Preserve the agent's structure (component map table, design-decisions list, data-flow narrative).

**Scaling:** For simple features (1-2 specs, no integrations), arch.md is concise — the agent calibrates to scope.

## Step 4: Generate Architecture Diagrams

**Dispatch the devops-architect role agent** for the deployment topology and the application-architect's `<svg>` for the system diagram. The orchestrator's job is to convert the agent's diagram content into `.drawio` files.

```
Agent tool (subagent_type: devops-architect, run_in_background: false):
"You are running Step 4.5 (deployment architecture) for this epic. Produce the deployment topology
(inline <svg> in your handoff is fine — the orchestrator will translate to .drawio), observability
stack, scaling notes, and failure-recovery section. Produce your handoff at:
  specs/handoffs/step-4.5-<epic-slug>-devops-architect.html"
```

`mkdir -p specs/diagrams` and assemble:

- **`specs/diagrams/system-architecture.drawio`** (always) — from application-architect's component map. High-level components, labeled boxes, directional arrows, color coding (blue: existing, green: new/changed), legend.
- **`specs/diagrams/data-flow.drawio`** (when the system has non-trivial request lifecycle) — from application-architect's data flow narrative.
- **`specs/diagrams/deployment.drawio`** (when multiple services / infra) — from devops-architect's topology.

**Each diagram:** focused (one concept), consistent styling, readable at a glance.

## Step 5: Generate Design Overview Page

Generate `specs/overview.html` — a standalone HTML page that presents the entire design in a visual, accessible format for **non-technical stakeholders**.

### Content Requirements

The page must include:
- **Project summary** — what's being built and why, in plain language (no jargon)
- **Feature list** — each spec summarized in 1-2 sentences with status badges (approved/implemented/verified)
- **Architecture diagram** — embedded SVG or visual HTML representation of the system architecture (not a .drawio reference — render it inline so the page is self-contained)
- **UI previews** — if UI-facing specs exist, include simplified visual representations or descriptions of the UI mockups
- **Build order** — visual dependency graph showing which features come first and which can be built in parallel
- **Key design decisions** — the rationale behind major choices, written for a non-technical audience
- **Glossary** — brief definitions of any technical terms used on the page

### Design Requirements

This page represents the project's design quality — treat it accordingly:
- **Self-contained**: inline CSS, no external dependencies, opens directly in any browser with no build step
- **Clean typography**: optimize for scanning and comprehension. Use a readable font stack, clear hierarchy, generous line-height.
- **Responsive**: viewable on laptop and tablet
- **Print-friendly**: stakeholders may want to print or PDF it
- **Visual hierarchy**: use color, spacing, and layout to guide the reader's attention — not a wall of text
- **Professional aesthetic**: apply the frontend-design skill's sensibility. This page may be shared with stakeholders, leadership, or clients. It should look intentionally designed, not like a default HTML page.

### Technical Guidelines

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>[Project Name] — Design Overview</title>
  <style>
    /* All styles inline — no external CSS */
    /* Use CSS custom properties for consistency */
    /* Include @media print styles */
  </style>
</head>
<body>
  <!-- Project summary -->
  <!-- Feature list with status badges -->
  <!-- Architecture diagram (inline SVG or HTML/CSS representation) -->
  <!-- Build order / dependency graph -->
  <!-- Key design decisions -->
  <!-- Glossary -->
</body>
</html>
```

## Step 6: Gate Check

Before presenting to the user, verify all artifacts exist on disk:

```bash
ls specs/arch.md specs/diagrams/system-architecture.drawio specs/overview.html
```

**If any file is missing, STOP.** Go back to the step that should have produced it. Do not present incomplete architecture documentation.

## Step 7: Present and Confirm

Present the architecture documentation to the user via AskUserQuestion:

```
"Architecture documentation is ready:

- **specs/arch.md** — System architecture, component map, data flow, design decisions
- **specs/diagrams/** — Architecture diagrams (open .drawio files in draw.io or diagrams.net)
  - system-architecture.drawio [+ any additional diagrams]
- **specs/overview.html** — Open in your browser for a visual summary of the entire design (shareable with non-technical stakeholders)

Does the architecture capture the system correctly?"
```

**BLOCK until user confirms.**

Options:
- User confirms → Architecture documentation is complete. Exit.
- User requests changes → Revise the affected artifact(s), re-run gate check, re-present.
- User wants additional diagrams → Generate them, re-run gate check, re-present.

## Exit State

/design-arch is complete when:
- `specs/arch.md` exists with complete architecture overview
- `specs/diagrams/system-architecture.drawio` exists (plus additional diagrams as warranted)
- `specs/overview.html` exists and is self-contained / viewable in browser
- User has confirmed all artifacts via AskUserQuestion

**When invoked by /design:** Return control to /design to proceed with Beads Setup.

**When invoked independently:** Tell the user: "Architecture documentation updated. All artifacts in `specs/` are current."

</the_process>

<examples>

<example>
<scenario>Simple feature — 2 specs, no external integrations</scenario>

<why_it_fails>
Without /design-arch, the agent looks at "2 small specs, no external services" and concludes no architecture doc is needed — the specs themselves are documentation. But two specs *with a dependency* already have structure to communicate: which one ships first, how they connect, what the public surface looks like. The stakeholder who funded the work has nothing visual to look at; the next contributor has to read both Gherkin files to understand fit. The skip criteria are narrow on purpose: one trivial spec with no deps. Two specs with a dep is not trivial — concise arch.md and one diagram is the right answer, not zero artifacts.
</why_it_fails>

<correction>
**Step 1:** "I'm using /design-arch to generate architecture documentation."

**Step 2:** Read specs/nearby-breweries.md and specs/brewery-search.md.

**Step 3:** Generate concise arch.md — short overview, 2-row component map, one design decision.

**Step 4:** Generate system-architecture.drawio only (no data-flow or deployment — too simple).

**Step 5:** Generate overview.html with feature list, simple architecture visual, build order.

**Step 6:** Gate check — all files exist.

**Step 7:** Present to user, confirm.
</correction>
</example>

<example>
<scenario>Greenfield app — system spec + 5 feature specs with dependencies</scenario>

<why_it_fails>
Without /design-arch, the agent generates one diagram (system architecture) and considers the job done. But greenfield with 5 dependent specs has a request lifecycle worth tracing, a deployment topology worth drawing, and a design-decisions section worth writing — because future contributors will hit "why did we choose JWT over sessions" within a week. The agent that says "one diagram is enough" is the same agent that, six months later, can't reconstruct why the data model has both `user_id` and `account_id`. Architecture docs are insurance against future ambiguity, and the premium is paid at the moment of design, not after the confusion sets in.
</why_it_fails>

<correction>
**Step 1:** "I'm using /design-arch to generate architecture documentation."

**Step 2:** Read specs/system.md first, then all 5 feature specs. Map the full dependency graph.

**Step 3:** Generate comprehensive arch.md — full overview, component map with all 5 features, detailed data flow section, tech stack from system spec, 4-5 design decisions with alternatives considered.

**Step 4:** Generate all three diagrams:
- system-architecture.drawio — all components with dependency arrows
- data-flow.drawio — request lifecycle from client through API to database
- deployment.drawio — services, database, external integrations

**Step 5:** Generate rich overview.html — project summary, all features with status badges, inline architecture diagram, build order showing parallel lanes, design decisions in plain language, glossary of domain terms.

**Step 6:** Gate check — all files exist.

**Step 7:** Present to user, confirm.
</correction>
</example>

<example>
<scenario>Independent invocation — architecture update after /respec</scenario>

<why_it_fails>
Without /design-arch's "update, don't skip" rule, the agent looks at the existing arch.md and decides the old document is "good enough" — the spec change is small, why rewrite the architecture? But the respec'd spec might have changed the auth flow, the data model, or a service boundary; the architecture document is now describing a system that no longer exists. Worse, the overview.html still shows the old build order to stakeholders. Arch docs that aren't kept in sync silently become wrong, and "wrong documentation" is worse than no documentation — readers trust it. The respec touched the system; the architecture description has to follow.
</why_it_fails>

<correction>
**Step 1:** "I'm using /design-arch to update architecture documentation after spec changes."

**Step 2:** Read all current specs. Compare against existing arch.md to identify what changed.

**Steps 3-5:** Regenerate all three artifacts with updated information. Preserve design decisions that haven't changed; update or add new ones for the respec'd features.

**Step 6:** Gate check.

**Step 7:** "Architecture documentation updated. Changes: [summary of what changed in arch.md and diagrams]."
</correction>
</example>

</examples>

<critical_rules>
## Rules That Have No Exceptions

1. **All three artifact types must be produced** → arch.md, at least one .drawio diagram, and overview.html. No partial output.
2. **Gate check before presenting** → `ls` to verify files exist on disk. Missing file = go back and generate it.
3. **User confirmation via AskUserQuestion** → Do not exit without user confirmation. BLOCK until confirmed.
4. **overview.html is self-contained** → Inline CSS, no external dependencies. Must open in any browser with no build step.
5. **Architecture diagrams use draw.io format** → .drawio files that can be opened in draw.io or diagrams.net. Not Mermaid, not SVG, not ASCII art. draw.io XML specifically.
6. **Update, don't skip, when artifacts already exist** → If `specs/arch.md` or diagrams already exist from a previous /design-arch run, UPDATE them — preserve unchanged sections, add/modify sections for new or changed specs. Existing artifacts are the starting point, not a reason to skip.

## Skip Criteria (Precise Definition)

Skip /design-arch ONLY when ALL three deterministic checks pass:

```bash
# (1) Exactly one spec entry (excluding system.md)
[ "$(ls specs/*.md 2>/dev/null | grep -v 'system.md' | wc -l)" -eq 1 ]

# (2) No @depends-on or @blocks relationships anywhere
! grep -qE '@depends-on|@blocks' specs/*.md

# (3) The single spec is tagged @trivial
grep -q '@trivial' "$(ls specs/*.md | grep -v system.md)"
```

All three must pass. If any returns false, /design-arch runs. "Two small specs" is not trivial. "A bug fix with a dependency" is not trivial. The qualitative condition is now a `@trivial` tag set during /design — prose claims without that tag are not sufficient to skip.

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "The architecture is obvious from the specs" → Specs define behavior. Architecture defines structure. Different artifacts for different audiences.
- "The overview page is overkill" → It takes minutes to generate and saves hours of stakeholder explanation.
- "I'll do the architecture docs during build" → Architecture is a design artifact. After implementation it's documentation, not design.
- "One diagram is enough" → One diagram is the minimum. If the system has non-trivial data flow or deployment, add diagrams.
- "The user didn't ask for architecture docs" → /design auto-invokes this skill. It's part of the design process, not an optional extra.
- "I'll just describe the architecture in text" → Text is arch.md. Diagrams are diagrams. The overview page is visual. All three serve different purposes.
- "Mermaid/ASCII diagrams are better than .drawio" → No. The format is .drawio, not Mermaid, not SVG, not ASCII. draw.io is the standard because the user opens and edits diagrams in draw.io/diagrams.net. Mermaid is not a substitute. Diffability is not the goal — visual editability is.
- "The existing arch.md would be overwritten" → Correct — that's the point. Architecture docs are living artifacts. Update them: preserve unchanged sections, modify what changed. An existing arch.md is the starting point for the update, not a reason to skip.
- "No non-technical stakeholders need this" → You don't know who will read it. The overview page costs minutes to produce and may save hours later. Generate it. If nobody reads it, no harm done. If someone needs it and it doesn't exist, that's a problem.
- "These are just bug fixes / small changes" → Check the skip criteria above. If the work has dependencies, multiple specs, or touches architecture, it's not trivial. Generate concise artifacts — but generate them.
</critical_rules>

<verification_checklist>
Before claiming /design-arch is complete:

- [ ] All approved specs read and understood
- [ ] `specs/arch.md` generated with component map, data flow, tech stack, design decisions
- [ ] `specs/diagrams/system-architecture.drawio` generated (at minimum)
- [ ] Additional diagrams generated where warranted (data-flow.drawio, deployment.drawio)
- [ ] `specs/overview.html` generated, self-contained, viewable in browser
- [ ] Gate check passed: `ls specs/arch.md specs/diagrams/system-architecture.drawio specs/overview.html`
- [ ] User confirmed architecture documentation via AskUserQuestion

**Cannot check all boxes? Do not claim /design-arch is complete.**
</verification_checklist>

<integration>
**This skill calls:**

| Skill / Tool | When |
|---|---|
| AskUserQuestion | Presenting architecture docs for user confirmation |
| frontend-design | Aesthetic sensibility for overview.html design |

**This skill produces:**
- `specs/arch.md` — architecture document
- `specs/diagrams/*.drawio` — architecture diagrams
- `specs/overview.html` — visual design overview page

**This skill is called by:**
- `/design` (Step 4.5 — auto-invoked after spec approval)
- User typing `/design-arch` directly
- After `/respec` when architecture needs updating
- Mid-build when implementation reveals architectural changes

**This skill consumes:**
- `specs/*.md` files with `@status(approved)` or later
- `specs/system.md` (if it exists — provides foundation context)
- `specs/mockups/` (if UI mockups exist — referenced in overview.html)
</integration>
