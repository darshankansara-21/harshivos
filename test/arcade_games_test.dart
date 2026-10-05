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
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Sky Hop'), findsOneWidget);
    await tester.tapAt(const Offset(400, 800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stack builds and drops', (tester) async {
    await _pump(tester, const StackGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Stack'), findsOneWidget);
    await tester.tapAt(const Offset(400, 800));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Merge builds and slides', (tester) async {
    await _pump(tester, const MergeGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Merge'), findsOneWidget);
    await tester.drag(find.byType(MergeGame), const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.drag(find.byType(MergeGame), const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Echo builds and shows a sequence', (tester) async {
    await _pump(tester, const EchoGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Echo'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tapAt(const Offset(300, 900));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tic-Tac-Toe builds and plays a move', (tester) async {
    await _pump(tester, const TicTacToeGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
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
    expect(find.textContaining('0 / 180'), findsOneWidget);
    expect(find.text('Ships: 3'), findsOneWidget);
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
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Quick Tap'), findsOneWidget);
    await tester.tapAt(const Offset(400, 900));
    await tester.pump(const Duration(seconds: 4));
    await tester.tapAt(const Offset(400, 900));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pinball builds and flips', (tester) async {
    await _pump(tester, const PinballGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Pinball'), findsOneWidget);
    await tester.tapAt(const Offset(120, 900));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(680, 900));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Basketball builds and shoots', (tester) async {
    await _pump(tester, const BasketballGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Basketball'), findsOneWidget);
    await tester.drag(find.byType(BasketballGame), const Offset(10, -320));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mini Golf builds and putts', (tester) async {
    await _pump(tester, const MiniGolfGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Mini Golf'), findsOneWidget);
    await tester.drag(find.byType(MiniGolfGame), const Offset(-40, -300));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Air Hockey builds and slides', (tester) async {
    await _pump(tester, const AirHockeyGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Air Hockey'), findsOneWidget);
    await tester.drag(find.byType(AirHockeyGame), const Offset(30, -60));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Target Toss builds and tosses', (tester) async {
    await _pump(tester, const TargetTossGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Target Toss'), findsOneWidget);
    await tester.drag(find.byType(TargetTossGame), const Offset(10, -300));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bubble Wrap builds and pops', (tester) async {
    await _pump(tester, const BubbleWrapGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Bubble Wrap'), findsOneWidget);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Drum Garden builds and plays pads', (tester) async {
    await _pump(tester, const DrumGardenGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Drum Garden'), findsOneWidget);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Color Mixer builds and pours', (tester) async {
    await _pump(tester, const ColorMixerGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Color Mixer'), findsOneWidget);
    await tester.tap(find.text('Red'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Yellow'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fishing builds and casts', (tester) async {
    await _pump(tester, const FishingGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Fishing'), findsOneWidget);
    await tester.tapAt(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Maze Run builds and swipes', (tester) async {
    await _pump(tester, const MazeRunGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Maze Run'), findsOneWidget);
    await tester.fling(find.byType(MazeRunGame), const Offset(200, 0), 800);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beat Builder builds and toggles', (tester) async {
    await _pump(tester, const BeatBuilderGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Beat Builder'), findsOneWidget);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Catch the Beat builds and taps lanes', (tester) async {
    await _pump(tester, const CatchBeatGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Catch the Beat'), findsOneWidget);
    await tester.tapAt(const Offset(200, 500));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Firefly Count builds and answers', (tester) async {
    await _pump(tester, const FireflyCountGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Firefly Count'), findsOneWidget);
    await tester.tapAt(const Offset(200, 760));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sorting Train builds and loads', (tester) async {
    await _pump(tester, const SortingTrainGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Sorting Train'), findsOneWidget);
    await tester.tapAt(const Offset(200, 760));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shadow Match builds and picks', (tester) async {
    await _pump(tester, const ShadowMatchGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Shadow Match'), findsOneWidget);
    await tester.tapAt(const Offset(200, 600));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pattern Weaver builds and answers', (tester) async {
    await _pump(tester, const PatternWeaverGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Pattern Weaver'), findsOneWidget);
    await tester.tapAt(const Offset(200, 760));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Balloon Math builds and pops', (tester) async {
    await _pump(tester, const BalloonMathGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Balloon Math'), findsOneWidget);
    await tester.tapAt(const Offset(200, 450));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dot-to-Dot builds and connects', (tester) async {
    await _pump(tester, const DotToDotGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Dot-to-Dot'), findsOneWidget);
    await tester.tapAt(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rhythm Clap builds and claps', (tester) async {
    await _pump(tester, const RhythmClapGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Rhythm Clap'), findsOneWidget);
    await tester.tapAt(const Offset(200, 600));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shape Builder builds and places', (tester) async {
    await _pump(tester, const ShapeBuilderGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Shape Builder'), findsOneWidget);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Memory Pairs Deluxe builds and flips', (tester) async {
    await _pump(tester, const MemoryPairsDeluxeGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Memory Pairs Deluxe'), findsOneWidget);
    await tester.tapAt(const Offset(120, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bug Catch builds and taps', (tester) async {
    await _pump(tester, const BugCatchGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Bug Catch'), findsOneWidget);
    await tester.tapAt(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spot the Difference builds and picks', (tester) async {
    await _pump(tester, const SpotDifferenceGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Spot the Difference'), findsOneWidget);
    await tester.tapAt(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 100));
    // A tapped-wrong-tile auto-clears its flash via a 450ms timer; pump past
    // it so the timer fires and is flushed before teardown.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Weather Sort builds and sorts', (tester) async {
    await _pump(tester, const WeatherSortGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Weather Sort'), findsOneWidget);
    await tester.tap(find.text('☀️'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Maze Marble builds and drags', (tester) async {
    await _pump(tester, const MazeMarbleGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Maze Marble'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Piano Song builds and plays a key', (tester) async {
    await _pump(tester, const PianoSongGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Piano Song'), findsOneWidget);
    await tester.tap(find.text('C'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Letter Trace builds and traces', (tester) async {
    await _pump(tester, const LetterTraceGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Letter Trace'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(40, 60));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Soccer Kick builds and shoots', (tester) async {
    await _pump(tester, const SoccerKickGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Soccer Kick'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(30, 120));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Xylophone Tap builds and plays', (tester) async {
    await _pump(tester, const XylophoneTapGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Xylophone Tap'), findsOneWidget);
    await tester.tapAt(const Offset(300, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Jigsaw Four builds and drags', (tester) async {
    await _pump(tester, const JigsawFourGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Jigsaw Four'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(40, -80));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Counting Baskets builds and drags', (tester) async {
    await _pump(tester, const CountingBasketsGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Counting Baskets'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(0, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Star Path builds and connects', (tester) async {
    await _pump(tester, const StarPathGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Star Path'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(60, 80));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Feelings Match builds and picks', (tester) async {
    await _pump(tester, const FeelingsMatchGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Feelings Match'), findsOneWidget);
    await tester.tapAt(const Offset(200, 700));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Penalty Dash builds and shoots', (tester) async {
    await _pump(tester, const PenaltyDashGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Penalty Dash'), findsOneWidget);
    await tester.tapAt(const Offset(300, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Penalty Dash ignores rapid double taps for one opening', (tester) async {
    await _pump(tester, const PenaltyDashGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    await tester.tapAt(const Offset(300, 400));
    await tester.pump();
    expect(find.textContaining('1 / 10'), findsOneWidget);

    await tester.tapAt(const Offset(300, 400));
    await tester.pump();
    expect(find.textContaining('1 / 10'), findsOneWidget);
    expect(find.textContaining('2 / 10'), findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shape Sort Chute builds and drags', (tester) async {
    await _pump(tester, const ShapeSortChuteGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Shape Sort Chute'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Balloon Bounce builds and taps', (tester) async {
    await _pump(tester, const BalloonBounceGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Balloon Bounce'), findsOneWidget);
    await tester.tapAt(const Offset(300, 500));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Count & Pop builds and pops', (tester) async {
    await _pump(tester, const CountPopGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Count & Pop'), findsOneWidget);
    await tester.tapAt(const Offset(300, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mirror Draw builds and traces', (tester) async {
    await _pump(tester, const MirrorDrawGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Mirror Draw'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(-60, 40));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calm Breaths builds and breathes', (tester) async {
    await _pump(tester, const CalmBreathsGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Calm Breaths'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hoop Toss builds and tosses', (tester) async {
    await _pump(tester, const HoopTossGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Hoop Toss'), findsOneWidget);
    await tester.tapAt(const Offset(300, 500));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Echo Drums builds and taps', (tester) async {
    await _pump(tester, const EchoDrumsGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Echo Drums'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.tapAt(const Offset(150, 400));
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Slide Puzzle builds and slides', (tester) async {
    await _pump(tester, const SlidePuzzleGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Slide Puzzle'), findsOneWidget);
    await tester.tapAt(const Offset(300, 500));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add It Up builds and taps', (tester) async {
    await _pump(tester, const AddItUpGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Add It Up'), findsOneWidget);
    await tester.tapAt(const Offset(150, 600));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Steady Hand builds and drags', (tester) async {
    await _pump(tester, const SteadyHandGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Steady Hand'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(40, -40));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kindness Match builds and picks', (tester) async {
    await _pump(tester, const KindnessMatchGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Kindness Match'), findsOneWidget);
    await tester.tapAt(const Offset(200, 650));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skee Ball builds and rolls', (tester) async {
    await _pump(tester, const SkeeBallGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Skee Ball'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tone Match builds and taps', (tester) async {
    await _pump(tester, const ToneMatchGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Tone Match'), findsOneWidget);
    await tester.tapAt(const Offset(120, 400));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Odd One Out builds and taps', (tester) async {
    await _pump(tester, const OddOneOutGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Odd One Out'), findsOneWidget);
    await tester.tapAt(const Offset(200, 500));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bigger Number builds and taps', (tester) async {
    await _pump(tester, const BiggerNumberGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Bigger Number'), findsOneWidget);
    await tester.tapAt(const Offset(200, 600));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Balance Ball builds and drags', (tester) async {
    await _pump(tester, const BalanceBallGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Balance Ball'), findsOneWidget);
    await tester.drag(find.byType(CustomPaint).last, const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calm Choices builds and picks', (tester) async {
    await _pump(tester, const CalmChoicesGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Calm Choices'), findsOneWidget);
    await tester.tapAt(const Offset(200, 650));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ball Sort builds and accepts taps', (tester) async {
    await _pump(tester, const BallSortGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Ball Sort'), findsOneWidget);
    await tester.tapAt(const Offset(200, 1000));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(500, 1000));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tap Order builds and accepts taps', (tester) async {
    await _pump(tester, const TapOrderGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('8 correct answers wins'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('color_quest-option-0')));
    await tester.pump(const Duration(milliseconds: 100));
    // The tapped option is randomly the wrong one depending on round setup,
    // in which case it auto-clears its red flash via a 450ms timer; pump
    // past it so the timer always fires and is flushed before teardown.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shape Scout states its target and accepts a choice', (tester) async {
    await _pump(tester, const ShapeScoutGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('8 matches wins'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shape_scout-option-0')));
    await tester.pump(const Duration(milliseconds: 100));
    // A wrong choice auto-clears its red flash via a 450ms timer; pump past
    // it so the timer fires and is flushed before teardown.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Number Splash states its target and accepts a choice', (tester) async {
    await _pump(tester, const NumberSplashGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('8 correct answers wins'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('number_splash-option-0')));
    await tester.pump(const Duration(milliseconds: 100));
    // A wrong choice auto-clears its red flash via a 450ms timer; pump past
    // it so the timer fires and is flushed before teardown.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Path Finder exposes and advances its glowing first step', (tester) async {
    await _pump(tester, const PathFinderGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Follow the glowing path'), findsOneWidget);
    // The maze path is randomised every game, so find the flag (the start
    // of today's path) rather than a hardcoded cell index.
    await tester.tap(find.text('🚩'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('1 / 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Goal Keeper reads a shot and makes the opening save', (tester) async {
    await _pump(tester, const GoalKeeperGame());
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.textContaining('Make 10 saves'), findsOneWidget);
    // The opening shot is straight down the middle and the keeper starts
    // centred, so letting it fly in is a guaranteed save. Pump in small
    // steps because the game loop skips large frame deltas.
    for (var i = 0; i < 32; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.textContaining('1 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
