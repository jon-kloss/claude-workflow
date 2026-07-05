# Incident Ledger

The documented failures that produced the workflow's rules. Skills, agents, and hooks
cite these entries by anchor (e.g. `docs/incidents.md#trainr`) instead of retelling the
story inline. One entry per incident: stable anchor, date, what happened, and the rule(s)
it produced. Add new entries at the bottom; never rename an anchor — citations depend on it.

---

<a id="squashbuckler-2026-05-31"></a>
## SquashBuckler — verified features, no product (2026-05-31)

The SquashBuckler dogfood epic decomposed into ~40 independent UI feature specs. Each one
was built, tested, and marked `@status(verified)` in isolation — and the running app
reached none of them. Every feature passed as a disconnected demo card; the app shell that
mounts them into one product did not exist and had to be retrofitted afterwards under a
separate slug. Nothing in decomposition, per-spec verification, or epic close had asked
"is this feature reachable in the assembled product?"

**Rules produced:** the `@integration` spec + `## Mount Map` requirement at decomposition
(application-architect owns it — an unmapped UI feature is a decomposition bug); the
`@mounts-in(...)` tag on every UI feature; the `require-feature-mounted.sh` hook blocking
`@status(verified)` on orphans; qa-engineer's Step 4.1 rule that every e2e test launches
the real app entry point and walks the Mount Map (`mount-map-reachability.spec.ts`);
release-coordinator's orphan-feature check gating epic close.

---

<a id="squashbuckler-fix-cycles-2026-05-26"></a>
## SquashBuckler — fix-cycle handoffs dropped under pressure (2026-05-26)

During the same dogfood, implementer agents dispatched in fix mode twice did the code work
but returned without writing their fix-cycle handoff or updating memory. The reviewer side
of each cycle had its re-verify artifact; the implementer side had nothing — leaving the
orchestrator to either synthesize a fake artifact or skip the cycle, both of which corrupt
the audit trail.

**Rules produced:** the `require-fix-cycle-handoff.sh` hook, which blocks
`@status(verified)` on specs with asymmetric fix-cycle handoffs; the exit rule in
`docs/agent-protocol.md` §1 — the handoff write is the last thing an agent does before
returning, never a step to drop under pressure.

---

<a id="trainr"></a>
## Trainr — specs verified with a whole layer missing (2026-05)

The trainr project shipped 15 full-stack specs marked verified with zero mobile code — the
API side passed its tests, so the specs were declared done while the user-facing layer
didn't exist. The same project's specs had shipped without mockups, so every screen that
did get built had to be redesigned after the user saw it.

**Rules produced:** layer-aware verification — if a spec describes UI scenarios, API tests
alone are not implementation; the `@layer(...)` tag governs which verification axes apply.
Mockup-first design — every UI-facing spec gets a mockup before implementation begins
(/design-ui's blocking mockup requirement; no mockup = spec cannot be approved).

---

<a id="fitconnect"></a>
## FitConnect — every unit test green, nothing worked end-to-end (2026-05)

FitConnect launched with a full suite of passing unit tests and buttons that did nothing.
Features were verified in isolation; no one traced a complete user journey through the
running application, so wiring gaps between components, routes, and APIs went undetected
until launch.

**Rules produced:** Critical User Journey tracing at design time (every spec carries a
`## Critical User Journeys` table); epic-level cross-spec CUJ e2e gates (qa-engineer
Step 4.1) that drive the real UI through real navigation; connectivity verification —
every Interaction Map row gets a network-intercepted test proving the click actually hits
its declared endpoint.

---

<a id="mental-gates-2026-05-21"></a>
## Design-UI gates "run mentally" instead of invoked (2026-05-21)

A design session authored mockups directly with DESIGN.md tokens and recorded that the
/impeccable quality gates had been "applied mentally / inline" rather than invoking them as
Skill calls — on the reasoning that dozens of sub-skill invocations were excessive. The
mockups shipped without any actual gate output, which is exactly the unaudited-quality
state the gates exist to prevent.

**Rules produced:** design-ui's rigid rule that a gate is a real `Skill` invocation whose
output appears in the transcript — a mental run is a skipped gate; the
`claim-vs-call-audit.sh` hook, which cross-checks gate invocations claimed in `## UI
Design` sections against the Skill calls actually made in the session.
