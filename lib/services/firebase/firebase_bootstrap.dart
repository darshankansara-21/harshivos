import 'package:flutter/foundation.dart';

/// Optional cloud bootstrap.
///
/// HARSHIVOS is offline-first: the entire app works with zero cloud config.
/// When a Firebase project *is* configured (google-services.json /
/// GoogleService-Info.plist + generated firebase_options.dart), call-sites can
/// opt in. Until then this stays a graceful no-op so the MVP runs anywhere.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _ready = false;

  /// True once Firebase has successfully initialised.
  static bool get isReady => _ready;

  /// Attempts to initialise Firebase. Never throws — failures simply leave the
  /// app in offline-only mode.
  static Future<void> tryInitialize() async {
    try {
      // Wire this up once firebase_options.dart is generated via the FlutterFire
      // CLI. Kept commented so the project compiles without platform config:
      //
      // await Firebase.initializeApp(
      //   options: DefaultFirebaseOptions.currentPlatform,
      // );
      // _ready = true;
      _ready = false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase unavailable, running offline-only: $e');
      }
      _ready = false;
    }
  }
}
