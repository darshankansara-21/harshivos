import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/play/toy_player_screen.dart';
import 'package:harshivos/models/toy_meta.dart';
import 'package:harshivos/models/sensory_profile.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  testWidgets('toy player chrome bar at 2.5x text scale has no overflow', (tester) async {
    // A narrow phone width plus a long real toy title ("Kaleidoscope
    // Mirror") is the worst case for the top chrome Row's back button +
    // title chip + spacer + mute + hide button.
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    const toy = ToyMeta(
      id: 'kaleidoscope',
      title: 'Kaleidoscope Mirror',
      emoji: '🔷',
      implemented: true,
      gradient: <Color>[Color(0xFFF857A6), Color(0xFFFF5858)],
      channels: <SensoryChannel>[SensoryChannel.visual],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[localStorageProvider.overrideWithValue(storage)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.5)),
          child: child!,
        ),
        home: const ToyPlayerScreen(toy: toy),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
