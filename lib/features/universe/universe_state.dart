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
  const ToyUsage({this.recents = const <String>[], this.counts = const <String, int>{}});

  /// Most-recent first, capped.
  final List<String> recents;
  final Map<String, int> counts;

  ToyUsage copyWith({List<String>? recents, Map<String, int>? counts}) =>
      ToyUsage(recents: recents ?? this.recents, counts: counts ?? this.counts);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'recents': recents,
        'counts': counts,
      };

  factory ToyUsage.fromJson(Map<String, dynamic> j) => ToyUsage(
        recents: (j['recents'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList(),
        counts: (j['counts'] as Map<String, dynamic>? ?? const <String, dynamic>{})
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
