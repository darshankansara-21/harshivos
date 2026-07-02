import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A whimsical animated wooden signpost used as a "first — then" sequence object.
///
/// A vertical post is planted in a little grassy mound. Two arrow-shaped boards
/// point right (an upper "1" and a lower "2") and gently sway. A glowing firefly
/// slowly orbits the post, and small flowers sit at the base.
/// Fully self-contained, idle-animated, no gesture handling.
class SignpostObject extends StatefulWidget {
  const SignpostObject({super.key});

  @override
  State<SignpostObject> createState() => _SignpostObjectState();
}

class _SignpostObjectState extends State<SignpostObject>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
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
          painter: _SignpostPainter(t: _controller.value),
        );
      },
    );
  }
}

class _SignpostPainter extends CustomPainter {
  _SignpostPainter({required this.t});

  /// Normalized animation time in [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = Offset(size.width / 2, size.height / 2);

    // Gentle sway shared by post + boards.
    final double sway = math.sin(t * 2 * math.pi) * 0.04;

    final double moundCY = c.dy + s * 0.34;

    _paintGroundShadow(canvas, Offset(c.dx, moundCY), s);
    _paintMound(canvas, Offset(c.dx, moundCY), s);

    // Pivot the whole post+signs from the base of the post.
    final Offset pivot = Offset(c.dx, moundCY - s * 0.02);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(sway);
    canvas.translate(-pivot.dx, -pivot.dy);

    final double postTop = c.dy - s * 0.36;
    final double postBottom = moundCY - s * 0.01;
    _paintPost(canvas, c.dx, postTop, postBottom, s);

    // Two arrow boards pointing right.
    _paintArrowBoard(
      canvas,
      Offset(c.dx, c.dy - s * 0.20),
      s,
      label: '1',
      tone: const [Color(0xFF7FC8A9), Color(0xFF3E8E6B)],
    );
    _paintArrowBoard(
      canvas,
      Offset(c.dx, c.dy - s * 0.02),
      s,
      label: '2',
      tone: const [Color(0xFFE9A85C), Color(0xFFC97B2E)],
    );

    canvas.restore();

    _paintFlowers(canvas, Offset(c.dx, moundCY), s);
    _paintFirefly(canvas, c, s);
  }

  void _paintGroundShadow(Canvas canvas, Offset center, double s) {
    final Rect shadow = Rect.fromCenter(
      center: Offset(center.dx, center.dy + s * 0.07),
      width: s * 0.58,
      height: s * 0.10,
    );
    final Paint p = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.24),
          Colors.black.withValues(alpha: 0.0),
        ],
      ).createShader(shadow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(shadow, p);
  }

  void _paintMound(Canvas canvas, Offset center, double s) {
    final Rect mound = Rect.fromCenter(
      center: center,
      width: s * 0.52,
      height: s * 0.22,
    );
    // Soil base.
    final Paint soil = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF8B5A2B), Color(0xFF5E3A18)],
      ).createShader(mound);
    final Path moundPath = Path()
      ..moveTo(mound.left, mound.center.dy)
      ..quadraticBezierTo(
        mound.center.dx, mound.top, mound.right, mound.center.dy)
      ..quadraticBezierTo(
        mound.center.dx, mound.bottom, mound.left, mound.center.dy)
      ..close();
    canvas.drawPath(moundPath, soil);

    // Grass cap.
    final Rect grassRect = Rect.fromLTWH(
      mound.left, mound.top - s * 0.01, mound.width, s * 0.10);
    final Paint grass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF8FD86B), Color(0xFF4FA63F)],
      ).createShader(grassRect);
    final Path grassPath = Path()
      ..moveTo(mound.left, mound.center.dy)
      ..quadraticBezierTo(
        mound.center.dx, mound.top - s * 0.01, mound.right, mound.center.dy)
      ..quadraticBezierTo(
        mound.center.dx, mound.center.dy + s * 0.03, mound.left, mound.center.dy)
      ..close();
    canvas.drawPath(grassPath, grass);

    // Grass blades along the top.
    final Paint blade = Paint()
      ..color = const Color(0xFF3E8E36)
      ..strokeWidth = s * 0.006
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final math.Random rnd = math.Random(7);
    for (int i = 0; i < 9; i++) {
      final double fx = i / 8;
      final double x = mound.left + s * 0.04 + (mound.width - s * 0.08) * fx;
      final double arc = math.sin((fx - 0.5) * math.pi);
      final double yTop = mound.top + arc.abs() * s * 0.015 + s * 0.005;
      final double lean = (rnd.nextDouble() - 0.5) * s * 0.02;
      canvas.drawLine(
        Offset(x, yTop + s * 0.02),
        Offset(x + lean, yTop - s * 0.03),
        blade,
      );
    }
  }

  void _paintPost(
      Canvas canvas, double cx, double top, double bottom, double s) {
    final Rect postRect = Rect.fromLTRB(
      cx - s * 0.035, top, cx + s * 0.035, bottom);
    final RRect post = RRect.fromRectAndRadius(
      postRect, Radius.circular(s * 0.02));

    final Paint wood = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF9A6336),
          Color(0xFFB97B45),
          Color(0xFF7A4A24),
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(postRect);
    canvas.drawRRect(post, wood);

    // Left rim-light.
    final Paint rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = s * 0.006
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(postRect.left + s * 0.008, top + s * 0.02),
      Offset(postRect.left + s * 0.008, bottom - s * 0.02),
      rim,
    );

    // Wood grain.
    final Paint grain = Paint()
      ..color = const Color(0xFF5E3A1B).withValues(alpha: 0.3)
      ..strokeWidth = s * 0.003;
    for (int i = 1; i < 3; i++) {
      final double x = postRect.left + postRect.width * i / 3;
      canvas.drawLine(
        Offset(x, top + s * 0.03),
        Offset(x, bottom - s * 0.03),
        grain,
      );
    }

    // Rounded cap on top.
    final Paint cap = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFC78A52), Color(0xFF96622F)],
      ).createShader(Rect.fromCircle(center: Offset(cx, top), radius: s * 0.05));
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, top + s * 0.005),
        width: s * 0.09,
        height: s * 0.06),
      math.pi,
      math.pi,
      true,
      cap,
    );
  }

  void _paintArrowBoard(
    Canvas canvas,
    Offset center,
    double s, {
    required String label,
    required List<Color> tone,
  }) {
    final double w = s * 0.46;
    final double h = s * 0.13;
    final double tip = s * 0.07;
    final double left = center.dx - s * 0.02;
    final Rect bound =
        Rect.fromLTWH(left, center.dy - h / 2, w, h);

    // Arrow pointing right.
    final Path arrow = Path()
      ..moveTo(bound.left, bound.top)
      ..lineTo(bound.right - tip, bound.top)
      ..lineTo(bound.right, bound.center.dy)
      ..lineTo(bound.right - tip, bound.bottom)
      ..lineTo(bound.left, bound.bottom)
      ..close();

    // Drop shadow under the board.
    final Paint boardShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012);
    canvas.save();
    canvas.translate(s * 0.006, s * 0.012);
    canvas.drawPath(arrow, boardShadow);
    canvas.restore();

    // Painted wood face.
    final Paint face = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: tone,
      ).createShader(bound);
    canvas.drawPath(arrow, face);

    // Plank seams.
    final Paint seam = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = s * 0.004;
    canvas.drawLine(
      Offset(bound.left, bound.center.dy - h * 0.18),
      Offset(bound.right - tip * 0.5, bound.center.dy - h * 0.18),
      seam,
    );
    canvas.drawLine(
      Offset(bound.left, bound.center.dy + h * 0.18),
      Offset(bound.right - tip * 0.5, bound.center.dy + h * 0.18),
      seam,
    );

    // Top rim-light.
    final Paint rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = s * 0.005
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(bound.left + s * 0.01, bound.top + s * 0.006),
      Offset(bound.right - tip, bound.top + s * 0.006),
      rim,
    );

    // Dark edge outline for storybook pop.
    final Paint outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.006
      ..color = const Color(0xFF3A2412).withValues(alpha: 0.55)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(arrow, outline);

    // Label.
    final double fontSize = h * 0.62;
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFFFFF7E6),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Offset labelPos = Offset(
      bound.left + s * 0.04,
      bound.center.dy - tp.height / 2,
    );
    tp.paint(canvas, labelPos);

    // Small dot motif beside the number.
    final Paint dot = Paint()..color = const Color(0xFFFFF7E6).withValues(alpha: 0.85);
    final double dotX = labelPos.dx + tp.width + s * 0.05;
    final int dots = label == '1' ? 1 : 2;
    for (int i = 0; i < dots; i++) {
      canvas.drawCircle(
        Offset(dotX + i * s * 0.035, bound.center.dy),
        s * 0.012,
        dot,
      );
    }

    // A peg/nail where the board meets the post.
    final Paint peg = Paint()..color = const Color(0xFF4A2E15);
    canvas.drawCircle(Offset(bound.left + s * 0.015, bound.center.dy), s * 0.01, peg);
  }

  void _paintFlowers(Canvas canvas, Offset moundCenter, double s) {
    _flower(canvas, Offset(moundCenter.dx - s * 0.20, moundCenter.dy + s * 0.01),
        s, const Color(0xFFFF8FB2));
    _flower(canvas, Offset(moundCenter.dx + s * 0.21, moundCenter.dy + s * 0.02),
        s, const Color(0xFFFFD166));
    _flower(canvas, Offset(moundCenter.dx + s * 0.12, moundCenter.dy + s * 0.04),
        s * 0.8, const Color(0xFFB6A7FF));
  }

  void _flower(Canvas canvas, Offset base, double s, Color petal) {
    // Stem.
    final Paint stem = Paint()
      ..color = const Color(0xFF3E8E36)
      ..strokeWidth = s * 0.008
      ..strokeCap = StrokeCap.round;
    final Offset head = Offset(base.dx, base.dy - s * 0.07);
    canvas.drawLine(base, head, stem);

    // Petals.
    final double pr = s * 0.018;
    final Paint pPaint = Paint()..color = petal;
    for (int i = 0; i < 5; i++) {
      final double a = i / 5 * 2 * math.pi;
      canvas.drawCircle(
        Offset(head.dx + math.cos(a) * pr, head.dy + math.sin(a) * pr),
        pr * 0.8,
        pPaint,
      );
    }
    // Center.
    canvas.drawCircle(head, pr * 0.7, Paint()..color = const Color(0xFFFFF2B0));
  }

  void _paintFirefly(Canvas canvas, Offset c, double s) {
    final double a = t * 2 * math.pi;
    final double rx = s * 0.26;
    final double ry = s * 0.30;
    final double x = c.dx + math.cos(a) * rx;
    final double y = c.dy - s * 0.08 + math.sin(a) * ry;
    // Depth: dimmer when "behind" the post (upper arc).
    final double depth = (math.sin(a) + 1) / 2; // 0 behind .. 1 front
    final double alpha = 0.45 + depth * 0.55;

    final double glowR = s * 0.05 * (0.8 + 0.2 * math.sin(t * 12 * math.pi));
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF6B0).withValues(alpha: 0.85 * alpha),
          const Color(0xFFFFE066).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(x, y), radius: glowR))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02);
    canvas.drawCircle(Offset(x, y), glowR, glow);

    final Paint core = Paint()
      ..color = const Color(0xFFFFFDE0).withValues(alpha: alpha);
    canvas.drawCircle(Offset(x, y), s * 0.012, core);
  }

  @override
  bool shouldRepaint(covariant _SignpostPainter oldDelegate) =>
      oldDelegate.t != t;
}
