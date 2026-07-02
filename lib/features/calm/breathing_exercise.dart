import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A slow, looping breathing guide built for Harshiv:
/// visual-first (never relies on sound), high-contrast, and predictable so he
/// can *anticipate* each phase. The orb expands on inhale, holds, contracts on
/// exhale; a progress arc and breath rings show where we are in the cycle.
class BreathingExercise extends StatefulWidget {
  const BreathingExercise({super.key});

  @override
  State<BreathingExercise> createState() => _BreathingExerciseState();
}

class _BreathingExerciseState extends State<BreathingExercise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // 4s in, 2s hold, 4s out, 1s hold = 11s cycle.
  static const double _inEnd = 4 / 11;
  static const double _holdTopEnd = 6 / 11;
  static const double _outEnd = 10 / 11;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({double scale, String label, String emoji, Color color}) _phase(double t) {
    if (t < _inEnd) {
      final p = Curves.easeInOut.transform(t / _inEnd);
      return (
        scale: 0.5 + 0.5 * p,
        label: 'Breathe in',
        emoji: '🌬️',
        color: const Color(0xFF89F7FE),
      );
    } else if (t < _holdTopEnd) {
      return (
        scale: 1.0,
        label: 'Hold',
        emoji: '✨',
        color: const Color(0xFFB388FF),
      );
    } else if (t < _outEnd) {
      final p =
          Curves.easeInOut.transform((t - _holdTopEnd) / (_outEnd - _holdTopEnd));
      return (
        scale: 1.0 - 0.5 * p,
        label: 'Breathe out',
        emoji: '😌',
        color: const Color(0xFF66A6FF),
      );
    }
    return (
      scale: 0.5,
      label: 'Rest',
      emoji: '💤',
      color: const Color(0xFF7FD8BE),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final phase = _phase(t);
          final media = MediaQuery.of(context).size;
          final base = math.min(media.width, media.height);
          final orb = (base * 0.42).clamp(180.0, 360.0);

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: orb * 1.5,
                  height: orb * 1.5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      // Expanding breath rings ripple outward continuously.
                      for (int i = 0; i < 3; i++)
                        _BreathRing(
                          progress: (t + i / 3) % 1.0,
                          maxSize: orb * 1.5,
                          color: phase.color,
                        ),
                      // Phase-progress arc — lets Harshiv anticipate the change.
                      SizedBox(
                        width: orb * 1.18,
                        height: orb * 1.18,
                        child: CustomPaint(
                          painter: _ProgressArcPainter(
                            progress: t,
                            color: phase.color,
                          ),
                        ),
                      ),
                      // The breathing orb.
                      Transform.scale(
                        scale: phase.scale,
                        child: Container(
                          width: orb,
                          height: orb,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                Colors.white,
                                phase.color,
                                phase.color.withOpacity(0.7),
                              ],
                              stops: const <double>[0.0, 0.55, 1.0],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: phase.color.withOpacity(0.6),
                                blurRadius: 50 + 24 * math.sin(t * math.pi * 2),
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              phase.emoji,
                              style: TextStyle(fontSize: orb * 0.28),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                // Big, high-contrast prompt (left-eye coloboma friendly).
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    phase.label,
                    key: ValueKey<String>(phase.label),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A single ring that grows and fades outward — a silent visual "pulse".
class _BreathRing extends StatelessWidget {
  const _BreathRing({
    required this.progress,
    required this.maxSize,
    required this.color,
  });

  final double progress; // 0..1
  final double maxSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = maxSize * (0.5 + 0.5 * progress);
    final opacity = (1.0 - progress) * 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(opacity.clamp(0.0, 1.0)),
          width: 2,
        ),
      ),
    );
  }
}

/// Draws a circular progress arc around the orb showing cycle position.
class _ProgressArcPainter extends CustomPainter {
  _ProgressArcPainter({required this.progress, required this.color});

  final double progress; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white.withOpacity(0.12);
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = color.withOpacity(0.9);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ProgressArcPainter old) =>
      old.progress != progress || old.color != color;
}
