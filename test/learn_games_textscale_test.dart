import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/learn/emotion_match_game.dart';
import 'package:harshivos/features/learn/pattern_game.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> probe(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    await tester.pumpWidget(ProviderScope(
        overrides: <Override>[localStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.5)),
            child: c!,
          ),
          home: home,
        )));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  testWidgets('pattern game at 2.5x text scale has no overflow',
      (tester) async {
    await probe(tester, const PatternGameScreen());
  });

  testWidgets('emotion match at 2.5x text scale has no overflow',
      (tester) async {
    await probe(tester, const EmotionMatchGame());
  });
}
