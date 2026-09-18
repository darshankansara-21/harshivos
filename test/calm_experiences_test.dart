import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/calm/firefly_glow.dart';
import 'package:harshivos/features/calm/gravity_garden.dart';
import 'package:harshivos/features/calm/star_weaver.dart';
import 'package:harshivos/features/calm/zen_stones.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Star Weaver builds, threads stars, and does not throw',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StarWeaverToy())));
    await tester.pump(const Duration(milliseconds: 50));

    // Sweep across the sky to try to connect drifting stars.
    for (double y = 100; y < 900; y += 40) {
      await tester.tapAt(Offset(300, y));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.dragFrom(const Offset(120, 200), const Offset(600, 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Firefly Glow builds, gathers on hold, and does not throw',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FireflyGlowToy())));
    await tester.pump(const Duration(milliseconds: 50));

    final TestGesture g = await tester.startGesture(const Offset(400, 800));
    for (int i = 0; i < 10; i++) {
      await g.moveBy(const Offset(6, -6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gravity Garden builds, nudges orbits, and does not throw',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GravityGardenToy())));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.dragFrom(const Offset(540, 1200), const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(540, 700));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Zen Stones builds, stacks, resets, and does not throw',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ZenStonesToy())));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ZenStonesToy), findsOneWidget);

    for (int i = 0; i < 5; i++) {
      await tester.tapAt(Offset(540 + (i.isEven ? 60 : -60), 1200));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.longPress(find.byType(ZenStonesToy));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
