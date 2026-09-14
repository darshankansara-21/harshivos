import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/snack_studio.dart';

void main() {
  testWidgets('builds, serves, and feeds a snack', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SnackStudioToy())));

    expect(find.text('Pick a snack base'), findsOneWidget);
    await tester.tap(find.text('Bread'));
    await tester.pump();
    expect(find.text('Add a topping'), findsOneWidget);

    await tester.tap(find.text('Berry'));
    await tester.pump();
    expect(find.text('Add more or serve it'), findsOneWidget);

    await tester.tap(find.text('Serve snack'));
    await tester.pump();
    expect(find.text('Ready for Hari and Pico!'), findsOneWidget);

    await tester.tap(find.text('Feed Hari and Pico'));
    await tester.pump();
    expect(find.text('Served 1'), findsOneWidget);
    expect(find.text('Pick a snack base'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
