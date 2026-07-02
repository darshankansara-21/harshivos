import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An adorable Fisher-Price-style pull-along toy phone with a smiley dial face,
/// a slowly rotating rotary dial, a glossy red handset, a pulsing antenna and
/// two wheels. Passive, always-animating art object intended to be placed
/// inside a roughly-square host box (90–220 logical px per side).
class ToyPhoneObject extends StatefulWidget {
  const ToyPhoneObject({super.key});

  @override
  State<ToyPhoneObject> createState() => _ToyPhoneObjectState();
}

class _ToyPhoneObjectState extends State<ToyPhoneObject>
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
          painter: _ToyPhonePainter(t: _controller.value),
        );
      },
    );
  }
}

class _ToyPhonePainter extends CustomPainter {
  _ToyPhonePainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset boxCenter = Offset(size.width / 2, size.height / 2);

    // Gentle idle bob + wobble.
    final double bob = math.sin(t * math.pi * 2) * s * 0.012;
    final double tilt = math.sin(t * math.pi * 2 + 0.6) * 0.025;

    _paintGroundShadow(canvas, size, s, boxCenter, bob);

    canvas.save();
    canvas.translate(boxCenter.dx, boxCenter.dy + bob);
    canvas.rotate(tilt);
    canvas.translate(-boxCenter.dx, -boxCenter.dy);

    // Geometry anchors.
    final double bodyW = s * 0.74;
    final double bodyH = s * 0.50;
    final Rect bodyRect = Rect.fromCenter(
      center: Offset(boxCenter.dx, boxCenter.dy + s * 0.10),
      width: bodyW,
      height: bodyH,
    );

    _paintWheels(canvas, s, bodyRect);
    _paintAntenna(canvas, s, bodyRect, boxCenter);
    _paintHandset(canvas, s, bodyRect);
    _paintBody(canvas, s, bodyRect);
    _paintDial(canvas, s, bodyRect);

    canvas.restore();
  }

  void _paintGroundShadow(
      Canvas canvas, Size size, double s, Offset boxCenter, double bob) {
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(boxCenter.dx, boxCenter.dy + s * 0.42),
      width: s * 0.72 - bob, // shrinks slightly as object rises
      height: s * 0.11,
    );
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05);
    canvas.drawOval(shadowRect, shadowPaint);
  }

  void _paintWheels(Canvas canvas, double s, Rect body) {
    final double wheelR = s * 0.085;
    final double wheelY = body.bottom - s * 0.01;
    for (final double wx in <double>[
      body.left + body.width * 0.24,
      body.right - body.width * 0.24,
    ]) {
      final Offset c = Offset(wx, wheelY);
      final Rect wb = Rect.fromCircle(center: c, radius: wheelR);
      // Tyre.
      canvas.drawCircle(
        c,
        wheelR,
        Paint()
          ..shader = const RadialGradient(
            colors: <Color>[
              Color(0xFF4A4A52),
              Color(0xFF1E1E24),
            ],
          ).createShader(wb),
      );
      // Yellow hub.
      canvas.drawCircle(
        c,
        wheelR * 0.5,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.3),
            colors: <Color>[
              Color(0xFFFFE27A),
              Color(0xFFF2B227),
            ],
          ).createShader(wb),
      );
      canvas.drawCircle(
        c,
        wheelR * 0.16,
        Paint()..color = const Color(0xFF8A5A12),
      );
      // Tyre highlight.
      canvas.drawCircle(
        Offset(c.dx - wheelR * 0.35, c.dy - wheelR * 0.4),
        wheelR * 0.16,
        Paint()..color = Colors.white.withOpacity(0.30),
      );
    }
  }

  void _paintAntenna(Canvas canvas, double s, Rect body, Offset boxCenter) {
    final Offset base = Offset(body.right - body.width * 0.16, body.top);
    final Offset tip = Offset(base.dx + s * 0.10, body.top - s * 0.22);

    final Paint rod = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          Color(0xFF3FB7C4),
          Color(0xFF8FE6EF),
        ],
      ).createShader(Rect.fromPoints(base, tip));
    canvas.drawLine(base, tip, rod);

    // Pulsing glow dot at the tip.
    final double pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2 * 2);
    final double glowR = s * (0.045 + 0.02 * pulse);
    canvas.drawCircle(
      tip,
      glowR * 1.9,
      Paint()
        ..color = const Color(0xFFFFD23F).withOpacity(0.25 + 0.25 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
    );
    canvas.drawCircle(
      tip,
      glowR,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0xFFFFF6C9),
            Color(0xFFFFC02E),
          ],
        ).createShader(Rect.fromCircle(center: tip, radius: glowR)),
    );
    canvas.drawCircle(
      Offset(tip.dx - glowR * 0.3, tip.dy - glowR * 0.3),
      glowR * 0.3,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  void _paintHandset(Canvas canvas, double s, Rect body) {
    // Handset sits across the top of the body. Drawn as a thick curved bar
    // with two bulged ear/mouth pieces.
    final double topY = body.top - s * 0.045;
    final double leftX = body.left + body.width * 0.16;
    final double rightX = body.left + body.width * 0.66;
    final double thick = s * 0.075;

    final Rect hb = Rect.fromLTRB(leftX - thick, topY - thick * 1.4,
        rightX + thick, topY + thick * 1.4);
    final Shader redShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFFFF6B6B),
        Color(0xFFE3322F),
        Color(0xFFB31E1C),
      ],
      stops: <double>[0.0, 0.55, 1.0],
    ).createShader(hb);

    // Curved bar connecting the two ends.
    final Path bar = Path()
      ..moveTo(leftX, topY)
      ..quadraticBezierTo(
        (leftX + rightX) / 2,
        topY - s * 0.10,
        rightX,
        topY,
      );
    final Paint barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round
      ..shader = redShader;
    canvas.drawPath(bar, barPaint);

    // Ear/mouth bulges.
    for (final Offset e in <Offset>[Offset(leftX, topY), Offset(rightX, topY)]) {
      canvas.drawCircle(e, thick * 0.95, Paint()..shader = redShader);
      // Inner ear ring.
      canvas.drawCircle(
        e,
        thick * 0.5,
        Paint()..color = const Color(0xFF8E1614).withOpacity(0.55),
      );
      // Specular highlight.
      canvas.drawCircle(
        Offset(e.dx - thick * 0.35, e.dy - thick * 0.4),
        thick * 0.22,
        Paint()..color = Colors.white.withOpacity(0.7),
      );
      // Thin rim around the ear piece.
      canvas.drawCircle(
        e,
        thick * 0.95,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.006
          ..color = const Color(0xFF7E1210).withOpacity(0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.004),
      );
    }

    // Glossy sheen along the top of the curved bar.
    final Path sheen = Path()
      ..moveTo(leftX, topY - thick * 0.25)
      ..quadraticBezierTo(
        (leftX + rightX) / 2,
        topY - s * 0.10 - thick * 0.25,
        rightX,
        topY - thick * 0.25,
      );
    canvas.drawPath(
      sheen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick * 0.28
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.006),
    );
  }

  void _paintBody(Canvas canvas, double s, Rect body) {
    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(s * 0.13));

    // Outer soft glow.
    canvas.drawRRect(
      rr.inflate(s * 0.015),
      Paint()
        ..color = const Color(0xFFFF6B6B).withOpacity(0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04),
    );

    // Cherry-red body gradient.
    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFFF7A7A),
          Color(0xFFE23330),
          Color(0xFFB01E1C),
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(body);
    canvas.drawRRect(rr, bodyPaint);

    // Top glossy sheen.
    final Rect sheenRect =
        Rect.fromLTWH(body.left, body.top, body.width, body.height * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        sheenRect,
        topLeft: Radius.circular(s * 0.13),
        topRight: Radius.circular(s * 0.13),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withOpacity(0.45),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(sheenRect),
    );

    // Inner shadow at the base.
    final Rect innerRect = Rect.fromLTWH(
      body.left,
      body.center.dy,
      body.width,
      body.height * 0.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        innerRect,
        bottomLeft: Radius.circular(s * 0.13),
        bottomRight: Radius.circular(s * 0.13),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            const Color(0xFF6E0F0D).withOpacity(0.45),
            Colors.transparent,
          ],
        ).createShader(innerRect),
    );

    // Teal accent base strip.
    final Rect strip = Rect.fromLTWH(
      body.left,
      body.bottom - body.height * 0.20,
      body.width,
      body.height * 0.20,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        strip,
        bottomLeft: Radius.circular(s * 0.13),
        bottomRight: Radius.circular(s * 0.13),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF49C2CE),
            Color(0xFF2C8C97),
          ],
        ).createShader(strip),
    );

    // Left rim light.
    canvas.drawPath(
      Path()
        ..moveTo(body.left + s * 0.025, body.top + s * 0.12)
        ..lineTo(body.left + s * 0.025, body.bottom - s * 0.14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.014
        ..color = Colors.white.withOpacity(0.40)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.008),
    );
  }

  void _paintDial(Canvas canvas, double s, Rect body) {
    final Offset c = Offset(body.center.dx, body.center.dy - s * 0.01);
    final double faceR = s * 0.20;
    final Rect fb = Rect.fromCircle(center: c, radius: faceR);

    // Yellow dial face plate.
    canvas.drawCircle(
      c,
      faceR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: <Color>[
            Color(0xFFFFF1B0),
            Color(0xFFFFD23F),
            Color(0xFFE9A91C),
          ],
          stops: <double>[0.0, 0.6, 1.0],
        ).createShader(fb),
    );
    // Face rim.
    canvas.drawCircle(
      c,
      faceR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = const Color(0xFFB9831A).withOpacity(0.7),
    );

    // Rotating rotary ring with finger holes.
    final double rot = t * math.pi * 2; // slow continuous rotation
    final double holeOrbit = faceR * 0.66;
    final double holeR = faceR * 0.11;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    for (int i = 0; i < 10; i++) {
      final double a = (i / 10) * math.pi * 2;
      final Offset h = Offset(math.cos(a) * holeOrbit, math.sin(a) * holeOrbit);
      canvas.drawCircle(
        h,
        holeR,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFB9831A).withOpacity(0.65),
              const Color(0xFF8A6012).withOpacity(0.85),
            ],
          ).createShader(Rect.fromCircle(center: h, radius: holeR)),
      );
    }
    // Finger-stop nub.
    canvas.drawCircle(
      Offset(holeOrbit + holeR * 1.6, 0),
      holeR * 0.5,
      Paint()..color = const Color(0xFF8A6012),
    );
    canvas.restore();

    // Smiley face plate in the centre (above the rotating holes).
    final double smR = faceR * 0.5;
    final Rect smb = Rect.fromCircle(center: c, radius: smR);
    canvas.drawCircle(
      c,
      smR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: <Color>[
            Color(0xFFFFFDF2),
            Color(0xFFFFE9A6),
          ],
        ).createShader(smb),
    );
    canvas.drawCircle(
      c,
      smR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.008
        ..color = const Color(0xFFB9831A).withOpacity(0.5),
    );

    _paintSmiley(canvas, s, c, smR);

    // Top specular sweep on the whole face.
    canvas.drawCircle(
      Offset(c.dx - faceR * 0.3, c.dy - faceR * 0.42),
      faceR * 0.22,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );
  }

  void _paintSmiley(Canvas canvas, double s, Offset c, double r) {
    // Occasional blink: eyes are open most of the time, snapping shut briefly.
    final double cyc = (t * 3) % 1.0; // three blink opportunities per loop
    final bool blinking = cyc > 0.94;
    final double eyeDx = r * 0.42;
    final double eyeDy = -r * 0.22;
    final double eyeR = r * 0.16;

    final Paint ink = Paint()
      ..color = const Color(0xFF3A2A0C)
      ..style = PaintingStyle.fill;
    final Paint inkStroke = Paint()
      ..color = const Color(0xFF3A2A0C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;

    for (final double sx in <double>[-1, 1]) {
      final Offset e = Offset(c.dx + sx * eyeDx, c.dy + eyeDy);
      if (blinking) {
        canvas.drawLine(
          Offset(e.dx - eyeR, e.dy),
          Offset(e.dx + eyeR, e.dy),
          inkStroke,
        );
      } else {
        canvas.drawCircle(e, eyeR, ink);
        // Eye sparkle.
        canvas.drawCircle(
          Offset(e.dx - eyeR * 0.3, e.dy - eyeR * 0.35),
          eyeR * 0.32,
          Paint()..color = Colors.white.withOpacity(0.9),
        );
      }
    }

    // Rosy cheeks.
    for (final double sx in <double>[-1, 1]) {
      canvas.drawCircle(
        Offset(c.dx + sx * r * 0.6, c.dy + r * 0.18),
        r * 0.16,
        Paint()
          ..color = const Color(0xFFFF9AA2).withOpacity(0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
      );
    }

    // Curved smile.
    final Rect smileRect = Rect.fromCenter(
      center: Offset(c.dx, c.dy + r * 0.12),
      width: r * 1.0,
      height: r * 0.9,
    );
    canvas.drawArc(
      smileRect,
      math.pi * 0.15,
      math.pi * 0.70,
      false,
      inkStroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ToyPhonePainter oldDelegate) =>
      oldDelegate.t != t;
}
