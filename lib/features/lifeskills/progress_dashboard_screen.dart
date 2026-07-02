import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../../core/widgets/glass_card.dart';
import '../../state/providers.dart';
import 'data/routine_library.dart';
import 'models/life_models.dart';
import 'state/lifeskills_providers.dart';

/// A warm, visual PARENT-facing progress dashboard for the "My Daily Life"
/// life-skills pillar — independence score, streaks, mastery and gentle nudges.
class ProgressDashboardScreen extends ConsumerWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childName = ref.watch(childNameProvider);
    final progress = ref.watch(lifeProgressProvider);

    return HarshivScaffold(
      padding: EdgeInsets.zero,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _TopBar(childName: childName),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _HeroCard(progress: progress),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _MasteredSection(progress: progress),
            ),
          ),
          if (progress.mastered.length < RoutineLibrary.routines.length)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _NeedsPracticeSection(progress: progress),
              ),
            ),
          if (progress.favorites.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _FavoritesSection(progress: progress),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

/// Back button + title with child's name.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.childName});

  final String childName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 16,
          onTap: () => Navigator.of(context).pop(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            "$childName's Progress",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hero card: Independence Score ring + streak + total completed pills.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.progress});

  final LifeProgress progress;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      borderRadius: 32,
      glowColor: const Color(0xFF4CC9F0),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _IndependenceRingPainter(
                    score: progress.independenceScore,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '${progress.independenceScore}',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Independent',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _StatPill(
                      emoji: '🔥',
                      value: '${progress.streak}',
                      label: 'day streak',
                      accentColor: const Color(0xFFFF6B6B),
                    ),
                    const SizedBox(height: 12),
                    _StatPill(
                      emoji: '✅',
                      value: '${progress.totalCompleted}',
                      label: 'activities done',
                      accentColor: const Color(0xFF06D6A0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stat pill: emoji + value + label.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.emoji,
    required this.value,
    required this.label,
    required this.accentColor,
  });

  final String emoji;
  final String value;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accentColor.withOpacity(0.15),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Skills Mastered ⭐" section.
class _MasteredSection extends StatelessWidget {
  const _MasteredSection({required this.progress});

  final LifeProgress progress;

  @override
  Widget build(BuildContext context) {
    if (progress.mastered.isEmpty) {
      return const SizedBox.shrink();
    }

    final masteredRoutines = RoutineLibrary.routines
        .where((r) => progress.mastered.contains(r.id))
        .toList();

    if (masteredRoutines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Skills Mastered ⭐',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...masteredRoutines.map((routine) {
          final count = progress.completions[routine.id] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoutineTile(
              routine: routine,
              completionCount: count,
              isMastered: true,
            ),
          );
        }),
      ],
    );
  }
}

/// "Needs Practice" section: routines with 0 completions.
class _NeedsPracticeSection extends StatelessWidget {
  const _NeedsPracticeSection({required this.progress});

  final LifeProgress progress;

  @override
  Widget build(BuildContext context) {
    final needsPractice = RoutineLibrary.routines
        .where((r) => (progress.completions[r.id] ?? 0) == 0)
        .toList();

    if (needsPractice.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "Let's Try These Together 💪",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'These skills are waiting for you. Every step counts!',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...needsPractice.take(3).map((routine) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoutineTile(
              routine: routine,
              completionCount: 0,
              isMastered: false,
            ),
          );
        }),
      ],
    );
  }
}

/// "Favorites 💜" section.
class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection({required this.progress});

  final LifeProgress progress;

  @override
  Widget build(BuildContext context) {
    final favoriteRoutines = RoutineLibrary.routines
        .where((r) => progress.favorites.contains(r.id))
        .toList();

    if (favoriteRoutines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Favorites 💜',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...favoriteRoutines.map((routine) {
          final count = progress.completions[routine.id] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoutineTile(
              routine: routine,
              completionCount: count,
              isMastered: progress.mastered.contains(routine.id),
            ),
          );
        }),
      ],
    );
  }
}

/// Individual routine tile: emoji + title + progress bar + count/star.
class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.routine,
    required this.completionCount,
    required this.isMastered,
  });

  final LifeRoutine routine;
  final int completionCount;
  final bool isMastered;

  @override
  Widget build(BuildContext context) {
    final accentColor = routine.gradient.isNotEmpty
        ? routine.gradient.first
        : const Color(0xFF4CC9F0);
    final progressValue = math.min(completionCount / 3.0, 1.0);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      glowColor: accentColor.withOpacity(0.4),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                routine.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      routine.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      routine.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMastered)
                Text(
                  '⭐',
                  style: TextStyle(
                    fontSize: 20,
                    shadows: <Shadow>[
                      Shadow(
                        color: accentColor.withOpacity(0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Done $completionCount×',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$completionCount/3 for mastery',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter: ring with progress arc for independence score.
class _IndependenceRingPainter extends CustomPainter {
  _IndependenceRingPainter({required this.score});

  final int score;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 60.0;
    const strokeWidth = 8.0;

    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: <Color>[Color(0xFF4CC9F0), Color(0xFF06D6A0)],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100.0) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_IndependenceRingPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
