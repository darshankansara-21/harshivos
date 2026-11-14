import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:harshivos/services/audio/tone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Finder golfPaint = find.byWidgetPredicate((widget) =>
    widget is CustomPaint &&
    widget.painter.runtimeType.toString() == '_GolfPainter');

Future<void> startGame(WidgetTester tester, {bool reduceMotion = false}) async {
  await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const Scaffold(body: MiniGolfGame()))));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump(const Duration(milliseconds: 16));
}

SemanticsNode golfNode(WidgetTester tester) => tester
    .getSemantics(find.bySemanticsLabel(RegExp('Hole [0-9] of 9. Strokes')));

dynamic golfPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(golfPaint).painter;

Future<void> action(WidgetTester tester, String label) async {
  final node = golfNode(tester);
  final actionId = node
      .getSemanticsData()
      .customSemanticsActionIds!
      .firstWhere((id) => CustomSemanticsAction.getAction(id)!.label == label);
  tester.binding.pipelineOwner.semanticsOwner!
      .performAction(node.id, SemanticsAction.customAction, actionId);
  await tester.pump();
}

Future<void> setPower(WidgetTester tester, int power) async {
  final match =
      RegExp(r'Power (\d+) percent').firstMatch(golfNode(tester).label)!;
  var current = int.parse(match.group(1)!);
  while (current != power) {
    final delta = current < power ? 10 : -10;
    await action(tester,
        delta > 0 ? 'Increase power 10 percent' : 'Decrease power 10 percent');
    current += delta;
  }
}

Future<void> tapPutt(WidgetTester tester) async {
  final node = golfNode(tester);
  tester.binding.pipelineOwner.semanticsOwner!
      .performAction(node.id, SemanticsAction.tap);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> sinkCurrentHole(WidgetTester tester, int hole) async {
  for (var attempt = 0; attempt < 6; attempt++) {
    final dynamic painter = golfPainter(tester);
    final direction = Offset((painter.cupX as double) - (painter.bx as double),
        (painter.cupY as double) - (painter.by as double));
    final power = (((direction.distance * 1.5 + 0.2) / 1.9 * 10).round() * 10)
        .clamp(10, 100);
    await action(tester, 'Aim at cup');
    await setPower(tester, power);
    await tapPutt(tester);
    for (var step = 0; step < 100; step++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (golfNode(tester).label.contains('Hole ${hole + 1} of 9')) return;
      if (golfNode(tester).label.contains('Ready to putt')) break;
    }
  }
  fail('Could not sink hole $hole using semantic controls');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('semantic aim and power change the actual putt', (tester) async {
    final semantics = tester.ensureSemantics();
    await startGame(tester);
    final dynamic before = tester.widget<CustomPaint>(golfPaint).painter;
    final double cupX = before.cupX;
    final double cupY = before.cupY;
    final size = tester.getSize(golfPaint);
    final aspect = size.height / size.width;
    for (var step = 0; step < 6; step++) {
      await action(tester, 'Turn aim right 15 degrees');
    }
    for (var step = 0; step < 20; step++) {
      await action(tester, 'Decrease power 10 percent');
    }
    expect(golfNode(tester).label, contains('Power 10 percent'));
    final node = golfNode(tester);
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await tester.pump(const Duration(milliseconds: 50));
    final dynamic after = tester.widget<CustomPaint>(golfPaint).painter;
    expect(after.bx as double, greaterThan(0.5));
    final displacement = Offset(
        (after.bx as double) - 0.5, ((after.by as double) - 0.86) * aspect);
    final cupDirection = Offset(cupX - 0.5, (cupY - 0.86) * aspect);
    expect(
        (displacement.dx * cupDirection.dx + displacement.dy * cupDirection.dy)
            .abs(),
        lessThan(0.001));
    expect(displacement.distance, lessThan(0.02));
    expect(golfNode(tester).label, contains('Ball moving'));
    expect(find.textContaining('strokes 1'), findsOneWidget);
    expect(golfNode(tester).getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse);
    semantics.dispose();
  });

  testWidgets('aim resets to the cup and maximum power remains capped',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await startGame(tester);
    final initial = RegExp(r'Aim (\d+) degrees')
        .firstMatch(golfNode(tester).label)!
        .group(1);
    await action(tester, 'Turn aim left 15 degrees');
    expect(
        RegExp(r'Aim (\d+) degrees')
            .firstMatch(golfNode(tester).label)!
            .group(1),
        isNot(initial));
    await action(tester, 'Aim at cup');
    expect(
        RegExp(r'Aim (\d+) degrees')
            .firstMatch(golfNode(tester).label)!
            .group(1),
        initial);
    for (var step = 0; step < 20; step++) {
      await action(tester, 'Increase power 10 percent');
    }
    expect(golfNode(tester).label, contains('Power 100 percent'));
    await tapPutt(tester);
    final dynamic painter = golfPainter(tester);
    final displacement =
        Offset((painter.bx as double) - 0.5, (painter.by as double) - 0.86);
    expect(displacement.distance, greaterThan(0.08));
    expect(displacement.distance, lessThanOrEqualTo(1.9 * 0.05 + 0.0001));
    expect(
        golfNode(tester).getSemanticsData().customSemanticsActionIds ?? <int>[],
        isEmpty);
    semantics.dispose();
  });

  testWidgets('semantic controls get around a rail on hole three',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await startGame(tester);
    await sinkCurrentHole(tester, 1);
    await sinkCurrentHole(tester, 2);
    final dynamic painter = golfPainter(tester);
    final Rect wall = painter.wall;
    expect(golfNode(tester).label, contains('Obstacle rails'));
    final double ballX = painter.bx;
    final double ballY = painter.by;
    final double cupX = painter.cupX;
    final double cupY = painter.cupY;
    final aspect =
        tester.getSize(golfPaint).height / tester.getSize(golfPaint).width;
    final leftTarget = wall.left - 0.12;
    final rightTarget = wall.right + 0.12;
    final targetX = (ballX - leftTarget).abs() < (rightTarget - ballX).abs()
        ? leftTarget
        : rightTarget;
    final cupAngle = math.atan2((cupY - ballY) * aspect, cupX - ballX);
    final targetAngle =
        math.atan2((wall.center.dy - ballY) * aspect, targetX - ballX);
    final turnSteps = ((targetAngle - cupAngle) * 180 / math.pi / 15).round();
    for (var step = 0; step < turnSteps.abs(); step++) {
      await action(
          tester,
          turnSteps < 0
              ? 'Turn aim left 15 degrees'
              : 'Turn aim right 15 degrees');
    }
    await setPower(tester, 100);
    await action(tester, 'Increase power 10 percent');
    expect(golfNode(tester).label, contains('Power 100 percent'));
    await tapPutt(tester);
    var passedRail = false;
    for (var step = 0; step < 70; step++) {
      await tester.pump(const Duration(milliseconds: 40));
      final dynamic current = golfPainter(tester);
      if ((current.by as double) < wall.bottom) {
        expect(
            (current.bx as double) < wall.left - 0.03 ||
                (current.bx as double) > wall.right + 0.03,
            isTrue);
        passedRail = true;
        break;
      }
    }
    expect(passedRail, isTrue);
    semantics.dispose();
  });

  testWidgets('physical drag remains playable', (tester) async {
    await startGame(tester);
    final rect = tester.getRect(golfPaint);
    final ball =
        Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.86);
    await tester.dragFrom(ball, Offset(0, -rect.height * 0.1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(golfPainter(tester).by as double, lessThan(0.86));
    expect(find.textContaining('strokes 1'), findsOneWidget);
  });

  testWidgets('semantic sink respects reduced motion and disabled haptics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final tone = TonePlayer.instance;
    final oldVolume = tone.volumeScale;
    final oldHaptics = tone.hapticsEnabled;
    tone.volumeScale = 0;
    tone.hapticsEnabled = false;
    addTearDown(() {
      tone.volumeScale = oldVolume;
      tone.hapticsEnabled = oldHaptics;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final haptics = <MethodCall>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
      return null;
    });
    await startGame(tester, reduceMotion: true);
    final dynamic painter = golfPainter(tester);
    final direction = Offset((painter.cupX as double) - (painter.bx as double),
        (painter.cupY as double) - (painter.by as double));
    final power = (((direction.distance * 1.5 + 0.2) / 1.9 * 10).round() * 10)
        .clamp(10, 100);
    await setPower(tester, power);
    await tapPutt(tester);
    var sunk = false;
    for (var step = 0; step < 80; step++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (find.textContaining('1 / 9').evaluate().isNotEmpty) {
        expect((golfPainter(tester).bits as List).length, 5);
        expect(golfNode(tester).label, contains('Putt unavailable'));
        sunk = true;
        break;
      }
    }
    expect(sunk, isTrue);
    expect(haptics, isEmpty);
    expect(tone.volumeScale, 0);
    semantics.dispose();
  });
}
