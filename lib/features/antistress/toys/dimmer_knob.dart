import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A large rotary dimmer-knob fidget toy.
///
/// Drag around the centered knob to rotate it; the angle sets a brightness
/// from 0..1 that drives a big glowing bulb above. Glow radius and color
/// warmth scale with brightness. Detent haptics fire as the knob passes
/// evenly spaced steps. The knob carries a position-indicator notch.
class DimmerKnobToy extends StatefulWidget {
  const DimmerKnobToy({super.key});

  @override
  State<DimmerKnobToy> createState() => _DimmerKnobToyState();
}

class _DimmerKnobToyState extends State<DimmerKnobToy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Knob sweep is limited to a 270-degree arc for an intuitive dimmer.
  static const double _minAngle = -math.pi * 0.75;
  static const double _maxAngle = math.pi * 0.75;
  static const int _detents = 12;

  double _angle = _minAngle;
  int _lastDetent = 0;

  Offset _knobCenter = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Continuous ticker drives the bulb's gentle breathing shimmer at 60fps.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _brightness =>
      ((_angle - _minAngle) / (_maxAngle - _minAngle)).clamp(0.0, 1.0);

  void _updateFromPosition(Offset localPosition) {
    final Offset v = localPosition - _knobCenter;
    if (v.distance < 4) return;
    double a = math.atan2(v.dy, v.dx);
    // Clamp to the dimmer arc.
    if (a < _minAngle) a = _minAngle;
    if (a > _maxAngle) a = _maxAngle;
    setState(() => _angle = a);

    final int detent = (_brightness * _detents).round();
    if (detent != _lastDetent) {
      _lastDetent = detent;
      if (detent == 0 || detent == _detents) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        // Knob sits in the lower-middle; bulb glows above it.
        _knobCenter = Offset(size.width / 2, size.height * 0.66);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) {
            HapticFeedback.lightImpact();
            _updateFromPosition(d.localPosition);
          },
          onPanUpdate: (DragUpdateDetails d) =>
              _updateFromPosition(d.localPosition),
          onPanEnd: (DragEndDetails d) => HapticFeedback.lightImpact(),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _DimmerPainter(
                  angle: _angle,
                  brightness: _brightness,
                  minAngle: _minAngle,
                  maxAngle: _maxAngle,
                  detents: _detents,
                  shimmer: _controller.value,
                  knobCenter: _knobCenter,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DimmerPainter extends CustomPainter {
  _DimmerPainter({
    required this.angle,
    required this.brightness,
    required this.minAngle,
    required this.maxAngle,
    required this.detents,
    required this.shimmer,
    required this.knobCenter,
  });

  final double angle;
  final double brightness;
  final double minAngle;
  final double maxAngle;
  final int detents;
  final double shimmer;
  final Offset knobCenter;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Background darkens when dim, warms slightly when bright.
    final Color top = Color.lerp(
        const Color(0xFF0A0A12), const Color(0xFF241A0E), brightness)!;
    final Color bottom = Color.lerp(
        const Color(0xFF05050A), const Color(0xFF120D08), brightness)!;
    final Paint bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[top, bottom],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // ---- Bulb above the knob ----
    final Offset bulbCenter = Offset(size.width / 2, size.height * 0.30);
    final double breathe = 1.0 + 0.04 * math.sin(shimmer * 2 * math.pi);
    final Color warm = Color.lerp(
        const Color(0xFFFFF4D6), const Color(0xFFFFB347), 1 - brightness)!;
    final double glowR =
        (size.shortestSide * (0.12 + 0.42 * brightness)) * breathe;

    if (brightness > 0.001) {
      final Paint glow = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            warm.withOpacity(0.9 * brightness),
            warm.withOpacity(0.35 * brightness),
            warm.withOpacity(0.0),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromCircle(center: bulbCenter, radius: glowR),
        );
      canvas.drawCircle(bulbCenter, glowR, glow);
    }

    // Bulb body.
    final double bulbR = size.shortestSide * 0.075;
    final Paint bulbBody = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Color.lerp(const Color(0xFF2A2A33), warm, brightness)!,
          Color.lerp(const Color(0xFF14141A), warm.withOpacity(0.6), brightness)!,
        ],
      ).createShader(Rect.fromCircle(center: bulbCenter, radius: bulbR));
    canvas.drawCircle(bulbCenter, bulbR, bulbBody);

    // Filament hint.
    final Paint filament = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = warm.withOpacity(0.4 + 0.6 * brightness);
    final Path fil = Path()
      ..moveTo(bulbCenter.dx - bulbR * 0.4, bulbCenter.dy + bulbR * 0.2)
      ..lineTo(bulbCenter.dx - bulbR * 0.1, bulbCenter.dy - bulbR * 0.3)
      ..lineTo(bulbCenter.dx + bulbR * 0.1, bulbCenter.dy + bulbR * 0.3)
      ..lineTo(bulbCenter.dx + bulbR * 0.4, bulbCenter.dy - bulbR * 0.2);
    canvas.drawPath(fil, filament);

    // ---- Knob ----
    final double knobR = size.shortestSide * 0.20;

    // Outer detent ticks.
    final Paint tick = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i <= detents; i++) {
      final double a =
          minAngle + (maxAngle - minAngle) * (i / detents);
      final bool active = (brightness * detents) >= i - 0.001;
      tick
        ..strokeWidth = active ? 4 : 2.5
        ..color = active
            ? warm.withOpacity(0.9)
            : Colors.white.withOpacity(0.18);
      final Offset p1 = knobCenter +
          Offset(math.cos(a), math.sin(a)) * (knobR * 1.18);
      final Offset p2 = knobCenter +
          Offset(math.cos(a), math.sin(a)) * (knobR * 1.30);
      canvas.drawLine(p1, p2, tick);
    }

    // Knob base shadow.
    final Paint shadow = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(knobCenter.translate(0, 8), knobR, shadow);

    // Knob body with soft metallic radial shading.
    final Paint knobBody = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: <Color>[
          const Color(0xFF3A3A46),
          const Color(0xFF1C1C24),
          const Color(0xFF101016),
        ],
        stops: const <double>[0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: knobCenter, radius: knobR));
    canvas.drawCircle(knobCenter, knobR, knobBody);

    // Knob rim ring.
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = warm.withOpacity(0.25 + 0.5 * brightness);
    canvas.drawCircle(knobCenter, knobR * 0.96, rim);

    // Position indicator notch.
    final Offset notchOuter =
        knobCenter + Offset(math.cos(angle), math.sin(angle)) * (knobR * 0.82);
    final Offset notchInner =
        knobCenter + Offset(math.cos(angle), math.sin(angle)) * (knobR * 0.40);
    final Paint notch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..color = warm.withOpacity(0.55 + 0.45 * brightness);
    canvas.drawLine(notchInner, notchOuter, notch);

    // Glowing dot at the notch tip.
    final Paint notchDot = Paint()
      ..color = warm.withOpacity(0.6 + 0.4 * brightness)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(notchOuter, 6, notchDot);

    // Center hub.
    final Paint hub = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF4A4A56),
          const Color(0xFF14141A),
        ],
      ).createShader(
          Rect.fromCircle(center: knobCenter, radius: knobR * 0.28));
    canvas.drawCircle(knobCenter, knobR * 0.28, hub);
  }

  @override
  bool shouldRepaint(_DimmerPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.brightness != brightness ||
      oldDelegate.shimmer != shimmer;
}
