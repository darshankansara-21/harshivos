import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<LocalStorage> storage() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
