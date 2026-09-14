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
    expect(find.textContaining('Tap'), findsOneWidget);
    // Tap every visible star cell repeatedly; the active one scores, others
    // are gentle no-ops. Enough passes will drive the game to a win.
    for (var round = 0; round < 60; round++) {
      final stars = find.text('⭐');
      for (final star in stars.evaluate()) {
        await tester.tap(find.byWidget(star.widget), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (find.text('You did it!').evaluate().isNotEmpty) break;
    }
    expect(find.text('You did it!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Snake builds, steers, and runs without overflow', (tester) async {
    await _pumpGame(tester, const SnakeGame());
    expect(find.textContaining('Snake'), findsOneWidget);
    await tester.drag(find.byType(SnakeGame), const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.drag(find.byType(SnakeGame), const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Racing builds, changes lanes, and runs', (tester) async {
    await _pumpGame(tester, const RacingGame());
    expect(find.textContaining('Race'), findsOneWidget);
    await tester.tapAt(const Offset(100, 1200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(980, 1200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bowling aims, powers, and rolls a ball', (tester) async {
    await _pumpGame(tester, const BowlingGame());
    expect(find.textContaining('Bowl'), findsOneWidget);
    await tester.tap(find.byType(BowlingGame), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(BowlingGame), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.takeException(), isNull);
  });
}
