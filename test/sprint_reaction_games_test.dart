import 'package:flutter/material.dart';
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

Future<void> waitForQuickTapGo(WidgetTester tester) async {
  for (var step = 0; step < 50 && find.text('TAP!').evaluate().isEmpty; step++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
  expect(find.text('TAP!'), findsOneWidget);
}

int quickTapScore(WidgetTester tester) {
  final hud = tester.widget<Text>(find.byWidgetPredicate((widget) =>
      widget is Text && (widget.data?.contains('Quick Tap   ') ?? false)));
  return int.parse(RegExp(r'Quick Tap\s+(\d+) / 5').firstMatch(hud.data!)!.group(1)!);
}

int quickTapReactionMs(WidgetTester tester) {
  final result = tester.widget<Text>(find.byWidgetPredicate((widget) =>
      widget is Text && RegExp(r'^\d+ms$').hasMatch(widget.data ?? '')));
  return int.parse(result.data!.replaceAll('ms', ''));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Quick Tap tracks a streak without changing historical scoring',
      (tester) async {
    await pumpGame(tester, const QuickTapGame());
    await waitForQuickTapGo(tester);
    await tester.tap(find.text('TAP!'));
    await tester.pump();
    expect(find.textContaining('Streak 1'), findsOneWidget);
    final firstScore = quickTapScore(tester);
    expect(firstScore, (120 - quickTapReactionMs(tester) ~/ 10).clamp(5, 120));
    for (var step = 0; step < 15; step++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await waitForQuickTapGo(tester);
    await tester.tap(find.text('TAP!'));
    await tester.pump();
    expect(find.textContaining('Streak 2'), findsOneWidget);
    expect(quickTapScore(tester) - firstScore,
        (120 - quickTapReactionMs(tester) ~/ 10).clamp(5, 120));
    for (var step = 0; step < 15; step++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('Wait…'), findsOneWidget);
    await tester.tap(find.text('Wait…'));
    await tester.pump();
    expect(find.textContaining('Streak reset'), findsOneWidget);
    await tester.tap(find.text('Too soon!'));
    await tester.pump();
    await waitForQuickTapGo(tester);
    await tester.tap(find.text('TAP!'));
    await tester.pump();
    expect(find.textContaining('Streak 1'), findsOneWidget);
  });

  testWidgets('Bug Catch earns and consumes a shield', (tester) async {
    await pumpGame(tester, const BugCatchGame());
    await tester.pump(const Duration(milliseconds: 80));
    final banner = tester.widget<Text>(find.textContaining('Catch the '));
    final target = RegExp(r'Catch the (\w+) bugs').firstMatch(banner.data!)!.group(1)!;
    for (var catchNumber = 0; catchNumber < 3; catchNumber++) {
      final bug = find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == '$target bug');
      expect(bug, findsWidgets);
      tester.widget<Semantics>(bug.first).properties.onTap!();
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.textContaining('Shield ready'), findsOneWidget);
    final wrongBug = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        widget.properties.label?.endsWith(' bug') == true &&
        widget.properties.label != '$target bug');
    expect(wrongBug, findsWidgets);
    tester.widget<Semantics>(wrongBug.first).properties.onTap!();
    await tester.pump();
    expect(find.textContaining('Shield saved a life!'), findsOneWidget);
    expect(find.textContaining('💛💛💛'), findsOneWidget);
    tester.widget<Semantics>(wrongBug.first).properties.onTap!();
    await tester.pump();
    expect(find.textContaining('💛💛 ·'), findsOneWidget);
  });

  testWidgets('Count & Pop checks the count instead of finishing automatically',
      (tester) async {
    await pumpGame(tester, const CountPopGame());
    final prompt = tester.widget<Text>(find.byWidgetPredicate((widget) =>
      widget is Text && RegExp(r'Pop \d+ bubbles').hasMatch(widget.data ?? '')));
    final need = int.parse(RegExp(r'Pop (\d+) bubbles').firstMatch(prompt.data!)!.group(1)!);
    await tester.tap(find.text('Check count'));
    await tester.pump();
    expect(find.text('Keep counting!'), findsOneWidget);
    for (var count = 0; count < need + 1; count++) {
      final bubbles = find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == 'Bubble');
      tester.widget<Semantics>(bubbles.first).properties.onTap!();
      await tester.pump();
    }
    await tester.tap(find.text('Check count'));
    await tester.pump();
    expect(find.text('Too many. Try again!'), findsOneWidget);
    for (var count = 0; count < need; count++) {
      final bubbles = find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == 'Bubble');
      tester.widget<Semantics>(bubbles.first).properties.onTap!();
      await tester.pump();
    }
    await tester.tap(find.text('Check count'));
    await tester.pump();
    expect(find.textContaining('Yes! You popped $need'), findsOneWidget);
  });

  testWidgets('Star Path rewards ordered paths and gently flags a skipped star',
      (tester) async {
    await pumpGame(tester, const StarPathGame());
    final next = find.byWidgetPredicate((widget) => widget is Semantics &&
        (widget.properties.label?.startsWith('Next star,') ?? false));
    final later = find.byWidgetPredicate((widget) => widget is Semantics &&
        (widget.properties.label?.startsWith('Star ') ?? false));
    final nextCenter = tester.getCenter(next);
    final canvas = find.byWidgetPredicate((widget) => widget is CustomPaint &&
      widget.painter.runtimeType.toString() == '_StarPathPainter');
    final dynamic painter = tester.widget<CustomPaint>(canvas).painter;
    final List<List<double>> stars = painter.stars;
    final size = tester.getSize(canvas);
    final firstCenter = tester.getTopLeft(canvas) +
      Offset(stars.first[0] * size.width, stars.first[1] * size.height);
    final differentStar = later.evaluate().firstWhere((element) =>
      (tester.getCenter(find.byWidget(element.widget)) - nextCenter).distance > 50 &&
      (tester.getCenter(find.byWidget(element.widget)) - firstCenter).distance > 50);
    (differentStar.widget as Semantics).properties.onTap!();
    final staleAction = tester.widget<Semantics>(next).properties.onTap!;
    await tester.pump();
    expect(find.text('Follow the glowing star'), findsOneWidget);
    for (var path = 0; path < 2; path++) {
      final label = tester.widget<Semantics>(next).properties.label!;
      final total = int.parse(RegExp(r'of (\d+)').firstMatch(label)!.group(1)!);
      for (var step = 1; step < total; step++) {
        tester.widget<Semantics>(next).properties.onTap!();
        await tester.pump();
      }
      if (path == 0) {
        final nextLabel = tester.widget<Semantics>(next).properties.label;
        staleAction();
        await tester.pump();
        expect(tester.widget<Semantics>(next).properties.label, nextLabel);
      }
    }
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.textContaining('1 star badges'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Sorting Train sends full wagons and finishes after delivery',
      (tester) async {
    await pumpGame(tester, const SortingTrainGame());
    Finder wagons() => find.byWidgetPredicate((widget) => widget is Semantics &&
        (widget.properties.label?.startsWith('Wagon ') ?? false));
    for (var parcel = 0; parcel < 12; parcel++) {
      final parcelFinder = find.byWidgetPredicate((widget) => widget is Semantics &&
          (widget.properties.label?.startsWith('Parcel to load:') ?? false));
      final name = tester.widget<Semantics>(parcelFinder).properties.label!.split(': ')[1];
      final matching = wagons().evaluate().map((element) => element.widget as Semantics)
          .firstWhere((widget) => widget.properties.label!.contains(': $name,'));
      if (matching.properties.label!.contains('tap to send')) {
        matching.properties.onTap!();
        await tester.pump();
        expect(find.textContaining('Sent 2 parcels!'), findsOneWidget);
      }
      final refreshed = wagons().evaluate().map((element) => element.widget as Semantics)
          .firstWhere((widget) => widget.properties.label!.contains(': $name,'));
      refreshed.properties.onTap!();
      await tester.pump();
    }
    expect(find.textContaining('Send the remaining wagons!'), findsOneWidget);
    while (true) {
      final remaining = wagons().evaluate().map((element) => element.widget as Semantics)
          .where((widget) => widget.properties.label!.contains('tap to send')).toList();
      if (remaining.isEmpty) break;
      remaining.first.properties.onTap!();
      await tester.pump();
    }
    expect(find.text('Play again'), findsOneWidget);
  });
}