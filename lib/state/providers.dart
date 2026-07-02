import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
final childNameProvider = StateProvider<String>((ref) => 'Harshiv');
