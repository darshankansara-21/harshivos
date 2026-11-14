import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/goal_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> startGame(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
}

String direction(WidgetTester tester, String prefix) {
  final semantic = tester.widget<Semantics>(find.byWidgetPredicate(
    (widget) => widget is Semantics &&
        (widget.properties.label?.startsWith(prefix) ?? false),
  ));
  return semantic.properties.label!.split(' ').last;
}

Future<void> alignShape(WidgetTester tester) async {
  for (var turn = 0; turn < 4; turn++) {
    if (direction(tester, 'Target silhouette pointing ') ==
        direction(tester, 'Your shape pointing ')) return;
    await tester.tap(find.byKey(const ValueKey('shape-scout-turn-right')));
    await tester.pump();
  }
  fail('Could not align the shape');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Shape Scout locks a match and ignores callbacks from old runs',
      (tester) async {
    await startGame(tester, const ShapeScoutGame());
    await alignShape(tester);
    final match = find.byKey(const ValueKey('shape-scout-match'));
    final originalAction = tester.widget<FilledButton>(match).onPressed!;
    originalAction();
    originalAction();
    await tester.pump();
    expect(find.text('Aligned: 1 / 8'), findsOneWidget);
    expect(tester.widget<FilledButton>(match).onPressed, isNull);
    expect(tester.widget<IconButton>(
      find.byKey(const ValueKey('shape-scout-turn-right')),
    ).onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 160));
    final dynamic shell = tester.widget(find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_GoalShell',
    ));
    shell.onReset();
    await tester.pump();
    await alignShape(tester);
    await tester.tap(match);
    await tester.pump();
    final target = direction(tester, 'Target silhouette pointing ');
    final player = direction(tester, 'Your shape pointing ');
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text('Aligned: 1 / 8'), findsOneWidget);
    expect(direction(tester, 'Target silhouette pointing '), target);
    expect(direction(tester, 'Your shape pointing '), player);
    expect(tester.widget<FilledButton>(match).onPressed, isNull);
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.widget<FilledButton>(match).onPressed, isNotNull);

    final seenShapes = <String>{
      tester.widget<Text>(
        find.byKey(const ValueKey('shape-scout-target-name')),
      ).data!,
    };
    for (var round = 1; round < 8; round++) {
      seenShapes.add(tester.widget<Text>(
        find.byKey(const ValueKey('shape-scout-target-name')),
      ).data!);
      await alignShape(tester);
      await tester.tap(match);
      await tester.pump();
      if (round < 7) await tester.pump(const Duration(milliseconds: 320));
    }
    expect(seenShapes, hasLength(7));
    expect(find.text('Score 8 of 8'), findsOneWidget);
    expect(find.text('🔷'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Play again'));
    await tester.pump();
    expect(find.text('Aligned: 0 / 8'), findsOneWidget);
    expect(tester.widget<FilledButton>(match).onPressed, isNotNull);
  });

  testWidgets('Number Splash answer is actionable through semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    await startGame(tester, const NumberSplashGame());
    final pattern = RegExp(r'^(\d+) \+ (\d+) = \?$');
    final prompt = tester.widgetList<Text>(find.byType(Text))
        .map((text) => pattern.firstMatch(text.data ?? ''))
        .whereType<RegExpMatch>()
        .single;
    final answer = '${int.parse(prompt[1]!) + int.parse(prompt[2]!)}';
    final choice = find.byWidgetPredicate((widget) =>
        widget is Semantics && widget.properties.label == answer &&
        widget.properties.button == true);
    final node = tester.getSemantics(choice);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(find.textContaining('1 / 8'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}