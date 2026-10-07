import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/lifeskills/avatar_studio_screen.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  testWidgets('avatar studio glasses toggle row at 2.5x text scale has no overflow',
      (tester) async {
    // A narrow phone width is the worst case for the "Extras" toggle row's
    // fixed-width switch + unflexed label Text.
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[localStorageProvider.overrideWithValue(storage)],
      child: const MaterialApp(
        builder: _applyLargeTextScale,
        home: AvatarStudioScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
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
