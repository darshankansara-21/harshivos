# WonderPlay — Game Factory

**Mission:** The current catalog is the BASELINE, not the ceiling. This is a factory:
discover many strong game concepts, classify them by value, and ship the strongest ones
with genre-authentic feel. Every shipped game must clear the quality gate
(clear in 5s · satisfying in 30s · evolves in 2min · real "again" loop · responsive
touch/sound/visual feedback · clear scoring · real progression · WonderPlay character).

**Resume rule:** read this file + `GAME_QUALITY_WAR_ROOM.md`. Build from the first `A`-tier
concept that is not yet `SHIPPED`. Never restart.

## Shipping checklist (per new game)
1. State widget in the right toys file (`arcade_games.dart` / `mini_games.dart` / `goal_games.dart`) — ToyTicker + `_Emit` juice.
2. `toy_registry.dart` builder.
3. `toy_meta.dart` ToyMeta (`implemented: true`).
4. `universe_catalog.dart` UniverseToy + add to the appropriate discovery rail(s).
5. `game_thumb.dart` painted-set id + switch case + `_<id>` thumbnail painter.
6. `test/catalog_integrity_test.dart` gameIds + `test/arcade_games_test.dart` smoke test.
7. `flutter test` green + `flutter analyze` (0 errors / 0 warnings) → commit + push.

## Concept classification
Tiers: **A** = ship now (high joy, authentic, feasible with current primitives) ·
**B** = strong, ship after A · **C** = good but needs new tech/art · **D** = park (low value / redundant).

### Sports
| concept | tier | status | notes |
|---------|------|--------|-------|
| Basketball (drag-aim arcade hoops) | A | SHIPPED | Drag to aim, gravity arc, backboard bank vs swish, moving hoop, 12 to win. |
| Mini Golf (flick putt, par, holes) | A | PLANNED | Flick strength+angle, walls, cup, par per hole, stroke count. |
| Air Hockey (paddle vs AI, pips) | A | PLANNED | Drag paddle, puck physics, AI goalie, first-to-7. |
| Target Toss / Archery (aim+power ring) | B | PLANNED | Moving target, bullseye rings, wind at higher rounds. |
| Fishing (cast, wait, reel tug) | B | PLANNED | Cast meter, bite timing, reel mini-tension, rarity fish. |
| Penalty Shootout (reuse keeper physics) | C | PARKED | Overlaps Goal Keeper; revisit as mode not game. |
| Bowling | — | EXISTS | Already in catalog (rebuilt). |

### Music
| concept | tier | status | notes |
|---------|------|--------|-------|
| Drum Garden (tap pads, loop builder) | A | PLANNED | 4–6 pads, each a TonePlayer cue, free-play + call-and-response rounds. |
| Beat Builder (step sequencer grid) | B | PLANNED | Toggle a grid, loop plays, kid "composes"; colour-per-track. |
| Melody Match (Simon with tones) | B | PLANNED | Overlaps Tap Order / Piano Tiles — differentiate via free melody. |
| Piano Tiles | — | EXISTS | Already in catalog (melody added). |

### Creative
| concept | tier | status | notes |
|---------|------|--------|-------|
| Color Mixer (combine drops → new colour) | A | PLANNED | Drag primary drops together, discover secondaries, "find the target colour". |
| Magic Sandbox (falling-sand / paint) | C | PARKED | Needs a cellular grid sim; heavier. |
| Sticker Scene (drag/scale decals) | C | PARKED | Asset-heavy; low loop. |

### Calm / Sensory
| concept | tier | status | notes |
|---------|------|--------|-------|
| Bubble Wrap (endless satisfying pops) | A | PLANNED | Grid of bubbles, pop with juice+sound, refill, combo. |
| Zen Ripples (tap water, spreading rings) | B | PLANNED | Tap → ripple + tone; purely calming, no fail. |
| Firefly Catch (gentle drift, tap glow) | B | PLANNED | Slow floaters, tap to light, soft score. |

## Shipped this factory sprint
- **Basketball** 🏀 — arcade, deep. Drag-to-aim parabolic shot, dotted trajectory preview,
  side-wall + backboard bank (banked vs swish scoring), rim-knob collisions, moving hoop at
  score ≥4/≥8, 12 baskets to win, `_Shard` celebration burst, SWISH/Bank banner.
  Registered in all 6 sites + smoke test.
