# WonderPlay — Game Quality War Room

Persistent backlog for the game-quality sprint. **Resume rule:** read this file first,
continue from the first game that is not `VERIFIED`/`TRANSFORMED`. Never restart the catalog.

Statuses: `NOT_STARTED` · `IN_PROGRESS` · `TRANSFORMED` (passes the quality gate) · `VERIFIED` (device-checked).

Quality gate (every game): clear in 5s · satisfying in 30s · evolves in 2min · meaningful "again" loop ·
responsive touch/sound/visual feedback · clear scoring · real progression · WonderPlay character.

## Catalog (discovered from code — 28 Play games)

### mini_games.dart
| id | name | status | notes |
|----|------|--------|-------|
| bowling | Ten-Pin Bowling | TRANSFORMED | Perspective lane, flick-to-bowl, topple chain, 10 frames. Device-verified. |
| racing | Street Racer | TRANSFORMED | Real race: 1000m track, finish line, 3 rivals, placement, non-fatal shunts. Device-verified. |
| snake | Snake · Orbs | TRANSFORMED | Slither + AI worms + gold orbs + combos + particle juice + boost glow. Device-verified. |
| star_tap | Star Catch | TRANSFORMED | Gold +3, rainbow +5, Quick! timing bonus, on-fire combo, wave shooting-stars. |
| fruit_catch | Fruit Catch | TRANSFORMED | Catch-splash particles + gold/combo/bombs. |
| balloon_pop | Balloon Pop | TRANSFORMED | Pop-burst particles + gold/bomb/combo. |

### goal_games.dart
| id | name | status | notes |
|----|------|--------|-------|
| goal_keeper | Goal Keeper | TRANSFORMED | REBUILT: real goal, keeper slides to read+dive a flying ball; curve shots, lives, streaks, sparks. Needs device QA. |
| color_quest | Color Quest | TRANSFORMED | Now real COLOR SWATCHES (tap a colour, not a word) + wrong-tile red flash. |
| shape_scout | Shape Scout | TRANSFORMED | Wrong-tile red flash; visual glyph matching. |
| number_splash | Number Splash | TRANSFORMED | Wrong-tile red flash. |
| path_finder | Path Finder | NOT_STARTED | Review. |

### arcade_games.dart
| id | name | status | notes |
|----|------|--------|-------|
| pinball | Pinball | TRANSFORMED | New physics game: bumpers, flippers, drain, 3 balls, spark bursts. Device-verified. |
| whack | Whack | IN_PROGRESS | Added splat burst. Review depth. |
| brick_break | Brick Break | IN_PROGRESS | Added shatter shards. Review. |
| space_dodge | Space Dodge | IN_PROGRESS | Added thruster + collect bursts. Review. |
| bubble_shooter | Bubble Shooter | IN_PROGRESS | Added pop particles. Review. |
| sky_hop | Sky Hop | IN_PROGRESS | Added coin sparkles + flap puffs. Review. |
| piano_tiles | Piano Tiles | TRANSFORMED | Tiles carry a pentatonic melody (tap = play a tune), pitch-coloured tiles, column hit-flash. |
| stack | Stack | NOT_STARTED | Has perfect-streak; review. |
| echo | Echo | REVIEWED | Simon-says; functional pad flash + tone. Low priority. |
| merge | Merge | REVIEWED | 2048-style; functional, HSV tiles + merge sound. Low priority. |
| tic_tac_toe | Tic-Tac-Toe | TRANSFORMED | Placement pop, distinct AI sound, winning-line gold highlight. |
| memory_flip | Memory Flip | TRANSFORMED | Match pop (easeOutBack) + gold glow border on matched pairs. |
| tap_order | Tap Order | TRANSFORMED | Pop as each number completes + existing wrong-cell red flash. |
| memory_flip | Memory Flip | DONE above | |
| ball_sort | Ball Sort | REVIEWED | Functional: tube lift, water sound, clear celebration. Low priority. |
| tap_order | Tap Order | DONE above | |
| block_blast | Block Blast | NOT_STARTED | No ticker; needs retrofit for clear-burst. |
| quick_tap | Quick Tap | NOT_STARTED | Reaction game; review. |

### trace_game.dart
| id | name | status | notes |
|----|------|--------|-------|
| trace_it | Trace It | NOT_STARTED | Fine-motor; review. |

## Priority deep rebuilds
1. Racing — DONE (TRANSFORMED)
2. Goal Keeper — DONE this batch (TRANSFORMED)
3. Bowling — DONE (TRANSFORMED)
4. Snake — DONE (TRANSFORMED)
5. Pinball — DONE (TRANSFORMED)
6. Star Catch — DONE (TRANSFORMED)
7. Piano/Music — Piano Tiles TRANSFORMED; Music Garden (free-play) VERIFIED-GOOD, preserved.

## Shared systems in place
Start card (all shell games) · gameStart fanfare · opt-in ambient music (mute-gated) ·
result overlay + "Back to games" · progression XP hook · particle primitives `_Shard`/`_Particle`/`_Spark`.

## Rules for this sprint
NO version bump · NO release AAB/APK · targeted tests + analyze + device QA only, until catalog substantially done.
