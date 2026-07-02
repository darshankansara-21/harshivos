import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A charming brass-and-teal telescope on a wooden tripod, tilted toward the
/// sky. A specular glint sweeps across the front lens while a gentle trail of
/// twinkling stars streams out and upward — a magical "Play & Explore" object.
class TelescopeObject extends StatefulWidget {
  const TelescopeObject({super.key});

  @override
  State<TelescopeObject> createState() => _TelescopeObjectState();
}

class _TelescopeObjectState extends State<TelescopeObject>
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
          painter: _TelescopePainter(t: _controller.value),
        );
      },
    );
  }
}

class _TelescopePainter extends CustomPainter {
  _TelescopePainter({required this.t});

  /// Animation phase in the range [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Gentle idle bob.
    final bob = math.sin(t * 2 * math.pi) * s * 0.012;

    canvas.save();
    canvas.translate(cx, cy + bob);

    _paintGroundShadow(canvas, s);
    _paintTripod(canvas, s);
    _paintTelescope(canvas, s);
    _paintStarTrail(canvas, s);

    canvas.restore();
  }

  void _paintGroundShadow(Canvas canvas, double s) {
    final shadowRect = Rect.fromCenter(
      center: Offset(0, s * 0.40),
      width: s * 0.52,
      height: s * 0.12,
    );
    final shadow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0.0),
        ],
      ).createShader(shadowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(shadowRect, shadow);
  }

  void _paintTripod(Canvas canvas, double s) {
    // Pivot where the legs meet the telescope mount.
    final pivot = Offset(0, -s * 0.02);
    final legLen = s * 0.42;
    const woodDark = Color(0xFF6B3F1E);
    const woodMid = Color(0xFF9A5A2C);
    const woodLight = Color(0xFFC78A52);

    void leg(double angleDeg) {
      final a = angleDeg * math.pi / 180;
      final end = Offset(
        pivot.dx + math.sin(a) * legLen,
        pivot.dy + math.cos(a) * legLen,
      );
      final dir = end - pivot;
      final len = dir.distance;
      final norm = Offset(-dir.dy / len, dir.dx / len);
      final halfW = s * 0.022;

      final p = Path()
        ..moveTo(pivot.dx + norm.dx * halfW, pivot.dy + norm.dy * halfW)
        ..lineTo(pivot.dx - norm.dx * halfW, pivot.dy - norm.dy * halfW)
        ..lineTo(end.dx - norm.dx * halfW * 0.6, end.dy - norm.dy * halfW * 0.6)
        ..lineTo(end.dx + norm.dx * halfW * 0.6, end.dy + norm.dy * halfW * 0.6)
        ..close();

      final paint = Paint()
        ..shader = const LinearGradient(
          colors: [woodLight, woodMid, woodDark],
        ).createShader(Rect.fromPoints(pivot, end));
      canvas.drawPath(p, paint);

      // Little foot cap.
      canvas.drawCircle(
        end,
        s * 0.018,
        Paint()..color = woodDark,
      );
    }

    leg(-26);
    leg(20);
    leg(2); // center-back leg drawn slightly behind feel via order

    // Mount hub.
    canvas.drawCircle(
      pivot,
      s * 0.05,
      Paint()
        ..shader = const RadialGradient(
          colors: [woodLight, woodDark],
        ).createShader(
          Rect.fromCircle(center: pivot, radius: s * 0.05),
        ),
    );
  }

  void _paintTelescope(Canvas canvas, double s) {
    canvas.save();
    // Mount pivot, tilted up toward the sky.
    canvas.translate(0, -s * 0.02);
    canvas.rotate(-22 * math.pi / 180);

    final bodyLen = s * 0.62;
    final r = s * 0.075; // body radius
    final backX = -bodyLen * 0.42;
    final frontX = bodyLen * 0.58;

    // Brass body gradient (top-lit cylinder).
    final bodyRect = Rect.fromLTRB(backX, -r, frontX, r);
    final brass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFBE3A1),
          Color(0xFFE0A53D),
          Color(0xFFB97A1E),
          Color(0xFF7E4F12),
        ],
        stops: [0.0, 0.35, 0.72, 1.0],
      ).createShader(bodyRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(r)),
      brass,
    );

    // Teal front segment (the wider lens barrel).
    final tealRect = Rect.fromLTRB(frontX - r * 1.6, -r * 1.18, frontX + r * 0.6,
        r * 1.18);
    final teal = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF8FE6E0),
          Color(0xFF2BA9A0),
          Color(0xFF0E6F69),
          Color(0xFF073F3C),
        ],
        stops: [0.0, 0.38, 0.74, 1.0],
      ).createShader(tealRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tealRect, Radius.circular(r * 1.18)),
      teal,
    );

    // Decorative brass rings/bands along the body.
    for (final fx in [0.0, 0.32, 0.62]) {
      final bx = backX + (frontX - backX) * (0.18 + fx * 0.7);
      final ringRect = Rect.fromLTRB(bx - r * 0.10, -r * 1.05, bx + r * 0.10,
          r * 1.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(ringRect, Radius.circular(r * 0.10)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF0C2), Color(0xFFB97A1E)],
          ).createShader(ringRect),
      );
    }

    // Top rim-light highlight running along the body.
    final rimRect = Rect.fromLTRB(backX, -r * 0.78, frontX, -r * 0.42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rimRect, Radius.circular(r * 0.2)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.65),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rimRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Eyepiece at the back.
    final eyeCenter = Offset(backX - r * 0.5, 0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: eyeCenter, width: r * 0.9, height: r * 1.5),
        Radius.circular(r * 0.3),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A3A42), Color(0xFF15151A)],
        ).createShader(
          Rect.fromCenter(
              center: eyeCenter, width: r * 0.9, height: r * 1.5),
        ),
    );

    // Front lens face.
    final lensCenter = Offset(frontX - r * 0.5, 0);
    final lensR = r * 1.05;
    canvas.drawCircle(
      lensCenter,
      lensR,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFF18484F),
            Color(0xFF0B2A2E),
            Color(0xFF02161A),
          ],
        ).createShader(Rect.fromCircle(center: lensCenter, radius: lensR)),
    );
    // Lens rim.
    canvas.drawCircle(
      lensCenter,
      lensR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.18
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFF0C2),
            Color(0xFFB97A1E),
            Color(0xFFFFF0C2),
            Color(0xFFB97A1E),
            Color(0xFFFFF0C2),
          ],
        ).createShader(Rect.fromCircle(center: lensCenter, radius: lensR)),
    );

    // Animated specular glint sweeping across the lens glass.
    final glintPhase = (t * 2) % 1.0;
    final glintX = lensCenter.dx + (glintPhase - 0.5) * 2 * lensR * 0.8;
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(center: lensCenter, radius: lensR * 0.92)));
    final glintRect = Rect.fromCenter(
      center: Offset(glintX, lensCenter.dy),
      width: lensR * 0.5,
      height: lensR * 2.4,
    );
    canvas.drawRect(
      glintRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(glintRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    // Static soft highlight dot on the glass.
    canvas.drawCircle(
      Offset(lensCenter.dx - lensR * 0.34, lensCenter.dy - lensR * 0.34),
      lensR * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    canvas.restore();
  }

  void _paintStarTrail(Canvas canvas, double s) {
    // Origin near the front lens (matching the telescope tilt direction).
    const angle = -22 * math.pi / 180;
    final start = Offset(
      math.cos(angle) * s * 0.34,
      -s * 0.02 + math.sin(angle) * s * 0.34,
    );
    // Stream direction: out and upward.
    final dir = Offset(math.cos(angle), math.sin(angle));
    final perp = Offset(-dir.dy, dir.dx);

    final rnd = math.Random(7);
    const count = 14;
    for (var i = 0; i < count; i++) {
      // Each sparkle advances along the stream, looping.
      final phase = (t + i / count) % 1.0;
      final dist = phase * s * 0.55;
      final wobble = math.sin(phase * 6 * math.pi + i) * s * 0.05;
      final spread = (rnd.nextDouble() - 0.5) * s * 0.06;

      final pos = start +
          dir * dist +
          perp * (wobble + spread) -
          Offset(0, dist * 0.15);

      // Fade in then out across the loop.
      final fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final twinkle =
          0.6 + 0.4 * math.sin(t * 2 * math.pi * 3 + i * 1.7);
      final alpha = (fade * twinkle).clamp(0.0, 1.0);
      final starR = s * (0.006 + 0.010 * (1 - phase)) * (0.6 + twinkle * 0.4);

      // Glow.
      canvas.drawCircle(
        pos,
        starR * 2.4,
        Paint()
          ..color = const Color(0xFFFFF3C4).withValues(alpha: alpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      // 4-point sparkle.
      _drawSparkle(canvas, pos, starR,
          const Color(0xFFFFFBEA).withValues(alpha: alpha));
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    final long = r * 2.2;
    final short = r * 0.55;
    path.moveTo(c.dx, c.dy - long);
    path.lineTo(c.dx + short, c.dy - short);
    path.lineTo(c.dx + long, c.dy);
    path.lineTo(c.dx + short, c.dy + short);
    path.lineTo(c.dx, c.dy + long);
    path.lineTo(c.dx - short, c.dy + short);
    path.lineTo(c.dx - long, c.dy);
    path.lineTo(c.dx - short, c.dy - short);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TelescopePainter oldDelegate) =>
      oldDelegate.t != t;
}
