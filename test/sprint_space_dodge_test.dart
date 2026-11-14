import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

final field = find.byWidgetPredicate((widget) =>
    widget is Semantics &&
    (widget.properties.label?.startsWith('Meteor field.') ?? false));

Future<dynamic> startGame(WidgetTester tester,
    {bool reducedMotion = false}) async {
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: const Scaffold(body: SpaceDodgeGame()),
    ),
  ));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
  return tester.state(find.byType(SpaceDodgeGame));
}

void action(WidgetTester tester, String label) {
  final actions =
      tester.widget<Semantics>(field).properties.customSemanticsActions!;
  actions.entries.singleWhere((entry) => entry.key.label == label).value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('charged fast swipe breaks a meteor before release, once',
      (tester) async {
    final dynamic state = await startGame(tester);
    state.debugSpaceDodgeSetup(energy: 1.0, meteorX: 0.6);
    final rect = tester.getRect(field);
    final start = rect.topLeft + Offset(rect.width * 0.5, rect.height * 0.85);
    final gesture = await tester.createGesture();
    await gesture.down(start);
    await gesture.moveTo(start + Offset(rect.width * 0.25, 0),
        timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    final (double energy, double dash, int lives, int bonus, int meteors) =
        state.debugSpaceDodgeState;
    expect(energy, 0);
    expect(dash, greaterThan(0));
    expect(lives, 3);
    expect(bonus, 8);
    expect(meteors, 0);
    await gesture.up(timeStamp: const Duration(milliseconds: 50));
    await tester.pump();
    expect(
        (state.debugSpaceDodgeState as (double, double, int, int, int)).$4, 8);
  });

  testWidgets('slow or uncharged movement does not start a dash',
      (tester) async {
    final dynamic state = await startGame(tester);
    state.debugSpaceDodgeSetup(energy: 1.0);
    final rect = tester.getRect(field);
    final start = rect.center;
    var gesture = await tester.createGesture();
    await gesture.down(start);
    await gesture.moveBy(const Offset(30, 0),
        timeStamp: const Duration(milliseconds: 200));
    await gesture.up(timeStamp: const Duration(milliseconds: 210));
    expect(
        (state.debugSpaceDodgeState as (double, double, int, int, int)).$1, 1);
    state.debugSpaceDodgeSetup();
    gesture = await tester.createGesture();
    await gesture.down(start, timeStamp: const Duration(seconds: 1));
    await gesture.moveBy(const Offset(100, 0),
        timeStamp: const Duration(milliseconds: 1040));
    expect(
        (state.debugSpaceDodgeState as (double, double, int, int, int)).$2, 0);
    await gesture.up();
  });

  testWidgets('semantic dash and nudge protect under reduced motion',
      (tester) async {
    final dynamic state = await startGame(tester, reducedMotion: true);
    state.debugSpaceDodgeSetup(energy: 1.0, meteorX: 0.6);
    action(tester, 'Activate phase dash');
    action(tester, 'Nudge ship right');
    await tester.pump();
    final (double energy, double dash, int lives, int bonus, int meteors) =
        state.debugSpaceDodgeState;
    expect(energy, 0);
    expect(dash, greaterThan(0));
    expect(lives, 3);
    expect(bonus, 8);
    expect(meteors, 0);
  });

  testWidgets('cancel clears input and next swipe can activate',
      (tester) async {
    final dynamic state = await startGame(tester);
    state.debugSpaceDodgeSetup(energy: 1.0);
    final start = tester.getRect(field).center;
    var gesture = await tester.createGesture();
    await gesture.down(start);
    await gesture.cancel();
    gesture = await tester.createGesture();
    await gesture.down(start, timeStamp: const Duration(seconds: 1));
    await gesture.moveBy(const Offset(100, 0),
        timeStamp: const Duration(milliseconds: 1040));
    expect(
        (state.debugSpaceDodgeState as (double, double, int, int, int)).$1, 0);
    await gesture.up();
  });

  testWidgets('small fast moves activate and cannot spend twice per gesture',
      (tester) async {
    final dynamic state = await startGame(tester);
    state.debugSpaceDodgeSetup(energy: 1.0);
    final start = tester.getRect(field).center;
    final gesture = await tester.createGesture();
    await gesture.down(start);
    await gesture.moveBy(const Offset(10, 0),
        timeStamp: const Duration(milliseconds: 10));
    await gesture.moveBy(const Offset(10, 0),
        timeStamp: const Duration(milliseconds: 20));
    expect(
        (state.debugSpaceDodgeState as (double, double, int, int, int)).$1, 0);
    state.debugSpaceDodgeSetup(energy: 1.0);
    await gesture.moveBy(const Offset(40, 0),
        timeStamp: const Duration(milliseconds: 40));
    expect(
        (state.debugSpaceDodgeState as (double, double, int, int, int)).$1, 1);
    await gesture.cancel();
  });

  testWidgets('unprotected meteor hits; replay resets dash and pointer',
      (tester) async {
    final dynamic state = await startGame(tester);
    state.debugSpaceDodgeSetup(energy: 1.0);
    final start = tester.getRect(field).center;
    final gesture = await tester.createGesture();
    await gesture.down(start);
    await gesture.moveBy(const Offset(100, 0),
        timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    state.onTick(0.8);
    for (var hit = 0; hit < 3; hit++) {
      final painter = tester.widget<CustomPaint>(find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() == '_SpacePainter'));
      final dynamic spacePainter = painter.painter;
      state.debugSpaceDodgeSetup(meteorX: spacePainter.shipX);
      state.onTick(0.01);
      if (hit < 2) state.onTick(1.2);
      await tester.pump();
    }
    expect(find.text('Play again'), findsOneWidget);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    final (double energy, double dash, int lives, int bonus, int meteors) =
        state.debugSpaceDodgeState;
    expect((energy, dash, lives, bonus, meteors), (0.0, 0.0, 3, 0, 0));
    await gesture.moveBy(const Offset(-80, 0),
        timeStamp: const Duration(milliseconds: 60));
    await tester.pump();
    final painter = tester.widget<CustomPaint>(find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_SpacePainter'));
    final dynamic spacePainter = painter.painter;
    expect(spacePainter.shipX, 0.5);
    await gesture.cancel();
    state.debugSpaceDodgeSetup(energy: 1.0);
    final next = await tester.createGesture();
    await next.down(start, timeStamp: const Duration(seconds: 1));
    await next.moveBy(const Offset(100, 0),
        timeStamp: const Duration(milliseconds: 1040));
    expect(
        (state.debugSpaceDodgeState as (double, double, int, int, int)).$1, 0);
    await next.up();
  });
}
