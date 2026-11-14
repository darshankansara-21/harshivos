import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpBasketball(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BasketballGame())));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump(const Duration(milliseconds: 16));
}

Finder basketballPaint() => find.byWidgetPredicate((widget) =>
    widget is CustomPaint && widget.painter.runtimeType.toString() == '_BasketPainter');

Future<void> advance(WidgetTester tester, int steps) async {
  for (var step = 0; step < steps; step++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('a green stationary estimate can hit the board and miss', (tester) async {
    expect(
      basketballReleaseGrade(launchVelocity: const Offset(0, -2), hoopX: 0.5),
      BasketballReleaseGrade.green,
    );
    await pumpBasketball(tester);
    final rect = tester.getRect(basketballPaint());
    final ball = Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.82);
    final gesture = await tester.startGesture(ball);
    await gesture.moveBy(Offset(0, -rect.height * 0.5));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Aim preview only: hoop can move and shots can bounce.'), findsOneWidget);
    await gesture.up();
    for (var step = 0; step < 75; step++) {
      await tester.pump(const Duration(milliseconds: 40));
      if (find.text('Missed! Try another shot.').evaluate().isNotEmpty) break;
    }
    expect(find.text('Missed! Try another shot.'), findsOneWidget);
    expect(find.textContaining('0 / 12'), findsOneWidget);
    expect(find.textContaining('PERFECT RELEASE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accessible shot remains available with a preliminary warning', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBasketball(tester);
    final node = tester.getSemantics(find.bySemanticsLabel(
      RegExp('Tap to shoot toward the hoop. Aim preview only'),
    ));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.tap);
    await advance(tester, 5);
    final dynamic painter = tester.widget<CustomPaint>(basketballPaint()).painter;
    expect(painter.by as double, lessThan(0.82));
    expect(find.textContaining('shots 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}