import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A magical animated treasure chest used as a "choices" board object.
///
/// The lid gently breathes open and closed in a slow loop. While open, warm
/// golden light spills out and a few sparkly gems drift up and fade above it.
/// Fully self-contained, idle-animated, no gesture handling.
class TreasureChestObject extends StatefulWidget {
  const TreasureChestObject({super.key});

  @override
  State<TreasureChestObject> createState() => _TreasureChestObjectState();
}

class _TreasureChestObjectState extends State<TreasureChestObject>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
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
          painter: _TreasureChestPainter(t: _controller.value),
        );
      },
    );
  }
}

class _TreasureChestPainter extends CustomPainter {
  _TreasureChestPainter({required this.t});

  /// Normalized animation time in [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = Offset(size.width / 2, size.height / 2);

    // Lid "breathing": eased open/close between 0 (closed) and 1 (most open).
    final double breath = (math.sin(t * 2 * math.pi - math.pi / 2) + 1) / 2;
    final double open = Curves.easeInOut.transform(breath);

    // Chest geometry, scaled to the shorter side.
    final double chestW = s * 0.62;
    final double chestH = s * 0.34;
    final double bodyTop = c.dy + s * 0.02;
    final Rect bodyRect = Rect.fromCenter(
      center: Offset(c.dx, bodyTop + chestH / 2),
      width: chestW,
      height: chestH,
    );

    _paintHaloGlow(canvas, c, s, open);
    _paintGroundShadow(canvas, c, s, open);
    _paintInteriorGlow(canvas, bodyRect, s, open);
    _paintFloatingGems(canvas, c, s, open);
    _paintBody(canvas, bodyRect, s);
    _paintLid(canvas, bodyRect, s, open);
  }

  void _paintGroundShadow(Canvas canvas, Offset c, double s, double open) {
    final double w = s * 0.62 * (1 + open * 0.04);
    final Rect shadow = Rect.fromCenter(
      center: Offset(c.dx, c.dy + s * 0.40),
      width: w,
      height: s * 0.10,
    );
    final Paint p = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0.0),
        ],
      ).createShader(shadow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(shadow, p);
  }

  void _paintHaloGlow(Canvas canvas, Offset c, double s, double open) {
    final double r = s * (0.40 + open * 0.06);
    final Rect halo = Rect.fromCircle(center: c, radius: r);
    final Paint p = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE08A).withValues(alpha: 0.10 + open * 0.22),
          const Color(0xFFFFB74D).withValues(alpha: 0.0),
        ],
      ).createShader(halo)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(c, r, p);
  }

  void _paintInteriorGlow(Canvas canvas, Rect body, double s, double open) {
    if (open <= 0.02) return;
    final Rect mouth = Rect.fromLTWH(
      body.left + body.width * 0.10,
      body.top - s * 0.02,
      body.width * 0.80,
      s * 0.14 * open + s * 0.02,
    );
    final RRect r = RRect.fromRectAndRadius(mouth, Radius.circular(s * 0.04));
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF6D5).withValues(alpha: 0.95 * open),
          const Color(0xFFFFC24D).withValues(alpha: 0.20 * open),
          const Color(0xFFFFC24D).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(mouth.inflate(s * 0.06))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03);
    canvas.drawRRect(r, glow);

    // Bright light rays fanning upward.
    final Paint ray = Paint()
      ..blendMode = BlendMode.plus
      ..color = const Color(0xFFFFF1C2).withValues(alpha: 0.18 * open);
    canvas.save();
    canvas.translate(body.center.dx, body.top);
    for (int i = -2; i <= 2; i++) {
      final double a = i * 0.16;
      final Path beam = Path()
        ..moveTo(-s * 0.012, 0)
        ..lineTo(s * 0.012, 0)
        ..lineTo(math.sin(a) * s * 0.20 + s * 0.05, -s * 0.30)
        ..lineTo(math.sin(a) * s * 0.20 - s * 0.05, -s * 0.30)
        ..close();
      canvas.drawPath(beam, ray);
    }
    canvas.restore();
  }

  void _paintFloatingGems(Canvas canvas, Offset c, double s, double open) {
    if (open <= 0.05) return;
    const int count = 5;
    for (int i = 0; i < count; i++) {
      final double phase = (t + i / count) % 1.0;
      final double life = phase; // rises and fades over its cycle
      final double fade = math.sin(life * math.pi); // 0 -> 1 -> 0
      final double alpha = fade * open;
      if (alpha <= 0.02) continue;

      final double seedX = math.sin(i * 12.9898) * 0.5;
      final double x = c.dx + seedX * s * 0.36 +
          math.sin(life * 2 * math.pi + i) * s * 0.03;
      final double y = c.dy - s * 0.02 - life * s * 0.38;
      final double gemR = s * (0.018 + (i % 3) * 0.006) * (0.6 + fade * 0.6);

      final List<Color> palette = [
        const Color(0xFF7FE0FF),
        const Color(0xFFFF9EC4),
        const Color(0xFFB5FF8A),
        const Color(0xFFFFE066),
        const Color(0xFFC9A7FF),
      ];
      final Color gem = palette[i % palette.length];

      // Soft glow behind gem.
      final Paint glow = Paint()
        ..color = gem.withValues(alpha: 0.45 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, gemR * 1.6);
      canvas.drawCircle(Offset(x, y), gemR * 1.8, glow);

      // Four-point sparkle.
      _drawSparkle(canvas, Offset(x, y), gemR * 2.2, gem, alpha);
      // Faceted core.
      final Paint core = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: alpha), gem.withValues(alpha: alpha)],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: gemR));
      canvas.drawCircle(Offset(x, y), gemR, core);
    }
  }

  void _drawSparkle(
      Canvas canvas, Offset center, double r, Color color, double alpha) {
    final Paint p = Paint()
      ..blendMode = BlendMode.plus
      ..color = color.withValues(alpha: 0.6 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    final Path star = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r * 0.18, center.dy - r * 0.18)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx + r * 0.18, center.dy + r * 0.18)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r * 0.18, center.dy + r * 0.18)
      ..lineTo(center.dx - r, center.dy)
      ..lineTo(center.dx - r * 0.18, center.dy - r * 0.18)
      ..close();
    canvas.drawPath(star, p);
  }

  void _paintBody(Canvas canvas, Rect body, double s) {
    final RRect bodyR = RRect.fromRectAndCorners(
      body,
      bottomLeft: Radius.circular(s * 0.05),
      bottomRight: Radius.circular(s * 0.05),
      topLeft: Radius.circular(s * 0.015),
      topRight: Radius.circular(s * 0.015),
    );

    // Warm wood gradient.
    final Paint wood = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFB06A35),
          Color(0xFF8A4A23),
          Color(0xFF6E3A1B),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(body);
    canvas.drawRRect(bodyR, wood);

    // Vertical plank shading.
    final Paint plank = Paint()
      ..color = const Color(0xFF5C2F14).withValues(alpha: 0.35)
      ..strokeWidth = s * 0.006
      ..style = PaintingStyle.stroke;
    for (int i = 1; i < 4; i++) {
      final double x = body.left + body.width * i / 4;
      canvas.drawLine(
        Offset(x, body.top + s * 0.01),
        Offset(x, body.bottom - s * 0.01),
        plank,
      );
    }

    // Inner top rim shadow (where lid meets body).
    final Paint rim = Paint()
      ..color = const Color(0xFF3A1F0E).withValues(alpha: 0.55)
      ..strokeWidth = s * 0.02
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(body.left + s * 0.02, body.top),
      Offset(body.right - s * 0.02, body.top),
      rim,
    );

    // Golden horizontal bands.
    _goldBand(canvas, body, s, body.top + body.height * 0.40);
    _goldBand(canvas, body, s, body.top + body.height * 0.78);

    // Vertical center band with clasp + keyhole.
    final Rect vBand = Rect.fromCenter(
      center: Offset(body.center.dx, body.center.dy + body.height * 0.05),
      width: s * 0.07,
      height: body.height * 0.95,
    );
    final Paint vGold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFE9A8),
          Color(0xFFE0A93C),
          Color(0xFF9E6E1E),
        ],
      ).createShader(vBand);
    canvas.drawRRect(
      RRect.fromRectAndRadius(vBand, Radius.circular(s * 0.012)),
      vGold,
    );

    // Clasp plate.
    final Rect clasp = Rect.fromCenter(
      center: Offset(body.center.dx, body.top + s * 0.012),
      width: s * 0.10,
      height: s * 0.06,
    );
    final Paint claspGold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF0C4), Color(0xFFD9A23A)],
      ).createShader(clasp);
    canvas.drawRRect(
      RRect.fromRectAndRadius(clasp, Radius.circular(s * 0.02)),
      claspGold,
    );

    // Keyhole.
    final Offset kh = Offset(body.center.dx, body.center.dy + body.height * 0.10);
    final Paint hole = Paint()..color = const Color(0xFF2A1606);
    canvas.drawCircle(kh, s * 0.016, hole);
    final Path slot = Path()
      ..moveTo(kh.dx - s * 0.008, kh.dy + s * 0.004)
      ..lineTo(kh.dx + s * 0.008, kh.dy + s * 0.004)
      ..lineTo(kh.dx + s * 0.014, kh.dy + s * 0.05)
      ..lineTo(kh.dx - s * 0.014, kh.dy + s * 0.05)
      ..close();
    canvas.drawPath(slot, hole);
  }

  void _goldBand(Canvas canvas, Rect body, double s, double y) {
    final Rect band = Rect.fromLTRB(
      body.left - s * 0.005,
      y - s * 0.022,
      body.right + s * 0.005,
      y + s * 0.022,
    );
    final Paint gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFEFB6),
          Color(0xFFE3AE43),
          Color(0xFF99691C),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(band);
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, Radius.circular(s * 0.01)),
      gold,
    );
    // Top highlight line for metallic sheen.
    final Paint sheen = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = s * 0.004;
    canvas.drawLine(
      Offset(band.left, band.top + s * 0.006),
      Offset(band.right, band.top + s * 0.006),
      sheen,
    );

    // Rivets.
    final Paint rivet = Paint()..color = const Color(0xFF7A521A);
    final Paint rivetHi = Paint()..color = const Color(0xFFFFE9A8);
    for (int i = 0; i <= 4; i++) {
      final double x = band.left + s * 0.02 + (band.width - s * 0.04) * i / 4;
      canvas.drawCircle(Offset(x, y), s * 0.008, rivet);
      canvas.drawCircle(Offset(x - s * 0.002, y - s * 0.002), s * 0.003, rivetHi);
    }
  }

  void _paintLid(Canvas canvas, Rect body, double s, double open) {
    // Lid pivots from the back-top edge and lifts the front upward.
    final double pivotY = body.top;
    final double lidH = body.height * 0.62;
    final double lift = open * lidH * 0.95;

    canvas.save();
    // Approximate a hinge by translating the front edge up.
    final Rect lidRect = Rect.fromLTWH(
      body.left,
      pivotY - lidH + (lidH - lift) * 0.0,
      body.width,
      lidH,
    );
    // Skew the lid upward toward the front by shifting using a vertical offset.
    canvas.translate(0, -lift * 0.55);

    final Path lid = Path();
    final double r = lidH; // dome radius feel
    lid.moveTo(lidRect.left, lidRect.bottom);
    lid.lineTo(lidRect.left, lidRect.bottom - lidH * 0.25);
    lid.quadraticBezierTo(
      lidRect.center.dx,
      lidRect.top - r * 0.10,
      lidRect.right,
      lidRect.bottom - lidH * 0.25,
    );
    lid.lineTo(lidRect.right, lidRect.bottom);
    lid.close();

    final Paint lidWood = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFC07B40),
          Color(0xFF95502A),
          Color(0xFF733E1E),
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(lidRect);
    canvas.drawPath(lid, lidWood);

    // Lid rim-light along the curved top.
    final Paint rimLight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(lidRect);
    final Path rimPath = Path()
      ..moveTo(lidRect.left, lidRect.bottom - lidH * 0.25)
      ..quadraticBezierTo(
        lidRect.center.dx,
        lidRect.top - r * 0.10,
        lidRect.right,
        lidRect.bottom - lidH * 0.25,
      );
    canvas.drawPath(rimPath, rimLight);

    // Curved golden band over the lid.
    final Paint lidGold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFEFB6), Color(0xFFD79F38)],
      ).createShader(lidRect);
    final Path goldArc = Path()
      ..moveTo(lidRect.center.dx, lidRect.bottom)
      ..lineTo(lidRect.center.dx, lidRect.bottom - lidH * 0.28)
      ..quadraticBezierTo(
        lidRect.center.dx,
        lidRect.top + r * 0.02,
        lidRect.center.dx,
        lidRect.top + r * 0.02,
      );
    canvas.drawPath(goldArc, lidGold);

    // Two side golden straps following the dome.
    for (final double fx in [0.22, 0.78]) {
      final double x = lidRect.left + lidRect.width * fx;
      final Paint strap = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE0AC44);
      canvas.drawLine(
        Offset(x, lidRect.bottom),
        Offset(x, lidRect.bottom - lidH * 0.50),
        strap,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TreasureChestPainter oldDelegate) =>
      oldDelegate.t != t;
}
