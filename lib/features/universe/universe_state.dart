import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage/local_storage.dart';
import '../../state/providers.dart';
import 'universe_catalog.dart';

// ---------------------------------------------------------------------------
// Favorites — the child's / parent's hearted toys.
// ---------------------------------------------------------------------------

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier(this._storage) : super(<String>{}) {
    _load();
  }

  static const String _key = 'toy_favorites';
  final LocalStorage _storage;

  void _load() {
    final raw = _storage.readList(_key);
    state = raw.map((e) => e.toString()).toSet();
  }

  Future<void> _persist() => _storage.writeJson(_key, state.toList());

  bool isFavorite(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    final next = Set<String>.from(state);
    if (!next.add(id)) next.remove(id);
    state = next;
    await _persist();
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) => FavoritesNotifier(ref.watch(localStorageProvider)),
);

// ---------------------------------------------------------------------------
// Usage — recents (ordered) + per-toy play counts (for "Most Loved").
// ---------------------------------------------------------------------------

@immutable
class ToyUsage {
  const ToyUsage({
    this.recents = const <String>[],
    this.counts = const <String, int>{},
    this.totalMs = const <String, int>{},
  });

  /// Most-recent first, capped.
  final List<String> recents;

  /// Number of times each toy was opened.
  final Map<String, int> counts;

  /// Total time (ms) spent playing each toy, summed across sessions.
  final Map<String, int> totalMs;

  ToyUsage copyWith({
    List<String>? recents,
    Map<String, int>? counts,
    Map<String, int>? totalMs,
  }) =>
      ToyUsage(
        recents: recents ?? this.recents,
        counts: counts ?? this.counts,
        totalMs: totalMs ?? this.totalMs,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'recents': recents,
        'counts': counts,
        'totalMs': totalMs,
      };

  factory ToyUsage.fromJson(Map<String, dynamic> j) => ToyUsage(
        recents: (j['recents'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList(),
        counts: (j['counts'] as Map<String, dynamic>? ?? const <String, dynamic>{})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        totalMs: (j['totalMs'] as Map<String, dynamic>? ?? const <String, dynamic>{})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}

class ToyUsageNotifier extends StateNotifier<ToyUsage> {
  ToyUsageNotifier(this._storage) : super(const ToyUsage()) {
    final raw = _storage.readJson(_key);
    if (raw.isNotEmpty) state = ToyUsage.fromJson(raw);
  }

  static const String _key = 'toy_usage';
  static const int _maxRecents = 20;
  final LocalStorage _storage;

  Future<void> _persist() => _storage.writeJson(_key, state.toJson());

  /// Records that a toy was opened: bumps its count and moves it to the front
  /// of the recents list.
  Future<void> record(String id) async {
    final recents = <String>[id, ...state.recents.where((e) => e != id)];
    if (recents.length > _maxRecents) recents.removeRange(_maxRecents, recents.length);
    final counts = Map<String, int>.from(state.counts);
    counts[id] = (counts[id] ?? 0) + 1;
    state = state.copyWith(recents: recents, counts: counts);
    await _persist();
  }

  /// Records how long a toy was played (added to its running total). Called
  /// when the immersive player is dismissed. Ignores implausible sessions
  /// (< 0.5s taps or > 1h) so the average stays meaningful.
  Future<void> recordDuration(String id, Duration played) async {
    final ms = played.inMilliseconds;
    if (ms < 500 || ms > 3600000) return;
    final totalMs = Map<String, int>.from(state.totalMs);
    totalMs[id] = (totalMs[id] ?? 0) + ms;
    state = state.copyWith(totalMs: totalMs);
    await _persist();
  }
}

final toyUsageProvider = StateNotifierProvider<ToyUsageNotifier, ToyUsage>(
  (ref) => ToyUsageNotifier(ref.watch(localStorageProvider)),
);

// ---------------------------------------------------------------------------
// Derived section lists for the Toy Universe rails.
// ---------------------------------------------------------------------------

/// Hearted toys, in catalogue order.
final favoriteToysProvider = Provider<List<UniverseToy>>((ref) {
  final favs = ref.watch(favoritesProvider);
  return kToyUniverse.where((t) => favs.contains(t.id)).toList();
});

/// Recently played, most-recent first.
final recentToysProvider = Provider<List<UniverseToy>>((ref) {
  final usage = ref.watch(toyUsageProvider);
  return usage.recents
      .map((id) => kToyUniverseById[id])
      .whereType<UniverseToy>()
      .toList();
});

/// Most-loved by play count (only toys played at least once).
final mostLovedToysProvider = Provider<List<UniverseToy>>((ref) {
  final usage = ref.watch(toyUsageProvider);
  final played = kToyUniverse
      .where((t) => (usage.counts[t.id] ?? 0) > 0)
      .toList()
    ..sort((a, b) => (usage.counts[b.id] ?? 0).compareTo(usage.counts[a.id] ?? 0));
  return played.take(10).toList();
});

/// New toys badge rail.
final newToysProvider = Provider<List<UniverseToy>>((ref) {
  return kToyUniverse.where((t) => t.isNew).toList();
});

// ---------------------------------------------------------------------------
// Analytics — what the child actually plays, so we can learn and tune.
// ---------------------------------------------------------------------------

/// A single toy's usage stats: how often it was opened, total and average
/// time spent inside it.
@immutable
class ToyStat {
  const ToyStat({
    required this.toy,
    required this.plays,
    required this.totalMs,
  });

  final UniverseToy toy;
  final int plays;
  final int totalMs;

  /// Average play duration (0 if never timed).
  Duration get average =>
      plays == 0 ? Duration.zero : Duration(milliseconds: totalMs ~/ plays);
}

/// Every toy's stats, sorted most-played first. Toys never played sort last
/// (plays == 0) so the tail of this list is the "least played" set.
final toyStatsProvider = Provider<List<ToyStat>>((ref) {
  final usage = ref.watch(toyUsageProvider);
  final stats = <ToyStat>[
    for (final t in kToyUniverse)
      ToyStat(
        toy: t,
        plays: usage.counts[t.id] ?? 0,
        totalMs: usage.totalMs[t.id] ?? 0,
      ),
  ]..sort((a, b) => b.plays.compareTo(a.plays));
  return stats;
});

/// Most played toys (played at least once), highest first.
final mostPlayedProvider = Provider<List<ToyStat>>((ref) {
  return ref.watch(toyStatsProvider).where((s) => s.plays > 0).toList();
});

/// Least played toys — the tail, including never-played toys, lowest first.
final leastPlayedProvider = Provider<List<ToyStat>>((ref) {
  final stats = ref.watch(toyStatsProvider).toList()
    ..sort((a, b) => a.plays.compareTo(b.plays));
  return stats;
});

/// Average play duration across every timed session, in seconds.
final averagePlaySecondsProvider = Provider<int>((ref) {
  final usage = ref.watch(toyUsageProvider);
  var totalMs = 0;
  var plays = 0;
  for (final t in kToyUniverse) {
    final ms = usage.totalMs[t.id] ?? 0;
    if (ms == 0) continue;
    totalMs += ms;
    plays += usage.counts[t.id] ?? 0;
  }
  if (plays == 0) return 0;
  return (totalMs / plays / 1000).round();
});
