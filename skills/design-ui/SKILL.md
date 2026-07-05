---
name: design-ui
description: Use after decomposition to generate UI/UX design for user-facing specs — runs PRODUCT.md/DESIGN.md setup, Impeccable craft pipeline, frontend-design aesthetics, component mockups, and quality gates. Auto-invoked by /design, also callable independently after /respec.
---

<skill_overview>
UI/UX design skill that produces component mockups, design system files, and `## UI Design` sections for Gherkin specs. Separates app-level design decisions (run once) from per-screen work (run per spec). Produces `specs/mockups/` artifacts that /build consumes as implementation starting points.

**Role-agent orchestration (experimental branch).** This skill is now the **procedure manual** the `uiux-designer` role agent (`agents/uiux-designer.md`) reads when dispatched by `/design` Step 2.85. The primary invocation path is `Agent(subagent_type: uiux-designer, ...)`, not `Skill(design-ui)` directly. The agent reads this document, invokes the `/impeccable` gates as Skill calls, and produces an HTML handoff. When invoked as a standalone skill (e.g., after `/respec`), this skill behaves identically — the agent's prompt references the same procedure. The handoff path is `specs/handoffs/step-2.85-<slug>-uiux-designer.html`.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: PRODUCT.md + DESIGN.md must exist before any design work. No exceptions.
- **RIGID**: Every UI-facing spec gets a component mockup. No mockup = spec cannot be approved.
- **RIGID**: Every quality gate (`critique`, `audit`, `harden`, `clarify`, `adapt`) is an actual Skill tool invocation whose output appears in the transcript. Reasoning about what the skill would say is NOT a substitute — a mental run is a skipped gate (`docs/incidents.md#mental-gates-2026-05-21`), and `hooks/claim-vs-call-audit.sh` cross-checks the gates claimed in `## UI Design` sections against the Skill calls actually made.
- **RIGID**: The gate count is a formula, not a negotiation: **5 gates × N mockups**. Skipping any on the grounds of volume is the failure this skill exists to prevent.
- **FLEXIBLE**: Batching strategy for multi-screen apps — group by feature cluster, not rigid per-spec.
- **FLEXIBLE**: Visual direction probes can be app-wide or per-cluster depending on design diversity.
- **FLEXIBLE**: Ordering across mockups. Gates on different mockups are independent — fan them out in parallel where the context allows. Within a single mockup, run C1→C5 in order.
</rigidity_level>

<quick_reference>
## Usage

```
/design-ui                    # Run from /design after decomposition, or independently
/design-ui --specs auth,onboarding   # Run for specific specs only (after /respec)
```

## Flow

```
/design-ui
  -> Phase 1: Design System Setup (once per project)
     -> Gate: PRODUCT.md + DESIGN.md exist? If not, run /impeccable teach
     -> Register classification (brand vs product)
     -> App-wide visual direction probes (2-3 directions, user chooses)
     -> Category-reflex check
     -> Frontend-design: lock in typography, color, motion, spatial composition
  -> Phase 2: Per-Screen Design (per UI-facing spec)
     -> Group specs into feature clusters
     -> For each cluster: shape interview → mockup → five quality gates → enhance if needed
     -> Present cluster mockups to user for confirmation
  -> Phase 3: Incorporate into Specs
     -> Add ## UI Design section to each spec
     -> Verify all mockups exist on disk
     -> Exit: all UI-facing specs have mockups and UI Design sections
```

## Hard Constraints

1. PRODUCT.md + DESIGN.md must exist before any mockup work
2. Every UI-facing spec gets a mockup in specs/mockups/
3. All five quality gates (critique, audit, harden, clarify, adapt) on every mockup — no reduced mode
4. User confirms visual direction before mockup generation
5. No mockup = spec cannot proceed to @status(approved)
6. Enhancement commands applied when critique finds blandness (brand register: proactively)
</quick_reference>

<when_to_use>
**Use /design-ui when:**

- /design has a decomposition map with UI-facing entries (auto-invoked)
- /respec modified a UI-facing spec and mockups need updating
- Independently when existing specs need UI design retroactively

**Don't use /design-ui for:**
- Backend-only specs, CLI tools, API-only work, infra
- Work with no user-facing visual component
- Specs that already have mockups and `## UI Design` sections (unless redesigning)

**UI-facing detection — a spec is UI-facing if it describes:**
- Screens, pages, views, tabs
- Buttons, forms, interactive elements
- Navigation, layouts, visual components
- User-facing interactions (tapping, swiping, scrolling)
- Data visualization (charts, progress indicators)
</when_to_use>

<the_process>

## Phase 1: Design System Setup (Once Per Project)

### Step 1.1: Gate — PRODUCT.md + DESIGN.md

**BLOCKING REQUIREMENT**: Verify these files exist in the project root:

```bash
ls PRODUCT.md DESIGN.md 2>/dev/null
```

**If neither exists** (greenfield), run `/impeccable teach` first. This runs a strategic interview to create:
- **PRODUCT.md**: register (brand vs product), target users, brand personality traits, anti-references (what NOT to look like), design principles, competitive landscape
- **DESIGN.md**: color tokens (OKLCH), typography scale, spacing system, elevation levels, component patterns, do's and don'ts

**If code exists but docs don't** (retroactive design), run `/impeccable document` instead. This generates DESIGN.md from existing project code — extracting the implicit design system into explicit tokens.

**If files exist**, read them to load the design context.

**Why this is mandatory:** Every Impeccable command reads PRODUCT.md and DESIGN.md. Without them, all design output defaults to "generic modern SaaS." These files give the design its distinctive character.

### Step 1.2: Register Classification

Read PRODUCT.md to determine the project's **register**:

| Register | Meaning | Design Intensity |
|----------|---------|-----------------|
| **Brand** | Design IS the product (consumer apps, marketing sites, creative tools) | Maximum — every pixel matters. `/bolder`, `/delight`, `/animate` expected. |
| **Product** | Design SERVES the product (admin dashboards, dev tools, B2B) | Focused — clarity over flair. Still polished, but restraint is a feature. |

### Step 1.3: App-Wide Visual Direction

Generate 2-3 **visual direction probes** — distinct aesthetic approaches for the overall application. Present via AskUserQuestion — or, if AskUserQuestion is not in your toolset (you are running as a dispatched uiux-designer/game-ui-designer agent), write the probes as a blocking question in your handoff's `open-questions` per `docs/agent-protocol.md` §2 and return for the orchestrator to relay:

```
"Here are 3 visual directions for [app name]:

Direction A — [name]: [1-sentence description of the aesthetic approach]
Direction B — [name]: [1-sentence description]
Direction C — [name]: [1-sentence description]

Which direction resonates? Or should I blend elements from multiple?"
```

**Block until user chooses.** The chosen direction is the **north-star** for all mockups.

**When to re-probe per cluster:** Only if a feature cluster has a fundamentally different UX context (e.g., onboarding wizard vs. data-heavy dashboard). Most screens within an app share a single direction.

### Step 1.4: Category-Reflex Check

Test whether the chosen direction triggers "AI slop" signals:

First-order reflexes to avoid:
- Gradient cards with rounded corners (the "Stripe clone" reflex)
- Purple-to-blue hero sections
- Card grids with identical spacing
- Generic modern SaaS aesthetic
- Obvious Tailwind/framework defaults without customization

Second-order reflexes (trying too hard to be different):
- Random brutalism for a finance app
- Neon cyberpunk for a healthcare tool
- Aesthetic that fights the content

If triggered, adjust the direction before proceeding.

### Step 1.5: Frontend-Design Aesthetics

Apply the `frontend-design` skill to lock in the visual system:
- **Tone**: Bold aesthetic consistent with the chosen visual direction
- **Typography**: Prefer distinctive, characterful choices from DESIGN.md tokens (or establish new ones). Generic system fonts (Inter, Roboto, Arial) are a weak default, not a ban — using one needs a documented reason (e.g. the product register or platform demands it).
- **Color & Theme**: OKLCH-based palette from DESIGN.md tokens. Cohesive aesthetic via CSS variables.
- **Motion**: CSS-only or Motion library animations. Functional motion for product register; expressive motion for brand register.
- **Spatial Composition**: Unexpected layouts, asymmetry, generous negative space or controlled density
- **Backgrounds & Visual Details**: Atmosphere and depth appropriate to the register

These decisions apply to ALL mockups. They are not repeated per screen.

## Phase 2: Per-Screen Design

### Step 2.1: Identify UI-Facing Specs

Scan the decomposition map (or specs/ directory if running independently). A spec is UI-facing if it describes screens, buttons, forms, navigation, or user-facing interactions.

List all UI-facing specs with their feature area.

### Step 2.2: Group into Feature Clusters

Group related specs to batch the shape interview. Screens that share UX context get shaped together:

```
Example clusters for a fitness app:
  Cluster 1 — Onboarding: auth, onboarding, role-selection
  Cluster 2 — Workout Flow: workout-management, workout-tracking, exercise-library
  Cluster 3 — Nutrition: nutrition-tracking, meal-plans
  Cluster 4 — Progress: body-metrics, progress-dashboard
  Cluster 5 — Social: client-trainer-relationship, messaging, notifications
  Cluster 6 — Settings: user-profiles, subscriptions-payments
```

Clustering reduces shape interviews from N (one per spec) to M clusters (typically 3-6).

### Step 2.3: Shape + Mockup + Quality Gate (Per Cluster)

For each cluster:

**A. Shape Interview** (`/impeccable shape [cluster-name]`)

Run a single shape interview covering all screens in the cluster:
- Feature summary and primary user actions per screen
- User state of mind when navigating this section
- Content ranges (min/max data, empty states, overflow)
- Layout strategy and visual hierarchy
- Key states (default, empty, loading, error, success)
- Interaction model (tap, swipe, scroll, feedback, flow)
- Content requirements (copy, labels, microcopy, empty states)
- Anti-goals (what this cluster should NOT look like)

The shape interview supplements (not replaces) the Socratic questioning from /design Step 2.

**B. Component Mockups** (per spec in the cluster)

**BLOCKING REQUIREMENT**: Every UI-facing spec MUST have a mockup. No mockup = spec cannot be approved.

The mockup format depends on the project's framework:

**Option 1: React/React Native/Vue/Svelte — Component + Storybook story (preferred)**

```
specs/mockups/<feature-slug>/
  <ComponentName>.tsx       # Component with mock data, styled
  <ComponentName>.stories.tsx  # Storybook stories for key states
  README.md                 # Design decisions, references shape brief
```

**Option 2: Non-framework — Standalone HTML/CSS**

```
specs/mockups/<feature-slug>.html   # Self-contained, opens in browser
```

Each mockup includes:
- Semantic structure with the actual layout
- Styled with the project's approach using frontend-design aesthetic decisions
- Mock/hardcoded data showing realistic content
- Key states: default, empty, loading, error, edge cases
- Mock fidelity inventory (what's captured vs. deferred to build)

**Gate check** after each mockup:
```bash
ls specs/mockups/<feature-slug>/ 2>/dev/null || ls specs/mockups/<feature-slug>.html 2>/dev/null
```
If neither exists, you have not completed this step.

**C. Quality Gates** (per mockup)

Run these five checks per mockup — each is a real Skill invocation per the RIGID rule above. Within one mockup run C1→C5 in order (each catches different problems); across mockups the gates are independent and may be fanned out in parallel.

**C1. Critique** (`/impeccable critique`) — Design quality
- Design review: visual hierarchy, readability, DESIGN.md consistency, PRODUCT.md alignment
- Anti-pattern detection: the 27-rule deterministic AI-slop scan (lives inside critique — there is no separate `detect` command)
- Nielsen heuristic scoring
- Persona test: Would target users from PRODUCT.md be satisfied?

Fix design issues BEFORE proceeding.

**C2. Audit** (`/impeccable audit`) — Technical quality
- Accessibility: contrast ratios, focus indicators, screen reader compatibility, touch targets
- Performance: image sizes, animation cost, render complexity
- Responsive behavior: breakpoints, overflow, touch vs. pointer interactions

Fix technical issues. Accessibility violations are **CRITICAL** — do not defer.

**C3. Harden** (`/impeccable harden`) — Production readiness
- Error states: what does the user see when the API fails? When data is malformed?
- Empty states: what does a brand-new user with zero data see?
- Edge cases: extremely long text, zero items, maximum items, slow connections
- i18n readiness: hardcoded strings, date/number formatting, RTL layout considerations

Add missing states to the mockup. An error-less mockup is an incomplete mockup.

**C4. Clarify** (`/impeccable clarify`) — UX copy
- Labels: are button labels action-oriented? ("Save changes" not "Submit")
- Error messages: are they helpful and specific? ("Email is already registered" not "Error 409")
- Empty states: do they guide the user toward action? ("Add your first workout" not "No data")
- Microcopy: tooltips, placeholders, confirmation dialogs — clear and concise?

Fix copy issues. Poor microcopy is a UX bug.

**C5. Adapt** (`/impeccable adapt`) — Responsive design
- Mobile (375px): does the layout collapse gracefully? Touch targets large enough?
- Tablet (768px): is the layout using the space, or just stretched mobile?
- Desktop (1440px+): is there awkward whitespace or overly wide content?

For mobile-first apps (React Native), this primarily checks tablet/landscape behavior.

**D. Enhancement Pass** (if needed)

If quality gates found the design is too safe, bland, aggressive, or missing personality, apply targeted enhancement commands:

| Weakness | Command | Register |
|----------|---------|----------|
| Bland, plays it safe | `/impeccable bolder` | Brand (proactive) / Product (if flagged) |
| Needs maximum visual impact | `/impeccable overdrive` | Brand only — pushes past bolder into technically extraordinary |
| Color is flat/generic | `/impeccable colorize` | Both |
| Typography is forgettable | `/impeccable typeset` | Both |
| No personality or delight | `/impeccable delight` | Brand (proactive) / Product (if flagged) |
| Static, feels dead | `/impeccable animate` | Both |
| Spacing/rhythm is off | `/impeccable layout` | Both |
| Too aggressive/loud | `/impeccable quieter` | Both — when bolder overshot or design is harsh |
| Bloated, too complex | `/impeccable distill` | Product (proactive) / Brand (if flagged) |

**Register-specific defaults:**
- **Brand register**: run `/impeccable bolder` and `/impeccable delight` proactively. Consider `/impeccable overdrive` for hero screens.
- **Product register**: run `/impeccable distill` proactively. Clarity over flair.

After enhancement, re-run critique to verify the fix didn't introduce new issues. Maximum 2 enhancement-critique cycles.

**E. Onboard** (`/impeccable onboard`) — First-run screens only

For specs that involve onboarding, welcome flows, empty states, or first-time user activation:
- Design the first-run experience: what does a brand-new user see?
- Empty state designs: not just "no data" but guidance toward first action
- Progressive disclosure: what do they see on day 1 vs. day 30?
- Activation sequence: what's the shortest path to the "aha" moment?

Run this AFTER the quality gates for onboarding-related specs. It adds onboarding-specific design decisions that shape and critique don't cover.

**Skip when:** Spec is NOT tagged `@onboarding`. Deterministic check (when invoked standalone after specs exist — on the primary /design path spec files don't exist yet at Step 2.85, so classify from the decomposition map and add the tag when specs are generated): `grep -q '@onboarding' specs/<slug>.md`. If a spec is onboarding-related but lacks the tag, add the tag — do not skip by inference.

### Step 2.4: Present Cluster and Confirm

After all mockups in a cluster are built and quality-checked, present them to the user via AskUserQuestion — or, without that tool (dispatched-agent context), as a blocking `open-questions` entry per `docs/agent-protocol.md` §2:

```
"Here are the UI designs for [cluster name] ([N] screens):

**Design Context**: [brand/product] register — [personality from PRODUCT.md]
**Visual Direction**: [chosen direction name]

Screens:
1. [feature-slug] — [primary user action]. Mockup: specs/mockups/[slug]/
2. [feature-slug] — [primary user action]. Mockup: specs/mockups/[slug]/

Quality: All mockups passed the five quality gates.

View mockups:
- Storybook: `npm run storybook`
- HTML: open files in specs/mockups/ in your browser

Does this cluster work, or should I adjust any screens?"
```

**Block until user confirms.** Then proceed to next cluster.

## Phase 3: Finalize and Incorporate

After all clusters are confirmed:

### Step 3.0: Extract Design System (`/impeccable extract`)

After all mockups are built, run `/impeccable extract` to pull reusable tokens and component patterns from the mockups into DESIGN.md:
- Color tokens used across mockups → formalized in DESIGN.md
- Typography patterns → added to type scale
- Spacing values → normalized to the spacing system
- Repeated component patterns → documented as component recipes

This ensures the design system reflects what was ACTUALLY designed, not just what was planned in Phase 1.

**Skip when:** an `EXTRACT GATE: no-new-tokens` entry (written via `bd comments add`) was logged on the active epic in this session AND DESIGN.md was created via `/impeccable teach` earlier in the same session. Deterministic check (when invoked standalone after the beads epic exists — on the primary /design path beads setup happens later, so this check runs then, not at Step 2.85): `bd comments <epic-id> | grep -q 'EXTRACT GATE: no-new-tokens'`. The entry must be written intentionally — "no new tokens emerged" by claim alone is not sufficient.

### Step 3.1: Add UI Design Sections

For each UI-facing spec, add a `## UI Design` section with:
- **Register**: brand or product (from PRODUCT.md)
- **Design direction**: chosen visual direction probe name and description
- **Shape brief summary**: layout strategy, key states, interaction model, anti-goals
- **Visual aesthetics**: typography (specific fonts), color (OKLCH tokens), motion, spatial composition
- **Mockup reference**: `Mockup: specs/mockups/<feature-slug>/` or `.html`
- **Mock fidelity inventory**: what's captured vs. deferred to build
- **Quality gates run**: explicit list of the Skill invocations made for this spec, e.g.
  ```
  - Skill(impeccable, "critique <slug>") — findings: ...
  - Skill(impeccable, "audit <slug>") — findings: ...
  - Skill(impeccable, "harden <slug>") — findings: ...
  - Skill(impeccable, "clarify <slug>") — findings: ...
  - Skill(impeccable, "adapt <slug>") — findings: ...
  ```
  Every UI-facing spec must list all five (plus `onboard` if applicable). If a gate was skipped, the spec is not approvable — go run the gate (per the RIGID rule; `claim-vs-call-audit.sh` cross-checks this list against the session's actual Skill calls).
- **Enhancement commands applied**: which `/impeccable` commands were used and why (each a Skill invocation)
- **Content requirements**: UX copy decisions, microcopy, empty state messages

### Step 3.2: Final Verification

```bash
# Verify every UI-facing spec has a mockup
for spec in [list of UI-facing specs]; do
  ls specs/mockups/${spec}/ 2>/dev/null || ls specs/mockups/${spec}.html 2>/dev/null || echo "MISSING: ${spec}"
done
```

Any missing mockup = STOP. Go back and create it.

### Exit State

/design-ui is complete when:
- PRODUCT.md and DESIGN.md exist
- All UI-facing specs have mockups in `specs/mockups/`
- All mockups passed all five quality gates (critique, audit, harden, clarify, adapt)
- All UI-facing specs have `## UI Design` sections
- User confirmed all clusters

**Tell the user:** "UI/UX design complete. [N] mockups created across [M] clusters. View them in specs/mockups/. Returning to /design."

</the_process>

<examples>

<example>
<scenario>Greenfield fitness app — 14 UI-facing specs</scenario>

<why_it_fails>
Without /design-ui, the agent either (a) skips UI design entirely and ships 14 prose-only specs that /build implements as default Tailwind cards, or (b) runs /impeccable shape per spec without PRODUCT.md, DESIGN.md, visual probes, or quality gates — producing 14 individually-bland mockups with no shared system. Either way, the user sees the implementation and asks "why does this look like every other SaaS app?" Then 14 specs have to be redesigned. The fix isn't "design harder next time" — it's running the full pipeline once at the front: probes → frontend-design lockdown → per-cluster shape → mockups → the five quality gates → extract. 5 gates × N mockups isn't optional; it's the difference between distinctive and forgettable.
</why_it_fails>

<correction>
**Phase 1 — Design System (once):**
- Gate: No PRODUCT.md or DESIGN.md → run `/impeccable teach`
- Register: Brand (consumer fitness app)
- Visual direction: Present 3 probes → user picks "Direction B — Athletic Minimalism"
- Category-reflex check: PASS (not triggering generic fitness app patterns)
- Frontend-design: Lock in Geist font, OKLCH green accent palette, spring motion

**Phase 2 — Per-Screen (6 clusters):**
- Cluster 1 (Onboarding): Shape 3 screens together → 3 mockups → five gates each → PASS
- Cluster 2 (Workout Flow): Shape 3 screens → 3 mockups → critique found workout-tracking bland → `/bolder` → re-critique → PASS
- Cluster 3 (Nutrition): Shape 2 screens → 2 mockups → five gates each → PASS
- Cluster 4 (Progress): Shape 2 screens → 2 mockups → five gates each → PASS
- Cluster 5 (Social): Shape 3 screens → 3 mockups → five gates each → PASS
- Cluster 6 (Settings): Shape 2 screens → 1 mockup (settings is one screen with sections) → five gates → PASS
Present each cluster, user confirms before next.

**Phase 3 — Incorporate:**
- Add `## UI Design` to all 14 specs
- Verify: 14/14 mockups exist
- Exit: "UI/UX design complete. 14 mockups across 6 clusters."
</correction>
</example>

<example>
<scenario>Single new screen added via /respec</scenario>

<why_it_fails>
Without /design-ui, the agent figures: "one screen, design system already exists, I'll just write the spec with a prose description of the layout." No mockup, no quality gates, no extract pass. /build then implements the screen from prose, which never captures spacing, hierarchy, or interaction states accurately. The new screen ships looking inconsistent with the rest of the app — different padding, different button treatment, different empty-state copy style — because every per-screen design decision was made individually instead of derived from the shared system. Even "small" UI work routes through the full pipeline; the shortcut is that Phase 1 is already done, not that Phase 2 is skipped.
</why_it_fails>

<correction>
**Phase 1 — Design System:**
- Gate: PRODUCT.md and DESIGN.md already exist → read them
- Register: Already classified (product register)
- Visual direction: Already established → skip probes (unless the new screen diverges significantly)

**Phase 2 — Per-Screen:**
- Single spec, single cluster
- Shape interview for the new screen
- Generate mockup
- Five quality gates → PASS

**Phase 3 — Incorporate:**
- Add `## UI Design` to the new/modified spec
- Verify mockup exists
- Exit: "1 new mockup created."
</correction>
</example>

</examples>

<critical_rules>
## Rules That Have No Exceptions

1. **PRODUCT.md + DESIGN.md before any mockup** → If missing, run `/impeccable teach`. No design without design system.
2. **Every UI-facing spec gets a mockup** → No mockup = spec cannot be approved. This is a blocking requirement.
3. **Quality gates on every mockup** → All five (critique, audit, harden, clarify, adapt). No reduced mode regardless of timeline.
4. **User confirms visual direction before mockups** → Don't generate mockups without direction consensus.
5. **User confirms each cluster before proceeding** → Block until confirmed.
6. **App-level decisions are made once** → PRODUCT.md, DESIGN.md, register, visual direction, frontend-design aesthetics. Not repeated per screen.
7. **Enhancement for brand register is proactive** → Don't wait for critique to flag blandness. Run `/impeccable bolder` by default.

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "The UI is simple enough to skip the mockup / I'll describe it in prose" → Simple UIs still get mockups; users cannot review a layout from prose (rule 2).
- "PRODUCT.md/DESIGN.md aren't needed for this project" → Every project with UI needs them. 5 minutes of `/teach` prevents hours of bland redesign (rule 1).
- "The user wants to move fast, I'll skip the quality gates" → Skipping gates now means redesigning later. Every step exists because its absence caused a documented failure (`docs/incidents.md#trainr`).
- "I authored the mockups with tokens directly and ran the principles mentally / applied them inline / batched them" → The documented failure mode this skill exists to prevent (`docs/incidents.md#mental-gates-2026-05-21`). A gate is a real Skill invocation per the RIGID rule; a caveat in the spec is not a substitute for running it. If 5 × N calls is the right number, make 5 × N calls.
- "I'll do the design system setup per-screen" → No. PRODUCT.md, DESIGN.md, register, visual direction, and frontend-design aesthetics are app-level decisions (rule 6). Per-screen setup wastes time and produces inconsistent designs.
</critical_rules>

<verification_checklist>
Before claiming /design-ui is complete:

**Design System (Phase 1):**
- [ ] PRODUCT.md exists (created via `/impeccable teach` if missing)
- [ ] DESIGN.md exists (created via `/impeccable teach` if missing)
- [ ] Register classified (brand or product)
- [ ] Visual direction chosen by user from 2-3 probes
- [ ] Category-reflex check passed
- [ ] Frontend-design aesthetics locked in (typography, color, motion, spatial)

**Per-Screen (Phase 2):**
- [ ] All UI-facing specs identified from decomposition map
- [ ] Specs grouped into feature clusters
- [ ] Shape interview completed per cluster (`Skill(impeccable, "shape ...")` invocation in transcript)
- [ ] Component mockup EXISTS ON DISK for every UI-facing spec (`ls specs/mockups/`)
- [ ] Mock fidelity inventory created per mockup
- [ ] All five gates (critique, audit, harden, clarify, adapt) invoked per mockup, per the RIGID rule
- [ ] Onboard gate invoked via Skill tool for onboarding specs — or N/A
- [ ] Enhancement commands applied where quality gates found weaknesses (each one a Skill invocation, not a mental pass)
- [ ] User confirmed each cluster

**Incorporation (Phase 3):**
- [ ] `/impeccable extract` run to formalize design tokens in DESIGN.md — or skipped (no new tokens)
- [ ] `## UI Design` section added to every UI-facing spec, listing each gate Skill invocation that was made (gate name + slug, one line per call)
- [ ] Final verification: all mockups exist on disk

**Cannot check all boxes truthfully? Do not claim /design-ui is complete.**
</verification_checklist>

<integration>
**This skill calls:**

| Skill / Tool | When | Phase |
|---|---|---|
| impeccable (teach) | Create PRODUCT.md + DESIGN.md from scratch (greenfield) | 1 |
| impeccable (document) | Generate DESIGN.md from existing code (retroactive) | 1 |
| impeccable (shape) | Discovery interview per feature cluster | 2 |
| impeccable (critique) | Design quality gate per mockup | 2 |
| impeccable (audit) | Technical quality: a11y, performance, responsive | 2 |
| impeccable (harden) | Error states, empty states, edge cases, i18n | 2 |
| impeccable (clarify) | UX copy, labels, error messages, microcopy | 2 |
| impeccable (adapt) | Responsive behavior across devices | 2 |
| impeccable (onboard) | First-run flows, empty states, activation (onboarding specs only) | 2 |
| impeccable (bolder) | Amplify bland designs (brand: proactive) | 2 |
| impeccable (overdrive) | Maximum visual impact (brand register, hero screens) | 2 |
| impeccable (colorize) | Strategic color for flat/monochrome designs | 2 |
| impeccable (typeset) | Typography hierarchy, fonts, readability | 2 |
| impeccable (delight) | Personality, micro-interactions, charm | 2 |
| impeccable (animate) | Purposeful motion design | 2 |
| impeccable (layout) | Spacing, rhythm, visual hierarchy | 2 |
| impeccable (quieter) | Tone down aggressive/loud designs | 2 |
| impeccable (distill) | Strip complexity, simplify (product: proactive) | 2 |
| impeccable (extract) | Pull tokens/components into DESIGN.md | 3 |
| impeccable (live) | Visual variant iteration during user feedback | 2 (edge case) |
| frontend-design | Visual aesthetics: typography, color, motion, spatial | 1 |
| AskUserQuestion | Visual direction probes + cluster confirmation | 1, 2 |

**This skill produces (consumed by /build):**
- `PRODUCT.md` — strategic context (if created)
- `DESIGN.md` — visual system (if created)
- `specs/mockups/` — component mockups for all UI-facing specs
- `## UI Design` sections in spec files

**This skill is triggered by:**
- /design (auto-invoked after decomposition for UI-facing work)
- /respec (when a UI-facing spec is modified)
- User typing `/design-ui` independently
</integration>

<edge_cases>

## No UI-facing specs in decomposition
"No UI-facing specs found in the decomposition map. /design-ui is not needed." STOP.

## PRODUCT.md exists but DESIGN.md doesn't (or vice versa)
Run `/impeccable teach` to create the missing file. Do not proceed with only one.

## Running independently (not from /design)
Read all specs in `specs/`. Identify which are UI-facing. Proceed with Phase 1 if PRODUCT.md/DESIGN.md are missing, otherwise skip to Phase 2.

## Spec already has mockup and UI Design section
Skip that spec unless the user explicitly asked to redesign it or /respec modified the spec's core behavior.

## User rejects a cluster's mockups
Ask what's wrong. For targeted adjustments, use `/impeccable live` to iterate visually in the browser — pick elements and generate design alternatives in real-time. For broader changes, re-run shape interview for that cluster with the feedback, regenerate mockups, re-run quality gates. Maximum 3 revision cycles before escalating with full critique findings.

## Too many screens for one session
If the decomposition has 20+ UI-facing specs, inform the user and suggest prioritizing clusters. Design the highest-priority clusters first, defer the rest. But do NOT skip any — defer means "next session," not "never."

</edge_cases>
