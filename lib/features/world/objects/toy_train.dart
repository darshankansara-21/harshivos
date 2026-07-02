import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A chubby, cheerful cartoon steam locomotive sitting on a short bit of track.
/// Wheels rotate, a big round headlight glows, and white puffs of steam rise,
/// expand and fade from the funnel in a loop. Gentle chug bob keeps it alive
/// even idle. Passive art only (no gestures).
class ToyTrainObject extends StatefulWidget {
  const ToyTrainObject({super.key});

  @override
  State<ToyTrainObject> createState() => _ToyTrainObjectState();
}

class _ToyTrainObjectState extends State<ToyTrainObject>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ToyTrainPainter(t: _controller.value),
        );
      },
    );
  }
}

class _ToyTrainPainter extends CustomPainter {
  _ToyTrainPainter({required this.t});

  /// Normalized animation phase in [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    const tau = math.pi * 2;

    // Gentle chug bob — the whole loco rocks slightly up/down.
    final bob = math.sin(t * tau * 2) * s * 0.012;
    final tilt = math.sin(t * tau * 2 + math.pi / 2) * 0.015;

    // ---- Grounding shadow -------------------------------------------------
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + s * 0.34),
        width: s * 0.74,
        height: s * 0.14,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.045),
    );

    // ---- Track (drawn before the train) ----------------------------------
    _drawTrack(canvas, center, s);

    // ---- Steam puffs (behind the funnel reads fine over background) ------
    _drawSteam(canvas, Offset(center.dx - s * 0.18, center.dy - s * 0.18 + bob), s);

    // ---- The locomotive (with chug bob + slight tilt) --------------------
    canvas.save();
    canvas.translate(center.dx, center.dy + bob);
    canvas.rotate(tilt);
    canvas.translate(-center.dx, -center.dy);
    _drawLoco(canvas, center, s);
    canvas.restore();
  }

  // -----------------------------------------------------------------------
  void _drawTrack(Canvas canvas, Offset center, double s) {
    final railY = center.dy + s * 0.265;
    final left = center.dx - s * 0.40;
    final right = center.dx + s * 0.40;

    // Sleepers (ties).
    final tiePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB07A4A), Color(0xFF8A5A30)],
      ).createShader(Rect.fromLTRB(left, railY, right, railY + s * 0.06));
    const ties = 6;
    for (var i = 0; i < ties; i++) {
      final x = left + (right - left) * (i + 0.5) / ties;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, railY + s * 0.018),
            width: s * 0.05,
            height: s * 0.055,
          ),
          Radius.circular(s * 0.01),
        ),
        tiePaint,
      );
    }

    // Two rails.
    final railPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD9DEE5), Color(0xFF9AA3AE)],
      ).createShader(Rect.fromLTRB(left, railY - s * 0.01, right, railY + s * 0.03))
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, railY), Offset(right, railY), railPaint);
    canvas.drawLine(
      Offset(left, railY + s * 0.035),
      Offset(right, railY + s * 0.035),
      railPaint,
    );
  }

  // -----------------------------------------------------------------------
  void _drawLoco(Canvas canvas, Offset center, double s) {
    const tau = math.pi * 2;

    // Wheels first (behind body), so the body overlaps the tops.
    final wheelY = center.dy + s * 0.20;
    final spin = t * tau * 2; // rotation phase
    _drawWheel(canvas, Offset(center.dx - s * 0.16, wheelY), s * 0.075, spin, s);
    _drawWheel(canvas, Offset(center.dx + s * 0.02, wheelY), s * 0.075, spin, s);
    _drawWheel(
      canvas,
      Offset(center.dx + s * 0.185, wheelY),
      s * 0.105,
      spin,
      s,
    ); // big drive wheel

    // ---- Cabin (blue) -----------------------------------------------------
    final cabinRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(
        center.dx - s * 0.24,
        center.dy - s * 0.16,
        center.dx - s * 0.02,
        center.dy + s * 0.16,
      ),
      topLeft: Radius.circular(s * 0.06),
      topRight: Radius.circular(s * 0.04),
      bottomLeft: Radius.circular(s * 0.02),
      bottomRight: Radius.circular(s * 0.02),
    );
    canvas.drawRRect(
      cabinRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4FA9E0), Color(0xFF2C6FB0)],
        ).createShader(cabinRect.outerRect),
    );
    // Cabin gloss.
    canvas.drawRRect(
      cabinRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(cabinRect.outerRect),
    );
    // Cabin window.
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - s * 0.13, center.dy - s * 0.055),
        width: s * 0.12,
        height: s * 0.10,
      ),
      Radius.circular(s * 0.025),
    );
    canvas.drawRRect(
      windowRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8FBFF), Color(0xFFA9D8EC)],
        ).createShader(windowRect.outerRect),
    );
    canvas.drawRRect(
      windowRect,
      Paint()
        ..color = const Color(0xFF1E5688)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012,
    );

    // ---- Boiler (red rounded cylinder) -----------------------------------
    final boilerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        center.dx - s * 0.05,
        center.dy - s * 0.085,
        center.dx + s * 0.30,
        center.dy + s * 0.16,
      ),
      Radius.circular(s * 0.11),
    );
    canvas.drawRRect(
      boilerRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6B5E), Color(0xFFD8362B)],
        ).createShader(boilerRect.outerRect),
    );
    // Boiler top gloss / rim light.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          center.dx - s * 0.04,
          center.dy - s * 0.08,
          center.dx + s * 0.29,
          center.dy - s * 0.01,
        ),
        Radius.circular(s * 0.04),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromLTRB(
            center.dx - s * 0.04,
            center.dy - s * 0.08,
            center.dx + s * 0.29,
            center.dy - s * 0.01,
          ),
        ),
    );
    // Boiler front face (smokebox).
    final faceCenter = Offset(center.dx + s * 0.30, center.dy + s * 0.038);
    canvas.drawCircle(
      faceCenter,
      s * 0.108,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFF7A6E), Color(0xFFC22E24)],
        ).createShader(Rect.fromCircle(center: faceCenter, radius: s * 0.108)),
    );

    // Gold bands around the boiler.
    final bandPaint = Paint()
      ..color = const Color(0xFFFFD54A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016;
    canvas.drawLine(
      Offset(center.dx + s * 0.10, center.dy - s * 0.075),
      Offset(center.dx + s * 0.10, center.dy + s * 0.15),
      bandPaint,
    );

    // ---- Headlight (glowing) ---------------------------------------------
    final glowPulse = 0.6 + 0.4 * math.sin(t * tau * 2);
    final lightCenter = Offset(center.dx + s * 0.30, center.dy + s * 0.005);
    canvas.drawCircle(
      lightCenter,
      s * 0.075 * (1.4 + glowPulse * 0.3),
      Paint()
        ..color = const Color(0xFFFFF1A8).withValues(alpha: 0.45 * glowPulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
    );
    canvas.drawCircle(
      lightCenter,
      s * 0.05,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFDE7), Color(0xFFFFC93C)],
        ).createShader(Rect.fromCircle(center: lightCenter, radius: s * 0.05)),
    );
    canvas.drawCircle(
      lightCenter,
      s * 0.05,
      Paint()
        ..color = const Color(0xFFFFD54A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.01,
    );
    // Headlight glint.
    canvas.drawCircle(
      Offset(lightCenter.dx - s * 0.015, lightCenter.dy - s * 0.018),
      s * 0.013,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // ---- Funnel / chimney (yellow) ---------------------------------------
    final funnelBase = Offset(center.dx - s * 0.18, center.dy - s * 0.085);
    final funnel = Path()
      ..moveTo(funnelBase.dx - s * 0.045, funnelBase.dy)
      ..lineTo(funnelBase.dx - s * 0.06, funnelBase.dy - s * 0.085)
      ..quadraticBezierTo(
        funnelBase.dx,
        funnelBase.dy - s * 0.115,
        funnelBase.dx + s * 0.06,
        funnelBase.dy - s * 0.085,
      )
      ..lineTo(funnelBase.dx + s * 0.045, funnelBase.dy)
      ..close();
    canvas.drawPath(
      funnel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54A), Color(0xFFEAA21E)],
        ).createShader(funnel.getBounds()),
    );
    // Funnel rim.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(funnelBase.dx, funnelBase.dy - s * 0.085),
        width: s * 0.125,
        height: s * 0.03,
      ),
      Paint()..color = const Color(0xFFFFE89A),
    );

    // ---- Steam dome (little gold dome on the boiler) ---------------------
    final domeCenter = Offset(center.dx + s * 0.07, center.dy - s * 0.085);
    canvas.drawArc(
      Rect.fromCircle(center: domeCenter, radius: s * 0.05),
      math.pi,
      math.pi,
      false,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE07A), Color(0xFFE0A41E)],
        ).createShader(Rect.fromCircle(center: domeCenter, radius: s * 0.05)),
    );

    // ---- Cow-catcher (front, yellow) -------------------------------------
    final catcher = Path()
      ..moveTo(center.dx + s * 0.30, center.dy + s * 0.12)
      ..lineTo(center.dx + s * 0.36, center.dy + s * 0.225)
      ..lineTo(center.dx + s * 0.27, center.dy + s * 0.225)
      ..close();
    canvas.drawPath(
      catcher,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD54A), Color(0xFFE0A41E)],
        ).createShader(catcher.getBounds()),
    );

    // Subtle outer glow around whole loco.
    canvas.drawRRect(
      boilerRect,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.0),
    );
  }

  // -----------------------------------------------------------------------
  void _drawWheel(
    Canvas canvas,
    Offset c,
    double r,
    double spin,
    double s,
  ) {
    // Tyre.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF4A4F57), Color(0xFF23262B)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Hub.
    canvas.drawCircle(c, r * 0.42, Paint()..color = const Color(0xFFE7B53B));
    canvas.drawCircle(
      c,
      r * 0.42,
      Paint()
        ..color = const Color(0xFFB07F1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.006,
    );

    // Rotating spokes.
    final spokePaint = Paint()
      ..color = const Color(0xFFF1CB5A)
      ..strokeWidth = s * 0.012
      ..strokeCap = StrokeCap.round;
    const spokes = 6;
    for (var i = 0; i < spokes; i++) {
      final a = spin + i * (math.pi * 2 / spokes);
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r * 0.40, c.dy + math.sin(a) * r * 0.40),
        Offset(c.dx + math.cos(a) * r * 0.80, c.dy + math.sin(a) * r * 0.80),
        spokePaint,
      );
    }
    // Center cap.
    canvas.drawCircle(c, r * 0.16, Paint()..color = const Color(0xFF7A5512));
    // Glossy highlight.
    canvas.drawCircle(
      Offset(c.dx - r * 0.35, c.dy - r * 0.4),
      r * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  // -----------------------------------------------------------------------
  void _drawSteam(Canvas canvas, Offset funnelTop, double s) {
    const puffs = 5;
    for (var i = 0; i < puffs; i++) {
      final seed = i / puffs;
      final life = (t * 1.2 + seed) % 1.0;
      // Rise up and drift slightly.
      final x = funnelTop.dx - life * s * 0.10 + math.sin(life * 6 + i) * s * 0.02;
      final y = funnelTop.dy - life * s * 0.30;
      final grow = 0.4 + life * 1.1;
      final r = s * 0.05 * grow;
      final alpha = (1.0 - life) * 0.85;
      // Layered cloud blobs for a fluffy puff.
      final base = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012);
      canvas.drawCircle(Offset(x, y), r, base);
      canvas.drawCircle(Offset(x - r * 0.6, y + r * 0.2), r * 0.7, base);
      canvas.drawCircle(Offset(x + r * 0.6, y + r * 0.15), r * 0.65, base);
      canvas.drawCircle(Offset(x, y - r * 0.55), r * 0.6, base);
      // Soft top highlight.
      canvas.drawCircle(
        Offset(x - r * 0.25, y - r * 0.3),
        r * 0.35,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ToyTrainPainter oldDelegate) =>
      oldDelegate.t != t;
}
