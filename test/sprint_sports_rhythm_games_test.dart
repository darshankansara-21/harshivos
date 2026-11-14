import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpGame(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump(const Duration(milliseconds: 16));
}

Finder gamePaint(String name) => find.byWidgetPredicate((widget) =>
    widget is CustomPaint && widget.painter.runtimeType.toString() == name);

Future<void> advance(WidgetTester tester, int steps) async {
  for (var step = 0; step < steps; step++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Soccer kicks upward after pulling the ball down', (tester) async {
    await pumpGame(tester, const SoccerKickGame());
    final paint = find.byWidgetPredicate((widget) =>
        widget is CustomPaint && widget.painter.runtimeType.toString() == '_SoccerPainter');
    final rect = tester.getRect(paint);
    final ball = Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.84);
    await tester.dragFrom(ball, Offset(0, rect.height * 0.12));
    for (var step = 0; step < 5; step++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final dynamic painter = tester.widget<CustomPaint>(paint).painter;
    expect(painter.by as double, lessThan(0.84));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Soccer semantic kick launches toward goal', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGame(tester, const SoccerKickGame());
    final node = tester.getSemantics(find.bySemanticsLabel(RegExp('Tap to kick for the corner')));
    tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.tap);
    await advance(tester, 5);
    final dynamic painter = tester.widget<CustomPaint>(gamePaint('_SoccerPainter')).painter;
    expect(painter.by as double, lessThan(0.84));
    await advance(tester, 25);
    expect(find.text('Wide!'), findsNothing);
    expect(find.text('Saved!').evaluate().isNotEmpty ||
      find.text('GOAL!  ⚽').evaluate().isNotEmpty, isTrue);
    semantics.dispose();
  });

  testWidgets('Air hockey accessible nudge moves the mallet', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpGame(tester, const AirHockeyGame());
    final paint = gamePaint('_HockeyPainter');
    final dynamic before = tester.widget<CustomPaint>(paint).painter;
    final double initialX = before.ppx;
    final node = tester.getSemantics(find.bySemanticsLabel(RegExp('Air hockey table')));
    final actionId = node.getSemanticsData().customSemanticsActionIds!
      .firstWhere((id) => CustomSemanticsAction.getAction(id)!.label == 'Nudge right');
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id, SemanticsAction.customAction, actionId);
    await tester.pump();
    final dynamic after = tester.widget<CustomPaint>(paint).painter;
    expect(after.ppx as double, greaterThan(initialX));
    semantics.dispose();
  });

  testWidgets('Mini golf counts a putt and moves the ball', (tester) async {
    await pumpGame(tester, const MiniGolfGame());
    final paint = gamePaint('_GolfPainter');
    final rect = tester.getRect(paint);
    final ball = Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.86);
    await tester.dragFrom(ball, Offset(0, -rect.height * 0.1));
    await advance(tester, 3);
    final dynamic painter = tester.widget<CustomPaint>(paint).painter;
    expect(painter.by as double, lessThan(0.86));
    expect(find.textContaining('strokes 1'), findsOneWidget);
  });

  testWidgets('Mini golf tells the player when a cup crossing is too fast', (tester) async {
    await pumpGame(tester, const MiniGolfGame());
    final paint = gamePaint('_GolfPainter');
    final rect = tester.getRect(paint);
    final dynamic painter = tester.widget<CustomPaint>(paint).painter;
    final direction = Offset((painter.cupX as double) - 0.5,
        (painter.cupY as double) - 0.86);
    final ball = Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.86);
    final aim = direction / direction.distance * 0.6;
    await tester.dragFrom(ball, Offset(aim.dx * rect.width, aim.dy * rect.height));
    var sawTooFast = false;
    for (var step = 0; step < 30; step++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (find.text('Too fast - try a softer putt').evaluate().isNotEmpty) {
        sawTooFast = true;
        break;
      }
    }
    expect(sawTooFast, isTrue);
    expect(find.textContaining('0 / 9'), findsOneWidget);
  });

  testWidgets('Mini golf sinks a gently aimed putt', (tester) async {
    await pumpGame(tester, const MiniGolfGame());
    final paint = gamePaint('_GolfPainter');
    final rect = tester.getRect(paint);
    final dynamic painter = tester.widget<CustomPaint>(paint).painter;
    final direction = Offset((painter.cupX as double) - 0.5,
        (painter.cupY as double) - 0.86);
    final speed = direction.distance * 1.5 + 0.22;
    final aim = direction / direction.distance * (speed / 3);
    final ball = Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.86);
    await tester.dragFrom(ball, Offset(aim.dx * rect.width, aim.dy * rect.height));
    await advance(tester, 36);
    expect(find.textContaining('1 / 9'), findsOneWidget);
  });

  testWidgets('Rhythm marks a beat missed after the full timing window', (tester) async {
    await pumpGame(tester, const RhythmClapGame());
    final paint = gamePaint('_RhythmPainter');
    dynamic painter = tester.widget<CustomPaint>(paint).painter;
    final double marker = (painter.markers as List<double>).first;
    while ((painter.head as double) < marker + 0.07) {
      await tester.pump(const Duration(milliseconds: 40));
      painter = tester.widget<CustomPaint>(paint).painter;
    }
    expect((painter.missed as List<bool>).first, isTrue);
    expect((painter.hit as List<bool>).first, isFalse);
    expect(find.text('Missed beat'), findsOneWidget);
  });

  testWidgets('Rhythm rewards a timed clap and reports the streak', (tester) async {
    await pumpGame(tester, const RhythmClapGame());
    final paint = gamePaint('_RhythmPainter');
    dynamic painter = tester.widget<CustomPaint>(paint).painter;
    final double marker = (painter.markers as List<double>).first;
    while ((painter.head as double) < marker - 0.01) {
      await tester.pump(const Duration(milliseconds: 20));
      painter = tester.widget<CustomPaint>(paint).painter;
    }
    await tester.tapAt(tester.getRect(paint).bottomCenter - const Offset(0, 100));
    await tester.pump();
    painter = tester.widget<CustomPaint>(paint).painter;
    expect((painter.hit as List<bool>).first, isTrue);
    expect(find.text('On beat! Streak 1'), findsOneWidget);
  });

  testWidgets('Echo replay costs no life and completed phrases score', (tester) async {
    await pumpGame(tester, const EchoDrumsGame());
    final pads = find.byType(AnimatedContainer);
    int litPad() {
      for (var index = 0; index < 4; index++) {
        final decoration = tester.widget<AnimatedContainer>(pads.at(index)).decoration! as BoxDecoration;
        if (decoration.color!.a > 0.99) return index;
      }
      throw StateError('No lit drum');
    }
    final first = litPad();
    await advance(tester, 18);
    final replay = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Replay phrase');
    expect(tester.widget<IconButton>(replay).onPressed, isNotNull);
    await tester.tap(replay);
    await tester.pump();
    expect(litPad(), first);
    expect(tester.widget<IconButton>(replay).onPressed, isNull);
    await advance(tester, 52);
    expect(find.textContaining('Your turn: 0/1'), findsOneWidget);
    expect(find.textContaining('💛💛💛'), findsOneWidget);
    await tester.tap(pads.at(first));
    await tester.pump();
    expect(find.textContaining('1 / 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Echo scores all eight completed phrases', (tester) async {
    await pumpGame(tester, const EchoDrumsGame());
    final pads = find.byType(AnimatedContainer);
    final replay = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Replay phrase');
    int currentPad() {
      for (var index = 0; index < 4; index++) {
        final decoration = tester.widget<AnimatedContainer>(pads.at(index)).decoration! as BoxDecoration;
        if (decoration.color!.a > 0.99) return index;
      }
      return -1;
    }
    for (var round = 1; round <= 8; round++) {
      final phrase = <int>[];
      var previousPad = -1;
      for (var frame = 0; frame < 250; frame++) {
        final pad = currentPad();
        if (pad >= 0 && previousPad == -1) phrase.add(pad);
        previousPad = pad;
        if (tester.widget<IconButton>(replay).onPressed != null) break;
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(phrase.length, round);
      for (final pad in phrase) {
        await tester.tap(pads.at(pad));
        await tester.pump(const Duration(milliseconds: 10));
      }
    }
    expect(find.textContaining('8 / 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}