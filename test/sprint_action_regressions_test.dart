import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/companion/companion.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder nextStar() => find.byWidgetPredicate((widget) =>
    widget is Semantics &&
    (widget.properties.label?.startsWith('Next star,') ?? false));

Future<void> startGame(WidgetTester tester, Widget game) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> waitForGo(WidgetTester tester) async {
  for (var step = 0; step < 50 && find.text('TAP!').evaluate().isEmpty; step++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  expect(find.text('TAP!'), findsOneWidget);
}

int quickScore(WidgetTester tester) {
  final hud = tester.widget<Text>(find.byWidgetPredicate((widget) =>
      widget is Text && (widget.data?.contains('Quick Tap   ') ?? false)));
  return int.parse(RegExp(r'Quick Tap\s+(\d+) / 5').firstMatch(hud.data!)!.group(1)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('closed ordered paths earn a badge from the starting star', (tester) async {
    dynamic painter;
    Finder canvas = find.byWidgetPredicate((widget) => widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_StarPathPainter');
    for (var attempt = 0; attempt < 30; attempt++) {
      await startGame(tester, const StarPathGame());
      painter = tester.widget<CustomPaint>(canvas).painter;
      final List<List<double>> stars = painter.stars;
      if (stars.first[0] == stars.last[0] && stars.first[1] == stars.last[1]) break;
      await tester.pumpWidget(const SizedBox());
    }
    final List<List<double>> stars = painter.stars;
    expect(stars.first, stars.last);
    final size = tester.getSize(canvas);
    final origin = tester.getTopLeft(canvas);
    Offset starPosition(List<double> star) =>
        origin + Offset(star[0] * size.width, star[1] * size.height);
    final gesture = await tester.startGesture(starPosition(stars.first));
    await tester.pump();
    expect(find.text('Follow the glowing star'), findsNothing);
    for (var index = 1; index < stars.length; index++) {
      await gesture.moveTo(starPosition(stars[index]));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.textContaining('1 star badges'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a nonadjacent star forfeits the current path badge', (tester) async {
    await startGame(tester, const StarPathGame());
    final nextCenter = tester.getCenter(nextStar());
    final canvas = find.byWidgetPredicate((widget) => widget is CustomPaint &&
      widget.painter.runtimeType.toString() == '_StarPathPainter');
    final dynamic painter = tester.widget<CustomPaint>(canvas).painter;
    final List<List<double>> stars = painter.stars;
    final size = tester.getSize(canvas);
    final firstCenter = tester.getTopLeft(canvas) +
      Offset(stars.first[0] * size.width, stars.first[1] * size.height);
    final later = find.byWidgetPredicate((widget) => widget is Semantics &&
        (widget.properties.label?.startsWith('Star ') ?? false));
    final skip = later.evaluate().firstWhere((element) =>
      (tester.getCenter(find.byWidget(element.widget)) - nextCenter).distance > 50 &&
      (tester.getCenter(find.byWidget(element.widget)) - firstCenter).distance > 50);
    (skip.widget as Semantics).properties.onTap!();
    await tester.pump();
    expect(find.text('Follow the glowing star'), findsOneWidget);
    final label = tester.widget<Semantics>(nextStar()).properties.label!;
    final total = int.parse(RegExp(r'of (\d+)').firstMatch(label)!.group(1)!);
    for (var index = 1; index < total; index++) {
      tester.widget<Semantics>(nextStar()).properties.onTap!();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.textContaining('0 star badges'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Quick Tap compares compatible scores with an existing record', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best_quick_tap', 550);
    final events = <ExperienceEvent>[];
    await startGame(tester, NotificationListener<CompanionEventNotification>(
      onNotification: (notification) {
        events.add(notification.event);
        return false;
      },
      child: const QuickTapGame(),
    ));
    for (var round = 0; round < 5; round++) {
      await waitForGo(tester);
      for (var step = 0; step < 3; step++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.tap(find.text('TAP!'));
      await tester.pump();
      expect(quickScore(tester), (round + 1) * 96);
      if (round < 4) {
        for (var step = 0; step < 12; step++) {
          await tester.pump(const Duration(milliseconds: 80));
        }
      }
    }
    expect(prefs.getInt('best_quick_tap'), 550);
    expect(events, isNot(contains(ExperienceEvent.personalBest)));
    expect(find.text('🏆 New best!'), findsNothing);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    for (var round = 0; round < 5; round++) {
      await waitForGo(tester);
      await tester.tap(find.text('TAP!'));
      await tester.pump();
      if (round < 4) {
        for (var step = 0; step < 12; step++) {
          await tester.pump(const Duration(milliseconds: 80));
        }
      }
    }
    expect(prefs.getInt('best_quick_tap'), 600);
    expect(events.where((event) => event == ExperienceEvent.personalBest).length, 1);
    expect(find.text('🏆 New best!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}