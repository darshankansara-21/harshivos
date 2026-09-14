// Smoke test for WonderPlay.
//
// Verifies the app boots and renders the WonderPlay home with destinations.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/app.dart';
import 'package:harshivos/features/calm/calm_me_screen.dart';
import 'package:harshivos/features/learn/learn_screen.dart';
import 'package:harshivos/features/lifeskills/profile_wizard_screen.dart';
import 'package:harshivos/features/talk/talk_screen.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  testWidgets('First launch shows quick setup', (tester) async {
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

    expect(find.byType(ProfileWizardScreen), findsOneWidget);
    expect(find.textContaining("What's your"), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Returning child sees the toybox destinations', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'profile_complete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorage(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
          profileCompleteProvider.overrideWith((ref) => true),
        ],
        child: const HarshivApp(),
      ),
    );
    await tester.pump();

    expect(find.text('WONDERPLAY'), findsOneWidget);
    expect(find.textContaining('Play. Learn. Calm. Connect.'), findsOneWidget);
    expect(find.textContaining('Most Loved'), findsOneWidget);
    expect(find.byTooltip('My avatar'), findsOneWidget);
  });

  testWidgets('Five core destinations are one tap from home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'profile_complete': true,
    });
    final storage = LocalStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
          profileCompleteProvider.overrideWith((ref) => true),
        ],
        child: const HarshivApp(),
      ),
    );
    await tester.pump();

    for (final label in <String>['Play', 'Calm', 'Talk', 'Routines', 'Learn']) {
      expect(find.text(label), findsOneWidget, reason: '$label door missing');
    }

    // The Talk door must actually open the communication board.
    await tester.tap(find.text('Talk'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Help Me Talk'), findsOneWidget);
  });

  testWidgets('Smoke journey: avatar + core destinations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'profile_complete': true,
    });
    final storage = LocalStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
          profileCompleteProvider.overrideWith((ref) => true),
        ],
        child: const HarshivApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Avatar editor round-trip should open and return without regressions.
    await tester.tap(find.byTooltip('My avatar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(ProfileWizardScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('WONDERPLAY'), findsOneWidget);

    await tester.tap(find.text('🌊').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(CalmMeScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('🎓').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(LearnScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('💬').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(TalkScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.scrollUntilVisible(
      find.text('All Toys'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('All Toys'), findsOneWidget);
  });
}
