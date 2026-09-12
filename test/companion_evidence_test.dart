// Rendered evidence for the Hari + Pico companion system. Captures the living
// companion in the toy player, a strip of reaction states, and Pico breathing
// inside the calm orb. Run:
//   flutter test test/companion_evidence_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:harshivos/features/antistress/antistress_player_screen.dart';
import 'package:harshivos/features/antistress/toys/bubble_wrap.dart';
import 'package:harshivos/features/calm/breathing_exercise.dart';
import 'package:harshivos/features/companion/companion.dart';

Future<void> _grab(WidgetTester tester, GlobalKey key, String path) async {
  // Wait past any reaction swap and let the authored art fully decode.
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1500)));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pump(const Duration(milliseconds: 200));
  while (tester.takeException() != null) {}
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<GlobalKey> _pump(WidgetTester tester, Widget child, Size size) async {
  await tester.binding.setSurfaceSize(size);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: child,
    ),
  ));
  // Let authored art decode.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump(const Duration(milliseconds: 300));
  while (tester.takeException() != null) {}
  return key;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'), (call) async => 1);
    final prior = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
  });

  testWidgets('Companion — living in the toy player', (tester) async {
    final key = await _pump(
        tester,
        const AntistressPlayerScreen(
          toy: BubbleWrapToy(),
          title: 'Bubble Wrap',
          emoji: '🎈',
        ),
        const Size(390, 780));
    await _grab(tester, key, 'evidence/companion/01_toy_player.png');
  });

  testWidgets('Companion — reaction states', (tester) async {
    const reactions = <CompanionReaction>[
      CompanionReaction.curious,
      CompanionReaction.excited,
      CompanionReaction.proud,
      CompanionReaction.celebrating,
      CompanionReaction.calm,
      CompanionReaction.sleepy,
    ];
    final controllers = <CompanionController>[
      for (final r in reactions) CompanionController()..setReaction(r),
    ];
    final key = await _pump(
      tester,
      Scaffold(
        backgroundColor: const Color(0xFF1B1E2B),
        body: SafeArea(
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              for (var i = 0; i < reactions.length; i++)
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: CompanionView(
                        controller: controllers[i],
                        animate: false,
                      ),
                    ),
                    Text(reactions[i].name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
            ],
          ),
        ),
      ),
      const Size(440, 520),
    );
    await _grab(tester, key, 'evidence/companion/02_reactions.png');
  });

  testWidgets('Calm — Pico breathes in the orb', (tester) async {
    final key =
        await _pump(tester, const BreathingExercise(), const Size(420, 720));
    await _grab(tester, key, 'evidence/companion/03_breathing.png');
  });

  testWidgets('Companion — animate true isolation', (tester) async {
    final c = CompanionController()..setReaction(CompanionReaction.excited);
    final key = await _pump(
      tester,
      Scaffold(
        backgroundColor: const Color(0xFF2A2E3F),
        body: Center(
          child: SizedBox(
            width: 200,
            height: 180,
            child: CompanionView(controller: c, animate: true),
          ),
        ),
      ),
      const Size(300, 300),
    );
    await _grab(tester, key, 'evidence/companion/04_animate.png');
  });
}
