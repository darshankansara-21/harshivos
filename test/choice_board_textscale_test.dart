import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harshivos/features/choices/choice_board_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'choice board header and reveal overlay at 2.5x text scale has no overflow',
      (tester) async {
    // A narrow phone width is the worst case for the header's unflexed
    // "I Choose" title next to the back IconButton, and for the reveal
    // overlay's "Tap to go back" row.
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      builder: _applyLargeTextScale,
      home: ChoiceBoardScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Switch to the "Places" category, which has the longest word
    // ("Playground"), and reveal it — the full-screen bloom renders the
    // word at fontSize 56, the biggest unflexed text in the screen. The
    // chip row scrolls horizontally at 2.5x scale, so scroll it into view
    // first.
    await tester.ensureVisible(find.text('Places'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Places'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Playground'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Playground'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}

Widget _applyLargeTextScale(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2.5)),
    child: child!,
  );
}
