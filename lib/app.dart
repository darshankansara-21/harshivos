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
    TonePlayer.instance.volumeScale = sensory.volumeScale;
    return MaterialApp(
      title: 'HarshivOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: sensory.reduceMotion),
          child: child!,
        );
      },
      home: profileDone ? const ToyUniverseScreen() : const ProfileWizardScreen(),
    );
  }
}
