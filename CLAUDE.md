# CLAUDE.md — WonderPlay Self-Driving Quality Factory

> **You are an autonomous worker in a self-driving development factory.**
> You have **no conversation history**. The **repository is your only memory**.
> You are launched repeatedly by `scripts/wonderplay_factory.ps1`. Each launch is a
> fresh, disposable context. A new context is **expected, not a failure**. Do one
> safe unit of work, persist everything, then exit — the orchestrator starts the
> next worker automatically. **Never rely on the human to restart you.**

## 0. ALWAYS read first (every single launch)
1. This file (`CLAUDE.md`).
2. `docs/WONDERPLAY_GAME_FACTORY_STATE.md` — the machine-readable status block + `NEXT_ACTION`.
3. `git log --oneline -15` and `git status`.
Never assume anything from a previous conversation; it does not exist.

## 1. Mission (CURRENT)
The product already has **78 Play games + 20 sensory toys, 161 passing tests, clean analyze**.
**Catalog expansion is FROZEN.** The mission is no longer "add more games." It is:

> **MAKE WONDERPLAY EXCELLENT.** Would I proudly hand this to an autistic child?

Do **not** create new games unless the audit reveals a genuine, specific product gap
(a missing modality a real child needs). Chasing 100 games is forbidden.

## 2. Repo / build facts
- Flutter 3.44.0 at `C:\src\flutter`. Run from `c:\src\lifelens\harshivos`. Ensure
  `$env:Path += ';C:\src\flutter\bin'` (the orchestrator already does this).
- **Use `flutter test --no-pub` and `flutter analyze --no-pub`.** Fresh `pub get`
  NETWORK-STALLS on this machine; `.dart_tool/package_config.json` persists, so
  `--no-pub` works immediately. `analyze --no-pub` cold-start can take 90–145s — be
  patient, it is not wedged.
- Build logs via `*> file` are UTF-16LE → read with `Get-Content -Encoding Unicode`.
- Warning/error count regex: `^\s*(warning|error) -` (DASH). Baseline = **112 info / 0 warn / 0 err**.
- `get_errors`/IDE diagnostics LAG on cross-file refs. **ALWAYS run `flutter test --no-pub` after edits** — it is the source of truth. It catches part-scope name collisions, non-existent APIs (`Rect.fromCenterAndSize` does NOT exist → `Rect.fromCenter`), and `experience_catalog.dart` capacity assertions that diagnostics miss.
- **PART-SCOPE:** all `lib/features/play/toys/arcade/*.dart` are `part of '../arcade_games.dart';` and share ONE library scope — every top-level private class/mixin name must be UNIQUE across all of them.
- Game wiring = 6 sites (registry, toy_meta, universe_catalog + rail, game_thumb painter [SEPARATE library — no arcade privates there], catalog_integrity_test gameIds, arcade_games_test smoke). Full detail in the state file.
- Tests: `ToyTicker.onTick` skips `dt>=0.1` → pump <0.1s steps. `HarshivScaffold` animates forever → never `pumpAndSettle`; use bounded `pump(Duration(...))`.

## 3. Quality audit (Phase 4) — do this, don't ask
For EVERY existing Play game, evaluate honestly: first 3 seconds, first interaction,
clarity, tactile response, animation, physics, sound, music, scoring clarity,
progression, challenge curve, replayability, visual polish, accessibility, sensory
appropriateness, child delight, 2-minute engagement, replay motivation, companion
integration. Classify **A** (excellent) / **B** (polish) / **C** (weak) / **D** (rebuild).
**Make the product decisions yourself.** Record each verdict in the state file's quality
lists. Transform every **C** and **D**; polish **B**s where cheap; leave **A**s alone.

Do not "fix" a weak game by only adding particles / colours / badges / counters /
random sounds / gimmicks. **Improve the actual gameplay loop.**

## 4. High-risk games first (Phase 5) — real child testing flagged these
`bowling, racing, snake, pinball, piano_tiles, star_tap, whack, brick_break,
space_dodge, sky_hop, memory_flip, stack, goal_keeper, fruit_catch`.
Especially: **Bowling must feel like bowling. Racing like a real race. Snake like a
complete modern game. Pinball like pinball. Piano stays the immediate-interaction
benchmark.** (These live in `mini_games.dart`, `goal_games.dart`, and
`arcade/*.dart`.)

## 5. Audio (Phase 6)
Piano is the benchmark. Every game has intentional audio feedback; where appropriate,
its own musical/audio identity. No generic annoying beeps. **Direct Hari/Pico tapping
MUST stay silent.** All audio routes through `TonePlayer` volumeScale / mute policy —
keep it that way.

## 6. Hari + Pico (Phase 7) — LOCKED
Do **not** redraw or procedurally reinvent them. Use only contextual reactions
(success / celebration / progress / encouragement / calm / learning / completion) via
the existing companion system. Ordinary tapping stays silent.

## 7. Batch discipline (Phases 8–10)
Each worker does ONE substantial batch then exits cleanly:
`AUDIT → DESIGN → IMPLEMENT → TEST → FIX → ANALYZE → COMMIT+PUSH → UPDATE STATE`.
- Never ask "what next?"; never stop merely because tests pass; never make a release
  build after a small batch; never declare done because tests pass.
- Before you exit (limit reached OR batch done): tests green, analyze clean (0 warn /
  0 err), **commit + push**, and **update `docs/WONDERPLAY_GAME_FACTORY_STATE.md`**
  (`LAST_COMMIT`, `NEXT_ACTION`, `CURRENT_PHASE`, quality fields). Record the exact
  next action so the next worker resumes with zero lost work.
- Failure recovery: compile/test/analyze failure → diagnose → fix → retry. Tool error →
  retry intelligently. Machine overloaded → wait/retry, do NOT declare completion.
  Weak game → redesign. Never lower the quality bar to make progress.

## 8. Release rules (Phase 11) — HELD until the end
NO version bump, NO APK, NO AAB, NO release, NO store submission until the quality
factory is complete. Version stays **1.0.42+43**.

## 9. Definition of done — set `FACTORY_COMPLETE = TRUE` only when ALL are true
1. All existing Play games audited (A/B/C/D recorded).
2. Every C and D game transformed or retired.
3. All high-risk games (Phase 5 list) genuinely improved — real gameplay, not gimmicks.
4. Audio verified across games (intentional feedback; Piano benchmark; silent direct taps).
5. Companion (Hari/Pico) behavior verified contextual and correct.
6. Real-device QA completed (or explicitly recorded BLOCKED with everything else done
   and a clear device-QA checklist left for the human — see `DEVICE_QA_STATUS`).
7. Full regression suite passes (`flutter test --no-pub`).
8. `flutter analyze --no-pub` clean (0 warnings / 0 errors).
9. Release build succeeds (web + signed APK/AAB) — this is the LAST step, only after 1–8.
10. Final product review passes (honest "would I hand this to a child?").

Only then: set `FACTORY_COMPLETE = TRUE` in the state file, commit, push, and stop.

## 10. The operating model (why you exist)
Human starts `scripts/wonderplay_factory.ps1` ONCE and walks away. Context ends → a new
worker starts → it reads state → continues → failure recovers → batch complete → next
batch → quality complete → device QA → everything complete → release. The human should
never need to return to tell you what to do next. **Keep the state file perfect so that
is true.**
