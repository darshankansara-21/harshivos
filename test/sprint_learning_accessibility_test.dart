import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

const feelings = <String, String>{
  'Happy': '😄',
  'Sad': '😢',
  'Angry': '😠',
  'Scared': '😨',
  'Surprised': '😲',
  'Sleepy': '😴',
  'Silly': '😜',
  'Loving': '🥰',
};

Future<void> startGame(WidgetTester tester, Widget game,
    {bool accessible = false}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(accessibleNavigation: accessible),
      child: Scaffold(body: game),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
}

Future<void> tick(WidgetTester tester, int steps) async {
  for (var step = 0; step < steps; step++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

List<Semantics> cards(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.endsWith(' card') ?? false)))
    .toList();

List<Semantics> options(WidgetTester tester, Iterable<String> labels) => tester
    .widgetList<Semantics>(find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        labels.contains(widget.properties.label)))
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('accessible previews wait for dismissal, including paid peek',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await startGame(tester, const MemoryFlipGame(), accessible: true);
    final preview = cards(tester).map((card) => card.properties.label).toList();
    expect(preview, hasLength(12));
    expect(preview, isNot(contains('Hidden card')));
    final firstCard = find.byWidgetPredicate((widget) =>
      widget is Semantics && widget.properties.label == preview.first).first;
    final previewNode = tester.getSemantics(firstCard).getSemanticsData();
    expect(previewNode.label, preview.first);
    expect(previewNode.hasAction(SemanticsAction.tap), isFalse);
    await tick(tester, 80);
    expect(cards(tester).map((card) => card.properties.label).toList(), preview);
    expect(find.text('Hide cards'), findsOneWidget);
    await tester.tap(find.text('Hide cards'));
    await tester.pump();
    expect(cards(tester).map((card) => card.properties.label),
        everyElement('Hidden card'));
    final hiddenNode = tester.getSemantics(find.byWidgetPredicate((widget) =>
      widget is Semantics && widget.properties.label == 'Hidden card').first)
      .getSemanticsData();
    expect(hiddenNode.label, 'Hidden card');
    expect(hiddenNode.hasAction(SemanticsAction.tap), isTrue);
    expect(find.textContaining('0/6 pairs'), findsOneWidget);
    await tester.tap(find.text('Peek (5s)'));
    await tester.pump();
    expect(cards(tester).map((card) => card.properties.label).toList(), preview);
    await tick(tester, 80);
    expect(cards(tester).map((card) => card.properties.label).toList(), preview);
    await tester.tap(find.text('Hide cards'));
    await tester.pump();
    expect(cards(tester).map((card) => card.properties.label),
        everyElement('Hidden card'));
    expect(find.text('Peek used'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    semantics.dispose();
  });

  testWidgets('ordinary preview and peek still finish on their timers',
      (tester) async {
    await startGame(tester, const MemoryFlipGame());
    expect(cards(tester).where((card) => card.properties.label == 'Hidden card'),
        isEmpty);
    await tick(tester, 31);
    expect(cards(tester).map((card) => card.properties.label),
        everyElement('Hidden card'));
    expect(find.text('Hide cards'), findsNothing);
    await tester.tap(find.text('Peek (5s)'));
    await tester.pump();
    expect(cards(tester).where((card) => card.properties.label == 'Hidden card'),
        isEmpty);
    await tick(tester, 20);
    expect(cards(tester).map((card) => card.properties.label),
        everyElement('Hidden card'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('preview follows accessibility changes and renews on next level',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final accessible = ValueNotifier<bool>(true);
    addTearDown(accessible.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: accessible,
        builder: (context, value, child) => MediaQuery(
          data: MediaQueryData(accessibleNavigation: value),
          child: child!,
        ),
        child: const Scaffold(body: MemoryFlipGame()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(cards(tester).map((card) => card.properties.label),
        everyElement('Hidden card'));
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    final preview = cards(tester).map((card) => card.properties.label!).toList();
    expect(cards(tester).every((card) => card.properties.onTap == null), isTrue);
    await tester.tap(find.text('Hide cards'));
    await tester.pump();
    final seen = <String>{};
    for (var index = 0; index < preview.length; index++) {
      if (!seen.add(preview[index])) continue;
      cards(tester)[index].properties.onTap!();
      await tester.pump();
      cards(tester)[preview.lastIndexOf(preview[index])].properties.onTap!();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 700));
    expect(cards(tester), hasLength(16));
    await tick(tester, 80);
    expect(cards(tester).where((card) => card.properties.label == 'Hidden card'),
        isEmpty);
    accessible.value = false;
    await tester.pump();
    expect(find.text('Hide cards'), findsNothing);
    await tick(tester, 40);
    expect(cards(tester).map((card) => card.properties.label),
        everyElement('Hidden card'));
    accessible.value = true;
    await tester.pump();
    await tester.tap(find.text('Peek (5s)'));
    await tester.pump();
    await tick(tester, 80);
    expect(find.text('Hide cards'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Feelings retains answered mode until each new deal',
      (tester) async {
    await startGame(tester, const FeelingsMatchGame());
    for (var round = 0; round < 10; round++) {
      final chooseWord = round.isOdd;
      final instruction = chooseWord
          ? 'Which feeling fits this face?'
          : 'Which face feels like this?';
      final prompt = feelings.keys.singleWhere((name) =>
          find.text(chooseWord ? feelings[name]! : name).evaluate().isNotEmpty);
      final labels = feelings.keys.map((name) => chooseWord ? name : '$name face');
      final before = options(tester, labels)
          .map((option) => option.properties.label)
          .toList();
      final correctLabel = chooseWord ? prompt : '$prompt face';
      options(tester, labels)
          .singleWhere((option) => option.properties.label == correctLabel)
          .properties.onTap!();
      await tester.pump();
      expect(find.text(instruction), findsOneWidget);
      expect(options(tester, labels).map((option) => option.properties.label), before);
      expect(find.text(chooseWord ? feelings[prompt]! : prompt), findsOneWidget);
      final correctOption = find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == correctLabel &&
          widget.properties.button == true);
      final tile = tester.widget<AnimatedContainer>(find.descendant(
          of: correctOption, matching: find.byType(AnimatedContainer)));
      expect((tile.decoration! as BoxDecoration).color, const Color(0xFF80ED99));
      options(tester, labels)
          .firstWhere((option) => option.properties.label != correctLabel)
          .properties.onTap!();
      await tester.pump();
      expect(find.textContaining('${round + 1} / 10'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 219));
      expect(find.text(instruction), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2));
      if (round < 9) expect(find.text(instruction), findsNothing);
    }
    expect(find.text('Play again'), findsOneWidget);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(find.text('Which face feels like this?'), findsOneWidget);
    expect(find.textContaining('0 / 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}