import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/mini_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder get _arena => find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_SnakePainter',
    );

// Exercise the rendered simulation, including its real ticker and controls.
dynamic _world(WidgetTester tester) =>
    tester.widget<CustomPaint>(_arena).painter;

Future<void> _start(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SnakeGame())),
  );
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
}

dynamic _onlyRival(WidgetTester tester) {
  final dynamic world = _world(tester);
  world.orbs.clear();
  final dynamic rival = world.ai.first;
  world.ai
    ..clear()
    ..add(rival);
  rival.turnTimer = 10.0;
  return rival;
}

Future<void> _advance(WidgetTester tester, int totalMs, int stepMs) async {
  for (var elapsed = 0; elapsed < totalMs; elapsed += stepMs) {
    await tester.pump(
      Duration(milliseconds: math.min(stepMs, totalMs - elapsed)),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('player and rivals start with full-length bodies',
      (tester) async {
    await _start(tester);
    final dynamic world = _world(tester);
    final List<Offset> path = world.path;
    expect((path.first - path.last).distance, closeTo(23 * 8, 0.001));
    final Iterable<dynamic> rivals = world.ai;
    for (final dynamic rival in rivals) {
      final List<Offset> trail = rival.path;
      expect(trail.first, rival.head);
      expect((trail.first - trail.last).distance,
          closeTo(((rival.length as int) - 1) * 8, 0.001));
    }
    expect(tester.takeException(), isNull);
  });

  for (final stepMs in <int>[16, 80]) {
    testWidgets('head-on contact ends the run at ${stepMs}ms frames',
        (tester) async {
      await _start(tester);
      final dynamic rival = _onlyRival(tester);
      rival.head = const Offset(65, 0);
      rival.angle = math.pi;
      rival.target = math.pi;
      rival.path
        ..clear()
        ..addAll(<Offset>[const Offset(65, 0), const Offset(150, 0)]);
      await _advance(tester, 240, stepMs);
      expect(find.text('You ran into another snake!'), findsOneWidget);
      expect((_world(tester).head as Offset).dx, lessThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a crossing body cannot be skipped at ${stepMs}ms frames',
        (tester) async {
      await _start(tester);
      final dynamic rival = _onlyRival(tester);
      rival.length = 30;
      rival.head = const Offset(65, 100);
      rival.angle = math.pi / 2;
      rival.target = math.pi / 2;
      rival.path
        ..clear()
        ..addAll(<Offset>[const Offset(65, 100), const Offset(65, -100)]);
      await _advance(tester, 480, stepMs);
      expect(find.text('You ran into another snake!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nearby parallel worms do not cause phantom collisions',
      (tester) async {
    await _start(tester);
    final dynamic rival = _onlyRival(tester);
    rival.head = const Offset(100, 28);
    rival.angle = 0.0;
    rival.target = 0.0;
    rival.path
      ..clear()
      ..addAll(<Offset>[const Offset(100, 28), const Offset(-100, 28)]);
    await _advance(tester, 480, 80);
    expect(find.text('You ran into another snake!'), findsNothing);
    expect((_world(tester).head as Offset).dx, greaterThan(70));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a trimmed rival tail has no invisible collision extension',
      (tester) async {
    await _start(tester);
    final dynamic rival = _onlyRival(tester);
    rival.length = 14;
    rival.head = const Offset(65, 150);
    rival.angle = math.pi / 2;
    rival.target = math.pi / 2;
    rival.path
      ..clear()
      ..addAll(<Offset>[const Offset(65, 150), const Offset(65, -100)]);
    await _advance(tester, 480, 80);
    expect(find.text('You ran into another snake!'), findsNothing);
    expect((_world(tester).head as Offset).dx, greaterThan(70));
    final List<Offset> trail = rival.path;
    expect((trail.first - trail.last).distance, closeTo(13 * 8, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rival crossing the player body gives a takedown, not a loss',
      (tester) async {
    await _start(tester);
    final dynamic rival = _onlyRival(tester);
    rival.head = const Offset(-80, -40);
    rival.angle = math.pi / 2;
    rival.target = math.pi / 2;
    rival.path
      ..clear()
      ..addAll(<Offset>[const Offset(-80, -40), const Offset(-80, -120)]);
    await _advance(tester, 320, 16);
    expect(find.text('You  3 / 30'), findsOneWidget);
    expect(find.text('You ran into another snake!'), findsNothing);
    final Iterable<dynamic> orbs = _world(tester).orbs;
    expect(orbs, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'boost speed, length cost and steering are frame-rate independent',
      (tester) async {
    Future<(Offset, double, int)> run(int stepMs) async {
      await _start(tester);
      final dynamic initial = _world(tester);
      initial.ai.clear();
      // Two normal catches unlock boost; keep the rest of the arena empty.
      final List<dynamic> food = List<dynamic>.from(
        (initial.orbs as Iterable<dynamic>)
            .where((orb) => orb.golden == false)
            .take(2),
      );
      initial.orbs.clear();
      for (final dynamic orb in food) {
        orb.pos = const Offset(2, 0);
        initial.orbs.add(orb);
      }
      await tester.pump(const Duration(milliseconds: 16));
      _world(tester).orbs.clear();
      expect(_world(tester).length, 28);
      final boost = await tester.startGesture(tester.getCenter(
        find.bySemanticsLabel('Boost, hold to speed up'),
      ));
      // A second finger must still steer while boost is held.
      final bounds = tester.getRect(_arena);
      final steering = await tester.startGesture(
        bounds.center + const Offset(120, 80),
        pointer: 2,
      );
      await _advance(tester, 400, stepMs);
      final dynamic world = _world(tester);
      final result =
          (world.head as Offset, world.angle as double, world.length as int);
      await steering.up();
      await boost.up();
      await tester.pumpWidget(const SizedBox.shrink());
      return result;
    }

    final fine = await run(16);
    final coarse = await run(80);
    expect((fine.$1 - coarse.$1).distance, lessThan(0.001));
    expect(fine.$2, closeTo(coarse.$2, 0.001));
    expect(fine.$2, greaterThan(0.4));
    expect(fine.$3, 26);
    expect(coarse.$3, fine.$3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding locked boost does not show an active speed glow',
      (tester) async {
    await _start(tester);
    _world(tester).ai.clear();
    _world(tester).orbs.clear();
    final press = await tester.startGesture(tester.getCenter(
      find.bySemanticsLabel('Boost, grow a little more to unlock'),
    ));
    await tester.pump(const Duration(milliseconds: 80));
    expect(_world(tester).boost, isFalse);
    expect((_world(tester).head as Offset).dx, closeTo(12.375, 0.001));
    await press.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets('replay resets bodies, score, boost and physics after a collision',
      (tester) async {
    await _start(tester);
    final dynamic rival = _onlyRival(tester);
    rival.head = const Offset(20, 0);
    rival.angle = math.pi;
    rival.target = math.pi;
    rival.path
      ..clear()
      ..addAll(<Offset>[const Offset(20, 0), const Offset(120, 0)]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('You ran into another snake!'), findsOneWidget);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    final dynamic world = _world(tester);
    expect(world.head, Offset.zero);
    expect(world.length, 24);
    expect(world.boost, isFalse);
    expect((world.ai as Iterable<dynamic>).length, 5);
    expect(find.text('You  0 / 30'), findsOneWidget);
    expect(find.text('You ran into another snake!'), findsNothing);
    world.orbs.clear();
    world.ai.clear();
    await tester.pump(const Duration(milliseconds: 80));
    expect((_world(tester).head as Offset).dx, closeTo(12.375, 0.001));
    expect(tester.takeException(), isNull);
  });
}
