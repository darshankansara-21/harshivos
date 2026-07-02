import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pendulum waves: a calming kinetic-art fidget toy.
///
/// A row of pendulums with slightly increasing lengths swing together. Because
/// each has a different period they drift in and out of phase, painting endless
/// travelling-wave patterns. Tap anywhere to re-sync them all to the same angle.
class PendulumWavesToy extends StatefulWidget {
  const PendulumWavesToy({super.key});

  @override
  State<PendulumWavesToy> createState() => _PendulumWavesToyState();
}

class _PendulumWavesToyState extends State<PendulumWavesToy>
    with SingleTickerProviderStateMixin {
  static const int _count = 15;
  static const double _startAngle = 0.6; // radians

  late final AnimationController _ticker;
  Duration _lastTick = Duration.zero;

  // Each pendulum's angle, angular velocity and natural frequency.
  final List<double> _angle = List<double>.filled(_count, _startAngle);
  final List<double> _vel = List<double>.filled(_count, 0);
  final List<double> _omega = List<double>.filled(_count, 0);

  @override
  void initState() {
    super.initState();
    _configureFrequencies();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onTick);
    _ticker.forward();
  }

  @override
  void dispose() {
    _ticker
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  /// Classic pendulum-wave tuning: pendulum i completes (base + i) oscillations
  /// in a fixed cycle, so they all realign periodically.
  void _configureFrequencies() {
    const double cycleSeconds = 30.0;
    const int baseOscillations = 20;
    for (int i = 0; i < _count; i++) {
      final double oscillations = (baseOscillations + i).toDouble();
      _omega[i] = 2 * math.pi * oscillations / cycleSeconds;
    }
  }

  void _onTick() {
    final Duration now = _ticker.lastElapsedDuration ?? Duration.zero;
    double dt = (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    if (dt <= 0) return;
    dt = dt.clamp(0.0, 1 / 60);

    // Simple harmonic motion: a'' = -omega^2 * a (small-angle pendulum).
    for (int i = 0; i < _count; i++) {
      final double accel = -_omega[i] * _omega[i] * _angle[i];
      _vel[i] += accel * dt;
      _angle[i] += _vel[i] * dt;
    }

    if (mounted) setState(() {});
  }

  void _reset() {
    for (int i = 0; i < _count; i++) {
      _angle[i] = _startAngle;
      _vel[i] = 0;
    }
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.1,
            colors: <Color>[Color(0xFF0E1430), Color(0xFF05060F)],
          ),
        ),
        child: CustomPaint(
          painter: _WavesPainter(angles: _angle),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  _WavesPainter({required this.angles});

  final List<double> angles;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = angles.length;
    if (n == 0) return;

    final double pivotY = size.height * 0.12;
    final double maxLen = size.height * 0.78;
    final double minLen = maxLen * 0.62;
    final double margin = size.width * 0.10;
    final double span = size.width - margin * 2;

    final Paint string = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.0;

    for (int i = 0; i < n; i++) {
      final double fx = n == 1 ? 0.5 : i / (n - 1);
      final double pivotX = margin + span * fx;
      // Longest pendulum first so lengths increase smoothly across the row.
      final double len = maxLen - (maxLen - minLen) * (i / (n - 1));
      final double a = angles[i];

      final Offset pivot = Offset(pivotX, pivotY);
      final Offset bob = Offset(
        pivotX + math.sin(a) * len,
        pivotY + math.cos(a) * len,
      );

      canvas.drawLine(pivot, bob, string);

      final Color hue =
          HSVColor.fromAHSV(1.0, (200 + i * 11) % 360, 0.55, 1.0).toColor();

      // Glow.
      canvas.drawCircle(
        bob,
        18,
        Paint()
          ..color = hue.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      // Bob.
      canvas.drawCircle(
        bob,
        9,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[Colors.white, hue],
            stops: const <double>[0.0, 1.0],
          ).createShader(Rect.fromCircle(center: bob, radius: 9)),
      );
      // Pivot dot.
      canvas.drawCircle(pivot, 2.5, Paint()..color = Colors.white.withOpacity(0.4));
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) => true;
}
