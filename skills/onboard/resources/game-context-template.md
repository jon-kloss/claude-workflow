# Game Context

This file is the canonical, project-level orientation read by every game-design role agent (`game-designer`, `level-designer`, `narrative-designer`, `systems-designer`, `game-ui-designer`) at Phase 1 of every dispatch. It is committed to git. **It is NOT a design document** — it's a constants file. Real design lives in handoffs and specs.

If you've cloned a game project and don't see this file, the game agents will refuse to dispatch and ask you to create it.

## Genre

<One of: action / adventure / arcade / city-builder / fighting / metroidvania / narrative-adventure / platformer / puzzle / racing / rhythm / roguelike / rpg / shooter / sim / sports / strategy / survival / tactics / visual-novel / generic>

If "generic" — agents use neutral defaults and ask before applying genre-specific opinions. Pick something specific as soon as you can; generic defaults are weaker.

## Target platform

<desktop / mobile / handheld / console / web / cross-platform>

Specifically:
- Primary input: <controller / keyboard+mouse / touch / stylus / motion>
- Screen baseline: <handheld 720p / desktop 1080p / TV 4K / mobile portrait>
- Performance baseline: <eg 60fps locked / 30fps stable / variable>

## Audience

<Brief paragraph: who plays this game, what they know already (other games in this space they've played), what they're currently frustrated by, what would make them recommend the game to a friend.>

## Scope

<jam / prototype / commercial / live-service / educational / portfolio>

What scope means here:
- **jam:** 1-7 day deliverable. Cut ruthlessly.
- **prototype:** 2-8 week deliverable. One core loop, one zone, one boss. Polish only the core.
- **commercial:** months-to-years. Ship-quality on everything that ships.
- **live-service:** ongoing. Monetization + retention systems matter at design time, not retrofitted.
- **educational:** ship-quality but optimize for clarity over depth.
- **portfolio:** ship-quality on the slice you're showing. Cut everything else.

## Engine

<Unity / Unreal / Godot / Bevy / love2d / pico-8 / web-canvas / custom / TBD>

If "TBD" — gameplay code goes through `backend-engineer` with `@layer(gameplay)` until you pick an engine. Engine-specific specialist agents (if any) are deferred until you commit.

## References

Cite 3-7 references that anchor the target experience. Mix media:

- **Games (positive):** <games whose feel you're aiming at>
- **Games (anti-reference):** <games whose feel you're explicitly NOT aiming at — these prevent drift>
- **Films / TV / books:** <narrative or tonal references>
- **Music / aesthetic:** <if visual/audio style matters>

For each reference, one sentence on what specifically you're referencing — never just "this game" without naming the axis. "Dark Souls combat weight, NOT its punishment philosophy" beats "Dark Souls."

## Perspective + camera

<First-person / Third-person / Top-down / Isometric / Side-scroll / 2.5D / Mixed>

For top-down or isometric, name the tile size or grid convention if relevant.

## Save / session model

<single-session / per-run / persistent / mixed>

- **single-session:** game completes in one sitting; no save needed
- **per-run:** roguelike-style, run restarts on death
- **persistent:** classic save system
- **mixed:** runs PLUS meta-progression

## Multiplayer

<single-player / local-coop / online-coop / pvp / hybrid / TBD>

## Content rating target

<E / E10+ / T / M / Unrated / TBD>

Affects narrative scope (violence, language, themes) and game-ui-designer's content-gate design.

## Accessibility commitments (default-on)

- Subtitles for all dialogue (always on by default; opt-out only)
- Colorblind-safe primary palette
- Motion-reduction toggle
- Input remapping
- Font scale 0.85×–1.5× minimum

If you're shipping a "casual accessibility-first" game, raise these commitments. Don't lower them.

## Notes for agents reading this

This file is the orientation, not the design. When you reach a design decision (which level archetype to use, which balance shape, which juice budget), the decision lives in your handoff and your memory file — not here. This file changes rarely; agent memory changes often.

If genre is "generic" or scope is "TBD," ask the user via AskUserQuestion before applying defaults that would be opinionated. When in doubt, surface in `open-questions`.
