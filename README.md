# HARSHIVOS 🌈

> The world's first AI-powered Autism Companion focused on **Regulation, Communication, Learning, and Emotional Wellness.**

HARSHIVOS doesn't feel like therapy, school, or ABA. It feels like a **beautiful toybox** — a magical space children *want* to open, that quietly helps them regulate, communicate, and grow.

---

## ✨ What's in this MVP

| Area | Status |
| --- | --- |
| 🏠 Magical animated home (floating glass cards, drifting particles) | ✅ |
| 🎮 **Play & Explore** — sensory toybox | ✅ **14 fully-playable physics toys** |
| 🌈 **Calm Me** — one-tap regulation with guided breathing → ripples → galaxy sequence + outcome tracking | ✅ |
| 🗣️ **Help Me Talk** — AAC board with TTS, sentence strip, AI language expansion | ✅ |
| 📖 **Social Stories** — AI story generator + narrated practice mode | ✅ (AI-ready) |
| 🧠 **Learn** — adaptive Emotion-Match game (+ scaffolded games) | ✅ |
| 👨‍👩‍👦 **Parent Copilot** — AI caregiver assistant | ✅ (AI-ready) |
| 📊 **Regulation Genome** — sensory radar, top calming toys, triggers, best times | ✅ |
| 🤖 AI abstraction (Gemini / OpenAI / offline mock) | ✅ |
| 💾 Offline-first local storage + optional Firebase | ✅ |

### The 14 playable sensory toys
Bubble Pop World · Particle Galaxy · Water Ripples · Fireworks Touch · Paint With Light · Sand Garden · Magnetic Balls · Fluid Simulator · Sensory Lava Lamp · Kaleidoscope Mirror · Music Garden · Fidget Cube Digital · Calm Clouds · Rainbow Rain

Six more (Slime, Color Mixing, Car Track, Spin Universe, Marble Run…) are scaffolded in the catalogue as "coming soon".

---

## 🏗️ Architecture

```
lib/
  main.dart                     # bootstrap: storage + optional Firebase + ProviderScope
  app.dart                      # MaterialApp (Material 3, dark-first)
  core/
    theme/                      # colours, gradients, Material 3 theme
    widgets/                    # AnimatedBackground, FloatingParticles, GlassCard, HarshivScaffold
    toy/toy_ticker.dart         # reusable 60fps game-loop mixin (real delta time)
  models/                       # SensoryProfile, RegulationEntry, SocialStory, CommunicationItem, ToyMeta
  services/
    ai/                         # AiProvider abstraction → MockAiProvider | RemoteAiProvider (Gemini/OpenAI)
    regulation/                 # RegulationEngine (the "Regulation Genome" math — pure & testable)
    storage/                    # offline-first LocalStorage
    firebase/                   # optional, graceful no-op until configured
  state/providers.dart          # Riverpod wiring (log → derived profile, rankings, insights)
  features/
    home/ play/ calm/ talk/ stories/ learn/ parent/ analytics/
```

**Design language:** soft gradients, glassmorphism, fluid 60fps physics, large touch targets, tablet-first, dark mode, zero ads, zero clutter. Apple × Disney × Pixar — never hospital software.

### AI is provider-agnostic
The whole app talks only to the `AiProvider` interface. It ships defaulting to a fully-offline **mock** so it runs with **zero API keys**. To enable live AI:

1. Edit `assets/config/ai_config.json` → set `"provider": "gemini"` (or `"openai"`).
2. Create `assets/config/secrets.json` (gitignored): `{ "apiKey": "YOUR_KEY" }`.

The remote provider returns strict JSON and **falls back to the mock on any error**, so the UX never breaks.

### Regulation engine
Every play/calm session is logged on-device. From that log the engine derives a 5-channel **sensory profile** (visual / auditory / tactile / vestibular / proprioceptive), ranks which toys calm fastest, detects trigger moods, finds the best regulation times, and recommends toys — surfaced as plain-language parent insights like *"Harshiv calms fastest with Particle Galaxy and Water Ripples."*

---

## 🚀 Run it

> Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+).

```bash
cd harshivos

# Generate platform folders (android/ios/web/etc.) for this project:
flutter create .

flutter pub get
flutter run            # pick a tablet/emulator; landscape & dark mode shine
```

To try the analytics with data immediately, open **Insights** (top-right on Home) → **Generate sample insights**.

---

## 🔐 Privacy
All regulation data is stored **locally on the device** by default. Cloud sync (Firebase) is opt-in and only activates once `firebase_options.dart` is generated via the FlutterFire CLI.
