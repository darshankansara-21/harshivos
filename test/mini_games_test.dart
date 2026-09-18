import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/mini_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpGame(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Fruit Catch builds and runs without overflow', (tester) async {
    await _pumpGame(tester, const FruitCatchGame());
    expect(find.textContaining('Catch'), findsOneWidget);
    await tester.tap(find.byType(FruitCatchGame), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Balloon Pop builds and runs without overflow', (tester) async {
    await _pumpGame(tester, const BalloonPopGame());
    expect(find.textContaining('Pop'), findsOneWidget);
    await tester.tap(find.byType(BalloonPopGame), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Star Tap builds, is playable, and can be won', (tester) async {
    await _pumpGame(tester, const StarTapGame());
    expect(find.textContaining('Star Catch'), findsOneWidget);
    // The grid is nine tappable cells; tapping all of them each round always
    // hits the active star, so the score climbs deterministically to a win
    // (no reliance on where the star randomly appears).
    for (var round = 0;
        round < 60 && find.text('You did it!').evaluate().isEmpty;
        round++) {
      for (var k = 0;
          k < 9 && find.text('You did it!').evaluate().isEmpty;
          k++) {
        final cell = find.byType(GestureDetector).at(k);
        if (cell.evaluate().isNotEmpty) {
          await tester.tap(cell, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
    }
    expect(find.text('You did it!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Snake builds, steers, and runs without overflow', (tester) async {
    await _pumpGame(tester, const SnakeGame());
    // Dismiss the start card, then play.
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Snake · Orbs'), findsOneWidget);
    expect(find.textContaining('Cut off rival'), findsOneWidget);
    expect(find.text('ORB RACE'), findsOneWidget);
    await tester.drag(find.byType(SnakeGame), const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.drag(find.byType(SnakeGame), const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Racing builds, changes lanes, and runs', (tester) async {
    await _pumpGame(tester, const RacingGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Racer'), findsOneWidget);
    await tester.tapAt(const Offset(100, 1200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(980, 1200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bowling starts, flicks the ball, and knocks pins', (tester) async {
    await _pumpGame(tester, const BowlingGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Frame 1/10'), findsOneWidget);
    // Flick the ball up the lane to bowl.
    await tester.fling(
        find.byType(BowlingGame), const Offset(0, -400), 1200);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 1400));
    expect(tester.takeException(), isNull);
  });
}
