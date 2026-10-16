# WonderPlay Sensory Quality Audit

Date: 2026-10-15

Baseline: `b4acf109a08c7ad8786b177cd724888da25c7489` (`main`, clean at audit start)

Version inspected: `1.0.43+44`

## Evidence boundary

This audit covers every canonical Play game and sensory toy by source inspection, shared-shell behavior, regression tests, analyzer output, and a fresh release APK build.

I cannot physically hear the connected phone. Tone, loudness, and repetition findings below are based on synthesis parameters, cue call sites, cooldowns, and channel-level tests. They are **not** claims that a human listened to every cue. A Pixel 6a install was attempted, but serial `23131JEGR02045` dropped off USB before installation; current-build device behavior and physical audio remain unverified.

## Changes made

- Added persistent **Quiet mode**. It silences effects, narration, and optional music while preserving the family's selected sound/music choices for later restoration.
- Changed the new-install sound default from Normal to **Soft** (`0.35` master scale). Existing stored choices remain unchanged. Music remains off by default.
- Mute and Quiet Mode now stop active pooled effects, game music, Hari voice, Story Reader, Card Deck, Routine Player, and Talk narration immediately.
- Story Reader and Card Deck no longer autoplay speech on entry or page/card navigation. Narration is explicit through the visible read-aloud control.
- Routine Player narration now obeys Off/Soft/Normal, quick mute, and Quiet Mode.
- Ordinary GlassCard navigation and game/toy back controls are silent. Direct Hari/Pico taps remain visual-only.
- Lowered central cue ceilings: interaction/navigation `0.30`, gameplay `0.70`, success/celebration `0.75`, ambient `0.50`.
- Replaced the noise-heavy crash burst with a brief sine thud; softened balloon, metal, laser, pop, click, tick, switch, zipper, whir, thock, and squish synthesis.
- Shortened the game-start fanfare from four notes to two gentle notes and reduced its haptic intensity.
- Preserved expressive piano behavior: direct `playNote` calls remain outside cue-category attenuation and retain pitch/duration variation.
- Routed high-frequency Talk, Learn, Home, Card Deck, Routine, and shared navigation haptics through the stored haptics gate.

## Controls and persistence

| Control | Default | Persistence and behavior |
|---|---:|---|
| Effects and voice | Soft | `audio_level`; Off/Soft/Normal restored through SharedPreferences |
| Quick mute | Off | `audio_muted`; suppresses and stops effects, voice, and music |
| Quiet mode | Off | `quiet_mode`; persistent silence without erasing selected levels |
| Background music | Off | `music_enabled`; starts only during active gameplay, stops on results, exit, background, mute, or Quiet Mode |
| Reduce motion | Off | `reduce_motion`; propagated as `MediaQuery.disableAnimations` |
| Haptics | On | `haptics_enabled`; central game/Talk/Learn paths obey it |

Persistence is regression-tested by creating a new provider container from the same SharedPreferences store, which models app restart. Hardware restart persistence was not verified because the Pixel disconnected.

## Audio-source audit

- `TonePlayer` is the only `AudioPlayer` owner. Effects are synthesized, master-gated, cooldown-limited, and best-effort.
- `GameMusicHost` owns optional loop lifecycle and stops it on app background, result, exit, mute, and Quiet Mode.
- Screen-owned Flutter TTS exists only in Story Reader, Card Deck, Routine Player, and Talk. All four now read the sensory volume, stop on suppression, and expose visual content without requiring speech; Learn and Hari cards use the separately gated `HariVoice` service.
- `HariVoice` gates Learn and Hari-card speech by sensory volume and is stopped from the app root on suppression.
- No `SystemSound` calls or bundled MP3/OGG/WAV playback paths were found.
- Remaining `SoundCue.navigation` calls are only explicit “sound on” confirmations, not route/card/back taps.
- No game autoplay was found. Every game waits behind an explicit start screen.
- Cue cooldowns range from 60 ms for rapid material interactions to 700 ms for milestones/results, limiting same-cue repetition.

## Game-by-game findings

Legend: **RM** means the game has custom reduced-motion tuning in addition to the global setting. **Visual** means progress and correctness remain visible with audio off. Every listed game has an explicit start, visible back/exit, and result/replay state through its shared shell unless noted.

| Game | Sound identity | Silent play | RM |
|---|---|---:|---:|
| Whack | soft impact/retry/result | Visual | No |
| Sky Hop | ball/collect/result | Visual | Yes |
| Stack | placement/retry/result | Visual | No |
| Merge | soft wood/merge/result | Visual | Yes |
| Echo | pentatonic sequence plus pad lights | Visual | No |
| Tic-Tac-Toe | placement/retry/result | Visual | No |
| Brick Break | brick/ball/retry/result | Visual | Yes |
| Space Dodge | collect/soft crash/result | Visual | No |
| Memory Flip | paper flip/retry/result | Visual | Yes |
| Ball Sort | water/placement/result | Visual | No |
| Tap Order | rising notes plus numbered progress | Visual | No |
| Piano Tiles | melody notes plus colored hit flash | Visual | No |
| Block Blast | placement/retry/result | Visual | Yes |
| Bubble Shooter | bubble/pop/result | Visual | Yes |
| Color Quest | correct/gentle retry/result | Visual | No |
| Shape Scout | correct/gentle retry/result | Visual | No |
| Number Splash | correct/gentle retry/result | Visual | No |
| Path Finder | path progress/retry/result | Visual | No |
| Goal Keeper | save/miss/result | Visual | Yes |
| Trace It | stroke pop/completion | Visual | No |
| Quick Tap | optional ready chirp plus color state | Visual | No |
| Pinball | bumper/flipper/result | Visual | Yes |
| Basketball | shot/rim/result | Visual | Yes |
| Mini Golf | putt/rail/result | Visual | Yes |
| Air Hockey | puck/mallet/result | Visual | Yes |
| Target Toss | throw/retry/result | Visual | No |
| Bubble Wrap | softened pop; no-fail | Visual | Yes |
| Drum Garden | musical pads plus pad lights | Visual | No |
| Color Mixer | paint/pop/result | Visual | Yes |
| Fishing | cast/catch/retry | Visual | Yes |
| Maze Run | movement/retry/result | Visual | No |
| Beat Builder | sequenced notes plus lit grid/playhead | Visual | No |
| Catch the Beat | lane notes plus hit-zone grading | Visual | Yes |
| Firefly Count | selection/retry/result | Visual | Yes |
| Sorting Train | load/correct/result | Visual | No |
| Shadow Match | correct/retry/result | Visual | Yes |
| Pattern Weaver | correct/retry/result | Visual | Yes |
| Balloon Math | softened balloon/correct/result | Visual | Yes |
| Dot-to-Dot | short rising notes plus drawn path | Visual | Yes |
| Rhythm Clap | beat notes plus visible playhead | Visual | Yes |
| Shape Builder | short placement melody plus shape fill | Visual | No |
| Memory Pairs Deluxe | paper/match/result | Visual | No |
| Bug Catch | catch/retry/result | Visual | Yes |
| Spot the Difference | correct/retry/result | Visual | Yes |
| Weather Sort | correct/retry/result | Visual | No |
| Maze Marble | marble/rail/result | Visual | Yes |
| Piano Song | guided melody plus glowing next key | Visual | Yes |
| Letter Trace | stroke/completion | Visual | No |
| Soccer Kick | kick/save/result | Visual | Yes |
| Xylophone Tap | expressive diatonic bars plus glow | Visual | No |
| Jigsaw Four | placement/completion | Visual | Yes |
| Counting Baskets | fruit/drop/result | Visual | No |
| Star Path | short notes plus connected path | Visual | No |
| Feelings Match | correct/retry/result | Visual | No |
| Penalty Dash | kick/save/result | Visual | Yes |
| Shape Sort Chute | soft wood/drop/result | Visual | Yes |
| Balloon Bounce | softened bounce/result | Visual | No |
| Count & Pop | softened pop/count/result | Visual | No |
| Mirror Draw | paper/trace/result | Visual | No |
| Calm Breaths | brief calm cue plus visual pacer | Visual | No |
| Hoop Toss | toss/ringer/result | Visual | Yes |
| Echo Drums | drum sequence plus lit pads | Visual | No |
| Slide Puzzle | softened tile tap/result | Visual | Yes |
| Add It Up | correct/gentle retry/result | Visual | No |
| Steady Hand | gentle retry/result | Visual | Yes |
| Kindness Match | correct/gentle retry/result | Visual | No |
| Skee Ball | score-band cue/result | Visual | No |
| Tone Match | matching notes; tapped bells reveal stable matching colors | Visual | Yes |
| Odd One Out | correct/retry/result | Visual | Yes |
| Bigger Number | correct/retry/result | Visual | No |
| Balance Ball | warning/result | Visual | Yes |
| Calm Choices | calm/correct/retry/result | Visual | No |
| Fruit Catch | fruit/catch/result | Visual | Yes |
| Balloon Pop | softened pop/result | Visual | Yes |
| Star Tap | correct/retry/result | Visual | Yes |
| Snake | collect/soft crash/result | Visual | Yes |
| Racing | engine/collect/soft crash/result | Visual | Yes |
| Bowling | low rumble/pins/result | Visual | Yes |

### Shared game findings

- All 78 games can progress with sound disabled; musical/memory games retain visible keys, pad lights, playheads, hit zones, or revealed matching colors.
- None requires a successful audio callback to update state.
- No obvious duplicate identical cue was found in one event branch. Shared cooldowns provide an additional repetition guard.
- All 78 expose back/exit, explicit start, and replay/result controls.
- No shared shell exposes a true mid-session pause. Back exits cleanly, but pause/resume remains a product gap.
- 41 of 78 have custom reduced-motion particle/speed tuning. The remaining 37 receive the global reduced-motion flag but do not explicitly reduce their custom ticker/particle behavior.

## Sensory-toy findings

| Toy | Audio behavior | Silent use |
|---|---|---:|
| Bubble Pop World | softened pop, cooldown-gated | Yes |
| Particle Galaxy | visual/tactile focus | Yes |
| Water Ripples | soft ripple/water cue | Yes |
| Fireworks Touch | brief musical cue with visual burst | Yes |
| Paint With Light | soft paint texture | Yes |
| Sand Garden | low granular sand texture | Yes |
| Magnetic Balls | softened material contact | Yes |
| Fluid Simulator | soft water interaction | Yes |
| Sensory Lava Lamp | visual-first | Yes |
| Kaleidoscope Mirror | visual-first | Yes |
| Music Garden | expressive pentatonic flowers; intentionally preserved | Yes, visually interactive |
| Fidget Cube Digital | softened click/thock/tick/switch vocabulary | Yes |
| Calm Clouds | visual-first gentle interaction | Yes |
| Rainbow Rain | soft water/musical feedback | Yes |
| Slime Stretch | softened low squish | Yes |
| Color Mixing Lab | soft paint feedback | Yes |
| Car Track Builder | softened engine/material feedback | Yes |
| Spin Universe | softened whir | Yes |
| Infinite Marble Run | brief softened marble contact | Yes |
| Pocket Picnic | short contextual placement cues | Yes |

All toy audio routes through `TonePlayer`, so Off, Soft, quick mute, and Quiet Mode apply. No toy audio source bypassing the master scale was found. Direct physical tone quality was not listened to.

## Validation

- Focused Story Reader tests: 2 passed.
- Focused narration/life-skills tests: 5 passed.
- Sensory preference/audio-policy focused suite: passed after updating the Soft-default expectation.
- Full Flutter suite after final code changes: **201 passed**.
- Analyzer: **0 errors, 0 warnings, 130 informational lints**.
- Fresh release APK: `build/app/outputs/flutter-apk/app-release.apk`, 64.5 MB build output.
- Existing nonfatal Jigsaw Four drag hit-test warning remains in the test suite.

## Device checks

Attempted on Google Pixel 6a serial `23131JEGR02045` using the fresh release APK. ADB returned no connected devices and the install wait was terminated. Therefore this audit does **not** claim current-build device installation, actual audio listening, hardware haptic strength, UI control persistence after a physical restart, or logcat validation.

## Remaining risks and next checks

1. A human listener should audition Soft and Normal on the Pixel speaker and headphones, focusing on crash, balloon, metal, start, success, game-over, rapid bubble-pop, fidget tick, and Piano Tiles/Music Garden dynamics.
2. Device QA should verify Quiet Mode, mute, music, reduced motion, and haptics after force-stop/relaunch and reboot.
3. Add custom reduced-motion tuning to the remaining 37 games, prioritizing continuously animated and particle-heavy games.
4. Add a shared pause/resume affordance to the three game shells without changing score or timers while paused.
5. Many legacy non-Play screens and older antistress/sensory-lab widgets still call `HapticFeedback` directly. The high-frequency Play/Talk/Learn/Home paths were fixed here, but full haptic-policy migration remains incomplete.
6. The third-party `flutter_tts` Android plugin still emits the known future Built-in Kotlin migration warning during release builds.
