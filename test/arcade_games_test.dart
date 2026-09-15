import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Whack builds and accepts taps', (tester) async {
    await _pump(tester, const WhackGame());
    expect(find.textContaining('Whack'), findsOneWidget);
    await tester.tapAt(const Offset(300, 800));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sky Hop builds and flaps', (tester) async {
    await _pump(tester, const SkyHopGame());
    expect(find.textContaining('Sky Hop'), findsOneWidget);
    await tester.tapAt(const Offset(400, 800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stack builds and drops', (tester) async {
    await _pump(tester, const StackGame());
    expect(find.textContaining('Stack'), findsOneWidget);
    await tester.tapAt(const Offset(400, 800));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Merge builds and slides', (tester) async {
    await _pump(tester, const MergeGame());
    expect(find.textContaining('Merge'), findsOneWidget);
    await tester.drag(find.byType(MergeGame), const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.drag(find.byType(MergeGame), const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Echo builds and shows a sequence', (tester) async {
    await _pump(tester, const EchoGame());
    expect(find.textContaining('Echo'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tapAt(const Offset(300, 900));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tic-Tac-Toe builds and plays a move', (tester) async {
    await _pump(tester, const TicTacToeGame());
    expect(find.textContaining('Tic-Tac-Toe'), findsOneWidget);
    // Tap a few board positions; a full game resolves without exceptions.
    for (final p in <Offset>[
      const Offset(300, 1000),
      const Offset(540, 1000),
      const Offset(780, 1000),
      const Offset(300, 1240),
      const Offset(540, 1240),
    ]) {
      await tester.tapAt(p);
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Brick Break builds and runs the ball', (tester) async {
    await _pump(tester, const BrickBreakGame());
    expect(find.textContaining('Brick Break'), findsOneWidget);
    await tester.dragFrom(const Offset(300, 1900), const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Space Dodge builds and steers', (tester) async {
    await _pump(tester, const SpaceDodgeGame());
    expect(find.textContaining('Space Dodge'), findsOneWidget);
    await tester.dragFrom(const Offset(400, 1900), const Offset(180, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Memory Flip builds and flips cards', (tester) async {
    await _pump(tester, const MemoryFlipGame());
    expect(find.textContaining('Memory Flip'), findsOneWidget);
    await tester.tapAt(const Offset(300, 1000));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(540, 1000));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });
}
