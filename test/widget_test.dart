// Smoke test for HARSHIVOS.
//
// Verifies the app boots and renders the home toybox with its destinations.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/app.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  testWidgets('Home screen shows the toybox destinations', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorage(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
        ],
        child: const HarshivApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Calm Me'), findsOneWidget);
    expect(find.text('Play & Explore'), findsOneWidget);
    expect(find.text('Parent Copilot'), findsOneWidget);
  });
}
