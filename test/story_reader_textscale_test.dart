import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harshivos/features/stories/story_reader_screen.dart';
import 'package:harshivos/models/social_story.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

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
    await tester.pumpWidget(MaterialApp(
      builder: _applyLargeTextScale,
      home: StoryReaderScreen(story: story),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Advance to the last page, where the button label switches to
    // "Practice" (longer text, worst case for the Row).
    await tester.drag(find.byType(PageView), const Offset(-2000, 0));
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
