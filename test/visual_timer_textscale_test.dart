import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harshivos/features/timer/visual_timer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('visual timer header at 2.5x text scale has no overflow',
      (tester) async {
    // A narrow phone width is the worst case for the header's unflexed
    // "Timer" title (fontSize 30) next to the back IconButton.
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      builder: _applyLargeTextScale,
      home: VisualTimerScreen(),
    ));
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
