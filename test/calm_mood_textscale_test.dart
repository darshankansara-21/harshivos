import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/calm/calm_me_screen.dart';
import 'package:harshivos/features/calm/calm_sequence_screen.dart';
import 'package:harshivos/models/regulation_entry.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, LocalStorage storage) => ProviderScope(
        overrides: <Override>[localStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.5)),
            child: c!,
          ),
          home: child,
        ),
      );

  testWidgets('calm me mood buttons at 2.5x text scale has no overflow',
      (tester) async {
    // A narrow phone width is the worst case for the unflexed "Overwhelmed"
    // label sitting between a fixed-width emoji and chevron icon.
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    await tester.pumpWidget(wrap(const CalmMeScreen(), storage));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'calm sequence header pill at 2.5x text scale has no overflow',
      (tester) async {
    // The header Row pairs an unflexed mood-emoji + long step-label pill
    // ("Drift through the galaxy") against a fixed timer pill with a
    // Spacer between them — the worst case is the longest step label on a
    // narrow phone width.
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    await tester.pumpWidget(
        wrap(const CalmSequenceScreen(mood: CalmMood.overwhelmed), storage));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
