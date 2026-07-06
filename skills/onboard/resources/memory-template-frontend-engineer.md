---
agent: frontend-engineer
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# frontend-engineer — project memory

## Summary

<1-2 paragraph orientation: framework (Next.js App Router / Remix / SvelteKit / RN / etc.), styling (Tailwind / vanilla-extract / styled-components), state management (RSC + URL state / Zustand / Redux / TanStack Query / etc.), routing approach. 100-200 words.>

## Conventions (canonical — always observe)

- Style: Tailwind classes only; no inline `style={}` except CSS custom properties from DESIGN.md
- Tokens: every color/spacing/type value from DESIGN.md; never raw hex/px
- API client: `src/lib/api-client.ts` (fetch wrapper with error normalization + retry); never raw `fetch()` in components
- State: server-state via RSC + cookies; client-state via URL params for sharable state, useState for ephemeral
- Forms: `react-hook-form` + Zod schemas (shared with backend)
- Tests: Vitest + @testing-library/react for components; Playwright for e2e

## Component map (top-level)

<directory or feature-level component map. Drill into a Pointer for specific subsystems.>

| Surface | Owns | File location | Spec | Pointer |
|---|---|---|---|---|
| AppShell | header, sidebar, theme switcher | src/components/AppShell.tsx | dark-mode.md, responsive-polish.md | [↓ shell](#pointer-shell) |
| ListView | list of tasks, drag-reorder, filters | src/features/lists/ListView.tsx | tasks-*.md | [↓ tasks](#pointer-tasks) |
| AuthForm | sign-in, sign-up, reset | src/features/auth/ | auth-*.md | — |

## Design system in use

<reference key tokens/recipes from DESIGN.md that are currently consumed. The full set lives in DESIGN.md; this is what's IN USE here.>

- Colors: `--color-surface-0`, `--color-surface-1`, `--color-accent-9`, `--color-danger-7` (full palette: DESIGN.md)
- Type scale: `--text-display`, `--text-h1`, `--text-h2`, `--text-body`, `--text-small`, `--text-caption`
- Spacing: 4px base; `--space-1` through `--space-16`
- Radius: `--radius-sm`, `--radius-md`, `--radius-lg`, `--radius-xl`, `--radius-full`
- Motion: 120-360ms; one spring on drag release

## Routing pattern

<top-level route map. For App Router: src/app/ tree. For React Router: routes file.>

- `/` — home (RSC, shows active list)
- `/lists/[id]` — list view (RSC)
- `/sign-in`, `/sign-up`, `/reset-password` — auth (RSC)
- `/api/*` — Route Handlers (POST/PATCH/DELETE)

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec> — <what frontend changed>

## Known issues / tech debt

<UI-layer issues flagged but deferred. Each: title, source, severity, fix path.>

## Pointers

<a id="pointer-shell"></a>
### AppShell detail
The shell SSR-resolves theme (light/dark) from cookie before first paint to prevent FOUC. See `src/components/AppShell.tsx:34` for the resolution. The theme toggle is `src/components/ThemeToggle.tsx`. Cross-tab sync via `BroadcastChannel('theme')`.

<a id="pointer-tasks"></a>
### Tasks ListView detail
Drag-reorder uses `@dnd-kit` (NOT `react-beautiful-dnd` which is archived). Reorder persists via PATCH `/api/tasks/:id/position` with LexoRank-style `sort_key`. See `src/features/lists/useTaskReorder.ts` for the optimistic update + rollback on error.

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This is the OTHER implementer memory (with backend-engineer). Used in fix-mode dispatches too.
- The Component map and Design tokens sections are highest-leverage — they're consulted on every UI spec.
- Don't memorize per-component prop interfaces (those live in the component source or storybook).
-->
