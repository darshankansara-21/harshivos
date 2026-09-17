import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/trace_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Trace It builds, accepts tracing, and does not throw',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TraceGame())));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Trace the dots'), findsOneWidget);

    // Drag across the canvas to light up dots.
    await tester.dragFrom(const Offset(200, 800), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.dragFrom(const Offset(200, 800), const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
