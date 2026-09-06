/// A single, privacy-first record of something the child actually did.
///
/// This is the one unified event schema for HARSHIVOS. Every feature logs
/// through it so personalization and parent insights read from ONE honest
/// source instead of scattered per-feature counters. Stored locally only.
enum ActivityType {
  toyPlayed,
  calmCompleted,
  spoke,
  feelingChosen,
  routineCompleted,
  gamePlayed,
  adventurePlayed,
}

class ActivityEvent {
  const ActivityEvent({
    required this.type,
    required this.target,
    required this.at,
    this.seconds = 0,
    this.label,
  });

  /// What kind of activity happened.
  final ActivityType type;

  /// A stable id: toy id, mood name, phrase label, routine id, game id.
  final String target;

  /// When it happened (local device time).
  final DateTime at;

  /// Optional duration in whole seconds (for timed activities).
  final int seconds;

  /// Optional human-friendly label for parent display (e.g. "Bubble Pop").
  final String? label;

  Map<String, dynamic> toJson() => <String, dynamic>{
        't': type.index,
        'x': target,
        'at': at.millisecondsSinceEpoch,
        's': seconds,
        if (label != null) 'l': label,
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> j) => ActivityEvent(
        type: ActivityType
            .values[(j['t'] as num?)?.toInt() ?? 0],
        target: (j['x'] as String?) ?? '',
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
        seconds: (j['s'] as num?)?.toInt() ?? 0,
        label: j['l'] as String?,
      );
}
