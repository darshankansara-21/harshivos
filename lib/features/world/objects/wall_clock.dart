import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A friendly pendulum wall clock — a cozy "visual timer" world object.
///
/// A round clock with a warm pastel rounded frame, a clean glowing face,
/// hour/minute/second hands that move smoothly over the animation loop, and a
/// gentle swinging pendulum hanging below. The whole clock gives a soft tick
/// "wobble" so it feels alive while idle. Calm and reassuring.
class WallClockObject extends StatefulWidget {
  const WallClockObject({super.key});

  @override
  State<WallClockObject> createState() => _WallClockObjectState();
}

class _WallClockObjectState extends State<WallClockObject>
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
          painter: _WallClockPainter(t: _controller.value),
        );
      },
    );
  }
}

class _WallClockPainter extends CustomPainter {
  _WallClockPainter({required this.t});

  /// Animation phase in [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    // Keep the clock body roughly square, 90..220px.
    final double box = s.clamp(90.0, 220.0);
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double tau = math.pi * 2;
    // Gentle tick wobble for the whole clock body.
    final double tick = math.sin(t * tau);
    final double wobble = math.sin(t * tau * 8) * 0.012 * (0.4 + 0.6 * tick.abs());

    final double faceR = box * 0.30;
    // The face sits a little above center to leave room for the pendulum.
    final Offset faceCenter = center.translate(0, -box * 0.12);

    // ---- Soft grounding shadow near the bottom ----
    final Offset shadowCenter = Offset(center.dx, faceCenter.dy + box * 0.62);
    final Paint shadowPaint = Paint()
      ..color = const Color(0x33101828)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.save();
    canvas.translate(shadowCenter.dx, shadowCenter.dy);
    canvas.scale(1.0, 0.30);
    canvas.drawCircle(Offset.zero, box * 0.30, shadowPaint);
    canvas.restore();

    // Apply the wobble around the top hanging point.
    final Offset pivot = Offset(faceCenter.dx, faceCenter.dy - faceR * 1.25);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(wobble);
    canvas.translate(-pivot.dx, -pivot.dy);

    // ---- Pendulum (drawn first so the case overlaps the rod top) ----
    _paintPendulum(canvas, faceCenter, faceR, box, tau);

    // ---- Outer rounded frame (warm pastel) ----
    final double frameR = faceR * 1.20;
    final Rect frameRect = Rect.fromCircle(center: faceCenter, radius: frameR);
    final Paint frameGlow = Paint()
      ..color = const Color(0x33F6B26B)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, box * 0.05);
    canvas.drawCircle(faceCenter, frameR * 1.02, frameGlow);

    final Paint framePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFF8C58E),
          Color(0xFFE39B5C),
          Color(0xFFC9783C),
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(frameRect);
    canvas.drawCircle(faceCenter, frameR, framePaint);

    // Frame rim-light highlight.
    final Paint rimLight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = frameR * 0.10
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: const <Color>[
          Color(0x00FFFFFF),
          Color(0x88FFF3E2),
          Color(0x00FFFFFF),
        ],
        stops: const <double>[0.0, 0.18, 0.42],
        transform: const GradientRotation(-math.pi * 0.75),
      ).createShader(frameRect);
    canvas.drawCircle(faceCenter, frameR * 0.94, rimLight);

    // ---- Clock face ----
    final Rect faceRect = Rect.fromCircle(center: faceCenter, radius: faceR);
    final Paint facePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        radius: 1.1,
        colors: <Color>[
          Color(0xFFFFFDF7),
          Color(0xFFFDF1DC),
          Color(0xFFF3E2C4),
        ],
        stops: <double>[0.0, 0.6, 1.0],
      ).createShader(faceRect);
    canvas.drawCircle(faceCenter, faceR, facePaint);

    // Inner soft shadow ring on the face.
    final Paint faceRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = faceR * 0.05
      ..color = const Color(0x22A06A2E);
    canvas.drawCircle(faceCenter, faceR * 0.96, faceRing);

    // ---- Ticks and glowing numerals ----
    _paintTicksAndNumerals(canvas, faceCenter, faceR, tau);

    // ---- Hands ----
    // Smoothly rotate over the loop. Minute = one full turn per loop, hour =
    // 1/12 of that, second = sweeping fast.
    final double minuteAngle = t * tau;
    final double hourAngle = t * tau / 6.0 + math.pi * 0.3;
    final double secondAngle = t * tau * 6.0;

    _paintHand(
      canvas,
      faceCenter,
      hourAngle,
      faceR * 0.50,
      faceR * 0.055,
      const Color(0xFF3B4252),
    );
    _paintHand(
      canvas,
      faceCenter,
      minuteAngle,
      faceR * 0.74,
      faceR * 0.038,
      const Color(0xFF4C566A),
    );

    // Red sweeping second hand.
    final Paint secondPaint = Paint()
      ..color = const Color(0xFFE85D5D)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = faceR * 0.018;
    final Offset secTip = faceCenter +
        Offset(math.sin(secondAngle), -math.cos(secondAngle)) * faceR * 0.82;
    final Offset secTail = faceCenter -
        Offset(math.sin(secondAngle), -math.cos(secondAngle)) * faceR * 0.20;
    canvas.drawLine(secTail, secTip, secondPaint);

    // Center cap with glow.
    final Paint capGlow = Paint()
      ..color = const Color(0x55E85D5D)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, faceR * 0.06);
    canvas.drawCircle(faceCenter, faceR * 0.10, capGlow);
    final Paint capPaint = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0xFF5A6276), Color(0xFF2E3440)],
      ).createShader(Rect.fromCircle(center: faceCenter, radius: faceR * 0.08));
    canvas.drawCircle(faceCenter, faceR * 0.07, capPaint);
    canvas.drawCircle(
      faceCenter.translate(-faceR * 0.02, -faceR * 0.02),
      faceR * 0.02,
      Paint()..color = const Color(0x88FFFFFF),
    );

    canvas.restore();
  }

  void _paintPendulum(
    Canvas canvas,
    Offset faceCenter,
    double faceR,
    double box,
    double tau,
  ) {
    final Offset hinge = Offset(faceCenter.dx, faceCenter.dy + faceR * 0.55);
    final double rodLen = box * 0.40;
    // Swing left-right around the hinge.
    final double swing = math.sin(t * tau) * 0.32;
    final Offset bob = hinge +
        Offset(math.sin(swing), math.cos(swing)) * rodLen;

    final Paint rodPaint = Paint()
      ..color = const Color(0xFFB68A53)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = box * 0.018;
    canvas.drawLine(hinge, bob, rodPaint);

    final Rect bobRect = Rect.fromCircle(center: bob, radius: box * 0.085);
    final Paint bobGlow = Paint()
      ..color = const Color(0x44FFD27A)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, box * 0.035);
    canvas.drawCircle(bob, box * 0.10, bobGlow);
    final Paint bobPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: <Color>[
          Color(0xFFFFE3A6),
          Color(0xFFF1B85A),
        ],
      ).createShader(bobRect);
    canvas.drawCircle(bob, box * 0.085, bobPaint);
    canvas.drawCircle(
      bob.translate(-box * 0.025, -box * 0.025),
      box * 0.022,
      Paint()..color = const Color(0x99FFFFFF),
    );
  }

  void _paintTicksAndNumerals(
    Canvas canvas,
    Offset faceCenter,
    double faceR,
    double tau,
  ) {
    for (int i = 0; i < 12; i++) {
      final double a = (i / 12.0) * tau;
      final Offset dir = Offset(math.sin(a), -math.cos(a));
      final bool major = i % 3 == 0;
      final Paint tickPaint = Paint()
        ..color = major ? const Color(0xFF7A5A33) : const Color(0x885A4A33)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = major ? faceR * 0.03 : faceR * 0.015;
      final Offset outer = faceCenter + dir * faceR * 0.90;
      final Offset inner =
          faceCenter + dir * faceR * (major ? 0.78 : 0.83);
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Glowing numerals at 12, 3, 6, 9.
    const List<String> labels = <String>['12', '3', '6', '9'];
    for (int i = 0; i < 4; i++) {
      final double a = (i / 4.0) * tau;
      final Offset dir = Offset(math.sin(a), -math.cos(a));
      final Offset pos = faceCenter + dir * faceR * 0.62;
      final double fontSize = faceR * 0.24;

      final TextPainter glow = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: const Color(0x66FFC861),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glow.paint(
        canvas,
        pos - Offset(glow.width / 2, glow.height / 2),
      );

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8A5A22),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintHand(
    Canvas canvas,
    Offset center,
    double angle,
    double length,
    double width,
    Color color,
  ) {
    final Offset dir = Offset(math.sin(angle), -math.cos(angle));
    final Offset tip = center + dir * length;
    final Offset tail = center - dir * (length * 0.22);
    final Paint p = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    canvas.drawLine(tail, tip, p);
  }

  @override
  bool shouldRepaint(_WallClockPainter oldDelegate) => oldDelegate.t != t;
}
