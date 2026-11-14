import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpGame(WidgetTester tester, Widget game,
  {bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: game),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
}

List<Semantics> labelled(WidgetTester tester, String prefix) => tester
    .widgetList<Semantics>(find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith(prefix) ?? false)))
    .toList();

Future<void> activate(WidgetTester tester, Semantics semantics) async {
  semantics.properties.onTap!();
  await tester.pump();
}

Future<void> tick(WidgetTester tester, int steps) async {
  for (var step = 0; step < steps; step++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Pattern Weaver opens with a real alternating pattern',
      (tester) async {
    await pumpGame(tester, const PatternWeaverGame());
    final pattern = tester.widget<Semantics>(find.byWidgetPredicate(
      (widget) => widget is Semantics &&
          (widget.properties.label?.startsWith('Pattern so far: ') ?? false),
    ));
    final beads = pattern.properties.label!
        .substring('Pattern so far: '.length)
        .split(', ');
    expect(beads[0], isNot(beads[1]));
    expect(beads[2], beads[0]);
    expect(beads[3], beads[1]);
  });

  testWidgets('Pattern Weaver sequences can be solved and replayed',
      (tester) async {
    await pumpGame(tester, const PatternWeaverGame());
    var repaired = false;
    var testedWrongRepair = false;
    for (var round = 0; round < 10; round++) {
      final label = labelled(tester, 'Pattern so far: ').single.properties.label!;
      final beads = label.substring('Pattern so far: '.length).split(', ');
      final missing = beads.indexOf('missing bead');
      if (missing < beads.length - 1) repaired = true;
      final answers = <String>{};
      for (var length = 2; length <= 5; length++) {
        final known = List<String?>.filled(length, null);
        var consistent = true;
        for (var index = 0; index < beads.length; index++) {
          if (index == missing) continue;
          final slot = index % length;
          if (known[slot] != null && known[slot] != beads[index]) {
            consistent = false;
            break;
          }
          known[slot] = beads[index];
        }
        if (consistent && known[missing % length] != null) {
          answers.add(known[missing % length]!);
        }
      }
      expect(answers, hasLength(1));
      final answer = answers.single;
        if (missing < beads.length - 1 && !testedWrongRepair) {
        final wrong = labelled(tester, 'Option ')
          .firstWhere((item) => !item.properties.label!.endsWith(answer));
        await activate(tester, wrong);
        expect(labelled(tester, 'Pattern so far: ').single.properties.label, label);
        expect(find.textContaining('Look at the pattern'), findsOneWidget);
        testedWrongRepair = true;
        }
      final option = labelled(tester, 'Option ')
          .singleWhere((item) => item.properties.label!.endsWith(answer));
        final optionFinder = find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == option.properties.label);
        await tester.tapAt(tester.getRect(optionFinder).center);
        await tester.pump();
    }
    expect(repaired, isTrue);
    expect(testedWrongRepair, isTrue);
    expect(find.text('Play again'), findsOneWidget);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(find.textContaining('0 / 10'), findsOneWidget);
    expect(labelled(tester, 'Pattern so far: '), hasLength(1));
  });

  testWidgets('Ball Sort undo restores both tubes after a pour', (tester) async {
    await pumpGame(tester, const BallSortGame());
    final before = labelled(tester, 'Tube ')
        .map((tube) => tube.properties.label!)
        .toList();
    final source = before.indexWhere((label) => !label.contains('empty'));
    final destination = before.indexWhere((label) => label.contains('empty'));
    expect(source, greaterThanOrEqualTo(0));
    expect(destination, greaterThanOrEqualTo(0));
    await activate(tester, labelled(tester, 'Tube ')[source]);
    await activate(tester, labelled(tester, 'Tube ')[destination]);
    expect(labelled(tester, 'Tube ')[destination].properties.label,
        isNot(before[destination]));
    await tester.tap(find.byTooltip('Undo last pour'));
    await tester.pump();
    expect(labelled(tester, 'Tube ').map((tube) => tube.properties.label).toList(),
        before);
    expect(tester.widget<IconButton>(find.byWidgetPredicate((widget) =>
      widget is IconButton && widget.tooltip == 'Undo last pour')).onPressed,
        isNull);
    await activate(tester, labelled(tester, 'Tube ')[source]);
    await activate(tester, labelled(tester, 'Tube ')[destination]);
    await tester.tap(find.byTooltip('New puzzle'));
    await tester.pump();
    expect(tester.widget<IconButton>(find.byWidgetPredicate((widget) =>
      widget is IconButton && widget.tooltip == 'Undo last pour')).onPressed,
      isNull);
    expect(labelled(tester, 'Tube ').where((tube) =>
      tube.properties.label!.contains('empty')), hasLength(2));
  });

  testWidgets('Slide Puzzle undo restores the board and counts both moves',
      (tester) async {
    await pumpGame(tester, const SlidePuzzleGame());
    List<String> board() => tester
        .widgetList<Semantics>(find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            (widget.properties.label == 'Empty space' ||
                (widget.properties.label?.startsWith('Tile ') ?? false))))
        .map((cell) => cell.properties.label!)
        .toList();
    final before = board();
    final blank = before.indexOf('Empty space');
    final neighbours = <int>[
      if (blank ~/ 3 > 0) blank - 3,
      if (blank ~/ 3 < 2) blank + 3,
      if (blank % 3 > 0) blank - 1,
      if (blank % 3 < 2) blank + 1,
    ];
    final chosen = neighbours.firstWhere((position) {
      final next = List<String>.of(before);
      next[blank] = next[position];
      next[position] = 'Empty space';
      return next.take(8).toList().asMap().entries.any(
          (entry) => entry.value != 'Tile ${entry.key + 1}');
    });
    await activate(tester, labelled(tester, before[chosen]).single);
    expect(board(), isNot(before));
    expect(find.textContaining('1 moves'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo last slide'));
    await tester.pump();
    expect(board(), before);
    expect(find.textContaining('2 moves'), findsOneWidget);
  });

  testWidgets('Memory Flip tracks pairs and clears a selected card on timeout',
      (tester) async {
    await pumpGame(tester, const MemoryFlipGame());
    final preview = tester.widgetList<Semantics>(find.byWidgetPredicate(
      (widget) => widget is Semantics &&
          (widget.properties.label?.endsWith(' card') ?? false),
    )).map((card) => card.properties.label!).toList();
    expect(preview, hasLength(12));
    final first = preview.first;
    final match = preview.lastIndexOf(first);
    expect(match, greaterThan(0));
    await tick(tester, 31);
    expect(labelled(tester, 'Hidden card'), hasLength(12));
    await activate(tester, labelled(tester, 'Hidden card').first);
    final hidden = labelled(tester, 'Hidden card');
    await activate(tester, hidden[match - 1]);
    expect(labelled(tester, 'Matched '), hasLength(2));
    expect(find.textContaining('1/6 pairs'), findsOneWidget);
    await activate(tester, labelled(tester, 'Hidden card').first);
    await tick(tester, 370);
    expect(labelled(tester, 'Hidden card'), hasLength(10));
    expect(find.textContaining('Too slow!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Memory Flip peek trades time for a second look once per level',
      (tester) async {
    await pumpGame(tester, const MemoryFlipGame());
    await tick(tester, 31);
    await activate(tester, labelled(tester, 'Hidden card').first);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Peek (5s)')).onPressed, isNull);
    await tick(tester, 370);
    expect(find.textContaining('Too slow!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    final timeAfterTimeout = tester.widget<Text>(find.textContaining('1 · 0/6 pairs')).data!;
    final secondsAfterTimeout = int.parse(RegExp(r'⏱ (\d+)s').firstMatch(timeAfterTimeout)!.group(1)!);
    await tester.tap(find.widgetWithText(TextButton, 'Peek (5s)'));
    await tester.pump();
    final preview = tester.widgetList<Semantics>(find.byWidgetPredicate(
      (widget) => widget is Semantics &&
          (widget.properties.label?.endsWith(' card') ?? false),
    )).map((card) => card.properties.label!).toList();
    expect(preview, hasLength(12));
    expect(find.text('Peek used'), findsOneWidget);
    await tick(tester, 20);
    final after = tester.widget<Text>(find.textContaining('1 · 0/6 pairs')).data!;
    final secondsAfter = int.parse(RegExp(r'⏱ (\d+)s').firstMatch(after)!.group(1)!);
    expect(secondsAfterTimeout - secondsAfter, 5);
    expect(labelled(tester, 'Hidden card'), hasLength(12));
    final match = preview.lastIndexOf(preview.first);
    await activate(tester, labelled(tester, 'Hidden card').first);
    await activate(tester, labelled(tester, 'Hidden card')[match - 1]);
    expect(find.textContaining('1/6 pairs'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Peek used')).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Memory Flip renews peek on the next level with reduced motion',
      (tester) async {
    await pumpGame(tester, const MemoryFlipGame(), reduceMotion: true);
    await tick(tester, 31);
    await tester.tap(find.widgetWithText(TextButton, 'Peek (5s)'));
    await tester.pump();
    List<Semantics> cards() => tester.widgetList<Semantics>(find.byWidgetPredicate(
      (widget) => widget is Semantics &&
          (widget.properties.label?.endsWith(' card') ?? false),
    )).toList();
    final preview = cards().map((card) => card.properties.label!).toList();
    expect(preview, hasLength(12));
    await tick(tester, 20);
    final found = <String>{};
    for (var index = 0; index < preview.length; index++) {
      if (!found.add(preview[index])) continue;
      final match = preview.lastIndexOf(preview[index]);
      await activate(tester, cards()[index]);
      await activate(tester, cards()[match]);
      if (found.length == 1) {
        final animation = tester.widget<TweenAnimationBuilder<double>>(
            find.byKey(ValueKey('mem-$index-true')));
        expect(animation.duration, Duration.zero);
      }
    }
    await tester.pump(const Duration(milliseconds: 700));
    await tick(tester, 40);
    expect(find.textContaining('Level 2'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Peek (5s)')).onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Memory Flip cannot spend the last five seconds on a peek',
      (tester) async {
    await pumpGame(tester, const MemoryFlipGame());
    await tick(tester, 31);
    await tick(tester, 320);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Peek (5s)')).onPressed,
        isNull);
    expect(find.textContaining('0/6 pairs'), findsOneWidget);
    await tick(tester, 47);
    expect(find.textContaining('Too slow!'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Peek (5s)')).onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Odd One Out restores a life for three correct finds and replays',
      (tester) async {
    await pumpGame(tester, const OddOneOutGame());
    List<Semantics> tiles() => labelled(tester, 'Row ');
    int oddIndex() {
      final descriptions = tiles().map((tile) =>
          tile.properties.label!.split(': ').last).toList();
      return descriptions.indexWhere((description) =>
          descriptions.where((other) => other == description).length == 1);
    }
    var odd = oddIndex();
    expect(odd, greaterThanOrEqualTo(0));
    await activate(tester, tiles()[(odd + 1) % tiles().length]);
    for (var round = 0; round < 3; round++) {
      odd = oddIndex();
      expect(odd, greaterThanOrEqualTo(0));
      await activate(tester, tiles()[odd]);
    }
    expect(find.text('Three in a row! Life restored'), findsOneWidget);
    for (var miss = 0; miss < 3; miss++) {
      odd = oddIndex();
      await activate(tester, tiles()[(odd + 1) % tiles().length]);
    }
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(find.textContaining('0/3 streak'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}