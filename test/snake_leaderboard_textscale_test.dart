// batch-415: dedicated probe for SnakeGame's `_SnakeLeaderboard` HUD, the
// one floating overlay in mini_games.dart left without the shared
// `_GameShellState` HUD pill's `maxScaleFactor: 1.3` text-scale cap. Mirrors
// arcade_overlay_textscale_test.dart's `_pumpSmallLargeText` 2.5x-scale probe
// on a small phone surface, the exact scenario that previously let unbounded
// HUD text clip past the Stack's edge.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/mini_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'Snake leaderboard HUD renders without overflow at 2.5x text scale',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
        child: const MaterialApp(home: Scaffold(body: SnakeGame())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));

    final Finder playButton = find.widgetWithText(FilledButton, 'Play');
    await tester.scrollUntilVisible(playButton, 200.0,
        scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(playButton);
    // Several short ticks (ToyTicker skips dt>=0.1s) so the leaderboard
    // actually builds with live AI worm scores, not just its initial frame.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull,
        reason:
            'Snake HUD (leaderboard + title pill + instructions) must not '
            'overflow at 2.5x text scale');
  });
}
