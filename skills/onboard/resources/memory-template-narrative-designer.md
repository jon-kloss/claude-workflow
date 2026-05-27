---
agent: narrative-designer
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# narrative-designer — project memory

<!--
BOOTSTRAP SCOPE:

EAGER:
- Tone commitments (positive AND anti-tone)
- Established lore (world rules, named factions, era, magic/tech base)
- Character voice index (canonical voices for major characters)
- Branching structure type (linear / hub / branch-and-converge / true branching)
- Content gates inventory (story content × unlock condition)

LAZY:
- Per-spec dialogue (lives in spec handoffs)
- Full dialogue scripts (separate doc, referenced via pointer)
-->

## Summary

<2-3 paragraph orientation: story-in-a-sentence, protagonist's arc, world era/setting, tonal commitment, branching shape.>

## Tone commitments (canonical)

**Positive:**
- <Tone rule. e.g., "Dry humor, never slapstick.">
- <Rule>

**Anti-tone (what we WON'T do):**
- <Anti-rule. e.g., "No fourth-wall breaks.">

## Lore bible (index — content in pointers)

| Domain | Established fact | Source |
|---|---|---|
| <era / faction / magic system / etc> | <one-line summary> | <pointer to fuller doc> |

## Character voice index

| Character | Role | Voice (3-5 adjectives) | Refusal lines |
|---|---|---|---|
| <name> | <role> | <adjectives> | <things they would NEVER say> |

## Branching structure

<Type: linear / hub / branch-and-converge / true branching. Pointer to specs/diagrams/narrative-tree.svg or similar if separate doc.>

## Content gates

| Content | Gate condition | Unlock |
|---|---|---|
| <story beat> | <mechanical / choice / time / etc.> | <unlock trigger> |

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec> — <narrative decision>

## Established narrative beats (canonical)

- <Beat. Where it lands. What it requires.>

## Known issues / narrative tensions

- <Tension. Severity. Where it surfaces.>

## Pointers

<a id="pointer-script-docs"></a>
### Dialogue scripts and lore docs
- <pointer to /docs/lore/, /docs/scripts/, or wherever full narrative content lives>

<a id="pointer-references"></a>
### Tonal references
Per `.claude/game-context.md`. Note any drift from cited references.

<a id="pointer-related-memories"></a>
### Sibling memory files
- `.claude/agent-memory/game-designer.md` — verbs that constrain narrative delivery
- `.claude/agent-memory/level-designer.md` — spatial beats anchoring story
- `.claude/agent-memory/game-ui-designer.md` — dialogue UI conventions

<!--
ROLE-SPECIFIC NOTES:
- Lore bible INDEX in memory; full content in /docs/ via pointer.
- Character voice samples (5-10 lines per character) live in /docs/scripts/voices.md or similar — pointer only.
- NEVER include unreleased plot twists if pre-launch sensitive — use a locked doc + pointer.
-->
