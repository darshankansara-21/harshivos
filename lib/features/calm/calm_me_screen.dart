import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../../models/regulation_entry.dart';
import '../antistress/toys/lava_blobs.dart';
import '../antistress/toys/sand_fall.dart';
import '../antistress/toys/water_drop.dart';
import '../companion/companion.dart';
import '../lifeskills/avatar/hari_cards.dart';
import '../lifeskills/avatar/pico.dart';
import 'breathing_exercise.dart';
import 'calm_sequence_screen.dart';
import 'firefly_glow.dart';
import 'star_weaver.dart';

/// Calm Me — one-tap emergency regulation. Big, low-pressure mood buttons.
class CalmMeScreen extends StatefulWidget {
  const CalmMeScreen({super.key});

  @override
  State<CalmMeScreen> createState() => _CalmMeScreenState();
}

class _CalmMeScreenState extends State<CalmMeScreen> {
  final CompanionController _companion = CompanionController();

  static const Map<CalmMood, Color> _colors = <CalmMood, Color>{
    CalmMood.overwhelmed: AppColors.moodOverwhelmed,
    CalmMood.frustrated: AppColors.moodFrustrated,
    CalmMood.sad: AppColors.moodSad,
    CalmMood.anxious: AppColors.moodAnxious,
    CalmMood.tired: AppColors.moodTired,
  };

  @override
  void initState() {
    super.initState();
    _companion.setReaction(CompanionReaction.soothing);
  }

  @override
  void dispose() {
    _companion.dispose();
    super.dispose();
  }

  void _openBreathingBubble() {
    _companion.calm();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Breathing Bubble'),
          ),
          body: const BreathingExercise(),
        ),
      ),
    );
  }

  void _openCalmActivity(_CalmActivity activity) {
    _companion.calm();
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(activity.title),
          ),
          body: activity.build(),
        ),
      ),
    );
  }

  // Genuinely calming, no-fail interactive experiences — Calm is a place, not
  // a single screen. Breathing keeps its own dedicated entry above.
  static final List<_CalmActivity> _calmActivities = <_CalmActivity>[
    _CalmActivity('Water Ripples', '💧', const <Color>[
      Color(0x6638B2F9),
      Color(0x6600BBF9),
    ], () => const WaterDropToy()),
    _CalmActivity('Kinetic Sand', '🏜️', const <Color>[
      Color(0x66FFB703),
      Color(0x66FB8500),
    ], () => const SandFallToy()),
    _CalmActivity('Floating Lights', '🫧', const <Color>[
      Color(0x66F15BB5),
      Color(0x669B5DE5),
    ], () => const LavaBlobsToy()),
    _CalmActivity('Star Weaver', '✨', const <Color>[
      Color(0x665C7CFA),
      Color(0x669B5DE5),
    ], () => const StarWeaverToy()),
    _CalmActivity('Firefly Glow', '🪰', const <Color>[
      Color(0x66B6FF9E),
      Color(0x662BD4B4),
    ], () => const FireflyGlowToy()),
  ];

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: IgnorePointer(child: _CalmAtmosphere()),
          ),
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text('How do you feel?',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    const SizedBox(
                      width: 52,
                      height: 52,
                      child: PicoWidget(mood: PicoMood.comforting),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: Text('Try a calming idea with Hari, or tell me how you feel.',
                    style: TextStyle(color: Colors.white70)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: GlassCard(
                  onTap: _openBreathingBubble,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0x6638B2F9), Color(0x662BD4B4)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  child: const Row(
                    children: <Widget>[
                      Text('🌬️', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Breathing Bubble',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'Start',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  itemCount: _calmActivities.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _CalmActivityCard(
                    activity: _calmActivities[i],
                    onTap: () => _openCalmActivity(_calmActivities[i]),
                  ),
                ),
              ),
              SizedBox(
                height: 300,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  itemCount: kCalmingStrategies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => SizedBox(
                    width: 200,
                    child: CalmingStrategyCard(
                      strategy: kCalmingStrategies[i],
                      onTry: _companion.calm,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Text('How do you feel right now?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 130),
                child: Column(
                  children: <Widget>[
                    for (final mood in CalmMood.values) ...<Widget>[
                      _MoodButton(
                        mood: mood,
                        color: _colors[mood]!,
                        onTap: () {
                          _companion.calm();
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CalmSequenceScreen(mood: mood),
                            ),
                          );
                        },
                      ),
                      if (mood != CalmMood.values.last)
                        const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ],
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            width: 150,
            height: 130,
            child: IgnorePointer(
              child: CompanionView(controller: _companion),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.mood, required this.color, required this.onTap});
  final CalmMood mood;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      gradient: LinearGradient(
        colors: <Color>[color.withOpacity(0.55), color.withOpacity(0.20)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      child: Row(
        children: <Widget>[
          Text(mood.emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(width: 18),
          Text(mood.label,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 30),
        ],
      ),
    );
  }
}

/// A single one-tap calming activity that opens full-screen.
class _CalmActivity {
  const _CalmActivity(this.title, this.emoji, this.gradient, this.build);
  final String title;
  final String emoji;
  final List<Color> gradient;
  final Widget Function() build;
}

class _CalmActivityCard extends StatelessWidget {
  const _CalmActivityCard({required this.activity, required this.onTap});
  final _CalmActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: activity.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(activity.emoji, style: const TextStyle(fontSize: 30)),
            Text(activity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// A slow, living backdrop for Calm — soft coloured orbs drifting and breathing
/// so the screen feels like an atmosphere to settle into, not a menu.
class _CalmAtmosphere extends StatefulWidget {
  const _CalmAtmosphere();
  @override
  State<_CalmAtmosphere> createState() => _CalmAtmosphereState();
}

class _CalmAtmosphereState extends State<_CalmAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 28))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          CustomPaint(painter: _CalmPainter(_c.value), size: Size.infinite),
    );
  }
}

class _CalmPainter extends CustomPainter {
  _CalmPainter(this.t);
  final double t;

  static const List<Color> _orbs = <Color>[
    Color(0xFF2BD4B4),
    Color(0xFF38B2F9),
    Color(0xFF6C5CE7),
    Color(0xFF00BBF9),
    Color(0xFF43CEA2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < _orbs.length; i++) {
      final phase = t * 2 * math.pi + i * 1.3;
      final cx = w * (0.2 + 0.6 * (0.5 + 0.5 * math.sin(phase + i)));
      final cy = h * (0.15 + 0.7 * (0.5 + 0.5 * math.cos(phase * 0.8 + i)));
      final r = (w * 0.32) * (0.8 + 0.2 * math.sin(phase * 1.3));
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = _orbs[i].withOpacity(0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
      );
    }
  }

  @override
  bool shouldRepaint(_CalmPainter oldDelegate) => oldDelegate.t != t;
}
