import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What the avatar is doing — drives arm/leg posture and any held prop.
enum AvatarPose {
  idle,
  wave,
  brush,
  wash,
  sit,
  eat,
  walk,
  sleep,
  point,
  clap,
  hold,
  cheer,
}

enum HairStyle { short, ponytail, curly, buzz, bun, spiky }

/// A fully customizable, reusable child avatar.
///
/// This is the single source of truth for "who" guides the child through the
/// app. It is intentionally serialisable so a family can save Harshiv's look
/// once and have it appear everywhere — routines, lessons, celebrations.
@immutable
class AvatarConfig {
  const AvatarConfig({
    this.skin = const Color(0xFFF1C9A5),
    this.hair = HairStyle.short,
    this.hairColor = const Color(0xFF3B2A1E),
    this.shirt = const Color(0xFF4CC9F0),
    this.glasses = false,
    this.hearingAid = true,
  });

  final Color skin;
  final HairStyle hair;
  final Color hairColor;
  final Color shirt;
  final bool glasses;

  /// Harshiv wears a hearing device — it is celebrated, never hidden.
  final bool hearingAid;

  static const List<Color> skinTones = <Color>[
    Color(0xFFFFE0BD),
    Color(0xFFF1C9A5),
    Color(0xFFE0AC69),
    Color(0xFFC68642),
    Color(0xFF8D5524),
  ];

  static const List<Color> hairColors = <Color>[
    Color(0xFF1A1A1A),
    Color(0xFF3B2A1E),
    Color(0xFF6B4423),
    Color(0xFFA9712B),
    Color(0xFFD9A441),
    Color(0xFFB5651D),
    Color(0xFF8E8E8E),
  ];

  static const List<Color> shirtColors = <Color>[
    Color(0xFF4CC9F0),
    Color(0xFF06D6A0),
    Color(0xFFEF476F),
    Color(0xFFFFD166),
    Color(0xFF9B5DE5),
    Color(0xFFF15BB5),
    Color(0xFFFF9E00),
  ];

  AvatarConfig copyWith({
    Color? skin,
    HairStyle? hair,
    Color? hairColor,
    Color? shirt,
    bool? glasses,
    bool? hearingAid,
  }) {
    return AvatarConfig(
      skin: skin ?? this.skin,
      hair: hair ?? this.hair,
      hairColor: hairColor ?? this.hairColor,
      shirt: shirt ?? this.shirt,
      glasses: glasses ?? this.glasses,
      hearingAid: hearingAid ?? this.hearingAid,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'skin': skin.value,
        'hair': hair.index,
        'hairColor': hairColor.value,
        'shirt': shirt.value,
        'glasses': glasses,
        'hearingAid': hearingAid,
      };

  factory AvatarConfig.fromJson(Map<String, dynamic> j) {
    return AvatarConfig(
      skin: Color((j['skin'] as num?)?.toInt() ?? 0xFFF1C9A5),
      hair: HairStyle.values[(j['hair'] as num?)?.toInt() ?? 0],
      hairColor: Color((j['hairColor'] as num?)?.toInt() ?? 0xFF3B2A1E),
      shirt: Color((j['shirt'] as num?)?.toInt() ?? 0xFF4CC9F0),
      glasses: j['glasses'] as bool? ?? false,
      hearingAid: j['hearingAid'] as bool? ?? true,
    );
  }
}

/// The animated avatar widget. Drop it anywhere; it breathes, blinks and
/// performs [pose]. Sized to fill its parent (give it a square box).
class AvatarWidget extends StatefulWidget {
  const AvatarWidget({
    super.key,
    required this.config,
    this.pose = AvatarPose.idle,
    this.animate = true,
  });

  final AvatarConfig config;
  final AvatarPose pose;
  final bool animate;

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant AvatarWidget old) {
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
        painter: _AvatarPainter(
          config: widget.config,
          pose: widget.pose,
          t: _c.value,
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter({required this.config, required this.pose, required this.t});
  final AvatarConfig config;
  final AvatarPose pose;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    // Vertical breathing.
    final breathe = math.sin(t * math.pi * 2) * s * 0.012;
    final cy = size.height / 2 + breathe;

    // Layout anchors.
    final headR = s * 0.17;
    final headC = Offset(cx, cy - s * 0.14);
    final bodyTop = headC.dy + headR * 0.78;

    _shadow(canvas, Offset(cx, cy + s * 0.36), s);
    _legs(canvas, cx, bodyTop, s);
    _body(canvas, cx, bodyTop, s);
    _arms(canvas, cx, bodyTop, headC, headR, s);
    _head(canvas, headC, headR, s);
    _hair(canvas, headC, headR, s);
    _face(canvas, headC, headR, s);
    if (config.glasses) _glasses(canvas, headC, headR, s);
    if (config.hearingAid) _hearingAid(canvas, headC, headR, s);
    _prop(canvas, headC, headR, bodyTop, cx, s);
  }

  void _shadow(Canvas canvas, Offset c, double s) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.16)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: s * 0.42, height: s * 0.1),
      paint,
    );
  }

  void _body(Canvas canvas, double cx, double bodyTop, double s) {
    final w = s * 0.30;
    final h = s * 0.30;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w / 2, bodyTop, w, h),
      Radius.circular(s * 0.11),
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          _lighten(config.shirt, 0.16),
          config.shirt,
          _darken(config.shirt, 0.12),
        ],
      ).createShader(rect.outerRect);
    canvas.drawRRect(rect, paint);
    // Soft collar highlight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w / 2, bodyTop, w, h * 0.3),
        Radius.circular(s * 0.11),
      ),
      Paint()..color = Colors.white.withOpacity(0.12),
    );
  }

  void _legs(Canvas canvas, double cx, double bodyTop, double s) {
    final paint = Paint()
      ..color = const Color(0xFF394A66)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.075
      ..style = PaintingStyle.stroke;
    final hipY = bodyTop + s * 0.30;
    double swing = 0;
    if (pose == AvatarPose.walk) {
      swing = math.sin(t * math.pi * 4) * s * 0.05;
    }
    if (pose == AvatarPose.sit) {
      // Folded legs forward.
      canvas.drawLine(Offset(cx - s * 0.07, hipY),
          Offset(cx - s * 0.14, hipY + s * 0.02), paint);
      canvas.drawLine(Offset(cx + s * 0.07, hipY),
          Offset(cx + s * 0.14, hipY + s * 0.02), paint);
      return;
    }
    canvas.drawLine(Offset(cx - s * 0.07, hipY),
        Offset(cx - s * 0.07 + swing, hipY + s * 0.11), paint);
    canvas.drawLine(Offset(cx + s * 0.07, hipY),
        Offset(cx + s * 0.07 - swing, hipY + s * 0.11), paint);
    // Shoes.
    final shoe = Paint()..color = const Color(0xFF1F2A3D);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - s * 0.07 + swing, hipY + s * 0.12),
            width: s * 0.09,
            height: s * 0.05),
        shoe);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + s * 0.07 - swing, hipY + s * 0.12),
            width: s * 0.09,
            height: s * 0.05),
        shoe);
  }

  void _arms(Canvas canvas, double cx, double bodyTop, Offset headC,
      double headR, double s) {
    final paint = Paint()
      ..color = config.skin
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.06
      ..style = PaintingStyle.stroke;
    final shoulderY = bodyTop + s * 0.04;
    final lShoulder = Offset(cx - s * 0.14, shoulderY);
    final rShoulder = Offset(cx + s * 0.14, shoulderY);

    // Default resting hands.
    Offset lHand = Offset(cx - s * 0.17, shoulderY + s * 0.18);
    Offset rHand = Offset(cx + s * 0.17, shoulderY + s * 0.18);

    switch (pose) {
      case AvatarPose.wave:
      case AvatarPose.cheer:
        final w = math.sin(t * math.pi * 6) * s * 0.03;
        rHand = Offset(cx + s * 0.20 + w, headC.dy - s * 0.04);
        if (pose == AvatarPose.cheer) {
          lHand = Offset(cx - s * 0.20 - w, headC.dy - s * 0.04);
        }
        break;
      case AvatarPose.clap:
        final c = math.sin(t * math.pi * 8).abs() * s * 0.05;
        lHand = Offset(cx - s * 0.05 - c, shoulderY + s * 0.10);
        rHand = Offset(cx + s * 0.05 + c, shoulderY + s * 0.10);
        break;
      case AvatarPose.point:
      case AvatarPose.hold:
        rHand = Offset(cx + s * 0.24, shoulderY + s * 0.10);
        break;
      case AvatarPose.brush:
        final b = math.sin(t * math.pi * 10) * s * 0.02;
        rHand = Offset(cx + s * 0.05 + b, headC.dy + s * 0.06);
        break;
      case AvatarPose.wash:
        final r = math.sin(t * math.pi * 8) * s * 0.02;
        lHand = Offset(cx - s * 0.03 + r, shoulderY + s * 0.16);
        rHand = Offset(cx + s * 0.03 - r, shoulderY + s * 0.16);
        break;
      case AvatarPose.eat:
        final e = (math.sin(t * math.pi * 4) * 0.5 + 0.5);
        rHand = Offset(cx + s * 0.06, headC.dy + s * 0.10 - e * s * 0.06);
        break;
      case AvatarPose.sleep:
        lHand = Offset(cx - s * 0.12, shoulderY + s * 0.16);
        rHand = Offset(cx + s * 0.12, shoulderY + s * 0.16);
        break;
      case AvatarPose.idle:
      case AvatarPose.walk:
      case AvatarPose.sit:
        final sway = math.sin(t * math.pi * 2) * s * 0.012;
        lHand = Offset(cx - s * 0.17, shoulderY + s * 0.18 + sway);
        rHand = Offset(cx + s * 0.17, shoulderY + s * 0.18 - sway);
        break;
    }

    _arm(canvas, lShoulder, lHand, paint, s);
    _arm(canvas, rShoulder, rHand, paint, s);
    // Hands.
    final hand = Paint()..color = config.skin;
    canvas.drawCircle(lHand, s * 0.038, hand);
    canvas.drawCircle(rHand, s * 0.038, hand);
    _rHand = rHand;
    _lHand = lHand;
  }

  Offset _rHand = Offset.zero;
  Offset _lHand = Offset.zero;

  void _arm(Canvas canvas, Offset a, Offset b, Paint paint, double s) {
    // Slight elbow bend for friendliness.
    final mid = Offset((a.dx + b.dx) / 2 + (b.dx - a.dx) * 0.1,
        (a.dy + b.dy) / 2 + s * 0.02);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    canvas.drawPath(path, paint);
  }

  void _head(Canvas canvas, Offset c, double r, double s) {
    final rect = Rect.fromCircle(center: c, radius: r);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: <Color>[_lighten(config.skin, 0.12), config.skin],
      ).createShader(rect);
    canvas.drawCircle(c, r, paint);
    // Ears.
    final ear = Paint()..color = config.skin;
    canvas.drawCircle(Offset(c.dx - r, c.dy), r * 0.22, ear);
    canvas.drawCircle(Offset(c.dx + r, c.dy), r * 0.22, ear);
  }

  void _hair(Canvas canvas, Offset c, double r, double s) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[_lighten(config.hairColor, 0.18), config.hairColor],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.3));
    switch (config.hair) {
      case HairStyle.short:
        final path = Path()
          ..addArc(Rect.fromCircle(center: c, radius: r * 1.04),
              math.pi, math.pi);
        path.lineTo(c.dx + r * 0.7, c.dy + r * 0.1);
        path.lineTo(c.dx - r * 0.7, c.dy + r * 0.1);
        path.close();
        canvas.drawPath(path, paint);
        break;
      case HairStyle.buzz:
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.98),
            math.pi, math.pi, false, paint..style = PaintingStyle.fill);
        break;
      case HairStyle.spiky:
        for (int i = -3; i <= 3; i++) {
          final x = c.dx + i * r * 0.28;
          final path = Path()
            ..moveTo(x - r * 0.16, c.dy - r * 0.2)
            ..lineTo(x, c.dy - r * 1.15)
            ..lineTo(x + r * 0.16, c.dy - r * 0.2)
            ..close();
          canvas.drawPath(path, paint);
        }
        break;
      case HairStyle.curly:
        for (int i = -3; i <= 3; i++) {
          canvas.drawCircle(
              Offset(c.dx + i * r * 0.32, c.dy - r * 0.78), r * 0.34, paint);
        }
        canvas.drawCircle(Offset(c.dx, c.dy - r * 0.5), r * 0.9, paint);
        break;
      case HairStyle.ponytail:
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.02),
            math.pi, math.pi, false, paint..style = PaintingStyle.fill);
        // Tail.
        final sway = math.sin(t * math.pi * 2) * r * 0.1;
        canvas.drawCircle(
            Offset(c.dx + r * 1.0 + sway, c.dy + r * 0.2), r * 0.42, paint);
        break;
      case HairStyle.bun:
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.02),
            math.pi, math.pi, false, paint..style = PaintingStyle.fill);
        canvas.drawCircle(Offset(c.dx, c.dy - r * 1.05), r * 0.34, paint);
        break;
    }
  }

  void _face(Canvas canvas, Offset c, double r, double s) {
    final sleeping = pose == AvatarPose.sleep;
    final blink = (t > 0.92 && t < 0.97);
    final eyeY = c.dy - r * 0.05;
    final eyePaint = Paint()..color = const Color(0xFF2A2320);
    if (sleeping || blink) {
      final p = Paint()
        ..color = const Color(0xFF2A2320)
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
          Rect.fromCircle(center: Offset(c.dx - r * 0.36, eyeY), radius: r * 0.16),
          0.2, math.pi - 0.4, false, p);
      canvas.drawArc(
          Rect.fromCircle(center: Offset(c.dx + r * 0.36, eyeY), radius: r * 0.16),
          0.2, math.pi - 0.4, false, p);
    } else {
      canvas.drawCircle(Offset(c.dx - r * 0.36, eyeY), r * 0.11, eyePaint);
      canvas.drawCircle(Offset(c.dx + r * 0.36, eyeY), r * 0.11, eyePaint);
      // Catchlights.
      final cl = Paint()..color = Colors.white.withOpacity(0.85);
      canvas.drawCircle(Offset(c.dx - r * 0.33, eyeY - r * 0.04), r * 0.035, cl);
      canvas.drawCircle(Offset(c.dx + r * 0.39, eyeY - r * 0.04), r * 0.035, cl);
    }
    // Rosy cheeks.
    final cheek = Paint()..color = const Color(0xFFFF8FA3).withOpacity(0.35);
    canvas.drawCircle(Offset(c.dx - r * 0.5, c.dy + r * 0.3), r * 0.14, cheek);
    canvas.drawCircle(Offset(c.dx + r * 0.5, c.dy + r * 0.3), r * 0.14, cheek);
    // Smile.
    final mouth = Paint()
      ..color = const Color(0xFF8A3B2E)
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (sleeping) {
      canvas.drawCircle(Offset(c.dx, c.dy + r * 0.45), r * 0.07,
          Paint()..color = const Color(0xFF8A3B2E));
    } else {
      canvas.drawArc(
          Rect.fromCircle(center: Offset(c.dx, c.dy + r * 0.32), radius: r * 0.26),
          0.25, math.pi - 0.5, false, mouth);
    }
  }

  void _glasses(Canvas canvas, Offset c, double r, double s) {
    final paint = Paint()
      ..color = const Color(0xFF2B2B2B)
      ..strokeWidth = r * 0.06
      ..style = PaintingStyle.stroke;
    final eyeY = c.dy - r * 0.05;
    canvas.drawCircle(Offset(c.dx - r * 0.36, eyeY), r * 0.24, paint);
    canvas.drawCircle(Offset(c.dx + r * 0.36, eyeY), r * 0.24, paint);
    canvas.drawLine(Offset(c.dx - r * 0.12, eyeY),
        Offset(c.dx + r * 0.12, eyeY), paint);
    // Lens glint.
    final glint = Paint()..color = Colors.white.withOpacity(0.18);
    canvas.drawCircle(Offset(c.dx - r * 0.36, eyeY), r * 0.22, glint);
    canvas.drawCircle(Offset(c.dx + r * 0.36, eyeY), r * 0.22, glint);
  }

  void _hearingAid(Canvas canvas, Offset c, double r, double s) {
    // A small, proud teal hearing device on the left ear.
    final ear = Offset(c.dx - r, c.dy + r * 0.05);
    final body = Paint()
      ..shader = LinearGradient(
        colors: <Color>[const Color(0xFF4CC9F0), const Color(0xFF2E9BD6)],
      ).createShader(Rect.fromCircle(center: ear, radius: r * 0.3));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: ear, width: r * 0.22, height: r * 0.34),
        Radius.circular(r * 0.1),
      ),
      body,
    );
    // Hook over the ear.
    final hook = Paint()
      ..color = const Color(0xFF2E9BD6)
      ..strokeWidth = r * 0.06
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(ear.dx, ear.dy - r * 0.1), radius: r * 0.16),
        -0.3, math.pi * 0.9, false, hook);
    // Little light.
    canvas.drawCircle(Offset(ear.dx, ear.dy + r * 0.12), r * 0.04,
        Paint()..color = const Color(0xFF8BFFE0));
  }

  /// Pose-specific held props (toothbrush, spoon, soap bubbles...).
  void _prop(Canvas canvas, Offset headC, double headR, double bodyTop,
      double cx, double s) {
    switch (pose) {
      case AvatarPose.brush:
        // Toothbrush in right hand near mouth.
        final h = _rHand;
        final brush = Paint()
          ..color = const Color(0xFF06D6A0)
          ..strokeWidth = s * 0.03
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(h, Offset(h.dx - s * 0.06, h.dy - s * 0.05), brush);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(h.dx - s * 0.07, h.dy - s * 0.06),
                width: s * 0.05,
                height: s * 0.025),
            Radius.circular(s * 0.01),
          ),
          Paint()..color = Colors.white,
        );
        break;
      case AvatarPose.wash:
        // Bubbles between hands.
        final mid = Offset((_lHand.dx + _rHand.dx) / 2,
            (_lHand.dy + _rHand.dy) / 2);
        final b = Paint()..color = Colors.white.withOpacity(0.7);
        for (int i = 0; i < 5; i++) {
          final ang = i / 5 * math.pi * 2 + t * 4;
          final p = mid +
              Offset(math.cos(ang), math.sin(ang)) * s * 0.05 *
                  (0.6 + 0.4 * math.sin(t * 6 + i));
          canvas.drawCircle(p, s * 0.018, b);
        }
        break;
      case AvatarPose.eat:
        // Spoon.
        final h = _rHand;
        final spoon = Paint()
          ..color = const Color(0xFFCED4DA)
          ..strokeWidth = s * 0.025
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(h, Offset(h.dx, h.dy - s * 0.06), spoon);
        canvas.drawCircle(Offset(h.dx, h.dy - s * 0.07), s * 0.025,
            Paint()..color = const Color(0xFFCED4DA));
        break;
      case AvatarPose.sleep:
        // Floating Z's.
        final z = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: s * 0.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final zy = headC.dy - headR - (t * s * 0.2);
        z.paint(canvas, Offset(headC.dx + headR * 0.6, zy));
        break;
      case AvatarPose.hold:
        // Open hand reaching out (to hold a parent's hand).
        canvas.drawCircle(_rHand, s * 0.045,
            Paint()..color = config.skin);
        break;
      case AvatarPose.idle:
      case AvatarPose.wave:
      case AvatarPose.sit:
      case AvatarPose.walk:
      case AvatarPose.point:
      case AvatarPose.clap:
      case AvatarPose.cheer:
        break;
    }
  }

  Color _lighten(Color c, double amt) =>
      Color.lerp(c, Colors.white, amt.clamp(0.0, 1.0))!;
  Color _darken(Color c, double amt) =>
      Color.lerp(c, Colors.black, amt.clamp(0.0, 1.0))!;

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.t != t || old.pose != pose || old.config != config;
}
