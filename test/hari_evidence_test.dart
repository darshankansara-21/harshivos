// Visual evidence harness for the Hari + Pico character system.
//
// Renders the REAL procedural character in every requested emotion/pose, the
// Pico companion, and the reusable cards to PNG sheets under `evidence/hari/`
// using RenderRepaintBoundary.toImage. Run:
//   flutter test test/hari_evidence_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/lifeskills/avatar/avatar.dart';
import 'package:harshivos/features/lifeskills/avatar/hari_cards.dart';
import 'package:harshivos/features/lifeskills/avatar/pico.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

Future<void> _grab(WidgetTester tester, GlobalKey key, String path) async {
  await tester.pump(const Duration(milliseconds: 120));
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

Widget _tile(String label, Widget child) => Container(
      width: 150,
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.1,
          colors: <Color>[Color(0xFF2A2350), Color(0xFF12102A)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(width: 130, height: 130, child: child),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );

Future<GlobalKey> _sheet(
    WidgetTester tester, String title, List<Widget> tiles,
    {Size size = const Size(680, 720)}) async {
  await tester.binding.setSurfaceSize(size);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(
          LocalStorage(await SharedPreferences.getInstance()),
        ),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFF0B1026),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Expanded(
                child: Wrap(alignment: WrapAlignment.center, children: tiles),
              ),
            ],
          ),
        ),
      ),
    ),
  ));
  return key;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'), (call) async => 1);
  });

  testWidgets('Hari emotions sheet', (tester) async {
    final key = await _sheet(tester, 'HARI — validation set', <Widget>[
      _tile('Default Hari', const Hari()),
      _tile('Harshiv preset', Hari(config: AvatarConfig.harshiv)),
      _tile('BAHA left',
          const Hari(device: HearingDevice.baha, hearingSide: HearingSide.left)),
      _tile('BAHA right',
          const Hari(device: HearingDevice.baha, hearingSide: HearingSide.right)),
      _tile('Happy', const Hari(emotion: HariEmotion.happy)),
      _tile('Excited', const Hari(emotion: HariEmotion.excited)),
      _tile('Calm', const Hari(emotion: HariEmotion.calm)),
      _tile('Sad', const Hari(emotion: HariEmotion.sad)),
      _tile('Worried', const Hari(emotion: HariEmotion.worried)),
      _tile('Frustrated', const Hari(emotion: HariEmotion.frustrated)),
      _tile('Proud', const Hari(emotion: HariEmotion.proud)),
      _tile('Thinking', const Hari(emotion: HariEmotion.thinking)),
      _tile('Sleeping',
          const Hari(emotion: HariEmotion.sleepy, pose: HariPose.sleep)),
      _tile('Brushing',
          const Hari(emotion: HariEmotion.happy, pose: HariPose.brush)),
      _tile('School',
          const Hari(emotion: HariEmotion.happy, pose: HariPose.school)),
      _tile('Calming down',
          const Hari(emotion: HariEmotion.calm, pose: HariPose.breathe)),
    ], size: const Size(660, 780));
    await _grab(tester, key, 'evidence/hari/01_emotions.png');
  });

  testWidgets('Hari poses + devices sheet', (tester) async {
    final key = await _sheet(tester, 'HARI — poses & Pico', <Widget>[
      _tile('Waving', const Hari(emotion: HariEmotion.happy, pose: HariPose.wave)),
      _tile('Breathing',
          const Hari(emotion: HariEmotion.calm, pose: HariPose.breathe)),
      _tile('Brush teeth',
          const Hari(emotion: HariEmotion.happy, pose: HariPose.brush)),
      _tile('Bedtime',
          const Hari(emotion: HariEmotion.sleepy, pose: HariPose.sleep)),
      _tile('Jump',
          const Hari(emotion: HariEmotion.excited, pose: HariPose.jump)),
      _tile('Ask for help',
          const Hari(emotion: HariEmotion.worried, pose: HariPose.help)),
      _tile('BAHA device',
          const Hari(emotion: HariEmotion.happy, device: HearingDevice.baha)),
      _tile('Cochlear',
          const Hari(emotion: HariEmotion.happy, device: HearingDevice.cochlear)),
      _tile('Pico', const PicoWidget()),
      _tile('Pico calm', const PicoWidget(mood: PicoMood.comforting)),
    ], size: const Size(680, 680));
    await _grab(tester, key, 'evidence/hari/02_poses_pico.png');
  });

  testWidgets('Hari + Pico together and cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 560));
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(
            LocalStorage(await SharedPreferences.getInstance()),
          ),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            color: const Color(0xFF0B1026),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      const Text('Hari + Pico',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SizedBox(
                        height: 200,
                        child: Row(
                          children: const <Widget>[
                            Expanded(
                              child: Hari(
                                  emotion: HariEmotion.excited,
                                  pose: HariPose.wave),
                            ),
                            Expanded(
                              child: PicoWidget(mood: PicoMood.celebrating),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                    width: 190,
                    child: HariEmotionCard(feeling: kHariFeelings[11])),
                const SizedBox(width: 12),
                SizedBox(
                    width: 200,
                    child:
                        CalmingStrategyCard(strategy: kCalmingStrategies[0])),
              ],
            ),
          ),
        ),
      ),
    ));
    await _grab(tester, key, 'evidence/hari/03_together_cards.png');
  });
}
