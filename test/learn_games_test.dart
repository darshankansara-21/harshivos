import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harshivos/features/learn/counting_game.dart';
import 'package:harshivos/features/learn/pattern_game.dart';

/// The two new adaptive learning loops must build, accept answers, and keep
/// running without throwing.
Future<void> _pump(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1080, 2000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: game));
  await tester.pump(const Duration(milliseconds: 32));
}

void main() {
  testWidgets('Counting game builds and accepts number taps', (tester) async {
    await _pump(tester, const CountingGameScreen());
    expect(find.textContaining('Count the'), findsOneWidget);
    // Tap several number choices across rounds — never throws.
    for (var i = 0; i < 6; i++) {
      for (final n in <String>['1', '2', '3', '4', '5']) {
        final f = find.text(n);
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 40));
          break;
        }
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pattern game builds and accepts taps', (tester) async {
    await _pump(tester, const PatternGameScreen());
    expect(find.text('Finish the pattern'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      final tokens = find.byWidgetPredicate((w) =>
          w is Text &&
          (w.data == '🔴' ||
              w.data == '🔵' ||
              w.data == '🟡' ||
              w.data == '🟢' ||
              w.data == '🟣' ||
              w.data == '🟠'));
      if (tokens.evaluate().isNotEmpty) {
        await tester.tap(tokens.last, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 40));
      }
    }
    expect(tester.takeException(), isNull);
  });
}
