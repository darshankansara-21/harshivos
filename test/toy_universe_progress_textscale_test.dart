import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/universe/toy_universe_screen.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  testWidgets('toy universe progress card at 2.5x text scale has no overflow', (tester) async {
    // A narrow phone width plus a long-running player (big level/record/play
    // counts, which both _ProgressCard header rows render as plain Text next
    // to a Spacer) is the worst case for the "Level N ... stars/badges" row.
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'player_progress': '{"xp":987654,"records":1234,"plays":56789,'
          '"achievements":["first_play","explorer_10","explorer_50","record_1","record_10","level_5","level_10"]}',
    });
    final storage = LocalStorage(await SharedPreferences.getInstance());
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(storage),
        childNameProvider.overrideWith((ref) => 'Harshiv'),
        profileCompleteProvider.overrideWith((ref) => true),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.5)),
          child: child!,
        ),
        home: const ToyUniverseScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
