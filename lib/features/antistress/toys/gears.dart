import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Several interlocking mechanical gears that mesh and rotate together.
///
/// Drag any gear to rotate it; the meshed gears rotate accordingly (opposite
/// direction, with speed scaled by the teeth ratio). There is spin momentum
/// and gentle friction. Full-bleed: fills its parent completely.
class GearsToy extends StatefulWidget {
  const GearsToy({super.key});

  @override
  State<GearsToy> createState() => _GearsToyState();
}

class _GearSpec {
  _GearSpec({
    required this.relCenter,
    required this.radiusFactor,
    required this.teeth,
    required this.color,
    required this.direction,
    required this.phase,
  });

  /// Center as a fraction of the smaller layout dimension, relative to canvas
  /// center (so layout scales with available space).
  final Offset relCenter;
  final double radiusFactor;
  final int teeth;
  final Color color;

  /// +1 or -1; the master gear is +1 and meshed gears alternate.
  final double direction;

  /// Static rotational offset so teeth interlock correctly.
  final double phase;
}

class _GearsToyState extends State<GearsToy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  // Master rotation (radians) drives the whole train; angular velocity decays.
  double _masterAngle = 0.0;
  double _angularVelocity = 0.0;
  static const double _friction = 0.5;

  Duration _lastTick = Duration.zero;

  Offset _center = Offset.zero;
  double _unit = 1.0; // pixels per layout unit
  double _lastDragAngle = 0.0;
  int _draggingGear = -1;
  int _lastToothTick = 0;

  // Gear train. The first gear is the master (largest); meshed gears alternate
  // spin direction. Speeds are derived from teeth ratios at paint time.
  static final List<_GearSpec> _gears = [
    _GearSpec(
      relCenter: const Offset(-0.30, 0.02),
      radiusFactor: 0.30,
      teeth: 18,
      color: const Color(0xFF8D9AAE),
      direction: 1.0,
      phase: 0.0,
    ),
    _GearSpec(
      relCenter: const Offset(0.14, -0.18),
      radiusFactor: 0.22,
      teeth: 13,
      color: const Color(0xFFB0795A),
      direction: -1.0,
      phase: math.pi / 13,
    ),
    _GearSpec(
      relCenter: const Offset(0.34, 0.22),
      radiusFactor: 0.18,
      teeth: 11,
      color: const Color(0xFF6E8298),
      direction: 1.0,
      phase: 0.0,
    ),
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

    _masterAngle += _angularVelocity * dt;
    _angularVelocity *= math.pow(_friction, dt).toDouble();
    if (_angularVelocity.abs() < 0.02) {
      _angularVelocity = 0.0;
    }

    _maybeHaptic();
    setState(() {});
  }

  void _maybeHaptic() {
    final master = _gears.first;
    final toothAngle = 2 * math.pi / master.teeth;
    final idx = (_masterAngle / toothAngle).floor();
    if (idx != _lastToothTick && _angularVelocity.abs() > 0.8) {
      _lastToothTick = idx;
      HapticFeedback.selectionClick();
    }
  }

  Offset _gearCenter(_GearSpec g) =>
      _center + Offset(g.relCenter.dx * _unit, g.relCenter.dy * _unit);

  /// Master-equivalent angle for a given gear (teeth ratio + direction).
  double _gearAngle(_GearSpec g) {
    final master = _gears.first;
    return g.phase +
        g.direction * _masterAngle * (master.teeth / g.teeth);
  }

  int _hitGear(Offset p) {
    for (int i = 0; i < _gears.length; i++) {
      final g = _gears[i];
      final c = _gearCenter(g);
      final r = g.radiusFactor * _unit;
      if ((p - c).distance <= r * 1.05) return i;
    }
    return -1;
  }

  double _angleAround(Offset center, Offset p) =>
      math.atan2(p.dy - center.dy, p.dx - center.dx);

  void _onPanStart(DragStartDetails d) {
    _draggingGear = _hitGear(d.localPosition);
    if (_draggingGear < 0) return;
    final c = _gearCenter(_gears[_draggingGear]);
    _lastDragAngle = _angleAround(c, d.localPosition);
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_draggingGear < 0) return;
    final g = _gears[_draggingGear];
    final c = _gearCenter(g);
    final a = _angleAround(c, d.localPosition);
    double delta = a - _lastDragAngle;
    while (delta > math.pi) delta -= 2 * math.pi;
    while (delta < -math.pi) delta += 2 * math.pi;
    _lastDragAngle = a;

    // Convert this gear's local rotation into master-equivalent rotation.
    final master = _gears.first;
    final masterDelta =
        delta * g.direction * (g.teeth / master.teeth);
    setState(() {
      _masterAngle += masterDelta;
      _angularVelocity = masterDelta * 60.0;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_draggingGear < 0) return;
    final g = _gears[_draggingGear];
    final master = _gears.first;
    final v = d.velocity.pixelsPerSecond;
    final r = math.max(g.radiusFactor * _unit, 1.0);
    // Approximate angular speed from tangential velocity magnitude.
    final localOmega = (v.distance / r) * 0.5;
    final sign = _angularVelocity == 0 ? 1.0 : _angularVelocity.sign;
    final masterOmega =
        sign * localOmega * g.direction.abs() * (g.teeth / master.teeth);
    _angularVelocity += masterOmega;
    _angularVelocity = _angularVelocity.clamp(-30.0, 30.0);
    _draggingGear = -1;
    HapticFeedback.mediumImpact();
  }

  void _onTap() {
    final sign = _angularVelocity == 0 ? 1.0 : _angularVelocity.sign;
    _angularVelocity += sign * 5.0;
    _angularVelocity = _angularVelocity.clamp(-30.0, 30.0);
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
          colors: [Color(0xFF2B2D33), Color(0xFF3C4048)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _center = Offset(size.width / 2, size.height / 2);
          _unit = math.min(size.width, size.height);

          final specs = _gears
              .map((g) => _PaintGear(
                    center: _gearCenter(g),
                    radius: g.radiusFactor * _unit,
                    teeth: g.teeth,
                    angle: _gearAngle(g),
                    color: g.color,
                  ))
              .toList();

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _GearsPainter(gears: specs),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PaintGear {
  _PaintGear({
    required this.center,
    required this.radius,
    required this.teeth,
    required this.angle,
    required this.color,
  });

  final Offset center;
  final double radius;
  final int teeth;
  final double angle;
  final Color color;
}

class _GearsPainter extends CustomPainter {
  _GearsPainter({required this.gears});

  final List<_PaintGear> gears;

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in gears) {
      _drawGear(canvas, g);
    }
  }

  void _drawGear(Canvas canvas, _PaintGear g) {
    final center = g.center;
    final r = g.radius;
    final toothDepth = r * 0.16;
    final rootR = r - toothDepth;

    // Soft drop shadow for subtle depth.
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center.translate(0, 4), rootR, shadow);

    // Build the toothed outline.
    final path = Path();
    final n = g.teeth;
    final toothAngle = 2 * math.pi / n;
    for (int i = 0; i < n; i++) {
      final base = g.angle + i * toothAngle;
      // Each tooth: root -> rise -> tip -> tip -> fall -> root.
      final a0 = base;
      final a1 = base + toothAngle * 0.25;
      final a2 = base + toothAngle * 0.5;
      final a3 = base + toothAngle * 0.75;

      final pRoot0 = center + Offset(math.cos(a0), math.sin(a0)) * rootR;
      final pTip0 = center + Offset(math.cos(a1), math.sin(a1)) * r;
      final pTip1 = center + Offset(math.cos(a2), math.sin(a2)) * r;
      final pRoot1 = center + Offset(math.cos(a3), math.sin(a3)) * rootR;

      if (i == 0) {
        path.moveTo(pRoot0.dx, pRoot0.dy);
      } else {
        path.lineTo(pRoot0.dx, pRoot0.dy);
      }
      path.lineTo(pTip0.dx, pTip0.dy);
      path.lineTo(pTip1.dx, pTip1.dy);
      path.lineTo(pRoot1.dx, pRoot1.dy);
    }
    path.close();

    // Metallic radial body shading.
    final body = Paint()
      ..shader = RadialGradient(
        colors: [
          _lighten(g.color, 0.22),
          g.color,
          _darken(g.color, 0.22),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawPath(path, body);

    // Rim highlight.
    final rim = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03;
    canvas.drawPath(path, rim);

    // Inner ring + spokes for mechanical detail.
    final ring = Paint()
      ..color = _darken(g.color, 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06;
    canvas.drawCircle(center, r * 0.62, ring);

    final spoke = Paint()
      ..color = _darken(g.color, 0.18)
      ..strokeWidth = r * 0.10
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final a = g.angle + i * math.pi / 2;
      final inner = center + Offset(math.cos(a), math.sin(a)) * r * 0.2;
      final outer = center + Offset(math.cos(a), math.sin(a)) * r * 0.58;
      canvas.drawLine(inner, outer, spoke);
    }

    // Center hub + bore.
    final hub = Paint()
      ..shader = RadialGradient(
        colors: [_lighten(g.color, 0.3), _darken(g.color, 0.1)],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.22));
    canvas.drawCircle(center, r * 0.22, hub);
    final bore = Paint()..color = const Color(0xFF1C1E22);
    canvas.drawCircle(center, r * 0.1, bore);
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  bool shouldRepaint(covariant _GearsPainter old) => true;
}
