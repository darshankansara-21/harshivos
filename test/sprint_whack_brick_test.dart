import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhackTestRandom implements math.Random {
  int doubleCalls = 0;
  int get spawns => doubleCalls ~/ 3;

  @override
  double nextDouble() {
    final call = doubleCalls++;
    final spawn = call ~/ 3 + 1;
    if (call % 3 == 1 && (spawn == 2 || spawn == 7)) return 0;
    return 0.9;
  }

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

Future<void> startGame(WidgetTester tester, Widget game,
    {bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: game),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump(const Duration(milliseconds: 16));
}

Finder brickPaint() => find.byWidgetPredicate((widget) =>
    widget is CustomPaint && widget.painter.runtimeType.toString() == '_BrickPainter');

dynamic brickPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(brickPaint()).painter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Whack counts moles, not bombs, for every seventh golden mole',
      (tester) async {
    final random = WhackTestRandom();
    await startGame(tester, WhackGame(random: random));
    var moles = 0;
    var golden = 0;
    for (var step = 0; step < 400 && moles < 14; step++) {
      await tester.pump(const Duration(milliseconds: 50));
      final targets = find.byWidgetPredicate((widget) => widget is Semantics &&
          (widget.properties.label?.contains(', mole. Tap to whack.') == true ||
              widget.properties.label?.contains(', golden mole.') == true));
      if (targets.evaluate().isEmpty) continue;
      final target = tester.widget<Semantics>(targets.first);
      final isGolden = target.properties.label!.contains('golden mole');
      moles++;
      expect(isGolden, moles % 7 == 0, reason: 'mole $moles');
      target.properties.onTap!();
      if (isGolden) {
        golden++;
        await tester.pump(const Duration(milliseconds: 50));
        final cracked = find.byWidgetPredicate((widget) => widget is Semantics &&
            widget.properties.label?.contains('golden mole. 1 hits left.') == true);
        expect(cracked, findsOneWidget);
        tester.widget<Semantics>(cracked).properties.onTap!();
      }
    }
    expect(moles, 14);
    expect(golden, 2);
    expect(random.spawns, greaterThanOrEqualTo(16));
    expect(tester.takeException(), isNull);
  });

  for (final reduceMotion in <bool>[false, true]) {
    testWidgets('Brick Break preserves fireball across serve (reduce motion: $reduceMotion)',
        (tester) async {
      await startGame(tester, const BrickBreakGame(), reduceMotion: reduceMotion);
      final dynamic state = tester.state(find.byType(BrickBreakGame));
      final bricks = brickPainter(tester).bricks as List<int>;
      bricks.fillRange(0, bricks.length, 0);
      bricks[3] = 1;
      await tester.tap(brickPaint());
      state.debugSetBrickBreakBall(x: 0.58, y: 0.12, vx: 0.0, vy: 0.0, combo: 4);
      await tester.pump(const Duration(milliseconds: 50));
      dynamic painter = brickPainter(tester);
      expect(painter.started, isFalse);
      expect(painter.fireT as double, closeTo(4.5, 0.001));
      expect(find.text('Level 2!'), findsOneWidget);

      for (var step = 0; step < 120; step++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      painter = brickPainter(tester);
      expect(painter.started, isFalse);
      expect(painter.fireT as double, closeTo(4.5, 0.001));

      await tester.tap(brickPaint());
      final nextBricks = brickPainter(tester).bricks as List<int>;
      nextBricks[3] = 2;
      state.debugSetBrickBreakBall(x: 0.58, y: 0.12, vx: 0.0, vy: 0.0, combo: 0);
      await tester.pump(const Duration(milliseconds: 50));
      painter = brickPainter(tester);
      expect(painter.started, isTrue);
      expect(painter.fireT as double, lessThan(4.5));
      expect(nextBricks[3], 0);

      state.debugSetBrickBreakBall(x: 0.5, y: 1.05, vx: 0.0, vy: 0.0, combo: 0);
      await tester.pump(const Duration(milliseconds: 50));
      painter = brickPainter(tester);
      expect(painter.started, isFalse);
      expect(painter.fireT, 0.0);
      expect(tester.takeException(), isNull);
    });
  }
}