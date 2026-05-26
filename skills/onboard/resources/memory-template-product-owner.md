---
agent: product-owner
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# product-owner — project memory

## Summary

<1-2 paragraph orientation: product purpose, primary user persona(s), the 3-5 outcomes the product is trying to deliver, what's explicitly OUT of scope for v1. 100-200 words.>

## Personas (canonical)

<list of personas this product serves. Each: name, context, primary goal.>

- **Sam (solo user)** — wants a fast, keyboard-driven personal task manager. Visits daily. Cares about: speed, ergonomics, persistence across devices.
- **Riley (occasional)** — uses a few times a week. Cares about: not breaking on returning visits, dark mode for night use.

## Out-of-scope (explicit deferrals, with reason)

<accumulated list of things the user has said NO to. Each: item, who asked when, reason for deferral.>

- Team sharing / multi-user lists — deferred indefinitely (single-user product per PRODUCT.md)
- Recurring tasks — deferred to v2 (decision: 2026-05-25 Socratic)
- Mobile native app — deferred; PWA is the path
- MFA — deferred to v2; argon2id + lockout sufficient for v1

## Accumulated scope decisions (chronological)

<numbered list. Each: date, decision, why. NEVER delete entries — only mark superseded.>

SD-001 (2026-05-25) — Email + password auth (no OAuth in v1). Reason: simplicity; OAuth adds 2 weeks for marginal v1 value. Source: design Step 2 Socratic.

SD-002 (2026-05-25) — Drag-reorder via @dnd-kit with keyboard alternative (j/k). Reason: accessibility + power-user ergonomics; spec auth-login-lockout adds shortcut layer.

SD-003 (2026-05-25) — DevOps recommendation accepted: edge rate-limit on /api/auth/* in v1 (not v2 as originally punted). Reason: credential-stuffing risk + cheap to add. Source: design Step 4.5 devops-architect handoff.

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec or decision> — <change>

## Open questions awaiting user decision

<questions surfaced by other agents/specs that need PO/user disposition. Each: question, source handoff, recommended default.>

## Pointers

<a id="pointer-product"></a>
### Full brand + personality
See `PRODUCT.md` at project root. This memory holds DECISIONS; PRODUCT.md holds the brand context that informs them.

<a id="pointer-roadmap"></a>
### Roadmap
See `docs/roadmap.md` (if exists). The deferred items above link to specific roadmap entries when applicable.

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This agent's memory is the ACCUMULATED VOICE OF THE USER over the life of the project.
- Scope decisions are write-ONCE — never delete. Strike-through (`~~text~~`) if superseded.
- Personas may drift over time; update when the user clarifies, but preserve old definitions in Recent changes for audit.
-->
