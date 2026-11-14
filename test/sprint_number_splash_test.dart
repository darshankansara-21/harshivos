import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/goal_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Number Splash introduces missing operands and remains no-fail',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NumberSplashGame())),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();

    final equationPattern = RegExp(r'^(\d+|\?) ([+−]) (\d+|\?) = (\d+|\?)$');
    final missingPositions = <int>{};
    for (var round = 0; round < 8; round++) {
      final prompts = tester.widgetList<Text>(find.byType(Text)).where(
            (text) => equationPattern.hasMatch(text.data ?? ''),
          );
      expect(prompts.length, 1);
      final match = equationPattern.firstMatch(prompts.single.data!)!;
      final left = match[1];
      final operator = match[2];
      final right = match[3];
      final result = match[4];
      final int answer;
      if (left == '?') {
        missingPositions.add(1);
        answer = operator == '+'
            ? int.parse(result!) - int.parse(right!)
            : int.parse(result!) + int.parse(right!);
      } else if (right == '?') {
        missingPositions.add(2);
        answer = operator == '+'
            ? int.parse(result!) - int.parse(left!)
            : int.parse(left!) - int.parse(result!);
      } else {
        missingPositions.add(3);
        answer = operator == '+'
            ? int.parse(left!) + int.parse(right!)
            : int.parse(left!) - int.parse(right!);
      }
      final tiles = <Finder>[
        for (var index = 0; index < 6; index++)
          if (find.byKey(ValueKey('number_splash-option-$index')).evaluate().isNotEmpty)
            find.byKey(ValueKey('number_splash-option-$index')),
      ];
      final values = tiles.map((tile) {
        final label = tester.widget<Text>(
          find.descendant(of: tile, matching: find.byType(Text)),
        );
        return int.parse(label.data!);
      }).toList();
      expect(values.toSet().length, values.length);
      expect(values.where((value) => value == answer).length, 1);
      expect(values.every((value) => value >= 0), isTrue);

      if (round == 3) {
        final wrongIndex = values.indexWhere((value) => value != answer);
        await tester.tap(tiles[wrongIndex]);
        await tester.pump();
        expect(find.text(prompts.single.data!), findsOneWidget);
        expect(find.textContaining('3 / 8'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.tap(tiles[values.indexOf(answer)]);
      await tester.pump();
      if (round == 0) {
        await tester.tap(tiles[values.indexOf(answer)]);
        await tester.pump();
        expect(find.textContaining('1 / 8'), findsOneWidget);
      }
      if (round < 7) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    expect(missingPositions, <int>{1, 2, 3});
    expect(find.text('Score 8 of 8'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Play again'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Play again'));
    await tester.pump();
    expect(find.textContaining('0 / 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}