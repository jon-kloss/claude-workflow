---
agent: level-designer
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# level-designer — project memory

<!--
BOOTSTRAP SCOPE:

EAGER:
- Zone archetypes you've established for THIS game (linear / hub / arena / wave / etc.)
- Pacing principles (breather frequency, climax cadence)
- Difficulty rating scale (so reviewers can read your difficulty bands consistently)
- Anti-patterns you've dodged (don't re-create them)

LAZY (per-spec, not at bootstrap):
- Per-level encounter sequences (those live in each spec's level-designer handoff)
- Reward placement details (per-zone)
-->

## Summary

<2-3 paragraph orientation: game's level structure (linear campaign / open world / procedural / Metroidvania), expected zone count, mode-of-play (single-session / persistent / both).>

## Pacing principles (canonical)

- <Breather frequency, e.g., "Every 3-4 combat encounters there's a non-combat beat.">
- <Climax cadence>
- <Difficulty rating scale: 1-5 / easy-medium-hard-brutal / etc. + what each band means>
- <Sight-line philosophy: "Foreshadow boss room 2 zones early">

## Zone archetypes

| Archetype | Used in zones | Shape | Pacing signature |
|---|---|---|---|
| <name> | <zone refs> | linear / hub / open / arena | <typical curve> |

## Difficulty curve standards

<table or inline svg pointing to a global difficulty curve across the game>

## Anti-patterns dodged (this game)

- <Anti-pattern> — <how we avoid it>

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec or level> — <structural change>

## Known issues / spatial tensions

- <Tension carried forward. Spec / zone. Severity.>

## Pointers

<a id="pointer-mockups-or-maps"></a>
### Level maps + mockups
- <pointer to specs/diagrams/levels/ or specs/mockups/levels/ if those exist>

<a id="pointer-related-memories"></a>
### Sibling memory files
- `.claude/agent-memory/game-designer.md` — core loop and verbs the levels exercise
- `.claude/agent-memory/narrative-designer.md` — story beats anchored to zones
- `.claude/agent-memory/systems-designer.md` — reward placement informs balance
- `.claude/agent-memory/game-ui-designer.md` — HUD elements that depend on level state

<!--
ROLE-SPECIFIC NOTES:
- Zone archetypes are HIGH-LEVERAGE memory — once named, they become shared vocabulary.
- Pacing principles prevent every level from re-inventing the breather/climax wheel.
- Don't memorize per-level encounter sequences — those go in spec handoffs.
-->
