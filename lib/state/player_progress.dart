import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage/local_storage.dart';
import 'providers.dart' show localStorageProvider;

/// A single unlockable achievement.
class Achievement {
  const Achievement(this.id, this.emoji, this.title, this.hint);
  final String id;
  final String emoji;
  final String title;
  final String hint;
}

/// The full deterministic achievement set. Unlock conditions live in
/// [PlayerProgress.earnedAchievements] so state and definitions never drift.
const List<Achievement> kAchievements = <Achievement>[
  Achievement('first_play', '🎉', 'First Play', 'Play your first game'),
  Achievement('explorer_10', '🧭', 'Explorer', 'Play 10 times'),
  Achievement('explorer_50', '🗺️', 'Adventurer', 'Play 50 times'),
  Achievement('record_1', '⭐', 'Record Breaker', 'Set your first best score'),
  Achievement('record_10', '🌟', 'Champion', 'Set 10 best scores'),
  Achievement('level_5', '🏅', 'Rising Star', 'Reach level 5'),
  Achievement('level_10', '🏆', 'WonderPlayer', 'Reach level 10'),
];

/// Local-first player progression. XP is earned only from real activity —
/// finishing a play session and beating your own best score — never inflated.
///
/// The model is intentionally serialisable and account-agnostic so a guest
/// profile can later be migrated to a synced account without a redesign.
class PlayerProgress {
  const PlayerProgress({
    this.xp = 0,
    this.plays = 0,
    this.records = 0,
    this.achievements = const <String>{},
  });

  final int xp;
  final int plays; // total play sessions
  final int records; // personal bests set — the app's collectible "stars"
  final Set<String> achievements;

  static const int _xpPerLevel = 60;

  int get level => 1 + xp ~/ _xpPerLevel;
  int get xpIntoLevel => xp % _xpPerLevel;
  int get xpForLevel => _xpPerLevel;
  double get levelProgress => xpIntoLevel / _xpPerLevel;
  int get stars => records;

  PlayerProgress copyWith({
    int? xp,
    int? plays,
    int? records,
    Set<String>? achievements,
  }) =>
      PlayerProgress(
        xp: xp ?? this.xp,
        plays: plays ?? this.plays,
        records: records ?? this.records,
        achievements: achievements ?? this.achievements,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'xp': xp,
        'plays': plays,
        'records': records,
        'achievements': achievements.toList(),
      };

  factory PlayerProgress.fromJson(Map<String, dynamic> j) => PlayerProgress(
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        records: (j['records'] as num?)?.toInt() ?? 0,
        achievements:
            ((j['achievements'] as List<dynamic>?) ?? const <dynamic>[])
                .map((e) => e.toString())
                .toSet(),
      );

  /// The achievements that should be unlocked for the current stats. Pure and
  /// deterministic, so recomputing is always safe.
  Set<String> get earnedAchievements {
    final s = <String>{};
    if (plays >= 1) s.add('first_play');
    if (plays >= 10) s.add('explorer_10');
    if (plays >= 50) s.add('explorer_50');
    if (records >= 1) s.add('record_1');
    if (records >= 10) s.add('record_10');
    if (level >= 5) s.add('level_5');
    if (level >= 10) s.add('level_10');
    return s;
  }
}

class PlayerProgressNotifier extends StateNotifier<PlayerProgress> {
  PlayerProgressNotifier(this._storage)
      : super(PlayerProgress.fromJson(_storage.readJson(_key)));

  static const String _key = 'player_progress';
  final LocalStorage _storage;

  /// Records one completed play session. [newBest] means the player beat their
  /// own best score; [completed] means they reached the game's goal/win.
  /// Returns the achievement ids newly unlocked by this session.
  List<String> recordSession({bool newBest = false, bool completed = false}) {
    var xp = state.xp + 6; // engagement
    if (newBest) xp += 12; // performance
    if (completed) xp += 8; // finished a goal
    final before = state.achievements;
    var next = state.copyWith(
      xp: xp,
      plays: state.plays + 1,
      records: state.records + (newBest ? 1 : 0),
    );
    final earned = next.earnedAchievements;
    next = next.copyWith(achievements: earned);
    state = next;
    _storage.writeJson(_key, state.toJson());
    return earned.difference(before).toList();
  }
}

final playerProgressProvider =
    StateNotifierProvider<PlayerProgressNotifier, PlayerProgress>(
  (ref) => PlayerProgressNotifier(ref.watch(localStorageProvider)),
);

Achievement? achievementById(String id) {
  for (final a in kAchievements) {
    if (a.id == id) return a;
  }
  return null;
}
