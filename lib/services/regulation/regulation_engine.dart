import '../../models/regulation_entry.dart';
import '../../models/sensory_profile.dart';
import '../../models/toy_meta.dart';

/// Aggregated, per-toy effectiveness derived from the regulation log.
class ToyEffectiveness {
  ToyEffectiveness({
    required this.toyId,
    required this.sessions,
    required this.averageCalmDelta,
  });

  final String toyId;
  final int sessions;

  /// Mean improvement in calm level (−1..1) across sessions using this toy.
  final double averageCalmDelta;
}

/// The "Regulation Genome": pure analysis over the regulation log.
///
/// Stateless on purpose — given the log it derives the sensory profile, the
/// toys that calm the child fastest, and the triggers to watch for. State
/// notifiers wrap this; the math lives here so it is testable in isolation.
class RegulationEngine {
  const RegulationEngine();

  /// Re-derive a sensory profile from scratch based on which toys produced the
  /// biggest calm improvements.
  SensoryProfile deriveProfile(List<RegulationEntry> log) {
    final profile = SensoryProfile();
    // Replay sessions oldest-first so the EMA reflects recent behaviour most.
    final ordered = [...log]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final entry in ordered) {
      final delta = entry.calmDelta ?? 0.0;
      // Map a positive outcome toward 1.0, a negative toward 0.0.
      final target = (0.5 + delta * 0.5).clamp(0.0, 1.0);
      for (final toyId in entry.toyIds) {
        for (final channel in toyMetaById(toyId).channels) {
          profile.reinforce(channel, target);
        }
      }
    }
    return profile;
  }

  /// Rank toys by how much they calm this child, most effective first.
  List<ToyEffectiveness> rankToys(List<RegulationEntry> log) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final entry in log) {
      final delta = entry.calmDelta;
      if (delta == null) continue;
      for (final toyId in entry.toyIds) {
        sums[toyId] = (sums[toyId] ?? 0) + delta;
        counts[toyId] = (counts[toyId] ?? 0) + 1;
      }
    }
    final result = <ToyEffectiveness>[
      for (final id in counts.keys)
        ToyEffectiveness(
          toyId: id,
          sessions: counts[id]!,
          averageCalmDelta: sums[id]! / counts[id]!,
        ),
    ]..sort((a, b) => b.averageCalmDelta.compareTo(a.averageCalmDelta));
    return result;
  }

  /// A plain-language insight a parent can read at a glance.
  String headlineInsight(List<RegulationEntry> log, {String childName = 'Your child'}) {
    final ranked = rankToys(log).where((t) => t.averageCalmDelta > 0).toList();
    if (ranked.isEmpty) {
      return 'Keep playing — HARSHIVOS is still learning what calms $childName.';
    }
    final names = ranked.take(2).map((t) => toyMetaById(t.toyId).title).toList();
    final joined = names.length == 1 ? names.first : '${names[0]} and ${names[1]}';
    return '$childName calms fastest with $joined.';
  }

  /// Recommend the toys most likely to help right now, given the profile.
  List<ToyMeta> recommendToys(SensoryProfile profile, {int count = 3}) {
    final dominant = profile.dominantChannels.take(2).toSet();
    final scored = kToyCatalog.where((t) => t.implemented).map((toy) {
      final overlap = toy.channels.where(dominant.contains).length;
      final channelScore =
          toy.channels.fold<double>(0, (s, c) => s + profile.scoreOf(c)) /
              toy.channels.length;
      return MapEntry(toy, overlap * 1.0 + channelScore);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.take(count).map((e) => e.key).toList();
  }

  /// Which moods most often precede a session (trigger pattern).
  Map<CalmMood, int> triggerFrequency(List<RegulationEntry> log) {
    final freq = <CalmMood, int>{};
    for (final e in log) {
      final m = e.mood;
      if (m != null) freq[m] = (freq[m] ?? 0) + 1;
    }
    return freq;
  }

  /// The hours of day with the most successful regulation sessions.
  List<int> bestRegulationHours(List<RegulationEntry> log) {
    final byHour = <int, double>{};
    for (final e in log) {
      final delta = e.calmDelta ?? 0;
      byHour[e.timestamp.hour] = (byHour[e.timestamp.hour] ?? 0) + delta;
    }
    final hours = byHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return hours.take(3).map((e) => e.key).toList();
  }
}
