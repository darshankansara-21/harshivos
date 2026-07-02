import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A premium, fully self-contained animated "magical world" object for
/// HarshivOS: a wise, friendly owl perched on a glowing reading lamp.
///
/// Represents the "Parent Copilot" helper — cozy, intelligent and reassuring.
/// The owl breathes softly, tilts its head, blinks occasionally, a warm lamp
/// glow pulses behind it and tiny fireflies drift nearby. Passive art only.
class OwlLampObject extends StatefulWidget {
  const OwlLampObject({super.key});

  @override
  State<OwlLampObject> createState() => _OwlLampObjectState();
}

class _OwlLampObjectState extends State<OwlLampObject>
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
          painter: _OwlLampPainter(t: _controller.value),
        );
      },
    );
  }
}

class _OwlLampPainter extends CustomPainter {
  _OwlLampPainter({required this.t});

  /// Normalised animation time in [0, 1), repeating.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = Offset(size.width / 2, size.height / 2);

    // Derived animation phases.
    const double tau = math.pi * 2;
    final double breathe = math.sin(t * tau); // -1..1, slow body breathing
    final double sway = math.sin(t * tau * 0.5); // head tilt / sway
    final double glowPulse = 0.5 + 0.5 * math.sin(t * tau); // 0..1 lamp glow

    // Occasional blink: a short closed window inside the cycle.
    final double blinkPhase = (t * 2.0) % 1.0;
    final double blink = blinkPhase > 0.92
        ? math.sin(((blinkPhase - 0.92) / 0.08) * math.pi).clamp(0.0, 1.0)
        : 0.0; // 0 = open, 1 = fully closed

    // Layout anchors relative to shortest side.
    final double bodyCx = c.dx;
    final double bodyCy = c.dy + s * 0.04 + breathe * s * 0.006;

    _paintGlow(canvas, Offset(bodyCx, bodyCy - s * 0.06), s, glowPulse);
    _paintGroundShadow(canvas, size, s, breathe);
    _paintLamp(canvas, size, s, bodyCx);
    _paintOwl(canvas, Offset(bodyCx, bodyCy), s, breathe, sway, blink);
    _paintFireflies(canvas, size, s);
  }

  // ---------------------------------------------------------------------------
  // Warm lamp glow halo behind the owl.
  // ---------------------------------------------------------------------------
  void _paintGlow(Canvas canvas, Offset center, double s, double pulse) {
    final double r = s * (0.46 + pulse * 0.05);
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Color.lerp(
            const Color(0x00FFE6A8),
            const Color(0x66FFD27A),
            0.6 + pulse * 0.4,
          )!,
          const Color(0x33FFCC70),
          const Color(0x00FFCC70),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, glow);
  }

  // ---------------------------------------------------------------------------
  // Soft grounding shadow near the bottom.
  // ---------------------------------------------------------------------------
  void _paintGroundShadow(Canvas canvas, Size size, double s, double breathe) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.5 + s * 0.42;
    final double w = s * (0.40 + breathe * 0.01);
    final double h = s * 0.075;
    final Rect rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: w * 2,
      height: h * 2,
    );
    final Paint shadow = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0x44101830), Color(0x00101830)],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(rect, shadow);
  }

  // ---------------------------------------------------------------------------
  // The glowing reading lamp / perch the owl sits on.
  // ---------------------------------------------------------------------------
  void _paintLamp(Canvas canvas, Size size, double s, double cx) {
    final double baseY = size.height * 0.5 + s * 0.40;

    // Lamp base (rounded pill).
    final RRect base = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, baseY),
        width: s * 0.42,
        height: s * 0.085,
      ),
      Radius.circular(s * 0.05),
    );
    final Paint basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF3C5A6E), Color(0xFF21333F)],
      ).createShader(base.outerRect);
    canvas.drawRRect(base, basePaint);

    // Base glossy highlight.
    final RRect baseGloss = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, baseY - s * 0.022),
        width: s * 0.34,
        height: s * 0.03,
      ),
      Radius.circular(s * 0.02),
    );
    canvas.drawRRect(baseGloss, Paint()..color = const Color(0x55BFEAF5));

    // Lamp stem rising to the perch under the owl.
    final double stemTop = size.height * 0.5 + s * 0.18;
    final RRect stem = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        cx - s * 0.028,
        stemTop,
        cx + s * 0.028,
        baseY - s * 0.02,
      ),
      Radius.circular(s * 0.03),
    );
    final Paint stemPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[Color(0xFF4E6E83), Color(0xFF2B414F)],
      ).createShader(stem.outerRect);
    canvas.drawRRect(stem, stemPaint);

    // Glowing lamp bulb / perch knob just under the owl's feet.
    final Offset bulb = Offset(cx, stemTop);
    final Paint bulbGlow = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0x88FFE9A8), Color(0x00FFE9A8)],
      ).createShader(Rect.fromCircle(center: bulb, radius: s * 0.12));
    canvas.drawCircle(bulb, s * 0.12, bulbGlow);

    final Paint bulbPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: <Color>[Color(0xFFFFF6D8), Color(0xFFFFD27A)],
      ).createShader(Rect.fromCircle(center: bulb, radius: s * 0.055));
    canvas.drawCircle(bulb, s * 0.055, bulbPaint);
  }

  // ---------------------------------------------------------------------------
  // The owl: body, belly, wings, head, ears, eyes, beak.
  // ---------------------------------------------------------------------------
  void _paintOwl(
    Canvas canvas,
    Offset center,
    double s,
    double breathe,
    double sway,
    double blink,
  ) {
    canvas.save();

    // Subtle breathing scale around the owl's centre.
    final double scale = 1.0 + breathe * 0.018;
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-center.dx, -center.dy);

    final double bodyW = s * 0.34;
    final double bodyH = s * 0.40;
    final Offset bodyC = Offset(center.dx, center.dy + s * 0.02);

    // --- Body (warm brown teardrop) ---
    final Rect bodyRect = Rect.fromCenter(
      center: bodyC,
      width: bodyW,
      height: bodyH,
    );
    final Path body = Path()..addOval(bodyRect);
    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF8A6240), Color(0xFF5E3E28)],
      ).createShader(bodyRect);
    canvas.drawPath(body, bodyPaint);

    // Teal feather sheen on lower body.
    final Paint sheen = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: <Color>[Color(0x553E8C8C), Color(0x003E8C8C)],
      ).createShader(bodyRect);
    canvas.drawPath(body, sheen);

    // --- Cream belly ---
    final Rect bellyRect = Rect.fromCenter(
      center: Offset(bodyC.dx, bodyC.dy + s * 0.03),
      width: bodyW * 0.62,
      height: bodyH * 0.66,
    );
    final Paint bellyPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.2),
        colors: <Color>[Color(0xFFFFF3DC), Color(0xFFF0D7AE)],
      ).createShader(bellyRect);
    canvas.drawOval(bellyRect, bellyPaint);

    // Layered feather scallops on the belly.
    _paintFeatherScallops(canvas, bellyRect, s);

    // --- Wings (folded, side teardrops) ---
    _paintWing(canvas, bodyC, bodyW, bodyH, s, left: true);
    _paintWing(canvas, bodyC, bodyW, bodyH, s, left: false);

    // Soft inner shadow at the top of the body where the head sits.
    final Rect innerShadowRect = Rect.fromCenter(
      center: Offset(bodyC.dx, bodyC.dy - bodyH * 0.32),
      width: bodyW * 0.9,
      height: bodyH * 0.4,
    );
    canvas.drawOval(
      innerShadowRect,
      Paint()
        ..color = const Color(0x33301B10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );

    // --- Head (tilts with sway) ---
    final double headTilt = sway * 0.10; // radians
    final Offset headC = Offset(center.dx, center.dy - s * 0.18);
    canvas.save();
    canvas.translate(headC.dx, headC.dy);
    canvas.rotate(headTilt);
    canvas.translate(-headC.dx, -headC.dy);

    _paintHead(canvas, headC, s, blink);

    canvas.restore();

    // Rim light along the owl's upper-left edge.
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0x99FFF1C8), Color(0x00FFF1C8)],
      ).createShader(bodyRect);
    canvas.drawArc(
      bodyRect.deflate(s * 0.006),
      math.pi * 1.05,
      math.pi * 0.7,
      false,
      rim,
    );

    canvas.restore();
  }

  void _paintFeatherScallops(Canvas canvas, Rect belly, double s) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.006
      ..color = const Color(0x33B98C5A)
      ..strokeCap = StrokeCap.round;
    for (int row = 0; row < 3; row++) {
      final double y = belly.top + belly.height * (0.32 + row * 0.22);
      final double span = belly.width * (0.7 - row * 0.06);
      final int count = 3 + row;
      final double step = span / count;
      final Path p = Path();
      for (int i = 0; i <= count; i++) {
        final double x = belly.center.dx - span / 2 + step * i;
        if (i == 0) {
          p.moveTo(x, y);
        }
        p.arcToPoint(
          Offset(x + step, y),
          radius: Radius.circular(step * 0.55),
          clockwise: false,
        );
      }
      canvas.drawPath(p, line);
    }
  }

  void _paintWing(
    Canvas canvas,
    Offset bodyC,
    double bodyW,
    double bodyH,
    double s, {
    required bool left,
  }) {
    final double dir = left ? -1.0 : 1.0;
    final Rect wingRect = Rect.fromCenter(
      center: Offset(bodyC.dx + dir * bodyW * 0.40, bodyC.dy + s * 0.01),
      width: bodyW * 0.34,
      height: bodyH * 0.78,
    );
    final Paint wingPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF6E4A30), Color(0xFF49301E)],
      ).createShader(wingRect);
    canvas.drawOval(wingRect, wingPaint);

    // Glossy highlight on the wing's outer edge.
    final Paint wingGloss = Paint()
      ..shader = LinearGradient(
        begin: left ? Alignment.centerRight : Alignment.centerLeft,
        end: left ? Alignment.centerLeft : Alignment.centerRight,
        colors: const <Color>[Color(0x55FFE6B0), Color(0x00FFE6B0)],
      ).createShader(wingRect);
    canvas.drawOval(wingRect.deflate(s * 0.004), wingGloss);
  }

  void _paintHead(Canvas canvas, Offset headC, double s, double blink) {
    final double headR = s * 0.20;
    final Rect headRect = Rect.fromCircle(center: headC, radius: headR);

    // Tufted ears.
    final Paint earPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF7A5436), Color(0xFF553720)],
      ).createShader(headRect);
    for (final double dir in <double>[-1.0, 1.0]) {
      final Path ear = Path();
      final Offset baseO = Offset(
        headC.dx + dir * headR * 0.62,
        headC.dy - headR * 0.55,
      );
      ear.moveTo(baseO.dx - dir * headR * 0.18, baseO.dy + headR * 0.16);
      ear.quadraticBezierTo(
        baseO.dx + dir * headR * 0.10,
        baseO.dy - headR * 0.55,
        baseO.dx + dir * headR * 0.30,
        baseO.dy - headR * 0.05,
      );
      ear.close();
      canvas.drawPath(ear, earPaint);
    }

    // Head dome.
    final Paint headPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: <Color>[Color(0xFF9A6E47), Color(0xFF63432B)],
      ).createShader(headRect);
    canvas.drawCircle(headC, headR, headPaint);

    // Teal sheen across the crown.
    final Paint crownSheen = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0x553E8C8C), Color(0x003E8C8C)],
      ).createShader(headRect);
    canvas.drawCircle(headC, headR, crownSheen);

    // Facial disc (lighter heart-shaped area framing the eyes).
    final Rect discRect = Rect.fromCenter(
      center: Offset(headC.dx, headC.dy + headR * 0.12),
      width: headR * 1.5,
      height: headR * 1.4,
    );
    final Paint disc = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0xFFF6E2C2), Color(0xFFD9BC95)],
      ).createShader(discRect);
    canvas.drawOval(discRect, disc);

    // Eyes.
    final double eyeDx = headR * 0.42;
    final double eyeY = headC.dy + headR * 0.02;
    _paintEye(canvas, Offset(headC.dx - eyeDx, eyeY), headR, s, blink);
    _paintEye(canvas, Offset(headC.dx + eyeDx, eyeY), headR, s, blink);

    // Beak (small warm triangle between/below eyes).
    final Offset beakTop = Offset(headC.dx, headC.dy + headR * 0.34);
    final Path beak = Path()
      ..moveTo(beakTop.dx - headR * 0.10, beakTop.dy)
      ..lineTo(beakTop.dx + headR * 0.10, beakTop.dy)
      ..lineTo(beakTop.dx, beakTop.dy + headR * 0.22)
      ..close();
    final Paint beakPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFFFC24E), Color(0xFFE8941F)],
      ).createShader(beak.getBounds());
    canvas.drawPath(beak, beakPaint);

    // Glossy top highlight on the head.
    final Rect glossRect = Rect.fromCenter(
      center: Offset(headC.dx - headR * 0.3, headC.dy - headR * 0.45),
      width: headR * 0.8,
      height: headR * 0.5,
    );
    canvas.drawOval(
      glossRect,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0x88FFF6DC), Color(0x00FFF6DC)],
        ).createShader(glossRect),
    );
  }

  void _paintEye(
    Canvas canvas,
    Offset eyeC,
    double headR,
    double s,
    double blink,
  ) {
    final double eyeR = headR * 0.34;

    // Outer eye ring.
    canvas.drawCircle(
      eyeC,
      eyeR * 1.12,
      Paint()..color = const Color(0xFF4A3320),
    );

    // White of the eye.
    final Rect eyeRect = Rect.fromCircle(center: eyeC, radius: eyeR);
    final Paint white = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.3),
        colors: <Color>[Color(0xFFFFFFFF), Color(0xFFE7EEF2)],
      ).createShader(eyeRect);
    canvas.drawCircle(eyeC, eyeR, white);

    // Iris + pupil (only meaningfully visible when eye is open).
    final double openFactor = (1.0 - blink).clamp(0.0, 1.0);
    if (openFactor > 0.05) {
      final double irisR = eyeR * 0.66;
      final Rect irisRect = Rect.fromCircle(center: eyeC, radius: irisR);
      final Paint iris = Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0xFF2C7A78), Color(0xFF12413F)],
        ).createShader(irisRect);
      canvas.drawCircle(eyeC, irisR, iris);
      canvas.drawCircle(eyeC, irisR * 0.5, Paint()..color = const Color(0xFF0A1A19));

      // Catchlight sparkle.
      canvas.drawCircle(
        Offset(eyeC.dx - irisR * 0.3, eyeC.dy - irisR * 0.35),
        eyeR * 0.16,
        Paint()..color = const Color(0xCCFFFFFF),
      );
    }

    // Blinking eyelid: warm feathered lid drops from the top.
    if (blink > 0.01) {
      final double lidH = eyeR * 2 * blink;
      final Rect lidRect = Rect.fromLTWH(
        eyeC.dx - eyeR * 1.14,
        eyeC.dy - eyeR * 1.14,
        eyeR * 2.28,
        lidH + eyeR * 0.14,
      );
      final Paint lid = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF8A6240), Color(0xFF6E4A30)],
        ).createShader(lidRect);
      canvas.save();
      canvas.clipPath(Path()..addOval(eyeRect.inflate(eyeR * 0.12)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(lidRect, Radius.circular(eyeR * 0.4)),
        lid,
      );
      canvas.restore();
    }
  }

  // ---------------------------------------------------------------------------
  // Tiny drifting fireflies.
  // ---------------------------------------------------------------------------
  void _paintFireflies(Canvas canvas, Size size, double s) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    const double tau = math.pi * 2;

    final List<List<double>> seeds = <List<double>>[
      <double>[0.0, 0.34, -0.30, 0.9],
      <double>[0.45, 0.28, 0.34, 1.4],
    ];

    for (final List<double> seed in seeds) {
      final double phase = (t + seed[0]) % 1.0;
      final double orbit = seed[1];
      final double baseX = seed[2];
      final double speed = seed[3];
      final double angle = phase * tau * speed;
      final double fx = cx + (baseX + 0.12 * math.cos(angle)) * s;
      final double fy = cy - s * 0.10 + math.sin(angle * 1.3) * s * orbit * 0.5;
      final double twinkle = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(angle * 2.0));

      final Offset f = Offset(fx, fy);
      canvas.drawCircle(
        f,
        s * 0.05,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Color.fromRGBO(255, 235, 150, 0.85 * twinkle),
              const Color(0x00FFEB96),
            ],
          ).createShader(Rect.fromCircle(center: f, radius: s * 0.05)),
      );
      canvas.drawCircle(
        f,
        s * 0.012,
        Paint()..color = Color.fromRGBO(255, 248, 210, twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OwlLampPainter oldDelegate) =>
      oldDelegate.t != t;
}
