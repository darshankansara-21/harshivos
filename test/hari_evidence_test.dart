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
import 'package:harshivos/features/lifeskills/data/routine_library.dart';
import 'package:harshivos/features/lifeskills/routine_player_screen.dart';
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

Future<void> _captureMatrix(
  WidgetTester tester, {
  required String title,
  required List<Widget> tiles,
  required String path,
}) async {
  final key = await _sheet(tester, title, tiles, size: const Size(720, 900));
  expect(tester.takeException(), isNull);
  await _grab(tester, key, path);
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
    final key = await _sheet(tester, 'HARI — polish validation', <Widget>[
      _tile('Standing', const Hari()),
      _tile('Waving', const Hari(emotion: HariEmotion.happy, pose: HariPose.wave)),
      _tile('Walking', const Hari(emotion: HariEmotion.happy, pose: HariPose.walk)),
      _tile('Sitting', const Hari(emotion: HariEmotion.calm, pose: HariPose.sit)),
      _tile('Excited', const Hari(emotion: HariEmotion.excited)),
      _tile('Calm', const Hari(emotion: HariEmotion.calm)),
      _tile('Sad', const Hari(emotion: HariEmotion.sad)),
      _tile('Worried', const Hari(emotion: HariEmotion.worried)),
      _tile('Frustrated', const Hari(emotion: HariEmotion.frustrated)),
      _tile('Proud', const Hari(emotion: HariEmotion.proud)),
      _tile('Breathing',
          const Hari(emotion: HariEmotion.calm, pose: HariPose.breathe)),
      _tile('Brushing',
          const Hari(emotion: HariEmotion.happy, pose: HariPose.brush)),
      _tile('Sleeping',
          const Hari(emotion: HariEmotion.sleepy, pose: HariPose.sleep)),
      _tile('BAHA',
          const Hari(emotion: HariEmotion.happy, device: HearingDevice.baha)),
      _tile('Harshiv', Hari(config: AvatarConfig.harshiv)),
    ], size: const Size(660, 760));
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

  testWidgets('Hari scale range and meal routine stay unobscured', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 420));
    final scaleKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: scaleKey,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Color(0xFF0B1026),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(width: 100, height: 100, child: Hari(animate: false)),
              SizedBox(width: 200, height: 200, child: Hari(animate: false)),
              SizedBox(width: 320, height: 320, child: Hari(animate: false)),
            ],
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    await _grab(tester, scaleKey, 'evidence/hari/04_scale_range.png');

    final meal = RoutineLibrary.routineById('meal')!;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final mealKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: mealKey,
      child: ProviderScope(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(
            LocalStorage(await SharedPreferences.getInstance()),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RoutinePlayerScreen(routine: meal),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull,
        reason: 'meal cover must reserve space above its fixed CTA');
    await _grab(tester, mealKey, 'evidence/hari/05_meal_cover.png');

    await tester.tap(find.text("Let's Go!"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull,
        reason: 'meal step must not overlap its fixed action row');
    await _grab(tester, mealKey, 'evidence/hari/06_meal_step.png');
  });

  testWidgets('every Hari expression, pose, and device renders', (tester) async {
    await _captureMatrix(
      tester,
      title: 'HARI - all emotions',
      path: 'evidence/hari/07_all_emotions.png',
      tiles: AvatarEmotion.values
          .map((emotion) => _tile(
                emotion.name,
                Hari(emotion: emotion, animate: false),
              ))
          .toList(),
    );

    await _captureMatrix(
      tester,
      title: 'HARI - all poses',
      path: 'evidence/hari/08_all_poses.png',
      tiles: AvatarPose.values
          .map((pose) => _tile(
                pose.name,
                Hari(pose: pose, animate: false),
              ))
          .toList(),
    );

    await _captureMatrix(
      tester,
      title: 'HARI - personalisation and devices',
      path: 'evidence/hari/09_devices.png',
      tiles: <Widget>[
        ...HearingDevice.values.expand(
          (device) => HearingSide.values.map(
            (side) => _tile(
              '${device.name} ${side.name}',
              Hari(
                device: device,
                hearingSide: side,
                animate: false,
              ),
            ),
          ),
        ),
        _tile(
          'glasses',
          Hari(config: AvatarConfig.hari.copyWith(glasses: true), animate: false),
        ),
        _tile('Harshiv BAHA', Hari(config: AvatarConfig.harshiv, animate: false)),
      ],
    );
  });
}
