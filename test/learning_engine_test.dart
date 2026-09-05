import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/learn/learn_screen.dart';
import 'package:harshivos/features/learn/learning_engine.dart';
import 'package:harshivos/models/activity_event.dart';
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

  testWidgets('Learn screen keeps both original games and adds engine games',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(home: LearnScreen()),
      ),
    );
    await tester.pump();

    // Preservation: the two bespoke games must still be present.
    expect(find.text('Emotion Match'), findsOneWidget);
    expect(find.text('Matching Pairs'), findsOneWidget);
    // Added depth from the shared engine.
    expect(find.text('Colors'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);
  });

  testWidgets('completing an engine game logs one real gamePlayed event',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());

    final container = ProviderContainer(overrides: <Override>[
      localStorageProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);

    final pack = kLearnPacks.firstWhere((p) => p.id == 'learn_colors');
    final labelToEmoji = <String, String>{
      for (final it in pack.items) it.label: it.emoji,
    };

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: LearningGameScreen(pack: pack)),
      ),
    );
    await tester.pump();

    // Play through all rounds by always tapping the correct answer.
    for (var i = 0; i < 8; i++) {
      String? target;
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        if (labelToEmoji.containsKey(t.data)) {
          target = t.data;
          break;
        }
      }
      expect(target, isNotNull, reason: 'a target word should be shown');
      await tester.tap(find.text(labelToEmoji[target]!).first);
      await tester.pump();
    }

    expect(find.text('You did it!'), findsOneWidget);

    final log = container.read(activityLogProvider);
    final games =
        log.where((e) => e.type == ActivityType.gamePlayed).toList();
    expect(games.length, 1);
    expect(games.first.target, 'learn_colors');
  });

  testWidgets('completing a sorting game logs one real gamePlayed event',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());

    final container = ProviderContainer(overrides: <Override>[
      localStorageProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);

    final pack = kSortPacks.firstWhere((p) => p.id == 'sort_animal_food');
    final emojiToCategory = <String, int>{
      for (final it in pack.items) it.emoji: it.category,
    };

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: SortingGameScreen(pack: pack)),
      ),
    );
    await tester.pump();

    for (var i = 0; i < 8; i++) {
      // The shown item is the large 96px emoji; find which one is on screen.
      String? shown;
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        if (emojiToCategory.containsKey(t.data)) {
          shown = t.data;
          break;
        }
      }
      expect(shown, isNotNull, reason: 'an item should be shown');
      final correctBin =
          emojiToCategory[shown] == 0 ? pack.categoryA : pack.categoryB;
      await tester.tap(find.text(correctBin));
      await tester.pump();
    }

    expect(find.text('You did it!'), findsOneWidget);

    final games = container
        .read(activityLogProvider)
        .where((e) => e.type == ActivityType.gamePlayed)
        .toList();
    expect(games.length, 1);
    expect(games.first.target, 'sort_animal_food');
  });
}
