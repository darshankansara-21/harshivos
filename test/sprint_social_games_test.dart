import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> startSocialGame(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
}

List<Semantics> socialOptions(WidgetTester tester, Iterable<String> labels) =>
    tester.widgetList<Semantics>(find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        labels.contains(widget.properties.label))).toList();

Future<void> chooseSocial(WidgetTester tester, Semantics option) async {
  option.properties.onTap!();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Feelings switches from faces to words and locks a correct pick',
      (tester) async {
    const feelings = <String>['Happy', 'Sad', 'Angry', 'Scared', 'Surprised', 'Sleepy', 'Silly', 'Loving'];
    const facesByFeeling = <String, String>{
      'Happy': '😄', 'Sad': '😢', 'Angry': '😠', 'Scared': '😨',
      'Surprised': '😲', 'Sleepy': '😴', 'Silly': '😜', 'Loving': '🥰',
    };
    await startSocialGame(tester, const FeelingsMatchGame());
    final prompt = feelings.singleWhere((name) => find.text(name).evaluate().isNotEmpty);
    final faces = socialOptions(tester, feelings.map((name) => '$name face'));
    expect(faces.length, greaterThanOrEqualTo(3));
    await chooseSocial(tester, faces.firstWhere((option) => option.properties.label != '$prompt face'));
    expect(find.textContaining('Try again!'), findsOneWidget);
    await chooseSocial(tester, faces.singleWhere((option) => option.properties.label == '$prompt face'));
    await chooseSocial(tester, faces.firstWhere((option) => option.properties.label != '$prompt face'));
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.text('Which feeling fits this face?'), findsOneWidget);
    final words = socialOptions(tester, feelings);
    expect(words.length, greaterThanOrEqualTo(3));
    expect(find.textContaining('1 / 10'), findsOneWidget);
    final reverseAnswer = facesByFeeling.keys.singleWhere(
      (name) => find.text(facesByFeeling[name]!).evaluate().isNotEmpty);
    await chooseSocial(tester, words.singleWhere((option) => option.properties.label == reverseAnswer));
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.text('Which face feels like this?'), findsOneWidget);
    expect(find.textContaining('2 / 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Kindness requires both decisions and replay resets the stage',
      (tester) async {
    const answers = <String, List<String>>{
      'Your friend falls down.': <String>['Are you okay?', 'Ask if they want help getting up'],
      'Someone is new at school.': <String>['Want to play with us?', 'Let them choose whether to join'],
      'Your friend looks sad.': <String>["I'm here for you", 'Ask if they want company'],
      'Someone drops their books.': <String>['Let me help you', 'Ask before picking up their books'],
      'A friend shares their toy.': <String>['Thank you so much!', 'Give the toy back when asked'],
      'Someone makes a mistake.': <String>["It's okay, try again", 'Ask if they want help'],
      'Your friend wins a game.': <String>['Well done!', 'Celebrate with them'],
      'Someone feels left out.': <String>['Come join us!', 'Make room if they want to join'],
      'A friend is scared.': <String>["I'll stay with you", 'Ask what would help them feel safe'],
      'Someone is tired.': <String>['Have a rest', 'Give them time to rest'],
    };
    await startSocialGame(tester, const KindnessMatchGame());
    final scene = answers.keys.singleWhere((text) => find.text(text).evaluate().isNotEmpty);
    await chooseSocial(tester, socialOptions(tester, <String>[answers[scene]![0]]).single);
    expect(find.text('What could you do next?'), findsOneWidget);
    expect(find.textContaining('0 / 10'), findsOneWidget);
    final followUp = socialOptions(tester, <String>[answers[scene]![1]]).single;
    final other = tester.widgetList<Semantics>(find.byWidgetPredicate((widget) =>
        widget is Semantics && widget.properties.button == true &&
        widget.properties.onTap != null && widget.properties.label != followUp.properties.label &&
        widget.child is GestureDetector)).first;
    await chooseSocial(tester, other);
    expect(find.text('What could you do next?'), findsOneWidget);
    await chooseSocial(tester, followUp);
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.textContaining('1 / 10'), findsOneWidget);
    expect(find.text('What could you do next?'), findsNothing);
    for (var miss = 0; miss < 2; miss++) {
      final nextScene = answers.keys.singleWhere((text) => find.text(text).evaluate().isNotEmpty);
      final options = tester.widgetList<Semantics>(find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.button == true &&
          widget.properties.onTap != null && widget.child is GestureDetector));
      await chooseSocial(tester, options.firstWhere((option) => option.properties.label != answers[nextScene]![0]));
    }
    expect(find.text('Play again'), findsOneWidget);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(find.textContaining('0 / 10'), findsOneWidget);
    expect(find.text('What could you do next?'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Kindness completes ten distinct two-step scenes at large text',
      (tester) async {
    const answers = <String, List<String>>{
      'Your friend falls down.': <String>['Are you okay?', 'Ask if they want help getting up'],
      'Someone is new at school.': <String>['Want to play with us?', 'Let them choose whether to join'],
      'Your friend looks sad.': <String>["I'm here for you", 'Ask if they want company'],
      'Someone drops their books.': <String>['Let me help you', 'Ask before picking up their books'],
      'A friend shares their toy.': <String>['Thank you so much!', 'Give the toy back when asked'],
      'Someone makes a mistake.': <String>["It's okay, try again", 'Ask if they want help'],
      'Your friend wins a game.': <String>['Well done!', 'Celebrate with them'],
      'Someone feels left out.': <String>['Come join us!', 'Make room if they want to join'],
      'A friend is scared.': <String>["I'll stay with you", 'Ask what would help them feel safe'],
      'Someone is tired.': <String>['Have a rest', 'Give them time to rest'],
    };
    await startSocialGame(tester, MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
      child: const KindnessMatchGame(),
    ));
    final seen = <String>{};
    for (var round = 0; round < 10; round++) {
      final scene = answers.keys.singleWhere((text) => find.text(text).evaluate().isNotEmpty);
      expect(seen.add(scene), isTrue);
      await chooseSocial(tester, socialOptions(tester, <String>[answers[scene]![0]]).single);
      expect(find.text('What could you do next?'), findsOneWidget);
      await chooseSocial(tester, socialOptions(tester, <String>[answers[scene]![1]]).single);
      await tester.pump(const Duration(milliseconds: 230));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Play again'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}