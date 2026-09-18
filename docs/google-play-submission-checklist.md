# WonderPlay — Google Play Submission Checklist

Status legend: ✅ ready in repo · ⚠️ needs a human action before submission

## 1. App identity
- ✅ App name: **WonderPlay** (verified in release APK application-label)
- ✅ Developer: DK Labs

## 2. AAB (upload artifact)
- ✅ Path: `build/app/outputs/bundle/release/app-release.aab`
- ✅ Release build succeeded; ~57.6 MB
- ✅ Signed with the upload keystore (see §5)

## 3. Version / versionCode
- ✅ versionName: **1.0.33**
- ✅ versionCode: **34**
- ⚠️ Bump versionCode for every subsequent upload (Play requires a higher code each time)

## 4. Package ID
- ✅ `com.darshankansara.harshivos` (verified in release APK)
- ⚠️ Package ID is permanent once published — confirm before first upload

## 5. Release signing
- ✅ Signed via `android/key.properties` → keystore `harshivos-release.jks`, alias `harshivos`
- ✅ Certificate: CN=Darshan Kansara, DK Labs (SHA-256 on file)
- ⚠️ Back up the keystore + passwords securely
- ⚠️ Recommended: enable **Play App Signing** on first upload (this keystore becomes the upload key)

## 6. Permissions / data behavior
- ✅ No runtime permissions requested (no INTERNET, camera, mic, location, storage)
- ✅ Only auto-added AGP receiver self-permission is present (standard, non-user-facing)
- ✅ App is fully offline

## 7. Privacy
- ✅ No analytics, tracking, ads, accounts, or cloud calls in the shipped app
- ✅ All state is local (device storage only)
- ⚠️ Complete the Play **Data safety** form as "No data collected / No data shared"
- ⚠️ Provide a hosted **Privacy Policy URL** (a policy exists at `docs/privacy-policy.html`; host it, e.g. GitHub Pages)

## 8. Content / accessibility
- ✅ Content rating: suitable for Everyone (no violence, no ads, no user-generated content)
- ⚠️ Complete the IARC content-rating questionnaire in Play Console
- ✅ Adjustable sound (off/soft/normal) and reduced-motion options
- ✅ Large touch targets; interactions have visual feedback (not sound-dependent)
- ⚠️ If targeting the "Designed for Families" / Teacher Approved programs, complete those forms and declare target age

## 9. Screenshots (needed — human action)
- ⚠️ Phone screenshots (min 2): Home, a game, Calm, Talk, Routines
- ⚠️ 7-inch and 10-inch tablet screenshots if targeting tablets

## 10. Feature graphic (needed — human action)
- ⚠️ 1024 × 500 feature graphic required for the store listing

## 11. App icon
- ✅ Launcher icon present (`@mipmap/ic_launcher`)
- ⚠️ 512 × 512 high-res icon required for the store listing

## 12. Store listing text
- ✅ Short + full description: `docs/google-play-store-copy.md`
- ✅ Release notes: `docs/google-play-release-notes.md`

## 13. Internal testing
- ⚠️ Upload the AAB to an Internal testing track first
- ⚠️ Add tester emails and validate install/launch on a real device

## 14. Production release
- ⚠️ Promote from Internal testing after validation
- ⚠️ Target SDK 36 and versionCode 34 satisfy current Play requirements at time of writing

## Technical facts (verified from the release APK)
- minSdk: 24 · targetSdk: 36 · compileSdk: 36
- No INTERNET or dangerous permissions
