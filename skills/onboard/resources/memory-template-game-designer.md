---
agent: game-designer
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# game-designer — project memory

<!--
BOOTSTRAP SCOPE (read before seeding via /onboard):

EAGER (capture at bootstrap, keep current):
- Core fantasy + tagline (the emotional north star)
- Player verbs inventory (the canonical list)
- Core loop in 1 sentence + linked diagram path if separate doc exists
- Anti-features (what we will NOT build) — load-bearing scope discipline
- Design principles you've committed to for THIS game

LAZY (defer to per-spec dispatches — DO NOT capture at bootstrap):
- Per-spec design tensions (those live in the spec's open-questions)
- Detailed level-by-level mechanic introductions (that's level-designer's domain)

Eager content stays under ~3,500 words. Use Pointers for anything longer.
-->

## Summary

<2-3 paragraph orientation: core fantasy, current core loop, target audience and what they value, scope (jam / commercial / live-service), genre baseline.>

## Design principles (canonical — always observe)

- <Principle 1 — a rule of thumb you've committed to. e.g., "Every verb teaches itself within 30 seconds of first availability.">
- <Principle 2>
- <Principle 3 — keep ~6-10 total>

## Player verbs (canonical inventory)

| Verb | Description | Implementation cost | Status |
|---|---|---|---|
| <verb> | <1-line> | low / medium / high | committed / proposed / cut |

## Core loop

<1-sentence statement. Reference a diagram if separate doc exists.>

<inline flowchart in ASCII or pointer to specs/diagrams/core-loop.svg>

## Ten fun things (commitments)

1. <Concrete moment.>
2. <...>
3. <...>
4. <...>
5. <...>
6. <...>
7. <...>
8. <...>
9. <...>
10. <...>

## Anti-features (what we will NOT build)

- <Feature> — <one-line reason>

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec or epic> — <design decision made or scrapped>

## Scrapped ideas (avoids revisiting)

- <idea> — <reason cut> — <date>

## Known issues / open design tensions

- <Tension you're carrying. Severity. Where it surfaces.>

## Pointers

<a id="pointer-references"></a>
### Genre + tonal references
See `.claude/game-context.md` for the canonical reference set. Note any references in this list that you've drifted from / reinforced.

<a id="pointer-related-memories"></a>
### Sibling memory files
- `.claude/agent-memory/product-owner.md` — audience and value-prop context
- `.claude/agent-memory/level-designer.md` — how the loop maps to space
- `.claude/agent-memory/narrative-designer.md` — story constraints on verbs
- `.claude/agent-memory/systems-designer.md` — math constraints on loop iteration

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- Game-designer authority is the experience contract. Memory tracks WHAT and WHY, not HOW.
- Scrapped ideas section is high-leverage — prevents the team from re-pitching dead designs.
- Anti-features list grows over time; protect it.
-->
