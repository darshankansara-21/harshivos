import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A cheerful smiling flower in a glossy ceramic pot that sways to an invisible
/// beat. Rounded rainbow petals pulse with the rhythm, two leaves bounce, and
/// musical notes drift upward and fade in a loop. Represents music / speech
/// play — joyful and lively.
class MusicFlowerObject extends StatefulWidget {
  const MusicFlowerObject({super.key});

  @override
  State<MusicFlowerObject> createState() => _MusicFlowerObjectState();
}

class _MusicFlowerObjectState extends State<MusicFlowerObject>
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
          painter: _MusicFlowerPainter(t: _controller.value),
        );
      },
    );
  }
}

class _MusicFlowerPainter extends CustomPainter {
  _MusicFlowerPainter({required this.t});

  /// Normalized animation time in [0, 1).
  final double t;

  static const _petalColors = <Color>[
    Color(0xFFFF6B8B),
    Color(0xFFFFAE5D),
    Color(0xFFFFE066),
    Color(0xFF7FD49C),
    Color(0xFF63B8F5),
    Color(0xFFB388F5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;

    final phase = t * math.pi * 2;
    // Fast musical "beat" pulse (4 beats per loop).
    final beat = (math.sin(t * math.pi * 8) * 0.5 + 0.5);

    // Ground baseline for the pot.
    final groundY = size.height * 0.86;

    _drawShadow(canvas, cx, groundY, s, beat);

    // Whole plant sways side to side around the pot.
    final sway = math.sin(phase) * 0.06; // radians

    final potTop = Offset(cx, groundY - s * 0.02);

    _drawNotes(canvas, cx, potTop.dy, s);

    // Stem + flower sway from the pot rim.
    canvas.save();
    canvas.translate(potTop.dx, potTop.dy);
    canvas.rotate(sway);

    _drawStemAndLeaves(canvas, s, phase);

    final flowerCenter = Offset(0, -s * 0.42);
    _drawFlower(canvas, flowerCenter, beat, s);

    canvas.restore();

    _drawPot(canvas, cx, groundY, s);
  }

  void _drawShadow(Canvas canvas, double cx, double y, double s, double beat) {
    final shadow = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final w = s * (0.34 + beat * 0.02);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, y + s * 0.10), width: w, height: s * 0.08),
      shadow,
    );
  }

  void _drawStemAndLeaves(Canvas canvas, double s, double phase) {
    final stem = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF4F9D5E), Color(0xFF7FD49C)],
      ).createShader(Rect.fromLTWH(-s * 0.03, -s * 0.42, s * 0.06, s * 0.42))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round;
    final stemPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-s * 0.04, -s * 0.22, 0, -s * 0.40);
    canvas.drawPath(stemPath, stem);

    // Two bouncing leaves.
    final bounce = math.sin(phase * 2) * 0.18;
    _drawLeaf(canvas, Offset(0, -s * 0.16), -1, bounce, s);
    _drawLeaf(canvas, Offset(0, -s * 0.26), 1, -bounce, s);
  }

  void _drawLeaf(Canvas canvas, Offset base, double dir, double bounce, double s) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(dir * (0.5 + bounce));
    final len = s * 0.16;
    final wid = s * 0.08;
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.5, -wid, len, 0)
      ..quadraticBezierTo(len * 0.5, wid, 0, 0)
      ..close();
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8FE0A6), Color(0xFF4F9D5E)],
      ).createShader(Rect.fromLTWH(0, -wid, len, wid * 2));
    canvas.drawPath(leaf, fill);

    final vein = Paint()
      ..color = const Color(0x553A6E45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.006
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(len * 0.9, 0), vein);
    canvas.restore();
  }

  void _drawFlower(Canvas canvas, Offset c, double beat, double s) {
    final petalCount = _petalColors.length;
    final pulse = 1.0 + beat * 0.12;
    final petalLen = s * 0.20 * pulse;
    final petalWid = s * 0.13 * pulse;

    // Petals radiating around the center.
    for (var i = 0; i < petalCount; i++) {
      final angle = (i / petalCount) * math.pi * 2 - math.pi / 2;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);

      final petal = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(petalWid, -petalLen * 0.5, 0, -petalLen)
        ..quadraticBezierTo(-petalWid, -petalLen * 0.5, 0, 0)
        ..close();

      final color = _petalColors[i];
      final fill = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.4),
          colors: [_lighten(color), color],
        ).createShader(
          Rect.fromCircle(center: Offset(0, -petalLen * 0.5), radius: petalLen),
        );
      canvas.drawPath(petal, fill);

      // Glossy highlight on each petal.
      final shine = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x88FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(-petalWid, -petalLen, petalWid * 2, petalLen * 0.7));
      canvas.drawPath(petal, shine);
      canvas.restore();
    }

    _drawFace(canvas, c, beat, s);
  }

  void _drawFace(Canvas canvas, Offset c, double beat, double s) {
    final faceR = s * 0.13;

    // Glow behind the face.
    final glow = Paint()
      ..color = const Color(0x55FFE9A8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(c, faceR * 1.2, glow);

    // Warm yellow center disc.
    final disc = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFFFF3C4), Color(0xFFFFC94D), Color(0xFFF2A93B)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: faceR));
    canvas.drawCircle(c, faceR, disc);

    // Rim light.
    final rim = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = faceR * 0.12;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: faceR * 0.94),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      rim,
    );

    // Eyes — blink subtly with the beat.
    final eyeOpen = (1.0 - beat * 0.3).clamp(0.4, 1.0);
    final eyePaint = Paint()..color = const Color(0xFF3A2A1A);
    final eyeDx = faceR * 0.42;
    final eyeDy = -faceR * 0.18;
    final eyeR = faceR * 0.16;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - eyeDx, c.dy + eyeDy),
        width: eyeR * 2,
        height: eyeR * 2 * eyeOpen,
      ),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx + eyeDx, c.dy + eyeDy),
        width: eyeR * 2,
        height: eyeR * 2 * eyeOpen,
      ),
      eyePaint,
    );
    // Eye sparkles.
    final sparkle = Paint()..color = const Color(0xCCFFFFFF);
    canvas.drawCircle(
      Offset(c.dx - eyeDx + eyeR * 0.3, c.dy + eyeDy - eyeR * 0.3),
      eyeR * 0.35,
      sparkle,
    );
    canvas.drawCircle(
      Offset(c.dx + eyeDx + eyeR * 0.3, c.dy + eyeDy - eyeR * 0.3),
      eyeR * 0.35,
      sparkle,
    );

    // Rosy cheeks.
    final cheek = Paint()
      ..color = const Color(0x55FF8FA8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(c.dx - faceR * 0.55, c.dy + faceR * 0.25), faceR * 0.18, cheek);
    canvas.drawCircle(Offset(c.dx + faceR * 0.55, c.dy + faceR * 0.25), faceR * 0.18, cheek);

    // Happy smile that opens a touch on the beat.
    final smile = Paint()
      ..color = const Color(0xFF6E3A24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = faceR * 0.12
      ..strokeCap = StrokeCap.round;
    final mouthRect = Rect.fromCenter(
      center: Offset(c.dx, c.dy + faceR * 0.32),
      width: faceR * 0.9,
      height: faceR * (0.5 + beat * 0.25),
    );
    canvas.drawArc(mouthRect, 0.15, math.pi - 0.3, false, smile);
  }

  void _drawNotes(Canvas canvas, double cx, double topY, double s) {
    // Three notes rising and fading on staggered phases.
    const count = 3;
    for (var i = 0; i < count; i++) {
      final local = (t + i / count) % 1.0;
      final rise = local; // 0 -> 1 upward
      // Fade in then out.
      final alpha = math.sin(local * math.pi).clamp(0.0, 1.0);
      if (alpha <= 0.03) continue;

      final drift = math.sin(local * math.pi * 2 + i) * s * 0.10;
      final side = (i.isEven ? 1.0 : -1.0);
      final pos = Offset(
        cx + side * s * 0.16 + drift,
        topY - s * 0.55 - rise * s * 0.35,
      );
      final color = _petalColors[i % _petalColors.length];
      _drawNote(canvas, pos, s * 0.07, alpha, color, i.isEven);
    }
  }

  void _drawNote(
    Canvas canvas,
    Offset c,
    double size,
    double alpha,
    Color color,
    bool doubled,
  ) {
    final paint = Paint()..color = color.withValues(alpha: alpha);
    final stemPaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.18
      ..strokeCap = StrokeCap.round;

    // Note head.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.25);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size * 0.9, height: size * 0.65),
      paint,
    );
    canvas.restore();

    // Stem.
    final stemTop = Offset(c.dx + size * 0.42, c.dy - size * 1.4);
    canvas.drawLine(Offset(c.dx + size * 0.42, c.dy), stemTop, stemPaint);

    if (doubled) {
      // Second head + connecting beam for a ♫ feel.
      final c2 = Offset(c.dx + size * 1.1, c.dy + size * 0.2);
      canvas.save();
      canvas.translate(c2.dx, c2.dy);
      canvas.rotate(-0.25);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: size * 0.9, height: size * 0.65),
        paint,
      );
      canvas.restore();
      final stem2Top = Offset(c2.dx + size * 0.42, c2.dy - size * 1.4);
      canvas.drawLine(Offset(c2.dx + size * 0.42, c2.dy), stem2Top, stemPaint);
      final beam = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.28
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(stemTop, stem2Top, beam);
    } else {
      // Flag for a single ♪.
      final flag = Path()
        ..moveTo(stemTop.dx, stemTop.dy)
        ..quadraticBezierTo(
          stemTop.dx + size * 0.7,
          stemTop.dy + size * 0.3,
          stemTop.dx + size * 0.2,
          stemTop.dy + size * 0.9,
        );
      canvas.drawPath(flag, stemPaint);
    }
  }

  void _drawPot(Canvas canvas, double cx, double groundY, double s) {
    final topW = s * 0.30;
    final botW = s * 0.22;
    final height = s * 0.20;
    final top = groundY - height;

    // Pot body (trapezoid with rounded base).
    final body = Path()
      ..moveTo(cx - topW / 2, top)
      ..lineTo(cx + topW / 2, top)
      ..lineTo(cx + botW / 2, groundY)
      ..quadraticBezierTo(cx, groundY + s * 0.03, cx - botW / 2, groundY)
      ..close();
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFE8744A), Color(0xFFFF9A6B), Color(0xFFCF5A35)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(cx - topW / 2, top, topW, height));
    canvas.drawPath(body, bodyPaint);

    // Glossy vertical highlight.
    final gloss = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x88FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromLTWH(cx - topW * 0.28, top, topW * 0.22, height));
    final glossPath = Path()
      ..moveTo(cx - topW * 0.28, top + height * 0.06)
      ..lineTo(cx - topW * 0.06, top + height * 0.06)
      ..lineTo(cx - topW * 0.10, groundY - height * 0.1)
      ..lineTo(cx - topW * 0.24, groundY - height * 0.1)
      ..close();
    canvas.drawPath(glossPath, gloss);

    // Rim.
    final rimRect = Rect.fromCenter(
      center: Offset(cx, top),
      width: topW * 1.08,
      height: height * 0.22,
    );
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFA877), Color(0xFFD96238)],
      ).createShader(rimRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rimRect, Radius.circular(height * 0.12)),
      rimPaint,
    );
    // Rim top sheen.
    final sheen = Paint()..color = const Color(0x66FFFFFF);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - topW * 0.18, top - height * 0.02),
        width: topW * 0.3,
        height: height * 0.08,
      ),
      sheen,
    );
  }

  Color _lighten(Color c) {
    return Color.fromRGBO(
      (c.r * 255.0 + (255 - c.r * 255.0) * 0.45).round(),
      (c.g * 255.0 + (255 - c.g * 255.0) * 0.45).round(),
      (c.b * 255.0 + (255 - c.b * 255.0) * 0.45).round(),
      1,
    );
  }

  @override
  bool shouldRepaint(covariant _MusicFlowerPainter oldDelegate) =>
      oldDelegate.t != t;
}
