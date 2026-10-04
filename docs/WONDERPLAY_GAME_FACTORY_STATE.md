# WonderPlay — Game Factory State

**Mandatory resume file.** On a new context: READ `CLAUDE.md` FIRST, then this file, then `git log`/`git status`. Resume from `NEXT_ACTION`. Never restart the sprint. Never rely on conversation history.

<!-- ============================================================ -->
<!-- FACTORY STATUS — machine-readable. EVERY worker MUST update   -->
<!-- this block before exiting. scripts/wonderplay_factory.ps1     -->
<!-- greps the FACTORY_COMPLETE line here to decide whether to stop.-->
<!-- ============================================================ -->
## FACTORY STATUS

```
CURRENT_PHASE:     4 ? QUALITY AUDIT & TRANSFORM (catalog expansion FROZEN)
CURRENT_GAME:      path_finder (was a genuine QUALITY_D: the "maze" was one hardcoded static route — `[20,15,16,11,6,7,8,3,4]` — identical on every single playthrough, zero replayability after the first solve. Rebuilt with a self-avoiding random-walk maze generator so every game/replay is a brand-new 5x5 route, plus a level counter that lengthens the path (9→16 cells) each time the child wins, giving it a real difficulty curve instead of rote memorisation.)
CURRENT_BATCH:     catalog-audit-batch-1 (audited 10 non-high-risk games: merge, echo, tictactoe, ball_sort, tap_order, block_blast, bubble_shooter, trace_it, quick_tap, path_finder. 9/10 already A-quality; path_finder was D and was transformed this batch.)
COMPLETED_WORK:    78 Play games + 20 sensory toys built (rounds 1-4); arcade_games.dart refactored into per-game part files; self-driving factory infra built (CLAUDE.md + scripts/wonderplay_factory.ps1, Copilot CLI headless verified); high-risk quality pass recorded for bowling, racing, snake, pinball, piano_tiles, star_tap, whack, brick_break, space_dodge, sky_hop, memory_flip, stack, goal_keeper, fruit_catch (all now QUALITY_A); broad catalog audit started — path_finder rebuilt from a static single maze to a randomised, level-scaling maze generator.
AUDITED_GAMES:     14 high-risk games (all QUALITY_A) + 10 more from the general catalog this batch: merge, echo, tictactoe, ball_sort, tap_order, block_blast, bubble_shooter, trace_it, quick_tap (all QUALITY_A as-is), path_finder (was QUALITY_D, transformed to QUALITY_A this batch). ~54 games in the catalog remain unaudited — see NEXT_ACTION.
QUALITY_A:         bowling, racing, snake, pinball, goal_keeper, star_tap, fruit_catch, piano_tiles, sky_hop, whack, brick_break, memory_flip, stack, space_dodge, merge, echo, tictactoe, ball_sort, tap_order, block_blast, bubble_shooter, trace_it, quick_tap, path_finder
QUALITY_B:         (none currently recorded)
QUALITY_C:         (none currently recorded)
QUALITY_D:         (none currently recorded — path_finder was the one D found and it has been transformed to A this batch)
KNOWN_DEFECTS:     none open from code or regression testing. Audio QA and device QA remain; 24 of ~78 games now have a recorded audit verdict — continue the broad catalog audit (NEXT_ACTION) for the rest.
FACTORY_BLOCKER:   none. Previously recorded AI model budget exhaustion was an orchestrator-loop concern, not a code/quality blocker; this batch completed normally with credits available.
ORCHESTRATOR:      HARDENED. scripts/wonderplay_factory.ps1 now HALTS-and-diagnoses on fatal worker failures (quota/credits/auth/missing-binary via Get-WorkerFatalReason) instead of looping. Separates FAILURE (exit!=0, FailLimit=3) vs STALL (exit0 no commit, StallLimit=4); removed the old pause-5min-then-loop-forever burn loop; writes _factory_logs/FACTORY_HALTED.txt on halt.
DEVICE_QA_STATUS:  BLOCKED (Pixel 6a off USB; needs physical replug). Record a device-QA checklist; do not let this block code/quality work.
AUDIO_QA_STATUS:   NOT_STARTED (Piano = benchmark; verify every game has intentional audio; direct Hari/Pico taps silent).
LAST_COMMIT:       (pending — see git log after this batch's commit)
NEXT_ACTION:       24 games now have a recorded Phase-4 verdict (14 high-risk + 10 this batch); path_finder's single-static-maze defect was the only D found so far and is fixed. Continue broadening the audit to the remaining ~54 games (see toy_registry.dart `toyBuilders` for the full id list; skip the 20 sensory/antistress toys which are open-ended and not scored). Good next candidates (not yet audited): color_quest, shape_scout, number_splash, goal-games `_ChoiceGoalGame`-based toys, air_hockey, target_toss, bubble_wrap, drum_garden, color_mixer, fishing, maze_run, beat_builder, catch_beat, firefly_count, sorting_train, shadow_match, pattern_weaver, balloon_math, dot_to_dot, rhythm_clap, shape_builder, memory_deluxe, bug_catch, spot_difference, weather_sort, maze_marble, piano_song, letter_trace, soccer_kick, xylophone_tap, jigsaw_four, counting_baskets, star_path, feelings_match, penalty_dash, shape_sort_chute, balloon_bounce, count_pop, mirror_draw, calm_breaths, hoop_toss, echo_drums, slide_puzzle, add_it_up, steady_hand, kindness_match, skee_ball, tone_match, odd_one_out, bigger_number, balance_ball, calm_choices. Pick a handful per batch, evaluate honestly against the Phase-4 criteria in CLAUDE.md (first 3 seconds, clarity, tactile response, scoring, progression, replayability, etc. — the path_finder bug shows "hardcoded content with no randomisation = zero replayability" is a real recurring risk pattern to check for). Record A/B/C/D verdicts here, and transform any C/D found. Do not build new games (catalog expansion is FROZEN).
FACTORY_COMPLETE:  FALSE
```

> **How to run the factory (human, once):**
> `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/wonderplay_factory.ps1`
> It launches a fresh Copilot worker, lets it do a safe batch, then relaunches
> automatically — forever — until `FACTORY_COMPLETE: TRUE` above. See `CLAUDE.md`
> for the permanent operating rules and the Phase-11 definition of done.

- **HEAD at last update:** (pending — see git log after this batch's commit) (Path Finder randomised-maze fix + catalog audit batch 1)
- **Version:** 1.0.42+43 (HELD — no bump during factory; release builds are LAST)
- **Updated:** 2026-10-04
- **Tests:** 161 pass · **Analyze:** 115 info / 0 warnings / 0 errors
- **Catalog:** 78 games + 20 sensory toys
- **REFACTOR_COMPLETE:** true — `arcade_games.dart` is now a thin library shell (imports + 39 `part 'arcade/<name>_game.dart';` directives + shared `_Shell`/`_Emit`). Each game lives in its own file under `lib/features/play/toys/arcade/`. All files share ONE library scope via `part`/`part of`, so private symbols (`_Shard`@brick_break, `_paintPolyShape`@sorting_train) stay visible with ZERO renames and ZERO behavior change. **To add a game:** create `lib/features/play/toys/arcade/<name>_game.dart` starting with `part of '../arcade_games.dart';` (NO imports in part files), add one `part 'arcade/<name>_game.dart';` line to `arcade_games.dart`, keep shared infra in `arcade_games.dart`. Then wire the 6 sites. No need to load the monolith anymore.
- **Note:** build machine pub-get NETWORK-STALLS hard on fresh terminals (file stuck 2642 bytes). `.dart_tool/package_config.json` persists on disk across sessions, so `flutter test --no-pub` / `flutter analyze --no-pub` work even in a FRESH terminal — use them directly, do NOT wait on pub get. `flutter analyze --no-pub` itself can take 8s–100s depending on machine load. ToyCategory = {sensory,fidget,arcade,creative,calm,learning,communication,lifeSkills} (NO 'puzzle'). ToyEngagement = {endless,deep,quick}. COMMON WARNING: a declared-but-unread field (e.g. `_turn`, `_rnd`) in a new game → remove it.
- **PART-SCOPE GOTCHA (critical):** every part file shares ONE library scope, so ALL top-level private names (classes/mixins) must be UNIQUE across every `arcade/*.dart` file. A new game's painter/helper CANNOT reuse a name already used by another game (e.g. `_BasketPainter` collided between basketball + counting_baskets). get_errors does NOT catch this; `flutter test` fails with "'_X' is already declared in this scope". Name painters distinctly (`_SoccerPainter`, `_FruitBasketPainter`, `_StarPathPainter`, ...).
- **Device QA:** BLOCKED (phone off USB since sprint #3; needs physical replug). Not sprint-ending — continue implementation; run accumulated QA when device returns.

## Build/terminal facts (critical)
- Flutter 3.44.0 at C:\src\flutter; run from `c:\src\lifelens\harshivos` with `$env:Path += ';C:\src\flutter\bin'`.
- Machine SEVERELY overloaded: full `flutter test` ~15s but `flutter analyze` ~7–100s; sync terminals WEDGE after builds (return no output) — recover with a fresh **async** `run_in_terminal`.
- Build logs via `*> file` are UTF-16LE → read with `Get-Content -Encoding Unicode`.
- Analyze warning/error count: match `^\s*(warning|error) -` (DASH, not bullet •). The bullet regex prior sprints used was WRONG and hid real warnings.
- `get_errors` lags on cross-method refs → ALWAYS `flutter test` after multi-edit.
- Timer-free one-shot pop = `TweenAnimationBuilder` keyed to a state string (no pending-timer test failures). Avoid `Future.delayed` in game states.
- ToyTicker `onTick(dt)` skips dt>=0.1 → tests must pump <0.1s / 90ms steps.

## New-game wiring = 6 sites (every new game)
1. Implementation in the right toys file (`arcade_games.dart` / `mini_games.dart` / `goal_games.dart`) — ToyTicker + `_Emit` juice + `_Shell` start card.
2. `lib/features/play/toy_registry.dart` — `toyBuilders` entry.
3. `lib/models/toy_meta.dart` — ToyMeta (`implemented: true`).
4. `lib/features/universe/universe_catalog.dart` — UniverseToy + add to a discovery rail (e.g. `arcadeToys()`).
5. `lib/features/universe/game_thumb.dart` — `painted` Set id + switch case + `_<id>` thumbnail painter.
6. `test/catalog_integrity_test.dart` gameIds + `test/arcade_games_test.dart` smoke test.
`catalog_integrity_test` requires each gameId: in toyBuilders + kToyUniverseById(working) + kToyCatalog(implemented) + listed in gameIds.

## Existing catalog (source of truth = toyBuilders) — 30 GAMES
All transformed across sprints 1–3 (see docs/GAME_QUALITY_WAR_ROOM.md) + Basketball/Mini Golf this sprint.

| game | status | notes |
|------|--------|-------|
| fruit_catch | VERIFIED | catch-splash particles, gold/combo/bombs |
| balloon_pop | VERIFIED | pop-burst particles, gold/bomb/combo |
| star_tap | VERIFIED | rainbow +5, quick bonus, on-fire combo, red decoys, wave shooting-stars |
| snake | VERIFIED(device) | slither + AI worms + gold orbs + combos + particle juice + boost glow |
| racing | VERIFIED(device) | real 1000m race, finish line, 3 rivals, placement, non-fatal shunts |
| bowling | VERIFIED(device) | perspective lane, flick-to-bowl, topple chain, 10 frames |
| whack | TRANSFORMED | bombs, combo, splat burst, milestone cheers 10/25/50 |
| sky_hop | TRANSFORMED | coins per pipe, flap puffs |
| stack | TRANSFORMED | perfect-drop streak + drop-impact shards |
| merge | TRANSFORMED | tile pop + new-best milestones |
| echo | TRANSFORMED | tap-flash input feedback + progress |
| tictactoe | TRANSFORMED | child-friendly AI, win-line highlight, placement pop |
| brick_break | TRANSFORMED | shatter shards |
| space_dodge | TRANSFORMED | gems + shield pickup, thruster trail, collect bursts |
| memory_flip | TRANSFORMED | 5 levels, growing board, match pop |
| ball_sort | TRANSFORMED | landing pop |
| tap_order | TRANSFORMED | completion pop per number |
| piano_tiles | TRANSFORMED | pentatonic melody, pitch tiles, column flash |
| block_blast | TRANSFORMED | placement pop |
| bubble_shooter | TRANSFORMED | flood-fill match-3, pop particles |
| color_quest | TRANSFORMED | real colour swatches, wrong-tile flash, collection tray, quick bonus |
| shape_scout | TRANSFORMED | 8-shape pool visual search, wrong flash |
| number_splash | TRANSFORMED | subtraction from round 3, wrong flash |
| path_finder | TRANSFORMED | step completion pop |
| goal_keeper | VERIFIED(device) | REBUILT read-and-dive keeper, 5 lives, 10 saves |
| trace_it | TRANSFORMED | fine-motor dotted shapes, chime + transition pop |
| quick_tap | TRANSFORMED | reaction timer, result phase with rating |
| pinball | VERIFIED(device) | physics bumpers/flippers/drain, 3 balls, spark bursts |
| basketball | TRANSFORMED | NEW this sprint — drag-aim, bank vs swish, moving hoop, 12 to win |
| mini_golf | TRANSFORMED | NEW this sprint — flick-putt, rails + obstacle, lip-out, 9 holes |

Plus 20 sensory/antistress toys (bubble_pop, particle_galaxy, water_ripples, fireworks, paint_light, sand_garden, magnetic_balls, fluid_sim, lava_lamp, kaleidoscope, music_garden, fidget_cube, calm_clouds, rainbow_rain, slime, color_mix, car_track, spin_universe, marble_run, snack_studio).

### EXISTING_CATALOG_COMPLETE
All 30 games meet the gameplay quality bar (clear in 5s · satisfying in 30s · evolves in 2min · real again-loop · feedback · scoring · progression · WonderPlay character). 6 device-verified; rest test-verified (device QA blocked). New-game factory UNLOCKED.

## New-game factory backlog
| game | category | file | status |
|------|----------|------|--------|
| Basketball | sports | arcade_games.dart | SHIPPED (b89288c) |
| Mini Golf | sports | arcade_games.dart | SHIPPED (21f59f8) |
| Air Hockey | sports | arcade_games.dart | SHIPPED (05189c6) |
| Target Toss | sports | arcade_games.dart | SHIPPED (05189c6) |
| Bubble Wrap | calm/sensory | arcade_games.dart | SHIPPED (05189c6) |
| Drum Garden | music | arcade_games.dart | SHIPPED (ac99155) |
| Color Mixer | creative | arcade_games.dart | SHIPPED (ac99155) |
| Fishing | sports/calm | arcade_games.dart | POLISHED (tests green) |
| Maze Run | puzzle | arcade_games.dart | POLISHED (tests green) |
| Beat Builder | music | arcade_games.dart | SHIPPED (b9978ee) |
| Catch the Beat | rhythm | arcade_games.dart | SHIPPED (b9978ee) |
| Firefly Count | learn/number | arcade_games.dart | POLISHED (tests green) |
| Sorting Train | learn/sort | arcade_games.dart | POLISHED (tests green) |
| Shadow Match | match/visual | arcade_games.dart | POLISHED (tests green) |

## Next backlog (auto-generated)
1. ~~Pattern Weaver~~ SHIPPED
2. ~~Balloon Math~~ SHIPPED
3. ~~Dot-to-Dot~~ SHIPPED
4. ~~Rhythm Clap~~ SHIPPED
5. ~~Shape Builder~~ SHIPPED
6. ~~Memory Pairs Deluxe~~ SHIPPED
7. ~~Bug Catch~~ SHIPPED
8. ~~Spot the Difference~~ SHIPPED
9. ~~Weather Sort~~ SHIPPED
10. ~~Maze Marble~~ SHIPPED (maze_marble, 🔵 — drag to roll a physics marble through the gate in each wall to the goal cup, 6 boards)
11. ~~Piano Song~~ SHIPPED (piano_song, 🎹 — follow the lit key to play a whole nursery tune, 3 songs)
12. ~~Letter Trace~~ SHIPPED (letter_trace, ✍️ — drag along the dotted path to trace a letter/number, 5 glyphs)

## Next backlog (auto-generated, balanced)
1. ~~Soccer Kick~~ SHIPPED (soccer_kick, ⚽ — drag-back slingshot free kick vs a reading keeper, 10 goals / 5 misses)
2. ~~Xylophone Tap~~ SHIPPED (xylophone_tap, 🎵 — 8 rainbow bars, guided glowing tune, 3 songs)
3. ~~Jigsaw Four~~ SHIPPED (jigsaw_four, 🧩 — drag fragments of a procedural scene into slots, 2x2→3x3, 3 pictures)
4. ~~Counting Baskets~~ SHIPPED (counting_baskets, 🧺 — drag exactly N fruits into the numbered basket, 10 rounds)
5. ~~Star Path~~ SHIPPED (star_path, ⭐ — drag star-to-star in order to draw constellations, 5 shapes)
6. ~~Feelings Match~~ SHIPPED (feelings_match, 😊 — tap the face that matches the feeling word, 3 lives, 10 right)

## Next backlog (auto-generated, balanced) — round 2
1. ~~Penalty Dash~~ SHIPPED (penalty_dash, 🥅 — tap to shoot when the striker marker is clear of the sweeping keeper, 10 goals / 5 misses)
2. ~~Balloon Bounce~~ SHIPPED (balloon_bounce, 🎈 — tap the balloon to bop it up before it hits the floor, 20 bounces; replaced the Simon-duplicate Memory Melody)
3. ~~Shape Sort Chute~~ SHIPPED (shape_sort_chute, 🔻 — drag the falling shape into the matching hole, reuses shared _paintPolyShape, 3 lives, 12 to win)
4. ~~Count & Pop~~ SHIPPED (count_pop, 🔢 — pop exactly the asked number of drifting bubbles, 10 rounds, no-fail)
5. ~~Mirror Draw~~ SHIPPED (mirror_draw, 🎨 — trace the left-half dots, mirrors to the right into a symmetric picture, 5 patterns)
6. ~~Calm Breaths~~ SHIPPED (calm_breaths, 🫧 — ToyTicker breath cycle inhale/hold/exhale, follow the growing circle, 5 breaths, no-fail, rankByScore:false)

## Next backlog (auto-generated, balanced) — round 3
1. ~~Hoop Toss~~ SHIPPED (hoop_toss, 🎪 — tap to toss the ring, time the sliding peg under it, 10 ringers / 5 misses)
2. ~~Echo Drums~~ SHIPPED (echo_drums, 🪘 — Simon memory: watch the drum phrase, tap it back, grows to 8, 3 lives)
3. ~~Slide Puzzle~~ SHIPPED (slide_puzzle, 🔀 — 3x3 sliding tiles, order 1-8, 3 boards)
4. ~~Add It Up~~ SHIPPED (add_it_up, ➕ — tap two number tiles that sum to the target, 3 lives, 10 to win)
5. ~~Steady Hand~~ SHIPPED (steady_hand, 🖐️ — drag a dot along a winding corridor without touching walls, point-to-segment distance, 3 paths)
6. ~~Kindness Match~~ SHIPPED (kindness_match, 💛 — read a situation, tap the kind response, 10 scenes, 3 lives)

## Next backlog (auto-generated, balanced) — round 4
1. ~~Skee Ball~~ SHIPPED (skee_ball, 🎳 — drag up to roll the ball up the ramp, power → landing ring, reach 100 pts)
2. ~~Tone Match~~ SHIPPED (tone_match, 🔔 — auditory memory pairs: identical bells, match by sound, 4 pairs)
3. ~~Odd One Out~~ SHIPPED (odd_one_out, 🧐 — tap the different shape/colour, grid grows, 3 lives, 10 to win)
4. ~~Bigger Number~~ SHIPPED (bigger_number, 🥇 — tap the biggest OR smallest number of 3, range grows, 3 lives, 12 to win)
5. ~~Balance Ball~~ SHIPPED (balance_ball, ⚖️ — ToyTicker; drag to tilt the beam, keep the ball from rolling off, wobble grows, survive 20s)
6. ~~Calm Choices~~ SHIPPED (calm_choices, 🌈 — read a big feeling, tap a healthy coping choice, 10 self-reg scenes, 3 lives)

## Catalog expansion — FROZEN (2026-10-04)
The product mission changed from "add more games" to "make WonderPlay excellent".
**Do NOT build round 5 or chase 100 games.** The round-5 ideas below are PARKED and
only to be revisited if the Phase-4 audit finds a genuine missing modality a real child
needs. The authoritative next step is the `NEXT_ACTION` in the FACTORY STATUS block at
the top of this file + `CLAUDE.md`.

### Parked ideas (NOT scheduled)
Archery · Sound Story · Pipe Connect · Subtraction Pop · Laser Maze · Good Manners

## NEXT EXACT ACTION
See the **FACTORY STATUS → NEXT_ACTION** block at the top of this file (Phase 4 quality
audit). Read `CLAUDE.md` for the permanent rules and the Phase-11 definition of done.
Do NOT build new games.
