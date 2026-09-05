import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_event.dart';
import '../models/regulation_entry.dart';
import '../models/sensory_profile.dart';
import '../services/ai/ai_provider.dart';
import '../services/ai/ai_service.dart';
import '../services/regulation/regulation_engine.dart';
import '../services/storage/local_storage.dart';

const _uuid = Uuid();

/// Offline-first storage. Overridden with a real instance in `main()`.
final localStorageProvider = Provider<LocalStorage>(
  (ref) => throw UnimplementedError('localStorageProvider must be overridden'),
);

/// The active AI provider (mock by default, Gemini/OpenAI when configured).
final aiServiceProvider = FutureProvider<AiService>((ref) => AiService.create());

/// Convenience accessor for the underlying [AiProvider].
final aiProvider = FutureProvider<AiProvider>(
  (ref) async => (await ref.watch(aiServiceProvider.future)).provider,
);

/// The stateless regulation analysis engine.
final regulationEngineProvider =
    Provider<RegulationEngine>((ref) => const RegulationEngine());

// ---------------------------------------------------------------------------
// Regulation log
// ---------------------------------------------------------------------------

class RegulationLogNotifier extends StateNotifier<List<RegulationEntry>> {
  RegulationLogNotifier(this._storage) : super(const <RegulationEntry>[]) {
    _load();
  }

  static const _key = 'regulation_log';
  final LocalStorage _storage;

  void _load() {
    final raw = _storage.readList(_key);
    state = raw
        .map((e) => RegulationEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _persist() async {
    await _storage.writeJson(_key, state.map((e) => e.toJson()).toList());
  }

  Future<RegulationEntry> logSession({
    required List<String> toyIds,
    CalmMood? mood,
    double? calmBefore,
    double? calmAfter,
    String? note,
  }) async {
    final entry = RegulationEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      toyIds: toyIds,
      mood: mood,
      calmBefore: calmBefore,
      calmAfter: calmAfter,
      note: note,
    );
    state = <RegulationEntry>[...state, entry];
    await _persist();
    return entry;
  }
}

final regulationLogProvider =
    StateNotifierProvider<RegulationLogNotifier, List<RegulationEntry>>(
  (ref) => RegulationLogNotifier(ref.watch(localStorageProvider)),
);

// ---------------------------------------------------------------------------
// Derived sensory profile + insights
// ---------------------------------------------------------------------------

/// The child's sensory profile, recomputed whenever the log changes.
final sensoryProfileProvider = Provider<SensoryProfile>((ref) {
  final log = ref.watch(regulationLogProvider);
  return ref.watch(regulationEngineProvider).deriveProfile(log);
});

/// Per-toy effectiveness ranking.
final toyRankingProvider = Provider<List<ToyEffectiveness>>((ref) {
  final log = ref.watch(regulationLogProvider);
  return ref.watch(regulationEngineProvider).rankToys(log);
});

/// One-line parent insight ("Harshiv calms fastest with …").
final headlineInsightProvider = Provider<String>((ref) {
  final log = ref.watch(regulationLogProvider);
  final name = ref.watch(childNameProvider);
  return ref.watch(regulationEngineProvider).headlineInsight(log, childName: name);
});

/// Recommended toys for right now.
final recommendedToysProvider = Provider((ref) {
  final profile = ref.watch(sensoryProfileProvider);
  return ref.watch(regulationEngineProvider).recommendToys(profile);
});

/// The child's display name (editable in settings; defaults to Harshiv).
/// The initial value is overridden from storage in `main()`.
final childNameProvider = StateProvider<String>((ref) => 'Harshiv');

/// Whether the first-launch child profile wizard has been completed.
/// Overridden from storage in `main()` so returning families skip the wizard.
final profileCompleteProvider = StateProvider<bool>((ref) => false);

enum AudioLevel { off, soft, normal }

class SensoryPreferences {
  const SensoryPreferences({
    this.audioLevel = AudioLevel.normal,
    this.reduceMotion = false,
  });

  final AudioLevel audioLevel;
  final bool reduceMotion;

  double get volumeScale => switch (audioLevel) {
        AudioLevel.off => 0,
        AudioLevel.soft => 0.35,
        AudioLevel.normal => 1,
      };

  SensoryPreferences copyWith({
    AudioLevel? audioLevel,
    bool? reduceMotion,
  }) =>
      SensoryPreferences(
        audioLevel: audioLevel ?? this.audioLevel,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );
}

class SensoryPreferencesNotifier extends StateNotifier<SensoryPreferences> {
  SensoryPreferencesNotifier(this._storage)
      : super(SensoryPreferences(
          audioLevel: AudioLevel.values.firstWhere(
            (level) =>
                level.name ==
                _storage.readString(
                  'audio_level',
                  fallback: AudioLevel.normal.name,
                ),
            orElse: () => AudioLevel.normal,
          ),
          reduceMotion: _storage.readBool('reduce_motion'),
        ));

  final LocalStorage _storage;

  Future<void> setAudioLevel(AudioLevel value) async {
    state = state.copyWith(audioLevel: value);
    await _storage.writeString('audio_level', value.name);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await _storage.writeBool('reduce_motion', value);
  }
}

final sensoryPreferencesProvider = StateNotifierProvider<
    SensoryPreferencesNotifier, SensoryPreferences>(
  (ref) => SensoryPreferencesNotifier(ref.watch(localStorageProvider)),
);

/// The child's most recently spoken AAC words, most-recent first. Surfaces a
/// child's real vocabulary at the top of the board so their actual needs are
/// always one tap away.
class TalkRecentsNotifier extends StateNotifier<List<String>> {
  TalkRecentsNotifier(this._storage) : super(const <String>[]) {
    state = _storage.readList(_key).map((e) => e.toString()).toList();
  }

  static const String _key = 'talk_recents';
  static const int _max = 6;
  final LocalStorage _storage;

  Future<void> record(String label) async {
    final next = <String>[label, ...state.where((e) => e != label)];
    if (next.length > _max) next.removeRange(_max, next.length);
    state = next;
    await _storage.writeJson(_key, next);
  }
}

final talkRecentsProvider =
    StateNotifierProvider<TalkRecentsNotifier, List<String>>(
  (ref) => TalkRecentsNotifier(ref.watch(localStorageProvider)),
);

/// AAC words a family has starred as favourites — always surfaced first so a
/// child's most important words are reachable under stress.
class TalkFavoritesNotifier extends StateNotifier<Set<String>> {
  TalkFavoritesNotifier(this._storage) : super(<String>{}) {
    state = _storage.readList(_key).map((e) => e.toString()).toSet();
  }

  static const String _key = 'talk_favorites';
  final LocalStorage _storage;

  bool isFavorite(String label) => state.contains(label);

  Future<void> toggle(String label) async {
    final next = Set<String>.from(state);
    if (!next.add(label)) next.remove(label);
    state = next;
    await _storage.writeJson(_key, next.toList());
  }
}

final talkFavoritesProvider =
    StateNotifierProvider<TalkFavoritesNotifier, Set<String>>(
  (ref) => TalkFavoritesNotifier(ref.watch(localStorageProvider)),
);

// ---------------------------------------------------------------------------
// Unified activity event log — ONE honest, local-only source of truth that
// personalization and parent insights read from. Privacy-first: never leaves
// the device, capped, and only records what the child actually did.
// ---------------------------------------------------------------------------

class ActivityLogNotifier extends StateNotifier<List<ActivityEvent>> {
  ActivityLogNotifier(this._storage) : super(const <ActivityEvent>[]) {
    state = _storage
        .readList(_key)
        .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static const String _key = 'activity_log';
  static const int _max = 1000;
  final LocalStorage _storage;

  Future<void> log(ActivityType type, String target,
      {int seconds = 0, String? label}) async {
    final ev = ActivityEvent(
      type: type,
      target: target,
      at: DateTime.now(),
      seconds: seconds,
      label: label,
    );
    final next = <ActivityEvent>[...state, ev];
    if (next.length > _max) next.removeRange(0, next.length - _max);
    state = next;
    await _storage.writeJson(_key, next.map((e) => e.toJson()).toList());
  }
}

final activityLogProvider =
    StateNotifierProvider<ActivityLogNotifier, List<ActivityEvent>>(
  (ref) => ActivityLogNotifier(ref.watch(localStorageProvider)),
);

/// A parent-friendly, deterministic summary of the child's activity. NOT AI:
/// pure aggregation of the local event log. Framed as observations, never
/// clinical conclusions.
class ActivityInsights {
  const ActivityInsights({
    required this.eventsToday,
    required this.minutes7d,
    required this.topActivities,
    required this.topWords,
    required this.feelings,
    required this.routinesCompleted7d,
    required this.calmCompleted7d,
    required this.activeHours,
    required this.patterns,
  });

  final int eventsToday;
  final int minutes7d;
  final List<MapEntry<String, int>> topActivities; // label -> count
  final List<MapEntry<String, int>> topWords; // label -> count
  final List<MapEntry<String, int>> feelings; // mood -> count
  final int routinesCompleted7d;
  final int calmCompleted7d;
  final List<int> activeHours; // most active hours 0-23
  final List<String> patterns; // honest week-over-week observations

  bool get hasData => eventsToday > 0 || minutes7d > 0 || topActivities.isNotEmpty;

  factory ActivityInsights.from(List<ActivityEvent> events) {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    var eventsToday = 0;
    var seconds7d = 0;
    var routines = 0;
    var calm = 0;
    final actCount = <String, int>{};
    final wordCount = <String, int>{};
    final feelingCount = <String, int>{};
    final hourCount = <int, int>{};

    // Category buckets for the current week vs the week before (for patterns).
    final thisWeek = <String, int>{};
    final prevWeek = <String, int>{};

    String bucket(ActivityType t) {
      switch (t) {
        case ActivityType.toyPlayed:
        case ActivityType.gamePlayed:
          return 'Play';
        case ActivityType.spoke:
          return 'Talking';
        case ActivityType.feelingChosen:
          return 'Feelings check-ins';
        case ActivityType.routineCompleted:
          return 'Routines';
        case ActivityType.calmCompleted:
          return 'Calm activities';
      }
    }

    for (final e in events) {
      if (e.at.isAfter(startToday)) eventsToday++;

      if (e.at.isAfter(weekAgo)) {
        thisWeek.update(bucket(e.type), (v) => v + 1, ifAbsent: () => 1);
      } else if (e.at.isAfter(twoWeeksAgo)) {
        prevWeek.update(bucket(e.type), (v) => v + 1, ifAbsent: () => 1);
      }

      if (e.at.isAfter(weekAgo)) {
        seconds7d += e.seconds;
        hourCount.update(e.at.hour, (v) => v + 1, ifAbsent: () => 1);
        final name = e.label ?? e.target;
        switch (e.type) {
          case ActivityType.toyPlayed:
          case ActivityType.gamePlayed:
            actCount.update(name, (v) => v + 1, ifAbsent: () => 1);
            break;
          case ActivityType.spoke:
            wordCount.update(name, (v) => v + 1, ifAbsent: () => 1);
            break;
          case ActivityType.feelingChosen:
            feelingCount.update(name, (v) => v + 1, ifAbsent: () => 1);
            break;
          case ActivityType.routineCompleted:
            routines++;
            break;
          case ActivityType.calmCompleted:
            calm++;
            actCount.update(name, (v) => v + 1, ifAbsent: () => 1);
            break;
        }
      }
    }

    List<MapEntry<String, int>> top(Map<String, int> m, int n) {
      final l = m.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return l.take(n).toList();
    }

    final hours = hourCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Honest, deterministic week-over-week observations. Only emitted when
    // there is enough data in the previous week to be a fair comparison.
    final patterns = <String>[];
    final categories = <String>{...thisWeek.keys, ...prevWeek.keys};
    for (final c in categories) {
      final t = thisWeek[c] ?? 0;
      final p = prevWeek[c] ?? 0;
      if (p == 0 && t == 0) continue;
      if (p == 0) continue; // no fair baseline last week
      if (t == p) {
        patterns.add('$c: about the same as last week ($t vs $p).');
      } else if (t > p) {
        patterns.add('$c: used more this week ($t vs $p).');
      } else {
        patterns.add('$c: used less this week ($t vs $p).');
      }
    }

    return ActivityInsights(
      eventsToday: eventsToday,
      minutes7d: (seconds7d / 60).round(),
      topActivities: top(actCount, 5),
      topWords: top(wordCount, 5),
      feelings: top(feelingCount, 5),
      routinesCompleted7d: routines,
      calmCompleted7d: calm,
      activeHours: hours.take(3).map((e) => e.key).toList(),
      patterns: patterns,
    );
  }
}

final activityInsightsProvider = Provider<ActivityInsights>((ref) {
  return ActivityInsights.from(ref.watch(activityLogProvider));
});
