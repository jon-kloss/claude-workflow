---
name: design-ui
description: Use after decomposition to generate UI/UX design for user-facing specs — runs PRODUCT.md/DESIGN.md setup, Impeccable craft pipeline, frontend-design aesthetics, component mockups, and quality gates. Auto-invoked by /design, also callable independently after /respec.
---

<skill_overview>
UI/UX design skill that produces component mockups, design system files, and `## UI Design` sections for Gherkin specs. Separates app-level design decisions (run once) from per-screen work (run per spec). Produces `specs/mockups/` artifacts that /build consumes as implementation starting points.
</skill_overview>

<rigidity_level>
MIXED:
- **RIGID**: PRODUCT.md + DESIGN.md must exist before any design work. No exceptions.
- **RIGID**: Every UI-facing spec gets a component mockup. No mockup = spec cannot be approved.
- **RIGID**: Every quality gate (`critique`, `audit`, `harden`, `clarify`, `adapt`) is an actual Skill tool invocation. Reasoning about what the skill would say is NOT a substitute. No "I ran it mentally," no "I applied the principles inline," no "I authored the mockup with tokens so the gates are unnecessary." If you did not type `Skill(impeccable, "<gate> <slug>")`, the gate did not run.
- **RIGID**: Sub-skill counts are not negotiable. 4 specs × (critique+audit+harden+clarify+adapt) = 20 Skill calls minimum. Skipping any of them on the grounds of volume is the failure this skill exists to prevent.
- **FLEXIBLE**: Batching strategy for multi-screen apps — group by feature cluster, not rigid per-spec.
- **FLEXIBLE**: Visual direction probes can be app-wide or per-cluster depending on design diversity.
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
     -> For each cluster: shape interview → mockup → critique + detect → enhance if needed
     -> Present cluster mockups to user for confirmation
  -> Phase 3: Incorporate into Specs
     -> Add ## UI Design section to each spec
     -> Verify all mockups exist on disk
     -> Exit: all UI-facing specs have mockups and UI Design sections
```

## Hard Constraints

1. PRODUCT.md + DESIGN.md must exist before any mockup work
2. Every UI-facing spec gets a mockup in specs/mockups/
3. Critique + detect quality gates on every mockup — no reduced mode
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

**Announce:** "I'm using /design-ui to create the UI/UX design for the UI-facing specs."

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

Generate 2-3 **visual direction probes** — distinct aesthetic approaches for the overall application. Present via AskUserQuestion:

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
- **Typography**: Distinctive, characterful font choices — never generic (no Inter, Roboto, Arial). Pull from DESIGN.md tokens or establish new ones.
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

Run these quality checks in order. Each catches different problems.

**HOW TO RUN A GATE — read this before C1.** A gate is a Skill tool invocation, not a thought experiment. For every gate below you MUST issue a `Skill` call with the named impeccable command, let it execute, and apply its output to the mockup. The following are all equivalent ways of skipping the gate, and all are forbidden:

- "I'll author the mockup with DESIGN.md tokens directly and run the principles mentally."
- "I know the 27 anti-patterns, so I'll skim the file instead of invoking critique."
- "Invoking 24 sub-skills is excessive for this scope — I'll batch them inline."
- "The mockup is short, so audit/harden/clarify/adapt aren't necessary."
- "I'll note in the spec that the gates were applied conceptually."

If you catch yourself reasoning along any of those lines, STOP and invoke the Skill. The output of the gate must be visible in your transcript. If it isn't, the gate did not run, regardless of what you wrote in the spec.

**C1. Critique** (`/impeccable critique`) — Design quality
- Design review: visual hierarchy, readability, DESIGN.md consistency, PRODUCT.md alignment
- Anti-pattern detection: 27 deterministic rules for AI slop signals
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

**Skip for:** Non-onboarding specs. Most specs in a cluster won't need this.

### Step 2.4: Present Cluster and Confirm

After all mockups in a cluster are built and quality-checked, present them to the user via AskUserQuestion:

```
"Here are the UI designs for [cluster name] ([N] screens):

**Design Context**: [brand/product] register — [personality from PRODUCT.md]
**Visual Direction**: [chosen direction name]

Screens:
1. [feature-slug] — [primary user action]. Mockup: specs/mockups/[slug]/
2. [feature-slug] — [primary user action]. Mockup: specs/mockups/[slug]/

Quality: All mockups passed critique + detect.

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

**Skip if:** DESIGN.md was just created via `/impeccable teach` in this session and no new tokens emerged during mockup creation.

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
  Every UI-facing spec must list all five (plus `onboard` if applicable). If a gate was skipped, the spec is not approvable — go run the gate. Do NOT write caveats like "ran the principles mentally" here; that is the documented failure mode and will be rejected.
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
- All mockups passed critique + detect quality gates
- All UI-facing specs have `## UI Design` sections
- User confirmed all clusters

**Tell the user:** "UI/UX design complete. [N] mockups created across [M] clusters. View them in specs/mockups/. Returning to /design."

</the_process>

<examples>

<example>
<scenario>Greenfield fitness app — 14 UI-facing specs</scenario>

<why_it_fails>
Without /design-ui, the agent either (a) skips UI design entirely and ships 14 prose-only specs that /build implements as default Tailwind cards, or (b) runs /impeccable shape per spec without PRODUCT.md, DESIGN.md, visual probes, or quality gates — producing 14 individually-bland mockups with no shared system. Either way, the user sees the implementation and asks "why does this look like every other SaaS app?" Then 14 specs have to be redesigned. The fix isn't "design harder next time" — it's running the full pipeline once at the front: probes → frontend-design lockdown → per-cluster shape → mockups → critique+audit+harden+clarify+adapt → extract. Twelve sub-skill calls per cluster isn't optional; it's the difference between distinctive and forgettable.
</why_it_fails>

<correction>
**Phase 1 — Design System (once):**
- Gate: No PRODUCT.md or DESIGN.md → run `/impeccable teach`
- Register: Brand (consumer fitness app)
- Visual direction: Present 3 probes → user picks "Direction B — Athletic Minimalism"
- Category-reflex check: PASS (not triggering generic fitness app patterns)
- Frontend-design: Lock in Geist font, OKLCH green accent palette, spring motion

**Phase 2 — Per-Screen (6 clusters):**
- Cluster 1 (Onboarding): Shape 3 screens together → 3 mockups → critique + detect → PASS
- Cluster 2 (Workout Flow): Shape 3 screens → 3 mockups → critique found workout-tracking bland → `/bolder` → re-critique → PASS
- Cluster 3 (Nutrition): Shape 2 screens → 2 mockups → PASS
- Cluster 4 (Progress): Shape 2 screens → 2 mockups → PASS
- Cluster 5 (Social): Shape 3 screens → 3 mockups → PASS
- Cluster 6 (Settings): Shape 2 screens → 1 mockup (settings is one screen with sections) → PASS
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
- Critique + detect → PASS

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
3. **Quality gates on every mockup** → Critique + detect. No reduced mode regardless of timeline.
4. **User confirms visual direction before mockups** → Don't generate mockups without direction consensus.
5. **User confirms each cluster before proceeding** → Block until confirmed.
6. **App-level decisions are made once** → PRODUCT.md, DESIGN.md, register, visual direction, frontend-design aesthetics. Not repeated per screen.
7. **Enhancement for brand register is proactive** → Don't wait for critique to flag blandness. Run `/impeccable bolder` by default.

## Common Rationalizations (All Mean: STOP, Follow the Process)

- "The UI is simple enough to skip the mockup" → Simple UIs still get mockups. A single-screen mockup takes 2 minutes.
- "I'll describe the UI in the spec instead" → Text descriptions do not replace visual mockups. Users cannot review a layout from prose.
- "I can generate mockups later / during build" → Mockups are design artifacts, not implementation artifacts. They capture intent BEFORE code.
- "PRODUCT.md/DESIGN.md aren't needed for this project" → Every project with UI needs them. 5 minutes of `/teach` prevents hours of bland redesign.
- "Just /impeccable shape is enough" → Shape is one step of many. Without visual probes, mockups, and quality gates, you get generic output every time.
- "Running critique/detect on every mockup is overkill" → Critique runs 27 rules in seconds. It catches patterns humans normalize. Run it.
- "This is too many screens to mock up individually" → Batch by cluster, don't skip. 14 mockups across 6 clusters is 6 shape interviews, not 14.
- "The user wants to move fast, I'll skip the quality gates" → Skipping gates now means redesigning later. Every step exists because its absence caused a documented failure (see: trainr incident).
- "I authored the mockups with DESIGN.md tokens directly and ran the principles mentally rather than invoking 24 more sub-skill calls" → This is the exact failure mode this skill exists to prevent (see: 2026-05-21 incident). Token usage in the source file is not a substitute for invoking critique/audit/harden/clarify/adapt. An LLM reasoning about what a fresh-context skill would say is provably worse than letting the skill run — that's the whole reason the gates are separate invocations. Number of calls is not a reason to skip; if 24 calls is the right number, make 24 calls.
- "I'll note in each spec that the gates were applied conceptually / I'll caveat the quality gates" → A caveat in the spec is not a substitute for the gate. The correct action is to run the gate, not to disclaim that you didn't.
- "The user said they trust my judgment" → Trust is not permission to skip rigid steps. The rigid steps exist because judgment alone produces bland output. If the user explicitly types "skip the gates," ask whether they want the rigidity downgraded; do not assume.
- "I'll do the design system setup per-screen" → No. PRODUCT.md, DESIGN.md, register, visual direction, and frontend-design aesthetics are app-level decisions. Running them per-screen wastes time and produces inconsistent designs.
- "The visual direction probes are unnecessary — I already know the aesthetic" → Probes exist because designers and LLMs have blind spots. 3 directions in 2 minutes prevents "I didn't know I wanted that."
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
- [ ] Critique gate **invoked via Skill tool** per mockup — transcript contains `Skill(impeccable, "critique <slug>")` and its output
- [ ] Audit gate **invoked via Skill tool** per mockup — transcript contains `Skill(impeccable, "audit <slug>")` and its output
- [ ] Harden gate **invoked via Skill tool** per mockup — transcript contains `Skill(impeccable, "harden <slug>")` and its output
- [ ] Clarify gate **invoked via Skill tool** per mockup — transcript contains `Skill(impeccable, "clarify <slug>")` and its output
- [ ] Adapt gate **invoked via Skill tool** per mockup — transcript contains `Skill(impeccable, "adapt <slug>")` and its output
- [ ] Onboard gate invoked via Skill tool for onboarding specs — or N/A
- [ ] Enhancement commands applied where quality gates found weaknesses (each one a Skill invocation, not a mental pass)
- [ ] User confirmed each cluster

**Self-honesty check (Phase 2, before claiming completion):**

Answer each question literally — not "essentially yes" or "in spirit yes." If any answer is "no," the gate did not run.

- Q1. For every mockup, did your transcript contain a separate `Skill` tool call for `critique`, `audit`, `harden`, `clarify`, and `adapt` (one call per gate per mockup)?
- Q2. Did you read the actual textual output produced by each of those Skill calls, or did you stop at invoking them?
- Q3. Did you author any sentence in a spec or summary that begins with "Caveat," "I ran the principles mentally," "I applied them inline," "I batched them," "rather than invoking N sub-skill calls," or any close paraphrase?
  - If yes → the gates were skipped. Delete the caveat, run the gates, redo the UI Design sections.

**Incorporation (Phase 3):**
- [ ] `/impeccable extract` run to formalize design tokens in DESIGN.md — or skipped (no new tokens)
- [ ] `## UI Design` section added to every UI-facing spec, listing each gate Skill invocation that was made (gate name + slug, one line per call)
- [ ] Final verification: all mockups exist on disk

**Cannot check all boxes truthfully? Do not claim /design-ui is complete.** Do not paper over a skipped gate with a caveat — go back and invoke the gate.
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
