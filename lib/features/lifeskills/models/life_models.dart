import 'package:flutter/material.dart';

import '../avatar/avatar.dart';

/// How a routine step behaves in the player.
enum StepKind { instruction, timer }

/// A single step inside a routine: one big visual, the avatar doing it, and a
/// short spoken instruction.
@immutable
class RoutineStep {
  const RoutineStep({
    required this.title,
    required this.instruction,
    required this.emoji,
    this.pose = AvatarPose.idle,
    this.kind = StepKind.instruction,
    this.timerSeconds,
    this.accent = const Color(0xFF4CC9F0),
    this.photoPath,
  });

  final String title;

  /// Spoken (and shown) instruction — kept short and warm.
  final String instruction;
  final String emoji;
  final AvatarPose pose;
  final StepKind kind;

  /// For [StepKind.timer] steps (brushing, hand-washing).
  final int? timerSeconds;
  final Color accent;

  /// Optional path to a family-supplied photo for this step (their own
  /// bathroom / temple / kitchen). Makes routines feel like *home*. Offline —
  /// the file lives in the app's documents directory.
  final String? photoPath;

  RoutineStep copyWith({
    String? title,
    String? instruction,
    String? emoji,
    AvatarPose? pose,
    StepKind? kind,
    int? timerSeconds,
    Color? accent,
    String? photoPath,
  }) {
    return RoutineStep(
      title: title ?? this.title,
      instruction: instruction ?? this.instruction,
      emoji: emoji ?? this.emoji,
      pose: pose ?? this.pose,
      kind: kind ?? this.kind,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      accent: accent ?? this.accent,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'instruction': instruction,
        'emoji': emoji,
        'pose': pose.index,
        'kind': kind.index,
        'timerSeconds': timerSeconds,
        'accent': accent.value,
        'photoPath': photoPath,
      };

  factory RoutineStep.fromJson(Map<String, dynamic> j) => RoutineStep(
        title: j['title'] as String? ?? '',
        instruction: j['instruction'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '⭐',
        pose: AvatarPose.values[(j['pose'] as num?)?.toInt() ?? 0],
        kind: StepKind.values[(j['kind'] as num?)?.toInt() ?? 0],
        timerSeconds: (j['timerSeconds'] as num?)?.toInt(),
        accent: Color((j['accent'] as num?)?.toInt() ?? 0xFF4CC9F0),
        photoPath: j['photoPath'] as String?,
      );
}

/// A complete guided routine (Morning, Potty, Brushing, ...).
@immutable
class LifeRoutine {
  const LifeRoutine({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradient,
    required this.steps,
    this.custom = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradient;
  final List<RoutineStep> steps;
  final bool custom;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'emoji': emoji,
        'gradient': gradient.map((c) => c.value).toList(),
        'steps': steps.map((s) => s.toJson()).toList(),
        'custom': custom,
      };

  factory LifeRoutine.fromJson(Map<String, dynamic> j) => LifeRoutine(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '⭐',
        gradient: ((j['gradient'] as List<dynamic>?) ?? <dynamic>[])
            .map((v) => Color((v as num).toInt()))
            .toList(),
        steps: ((j['steps'] as List<dynamic>?) ?? <dynamic>[])
            .map((v) => RoutineStep.fromJson(v as Map<String, dynamic>))
            .toList(),
        custom: j['custom'] as bool? ?? false,
      );
}

/// The nature of a lesson card — drives colour + iconography.
enum LessonKind { doThis, dontThis, good, bad, info }

/// A single teaching card (a "Do", a "Don't", a good/bad social example).
@immutable
class LessonCard {
  const LessonCard({
    required this.title,
    required this.narration,
    required this.emoji,
    required this.kind,
    this.pose = AvatarPose.idle,
  });

  final String title;
  final String narration;
  final String emoji;
  final LessonKind kind;
  final AvatarPose pose;
}

/// A themed deck of lesson cards (Do's & Don'ts, a social skill, a safety
/// place). Played as a swipeable stack in [CardDeckScreen].
@immutable
class LessonDeck {
  const LessonDeck({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradient,
    required this.cards,
  });

  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradient;
  final List<LessonCard> cards;
}

/// What kind of proud moment a [Win] captures.
enum WinKind { routine, milestone, moment }

/// A single celebrated success in the child's **Success Binder / My Wins** —
/// a growing keepsake of proud moments. Some are captured automatically when a
/// routine is finished; others are added by a parent ("Tried a new food!",
/// "Stayed calm at the dentist"). Stored locally, fully offline.
@immutable
class Win {
  const Win({
    required this.id,
    required this.title,
    required this.dateIso,
    this.note = '',
    this.emoji = '⭐',
    this.kind = WinKind.moment,
    this.routineId,
    this.photoPath,
    this.accent = const Color(0xFFFFD166),
  });

  final String id;
  final String title;

  /// yyyy-mm-dd of the day the win happened.
  final String dateIso;
  final String note;
  final String emoji;
  final WinKind kind;

  /// Set when the win came from finishing a routine.
  final String? routineId;

  /// Optional family photo of the proud moment (offline file path).
  final String? photoPath;
  final Color accent;

  Win copyWith({
    String? title,
    String? dateIso,
    String? note,
    String? emoji,
    WinKind? kind,
    String? routineId,
    String? photoPath,
    Color? accent,
  }) {
    return Win(
      id: id,
      title: title ?? this.title,
      dateIso: dateIso ?? this.dateIso,
      note: note ?? this.note,
      emoji: emoji ?? this.emoji,
      kind: kind ?? this.kind,
      routineId: routineId ?? this.routineId,
      photoPath: photoPath ?? this.photoPath,
      accent: accent ?? this.accent,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'dateIso': dateIso,
        'note': note,
        'emoji': emoji,
        'kind': kind.index,
        'routineId': routineId,
        'photoPath': photoPath,
        'accent': accent.value,
      };

  factory Win.fromJson(Map<String, dynamic> j) => Win(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        dateIso: j['dateIso'] as String? ?? '',
        note: j['note'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '⭐',
        kind: WinKind.values[(j['kind'] as num?)?.toInt() ?? 2],
        routineId: j['routineId'] as String?,
        photoPath: j['photoPath'] as String?,
        accent: Color((j['accent'] as num?)?.toInt() ?? 0xFFFFD166),
      );
}
