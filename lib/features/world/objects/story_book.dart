import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A magical open storybook with two pop-up paper-doll characters — a boy on
/// the left page and a girl on the right page — that bob gently as if alive.
/// Pages flutter at the edge, sparkles drift up, and a ribbon bookmark hangs
/// from the spine. Passive art only (no gestures).
class StoryBookObject extends StatefulWidget {
  const StoryBookObject({super.key});

  @override
  State<StoryBookObject> createState() => _StoryBookObjectState();
}

class _StoryBookObjectState extends State<StoryBookObject>
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
          painter: _StoryBookPainter(t: _controller.value),
        );
      },
    );
  }
}

class _StoryBookPainter extends CustomPainter {
  _StoryBookPainter({required this.t});

  /// Normalized animation phase in [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    const tau = math.pi * 2;

    // ---- Soft grounding shadow -------------------------------------------
    final shadowRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + s * 0.34),
      width: s * 0.78,
      height: s * 0.16,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
    );

    // ---- Gentle storytime glow halo --------------------------------------
    final glowPulse = 0.5 + 0.5 * math.sin(t * tau);
    canvas.drawCircle(
      Offset(center.dx, center.dy - s * 0.02),
      s * (0.40 + 0.03 * glowPulse),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3C4).withValues(alpha: 0.55 * glowPulse + 0.20),
            const Color(0xFFFFE08A).withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(center.dx, center.dy - s * 0.02),
            radius: s * 0.43,
          ),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04),
    );

    // ---- The open book ----------------------------------------------------
    _drawBook(canvas, center, s);

    // ---- Pop-up characters ------------------------------------------------
    // Boy on the LEFT page, girl on the RIGHT page; both bob.
    final boyBob = math.sin(t * tau) * s * 0.018;
    final girlBob = math.sin(t * tau + math.pi * 0.6) * s * 0.018;
    _drawBoy(
      canvas,
      Offset(center.dx - s * 0.165, center.dy - s * 0.075 + boyBob),
      s,
    );
    _drawGirl(
      canvas,
      Offset(center.dx + s * 0.165, center.dy - s * 0.075 + girlBob),
      s,
    );

    // ---- Floating star between them --------------------------------------
    final starBob = math.sin(t * tau * 1.3) * s * 0.02;
    _drawStar(
      canvas,
      Offset(center.dx, center.dy - s * 0.28 + starBob),
      s * 0.06,
      const Color(0xFFFFD54A),
      glowPulse,
    );

    // ---- Drifting sparkles rising from the pages -------------------------
    _drawSparkles(canvas, center, s);
  }

  // -----------------------------------------------------------------------
  void _drawBook(Canvas canvas, Offset center, double s) {
    const tau = math.pi * 2;

    // Spine / back cover spanning under both pages.
    final coverPath = Path()
      ..moveTo(center.dx - s * 0.40, center.dy + s * 0.16)
      ..quadraticBezierTo(
        center.dx - s * 0.42,
        center.dy + s * 0.02,
        center.dx - s * 0.34,
        center.dy - s * 0.04,
      )
      ..lineTo(center.dx, center.dy + s * 0.04)
      ..lineTo(center.dx + s * 0.34, center.dy - s * 0.04)
      ..quadraticBezierTo(
        center.dx + s * 0.42,
        center.dy + s * 0.02,
        center.dx + s * 0.40,
        center.dy + s * 0.16,
      )
      ..lineTo(center.dx, center.dy + s * 0.24)
      ..close();
    canvas.drawPath(
      coverPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8E5A3C), Color(0xFF5E3621)],
        ).createShader(coverPath.getBounds()),
    );

    // Two open pages forming a shallow V (cream, glowing).
    const pageColors = [Color(0xFFFFFDF4), Color(0xFFFDEFC9)];

    // Left page.
    final leftPage = Path()
      ..moveTo(center.dx, center.dy + s * 0.02)
      ..lineTo(center.dx - s * 0.34, center.dy - s * 0.07)
      ..quadraticBezierTo(
        center.dx - s * 0.345,
        center.dy + s * 0.08,
        center.dx - s * 0.30,
        center.dy + s * 0.155,
      )
      ..lineTo(center.dx, center.dy + s * 0.155)
      ..close();
    canvas.drawPath(
      leftPage,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: pageColors,
        ).createShader(leftPage.getBounds()),
    );

    // Right page.
    final rightPage = Path()
      ..moveTo(center.dx, center.dy + s * 0.02)
      ..lineTo(center.dx + s * 0.34, center.dy - s * 0.07)
      ..quadraticBezierTo(
        center.dx + s * 0.345,
        center.dy + s * 0.08,
        center.dx + s * 0.30,
        center.dy + s * 0.155,
      )
      ..lineTo(center.dx, center.dy + s * 0.155)
      ..close();
    canvas.drawPath(
      rightPage,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pageColors,
        ).createShader(rightPage.getBounds()),
    );

    // Soft inner shadow near the spine valley.
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - s * 0.05, center.dy - s * 0.02)
        ..lineTo(center.dx, center.dy + s * 0.02)
        ..lineTo(center.dx + s * 0.05, center.dy - s * 0.02)
        ..lineTo(center.dx, center.dy + s * 0.155)
        ..close(),
      Paint()
        ..color = const Color(0xFF8E5A3C).withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );

    // Faint text lines on each page.
    final linePaint = Paint()
      ..color = const Color(0xFFB89A6A).withValues(alpha: 0.45)
      ..strokeWidth = s * 0.006
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final dy = center.dy + s * (0.07 + i * 0.028);
      canvas.drawLine(
        Offset(center.dx - s * 0.27, dy),
        Offset(center.dx - s * 0.05, dy + s * 0.006),
        linePaint,
      );
      canvas.drawLine(
        Offset(center.dx + s * 0.05, dy + s * 0.006),
        Offset(center.dx + s * 0.27, dy),
        linePaint,
      );
    }

    // Fluttering page edges on the right (gentle turning motion).
    for (var i = 0; i < 3; i++) {
      final phase = t * tau + i * 0.9;
      final lift = (0.5 + 0.5 * math.sin(phase)) * s * 0.05;
      final pagePath = Path()
        ..moveTo(center.dx + s * 0.005, center.dy + s * 0.01)
        ..quadraticBezierTo(
          center.dx + s * 0.18,
          center.dy - s * 0.10 - lift,
          center.dx + s * 0.33,
          center.dy - s * 0.055 - lift * 0.3,
        )
        ..quadraticBezierTo(
          center.dx + s * 0.22,
          center.dy + s * 0.01,
          center.dx + s * 0.005,
          center.dy + s * 0.02,
        )
        ..close();
      canvas.drawPath(
        pagePath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 - i * 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        pagePath,
        Paint()
          ..color = const Color(0xFFE8D5A8).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.004,
      );
    }

    // Glossy highlight sweeping across the pages (rim light).
    canvas.drawPath(
      leftPage,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(leftPage.getBounds())
        ..blendMode = BlendMode.softLight,
    );

    // Ribbon bookmark hanging from the spine.
    final ribbonSway = math.sin(t * tau) * s * 0.012;
    final ribbon = Path()
      ..moveTo(center.dx - s * 0.018, center.dy + s * 0.02)
      ..lineTo(center.dx + s * 0.018, center.dy + s * 0.02)
      ..lineTo(center.dx + s * 0.022 + ribbonSway, center.dy + s * 0.30)
      ..lineTo(center.dx + ribbonSway, center.dy + s * 0.26)
      ..lineTo(center.dx - s * 0.022 + ribbonSway, center.dy + s * 0.30)
      ..close();
    canvas.drawPath(
      ribbon,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6F91), Color(0xFFD63D63)],
        ).createShader(ribbon.getBounds()),
    );
  }

  // -----------------------------------------------------------------------
  void _drawBoy(Canvas canvas, Offset p, double s) {
    final unit = s; // characters scale with shortest side

    // Soft contact shadow on the page.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx, p.dy + unit * 0.17),
        width: unit * 0.20,
        height: unit * 0.05,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    // Body / shirt (teal-blue), rounded paper-doll silhouette.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(p.dx, p.dy + unit * 0.085),
        width: unit * 0.165,
        height: unit * 0.16,
      ),
      Radius.circular(unit * 0.05),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF36C6D3), Color(0xFF1E8FA8)],
        ).createShader(bodyRect.outerRect),
    );
    // Shirt gloss.
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(bodyRect.outerRect),
    );

    // Little arms.
    final armPaint = Paint()
      ..color = const Color(0xFFF6C9A0)
      ..strokeWidth = unit * 0.028
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(p.dx - unit * 0.07, p.dy + unit * 0.05),
      Offset(p.dx - unit * 0.10, p.dy + unit * 0.11),
      armPaint,
    );
    canvas.drawLine(
      Offset(p.dx + unit * 0.07, p.dy + unit * 0.05),
      Offset(p.dx + unit * 0.10, p.dy + unit * 0.11),
      armPaint,
    );

    // Head.
    final headCenter = Offset(p.dx, p.dy - unit * 0.045);
    final headR = unit * 0.072;
    canvas.drawCircle(
      headCenter,
      headR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFE0C0), Color(0xFFF3BE92)],
        ).createShader(Rect.fromCircle(center: headCenter, radius: headR)),
    );

    // Short hair (boy).
    final hair = Path()
      ..addArc(
        Rect.fromCircle(center: headCenter, radius: headR * 1.02),
        math.pi,
        math.pi,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR,
        headCenter.dy - headR * 0.2,
        headCenter.dx + headR * 0.5,
        headCenter.dy - headR * 0.1,
      )
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy - headR * 0.5,
        headCenter.dx - headR * 0.5,
        headCenter.dy - headR * 0.1,
      )
      ..quadraticBezierTo(
        headCenter.dx - headR,
        headCenter.dy - headR * 0.2,
        headCenter.dx - headR,
        headCenter.dy,
      )
      ..close();
    canvas.drawPath(
      hair,
      Paint()..color = const Color(0xFF6B4226),
    );

    // Smiling face.
    _drawFace(canvas, headCenter, headR, unit);

    // Rim light on head.
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headR * 0.96),
      math.pi * 1.1,
      math.pi * 0.5,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.008
        ..strokeCap = StrokeCap.round,
    );
  }

  // -----------------------------------------------------------------------
  void _drawGirl(Canvas canvas, Offset p, double s) {
    final unit = s;

    // Contact shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx, p.dy + unit * 0.17),
        width: unit * 0.20,
        height: unit * 0.05,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    // Dress (pink/coral) — trapezoid skirt silhouette.
    final dress = Path()
      ..moveTo(p.dx - unit * 0.055, p.dy + unit * 0.01)
      ..lineTo(p.dx + unit * 0.055, p.dy + unit * 0.01)
      ..lineTo(p.dx + unit * 0.105, p.dy + unit * 0.165)
      ..quadraticBezierTo(
        p.dx,
        p.dy + unit * 0.20,
        p.dx - unit * 0.105,
        p.dy + unit * 0.165,
      )
      ..close();
    canvas.drawPath(
      dress,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8FAB), Color(0xFFF26d8a)],
        ).createShader(dress.getBounds()),
    );
    // Dress gloss.
    canvas.drawPath(
      dress,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(dress.getBounds()),
    );

    // Arms.
    final armPaint = Paint()
      ..color = const Color(0xFFF6C9A0)
      ..strokeWidth = unit * 0.026
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(p.dx - unit * 0.05, p.dy + unit * 0.03),
      Offset(p.dx - unit * 0.10, p.dy + unit * 0.09),
      armPaint,
    );
    canvas.drawLine(
      Offset(p.dx + unit * 0.05, p.dy + unit * 0.03),
      Offset(p.dx + unit * 0.10, p.dy + unit * 0.09),
      armPaint,
    );

    // Head.
    final headCenter = Offset(p.dx, p.dy - unit * 0.05);
    final headR = unit * 0.072;

    // Ponytail behind head.
    canvas.drawCircle(
      Offset(headCenter.dx + headR * 1.1, headCenter.dy + headR * 0.2),
      headR * 0.55,
      Paint()..color = const Color(0xFF7A4A22),
    );

    canvas.drawCircle(
      headCenter,
      headR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFE0C0), Color(0xFFF3BE92)],
        ).createShader(Rect.fromCircle(center: headCenter, radius: headR)),
    );

    // Hair cap.
    final hair = Path()
      ..addArc(
        Rect.fromCircle(center: headCenter, radius: headR * 1.02),
        math.pi,
        math.pi,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR,
        headCenter.dy - headR * 0.1,
        headCenter.dx + headR * 0.4,
        headCenter.dy + headR * 0.05,
      )
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy - headR * 0.4,
        headCenter.dx - headR * 0.4,
        headCenter.dy + headR * 0.05,
      )
      ..quadraticBezierTo(
        headCenter.dx - headR,
        headCenter.dy - headR * 0.1,
        headCenter.dx - headR,
        headCenter.dy,
      )
      ..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFF7A4A22));

    // Bow on top.
    final bowCenter = Offset(headCenter.dx + headR * 0.55, headCenter.dy - headR * 0.85);
    _drawBow(canvas, bowCenter, headR * 0.5);

    // Smiling face.
    _drawFace(canvas, headCenter, headR, unit);

    // Rim light.
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headR * 0.96),
      math.pi * 1.1,
      math.pi * 0.5,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.008
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBow(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = const Color(0xFFFF5C8A);
    final left = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx - r, c.dy - r * 0.7)
      ..lineTo(c.dx - r, c.dy + r * 0.7)
      ..close();
    final right = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + r, c.dy - r * 0.7)
      ..lineTo(c.dx + r, c.dy + r * 0.7)
      ..close();
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);
    canvas.drawCircle(c, r * 0.35, Paint()..color = const Color(0xFFD63D63));
  }

  void _drawFace(Canvas canvas, Offset headCenter, double headR, double unit) {
    final eyePaint = Paint()..color = const Color(0xFF3A2A1A);
    canvas.drawCircle(
      Offset(headCenter.dx - headR * 0.32, headCenter.dy + headR * 0.05),
      headR * 0.11,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + headR * 0.32, headCenter.dy + headR * 0.05),
      headR * 0.11,
      eyePaint,
    );
    // Eye sparkles.
    final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(
      Offset(headCenter.dx - headR * 0.28, headCenter.dy + headR * 0.0),
      headR * 0.04,
      sparkle,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + headR * 0.36, headCenter.dy + headR * 0.0),
      headR * 0.04,
      sparkle,
    );
    // Rosy cheeks.
    final cheek = Paint()..color = const Color(0xFFFF9EB0).withValues(alpha: 0.55);
    canvas.drawCircle(
      Offset(headCenter.dx - headR * 0.5, headCenter.dy + headR * 0.32),
      headR * 0.13,
      cheek,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + headR * 0.5, headCenter.dy + headR * 0.32),
      headR * 0.13,
      cheek,
    );
    // Smile.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCenter.dx, headCenter.dy + headR * 0.28),
        width: headR * 0.7,
        height: headR * 0.55,
      ),
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = const Color(0xFF8A4B2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.008
        ..strokeCap = StrokeCap.round,
    );
  }

  // -----------------------------------------------------------------------
  void _drawStar(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double pulse,
  ) {
    // Outer glow.
    canvas.drawCircle(
      c,
      r * (1.8 + pulse * 0.4),
      Paint()
        ..color = color.withValues(alpha: 0.35 * pulse + 0.1)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
    );
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final angle = -math.pi / 2 + i * math.pi / points;
      final pt = Offset(
        c.dx + radius * math.cos(angle),
        c.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, color],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  // -----------------------------------------------------------------------
  void _drawSparkles(Canvas canvas, Offset center, double s) {
    const tau = math.pi * 2;
    const count = 7;
    for (var i = 0; i < count; i++) {
      final seed = i / count;
      final rise = (t + seed) % 1.0;
      final x = center.dx + math.sin((seed + t) * tau * 1.3) * s * 0.30;
      final y = center.dy + s * 0.06 - rise * s * 0.42;
      final twinkle = (0.5 + 0.5 * math.sin((t * 2 + seed) * tau)).clamp(0.0, 1.0);
      final r = s * 0.012 * (0.6 + twinkle * 0.8) * (1.0 - rise * 0.4);
      final paint = Paint()
        ..color = const Color(0xFFFFE08A)
            .withValues(alpha: (1.0 - rise) * 0.9 * twinkle);
      // Four-point sparkle.
      canvas.drawPath(
        Path()
          ..moveTo(x, y - r * 2)
          ..lineTo(x + r * 0.5, y)
          ..lineTo(x, y + r * 2)
          ..lineTo(x - r * 0.5, y)
          ..close(),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x - r * 2, y)
          ..lineTo(x, y + r * 0.5)
          ..lineTo(x + r * 2, y)
          ..lineTo(x, y - r * 0.5)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StoryBookPainter oldDelegate) =>
      oldDelegate.t != t;
}
