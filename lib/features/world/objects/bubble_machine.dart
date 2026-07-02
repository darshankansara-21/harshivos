import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A glossy pastel bubble-making machine that continuously blows a stream of
/// iridescent soap bubbles. Passive, always-animating art object intended to be
/// placed inside a roughly-square host box (90–220 logical px per side).
class BubbleMachineObject extends StatefulWidget {
  const BubbleMachineObject({super.key});

  @override
  State<BubbleMachineObject> createState() => _BubbleMachineObjectState();
}

class _BubbleMachineObjectState extends State<BubbleMachineObject>
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
          painter: _BubbleMachinePainter(t: _controller.value),
        );
      },
    );
  }
}

/// Stable per-bubble personality so each bubble keeps its size/phase across
/// frames while looping smoothly.
class _BubbleSpec {
  const _BubbleSpec({
    required this.phase,
    required this.radius,
    required this.drift,
    required this.wobbleAmp,
    required this.wobbleFreq,
    required this.hue,
  });

  final double phase; // 0..1 offset into the rise loop
  final double radius; // fraction of shortestSide
  final double drift; // horizontal lateral offset fraction
  final double wobbleAmp; // horizontal wobble amplitude fraction
  final double wobbleFreq; // wobble cycles per rise
  final double hue; // base soap-film hue 0..360
}

class _BubbleMachinePainter extends CustomPainter {
  _BubbleMachinePainter({required this.t});

  final double t;

  static const List<_BubbleSpec> _bubbles = <_BubbleSpec>[
    _BubbleSpec(
        phase: 0.00,
        radius: 0.075,
        drift: -0.04,
        wobbleAmp: 0.05,
        wobbleFreq: 2.0,
        hue: 200),
    _BubbleSpec(
        phase: 0.13,
        radius: 0.050,
        drift: 0.06,
        wobbleAmp: 0.04,
        wobbleFreq: 2.6,
        hue: 290),
    _BubbleSpec(
        phase: 0.27,
        radius: 0.090,
        drift: 0.01,
        wobbleAmp: 0.06,
        wobbleFreq: 1.7,
        hue: 150),
    _BubbleSpec(
        phase: 0.40,
        radius: 0.045,
        drift: -0.08,
        wobbleAmp: 0.03,
        wobbleFreq: 3.1,
        hue: 50),
    _BubbleSpec(
        phase: 0.52,
        radius: 0.065,
        drift: 0.09,
        wobbleAmp: 0.05,
        wobbleFreq: 2.2,
        hue: 330),
    _BubbleSpec(
        phase: 0.64,
        radius: 0.055,
        drift: -0.02,
        wobbleAmp: 0.045,
        wobbleFreq: 2.8,
        hue: 180),
    _BubbleSpec(
        phase: 0.76,
        radius: 0.082,
        drift: 0.05,
        wobbleAmp: 0.055,
        wobbleFreq: 1.9,
        hue: 250),
    _BubbleSpec(
        phase: 0.88,
        radius: 0.048,
        drift: -0.06,
        wobbleAmp: 0.035,
        wobbleFreq: 3.4,
        hue: 100),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset center = Offset(size.width / 2, size.height / 2);

    _paintGroundShadow(canvas, size, s, center);

    // Geometry anchors (all relative to shortestSide).
    final double bodyW = s * 0.62;
    final double bodyH = s * 0.42;
    final double bodyTop = center.dy + s * 0.02;
    final Rect bodyRect = Rect.fromLTWH(
      center.dx - bodyW / 2,
      bodyTop,
      bodyW,
      bodyH,
    );
    final double funnelTopY = bodyTop - s * 0.20;
    final Offset funnelMouth = Offset(center.dx, funnelTopY);

    // Bubbles rise from the funnel mouth toward the top of the box. Paint them
    // first so the machine body overlaps the lowest (emerging) ones.
    _paintBubbles(canvas, size, s, funnelMouth);

    _paintFeet(canvas, s, bodyRect);
    _paintFunnel(canvas, s, center, bodyTop, funnelMouth);
    _paintBody(canvas, s, bodyRect);
    _paintKnobs(canvas, s, bodyRect);
  }

  void _paintGroundShadow(Canvas canvas, Size size, double s, Offset center) {
    final double shadowW = s * 0.66;
    final double shadowH = s * 0.10;
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + s * 0.44),
      width: shadowW,
      height: shadowH,
    );
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05);
    canvas.drawOval(shadowRect, shadowPaint);
  }

  void _paintBubbles(Canvas canvas, Size size, double s, Offset mouth) {
    final double riseTop = size.height * 0.06;
    final double riseSpan = mouth.dy - riseTop;
    if (riseSpan <= 0) return;

    for (final _BubbleSpec spec in _bubbles) {
      final double p = (t + spec.phase) % 1.0;
      // Ease-out near the top so bubbles appear to slow and drift.
      final double eased = 1 - math.pow(1 - p, 1.6).toDouble();
      final double y = mouth.dy - eased * riseSpan;

      final double wobble =
          math.sin((p * spec.wobbleFreq + spec.phase) * math.pi * 2) *
              spec.wobbleAmp *
              s;
      final double x = mouth.dx + spec.drift * s * p + wobble;

      // Bubbles grow slightly as they detach, then fade near the top.
      final double grow = 0.55 + 0.45 * math.min(1.0, p * 4);
      final double r = spec.radius * s * grow;

      double alpha = 1.0;
      if (p < 0.06) {
        alpha = p / 0.06; // spawn fade-in
      } else if (p > 0.78) {
        alpha = (1 - p) / 0.22; // fade out near top
      }
      alpha = alpha.clamp(0.0, 1.0);
      if (alpha <= 0.01 || r <= 0.5) continue;

      _paintBubble(canvas, Offset(x, y), r, spec.hue, alpha);
    }
  }

  void _paintBubble(
      Canvas canvas, Offset c, double r, double hue, double alpha) {
    final Rect bounds = Rect.fromCircle(center: c, radius: r);

    // Iridescent soap-film body: a sweep of soft rainbow tints.
    final Paint film = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: <Color>[
          HSVColor.fromAHSV(0.55 * alpha, hue % 360, 0.45, 1.0).toColor(),
          HSVColor.fromAHSV(0.45 * alpha, (hue + 60) % 360, 0.40, 1.0).toColor(),
          HSVColor.fromAHSV(0.50 * alpha, (hue + 140) % 360, 0.45, 1.0)
              .toColor(),
          HSVColor.fromAHSV(0.40 * alpha, (hue + 220) % 360, 0.40, 1.0)
              .toColor(),
          HSVColor.fromAHSV(0.55 * alpha, hue % 360, 0.45, 1.0).toColor(),
        ],
      ).createShader(bounds);
    canvas.drawCircle(c, r, film);

    // Radial depth: brighter rim, translucent core.
    final Paint depth = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withOpacity(0.02 * alpha),
          Colors.white.withOpacity(0.10 * alpha),
          Colors.white.withOpacity(0.42 * alpha),
        ],
        stops: const <double>[0.0, 0.72, 1.0],
      ).createShader(bounds);
    canvas.drawCircle(c, r, depth);

    // Thin bright rim (surface tension highlight).
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10
      ..color = Colors.white.withOpacity(0.55 * alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06);
    canvas.drawCircle(c, r * 0.94, rim);

    // Specular highlight dot (top-left).
    final Offset spec = Offset(c.dx - r * 0.34, c.dy - r * 0.38);
    final Paint specPaint = Paint()
      ..color = Colors.white.withOpacity(0.92 * alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04);
    canvas.drawCircle(spec, r * 0.16, specPaint);

    // Small secondary glint (bottom-right).
    final Offset glint = Offset(c.dx + r * 0.30, c.dy + r * 0.30);
    canvas.drawCircle(
      glint,
      r * 0.07,
      Paint()..color = Colors.white.withOpacity(0.45 * alpha),
    );
  }

  void _paintFeet(Canvas canvas, double s, Rect body) {
    final double footW = s * 0.10;
    final double footH = s * 0.07;
    final double footY = body.bottom - footH * 0.4;
    final Paint footPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF3FA9B8),
          Color(0xFF2A7E8C),
        ],
      ).createShader(Rect.fromLTWH(0, footY, s, footH));

    for (final double fx in <double>[
      body.left + body.width * 0.22,
      body.right - body.width * 0.22,
    ]) {
      final RRect foot = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(fx, footY + footH / 2),
            width: footW,
            height: footH),
        Radius.circular(footH * 0.5),
      );
      canvas.drawRRect(foot, footPaint);
    }
  }

  void _paintFunnel(Canvas canvas, double s, Offset center, double bodyTop,
      Offset mouth) {
    // Trapezoid funnel narrowing from the body to the mouth.
    final double baseHalf = s * 0.11;
    final double mouthHalf = s * 0.075;
    final Path funnel = Path()
      ..moveTo(center.dx - baseHalf, bodyTop + s * 0.02)
      ..lineTo(center.dx - mouthHalf, mouth.dy + s * 0.015)
      ..lineTo(center.dx + mouthHalf, mouth.dy + s * 0.015)
      ..lineTo(center.dx + baseHalf, bodyTop + s * 0.02)
      ..close();

    final Paint funnelPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Color(0xFF7FD4DF),
          Color(0xFFB9EEF3),
          Color(0xFF4FB3C2),
        ],
        stops: <double>[0.0, 0.45, 1.0],
      ).createShader(funnel.getBounds());
    canvas.drawPath(funnel, funnelPaint);

    // Glossy mouth rim (ellipse lip).
    final Rect lip = Rect.fromCenter(
      center: Offset(mouth.dx, mouth.dy + s * 0.01),
      width: mouthHalf * 2,
      height: s * 0.05,
    );
    canvas.drawOval(
      lip,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[
            Color(0xFFEAFBFD),
            Color(0xFF8FDCE7),
          ],
        ).createShader(lip),
    );
    canvas.drawOval(
      lip.deflate(s * 0.012),
      Paint()..color = const Color(0xFF2C6E79).withOpacity(0.55),
    );

    // Left-edge highlight on the funnel.
    final Paint funnelGloss = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..color = Colors.white.withOpacity(0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.01);
    canvas.drawLine(
      Offset(center.dx - baseHalf * 0.8, bodyTop),
      Offset(center.dx - mouthHalf * 0.8, mouth.dy + s * 0.02),
      funnelGloss,
    );
  }

  void _paintBody(Canvas canvas, double s, Rect body) {
    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(s * 0.10));

    // Outer soft glow.
    canvas.drawRRect(
      rr.inflate(s * 0.015),
      Paint()
        ..color = const Color(0xFF7FE3F0).withOpacity(0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04),
    );

    // Main pastel teal/blue body gradient.
    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFA7ECF5),
          Color(0xFF66C6D8),
          Color(0xFF3E97AD),
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(body);
    canvas.drawRRect(rr, bodyPaint);

    // Top glossy sheen.
    final Rect sheenRect = Rect.fromLTWH(
      body.left,
      body.top,
      body.width,
      body.height * 0.5,
    );
    final RRect sheen = RRect.fromRectAndCorners(
      sheenRect,
      topLeft: Radius.circular(s * 0.10),
      topRight: Radius.circular(s * 0.10),
    );
    canvas.drawRRect(
      sheen,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withOpacity(0.55),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(sheenRect),
    );

    // Soft inner shadow along the bottom edge.
    final Rect innerRect = Rect.fromLTWH(
      body.left,
      body.center.dy,
      body.width,
      body.height * 0.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        innerRect,
        bottomLeft: Radius.circular(s * 0.10),
        bottomRight: Radius.circular(s * 0.10),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            const Color(0xFF1F5E6B).withOpacity(0.40),
            Colors.transparent,
          ],
        ).createShader(innerRect),
    );

    // Rim light along the left edge.
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014
      ..color = Colors.white.withOpacity(0.40)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.008);
    final Path leftRim = Path()
      ..moveTo(body.left + s * 0.02, body.top + s * 0.10)
      ..lineTo(body.left + s * 0.02, body.bottom - s * 0.10);
    canvas.drawPath(leftRim, rim);

    // A little decorative window/gauge on the body face.
    final Rect gauge = Rect.fromCenter(
      center: Offset(body.center.dx, body.center.dy + s * 0.02),
      width: body.width * 0.34,
      height: body.height * 0.34,
    );
    final RRect gaugeRR =
        RRect.fromRectAndRadius(gauge, Radius.circular(s * 0.03));
    canvas.drawRRect(
      gaugeRR,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0xFFEFFCFE),
            Color(0xFF9FD9E4),
          ],
        ).createShader(gauge),
    );
    canvas.drawRRect(
      gaugeRR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.01
        ..color = const Color(0xFF2C6E79).withOpacity(0.6),
    );
  }

  void _paintKnobs(Canvas canvas, double s, Rect body) {
    final double knobR = s * 0.05;
    final double knobY = body.bottom - body.height * 0.22;
    for (final double kx in <double>[
      body.left + body.width * 0.18,
      body.right - body.width * 0.18,
    ]) {
      final Offset c = Offset(kx, knobY);
      final Rect kb = Rect.fromCircle(center: c, radius: knobR);
      canvas.drawCircle(
        c,
        knobR,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.4),
            colors: <Color>[
              Color(0xFFFFE7A8),
              Color(0xFFF4B63C),
              Color(0xFFC9821C),
            ],
            stops: <double>[0.0, 0.6, 1.0],
          ).createShader(kb),
      );
      // Knob specular dot.
      canvas.drawCircle(
        Offset(c.dx - knobR * 0.3, c.dy - knobR * 0.35),
        knobR * 0.28,
        Paint()..color = Colors.white.withOpacity(0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubbleMachinePainter oldDelegate) =>
      oldDelegate.t != t;
}
