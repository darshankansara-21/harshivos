import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A glowing 3-arm fidget spinner that spins with momentum and friction decay.
///
/// Flick it (pan with velocity) to spin; it keeps spinning and gradually
/// slows down via a repeating ticker that integrates angular velocity. A tap
/// gives it a gentle nudge. Full-bleed: fills its parent completely.
class FidgetSpinnerToy extends StatefulWidget {
  const FidgetSpinnerToy({super.key});

  @override
  State<FidgetSpinnerToy> createState() => _FidgetSpinnerToyState();
}

class _FidgetSpinnerToyState extends State<FidgetSpinnerToy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  // Rotation state (radians) and angular velocity (radians/sec).
  double _angle = 0.0;
  double _angularVelocity = 0.0;

  // Friction: fraction of velocity retained per second.
  static const double _friction = 0.55;

  // Tracks elapsed time between ticker frames.
  Duration _lastTick = Duration.zero;

  // Drag tracking for flick velocity.
  Offset _center = Offset.zero;
  double _lastDragAngle = 0.0;

  // Haptic cadence: pulse when a new arm passes the top marker.
  int _lastArmIndex = 0;

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

    // Integrate angle, apply exponential friction decay.
    _angle += _angularVelocity * dt;
    _angularVelocity *= math.pow(_friction, dt).toDouble();

    if (_angularVelocity.abs() < 0.02) {
      _angularVelocity = 0.0;
    }

    _maybeHaptic();
    setState(() {});
  }

  void _maybeHaptic() {
    // 3 arms => an arm crosses top every 120 degrees.
    final idx = ((_angle / (2 * math.pi / 3)).floor()) % 3;
    if (idx != _lastArmIndex && _angularVelocity.abs() > 1.2) {
      _lastArmIndex = idx;
      HapticFeedback.selectionClick();
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
    // Normalize to [-pi, pi].
    while (delta > math.pi) delta -= 2 * math.pi;
    while (delta < -math.pi) delta += 2 * math.pi;
    _lastDragAngle = a;
    setState(() {
      _angle += delta;
      // Blend toward a velocity estimate for a responsive feel.
      _angularVelocity = delta * 60.0;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    // Convert pan velocity into angular impulse around the center.
    final v = d.velocity.pixelsPerSecond;
    final tangential = v.distance / 90.0;
    final sign = _angularVelocity == 0 ? 1.0 : _angularVelocity.sign;
    _angularVelocity += sign * tangential;
    _angularVelocity = _angularVelocity.clamp(-40.0, 40.0);
    HapticFeedback.mediumImpact();
  }

  void _onTap() {
    final sign = _angularVelocity == 0 ? 1.0 : _angularVelocity.sign;
    _angularVelocity += sign * 6.0;
    _angularVelocity = _angularVelocity.clamp(-40.0, 40.0);
    HapticFeedback.lightImpact();
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141E30), Color(0xFF243B55)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _center = Offset(size.width / 2, size.height / 2);
          final radius = math.min(size.width, size.height) * 0.36;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _SpinnerPainter(angle: _angle, radius: radius),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({required this.angle, required this.radius});

  final double angle;
  final double radius;

  static const List<Color> _armColors = [
    Color(0xFF4FD1C5),
    Color(0xFFF687B3),
    Color(0xFFFBD38D),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final weightR = radius * 0.34;
    final armWidth = radius * 0.42;

    for (int i = 0; i < 3; i++) {
      final a = angle + i * (2 * math.pi / 3);
      final armCenter = center + Offset(math.cos(a), math.sin(a)) * radius;
      final color = _armColors[i];

      // Soft glow halo behind each weighted arm.
      final glow = Paint()
        ..color = color.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawCircle(armCenter, weightR * 1.25, glow);

      // Arm connector from center to weight.
      final arm = Paint()
        ..color = color.withOpacity(0.85)
        ..strokeWidth = armWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, armCenter, arm);

      // Weighted ring (bearing housing) at arm tip.
      final ringFill = Paint()..color = color;
      canvas.drawCircle(armCenter, weightR, ringFill);
      final ringInner = Paint()..color = const Color(0xFF1A2030);
      canvas.drawCircle(armCenter, weightR * 0.5, ringInner);
      final ringHighlight = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = weightR * 0.12;
      canvas.drawCircle(armCenter, weightR * 0.72, ringHighlight);
    }

    // Center bearing.
    final bearingGlow = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius * 0.46, bearingGlow);

    final bearingOuter = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFEDF2F7), Color(0xFF9AA5B1)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.4));
    canvas.drawCircle(center, radius * 0.4, bearingOuter);

    final bearingInner = Paint()..color = const Color(0xFF2D3748);
    canvas.drawCircle(center, radius * 0.2, bearingInner);

    final bearingDot = Paint()..color = Colors.white.withOpacity(0.8);
    canvas.drawCircle(center, radius * 0.06, bearingDot);
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) =>
      old.angle != angle || old.radius != radius;
}
