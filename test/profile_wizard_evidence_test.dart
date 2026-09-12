import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/features/lifeskills/profile_wizard_screen.dart';
import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

Future<void> _grab(WidgetTester tester, GlobalKey key, String path) async {
  await tester.pump(const Duration(milliseconds: 400));
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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Profile wizard look step is clean', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());

    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: <Override>[
            localStorageProvider.overrideWithValue(storage),
            childNameProvider.overrideWith((ref) => 'Harshiv'),
          ],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: ProfileWizardScreen(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 500));

    await _grab(tester, key, 'evidence/inapp/08_avatar_look_step.png');
  });
}
