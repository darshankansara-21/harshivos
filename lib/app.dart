import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/world/world_screen.dart';

/// Root of the HARSHIVOS experience.
///
/// Dark-mode first (calming, low-stimulation), Material 3, tablet-friendly.
class HarshivApp extends ConsumerWidget {
  const HarshivApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'HarshivOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const WorldScreen(),
    );
  }
}
