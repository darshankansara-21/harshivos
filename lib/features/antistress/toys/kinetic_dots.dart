import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A grid of glowing dots that recoil from your touch.
///
/// Each dot sits at a "home" position. When a finger comes near, dots are
/// pushed radially outward by a soft displacement field; when the finger
/// leaves they spring smoothly back home. Dots tint by how far they have been
/// displaced. A continuous ticker integrates the spring physics for 60fps.
class KineticDotsToy extends StatefulWidget {
  const KineticDotsToy({super.key});

  @override
  State<KineticDotsToy> createState() => _KineticDotsToyState();
}

class _KineticDotsToyState extends State<KineticDotsToy>
    with SingleTickerProviderStateMixin {
  static const double _spacing = 46.0;
  static const double _pushRadius = 130.0;
  static const double _pushStrength = 2600.0;
  static const double _stiffness = 120.0;
  static const double _damping = 14.0;
  static const double _maxStep = 1 / 60;

  late final AnimationController _controller;

  final List<_Dot> _dots = <_Dot>[];
  Size _size = Size.zero;
  Offset? _finger;
  Duration _lastElapsed = Duration.zero;
  int _hapticThrottle = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_onTick);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _ensureDots(Size size) {
    if (size == _size && _dots.isNotEmpty) return;
    _size = size;
    _dots.clear();
    final int cols = math.max(1, (size.width / _spacing).floor());
    final int rows = math.max(1, (size.height / _spacing).floor());
    final double offsetX = (size.width - (cols - 1) * _spacing) / 2;
    final double offsetY = (size.height - (rows - 1) * _spacing) / 2;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final Offset home =
            Offset(offsetX + c * _spacing, offsetY + r * _spacing);
        _dots.add(_Dot(home: home, position: home));
      }
    }
  }

  void _onTick() {
    final Duration elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    // Clamp to avoid instability on big frame gaps.
    dt = math.min(dt, _maxStep * 2);

    final Offset? finger = _finger;
    for (final _Dot dot in _dots) {
      // Spring toward home.
      final Offset toHome = dot.home - dot.position;
      Offset force = toHome * _stiffness - dot.velocity * _damping;

      // Radial push away from the finger.
      if (finger != null) {
        final Offset delta = dot.position - finger;
        final double dist = delta.distance;
        if (dist < _pushRadius && dist > 0.001) {
          final double falloff = 1.0 - (dist / _pushRadius);
          final Offset dir = delta / dist;
          force += dir * (_pushStrength * falloff * falloff);
        }
      }

      dot.velocity += force * dt;
      dot.position += dot.velocity * dt;
    }

    if (mounted) setState(() {});
  }

  void _setFinger(Offset? p) {
    _finger = p;
    if (p != null) {
      _hapticThrottle = (_hapticThrottle + 1) % 6;
      if (_hapticThrottle == 0) {
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureDots(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) {
            HapticFeedback.lightImpact();
            _setFinger(d.localPosition);
          },
          onPanUpdate: (DragUpdateDetails d) => _setFinger(d.localPosition),
          onPanEnd: (DragEndDetails d) => _setFinger(null),
          onPanCancel: () => _setFinger(null),
          onTapDown: (TapDownDetails d) {
            HapticFeedback.lightImpact();
            _setFinger(d.localPosition);
          },
          onTapUp: (TapUpDetails d) => _setFinger(null),
          child: CustomPaint(
            painter: _DotsPainter(dots: _dots),
            size: size,
          ),
        );
      },
    );
  }
}

class _Dot {
  _Dot({required this.home, required this.position})
      : velocity = Offset.zero;

  final Offset home;
  Offset position;
  Offset velocity;
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.dots});

  final List<_Dot> dots;

  static const Color _calmA = Color(0xFF2DD4BF);
  static const Color _calmB = Color(0xFFA78BFA);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Paint bg = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: <Color>[Color(0xFF141A2E), Color(0xFF0A0E1C)],
      ).createShader(bounds);
    canvas.drawRect(bounds, bg);

    final Paint glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final Paint core = Paint();

    for (final _Dot dot in dots) {
      final double disp = (dot.position - dot.home).distance;
      final double t = (disp / 90.0).clamp(0.0, 1.0);
      final Color color = Color.lerp(_calmA, _calmB, t)!;
      final double radius = 5.0 + t * 4.0;

      glow.color = color.withOpacity(0.35 + 0.4 * t);
      canvas.drawCircle(dot.position, radius * 2.2, glow);

      core.color = color.withOpacity(0.95);
      canvas.drawCircle(dot.position, radius, core);
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) => true;
}
