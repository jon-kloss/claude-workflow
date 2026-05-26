---
agent: uiux-designer
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# uiux-designer — project memory

## Summary

<1-2 paragraph orientation: register (brand vs product), tone/personality, target users, primary use cases. 100-200 words.>

## Conventions (canonical — always observe)

- Register: <brand | product> — see PRODUCT.md for full personality
- Mockup format: <inline HTML in specs/mockups/ | Figma export | Storybook> + DESIGN.md tokens
- Quality gates: 5 /impeccable gates per UI spec (critique/audit/harden/clarify/adapt). Skill calls are logged in spec's `## UI Design` section.
- Tokens: every value via DESIGN.md custom properties; pure OKLCH for color
- States required per component: default, hover, focus-visible, active, disabled, loading, empty, error
- Responsive: 375 / 768 / 1440 minimum; consider 1920 for marketing surfaces

## Brand context (from PRODUCT.md)

<short distillation — full content in PRODUCT.md, pointer below.>

- Personality: <calm/direct/confident/playful/etc.>
- Anti-references: <what NOT to look like — competitors / patterns to avoid>
- Audience: <who the design serves>

## Component recipes (formalized via /impeccable extract)

<list of named recipes folded into DESIGN.md by extract passes. Recipes are reusable patterns the project has settled on.>

- `task-row` — drag handle + checkbox + title + meta + actions, src/components/TaskRow.tsx
- `priority-badge` — pill, color from --color-priority-{low,medium,high}, src/components/PriorityBadge.tsx
- `keyboard-chip` — kbd-style key indicator, src/components/Kbd.tsx
- `dialog` — centered card, backdrop, focus-trap, esc-to-close, src/components/Dialog.tsx

## Established mockups

<inventory of mockup files. Cite spec + path.>

- specs/mockups/auth.html — login / register / reset / lockout — auth-*.md
- specs/mockups/dark-mode.html — toggle + cheatsheet + lockout countdown — dark-mode.md
- specs/mockups/tasks.html — list / detail / drag / filters — tasks-*.md

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec> — <design change>

## Known issues / design tech debt

<design-quality concerns flagged but deferred. Each: title, source gate verdict, fix path.>

## Pointers

<a id="pointer-product"></a>
### Full brand context
See `PRODUCT.md` at project root. Don't duplicate that file's content here — it's the source of truth for brand personality. This memory holds only the *distillation* and recent decisions.

<a id="pointer-design-md"></a>
### Full design system
See `DESIGN.md` at project root. The recipes list above pulls names from DESIGN.md; full token tables and component recipes live there.

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This agent BENEFITS from terse memory because PRODUCT.md and DESIGN.md already hold the canonical detail.
- Component recipes section is the highest-leverage entry — it surfaces what's been formalized vs ad-hoc.
- Don't memorize per-mockup descriptions — they live in the mockup files themselves.
-->
