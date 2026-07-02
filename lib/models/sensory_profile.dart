import 'package:flutter/material.dart';

/// The five sensory-seeking dimensions HARSHIVOS learns for each child.
enum SensoryChannel { visual, auditory, tactile, vestibular, proprioceptive }

extension SensoryChannelX on SensoryChannel {
  String get label => switch (this) {
        SensoryChannel.visual => 'Visual seeker',
        SensoryChannel.auditory => 'Auditory seeker',
        SensoryChannel.tactile => 'Tactile seeker',
        SensoryChannel.vestibular => 'Vestibular seeker',
        SensoryChannel.proprioceptive => 'Proprioceptive seeker',
      };

  String get emoji => switch (this) {
        SensoryChannel.visual => '👁️',
        SensoryChannel.auditory => '🎧',
        SensoryChannel.tactile => '✋',
        SensoryChannel.vestibular => '🌀',
        SensoryChannel.proprioceptive => '💪',
      };

  Color get color => switch (this) {
        SensoryChannel.visual => const Color(0xFF54A0FF),
        SensoryChannel.auditory => const Color(0xFFFF9F43),
        SensoryChannel.tactile => const Color(0xFF26DE81),
        SensoryChannel.vestibular => const Color(0xFFA55EEA),
        SensoryChannel.proprioceptive => const Color(0xFFFF6B9D),
      };
}

/// A learned, evolving picture of how a child seeks and regulates sensory input.
///
/// Scores are exponential moving averages in the range 0..1 — they shift as the
/// regulation engine observes which toys calm the child fastest.
class SensoryProfile {
  SensoryProfile({Map<SensoryChannel, double>? scores})
      : scores = scores ??
            <SensoryChannel, double>{
              for (final c in SensoryChannel.values) c: 0.5,
            };

  final Map<SensoryChannel, double> scores;

  double scoreOf(SensoryChannel c) => scores[c] ?? 0.5;

  /// The channels this child seeks most strongly, highest first.
  List<SensoryChannel> get dominantChannels {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  /// Nudge a channel toward [target] (0..1) using an EMA so the profile
  /// adapts gradually rather than lurching.
  void reinforce(SensoryChannel c, double target, {double rate = 0.18}) {
    final current = scores[c] ?? 0.5;
    scores[c] = (current + (target - current) * rate).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() =>
      <String, dynamic>{for (final e in scores.entries) e.key.name: e.value};

  factory SensoryProfile.fromJson(Map<String, dynamic> json) {
    final scores = <SensoryChannel, double>{};
    for (final c in SensoryChannel.values) {
      scores[c] = (json[c.name] as num?)?.toDouble() ?? 0.5;
    }
    return SensoryProfile(scores: scores);
  }
}
