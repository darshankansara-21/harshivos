import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'services/audio/tone_player.dart';
import 'features/lifeskills/profile_wizard_screen.dart';
import 'features/universe/toy_universe_screen.dart';
import 'state/providers.dart';

/// Root of the HARSHIVOS experience.
///
/// Dark-mode first (calming, low-stimulation), Material 3, tablet-friendly.
class HarshivApp extends ConsumerWidget {
  const HarshivApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileDone = ref.watch(profileCompleteProvider);
    final sensory = ref.watch(sensoryPreferencesProvider);
    TonePlayer.instance.applyAudio(sensory.volumeScale, sensory.musicEnabled,
        haptics: sensory.hapticsEnabled);
    return MaterialApp(
      title: 'WonderPlay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: sensory.reduceMotion,
            // Every Play game is hand-tuned with fixed-pixel containers,
            // headers, and swatches around deliberately oversized, friendly
            // fonts. With no clamp, a parent's system accessibility text
            // scale (common, and plausible for parents of autistic/low-vision
            // children) is applied uncapped on top of those already-large
            // fonts, overflowing hardcoded-height banners/tiles across all
            // 78 games. Clamp instead of ignoring the setting outright: text
            // can still grow up to 1.3x for genuine accessibility need, and
            // never shrinks below the app's own baseline size.
            textScaler: media.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
      home: profileDone ? const ToyUniverseScreen() : const ProfileWizardScreen(),
    );
  }
}
