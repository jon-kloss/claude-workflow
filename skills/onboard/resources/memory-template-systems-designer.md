---
agent: systems-designer
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# systems-designer — project memory

<!--
BOOTSTRAP SCOPE:

EAGER:
- Progression axes (canonical list)
- Balance principles (your committed rules-of-thumb for THIS game's math)
- Established constants (committed numbers — exchange rates, base damage, etc.)
- Economy shape (open / closed / cyclical)
- Anti-degenerate defenses inventory

LAZY:
- Per-spec drop tables (those live in spec handoffs)
- Simulation outputs (re-runnable, not stored)
-->

## Summary

<2-3 paragraph orientation: progression axes in play, economy shape, what scales (player power, world difficulty, both), single most load-bearing balance equation.>

## Balance principles (canonical)

- <Principle. e.g., "Diminishing returns above 5 stat points in any single attribute.">
- <Principle>

## Progression axes (canonical inventory)

| Axis | Range | Unlock granularity | Reset behavior |
|---|---|---|---|
| <axis> | 1-N | <event / chapter / continuous> | <per-run / persistent / partial> |

## Established constants (committed)

| Constant | Value | Rationale | Locked? |
|---|---|---|---|
| <name> | <value> | <derivation in 1 line> | yes/no |

## Economy graph

<Inline svg or DOT, OR pointer to specs/diagrams/economy-graph.svg>

## Anti-degenerate defenses

| Defense | Defends against | How |
|---|---|---|
| <name> | <failure mode> | <mechanic> |

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec or constant> — <tuning change with old/new values>

## Reverted tunings (avoid re-trying)

- <Old value> → tried <new value> on <date> → reverted because <reason>

## Known issues / open balance questions

- <Question. Where it surfaces. What data would resolve it.>

## Pointers

<a id="pointer-formulas"></a>
### Formula derivations + sim scripts
- <pointer to docs/balance/ or specs/sims/ if separate>

<a id="pointer-related-memories"></a>
### Sibling memory files
- `.claude/agent-memory/game-designer.md` — verbs that get scaled
- `.claude/agent-memory/level-designer.md` — encounter density informs reward rate
- `.claude/agent-memory/narrative-designer.md` — narrative-gated content vs system-gated

<!--
ROLE-SPECIFIC NOTES:
- "Established constants" is the highest-value memory section — protect committed values.
- "Reverted tunings" prevents re-tuning the same dead end.
- NEVER include monetization constants if commercially sensitive — pointer to locked doc.
-->
