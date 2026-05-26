---
agent: application-architect
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# application-architect — project memory

## Summary

<1-2 paragraph orientation: stack, monorepo vs single repo, top-level module boundaries, the architectural seams that matter most. Aim for 100-200 words.>

## Conventions (canonical — always observe)

<3-7 conventions the team holds for new specs. Examples:>
- Decomposition uses the independence-test rule documented in skills/design/SKILL.md Step 2.5
- @parallel-risk is reserved for true file-overlap, not "related work"
- New features go in src/features/<slug>/, with co-located tests
- Cross-module communication via events (src/events/) not direct imports

## Component map (top-level)

<table of high-level modules — the architectural layer, NOT every file. Drill-down via Pointers.>

| Module | Owns | Talks to | Spec(s) | Pointer |
|---|---|---|---|---|
| src/api/auth/ | login, register, password-reset, lockout | src/lib/db, src/middleware/auth | auth-*.md | [↓ auth detail](#pointer-auth) |
| src/api/lists/ | list CRUD + ownership | src/lib/db | lists-crud.md | — |
| src/components/ | UI shell, design system | src/lib/api-client, theme | (UI specs) | [↓ ui detail](#pointer-ui) |

## Dependency graph

<text or inline svg of the high-level dependency graph between modules. Cite the source spec when relevant.>

## Key design decisions (chronological, latest at bottom)

<numbered list of architectural decisions made over the life of the project. Each: date, decision, rationale, alternatives considered.>

DD-001 (2026-05-25) — Single-tenant per user. Rationale: simplifies authz to ownership filtering. Alternatives: multi-tenant from day one (rejected as premature). Spec: data-model.md.

## Recent changes (rolling, last 5)

<delta entries since the prior memory write. Trim oldest when over 5.>

- <YYYY-MM-DD> — <spec or PR> — <what changed>

## Known issues / architectural tech debt

<surfaced architectural concerns deferred for follow-up. Each: title, source (finding/handoff), severity, target spec for remediation.>

## Pointers

<a id="pointer-auth"></a>
### Auth architecture detail
See `src/middleware/auth.ts` for the verifyJwt + lockout check. Trust boundary at src/middleware/auth.ts:42; everything inside is authenticated. The session model is documented in `specs/auth-email-password.md` Technical Context.

<a id="pointer-ui"></a>
### UI architecture detail
React Server Components for reads, Route Handlers for mutations. State management is local-first with server sync. See `frontend-engineer.md` memory for component-level patterns.

<!--
ROLE-SPECIFIC NOTES (delete this comment block in production memory files):
- This agent owns the BIG PICTURE. Avoid duplicating data-architect's schema detail or backend-engineer's
  route detail — those agents own those layers.
- Component map is the highest-leverage section. Keep it ≤ 10 rows; drill-down via Pointers.
- Design decisions are valuable history — never delete them, only mark superseded ones with a strike.
-->
