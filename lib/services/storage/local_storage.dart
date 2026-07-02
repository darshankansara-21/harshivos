import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin, typed wrapper over [SharedPreferences] for offline-first persistence.
///
/// Everything HARSHIVOS records (regulation log, sensory profile, toy usage,
/// communication history) lives here first; cloud sync is an optional mirror.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  // ---- Raw JSON helpers ----------------------------------------------------

  Map<String, dynamic> readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  List<dynamic> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <dynamic>[];
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return <dynamic>[];
    }
  }

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  int readInt(String key, {int fallback = 0}) =>
      _prefs.getInt(key) ?? fallback;

  Future<void> writeInt(String key, int value) => _prefs.setInt(key, value);

  String readString(String key, {String fallback = ''}) =>
      _prefs.getString(key) ?? fallback;

  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  bool readBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  Future<void> writeBool(String key, bool value) =>
      _prefs.setBool(key, value);
}
