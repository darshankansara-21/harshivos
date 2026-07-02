import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/firebase/firebase_bootstrap.dart';
import 'services/storage/local_storage.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tablet-first, but allow every orientation so the toybox feels native on
  // phones and tablets alike.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Offline-first storage is mandatory and always available.
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);

  // Cloud is optional. If Firebase config is missing the app keeps working.
  await FirebaseBootstrap.tryInitialize();

  runApp(
    ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(storage),
      ],
      child: const HarshivApp(),
    ),
  );
}
