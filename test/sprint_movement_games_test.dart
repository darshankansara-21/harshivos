import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpMovementGame(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> pumpMovementTime(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 50);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Balloon low taps produce extra lift; centre taps do not',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMovementGame(tester, const BalloonBounceGame());
    final balloon = find.bySemanticsLabel('Balloon');
    final rect = tester.getRect(balloon);
    await tester.tapAt(rect.center + Offset(0, rect.height * 0.2));
    await tester.pump();
    expect(find.text('Power bounce!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Balloon centre tap keeps the normal bounce', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMovementGame(tester, const BalloonBounceGame());
    await tester.tapAt(tester.getCenter(find.bySemanticsLabel('Balloon')));
    await tester.pump();
    expect(find.text('Power bounce!'), findsNothing);
    expect(find.textContaining('1/20'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('A low balloon hit rises higher than a centre hit', (tester) async {
    final semantics = tester.ensureSemantics();
    Future<double> rise({required bool low}) async {
      await pumpMovementGame(tester, const BalloonBounceGame());
      final balloon = tester.getRect(find.bySemanticsLabel('Balloon'));
      final painting = find.byWidgetPredicate((widget) =>
          widget is CustomPaint && widget.painter.runtimeType.toString() == '_BalloonBouncePainter');
      final dynamic initial = tester.widget<CustomPaint>(painting).painter;
      final double startY = initial.y;
      await tester.tapAt(balloon.center + Offset(0, low ? balloon.height * 0.2 : 0));
      await tester.pump();
      await pumpMovementTime(tester, const Duration(milliseconds: 300));
      final dynamic after = tester.widget<CustomPaint>(painting).painter;
      final double result = startY - (after.y as double);
      await tester.pumpWidget(const SizedBox());
      return result;
    }
    final normalRise = await rise(low: false);
    final powerRise = await rise(low: true);
    expect(powerRise, greaterThan(normalRise + 0.04));
    semantics.dispose();
  });

  testWidgets('Balloon waits for descent and rewards steering into its zone',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMovementGame(tester, const BalloonBounceGame());
    final balloon = find.bySemanticsLabel('Balloon');
    final painting = find.byWidgetPredicate((widget) =>
        widget is CustomPaint && widget.painter.runtimeType.toString() == '_BalloonBouncePainter');
    final shell = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_Shell');
    void action(String name) {
      final actions = tester.widget<Semantics>(balloon).properties.customSemanticsActions!;
      actions.entries.singleWhere((entry) => entry.key.label == name).value();
    }
    action('Bounce left');
    await tester.pump();
    action('Bounce left');
    await tester.pump();
    expect(find.text('Wait for it to fall'), findsOneWidget);
    expect(find.textContaining('1 / 20'), findsOneWidget);

    var foundBonus = false;
    for (var bounce = 0; bounce < 8 && !foundBonus; bounce++) {
      final dynamic initial = tester.widget<CustomPaint>(painting).painter;
      double previousY = initial.y;
      for (var frame = 0; frame < 100; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        final dynamic painter = tester.widget<CustomPaint>(painting).painter;
        final double y = painter.y;
        if (y >= 0.65 && y > previousY) break;
        previousY = y;
      }
      final dynamic before = tester.widget<CustomPaint>(painting).painter;
      final dynamic beforeShell = tester.widget(shell);
      final int previousScore = beforeShell.score;
      action(before.x < 0.2 ? 'Bounce right' : 'Bounce left');
      await tester.pump();
      final dynamic after = tester.widget<CustomPaint>(painting).painter;
      foundBonus = after.bonusX == 0.76;
      if (foundBonus) {
        final dynamic afterShell = tester.widget(shell);
        expect(afterShell.score, previousScore + 2);
        expect(find.textContaining('Star zone! +2'), findsOneWidget);
      }
    }
    expect(foundBonus, isTrue);
    final dynamic after = tester.widget<CustomPaint>(painting).painter;
    expect(after.bonusX, closeTo(0.76, 0.001));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Balloon accessible centre bounces can complete a game',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMovementGame(tester, const BalloonBounceGame());
    final balloon = find.bySemanticsLabel('Balloon');
    final painting = find.byWidgetPredicate((widget) =>
        widget is CustomPaint && widget.painter.runtimeType.toString() == '_BalloonBouncePainter');
    tester.widget<Semantics>(balloon).properties.onTap!();
    await tester.pump();
    for (var bounce = 0; bounce < 20 && find.text('Play again').evaluate().isEmpty; bounce++) {
      var previousY = -1.0;
      for (var frame = 0; frame < 100; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        final dynamic painter = tester.widget<CustomPaint>(painting).painter;
        final double y = painter.y;
        if (y >= 0.7 && y > previousY) break;
        previousY = y;
      }
      tester.widget<Semantics>(balloon).properties.onTap!();
      await tester.pump();
    }
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('🏆'), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Balance earns and spends a safety catch', (tester) async {
    await pumpMovementGame(tester, const BalanceBallGame());
    await pumpMovementTime(tester, const Duration(milliseconds: 3200));
    expect(find.text('Safety catch ready!'), findsOneWidget);
    final gesture = await tester.startGesture(const Offset(360, 500));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    await pumpMovementTime(tester, const Duration(seconds: 4));
    expect(find.text('Safety catch!'), findsOneWidget);
    await pumpMovementTime(tester, const Duration(seconds: 3));
    expect(find.text('Play again'), findsOneWidget);
    await gesture.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Steady Hand rejects a jump across the corridor', (tester) async {
    await pumpMovementGame(tester, const SteadyHandGame());
    final board = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Steady hand path.') ?? false));
    final rect = tester.getRect(board);
    Offset point(double x, double y) =>
        rect.topLeft + Offset(rect.width * x, rect.height * y);
    final gesture = await tester.startGesture(point(0.12, 0.8));
    await gesture.moveTo(point(0.14, 0.75));
    await tester.pump();
    await gesture.moveTo(point(0.8, 0.25));
    await tester.pump();
    expect(find.text('Touched the wall — back to start'), findsOneWidget);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Steady Hand can resume and follow a complete corridor',
      (tester) async {
    await pumpMovementGame(tester, const SteadyHandGame());
    final board = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Steady hand path.') ?? false));
    final rect = tester.getRect(board);
    Offset point(double x, double y) =>
        rect.topLeft + Offset(rect.width * x, rect.height * y);
    var gesture = await tester.startGesture(point(0.12, 0.8));
    await gesture.moveTo(point(0.14, 0.75));
    await tester.pump();
    await gesture.moveTo(point(0.3, 0.3));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    gesture = await tester.startGesture(point(0.3, 0.3));
    await gesture.moveTo(point(0.32, 0.332));
    await tester.pump();
    await gesture.moveTo(point(0.55, 0.7));
    await tester.pump();
    await gesture.moveTo(point(0.8, 0.25));
    await tester.pump();
    await gesture.up();
    expect(find.textContaining('1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Steady Hand accessible advance completes three paths',
      (tester) async {
    await pumpMovementGame(tester, const SteadyHandGame());
    final board = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Steady hand path.') ?? false));
    for (var index = 0; index < 12; index++) {
      final actions = tester.widget<Semantics>(board).properties.customSemanticsActions!;
      actions.entries.singleWhere((entry) => entry.key.label == 'Advance along path').value();
      await tester.pump();
    }
    expect(find.text('Play again'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Play again'));
    await tester.pump();
    for (var index = 0; index < 12; index++) {
      final actions = tester.widget<Semantics>(board).properties.customSemanticsActions!;
      actions.entries.singleWhere((entry) => entry.key.label == 'Advance along path').value();
      await tester.pump();
    }
    expect(find.text('Play again'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Maze Marble brake stops an accessible nudge', (tester) async {
    await pumpMovementGame(tester, const MazeMarbleGame());
    final board = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Maze marble board.') ?? false));
    void action(String name) {
      final actions = tester.widget<Semantics>(board).properties.customSemanticsActions!;
      actions.entries.singleWhere((entry) => entry.key.label == name).value();
    }
    final painting = find.byWidgetPredicate((widget) =>
        widget is CustomPaint && widget.painter.runtimeType.toString() == '_MazeMarblePainter');
    action('Nudge right');
    await pumpMovementTime(tester, const Duration(milliseconds: 300));
    final dynamic moving = tester.widget<CustomPaint>(painting).painter;
    final double movedX = moving.mx;
    expect(movedX, greaterThan(0.5));
    action('Brake');
    await tester.pump();
    await pumpMovementTime(tester, const Duration(milliseconds: 300));
    final dynamic stopped = tester.widget<CustomPaint>(painting).painter;
    expect(stopped.mx, closeTo(movedX, 0.00001));
  });

  testWidgets('Target Toss rewards three consecutive accessible hits',
      (tester) async {
    await pumpMovementGame(tester, const TargetTossGame());
    final board = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Points ') ?? false));
    for (var index = 0; index < 3; index++) {
      tester.widget<Semantics>(board).properties.onTap!();
      await tester.pump();
      await pumpMovementTime(tester, const Duration(milliseconds: 900));
    }
    expect(find.textContaining('streak +1'), findsOneWidget);
    final rect = tester.getRect(board);
    final gesture = await tester.startGesture(
      rect.topLeft + Offset(rect.width * 0.5, rect.height * 0.86));
    await gesture.moveTo(rect.topLeft + Offset(rect.width * 0.02, rect.height * 0.2));
    await gesture.up();
    await tester.pump();
    await pumpMovementTime(tester, const Duration(milliseconds: 1800));
    expect(find.textContaining('streak 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Target Toss short and long drags change reachable flight speed',
      (tester) async {
    await pumpMovementGame(tester, const TargetTossGame());
    final board = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Points ') ?? false));
    final painting = find.byWidgetPredicate((widget) =>
        widget is CustomPaint && widget.painter.runtimeType.toString() == '_TargetPainter');
    final rect = tester.getRect(board);
    Offset point(double x, double y) =>
        rect.topLeft + Offset(rect.width * x, rect.height * y);
    final gesture = await tester.startGesture(point(0.5, 0.86));
    await gesture.moveTo(point(0.5, 0.72));
    await tester.pump();
    final dynamic shortAim = tester.widget<CustomPaint>(painting).painter;
    final Offset shortVelocity = shortAim.launch;
    expect(shortAim.predictedX, isNotNull);
    await gesture.moveTo(point(0.5, 0.22));
    await tester.pump();
    final dynamic longAim = tester.widget<CustomPaint>(painting).painter;
    final Offset longVelocity = longAim.launch;
    expect(longVelocity.dy, lessThan(shortVelocity.dy - 0.5));
    await gesture.moveTo(point(0.5, 0.72));
    await gesture.up();
    await tester.pump();
    await pumpMovementTime(tester, const Duration(milliseconds: 1300));
    expect(find.textContaining('tosses 1'), findsOneWidget);
    final dynamic flight = tester.widget<CustomPaint>(painting).painter;
    expect(flight.by, lessThan(0.22));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Target Toss predicts a reversal and accessible play can win',
      (tester) async {
    await pumpMovementGame(tester, const TargetTossGame());
    final board = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Points ') ?? false));
    final painting = find.byWidgetPredicate((widget) =>
        widget is CustomPaint && widget.painter.runtimeType.toString() == '_TargetPainter');
    await pumpMovementTime(tester, const Duration(milliseconds: 1650));
    final rect = tester.getRect(board);
    Offset point(double x, double y) =>
        rect.topLeft + Offset(rect.width * x, rect.height * y);
    final gesture = await tester.startGesture(point(0.5, 0.86));
    await gesture.moveTo(point(0.5, 0.72));
    await tester.pump();
    final dynamic aimed = tester.widget<CustomPaint>(painting).painter;
    expect(aimed.tx, greaterThan(0.75));
    expect(aimed.predictedX, lessThan(aimed.tx));
    await gesture.cancel();
    await tester.pump();
    for (var toss = 0; toss < 12 && find.text('Play again').evaluate().isEmpty; toss++) {
      tester.widget<Semantics>(board).properties.onTap!();
      await tester.pump();
      await pumpMovementTime(tester, const Duration(milliseconds: 900));
    }
    expect(find.text('Play again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Target Toss can aim a slow throw at a reversing target',
      (tester) async {
    await pumpMovementGame(tester, const TargetTossGame());
    final board = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Points ') ?? false));
    final painting = find.byWidgetPredicate((widget) =>
        widget is CustomPaint && widget.painter.runtimeType.toString() == '_TargetPainter');
    final shell = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_Shell');
    await pumpMovementTime(tester, const Duration(milliseconds: 1650));
    final rect = tester.getRect(board);
    Offset point(double x, double y) =>
        rect.topLeft + Offset(rect.width * x, rect.height * y);
    final gesture = await tester.startGesture(point(0.5, 0.86));
    await gesture.moveTo(point(0.5, 0.72));
    await tester.pump();
    final dynamic preview = tester.widget<CustomPaint>(painting).painter;
    final Offset velocity = preview.launch;
    final double predictedX = preview.predictedX;
    final speed = -velocity.dy;
    final flightTime = (speed - math.sqrt(speed * speed - 2 * 0.35 * 0.64)) / 0.35;
    final aimX = 0.5 + (predictedX - 0.5) * 0.14 / (speed * flightTime);
    await gesture.moveTo(point(aimX, 0.72));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await pumpMovementTime(tester, const Duration(milliseconds: 1200));
    final dynamic result = tester.widget(shell);
    expect(result.score, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}