import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The living backdrop of the magical world: a cosy treehouse-at-dusk sky with
/// a glowing moon, shimmering aurora ribbons, twinkling stars, drifting
/// fireflies and a warm wooden floor. Everything breathes — nothing is static.
class WorldAmbient extends StatefulWidget {
  const WorldAmbient({super.key});

  @override
  State<WorldAmbient> createState() => _WorldAmbientState();
}

class _WorldAmbientState extends State<WorldAmbient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _AmbientPainter(t: _c.value),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // --- Night sky gradient ---
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF0A0E2A),
          Color(0xFF1A1145),
          Color(0xFF34185C),
          Color(0xFF4A1E54),
        ],
        stops: <double>[0.0, 0.4, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    // --- Moon glow (upper right) ---
    final moonC = Offset(w * 0.80, h * 0.20);
    final moonR = math.min(w, h) * 0.085;
    final moonGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFFFFF6D8).withOpacity(0.9),
          const Color(0xFFFFE9A8).withOpacity(0.25),
          const Color(0x00FFE9A8),
        ],
        stops: const <double>[0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: moonC, radius: moonR * 4));
    canvas.drawCircle(moonC, moonR * 4, moonGlow);
    final moon = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: const <Color>[Color(0xFFFFFDF2), Color(0xFFFCEFC0)],
      ).createShader(Rect.fromCircle(center: moonC, radius: moonR));
    canvas.drawCircle(moonC, moonR, moon);

    // --- Aurora ribbons ---
    _aurora(canvas, size, t);

    // --- Stars (deterministic, twinkling) ---
    final starRnd = math.Random(42);
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 90; i++) {
      final sx = starRnd.nextDouble() * w;
      final sy = starRnd.nextDouble() * h * 0.7;
      final base = 0.4 + starRnd.nextDouble() * 0.6;
      final tw = 0.5 + 0.5 * math.sin((t * 2 + starRnd.nextDouble()) * math.pi * 2);
      final r = (0.6 + starRnd.nextDouble() * 1.6);
      starPaint.color = Colors.white.withOpacity((base * tw).clamp(0.05, 1.0) * 0.9);
      canvas.drawCircle(Offset(sx, sy), r, starPaint);
    }

    // --- Warm floor band ---
    final floorTop = h * 0.82;
    final floor = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0x004A1E54),
          const Color(0xFF3A2140),
          const Color(0xFF2A1530),
        ],
      ).createShader(Rect.fromLTRB(0, floorTop, w, h));
    canvas.drawRect(Rect.fromLTRB(0, floorTop, w, h), floor);

    // --- Fireflies (slow drifting glow dots) ---
    final fRnd = math.Random(11);
    for (int i = 0; i < 16; i++) {
      final seedX = fRnd.nextDouble();
      final seedY = fRnd.nextDouble();
      final speed = 0.3 + fRnd.nextDouble() * 0.7;
      final phase = fRnd.nextDouble() * math.pi * 2;
      final fx = (seedX + math.sin(t * math.pi * 2 * speed + phase) * 0.06) * w;
      final fy = (0.25 + seedY * 0.6 +
              math.cos(t * math.pi * 2 * speed * 0.8 + phase) * 0.05) *
          h;
      final pulse = 0.4 + 0.6 * (0.5 + 0.5 * math.sin((t * 3 + seedX) * math.pi * 2));
      final glow = Paint()
        ..color = const Color(0xFFFFE07A).withOpacity(0.5 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(fx, fy), 5 * pulse, glow);
      canvas.drawCircle(
        Offset(fx, fy),
        1.6,
        Paint()..color = const Color(0xFFFFF6D0).withOpacity(0.9 * pulse),
      );
    }

    // --- Soft vignette ---
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: <Color>[
          const Color(0x00000000),
          Colors.black.withOpacity(0.28),
        ],
        stops: const <double>[0.65, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  void _aurora(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final colors = <Color>[
      const Color(0xFF36E0C0),
      const Color(0xFF7C6CF0),
      const Color(0xFFF06CCB),
    ];
    for (int band = 0; band < 3; band++) {
      final path = Path();
      final yBase = h * (0.14 + band * 0.07);
      final amp = h * (0.04 + band * 0.015);
      final phase = t * math.pi * 2 * (0.4 + band * 0.15) + band;
      path.moveTo(0, yBase);
      for (double x = 0; x <= w; x += w / 32) {
        final y = yBase +
            math.sin(x / w * math.pi * 2 * (1.5 + band * 0.5) + phase) * amp +
            math.sin(x / w * math.pi * 4 + phase * 1.3) * amp * 0.4;
        path.lineTo(x, y);
      }
      path.lineTo(w, yBase + amp * 2.5);
      path.lineTo(0, yBase + amp * 2.5);
      path.close();
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            colors[band].withOpacity(0.22),
            colors[band].withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTRB(0, yBase - amp, w, yBase + amp * 2.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => old.t != t;
}
