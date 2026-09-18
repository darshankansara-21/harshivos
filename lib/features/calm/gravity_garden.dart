import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gravity Garden — a slow, no-fail *orbit* calm experience.
///
/// Soft planets drift on slow circular paths around a warm sun, each leaving a
/// faint trailing arc. Touching near a planet gently draws its orbit toward the
/// fingertip, letting a child widen or tighten the whole quiet dance. There is
/// nothing to win and nothing to lose — only slow light to conduct.
class GravityGardenToy extends StatefulWidget {
  const GravityGardenToy({super.key});

  @override
  State<GravityGardenToy> createState() => _GravityGardenToyState();
}

class _GravityGardenToyState extends State<GravityGardenToy>
    with SingleTickerProviderStateMixin {
  final math.Random _rng = math.Random();
  late final AnimationController _controller;
  final List<_Planet> _planets = <_Planet>[];
  double _seconds = 0;
  double _last = 0;

  static const List<Color> _hues = <Color>[
    Color(0xFF8FD0FF),
    Color(0xFFB6A8FF),
    Color(0xFFFFB4D6),
    Color(0xFF9BE7C4),
    Color(0xFFFFD59E),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(_tick);
    _controller.repeat();
    for (int i = 0; i < 5; i++) {
      final double radius = 0.16 + i * 0.11;
      _planets.add(_Planet(
        radius: radius,
        targetRadius: radius,
        angle: _rng.nextDouble() * math.pi * 2,
        speed: (0.16 + _rng.nextDouble() * 0.14) * (i.isEven ? 1 : -1),
        size: 8.0 + _rng.nextDouble() * 7,
        color: _hues[i % _hues.length],
      ));
    }
  }

  void _tick() {
    final double now = _controller.lastElapsedDuration == null
        ? _seconds
        : _controller.lastElapsedDuration!.inMicroseconds / 1e6;
    final double dt = (now - _last).clamp(0.0, 0.05);
    _last = now;
    _seconds = now;
    for (final _Planet p in _planets) {
      p.angle += p.speed * dt;
      p.radius += (p.targetRadius - p.radius) * (dt * 2.2);
      p.trail.add(p.angle);
      if (p.trail.length > 26) p.trail.removeAt(0);
    }
    if (mounted) setState(() {});
  }

  void _nudge(Offset local, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double minDim = math.min(size.width, size.height);
    final double touchR = ((local - center).distance / minDim).clamp(0.08, 0.46);
    _Planet? nearest;
    double best = double.infinity;
    for (final _Planet p in _planets) {
      final Offset pos = _posOf(p, size);
      final double d = (pos - local).distance;
      if (d < best) {
        best = d;
        nearest = p;
      }
    }
    if (nearest != null && best < 110) {
      nearest.targetRadius = touchR;
      HapticFeedback.selectionClick();
    }
  }

  Offset _posOf(_Planet p, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double minDim = math.min(size.width, size.height);
    return center +
        Offset(math.cos(p.angle), math.sin(p.angle)) * (p.radius * minDim);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final Size size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => _nudge(d.localPosition, size),
          onPanStart: (DragStartDetails d) => _nudge(d.localPosition, size),
          onPanUpdate: (DragUpdateDetails d) => _nudge(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _GravityPainter(
              planets: _planets,
              seconds: _seconds,
              posOf: (p) => _posOf(p, size),
            ),
          ),
        );
      },
    );
  }
}

class _Planet {
  _Planet({
    required this.radius,
    required this.targetRadius,
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
  double radius;
  double targetRadius;
  double angle;
  final double speed;
  final double size;
  final Color color;
  final List<double> trail = <double>[];
}

class _GravityPainter extends CustomPainter {
  _GravityPainter({
    required this.planets,
    required this.seconds,
    required this.posOf,
  });

  final List<_Planet> planets;
  final double seconds;
  final Offset Function(_Planet) posOf;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0E1330), Color(0xFF241A3E)],
        ).createShader(rect),
    );

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double minDim = math.min(size.width, size.height);
    final double sunPulse = 0.85 + 0.15 * math.sin(seconds * 1.1);

    // Sun.
    canvas.drawCircle(
      center,
      46 * sunPulse,
      Paint()
        ..color = const Color(0xFFFFC978).withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    canvas.drawCircle(
        center, 18, Paint()..color = const Color(0xFFFFE0A6).withOpacity(0.95));

    for (final _Planet p in planets) {
      // Faint orbit ring.
      canvas.drawCircle(
        center,
        p.radius * minDim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withOpacity(0.05),
      );
      // Trailing arc.
      for (int i = 0; i < p.trail.length; i++) {
        final double a = p.trail[i];
        final Offset tp = center +
            Offset(math.cos(a), math.sin(a)) * (p.radius * minDim);
        final double f = i / p.trail.length;
        canvas.drawCircle(
          tp,
          p.size * 0.5 * f,
          Paint()..color = p.color.withOpacity(0.16 * f),
        );
      }
      final Offset pos = posOf(p);
      canvas.drawCircle(
        pos,
        p.size * 2.6,
        Paint()
          ..color = p.color.withOpacity(0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(pos, p.size, Paint()..color = p.color.withOpacity(0.95));
    }
  }

  @override
  bool shouldRepaint(covariant _GravityPainter old) => true;
}
