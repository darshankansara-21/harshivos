import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/cloud/cloud_sync.dart';
import '../../../state/providers.dart';
import '../avatar/avatar.dart';
import '../models/life_models.dart';

/// The child's Life Skills progress — completions, streaks, favourites and a
/// derived independence score. Stored locally, ready to mirror to Firebase.
class LifeProgress {
  const LifeProgress({
    this.completions = const <String, int>{},
    this.streak = 0,
    this.lastDay = '',
    this.favorites = const <String>{},
  });

  /// routineId -> times completed.
  final Map<String, int> completions;
  final int streak;
  final String lastDay; // yyyy-mm-dd of last completion
  final Set<String> favorites;

  int get totalCompleted =>
      completions.values.fold(0, (a, b) => a + b);

  /// A routine is "mastered" once done independently three times.
  Set<String> get mastered => completions.entries
      .where((e) => e.value >= 3)
      .map((e) => e.key)
      .toSet();

  /// 0–100, grows with practice and mastery.
  int get independenceScore {
    final base = totalCompleted * 4 + mastered.length * 12;
    return base > 100 ? 100 : base;
  }

  LifeProgress copyWith({
    Map<String, int>? completions,
    int? streak,
    String? lastDay,
    Set<String>? favorites,
  }) {
    return LifeProgress(
      completions: completions ?? this.completions,
      streak: streak ?? this.streak,
      lastDay: lastDay ?? this.lastDay,
      favorites: favorites ?? this.favorites,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'completions': completions,
        'streak': streak,
        'lastDay': lastDay,
        'favorites': favorites.toList(),
      };

  factory LifeProgress.fromJson(Map<String, dynamic> j) => LifeProgress(
        completions: ((j['completions'] as Map<String, dynamic>?) ??
                <String, dynamic>{})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        lastDay: j['lastDay'] as String? ?? '',
        favorites: ((j['favorites'] as List<dynamic>?) ?? <dynamic>[])
            .map((e) => e as String)
            .toSet(),
      );
}

class LifeProgressNotifier extends StateNotifier<LifeProgress> {
  LifeProgressNotifier(this._ref) : super(const LifeProgress()) {
    _load();
  }

  static const _key = 'life_progress';
  final Ref _ref;

  void _load() {
    final raw = _ref.read(localStorageProvider).readJson(_key);
    if (raw.isNotEmpty) state = LifeProgress.fromJson(raw);
  }

  Future<void> _persist() async {
    await _ref.read(localStorageProvider).writeJson(_key, state.toJson());
    await _ref.read(cloudSyncProvider).push('life_progress', state.toJson());
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> markComplete(String routineId) async {
    final counts = Map<String, int>.from(state.completions);
    counts[routineId] = (counts[routineId] ?? 0) + 1;

    final today = _today();
    int streak = state.streak;
    if (state.lastDay != today) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';
      streak = (state.lastDay == yStr) ? state.streak + 1 : 1;
    }
    if (streak == 0) streak = 1;

    state = state.copyWith(
      completions: counts,
      streak: streak,
      lastDay: today,
    );
    await _persist();
  }

  Future<void> toggleFavorite(String routineId) async {
    final favs = Set<String>.from(state.favorites);
    if (!favs.add(routineId)) favs.remove(routineId);
    state = state.copyWith(favorites: favs);
    await _persist();
  }
}

final lifeProgressProvider =
    StateNotifierProvider<LifeProgressNotifier, LifeProgress>(
  (ref) => LifeProgressNotifier(ref),
);

// --------------------------------------------------------------------------
// Custom family routines (parent-created, stored locally)
// --------------------------------------------------------------------------

class CustomRoutinesNotifier extends StateNotifier<List<LifeRoutine>> {
  CustomRoutinesNotifier(this._ref) : super(const <LifeRoutine>[]) {
    _load();
  }

  static const _key = 'life_custom_routines';
  final Ref _ref;

  void _load() {
    final raw = _ref.read(localStorageProvider).readList(_key);
    state = raw
        .map((e) => LifeRoutine.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _persist() async {
    await _ref
        .read(localStorageProvider)
        .writeJson(_key, state.map((r) => r.toJson()).toList());
    await _ref.read(cloudSyncProvider).push(
      'life_custom_routines',
      <String, dynamic>{'routines': state.map((r) => r.toJson()).toList()},
    );
  }

  Future<void> add(LifeRoutine routine) async {
    state = <LifeRoutine>[...state, routine];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _persist();
  }
}

final customRoutinesProvider =
    StateNotifierProvider<CustomRoutinesNotifier, List<LifeRoutine>>(
  (ref) => CustomRoutinesNotifier(ref),
);

// --------------------------------------------------------------------------
// Avatar configuration (the child's guide, saved once, used everywhere)
// --------------------------------------------------------------------------

class AvatarConfigNotifier extends StateNotifier<AvatarConfig> {
  AvatarConfigNotifier(this._ref) : super(const AvatarConfig()) {
    _load();
  }

  static const _key = 'avatar_config';
  final Ref _ref;

  void _load() {
    final raw = _ref.read(localStorageProvider).readJson(_key);
    if (raw.isNotEmpty) state = AvatarConfig.fromJson(raw);
  }

  Future<void> update(AvatarConfig config) async {
    state = config;
    await _ref.read(localStorageProvider).writeJson(_key, config.toJson());
    await _ref.read(cloudSyncProvider).push('avatar_config', config.toJson());
  }
}

final avatarConfigProvider =
    StateNotifierProvider<AvatarConfigNotifier, AvatarConfig>(
  (ref) => AvatarConfigNotifier(ref),
);
