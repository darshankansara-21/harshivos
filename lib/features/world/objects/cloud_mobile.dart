import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A dreamy nursery-mobile cloud that hangs from a thin string and sways
/// gently. Little felt shapes (raindrops, a heart, a rainbow arc) dangle on
/// threads below and swing with an offset pendulum motion. Represents emotion
/// regulation — calm and soothing.
class CloudMobileObject extends StatefulWidget {
  const CloudMobileObject({super.key});

  @override
  State<CloudMobileObject> createState() => _CloudMobileObjectState();
}

class _CloudMobileObjectState extends State<CloudMobileObject>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _CloudMobilePainter(t: _controller.value),
        );
      },
    );
  }
}

class _CloudMobilePainter extends CustomPainter {
  _CloudMobilePainter({required this.t});

  /// Normalized animation time in [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;

    // Two-phase loop in radians for smooth, continuous swaying.
    final phase = t * math.pi * 2;

    // Anchor point at the very top where the string is pinned.
    final anchor = Offset(cx, s * 0.06);

    // Gentle sway of the whole cloud around the anchor.
    final cloudSwing = math.sin(phase) * 0.10; // radians

    // The cloud body floats a little below the anchor on its string.
    final stringLen = s * 0.20;
    final cloudCenter = Offset(
      anchor.dx + math.sin(cloudSwing) * stringLen,
      anchor.dy + math.cos(cloudSwing) * stringLen,
    );

    _drawAnchorString(canvas, anchor, cloudCenter, s);
    _drawCloud(canvas, cloudCenter, cloudSwing, s);
    _drawDanglers(canvas, cloudCenter, phase, s);
    _drawSparkles(canvas, cloudCenter, s);
  }

  void _drawAnchorString(Canvas canvas, Offset anchor, Offset cloud, double s) {
    // Tiny ceiling knob.
    final knob = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE7E0F5), Color(0xFFBCAEDD)],
      ).createShader(Rect.fromCircle(center: anchor, radius: s * 0.02));
    canvas.drawCircle(anchor, s * 0.018, knob);

    final string = Paint()
      ..color = const Color(0xFFB9AFD6)
      ..strokeWidth = s * 0.008
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(anchor, Offset(cloud.dx, cloud.dy - s * 0.10), string);
  }

  void _drawCloud(Canvas canvas, Offset c, double swing, double s) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(swing * 0.6);

    final r = s * 0.16; // base puff radius

    // Soft drop shadow beneath the cloud.
    final shadow = Paint()
      ..color = const Color(0x22311B6B)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.55),
        width: r * 3.0,
        height: r * 1.1,
      ),
      shadow,
    );

    // Build a fluffy silhouette from overlapping circles.
    final puffs = <Offset>[
      Offset(-r * 1.05, r * 0.10),
      Offset(-r * 0.40, -r * 0.35),
      Offset(r * 0.40, -r * 0.30),
      Offset(r * 1.05, r * 0.10),
      Offset(0, r * 0.20),
    ];
    final radii = <double>[r * 0.75, r * 0.95, r * 0.95, r * 0.75, r * 1.05];

    final path = Path();
    for (var i = 0; i < puffs.length; i++) {
      path.addOval(Rect.fromCircle(center: puffs[i], radius: radii[i]));
    }

    // Underside lavender shading (rim from below).
    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF3F0FB),
          Color(0xFFD9CCF2),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.6));
    canvas.drawPath(path, body);

    // Glossy top highlight.
    final gloss = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x88FFFFFF), Color(0x00FFFFFF)],
      ).createShader(
        Rect.fromCircle(center: Offset(-r * 0.2, -r * 0.45), radius: r * 1.1),
      );
    canvas.drawPath(path, gloss);

    // Soft blue underside glow.
    final underGlow = Paint()
      ..color = const Color(0x33A99CE8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.55),
        width: r * 2.2,
        height: r * 0.7,
      ),
      underGlow,
    );

    canvas.restore();
  }

  void _drawDanglers(Canvas canvas, Offset cloud, double phase, double s) {
    // Attachment points along the cloud's underside.
    final baseY = cloud.dy + s * 0.10;
    final spots = <double>[-0.36, -0.12, 0.12, 0.36];
    final lengths = <double>[0.16, 0.20, 0.17, 0.15];

    final thread = Paint()
      ..color = const Color(0xFFCFC6E6)
      ..strokeWidth = s * 0.006
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < spots.length; i++) {
      final ax = cloud.dx + spots[i] * s;
      final top = Offset(ax, baseY);
      // Offset pendulum per dangler.
      final swing = math.sin(phase + i * 0.9) * 0.22;
      final len = lengths[i] * s;
      final end = Offset(
        top.dx + math.sin(swing) * len,
        top.dy + math.cos(swing) * len,
      );
      canvas.drawLine(top, end, thread);

      switch (i) {
        case 0:
          _drawRaindrop(canvas, end, s, const Color(0xFF8FC7F2));
        case 1:
          _drawHeart(canvas, end, s);
        case 2:
          _drawRainbow(canvas, end, s);
        case 3:
          _drawRaindrop(canvas, end, s, const Color(0xFFB7A6E8));
      }
    }
  }

  void _drawRaindrop(Canvas canvas, Offset c, double s, Color color) {
    final r = s * 0.05;
    final path = Path()
      ..moveTo(c.dx, c.dy - r * 1.3)
      ..quadraticBezierTo(c.dx + r, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r, c.dy, c.dx, c.dy - r * 1.3)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.95), _darken(color)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.3));
    canvas.drawPath(path, fill);

    final shine = Paint()..color = const Color(0x88FFFFFF);
    canvas.drawCircle(Offset(c.dx - r * 0.3, c.dy - r * 0.2), r * 0.25, shine);
  }

  void _drawHeart(Canvas canvas, Offset c, double s) {
    final r = s * 0.055;
    final path = Path()..moveTo(c.dx, c.dy + r * 0.9);
    path.cubicTo(
      c.dx - r * 1.4, c.dy - r * 0.3,
      c.dx - r * 0.6, c.dy - r * 1.3,
      c.dx, c.dy - r * 0.4,
    );
    path.cubicTo(
      c.dx + r * 0.6, c.dy - r * 1.3,
      c.dx + r * 1.4, c.dy - r * 0.3,
      c.dx, c.dy + r * 0.9,
    );
    path.close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFA8C8), Color(0xFFF06FA0)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.4));
    canvas.drawPath(path, fill);

    final shine = Paint()..color = const Color(0x88FFFFFF);
    canvas.drawCircle(Offset(c.dx - r * 0.45, c.dy - r * 0.35), r * 0.22, shine);
  }

  void _drawRainbow(Canvas canvas, Offset c, double s) {
    final colors = <Color>[
      const Color(0xFFFF9AA2),
      const Color(0xFFFFD59E),
      const Color(0xFFB5EAD7),
      const Color(0xFF9AC7F2),
    ];
    final base = s * 0.075;
    final band = s * 0.018;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = band;
    for (var i = 0; i < colors.length; i++) {
      stroke.color = colors[i];
      final radius = base - i * band;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(c.dx, c.dy + base * 0.3), radius: radius),
        math.pi,
        math.pi,
        false,
        stroke,
      );
    }
  }

  void _drawSparkles(Canvas canvas, Offset cloud, double s) {
    // Two sparkles that pulse in and out on different sub-phases.
    for (var i = 0; i < 2; i++) {
      final local = (t * 2 + i * 0.5) % 1.0;
      final alpha = math.sin(local * math.pi).clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;
      final angle = i * 2.3 + 0.7;
      final dist = s * (0.20 + 0.04 * i);
      final pos = Offset(
        cloud.dx + math.cos(angle) * dist,
        cloud.dy - s * 0.10 + math.sin(angle) * dist * 0.4,
      );
      _sparkle(canvas, pos, s * 0.03 * alpha, alpha);
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, double alpha) {
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, alpha * 0.95)
      ..strokeWidth = r * 0.35
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), paint);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
    final glow = Paint()
      ..color = Color.fromRGBO(255, 255, 255, alpha * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(c, r * 0.6, glow);
  }

  Color _darken(Color c) {
    return Color.fromRGBO(
      (c.r * 255.0 * 0.7).round(),
      (c.g * 255.0 * 0.7).round(),
      (c.b * 255.0 * 0.7).round(),
      1,
    );
  }

  @override
  bool shouldRepaint(covariant _CloudMobilePainter oldDelegate) =>
      oldDelegate.t != t;
}
