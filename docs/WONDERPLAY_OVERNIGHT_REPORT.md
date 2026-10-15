# WonderPlay Overnight Ship Report

Date: 2026-10-15

## Ship status

WonderPlay is ready for internal release testing. This sprint made one focused gameplay correction, added regression coverage, passed the full validation gates, produced fresh signed Android artifacts and a web release, and completed release-device QA on a Pixel 6a.

- Starting HEAD: `c777cdec51a742903260213d9248c572d971732f`
- Starting remote: `origin/main` at the same commit
- Final code HEAD before this report commit: `c777cdec51a742903260213d9248c572d971732f`
- Final shipped HEAD: the commit containing this report; verify with `git rev-parse origin/main` after push
- Version: `1.0.43+44`
- Application ID: `com.darshankansara.harshivos`
- Release label: `WonderPlay`

## Repository and factory diagnosis

The real product repository is `C:\src\lifelens\harshivos` on `main`. It began clean, with no staged or unstaged files, stash, nested repository, submodule, or competing WonderPlay factory process. The old `wonderplay_factory.ps1` loop was not launched.

The previously reported large change set was not an active dirty product diff. The parent repository pins Harshivos at historical commit `c5297d47f84f299f5029f07b33674935cc753f01`, while the child repository began this sprint at `c777cde`. Expanding that stale parent gitlink produces the historical 151-file, 26,553-insertion, 3,689-deletion range. No catalog expansion was performed.

## Product change

Color Quest, Shape Scout, and Number Splash previously started first-round response timing while their instruction card was still visible. A child who paused to read the instructions could therefore lose the 2.2-second quick-answer reward before pressing Play.

The shared goal-game start callback now records the first round's start time when Play is pressed. A regression test leaves Color Quest's instructions open beyond the quick threshold, presses Play, answers immediately, and requires the `Quick!` result.

Changed product files:

- `lib/features/play/toys/goal_games.dart`
- `test/arcade_games_test.dart`

## Validation

- Focused regression before fix: failed as expected because `Quick!` was absent.
- Arcade and goal-game suite: 74 tests passed.
- Full Flutter suite: 195 tests passed in 30 seconds.
- Flutter analysis: 0 errors, 0 warnings, 130 pre-existing informational lints.
- Touched-file editor diagnostics: no errors.
- `git diff --check`: passed.
- Reviewed product diff before creating this report: 24 insertions, 1 deletion across the two product files; no pre-existing untracked, generated, or secret-like additions.

A pre-existing nonfatal Jigsaw Four drag hit-test warning appeared in the test run. It did not fail the test or affect this change.

## Pixel 6a QA

Device: Google Pixel 6a (`bluejay`), serial `23131JEGR02045`.

The fresh release APK installed successfully with `adb install -r`. QA verified:

- WonderPlay Home rendered with Hari and Pico.
- Play navigation opened the 127-toy catalog.
- Color Quest opened correctly from the catalog.
- The instruction screen remained usable after an extended reading pause.
- Play started the first round.
- Selecting the named color advanced progress to `1/8` and awarded a star.
- The in-game audio control remained present.
- No crash or `FATAL EXCEPTION` appeared in logcat.

Logcat contained nonfatal Android audio-route, codec, and AppOps attribution messages during speech/audio activity. These are release non-blockers for this sprint.

## Release artifacts

### Android APK

- Path: `build/app/outputs/flutter-apk/app-release.apk`
- Size: 67,584,365 bytes (64.5 MB build output)
- SHA-256: `B8CB11EAFAE765DC025D54896A634809713C545E543ABD5E0E6A455EF8BA1935`
- Artifact metadata: version name `1.0.43`, version code `44`, minimum SDK 24, target SDK 36
- Signature: verified with APK Signature Scheme v2
- Signer: `CN=Darshan Kansara, OU=DK Labs, O=DK Labs, L=Seattle, ST=Washington, C=US`

### Android App Bundle

- Path: `build/app/outputs/bundle/release/app-release.aab`
- Size: 63,649,072 bytes (60.7 MB build output)
- SHA-256: `9A6C7949AF87753659DC02622B0C566E82FB19B2225060F3DD1AF3FFC94AE0C6`
- Signature: `jarsigner` found signed entries; signing certificate expires 2054-02-01

### Web

- Path: `build/web`
- Files: 71
- Total size: 46,659,104 bytes

## Blockers and non-blockers

Blockers: none found.

Non-blockers:

- The web build reports third-party `flutter_tts` WebAssembly dry-run incompatibilities. The normal JavaScript web release completed successfully.
- The web build reports that the Cupertino icon font is not bundled; Material icons are present and the build succeeds.
- Android builds warn that `flutter_tts` still applies the Kotlin Gradle Plugin and will require a future Built-in Kotlin migration.
- 32 dependency updates are outside current constraints.
- Analysis retains 130 informational style lints and no errors or warnings.

## Next action

Upload `build/app/outputs/bundle/release/app-release.aab` to the Google Play Console internal-testing track, confirm Play App Signing accepts version code 44, and run the internal-track install smoke test before promoting the release.
