import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A living spiral galaxy of twinkling stars orbiting a luminous core.
///
/// Hundreds of star particles ride Keplerian-style orbits arranged into spiral
/// arms. Touching opens a gravity well that bends and slings the stars around
/// the finger, spawning sparkles; releasing lets them settle back into the
/// spiral. Deep-space gradient, nebula tints, additive star glow.
class ParticleGalaxyExperience extends StatefulWidget {
  const ParticleGalaxyExperience({super.key});

  @override
  State<ParticleGalaxyExperience> createState() =>
      _ParticleGalaxyExperienceState();
}

class _ParticleGalaxyExperienceState extends State<ParticleGalaxyExperience>
    with SingleTickerProviderStateMixin {
  static const double _dt = 1 / 60;
  static const int _count = 320;
  static const int _arms = 4;
  static const int _maxSparkles = 160;

  late final AnimationController _controller;
  final math.Random _rng = math.Random(42);
  final List<_Star> _stars = <_Star>[];
  final List<_Sparkle> _sparkles = <_Sparkle>[];

  Size _size = Size.zero;
  Offset _center = Offset.zero;
  bool _seeded = false;
  double _time = 0;
  int _frame = 0;

  Offset? _touch;
  Duration _lastHaptic = Duration.zero;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_tick);
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  void _seed(Size size) {
    _stars.clear();
    _sparkles.clear();
    _center = Offset(size.width / 2, size.height / 2);
    final double maxR = math.min(size.width, size.height) * 0.46;

    for (int i = 0; i < _count; i++) {
      final int arm = i % _arms;
      // Bias toward outer regions for a fuller disc.
      final double rNorm = math.sqrt(_rng.nextDouble());
      final double radius = 26 + rNorm * maxR;
      // Logarithmic spiral arm angle + scatter.
      final double armBase = (arm / _arms) * math.pi * 2;
      final double swirl = radius * 0.012;
      final double scatter = (_rng.nextDouble() - 0.5) * 0.55;
      final double angle = armBase + swirl + scatter;

      final Offset pos = _center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius);

      final double hue =
          (210 + arm * 14 + rNorm * 70 + _rng.nextDouble() * 30) % 360;

      _stars.add(
        _Star(
          position: pos,
          velocity: Offset.zero,
          hue: hue,
          size: 0.7 + _rng.nextDouble() * 1.9,
          twinklePhase: _rng.nextDouble() * math.pi * 2,
          twinkleSpeed: 1.2 + _rng.nextDouble() * 2.6,
        ),
      );
    }
    _seeded = true;
  }

  double _orbitalSpeed(double r) {
    // Gentle, near-flat rotation curve for a pleasing swirl.
    return 130.0 / math.sqrt(r + 60.0) * math.sqrt(r);
  }

  void _tick() {
    _elapsed += Duration(microseconds: (_dt * 1e6).round());
    if (!_seeded || _size.isEmpty) {
      return;
    }
    _time += _dt;
    _frame++;

    final Offset center = _center;
    final Offset? touch = _touch;

    for (final _Star s in _stars) {
      final Offset toCenter = center - s.position;
      final double r = toCenter.distance.clamp(8.0, 100000.0);
      final Offset radial = toCenter / r;
      final Offset tangent = Offset(-radial.dy, radial.dx);

      // Target orbital velocity (restoring toward the spiral disc).
      final double v = _orbitalSpeed(r);
      Offset target = tangent * v;
      // Slight inward pull to hold the disc shape.
      target += radial * (math.max(0, r - 28) * 0.18);

      // Restore toward orbit; looser while a gravity well is active.
      final double restore = touch == null ? 0.10 : 0.045;
      s.velocity = Offset.lerp(s.velocity, target, restore)!;

      // Gravity well at the finger.
      if (touch != null) {
        final Offset g = touch - s.position;
        final double d = g.distance.clamp(14.0, 100000.0);
        final Offset gn = g / d;
        final double strength = 90000.0 / (d * d + 1400.0);
        s.velocity += gn * strength * _dt * 60.0;
      }

      s.position += s.velocity * _dt;
      s.twinklePhase += s.twinkleSpeed * _dt;
    }

    // Spawn sparkles around the finger.
    if (touch != null && _frame % 2 == 0) {
      for (int k = 0; k < 3; k++) {
        if (_sparkles.length >= _maxSparkles) {
          break;
        }
        final double a = _rng.nextDouble() * math.pi * 2;
        final double sp = 30 + _rng.nextDouble() * 140;
        _sparkles.add(
          _Sparkle(
            position: touch +
                Offset(
                  (_rng.nextDouble() - 0.5) * 24,
                  (_rng.nextDouble() - 0.5) * 24,
                ),
            velocity: Offset(math.cos(a), math.sin(a)) * sp,
            hue: (40 + _rng.nextDouble() * 60) % 360,
            life: 1.0,
          ),
        );
      }
    }

    for (int i = _sparkles.length - 1; i >= 0; i--) {
      final _Sparkle sp = _sparkles[i];
      sp.position += sp.velocity * _dt;
      sp.velocity = sp.velocity * 0.94;
      sp.life -= _dt * 1.4;
      if (sp.life <= 0) {
        _sparkles.removeAt(i);
      }
    }
  }

  void _maybeHaptic() {
    if (_elapsed - _lastHaptic > const Duration(milliseconds: 120)) {
      _lastHaptic = _elapsed;
      HapticFeedback.selectionClick();
    }
  }

  void _onPanStart(DragStartDetails d) {
    _touch = d.localPosition;
    _maybeHaptic();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _touch = d.localPosition;
  }

  void _onPanEnd(DragEndDetails d) {
    _touch = null;
  }

  void _onTapDown(TapDownDetails d) {
    _touch = d.localPosition;
    _maybeHaptic();
  }

  void _onTapUp(TapUpDetails d) {
    _touch = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        if (!_seeded || _size != size) {
          _size = size;
          _seed(size);
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _GalaxyPainter(
                  stars: _stars,
                  sparkles: _sparkles,
                  center: _center,
                  touch: _touch,
                  time: _time,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Star {
  _Star({
    required this.position,
    required this.velocity,
    required this.hue,
    required this.size,
    required this.twinklePhase,
    required this.twinkleSpeed,
  });

  Offset position;
  Offset velocity;
  double hue;
  final double size;
  double twinklePhase;
  final double twinkleSpeed;
}

class _Sparkle {
  _Sparkle({
    required this.position,
    required this.velocity,
    required this.hue,
    required this.life,
  });

  Offset position;
  Offset velocity;
  final double hue;
  double life;
}

class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter({
    required this.stars,
    required this.sparkles,
    required this.center,
    required this.touch,
    required this.time,
  });

  final List<_Star> stars;
  final List<_Sparkle> sparkles;
  final Offset center;
  final Offset? touch;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Deep-space background gradient.
    final Paint bg = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: <Color>[
          Color(0xFF131233),
          Color(0xFF0A0820),
          Color(0xFF03020A),
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Nebula tints (soft additive clouds).
    final Paint nebula = Paint()
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    nebula.color = const Color(0xFF3A2A6E).withOpacity(0.30);
    canvas.drawCircle(
      center + Offset(-size.width * 0.12, -size.height * 0.10),
      size.shortestSide * 0.42,
      nebula,
    );
    nebula.color = const Color(0xFF0E4D6B).withOpacity(0.26);
    canvas.drawCircle(
      center + Offset(size.width * 0.16, size.height * 0.14),
      size.shortestSide * 0.38,
      nebula,
    );

    // Galactic core glow.
    final Paint corePaint = Paint()
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    corePaint.color = const Color(0xFFFFE6B0).withOpacity(0.30);
    canvas.drawCircle(center, size.shortestSide * 0.10, corePaint);
    corePaint
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = const Color(0xFFFFF3D6).withOpacity(0.55);
    canvas.drawCircle(center, size.shortestSide * 0.045, corePaint);

    // Stars.
    final Paint glow = Paint()..blendMode = BlendMode.plus;
    for (final _Star s in stars) {
      final double tw = 0.55 + 0.45 * math.sin(s.twinklePhase);
      final Color c = HSVColor.fromAHSV(1.0, s.hue, 0.55, 1.0).toColor();
      final double radius = s.size;

      // Halo.
      glow
        ..color = c.withOpacity(0.10 * tw)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 3.2);
      canvas.drawCircle(s.position, radius * 3.0, glow);

      // Core.
      glow
        ..color = Color.lerp(c, Colors.white, 0.6)!.withOpacity(0.95 * tw)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.7);
      canvas.drawCircle(s.position, radius, glow);
    }

    // Sparkles.
    final Paint sparkPaint = Paint()..blendMode = BlendMode.plus;
    for (final _Sparkle sp in sparkles) {
      final double life = sp.life.clamp(0.0, 1.0);
      final Color c = HSVColor.fromAHSV(1.0, sp.hue, 0.5, 1.0).toColor();
      sparkPaint
        ..color = Color.lerp(c, Colors.white, 0.5)!.withOpacity(life)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(sp.position, 1.4 + life * 1.8, sparkPaint);
    }

    // Gravity-well shimmer at the finger.
    final Offset? t = touch;
    if (t != null) {
      final Paint well = Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
        ..color = const Color(0xFF8FB8FF).withOpacity(0.22);
      canvas.drawCircle(t, 46, well);
      well
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = Colors.white.withOpacity(0.30);
      canvas.drawCircle(t, 14, well);
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) => true;
}
