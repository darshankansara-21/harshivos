import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// PICO — Hari's small companion.
// ---------------------------------------------------------------------------
// A warm, procedurally-drawn puppy (no image assets) with genuine behavioural
// states. Pico is never wallpaper: he reacts, celebrates, and quietly sits
// with the child during calm moments. Drop [PicoWidget] into any square box.
// ---------------------------------------------------------------------------

/// Pico's emotional/behavioural state. Drives eyes, ears, mouth, tail and body.
enum PicoMood {
  happy,
  excited,
  curious,
  sleepy,
  calm,
  celebrating,
  worried,
  comforting,
}

/// The animated companion. Breathes, blinks, and wags with the [mood].
class PicoWidget extends StatefulWidget {
  const PicoWidget({
    super.key,
    this.mood = PicoMood.happy,
    this.animate = true,
    this.furColor = const Color(0xFFF2B45A),
    this.bandanaColor = const Color(0xFF3AA0FF),
  });

  final PicoMood mood;
  final bool animate;
  final Color furColor;
  final Color bandanaColor;

  @override
  State<PicoWidget> createState() => _PicoWidgetState();
}

class _PicoWidgetState extends State<PicoWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant PicoWidget old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
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
        painter: _PicoPainter(
          mood: widget.mood,
          t: _c.value,
          fur: widget.furColor,
          bandana: widget.bandanaColor,
        ),
      ),
    );
  }
}

class _PicoPainter extends CustomPainter {
  _PicoPainter({
    required this.mood,
    required this.t,
    required this.fur,
    required this.bandana,
  });

  final PicoMood mood;
  final double t;
  final Color fur;
  final Color bandana;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final wobble = math.sin(t * math.pi * 2);

    // Per-mood body language.
    final excited = mood == PicoMood.excited || mood == PicoMood.celebrating;
    final bounceAmp = excited ? 0.03 : (mood == PicoMood.sleepy ? 0.004 : 0.014);
    final bounce = wobble * s * bounceAmp;
    final lying = mood == PicoMood.sleepy;

    final cy = size.height / 2 + bounce + (lying ? s * 0.08 : 0);
    final headR = s * 0.22;
    final headC = Offset(cx, cy - s * 0.05);

    _shadow(canvas, Offset(cx, cy + s * 0.30), s, excited);
    _tail(canvas, cx, cy, s);
    _body(canvas, cx, cy, s, lying);
    _bandana(canvas, cx, cy, s);
    _ears(canvas, headC, headR);
    _head(canvas, headC, headR);
    _face(canvas, headC, headR);
    _extras(canvas, headC, headR, s);
  }

  Color _lighten(Color c, double a) => Color.lerp(c, Colors.white, a)!;
  Color _darken(Color c, double a) => Color.lerp(c, Colors.black, a)!;

  void _shadow(Canvas canvas, Offset c, double s, bool excited) {
    canvas.drawOval(
      Rect.fromCenter(
          center: c, width: s * (excited ? 0.34 : 0.4), height: s * 0.08),
      Paint()
        ..color = Colors.black.withOpacity(0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.025),
    );
  }

  void _body(Canvas canvas, double cx, double cy, double s, bool lying) {
    final bodyC = Offset(cx, cy + s * 0.16);
    final rect = lying
        ? Rect.fromCenter(center: bodyC, width: s * 0.44, height: s * 0.22)
        : Rect.fromCenter(center: bodyC, width: s * 0.32, height: s * 0.30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(s * 0.14)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 1.1,
          colors: <Color>[_lighten(fur, 0.16), fur, _darken(fur, 0.10)],
        ).createShader(rect),
    );
    // Little front paws.
    final pawY = rect.bottom - s * 0.02;
    for (final dx in <double>[-s * 0.08, s * 0.08]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + dx, pawY), width: s * 0.11, height: s * 0.07),
        Paint()..color = _lighten(fur, 0.10),
      );
    }
  }

  void _bandana(Canvas canvas, double cx, double cy, double s) {
    final neckY = cy + s * 0.045;
    final path = Path()
      ..moveTo(cx - s * 0.16, neckY)
      ..quadraticBezierTo(cx, neckY + s * 0.05, cx + s * 0.16, neckY)
      ..lineTo(cx + s * 0.13, neckY + s * 0.03)
      ..quadraticBezierTo(cx, neckY + s * 0.08, cx - s * 0.13, neckY + s * 0.03)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: <Color>[_lighten(bandana, 0.15), _darken(bandana, 0.08)],
          ).createShader(path.getBounds()));
    // Knot + a tiny heart tag.
    canvas.drawCircle(
        Offset(cx - s * 0.12, neckY + s * 0.01), s * 0.03, Paint()..color = bandana);
    _heart(canvas, Offset(cx, neckY + s * 0.02), s * 0.028,
        Colors.white.withOpacity(0.95));
  }

  void _tail(Canvas canvas, double cx, double cy, double s) {
    // Wag speed rises with excitement.
    final speed = switch (mood) {
      PicoMood.excited || PicoMood.celebrating => 12.0,
      PicoMood.happy => 7.0,
      PicoMood.curious => 4.0,
      PicoMood.sleepy => 0.6,
      _ => 2.5,
    };
    final wag = math.sin(t * math.pi * speed) * s * 0.10;
    final base = Offset(cx + s * 0.15, cy + s * 0.16);
    final tip = Offset(base.dx + s * 0.14, base.dy - s * 0.10 + wag);
    final mid = Offset(base.dx + s * 0.14, base.dy + wag * 0.4);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy),
      Paint()
        ..color = fur
        ..strokeWidth = s * 0.06
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(tip, s * 0.045, Paint()..color = _lighten(fur, 0.12));
  }

  void _ears(Canvas canvas, Offset c, double r) {
    // Curious raises one ear; worried/sleepy droop both.
    final droop = switch (mood) {
      PicoMood.worried || PicoMood.sleepy => 1.0,
      PicoMood.comforting || PicoMood.calm => 0.5,
      _ => 0.15,
    };
    final flop = math.sin(t * math.pi * 2) * r * 0.05;
    _ear(canvas, c, r, left: true, droop: droop, flop: flop);
    final rightDroop = mood == PicoMood.curious ? -0.3 : droop;
    _ear(canvas, c, r, left: false, droop: rightDroop, flop: -flop);
  }

  void _ear(Canvas canvas, Offset c, double r,
      {required bool left, required double droop, required double flop}) {
    final dir = left ? -1.0 : 1.0;
    final top = Offset(c.dx + dir * r * 0.72, c.dy - r * 0.55);
    final drop = r * (0.6 + droop * 0.7);
    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(c.dx + dir * r * 1.15, c.dy - r * 0.1 + flop,
          c.dx + dir * r * 0.85, c.dy + drop + flop)
      ..quadraticBezierTo(c.dx + dir * r * 0.45, c.dy + drop * 0.7 + flop,
          c.dx + dir * r * 0.4, c.dy - r * 0.35)
      ..close();
    canvas.drawPath(path, Paint()..color = _darken(fur, 0.14));
    canvas.drawPath(
      path,
      Paint()
        ..color = _darken(fur, 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.02,
    );
  }

  void _head(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCenter(center: c, width: r * 2, height: r * 1.9);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.05,
          colors: <Color>[_lighten(fur, 0.18), fur],
        ).createShader(rect),
    );
    // Muzzle.
    final muzzle =
        Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.42), width: r * 1.05, height: r * 0.8);
    canvas.drawOval(muzzle, Paint()..color = _lighten(fur, 0.22));
  }

  void _face(Canvas canvas, Offset c, double r) {
    final blink = t > 0.93 && t < 0.98;
    final closed = mood == PicoMood.sleepy || blink;
    final eyeDx = r * 0.42;
    final eyeY = c.dy - r * 0.05;

    // Brows for worried/comforting.
    if (mood == PicoMood.worried || mood == PicoMood.comforting) {
      final bp = Paint()
        ..color = _darken(fur, 0.35)
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final sign in <double>[-1, 1]) {
        canvas.drawLine(
          Offset(c.dx + sign * eyeDx - r * 0.12, eyeY - r * 0.34),
          Offset(c.dx + sign * eyeDx + r * 0.12, eyeY - r * 0.24),
          bp,
        );
      }
    }

    for (final sign in <double>[-1, 1]) {
      final center = Offset(c.dx + sign * eyeDx, eyeY);
      if (closed) {
        canvas.drawArc(
          Rect.fromCenter(center: center, width: r * 0.34, height: r * 0.2),
          0.15,
          math.pi - 0.3,
          false,
          Paint()
            ..color = const Color(0xFF2A211A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.06
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final wide = mood == PicoMood.curious || mood == PicoMood.excited;
        final eyeR = r * (wide ? 0.26 : 0.22);
        canvas.drawCircle(center, eyeR, Paint()..color = Colors.white);
        final look = switch (mood) {
          PicoMood.curious => const Offset(0.10, -0.06),
          PicoMood.worried => const Offset(0, 0.10),
          PicoMood.comforting => Offset(0, 0.04),
          _ => Offset(math.sin(t * math.pi * 2) * 0.05, 0),
        };
        final pc = center + Offset(look.dx * r, look.dy * r);
        canvas.drawCircle(pc, eyeR * 0.62, Paint()..color = const Color(0xFF241A12));
        canvas.drawCircle(pc + Offset(-eyeR * 0.25, -eyeR * 0.3), eyeR * 0.28,
            Paint()..color = Colors.white.withOpacity(0.95));
      }
    }

    // Nose.
    final nose = Offset(c.dx, c.dy + r * 0.18);
    canvas.drawOval(
      Rect.fromCenter(center: nose, width: r * 0.3, height: r * 0.22),
      Paint()..color = const Color(0xFF2A211C),
    );
    canvas.drawCircle(nose + Offset(-r * 0.05, -r * 0.05), r * 0.04,
        Paint()..color = Colors.white.withOpacity(0.8));

    _mouth(canvas, Offset(c.dx, c.dy + r * 0.42), r);

    // Cheeks for warm moods.
    if (mood == PicoMood.happy ||
        mood == PicoMood.excited ||
        mood == PicoMood.celebrating ||
        mood == PicoMood.comforting) {
      final blush = Paint()
        ..color = const Color(0xFFFF9BB0).withOpacity(0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
      canvas.drawCircle(Offset(c.dx - r * 0.62, c.dy + r * 0.28), r * 0.13, blush);
      canvas.drawCircle(Offset(c.dx + r * 0.62, c.dy + r * 0.28), r * 0.13, blush);
    }
  }

  void _mouth(Canvas canvas, Offset c, double r) {
    final line = Paint()
      ..color = const Color(0xFF2A211C)
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final open = mood == PicoMood.excited ||
        mood == PicoMood.celebrating ||
        mood == PicoMood.happy;
    // Nose bridge to mouth.
    canvas.drawLine(Offset(c.dx, c.dy - r * 0.18), Offset(c.dx, c.dy), line);
    if (open) {
      final rect = Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.04), width: r * 0.4, height: r * 0.34);
      canvas.drawArc(rect, 0.1, math.pi - 0.2, false, line);
      // Tongue.
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx, c.dy + r * 0.16), width: r * 0.2, height: r * 0.18),
        Paint()..color = const Color(0xFFF07A82),
      );
    } else if (mood == PicoMood.worried) {
      canvas.drawArc(
          Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.12), width: r * 0.3, height: r * 0.2),
          math.pi + 0.2, math.pi - 0.4, false, line);
    } else {
      // Gentle w-smile.
      canvas.drawArc(
          Rect.fromCenter(center: Offset(c.dx - r * 0.09, c.dy), width: r * 0.2, height: r * 0.16),
          0.1, math.pi - 0.2, false, line);
      canvas.drawArc(
          Rect.fromCenter(center: Offset(c.dx + r * 0.09, c.dy), width: r * 0.2, height: r * 0.16),
          0.1, math.pi - 0.2, false, line);
    }
  }

  void _extras(Canvas canvas, Offset headC, double headR, double s) {
    switch (mood) {
      case PicoMood.sleepy:
        final z = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: s * 0.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        z.paint(canvas,
            Offset(headC.dx + headR * 0.7, headC.dy - headR - (t * s * 0.18)));
        break;
      case PicoMood.excited:
      case PicoMood.celebrating:
        _sparkle(canvas, Offset(headC.dx + headR * 0.9, headC.dy - headR * 0.6), s * 0.05);
        _sparkle(canvas, Offset(headC.dx - headR * 0.95, headC.dy - headR * 0.2), s * 0.035);
        break;
      case PicoMood.comforting:
        _heart(canvas, Offset(headC.dx + headR * 0.95, headC.dy - headR * 0.55),
            s * 0.05, const Color(0xFFFF6B9D));
        break;
      default:
        break;
    }
  }

  void _sparkle(Canvas canvas, Offset c, double size) {
    final pulse = 0.6 + 0.4 * math.sin(t * math.pi * 6);
    final p = Paint()..color = Colors.white.withOpacity(0.9 * pulse);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - size)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + size, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + size)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - size, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - size)
        ..close(),
      p,
    );
  }

  void _heart(Canvas canvas, Offset c, double size, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + size * 0.38)
      ..cubicTo(c.dx - size * 1.05, c.dy - size * 0.30, c.dx - size * 0.5,
          c.dy - size * 1.05, c.dx, c.dy - size * 0.34)
      ..cubicTo(c.dx + size * 0.5, c.dy - size * 1.05, c.dx + size * 1.05,
          c.dy - size * 0.30, c.dx, c.dy + size * 0.38)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PicoPainter old) =>
      old.t != t || old.mood != mood || old.fur != fur || old.bandana != bandana;
}
