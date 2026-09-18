import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:harshivos/features/play/toys/goal_games.dart';
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
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Brick Break'), findsOneWidget);
    await tester.dragFrom(const Offset(300, 1900), const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Space Dodge builds and steers', (tester) async {
    await _pump(tester, const SpaceDodgeGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Space Dodge'), findsOneWidget);
    await tester.dragFrom(const Offset(400, 1900), const Offset(180, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Memory Flip builds and flips cards', (tester) async {
    await _pump(tester, const MemoryFlipGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Memory Flip'), findsOneWidget);
    await tester.tapAt(const Offset(300, 1000));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(540, 1000));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick Tap builds and reacts to taps', (tester) async {
    await _pump(tester, const QuickTapGame());
    expect(find.textContaining('Quick Tap'), findsOneWidget);
    await tester.tapAt(const Offset(400, 900));
    await tester.pump(const Duration(seconds: 4));
    await tester.tapAt(const Offset(400, 900));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ball Sort builds and accepts taps', (tester) async {
    await _pump(tester, const BallSortGame());
    expect(find.textContaining('Ball Sort'), findsOneWidget);
    await tester.tapAt(const Offset(200, 1000));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(500, 1000));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tap Order builds and accepts taps', (tester) async {
    await _pump(tester, const TapOrderGame());
    expect(find.textContaining('Tap Order'), findsOneWidget);
    await tester.tapAt(const Offset(300, 1000));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Piano Tiles builds and accepts taps', (tester) async {
    await _pump(tester, const PianoTilesGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Piano Tiles'), findsOneWidget);
    await tester.tapAt(const Offset(300, 1200));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Block Blast builds and places pieces', (tester) async {
    await _pump(tester, const BlockBlastGame());
    expect(find.textContaining('Block Blast'), findsOneWidget);
    await tester.tapAt(const Offset(200, 1900));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(300, 700));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bubble Shooter builds and fires', (tester) async {
    await _pump(tester, const BubbleShooterGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Bubble Shooter'), findsOneWidget);
    await tester.tapAt(const Offset(400, 900));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Color Quest states its target and accepts a choice', (tester) async {
    await _pump(tester, const ColorQuestGame());
    expect(find.textContaining('8 correct answers wins'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('color_quest-option-0')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shape Scout states its target and accepts a choice', (tester) async {
    await _pump(tester, const ShapeScoutGame());
    expect(find.textContaining('8 matches wins'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shape_scout-option-0')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Number Splash states its target and accepts a choice', (tester) async {
    await _pump(tester, const NumberSplashGame());
    expect(find.textContaining('8 correct answers wins'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('number_splash-option-0')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Path Finder exposes and advances its glowing first step', (tester) async {
    await _pump(tester, const PathFinderGame());
    expect(find.textContaining('Follow the glowing path'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('path-cell-20')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('1 / 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Goal Keeper exposes its win target and blocks a shot', (tester) async {
    await _pump(tester, const GoalKeeperGame());
    expect(find.textContaining('Make 10 saves'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-lane-1')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('1 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
