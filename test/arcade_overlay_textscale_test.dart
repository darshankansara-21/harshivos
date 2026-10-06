// Dedicated probe for the batch-374 `_overlayScroll` fix (arcade_games.dart):
// confirms the win/lose OVERLAY content itself (not just the ready/start
// screen) renders without a RenderFlex overflow at `TextScaler.linear(2.5)`
// on a small device surface — the exact failure mode the fix targeted.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/arcade_games.dart';
import 'package:shared_preferences/shared_preferences.dart';

// batch-380: generalizes the batch-379 probe to the other arcade games that
// share `BiggerNumberGame`'s pre-fix shape — a gameplay-state `Column` using
// `Spacer`s around a scaled `Text`/option list, found via a catalog-wide
// `grep 'Spacer('` sweep of arcade/*.dart.
Future<void> _tapPlayThenCheckNoOverflow(
    WidgetTester tester, Widget game) async {
  await _pumpSmallLargeText(tester, game);
  final Finder playButton = find.widgetWithText(FilledButton, 'Play');
  await _tapScrolledIntoView(tester, playButton);
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull,
      reason:
          'gameplay-state layout must not overflow at 2.5x text scale once started');
}

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

  testWidgets('AddItUp gameplay layout renders without overflow at 2.5x text scale',
      (tester) async {
    await _tapPlayThenCheckNoOverflow(tester, const AddItUpGame());
  });

  testWidgets('CalmChoices gameplay layout renders without overflow at 2.5x text scale',
      (tester) async {
    await _tapPlayThenCheckNoOverflow(tester, const CalmChoicesGame());
  });

  testWidgets('FeelingsMatch gameplay layout renders without overflow at 2.5x text scale',
      (tester) async {
    await _tapPlayThenCheckNoOverflow(tester, const FeelingsMatchGame());
  });

  testWidgets('KindnessMatch gameplay layout renders without overflow at 2.5x text scale',
      (tester) async {
    await _tapPlayThenCheckNoOverflow(tester, const KindnessMatchGame());
  });

  // batch-381: the `Spacer`/Column-overflow lens is exhausted, but it
  // revealed a sibling bug class — fixed-size `Container`s wrapping a
  // fixed-fontSize `Text` (no `FittedBox`) silently bleed their glyph past
  // the box at large text scale instead of throwing a RenderFlex exception,
  // so it never surfaced via `tester.takeException()`. Detect it instead by
  // comparing the glyph's natural (unconstrained) size against the fixed
  // box: if the glyph would need more room than the box offers, the box
  // MUST shrink it via FittedBox rather than silently letting it overflow.
  testWidgets(
      'WeatherSort item/bin emoji do not overflow their fixed circles at 2.5x text scale',
      (tester) async {
    await _pumpSmallLargeText(tester, const WeatherSortGame());
    await _tapScrolledIntoView(
        tester, find.widgetWithText(FilledButton, 'Play'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Rebuild the SAME emoji text, unconstrained, to learn how big it
    // actually wants to be at this text scale.
    double naturalSize(String text, double fontSize) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(2.5),
      )..layout();
      return painter.size.width > painter.size.height
          ? painter.size.width
          : painter.size.height;
    }

    for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
      final String? data = t.data;
      final double? fontSize = t.style?.fontSize;
      if (data == null || fontSize == null || fontSize < 40) continue;
      // Any Text this large (the item/bin emoji) must now be hosted inside
      // a FittedBox so it can shrink instead of bleeding past its circle.
      final Finder textFinder = find.text(data);
      final Finder fittedAncestor = find.ancestor(
          of: textFinder, matching: find.byType(FittedBox));
      expect(fittedAncestor, findsWidgets,
          reason:
              'large emoji "$data" (natural size ${naturalSize(data, fontSize)}) '
              'must be wrapped in FittedBox to avoid bleeding past its fixed circle');
    }
  });
}
