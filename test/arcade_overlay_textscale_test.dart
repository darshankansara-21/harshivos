// Dedicated probe for the batch-374 `_overlayScroll` fix (arcade_games.dart):
// confirms the win/lose OVERLAY content itself (not just the ready/start
// screen) renders without a RenderFlex overflow at `TextScaler.linear(2.5)`
// on a small device surface — the exact failure mode the fix targeted.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSmallLargeText(WidgetTester tester, Widget game) async {
  // A small phone surface (logical 320x568, iPhone-SE class) is what
  // originally produced the 1175px overflow; combine it with an aggressive
  // 2.5x accessibility text scale.
  tester.view.physicalSize = const Size(640, 1136);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
      child: MaterialApp(home: Scaffold(body: game)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 200));
}

// The whole point of `_overlayScroll` is that this overlay content can be
// TALLER than the viewport at 2.5x text scale, so the button a test wants to
// tap may be scrolled off-screen rather than overflowing — scroll it into
// view first instead of tapping blind.
Future<void> _tapScrolledIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200.0, scrollable: find.byType(Scrollable).first);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(finder);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'Bigger Number LOSE overlay renders without overflow at 2.5x text scale',
      (tester) async {
    await _pumpSmallLargeText(tester, const BiggerNumberGame());
    await _tapScrolledIntoView(
        tester, find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull,
        reason: 'ready overlay must not overflow at 2.5x text scale');

    // Repeatedly tap the first tile: whichever round it is wrong in costs a
    // life (the round doesn't advance on a miss), so looping guarantees
    // reaching GameStatus.over within 3 misses, deterministically, without
    // depending on which number is randomly the correct answer.
    for (var i = 0; i < 12 && find.text('Play again').evaluate().isEmpty; i++) {
      await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 260));
    }

    expect(find.text('Play again'), findsOneWidget,
        reason: 'game must reach an end-of-run overlay (won or lost)');
    expect(tester.takeException(), isNull,
        reason:
            'win/lose overlay must not overflow (_overlayScroll regression)');

    // Confirm the win/lose overlay's OWN button is reachable (proves the
    // scroll view actually contains it, not merely that no exception fired).
    await _tapScrolledIntoView(tester, find.text('Play again'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
