import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/stories/story_reader_screen.dart';
import 'package:harshivos/models/social_story.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

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

  Future<LocalStorage> storage({String audioLevel = 'normal'}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'audio_level': audioLevel,
    });
    return LocalStorage(await SharedPreferences.getInstance());
  }

  testWidgets(
      'story reader bottom action row at 2.5x text scale has no overflow',
      (tester) async {
    // A narrow phone width is the worst case for the bottom Row — its
    // "_Dots" indicator + Spacer + FilledButton.icon("Next"/"Practice")
    // has no Flexible wrapping the button, so it can never shrink.
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final story = SocialStory(
      title: 'Going to the Dentist',
      situation: 'Going to the dentist',
      pages: <SocialStoryPage>[
        SocialStoryPage(
            text: 'Today we are going to the dentist.',
            emoji: '🦷',
            imagePrompt: 'dentist'),
        SocialStoryPage(
            text: 'The dentist will look at my teeth.',
            emoji: '😁',
            imagePrompt: 'teeth'),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(await storage()),
      ],
      child: MaterialApp(
        builder: _applyLargeTextScale,
        home: StoryReaderScreen(story: story),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Advance to the last page, where the button label switches to
    // "Practice" (longer text, worst case for the Row).
    await tester.drag(find.byType(PageView), const Offset(-2000, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('story narration is explicit and follows the soft volume',
      (tester) async {
    final story = SocialStory(
      title: 'A quiet story',
      situation: 'Reading together',
      pages: <SocialStoryPage>[
        SocialStoryPage(
            text: 'First page.', emoji: '1️⃣', imagePrompt: 'first'),
        SocialStoryPage(
            text: 'Second page.', emoji: '2️⃣', imagePrompt: 'second'),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(
          await storage(audioLevel: 'soft'),
        ),
      ],
      child: MaterialApp(home: StoryReaderScreen(story: story)),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(ttsCalls.where((call) => call.method == 'speak'), isEmpty);
    await tester.drag(find.byType(PageView), const Offset(-1000, 0));
    await tester.pump(const Duration(milliseconds: 350));
    expect(ttsCalls.where((call) => call.method == 'speak'), isEmpty);

    await tester.tap(find.byTooltip('Read this page aloud'));
    await tester.pump();
    expect(
      ttsCalls.where((call) => call.method == 'setVolume').last.arguments,
      closeTo(0.35, 0.001),
    );
    expect(ttsCalls.where((call) => call.method == 'speak').single.arguments,
        'Second page.');

    ttsCalls.clear();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StoryReaderScreen)),
    );
    await container
        .read(sensoryPreferencesProvider.notifier)
        .setQuietMode(true);
    await tester.pump();
    expect(ttsCalls.any((call) => call.method == 'stop'), true);
  });
}

Widget _applyLargeTextScale(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2.5)),
    child: child!,
  );
}
