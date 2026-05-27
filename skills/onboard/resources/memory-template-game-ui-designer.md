---
agent: game-ui-designer
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# game-ui-designer — project memory

<!--
BOOTSTRAP SCOPE:

EAGER:
- Diegesis posture (which classes you use and why)
- HUD pattern library (named persistent elements)
- Input model (controller-first / keyboard-first / parity / touch)
- Controller mapping (canonical bindings)
- Accessibility commitments (subtitles / colorblind / motion-reduce / remap / font-scale)
- /impeccable gate posture (which gates fired against which mockups)

LAZY:
- Per-spec mockups (those live in specs/mockups/)
- Per-spec menu flows (lives in spec handoffs)

Game-ui-designer inherits uiux-designer's discipline; capture only the GAME-specific extensions here, not the base.
-->

## Summary

<2-3 paragraph orientation: surfaces covered (HUD / menus / pause / settings / dialogue UI), diegesis posture, input model, accessibility default-on commitments.>

## Diegesis posture

- **Diegetic elements:** <list>
- **Non-diegetic elements:** <list>
- **Spatial elements:** <list>
- **Meta elements:** <list, if any>

Rationale: <1-2 sentences on the tonal choice>

## HUD pattern library

| Element | Position | Sizing | Visibility | Data source |
|---|---|---|---|---|
| <name> | <screen region> | <fixed / responsive / safe-area> | <always / contextual / fade> | <game state var> |

## Input model

- **Primary:** <controller / keyboard / touch>
- **Secondary:** <other supported>
- **Focus model:** <how navigation works on non-mouse>

## Controller mapping (canonical)

| Action | Controller | Keyboard | Touch |
|---|---|---|---|
| <action> | <button> | <key> | <gesture or zone> |

## Accessibility commitments (default-on unless noted)

| Axis | Default | Configurable | Notes |
|---|---|---|---|
| Subtitles | on | yes | <styling notes> |
| Colorblind palettes | <off / N palettes> | yes | <axis support> |
| Motion reduction | <off> | yes | disables <specific effects> |
| Input remapping | n/a | yes | all bindings |
| Font scaling | 1.0× | yes | range <min>–<max> |

## Juice/feedback library

| Action | Visual | Audio (intent) | Haptic |
|---|---|---|---|
| <action> | <effect bounded> | <intent string> | <pattern> |

## /impeccable gates run (per spec)

| Spec | teach | craft | critique | detect | enhance |
|---|---|---|---|---|---|
| <slug> | ✓ | ✓ | ✓ | ✓ | ✓ |

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec> — <UI / accessibility / juice change>

## Known issues / open UI tensions

- <Tension. Spec affected. Severity.>

## Pointers

<a id="pointer-mockups"></a>
### Mockups
- `specs/mockups/<slug>/` — per-spec mockup directories

<a id="pointer-design-docs"></a>
### Visual system + base discipline
- `DESIGN.md` (tokens, type system, color, motion)
- `PRODUCT.md` (brand, register, anti-references)
- `agents/uiux-designer.md` (base discipline this role inherits)

<a id="pointer-related-memories"></a>
### Sibling memory files
- `.claude/agent-memory/game-designer.md` — verbs that need affordances
- `.claude/agent-memory/level-designer.md` — level state HUD must surface
- `.claude/agent-memory/narrative-designer.md` — dialogue UI requirements
- `.claude/agent-memory/systems-designer.md` — what resource/progression state to surface
- `.claude/agent-memory/uiux-designer.md` — base visual-fidelity discipline

<!--
ROLE-SPECIFIC NOTES:
- This role inherits uiux-designer's discipline; memory captures only the GAME-specific extensions.
- HUD pattern library is HIGH-LEVERAGE memory — establishes shared vocabulary for every future HUD spec.
- Accessibility commitments are NOT post-launch features — they belong in memory at bootstrap.
-->
