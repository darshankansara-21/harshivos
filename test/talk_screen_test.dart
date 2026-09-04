import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/talk/talk_screen.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  testWidgets('essential need speaks a complete phrase', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(home: TalkScreen()),
      ),
    );

    await tester.tap(find.text('Needs'));
    await tester.pump();
    await tester.tap(find.text('Hurt'));
    await tester.pump();

    expect(find.text('I am hurt'), findsOneWidget);
    expect(find.text('Hurt'), findsWidgets);
  });

  testWidgets('spoken words surface as Recent and persist', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());

    Widget board() => ProviderScope(
          overrides: <Override>[
            localStorageProvider.overrideWithValue(storage),
          ],
          child: const MaterialApp(home: TalkScreen()),
        );

    await tester.pumpWidget(board());
    await tester.tap(find.text('Drink'));
    await tester.pump();
    await tester.tap(find.text('Water'));
    await tester.pump();

    // A Recent strip now exists with the word the child just used.
    expect(find.text('Recent'), findsOneWidget);

    // Rebuild from storage (cold restart) — Recent must still be there.
    await tester.pumpWidget(board());
    await tester.pump();
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Water'), findsWidgets);
  });
}