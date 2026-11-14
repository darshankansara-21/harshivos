import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:harshivos/features/play/toys/mini_games.dart' show GameScores;
import 'package:shared_preferences/shared_preferences.dart';

Finder board(String label) => find.byWidgetPredicate((widget) =>
    widget is Semantics &&
    (widget.properties.label?.startsWith(label) ?? false));

Finder painting(String name) => find.byWidgetPredicate((widget) =>
    widget is CustomPaint && widget.painter.runtimeType.toString() == name);

GestureDetector controls(WidgetTester tester, Finder boardFinder) =>
    tester.widget<GestureDetector>(find
        .descendant(of: boardFinder, matching: find.byType(GestureDetector))
        .first);

Future<void> startGame(WidgetTester tester, Widget game, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
  await tester.pump(const Duration(milliseconds: 16));
  final shell = find
      .byWidgetPredicate((widget) => widget.runtimeType.toString() == '_Shell');
  final dynamic shellWidget = tester.widget(shell);
  shellWidget.onStart();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  testWidgets('Steady Hand re-grab does not move the dot outside the corridor',
      (tester) async {
    await startGame(tester, const SteadyHandGame(), const Size(400, 900));
    final boardFinder = board('Steady hand path.');
    final rect = tester.getRect(boardFinder);
    final control = controls(tester, boardFinder);
    Offset point(double x, double y) => Offset(x * rect.width, y * rect.height);
    control.onPanStart!(DragStartDetails(localPosition: point(0.23, 0.8)));
    await tester.pump();
    dynamic painter =
        tester.widget<CustomPaint>(painting('_SteadyHandPainter')).painter;
    expect(painter.dotX, closeTo(0.12, 0.00001));
    control.onPanUpdate!(DragUpdateDetails(
        globalPosition: rect.topLeft + point(0.225, 0.8),
        localPosition: point(0.225, 0.8)));
    await tester.pump();
    painter =
        tester.widget<CustomPaint>(painting('_SteadyHandPainter')).painter;
    expect(painter.dotX, closeTo(0.115, 0.00001));
    expect(find.textContaining('Touched the wall'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Steady Hand semantics continues from touch and retains checkpoints',
      (tester) async {
    await startGame(tester, const SteadyHandGame(), const Size(400, 900));
    final boardFinder = board('Steady hand path.');
    final rect = tester.getRect(boardFinder);
    Offset point(double x, double y) => Offset(x * rect.width, y * rect.height);
    final control = controls(tester, boardFinder);
    control.onPanStart!(DragStartDetails(localPosition: point(0.12, 0.8)));
    for (final position in <Offset>[point(0.3, 0.3), point(0.55, 0.7)]) {
      control.onPanUpdate!(DragUpdateDetails(
          globalPosition: rect.topLeft + position, localPosition: position));
      await tester.pump();
    }
    control.onPanEnd!(DragEndDetails());
    await tester.pump();
    final actions = tester
        .widget<Semantics>(boardFinder)
        .properties
        .customSemanticsActions!;
    actions.entries
        .singleWhere((entry) => entry.key.label == 'Advance along path')
        .value();
    await tester.pump();
    final dynamic painter =
        tester.widget<CustomPaint>(painting('_SteadyHandPainter')).painter;
    expect(painter.dotX, greaterThan(0.55));
    expect(painter.dotY, lessThan(0.7));
    final resumed = controls(tester, boardFinder);
    resumed.onPanStart!(
        DragStartDetails(localPosition: point(painter.dotX, painter.dotY)));
    resumed.onPanUpdate!(DragUpdateDetails(
        globalPosition: rect.topLeft + point(0.8, 0.25),
        localPosition: point(0.8, 0.25)));
    await tester.pump();
    expect(find.textContaining('1 / 3'), findsOneWidget);
    expect(find.textContaining('Touched the wall'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Steady Hand off-center re-grab survives a real pan',
      (tester) async {
    await startGame(tester, const SteadyHandGame(), const Size(400, 900));
    final rect = tester.getRect(board('Steady hand path.'));
    Offset point(double x, double y) =>
        rect.topLeft + Offset(x * rect.width, y * rect.height);
    final gesture = await tester.startGesture(point(0.23, 0.8));
    await gesture.moveTo(point(0.23, 0.83));
    await tester.pump();
    await gesture.moveTo(point(0.23, 0.828));
    await tester.pump();
    final dynamic painter =
        tester.widget<CustomPaint>(painting('_SteadyHandPainter')).painter;
    expect(painter.dotX, closeTo(0.12, 0.00001));
    expect(painter.dotY, closeTo(0.828, 0.00001));
    expect(find.textContaining('Touched the wall'), findsNothing);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Maze Marble five-wall routes have clearance on extreme boards',
      (tester) async {
    await GameScores.instance.submit('maze_marble', 6);
    for (final size in <Size>[
      const Size(400, 900),
      const Size(1000, 600),
      const Size(1600, 320),
    ]) {
      await startGame(tester, const MazeMarbleGame(), size);
      final boardFinder = board('Maze marble board.');
      final rect = tester.getRect(boardFinder);
      final aspect = rect.height / rect.width;
      final shell = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_Shell');
      for (var iteration = 0; iteration < 32; iteration++) {
        final dynamic painter =
            tester.widget<CustomPaint>(painting('_MazeMarblePainter')).painter;
        final walls = (painter.walls as List<dynamic>)
            .map((wall) => (
                  y: wall.y as double,
                  gapX: wall.gapX as double,
                  gapW: wall.gapW as double,
                ))
            .toList();
        if (iteration >= 30) {
          for (var index = 0; index < walls.length; index++) {
            walls[index] = (
              y: walls[index].y,
              gapX: (index + iteration).isEven ? 0.1 : 0.74,
              gapW: 0.16
            );
          }
        }
        expect(walls, hasLength(5));
        final double scale = painter.sizeScale;
        expect(scale, closeTo(math.min(1.0, aspect), 0.000001));
        final collisionRadius = 0.059 * scale;
        final points = <Offset>[const Offset(0.5, 0.1)];
        var previousY = 0.1;
        for (final wall in walls) {
          final double center = wall.gapX + wall.gapW / 2;
          final double y = wall.y;
          final midpoint = (previousY + y) / 2;
          points.add(Offset(points.last.dx, midpoint));
          points.add(Offset(center, midpoint));
          points.add(Offset(center, y));
          previousY = y;
        }
        final double goalX = painter.goalX;
        points.add(Offset(points.last.dx, (previousY + 0.93) / 2));
        points.add(Offset(goalX, (previousY + 0.93) / 2));
        points.add(Offset(goalX, 0.93));
        for (var segment = 1; segment < points.length; segment++) {
          for (var sample = 0; sample <= 40; sample++) {
            final point =
                Offset.lerp(points[segment - 1], points[segment], sample / 40)!;
            expect(
                point.dx, inInclusiveRange(0.045 * scale, 1 - 0.045 * scale));
            expect(point.dy * aspect,
                inInclusiveRange(0.045 * scale, aspect - 0.045 * scale));
            for (final wall in walls) {
              final double gapStart = wall.gapX;
              final double gapEnd = wall.gapX + wall.gapW;
              final dy = (point.dy - wall.y) * aspect;
              for (final interval in <List<double>>[
                <double>[0, gapStart],
                <double>[gapEnd, 1]
              ]) {
                final dx = point.dx - point.dx.clamp(interval[0], interval[1]);
                expect(
                    dx * dx + dy * dy,
                    greaterThanOrEqualTo(
                        collisionRadius * collisionRadius - 1e-10));
              }
            }
          }
        }
        final dynamic shellWidget = tester.widget(shell);
        shellWidget.onPlayAgain();
        await tester.pump();
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Maze Marble can roll through five landscape gates to the goal',
      (tester) async {
    await GameScores.instance.submit('maze_marble', 6);
    await startGame(tester, const MazeMarbleGame(), const Size(1600, 320));
    final boardFinder = board('Maze marble board.');
    final rect = tester.getRect(boardFinder);
    final painterFinder = painting('_MazeMarblePainter');
    final dynamic initial = tester.widget<CustomPaint>(painterFinder).painter;
    final walls = List<dynamic>.from(initial.walls);
    expect(walls, hasLength(5));
    final targets = <Offset>[];
    var previousY = 0.1;
    for (final wall in walls) {
      final double center = wall.gapX + wall.gapW / 2;
      targets.add(Offset(center, previousY));
      previousY = wall.y + 0.07;
      targets.add(Offset(center, previousY));
    }
    targets.add(Offset(initial.goalX, previousY));
    targets.add(Offset(initial.goalX, initial.goalY));

    for (final target in targets) {
      final control = controls(tester, boardFinder);
      final local = Offset(target.dx * rect.width, target.dy * rect.height);
      control.onPanStart!(DragStartDetails(localPosition: local));
      var reached = false;
      for (var frame = 0; frame < 300; frame++) {
        await tester.pump(const Duration(milliseconds: 30));
        final dynamic current =
            tester.widget<CustomPaint>(painterFinder).painter;
        if (find.textContaining('1 / 6').evaluate().isNotEmpty ||
            ((current.mx as double) - target.dx).abs() < 0.008 &&
                ((current.my as double) - target.dy).abs() < 0.008) {
          reached = true;
          break;
        }
      }
      expect(reached, isTrue, reason: 'Failed to reach $target');
      if (find.textContaining('1 / 6').evaluate().isNotEmpty) break;
      final actions = tester
          .widget<Semantics>(boardFinder)
          .properties
          .customSemanticsActions!;
      actions.entries
          .singleWhere((entry) => entry.key.label == 'Brake')
          .value();
      await tester.pump();
    }
    expect(find.textContaining('1 / 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
