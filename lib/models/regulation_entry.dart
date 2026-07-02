/// The emotional states a child (or caregiver) can pick in Calm Me.
enum CalmMood { overwhelmed, frustrated, sad, anxious, tired }

extension CalmMoodX on CalmMood {
  String get label => switch (this) {
        CalmMood.overwhelmed => 'Overwhelmed',
        CalmMood.frustrated => 'Frustrated',
        CalmMood.sad => 'Sad',
        CalmMood.anxious => 'Anxious',
        CalmMood.tired => 'Tired',
      };

  String get emoji => switch (this) {
        CalmMood.overwhelmed => '😖',
        CalmMood.frustrated => '😡',
        CalmMood.sad => '😢',
        CalmMood.anxious => '😨',
        CalmMood.tired => '😴',
      };
}

/// One logged regulation session — the heart of the "Regulation Genome".
class RegulationEntry {
  RegulationEntry({
    required this.id,
    required this.timestamp,
    required this.toyIds,
    this.mood,
    this.calmBefore,
    this.calmAfter,
    this.note,
  });

  final String id;
  final DateTime timestamp;

  /// Toys used during this session.
  final List<String> toyIds;

  /// Optional starting mood (set when launched from Calm Me).
  final CalmMood? mood;

  /// Self/caregiver-reported regulation level 0..1 (1 == fully calm).
  final double? calmBefore;
  final double? calmAfter;

  final String? note;

  /// Positive == the session helped.
  double? get calmDelta =>
      (calmBefore != null && calmAfter != null) ? calmAfter! - calmBefore! : null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'toyIds': toyIds,
        'mood': mood?.name,
        'calmBefore': calmBefore,
        'calmAfter': calmAfter,
        'note': note,
      };

  factory RegulationEntry.fromJson(Map<String, dynamic> json) => RegulationEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        toyIds: (json['toyIds'] as List<dynamic>).cast<String>(),
        mood: _moodFromName(json['mood'] as String?),
        calmBefore: (json['calmBefore'] as num?)?.toDouble(),
        calmAfter: (json['calmAfter'] as num?)?.toDouble(),
        note: json['note'] as String?,
      );

  static CalmMood? _moodFromName(String? name) {
    if (name == null) return null;
    for (final m in CalmMood.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}
