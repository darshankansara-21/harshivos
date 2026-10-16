import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/lifeskills/avatar/avatar.dart';
import 'package:harshivos/features/lifeskills/card_deck_screen.dart';
import 'package:harshivos/features/lifeskills/create_routine_screen.dart';
import 'package:harshivos/features/lifeskills/models/life_models.dart';
import 'package:harshivos/features/lifeskills/routine_player_screen.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

/// Regression probe for a shape of bug found repeatedly across the catalog:
/// a CTA button's Row (icon + label, `mainAxisAlignment: center`, no
/// `Flexible`/`Expanded`) overflows its fixed-width button once the label is
/// scaled up at large accessibility text scales. Covers the three
/// `lifeskills` CTA buttons that had this exact shape: `RoutinePlayerScreen`'s
/// `_BigButton`, `CardDeckScreen`'s "Next"/"Done" button, and
/// `CreateRoutineScreen`'s "Save Routine" / "Generate with AI" buttons.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> ttsCalls;

  setUp(() {
    ttsCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async {
        ttsCalls.add(call);
        return 1;
      },
    );
  });

  Future<LocalStorage> storage({
    String audioLevel = 'normal',
    bool muted = false,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'audio_level': audioLevel,
      'audio_muted': muted,
    });
    return LocalStorage(await SharedPreferences.getInstance());
  }

  testWidgets(
      'RoutinePlayerScreen _BigButton CTAs at 2.5x text scale have no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const routine = LifeRoutine(
      id: 'r1',
      title: 'Morning Routine',
      subtitle: 'Get ready for the day',
      emoji: '🌞',
      gradient: <Color>[Color(0xFF4CC9F0), Color(0xFF9B5DE5)],
      steps: <RoutineStep>[
        RoutineStep(
          title: 'Brush teeth',
          instruction: 'Brush your teeth',
          emoji: '🪥',
          pose: AvatarPose.idle,
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(await storage()),
      ],
      child: MaterialApp(
        builder: _applyLargeTextScale,
        home: const RoutinePlayerScreen(routine: routine),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);

    // Advance through the cover's "Let's Go!" CTA into the step player, whose
    // own CTA ("I did it!"/arrow) is the second `_BigButton` instance.
    await tester.tap(find.text("Let's Go!"));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('CardDeckScreen next/done button at 2.5x text scale has no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const deck = LessonDeck(
      id: 'd1',
      title: 'Do and Don\'t',
      subtitle: 'Learn together',
      emoji: '🧭',
      gradient: <Color>[Color(0xFF4CC9F0), Color(0xFF9B5DE5)],
      cards: <LessonCard>[
        LessonCard(
          title: 'Say please',
          narration: 'Always say please',
          emoji: '🙏',
          kind: LessonKind.doThis,
        ),
        LessonCard(
          title: 'Shout indoors',
          narration: 'Try not to shout indoors',
          emoji: '🤫',
          kind: LessonKind.dontThis,
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(await storage()),
      ],
      child: MaterialApp(
        builder: _applyLargeTextScale,
        home: const CardDeckScreen(deck: deck),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);

    // Advance to the final card so the button label flips "Next" -> "Done".
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('card deck pages stay silent until explicit read-aloud',
      (tester) async {
    const deck = LessonDeck(
      id: 'quiet-deck',
      title: 'Quiet cards',
      subtitle: 'Visual first',
      emoji: '🧭',
      gradient: <Color>[Color(0xFF4CC9F0), Color(0xFF9B5DE5)],
      cards: <LessonCard>[
        LessonCard(
          title: 'First',
          narration: 'First narration',
          emoji: '1️⃣',
          kind: LessonKind.info,
        ),
        LessonCard(
          title: 'Second',
          narration: 'Second narration',
          emoji: '2️⃣',
          kind: LessonKind.info,
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(
          await storage(audioLevel: 'soft'),
        ),
      ],
      child: const MaterialApp(home: CardDeckScreen(deck: deck)),
    ));
    await tester.pump();
    expect(ttsCalls.where((call) => call.method == 'speak'), isEmpty);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(ttsCalls.where((call) => call.method == 'speak'), isEmpty);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(
      ttsCalls.where((call) => call.method == 'setVolume').last.arguments,
      closeTo(0.35, 0.001),
    );
    expect(ttsCalls.where((call) => call.method == 'speak').single.arguments,
        'Second narration');
  });

  testWidgets('routine narration stays silent while muted', (tester) async {
    const routine = LifeRoutine(
      id: 'quiet-routine',
      title: 'Quiet routine',
      subtitle: 'Visual steps',
      emoji: '🌞',
      gradient: <Color>[Color(0xFF4CC9F0), Color(0xFF9B5DE5)],
      steps: <RoutineStep>[
        RoutineStep(
          title: 'First step',
          instruction: 'Do the first step',
          emoji: '1️⃣',
          pose: AvatarPose.idle,
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(await storage(muted: true)),
      ],
      child: const MaterialApp(home: RoutinePlayerScreen(routine: routine)),
    ));
    await tester.pump();
    await tester.tap(find.text("Let's Go!"));
    await tester.pump();

    expect(ttsCalls.where((call) => call.method == 'speak'), isEmpty);
  });

  testWidgets(
      'CreateRoutineScreen save/generate buttons at 2.5x text scale have no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(await storage()),
      ],
      child: MaterialApp(
        builder: _applyLargeTextScale,
        home: const CreateRoutineScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));
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
