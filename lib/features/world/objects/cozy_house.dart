import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A warm, storybook cottage representing "My Daily Life" — a child's home
/// and routines hub. Passive animated art only (no gestures): the house gently
/// breathes, the window light softly pulses, and a slow curl of smoke loops
/// from the chimney.
class CozyHouseObject extends StatefulWidget {
  const CozyHouseObject({super.key});

  @override
  State<CozyHouseObject> createState() => _CozyHouseObjectState();
}

class _CozyHouseObjectState extends State<CozyHouseObject>
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
          painter: _CozyHousePainter(t: _controller.value),
        );
      },
    );
  }
}

class _CozyHousePainter extends CustomPainter {
  _CozyHousePainter({required this.t});

  /// Normalized idle-loop time in [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Idle "breathing" — a gentle vertical bob and a whisper of scale.
    const twoPi = math.pi * 2;
    final bob = math.sin(t * twoPi) * s * 0.012;
    final breathe = 1.0 + math.sin(t * twoPi) * 0.012;

    // Soft pulsing window glow factor (separate, slower-feeling phase).
    final glowPulse = 0.5 + 0.5 * math.sin(t * twoPi * 1.6 + 0.7);
    // Tiny lamp flicker layered on top for a cosy, living light.
    final flicker =
        0.85 + 0.15 * math.sin(t * twoPi * 7.3 + math.sin(t * twoPi * 3.1));
    final windowGlow = (glowPulse * flicker).clamp(0.0, 1.0);

    canvas.save();
    // Apply breathing around the house centre.
    canvas.translate(cx, cy + bob);
    canvas.scale(breathe);
    canvas.translate(-cx, -cy);

    _paintShadow(canvas, size, s, cx);
    _paintOuterGlow(canvas, size, s, cx, cy, windowGlow);
    _paintGarden(canvas, size, s, cx);
    _paintBody(canvas, size, s, cx, cy);
    _paintRoof(canvas, size, s, cx, cy);
    _paintChimney(canvas, size, s, cx, cy);
    _paintWindow(canvas, size, s, cx, cy, windowGlow);
    _paintDoor(canvas, size, s, cx, cy);
    _paintSmoke(canvas, size, s, cx, cy);

    canvas.restore();
  }

  // ---- Geometry helpers --------------------------------------------------

  // The wall block, in absolute coordinates.
  Rect _wallRect(Size size, double s, double cx, double cy) {
    final w = s * 0.52;
    final h = s * 0.40;
    final left = cx - w / 2;
    final top = cy - h * 0.10;
    return Rect.fromLTWH(left, top, w, h);
  }

  // ---- Layers ------------------------------------------------------------

  void _paintShadow(Canvas canvas, Size size, double s, double cx) {
    final wall = _wallRect(size, s, cx, size.height / 2);
    final shadowCenter = Offset(cx, wall.bottom + s * 0.03);
    final shadowRect = Rect.fromCenter(
      center: shadowCenter,
      width: s * 0.62,
      height: s * 0.11,
    );
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.025);
    canvas.drawOval(shadowRect, paint);
  }

  void _paintOuterGlow(
    Canvas canvas,
    Size size,
    double s,
    double cx,
    double cy,
    double windowGlow,
  ) {
    final center = Offset(cx, cy);
    final radius = s * 0.52;
    final alpha = 0.10 + windowGlow * 0.08;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE3A8).withValues(alpha: alpha),
          const Color(0xFFFFC56B).withValues(alpha: alpha * 0.4),
          const Color(0x00FFC56B),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _paintGarden(Canvas canvas, Size size, double s, double cx) {
    final wall = _wallRect(size, s, cx, size.height / 2);
    final groundY = wall.bottom;

    // A small soft grass patch hugging the base of the house.
    final grassRect = Rect.fromCenter(
      center: Offset(cx, groundY + s * 0.01),
      width: s * 0.58,
      height: s * 0.10,
    );
    final grassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF9CD67A), Color(0xFF6FB84F)],
      ).createShader(grassRect);
    canvas.drawOval(grassRect, grassPaint);

    // Two little flowers — left (warm pink) and right (sunny yellow).
    _paintFlower(
      canvas,
      Offset(cx - s * 0.205, groundY + s * 0.012),
      s,
      const Color(0xFFFF8FB1),
      const Color(0xFFFFE08A),
    );
    _paintFlower(
      canvas,
      Offset(cx + s * 0.205, groundY + s * 0.022),
      s * 0.85,
      const Color(0xFFFFC861),
      const Color(0xFFFF9E5E),
    );
  }

  void _paintFlower(
    Canvas canvas,
    Offset base,
    double s,
    Color petal,
    Color center,
  ) {
    // Stem.
    final stemPaint = Paint()
      ..color = const Color(0xFF4F9E3C)
      ..strokeWidth = s * 0.012
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final stemTop = Offset(base.dx, base.dy - s * 0.085);
    canvas.drawLine(base, stemTop, stemPaint);

    // A small leaf on the stem.
    final leafPaint = Paint()..color = const Color(0xFF66B84C);
    final leafCenter = Offset(base.dx + s * 0.02, base.dy - s * 0.045);
    final leafRect = Rect.fromCenter(
      center: leafCenter,
      width: s * 0.05,
      height: s * 0.025,
    );
    canvas.save();
    canvas.translate(leafCenter.dx, leafCenter.dy);
    canvas.rotate(-0.5);
    canvas.translate(-leafCenter.dx, -leafCenter.dy);
    canvas.drawOval(leafRect, leafPaint);
    canvas.restore();

    // Petals around the flower head.
    final petalPaint = Paint()..color = petal;
    final petalR = s * 0.028;
    for (var i = 0; i < 5; i++) {
      final ang = (math.pi * 2 / 5) * i - math.pi / 2;
      final p = Offset(
        stemTop.dx + math.cos(ang) * petalR,
        stemTop.dy + math.sin(ang) * petalR,
      );
      canvas.drawCircle(p, petalR * 0.95, petalPaint);
    }
    // Flower centre.
    canvas.drawCircle(stemTop, petalR * 0.85, Paint()..color = center);
  }

  void _paintBody(Canvas canvas, Size size, double s, double cx, double cy) {
    final wall = _wallRect(size, s, cx, cy);
    final radius = Radius.circular(s * 0.06);
    final rrect = RRect.fromRectAndCorners(
      wall,
      topLeft: radius,
      topRight: radius,
      bottomLeft: Radius.circular(s * 0.045),
      bottomRight: Radius.circular(s * 0.045),
    );

    // Main wall gradient — cheerful cream → peach.
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF4E0), Color(0xFFFFD9B0), Color(0xFFFFC79A)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(wall);
    canvas.drawRRect(rrect, bodyPaint);

    // Soft inner shadow along the bottom for grounding.
    canvas.save();
    canvas.clipRRect(rrect);
    final innerShadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [
          const Color(0xFFB87A4E).withValues(alpha: 0.28),
          const Color(0x00B87A4E),
        ],
      ).createShader(wall);
    canvas.drawRRect(rrect, innerShadow);

    // Glossy vertical highlight on the left face.
    final highlightRect = Rect.fromLTWH(
      wall.left,
      wall.top,
      wall.width * 0.30,
      wall.height,
    );
    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          const Color(0x00FFFFFF),
        ],
      ).createShader(highlightRect);
    canvas.drawRect(highlightRect, highlight);
    canvas.restore();

    // Rim light along the top edge of the wall.
    final rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.008
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(wall.left + s * 0.04, wall.top + s * 0.006),
      Offset(wall.right - s * 0.04, wall.top + s * 0.006),
      rim,
    );
  }

  void _paintRoof(Canvas canvas, Size size, double s, double cx, double cy) {
    final wall = _wallRect(size, s, cx, cy);
    final eaveY = wall.top + s * 0.005;
    final overhang = s * 0.07;
    final left = wall.left - overhang;
    final right = wall.right + overhang;
    final apexY = wall.top - s * 0.20;

    // Curved roof using quadratic beziers for a soft storybook silhouette.
    final roof = Path()
      ..moveTo(left, eaveY)
      ..quadraticBezierTo(cx, eaveY - s * 0.02, right, eaveY)
      ..lineTo(right - s * 0.02, eaveY - s * 0.015)
      ..quadraticBezierTo(
        cx + s * 0.02,
        apexY - s * 0.01,
        cx,
        apexY,
      )
      ..quadraticBezierTo(
        cx - s * 0.02,
        apexY - s * 0.01,
        left + s * 0.02,
        eaveY - s * 0.015,
      )
      ..close();

    final roofRect = Rect.fromLTRB(left, apexY, right, eaveY);
    final roofPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF8A5B), Color(0xFFF2693C), Color(0xFFD9512B)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(roofRect);
    canvas.drawPath(roof, roofPaint);

    // Glossy sheen near the roof ridge.
    final sheen = Path()
      ..moveTo(cx - s * 0.02, apexY + s * 0.01)
      ..quadraticBezierTo(
        cx - s * 0.12,
        apexY + s * 0.06,
        left + s * 0.08,
        eaveY - s * 0.02,
      );
    final sheenPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(sheen, sheenPaint);

    // Warm shadow under the eaves where the roof meets the wall.
    final eaveShadowRect = Rect.fromLTWH(
      wall.left,
      eaveY,
      wall.width,
      s * 0.05,
    );
    final eaveShadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF9C4A2A).withValues(alpha: 0.30),
          const Color(0x009C4A2A),
        ],
      ).createShader(eaveShadowRect);
    canvas.drawRect(eaveShadowRect, eaveShadow);
  }

  void _paintChimney(Canvas canvas, Size size, double s, double cx, double cy) {
    final wall = _wallRect(size, s, cx, cy);
    final apexY = wall.top - s * 0.20;
    // Place the chimney on the right slope of the roof.
    final chimX = cx + s * 0.14;
    final chimTop = apexY + s * 0.02;
    final chimW = s * 0.055;
    final chimH = s * 0.11;
    final chimRect = Rect.fromLTWH(chimX, chimTop, chimW, chimH);
    final rrect = RRect.fromRectAndCorners(
      chimRect,
      topLeft: Radius.circular(s * 0.012),
      topRight: Radius.circular(s * 0.012),
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE07A53), Color(0xFFC0552F)],
      ).createShader(chimRect);
    canvas.drawRRect(rrect, paint);

    // Little cap on top of the chimney.
    final capRect = Rect.fromLTWH(
      chimX - s * 0.008,
      chimTop - s * 0.012,
      chimW + s * 0.016,
      s * 0.018,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, Radius.circular(s * 0.008)),
      Paint()..color = const Color(0xFFB04A28),
    );
  }

  void _paintWindow(
    Canvas canvas,
    Size size,
    double s,
    double cx,
    double cy,
    double windowGlow,
  ) {
    final wall = _wallRect(size, s, cx, cy);
    final center = Offset(cx - wall.width * 0.22, wall.top + wall.height * 0.32);
    final r = s * 0.058;

    // Outer light bloom spilling from the window.
    final bloom = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE59B)
              .withValues(alpha: 0.55 * windowGlow + 0.15),
          const Color(0x00FFE59B),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 2.4))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.01);
    canvas.drawCircle(center, r * 2.4, bloom);

    // Window frame.
    final frameRect = Rect.fromCenter(
      center: center,
      width: r * 2.1,
      height: r * 2.4,
    );
    final frameRRect = RRect.fromRectAndRadius(
      frameRect,
      Radius.circular(r * 0.9),
    );
    canvas.drawRRect(
      frameRRect.inflate(s * 0.012),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawRRect(
      frameRRect.inflate(s * 0.012),
      Paint()
        ..color = const Color(0xFFE9B98A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.006,
    );

    // Warm glowing glass — brightness pulses with windowGlow.
    final glassPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(const Color(0xFFFFF2C0), const Color(0xFFFFD96B),
              1 - windowGlow * 0.6)!,
          const Color(0xFFFFB347),
        ],
      ).createShader(frameRect);
    canvas.drawRRect(frameRRect, glassPaint);

    // Window mullions (cross bars).
    final barPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85)
      ..strokeWidth = s * 0.007
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, frameRect.top + s * 0.006),
      Offset(center.dx, frameRect.bottom - s * 0.006),
      barPaint,
    );
    canvas.drawLine(
      Offset(frameRect.left + s * 0.006, center.dy),
      Offset(frameRect.right - s * 0.006, center.dy),
      barPaint,
    );

    // Glossy diagonal glint on the glass.
    final glint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.006
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(frameRect.left + r * 0.5, center.dy - r * 0.7),
      Offset(center.dx - r * 0.1, frameRect.top + r * 0.3),
      glint,
    );
  }

  void _paintDoor(Canvas canvas, Size size, double s, double cx, double cy) {
    final wall = _wallRect(size, s, cx, cy);
    final doorW = s * 0.13;
    final doorH = s * 0.22;
    final left = cx + wall.width * 0.06;
    final top = wall.bottom - doorH;
    final doorRect = Rect.fromLTWH(left, top, doorW, doorH);

    // Arched top via rounded top corners.
    final doorRRect = RRect.fromRectAndCorners(
      doorRect,
      topLeft: Radius.circular(doorW * 0.5),
      topRight: Radius.circular(doorW * 0.5),
    );

    final doorPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB5754A), Color(0xFF8A5230)],
      ).createShader(doorRect);
    canvas.drawRRect(doorRRect, doorPaint);

    // Soft inner panel.
    final panelRect = doorRect.deflate(s * 0.018);
    final panelRRect = RRect.fromRectAndCorners(
      panelRect,
      topLeft: Radius.circular(doorW * 0.42),
      topRight: Radius.circular(doorW * 0.42),
    );
    canvas.drawRRect(
      panelRRect,
      Paint()..color = const Color(0xFF9C5E37).withValues(alpha: 0.6),
    );

    // Highlight down the door's left edge.
    final hi = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.006
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(left + s * 0.012, top + doorH * 0.5),
      Offset(left + s * 0.012, doorRect.bottom - s * 0.02),
      hi,
    );

    // A tiny heart on the door.
    final heartCenter = Offset(left + doorW * 0.5, top + doorH * 0.34);
    _paintHeart(canvas, heartCenter, s * 0.05,
        const Color(0xFFFF6F91));

    // Round door knob.
    canvas.drawCircle(
      Offset(doorRect.right - s * 0.022, cy + doorH * 0.05),
      s * 0.012,
      Paint()..color = const Color(0xFFFFE08A),
    );
  }

  void _paintHeart(Canvas canvas, Offset center, double sizeH, Color color) {
    final path = Path();
    final w = sizeH;
    final h = sizeH;
    final x = center.dx;
    final y = center.dy - h * 0.2;
    path.moveTo(x, y + h * 0.3);
    path.cubicTo(
      x - w * 0.5, y - h * 0.25,
      x - w * 0.5, y + h * 0.35,
      x, y + h * 0.55,
    );
    path.cubicTo(
      x + w * 0.5, y + h * 0.35,
      x + w * 0.5, y - h * 0.25,
      x, y + h * 0.3,
    );
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    // Tiny glossy dot on the heart.
    canvas.drawCircle(
      Offset(x - w * 0.12, y + h * 0.18),
      w * 0.06,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _paintSmoke(Canvas canvas, Size size, double s, double cx, double cy) {
    final wall = _wallRect(size, s, cx, cy);
    final apexY = wall.top - s * 0.20;
    final chimX = cx + s * 0.14 + s * 0.0275;
    final originY = apexY + s * 0.005;

    // Three puffs rising and fading in a slow loop.
    const puffCount = 3;
    for (var i = 0; i < puffCount; i++) {
      // Each puff has its own phase along the loop.
      final phase = (t + i / puffCount) % 1.0;
      final rise = phase * s * 0.22;
      final drift = math.sin(phase * math.pi * 2 + i) * s * 0.03;
      final radius = s * (0.018 + phase * 0.03);
      // Fade in at the start, out at the end.
      final fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final alpha = 0.30 * fade;
      if (alpha <= 0.01) {
        continue;
      }
      final c = Offset(chimX + drift, originY - rise);
      final paint = Paint()
        ..color = const Color(0xFFEDE6DE).withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.01);
      canvas.drawCircle(c, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CozyHousePainter oldDelegate) =>
      oldDelegate.t != t;
}
