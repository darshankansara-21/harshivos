import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/companion/companion.dart';

void main() {
  testWidgets('bubble reactions escalate only at meaningful milestones',
      (tester) async {
    final controller = CompanionController();

    controller.reactToEvent(ExperienceEvent.bubblePopped);
    expect(controller.eventCount(ExperienceEvent.bubblePopped), 1);
    expect(controller.reaction, CompanionReaction.curious);
    expect(controller.pulse, 0);

    for (var count = 2; count <= 5; count++) {
      controller.reactToEvent(ExperienceEvent.bubblePopped);
    }
    await tester.pump();
    expect(controller.eventCount(ExperienceEvent.bubblePopped), 5);
    expect(controller.reaction, CompanionReaction.proud);

    for (var count = 6; count <= 10; count++) {
      controller.reactToEvent(ExperienceEvent.bubblePopped);
    }
    await tester.pump();
    expect(controller.reaction, CompanionReaction.curious);
    await tester.pump(const Duration(milliseconds: 180));
    expect(controller.reaction, CompanionReaction.pair);

    for (var count = 11; count <= 25; count++) {
      controller.reactToEvent(ExperienceEvent.bubblePopped);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(controller.reaction, CompanionReaction.dance);

    for (var count = 26; count <= 50; count++) {
      controller.reactToEvent(ExperienceEvent.bubblePopped);
    }
    await tester.pump();
    expect(controller.reaction, CompanionReaction.excited);
    await tester.pump(const Duration(milliseconds: 260));
    expect(controller.reaction, CompanionReaction.celebrating);
    controller.dispose();
  });

  testWidgets('rapid ordinary taps are deduplicated and do not bounce',
      (tester) async {
    final controller = CompanionController();

    controller.tap();
    final firstPulse = controller.pulse;
    for (var tap = 0; tap < 20; tap++) {
      controller.tap();
    }

    expect(firstPulse, 0);
    expect(controller.pulse, firstPulse);
    expect(controller.reaction, CompanionReaction.curious);
    controller.dispose();
  });

  test('high-frequency sand and music toy events stay subtle', () {
    final controller = CompanionController();

    for (var index = 0; index < 7; index++) {
      controller.reactToEvent(ExperienceEvent.sandDrawn, toyId: 'sand_garden');
      controller.reactToEvent(ExperienceEvent.musicStarted, toyId: 'music_garden');
    }
    expect(controller.pulse, 0);
    expect(controller.eventCount(ExperienceEvent.sandDrawn), 7);
    expect(controller.eventCount(ExperienceEvent.musicStarted), 7);

    controller.reactToEvent(ExperienceEvent.musicStarted, toyId: 'music_garden');
    expect(controller.reaction, CompanionReaction.curious);
    expect(controller.eventCount(ExperienceEvent.musicStarted), 8);

    controller.dispose();
  });
}