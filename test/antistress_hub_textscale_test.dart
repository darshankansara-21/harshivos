import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harshivos/features/antistress/antistress_hub_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('antistress hub at 2.5x text scale has no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2.5)),
        child: c!,
      ),
      home: const AntistressHubScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
