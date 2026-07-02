import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A provider-agnostic cloud-sync contract for the Life Skills data
/// (progress, avatar, custom routines).
///
/// The app is offline-first: everything is always written to local storage
/// first. [CloudSync] is a *best-effort mirror* on top of that. The default
/// [LocalOnlyCloudSync] is a no-op, so the app works with zero cloud setup.
///
/// To enable Firebase later, add `cloud_firestore` + `firebase_auth`, implement
/// `FirestoreCloudSync` against this same interface, and override
/// [cloudSyncProvider] in `main.dart`. No feature code needs to change.
abstract class CloudSync {
  /// A stable identifier for the current child/profile (e.g. Firebase uid).
  String? get profileId;

  /// Whether a real backend is connected. When false, all pushes are dropped.
  bool get isConnected;

  /// Mirror a bag of JSON under [collection] for the current profile.
  Future<void> push(String collection, Map<String, dynamic> data);

  /// Fetch the last-known cloud copy of [collection], or null if unavailable.
  Future<Map<String, dynamic>?> pull(String collection);
}

/// Default implementation: local-only, does nothing. Safe everywhere.
class LocalOnlyCloudSync implements CloudSync {
  const LocalOnlyCloudSync();

  @override
  String? get profileId => null;

  @override
  bool get isConnected => false;

  @override
  Future<void> push(String collection, Map<String, dynamic> data) async {
    // No-op: data already lives in local storage. Firebase impl will upload.
  }

  @override
  Future<Map<String, dynamic>?> pull(String collection) async => null;
}

/// Override this in `main.dart` with a real backend when Firebase is wired.
final cloudSyncProvider = Provider<CloudSync>(
  (ref) => const LocalOnlyCloudSync(),
);
