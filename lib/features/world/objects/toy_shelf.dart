import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small floating wooden shelf holding a row of glossy fidget toys: a
/// colorful pop-it, a continuously spinning fidget spinner, and a glossy
/// Rubik-ish cube. Soft shadows, gentle glow — a tactile "pick me up" object
/// representing a box of antistress toys.
class FidgetShelfObject extends StatefulWidget {
  const FidgetShelfObject({super.key});

  @override
  State<FidgetShelfObject> createState() => _FidgetShelfObjectState();
}

class _FidgetShelfObjectState extends State<FidgetShelfObject>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
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
          painter: _FidgetShelfPainter(t: _controller.value),
        );
      },
    );
  }
}

class _FidgetShelfPainter extends CustomPainter {
  _FidgetShelfPainter({required this.t});

  /// Animation phase in the range [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Gentle floating bob.
    final bob = math.sin(t * 2 * math.pi) * s * 0.014;

    canvas.save();
    canvas.translate(cx, cy + bob);

    _paintGroundShadow(canvas, s);
    _paintShelf(canvas, s);

    // Toys sit on the shelf top surface.
    final toyBaseY = -s * 0.05;
    _paintToyShadow(canvas, Offset(-s * 0.26, toyBaseY), s * 0.16, s);
    _paintToyShadow(canvas, Offset(0, toyBaseY), s * 0.17, s);
    _paintToyShadow(canvas, Offset(s * 0.26, toyBaseY), s * 0.15, s);

    _paintPopIt(canvas, Offset(-s * 0.26, toyBaseY - s * 0.10), s);
    _paintSpinner(canvas, Offset(0, toyBaseY - s * 0.11), s);
    _paintCube(canvas, Offset(s * 0.26, toyBaseY - s * 0.11), s);

    canvas.restore();
  }

  void _paintGroundShadow(Canvas canvas, double s) {
    final shadowRect = Rect.fromCenter(
      center: Offset(0, s * 0.34),
      width: s * 0.70,
      height: s * 0.13,
    );
    final shadow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.26),
          Colors.black.withValues(alpha: 0.0),
        ],
      ).createShader(shadowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawOval(shadowRect, shadow);
  }

  void _paintShelf(Canvas canvas, double s) {
    final topY = -s * 0.05;
    final w = s * 0.78;
    final thick = s * 0.07;

    // Front face.
    final front = Rect.fromLTRB(-w / 2, topY, w / 2, topY + thick);
    canvas.drawRRect(
      RRect.fromRectAndRadius(front, Radius.circular(thick * 0.35)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFC78A52),
            Color(0xFF9A5A2C),
            Color(0xFF6B3F1E),
          ],
        ).createShader(front),
    );

    // Top surface (slightly lighter, perspective lip).
    final top = Path()
      ..moveTo(-w / 2, topY)
      ..lineTo(w / 2, topY)
      ..lineTo(w / 2 - s * 0.03, topY - s * 0.035)
      ..lineTo(-w / 2 + s * 0.03, topY - s * 0.035)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE7B988), Color(0xFFC78A52)],
        ).createShader(
          Rect.fromLTRB(-w / 2, topY - s * 0.035, w / 2, topY),
        ),
    );

    // Top highlight edge.
    canvas.drawLine(
      Offset(-w / 2 + s * 0.03, topY - s * 0.035),
      Offset(w / 2 - s * 0.03, topY - s * 0.035),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = s * 0.006,
    );

    // Wood grain lines on the front face.
    final grain = Paint()
      ..color = const Color(0xFF5A3318).withValues(alpha: 0.35)
      ..strokeWidth = s * 0.004;
    for (var i = 1; i <= 2; i++) {
      final gy = topY + thick * (i / 3);
      canvas.drawLine(
        Offset(-w / 2 + s * 0.02, gy),
        Offset(w / 2 - s * 0.02, gy),
        grain,
      );
    }

    // Soft inviting glow behind the shelf.
    canvas.drawCircle(
      Offset(0, topY - s * 0.12),
      s * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE9B0).withValues(alpha: 0.18),
            const Color(0xFFFFE9B0).withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(
              center: Offset(0, topY - s * 0.12), radius: s * 0.42),
        ),
    );
  }

  void _paintToyShadow(Canvas canvas, Offset center, double width, double s) {
    final rect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + s * 0.006),
      width: width,
      height: width * 0.34,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _paintPopIt(Canvas canvas, Offset center, double s) {
    final w = s * 0.20;
    final h = s * 0.17;
    final body = Rect.fromCenter(center: center, width: w, height: h);
    final rr = RRect.fromRectAndRadius(body, Radius.circular(h * 0.32));

    // Soft pastel base plate.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC1E3), Color(0xFFFF7FB6)],
        ).createShader(body),
    );
    // Rim light.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.006
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    // Grid of bubble domes with rainbow tint + shimmer.
    const cols = 3;
    const rows = 3;
    final cellW = w * 0.78 / cols;
    final cellH = h * 0.78 / rows;
    final startX = center.dx - cellW * (cols - 1) / 2;
    final startY = center.dy - cellH * (rows - 1) / 2;
    const palette = [
      Color(0xFFFF6B6B),
      Color(0xFFFFB14E),
      Color(0xFFFFE66D),
      Color(0xFF6BCB77),
      Color(0xFF4D96FF),
      Color(0xFF9D6BFF),
      Color(0xFFFF6FB5),
      Color(0xFF4EC8C8),
      Color(0xFFFFA3D7),
    ];
    final domeR = math.min(cellW, cellH) * 0.42;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        final pos = Offset(startX + c * cellW, startY + r * cellH);
        final shimmer =
            0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + idx * 0.8);
        final base = palette[idx % palette.length];
        canvas.drawCircle(
          pos,
          domeR,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.4),
              colors: [
                Color.lerp(base, Colors.white, 0.55 + shimmer * 0.25)!,
                base,
                Color.lerp(base, Colors.black, 0.25)!,
              ],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(Rect.fromCircle(center: pos, radius: domeR)),
        );
        // Tiny specular dot.
        canvas.drawCircle(
          Offset(pos.dx - domeR * 0.3, pos.dy - domeR * 0.3),
          domeR * 0.22,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4 + shimmer * 0.35),
        );
      }
    }
  }

  void _paintSpinner(Canvas canvas, Offset center, double s) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Continuous spin.
    canvas.rotate(t * 2 * math.pi * 2);

    final armR = s * 0.085;
    final lobeR = s * 0.045;
    const lobeColors = [
      Color(0xFF4D96FF),
      Color(0xFFFF6B6B),
      Color(0xFF6BCB77),
    ];

    // Three lobes at 120 degrees.
    for (var i = 0; i < 3; i++) {
      final a = i * 2 * math.pi / 3;
      final pos = Offset(math.cos(a) * armR, math.sin(a) * armR);
      final col = lobeColors[i];
      canvas.drawCircle(
        pos,
        lobeR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [
              Color.lerp(col, Colors.white, 0.5)!,
              col,
              Color.lerp(col, Colors.black, 0.3)!,
            ],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: pos, radius: lobeR)),
      );
      // Bearing dot in each lobe.
      canvas.drawCircle(
        pos,
        lobeR * 0.4,
        Paint()..color = const Color(0xFF2A2A30),
      );
      canvas.drawCircle(
        pos,
        lobeR * 0.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.004
          ..color = Colors.white.withValues(alpha: 0.4),
      );
    }

    // Connecting body between lobes.
    final bodyPath = Path();
    for (var i = 0; i < 3; i++) {
      final a = i * 2 * math.pi / 3;
      final pos = Offset(math.cos(a) * armR, math.sin(a) * armR);
      if (i == 0) {
        bodyPath.moveTo(pos.dx, pos.dy);
      } else {
        bodyPath.lineTo(pos.dx, pos.dy);
      }
    }
    bodyPath.close();
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0xFFEDEDF2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lobeR * 1.1
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Center hub.
    canvas.drawCircle(
      Offset.zero,
      lobeR * 0.85,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFF5F5F8), Color(0xFF9AA0AA)],
        ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: lobeR * 0.85),
        ),
    );
    canvas.drawCircle(
      Offset.zero,
      lobeR * 0.4,
      Paint()..color = const Color(0xFF3A3A42),
    );
    canvas.drawCircle(
      Offset(-lobeR * 0.2, -lobeR * 0.2),
      lobeR * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );

    canvas.restore();
  }

  void _paintCube(Canvas canvas, Offset center, double s) {
    final half = s * 0.075;

    // Top face (parallelogram).
    final lift = half * 0.55;
    final top = Path()
      ..moveTo(center.dx, center.dy - half - lift)
      ..lineTo(center.dx + half, center.dy - half * 0.5 - lift)
      ..lineTo(center.dx, center.dy - lift)
      ..lineTo(center.dx - half, center.dy - half * 0.5 - lift)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF0A6), Color(0xFFFFD23F)],
        ).createShader(
          Rect.fromCenter(
              center: Offset(center.dx, center.dy - half - lift),
              width: half * 2,
              height: half),
        ),
    );

    // Left face.
    final left = Path()
      ..moveTo(center.dx - half, center.dy - half * 0.5 - lift)
      ..lineTo(center.dx, center.dy - lift)
      ..lineTo(center.dx, center.dy + half - lift)
      ..lineTo(center.dx - half, center.dy + half * 0.5 - lift)
      ..close();
    canvas.drawPath(
      left,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6B6B), Color(0xFFC23B3B)],
        ).createShader(
          Rect.fromLTRB(center.dx - half, center.dy - lift, center.dx,
              center.dy + half - lift),
        ),
    );

    // Right face.
    final right = Path()
      ..moveTo(center.dx + half, center.dy - half * 0.5 - lift)
      ..lineTo(center.dx, center.dy - lift)
      ..lineTo(center.dx, center.dy + half - lift)
      ..lineTo(center.dx + half, center.dy + half * 0.5 - lift)
      ..close();
    canvas.drawPath(
      right,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4D96FF), Color(0xFF2C5FB3)],
        ).createShader(
          Rect.fromLTRB(center.dx, center.dy - lift, center.dx + half,
              center.dy + half - lift),
        ),
    );

    // Cube grid lines (3x3 sticker grooves) on each visible face.
    final groove = Paint()
      ..color = const Color(0xFF1E1E24).withValues(alpha: 0.45)
      ..strokeWidth = s * 0.004
      ..style = PaintingStyle.stroke;

    // Left face divisions.
    for (var i = 1; i < 3; i++) {
      final f = i / 3;
      canvas.drawLine(
        Offset.lerp(
            Offset(center.dx - half, center.dy - half * 0.5 - lift),
            Offset(center.dx, center.dy - lift),
            f)!,
        Offset.lerp(
            Offset(center.dx - half, center.dy + half * 0.5 - lift),
            Offset(center.dx, center.dy + half - lift),
            f)!,
        groove,
      );
      canvas.drawLine(
        Offset.lerp(
            Offset(center.dx - half, center.dy - half * 0.5 - lift),
            Offset(center.dx - half, center.dy + half * 0.5 - lift),
            f)!,
        Offset.lerp(Offset(center.dx, center.dy - lift),
            Offset(center.dx, center.dy + half - lift), f)!,
        groove,
      );
    }
    // Right face divisions.
    for (var i = 1; i < 3; i++) {
      final f = i / 3;
      canvas.drawLine(
        Offset.lerp(Offset(center.dx, center.dy - lift),
            Offset(center.dx + half, center.dy - half * 0.5 - lift), f)!,
        Offset.lerp(Offset(center.dx, center.dy + half - lift),
            Offset(center.dx + half, center.dy + half * 0.5 - lift), f)!,
        groove,
      );
      canvas.drawLine(
        Offset.lerp(Offset(center.dx, center.dy - lift),
            Offset(center.dx, center.dy + half - lift), f)!,
        Offset.lerp(
            Offset(center.dx + half, center.dy - half * 0.5 - lift),
            Offset(center.dx + half, center.dy + half * 0.5 - lift),
            f)!,
        groove,
      );
    }

    // Top-edge highlight for a glossy plastic look.
    canvas.drawLine(
      Offset(center.dx - half, center.dy - half * 0.5 - lift),
      Offset(center.dx, center.dy - half - lift),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = s * 0.005,
    );
  }

  @override
  bool shouldRepaint(covariant _FidgetShelfPainter oldDelegate) =>
      oldDelegate.t != t;
}
