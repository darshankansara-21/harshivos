import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A large colorful segmented wheel with a fixed pointer at the top.
///
/// Flick or drag to spin; it decelerates smoothly and lands anywhere. There is
/// no win/lose and no prizes — just a satisfying spin. Tapping spins it too.
/// Full-bleed: fills its parent completely.
class SpinWheelToy extends StatefulWidget {
  const SpinWheelToy({super.key});

  @override
  State<SpinWheelToy> createState() => _SpinWheelToyState();
}

class _SpinWheelToyState extends State<SpinWheelToy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  static const int _segments = 10;

  double _angle = 0.0;
  double _angularVelocity = 0.0;
  static const double _friction = 0.4;

  Duration _lastTick = Duration.zero;

  Offset _center = Offset.zero;
  double _lastDragAngle = 0.0;
  int _lastSegment = 0;

  static const List<Color> _palette = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF9F45),
    Color(0xFFB983FF),
    Color(0xFF38E54D),
    Color(0xFFFF5DA2),
    Color(0xFF00C2D1),
    Color(0xFFF8B400),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onTick);
    _ticker.repeat();
  }

  void _onTick() {
    final now = _ticker.lastElapsedDuration ?? Duration.zero;
    double dt = (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    if (dt <= 0 || dt > 0.1) dt = 0.016;

    if (_angularVelocity.abs() < 0.0005) return;

    _angle = (_angle + _angularVelocity * dt) % (2 * math.pi);
    if (_angle < 0) _angle += 2 * math.pi;
    _angularVelocity *= math.pow(_friction, dt).toDouble();

    if (_angularVelocity.abs() < 0.02) {
      _angularVelocity = 0.0;
    }

    _maybeTickHaptic();
    setState(() {});
  }

  void _maybeTickHaptic() {
    final seg = ((_angle / (2 * math.pi / _segments)).floor()) % _segments;
    if (seg != _lastSegment) {
      _lastSegment = seg;
      if (_angularVelocity.abs() > 0.6) {
        HapticFeedback.selectionClick();
      }
    }
  }

  double _angleTo(Offset p) => math.atan2(p.dy - _center.dy, p.dx - _center.dx);

  void _onPanStart(DragStartDetails d) {
    _lastDragAngle = _angleTo(d.localPosition);
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final a = _angleTo(d.localPosition);
    double delta = a - _lastDragAngle;
    while (delta > math.pi) delta -= 2 * math.pi;
    while (delta < -math.pi) delta += 2 * math.pi;
    _lastDragAngle = a;
    setState(() {
      _angle = (_angle + delta) % (2 * math.pi);
      if (_angle < 0) _angle += 2 * math.pi;
      _angularVelocity = delta * 60.0;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    final tangential = v.distance / 100.0;
    final sign = _angularVelocity == 0 ? 1.0 : _angularVelocity.sign;
    _angularVelocity += sign * tangential;
    _angularVelocity = _angularVelocity.clamp(-25.0, 25.0);
    HapticFeedback.mediumImpact();
  }

  void _onTap() {
    final sign = _angularVelocity == 0 ? 1.0 : _angularVelocity.sign;
    _angularVelocity += sign * 9.0;
    _angularVelocity = _angularVelocity.clamp(-25.0, 25.0);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _center = Offset(size.width / 2, size.height / 2);
          final radius = math.min(size.width, size.height) * 0.42;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _WheelPainter(
                  angle: _angle,
                  radius: radius,
                  segments: _segments,
                  palette: _palette,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.angle,
    required this.radius,
    required this.segments,
    required this.palette,
  });

  final double angle;
  final double radius;
  final int segments;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi / segments;

    // Outer glow ring.
    final glow = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.drawCircle(center, radius * 1.04, glow);

    // Segments.
    for (int i = 0; i < segments; i++) {
      final start = angle + i * sweep;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = palette[i % palette.length];
      canvas.drawArc(rect, start, sweep, true, paint);

      // Thin separators for crispness.
      final sep = Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.012;
      final edge = center +
          Offset(math.cos(start), math.sin(start)) * radius;
      canvas.drawLine(center, edge, sep);
    }

    // Outer rim.
    final rim = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05;
    canvas.drawCircle(center, radius, rim);

    // Center hub.
    final hubOuter = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFF7FAFC), Color(0xFFA0AEC0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.16));
    canvas.drawCircle(center, radius * 0.16, hubOuter);
    final hubInner = Paint()..color = const Color(0xFF2D3748);
    canvas.drawCircle(center, radius * 0.07, hubInner);

    // Fixed pointer at top.
    final pointerPaint = Paint()..color = const Color(0xFFFFFFFF);
    final pointerShadow = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final tipY = center.dy - radius * 1.02;
    final baseY = center.dy - radius * 0.82;
    final path = Path()
      ..moveTo(center.dx, tipY + radius * 0.0)
      ..lineTo(center.dx - radius * 0.09, baseY)
      ..lineTo(center.dx + radius * 0.09, baseY)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), pointerShadow);
    canvas.drawPath(path, pointerPaint);
    final pointerBorder = Paint()
      ..color = const Color(0xFFE53E3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.02;
    canvas.drawPath(path, pointerBorder);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.angle != angle || old.radius != radius;
}
