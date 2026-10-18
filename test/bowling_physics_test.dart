import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/mini_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder get _lane => find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_BowlPainter',
    );

// Read the actual rendered simulation, not a second implementation of physics.
dynamic _physics(WidgetTester tester) =>
    tester.widget<CustomPaint>(_lane).painter;

Future<void> _start(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: BowlingGame()),
  ));
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
}

Future<void> _finishRoll(WidgetTester tester, int stepMs) async {
  for (var i = 0; i < 3000 ~/ stepMs; i++) {
    await tester.pump(Duration(milliseconds: stepMs));
    if (_physics(tester).phase.toString() == '_BowlPhase.settle') return;
  }
  fail('The ball did not reach the pin deck within three seconds');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'a straight roll carries the head pin toward the back of the rack',
      (tester) async {
    await _start(tester);
    await tester.tapAt(tester.getRect(_lane).center);
    await tester.pump();
    final dynamic headPin = _physics(tester).pins.first;
    for (var i = 0; i < 60 && headPin.down == false; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(headPin.down, isTrue);
    expect(headPin.vy, lessThan(0),
        reason: 'Up the lane is negative Y, just like the incoming ball');
    await tester.pump(const Duration(milliseconds: 32));
    expect(headPin.oy, lessThan(0));
    await _finishRoll(tester, 16);
    final Iterable<dynamic> pins = _physics(tester).pins;
    expect(pins.where((pin) => pin.down == true).length, greaterThan(1),
        reason: 'The head pin should carry into the pins behind it');
    expect(tester.takeException(), isNull);
  });

  for (final towardHead in <bool>[false, true]) {
    testWidgets(
        'a sliding pin ${towardHead ? 'can' : 'cannot'} topple a neighbour '
        'it is moving ${towardHead ? 'toward' : 'away from'}', (tester) async {
      await _start(tester);
      await tester.tapAt(tester.getRect(_lane).center);
      await tester.pump();
      final List<dynamic> pins = _physics(tester).pins;
      // Isolate a contact between the first two rows, before the ball arrives.
      for (final dynamic pin in pins) {
        pin.down = true;
        pin.fallT = 1.0;
      }
      pins[0].down = false;
      pins[1].fallT = 0.1;
      pins[1].vx = 0.0;
      pins[1].vy = towardHead ? 0.1 : -0.1;
      await tester.pump(const Duration(milliseconds: 16));
      expect(pins[0].down, towardHead);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fast flicks hit the same pins at 16ms and 80ms frame intervals',
      (tester) async {
    Future<int> roll(int stepMs) async {
      await _start(tester);
      final lane = tester.getRect(_lane);
      await tester.flingFrom(
        Offset(lane.center.dx, lane.top + lane.height * 0.84),
        const Offset(0, -180),
        2400,
      );
      await _finishRoll(tester, stepMs);
      final Iterable<dynamic> pins = _physics(tester).pins;
      final knocked = pins.where((pin) => pin.down == true).length;
      await tester.pumpWidget(const SizedBox.shrink());
      return knocked;
    }

    final fine = await roll(16);
    final coarse = await roll(80);
    expect(fine, greaterThan(0));
    expect(coarse, fine);
    expect(tester.takeException(), isNull);
  });

  for (final side in <double>[-1, 1]) {
    testWidgets(
        'a ${side < 0 ? 'left' : 'right'} gutter stays a miss and resets',
        (tester) async {
      await _start(tester);
      final lane = tester.getRect(_lane);
      await tester.dragFrom(
        Offset(lane.center.dx, lane.top + lane.height * 0.84),
        Offset(lane.width * 0.28 * side, 0),
      );
      await _finishRoll(tester, 16);
      final dynamic physics = _physics(tester);
      final Iterable<dynamic> pins = physics.pins;
      expect(pins.every((pin) => pin.down == false), isTrue);
      expect((physics.ballX as double) * side,
          greaterThan((0.5 + 0.13 * side) * side));
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_physics(tester).phase.toString(), '_BowlPhase.aim');
      expect(_physics(tester).ballX, 0.5);
      expect(find.bySemanticsLabel(RegExp('Frame 1 of 10, ball 2')),
          findsOneWidget);
      // The gutter latch must not leak into the second ball.
      await tester.tapAt(lane.center);
      await _finishRoll(tester, 16);
      final Iterable<dynamic> secondRollPins = _physics(tester).pins;
      expect(secondRollPins.any((pin) => pin.down == true), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
