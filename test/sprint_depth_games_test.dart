import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:harshivos/features/play/toys/mini_games.dart' show GameScores;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> startGame(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump(const Duration(milliseconds: 16));
}

List<Semantics> tiles(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('Row ') ?? false)))
    .toList();

Future<void> choose(WidgetTester tester, Semantics tile) async {
  tile.properties.onTap!();
  await tester.pump();
}

int combinedAnswer(List<Semantics> current) {
  final descriptions = current.map((tile) => tile.properties.label!
    .split(': ').last.split('. ').first).toList();
  final colors = descriptions.map((description) =>
    description.substring(0, description.lastIndexOf(' '))).toList();
  final shapes = descriptions.map((description) =>
    description.split(' ').last).toList();
  final commonColor = colors.firstWhere((color) =>
    colors.where((other) => color == other).length > 2);
  final commonShape = shapes.firstWhere((shape) =>
    shapes.where((other) => shape == other).length > 2);
  return List<int>.generate(current.length, (index) => index).singleWhere(
    (index) => colors[index] != commonColor && shapes[index] != commonShape);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Odd One Out requires both attributes after four finds',
      (tester) async {
    await startGame(tester, const OddOneOutGame());
    for (var round = 0; round < 4; round++) {
      final current = tiles(tester);
      final descriptions = current.map((tile) =>
          tile.properties.label!.split(': ').last).toList();
      final answer = descriptions.indexWhere((description) =>
          descriptions.where((other) => other == description).length == 1);
      expect(answer, greaterThanOrEqualTo(0));
      await choose(tester, current[answer]);
    }
    final current = tiles(tester);
    final dynamic painter = tester.widget<CustomPaint>(find.byWidgetPredicate(
        (widget) => widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_OddOneOutPainter')).painter;
    final int answer = combinedAnswer(current);
    expect(answer, painter.oddIndex);
    final int shapeOnly = painter.shapeDecoy;
    final int colorOnly = painter.colorDecoy;
    expect(find.text('Different shape AND colour'), findsOneWidget);
    expect(<int>{answer, shapeOnly, colorOnly}, hasLength(3));
    final labels = current.map((tile) => tile.properties.label!.split(': ').last).toList();
    expect(labels[shapeOnly], isNot(labels[answer]));
    expect(labels[colorOnly], isNot(labels[answer]));
    await choose(tester, current[shapeOnly]);
    expect(find.text('Look closely…'), findsOneWidget);
    expect(find.textContaining('4 / 10'), findsOneWidget);
    await choose(tester, tiles(tester)[colorOnly]);
    expect(find.textContaining('4 / 10'), findsOneWidget);
    await choose(tester, tiles(tester)[answer]);
    expect(find.textContaining('5 / 10'), findsOneWidget);
    for (var round = 5; round < 10; round++) {
      final next = tiles(tester);
      await choose(tester, next[combinedAnswer(next)]);
    }
    expect(find.text('Play again'), findsOneWidget);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(find.textContaining('0 / 10'), findsOneWidget);
    expect(tiles(tester).length, greaterThanOrEqualTo(4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Air Hockey awards a bank opportunity after a player strike',
      (tester) async {
    await startGame(tester, const AirHockeyGame());
    final paint = find.byWidgetPredicate((widget) => widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_HockeyPainter');
    final rect = tester.getRect(paint);
    await tester.dragFrom(Offset(rect.left + rect.width * 0.25,
        rect.top + rect.height * 0.70), const Offset(2, 0));
    await tester.pump(const Duration(milliseconds: 30));
    dynamic painter = tester.widget<CustomPaint>(paint).painter;
    for (var frame = 0; frame < 60 && (painter.py as double) < 0.61; frame++) {
      await tester.pump(const Duration(milliseconds: 30));
      painter = tester.widget<CustomPaint>(paint).painter;
    }
    final double puckX = painter.px;
    final double puckY = painter.py;
    final target = Offset(rect.left + rect.width * (puckX - 0.08),
        rect.top + rect.height * (puckY + 0.02));
    await tester.dragFrom(target, const Offset(2, 0));
    var bankSeen = false;
    for (var frame = 0; frame < 90; frame++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (find.text('Bank in play! Goal earns 2').evaluate().isNotEmpty) {
        bankSeen = true;
        break;
      }
    }
    expect(bankSeen, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Air Hockey strikes an approaching puck with the mallet',
      (tester) async {
    await startGame(tester, const AirHockeyGame());
    final paint = find.byWidgetPredicate((widget) => widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_HockeyPainter');
    final rect = tester.getRect(paint);
    dynamic painter = tester.widget<CustomPaint>(paint).painter;
    for (var frame = 0; frame < 60 && (painter.py as double) < 0.63; frame++) {
      await tester.pump(const Duration(milliseconds: 30));
      painter = tester.widget<CustomPaint>(paint).painter;
    }
    final double puckX = painter.px;
    final double puckY = painter.py;
    expect(puckY, greaterThanOrEqualTo(0.63));
    final target = Offset(rect.left + rect.width * puckX,
        rect.top + rect.height * (puckY + 0.045));
    await tester.dragFrom(target, const Offset(0, -4));
    await tester.pump(const Duration(milliseconds: 30));
    painter = tester.widget<CustomPaint>(paint).painter;
    final double afterHit = painter.py;
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    painter = tester.widget<CustomPaint>(paint).painter;
    expect(painter.py as double, lessThan(afterHit));
    expect(tester.takeException(), isNull);
  });

  test('a valid zero lower-score record is not replaced by a worse score',
      () async {
    const id = 'sprint_zero_low_score';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('best_low_$id');
    final scores = GameScores.instance;
    await scores.ensureLoaded();

    expect(scores.hasBestLow(id), isFalse);
    expect(await scores.submitLow(id, 0), 0);
    expect(scores.hasBestLow(id), isTrue);
    expect(await scores.submitLow(id, 1), 0);
    expect(await scores.submitLow(id, 0), 0);
  });
}