import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// HARSHIVOS Character System
// ---------------------------------------------------------------------------
// A reusable, emotion-driven, fully customisable child character — the mascot
// of HARSHIVOS. Rendered entirely with a CustomPainter (no assets, no native
// deps) so it ships on every platform and never blocks a release build.
//
// Three axes drive every frame:
//   • AvatarConfig  — WHO the character is (skin, hair, eyes, clothes, device)
//   • AvatarEmotion — how they FEEL (face + subtle body language)
//   • AvatarPose    — what they're DOING (routine demonstrations)
//
// Assistive devices (hearing aid, BAHA, cochlear implant, glasses) are drawn
// with pride and detail — representation is a first-class feature.
// ---------------------------------------------------------------------------

/// What the character is doing — drives limb posture and any held prop.
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
  dress,
  potty,
  bath,
}

/// How the character feels. Drives eyes, brows, mouth, blush and body language.
enum AvatarEmotion {
  happy,
  calm,
  excited,
  proud,
  sad,
  frustrated,
  tired,
  nervous,
}

enum HairStyle { short, ponytail, curly, buzz, bun, spiky }

enum AvatarGender { boy, girl, neutral }

/// The kind of hearing technology the child wears.
enum HearingDevice { none, hearingAid, baha, cochlear }

/// Which side(s) the device is worn on — supports unilateral hearing.
enum HearingSide { left, right, both }

/// A fully customisable, serialisable child character.
///
/// Saved once by a family and reused everywhere — routines, lessons,
/// celebrations, progress. This is the single source of truth for the mascot.
@immutable
class AvatarConfig {
  const AvatarConfig({
    this.gender = AvatarGender.neutral,
    this.skin = const Color(0xFFF1C9A5),
    this.hair = HairStyle.short,
    this.hairColor = const Color(0xFF3B2A1E),
    this.eyeColor = const Color(0xFF5A3A22),
    this.shirt = const Color(0xFF4CC9F0),
    this.favoriteColor = const Color(0xFF06D6A0),
    this.device = HearingDevice.hearingAid,
    this.hearingSide = HearingSide.left,
    this.glasses = false,
  });

  final AvatarGender gender;
  final Color skin;
  final HairStyle hair;
  final Color hairColor;
  final Color eyeColor;
  final Color shirt;

  /// The child's favourite colour — used for accents, shoes and their device.
  final Color favoriteColor;

  /// The hearing technology the character proudly wears.
  final HearingDevice device;
  final HearingSide hearingSide;
  final bool glasses;

  /// Legacy compatibility — old code asked `hearingAid`.
  bool get hearingAid => device == HearingDevice.hearingAid;

  /// Harshiv's own look: unilateral (left) BAHA, sensory-calm palette.
  /// This normalises assistive devices — the whole reason HARSHIVOS exists.
  static const AvatarConfig harshiv = AvatarConfig(
    gender: AvatarGender.boy,
    skin: Color(0xFFF1C9A5),
    hair: HairStyle.short,
    hairColor: Color(0xFF2A1E14),
    eyeColor: Color(0xFF3B2A1E),
    shirt: Color(0xFF0891B2),
    favoriteColor: Color(0xFF06D6A0),
    device: HearingDevice.baha,
    hearingSide: HearingSide.left,
    glasses: false,
  );

  static const List<Color> skinTones = <Color>[
    Color(0xFFFFE0BD),
    Color(0xFFF1C9A5),
    Color(0xFFE0AC69),
    Color(0xFFC68642),
    Color(0xFF8D5524),
    Color(0xFF5C3A21),
  ];

  static const List<Color> hairColors = <Color>[
    Color(0xFF1A1A1A),
    Color(0xFF3B2A1E),
    Color(0xFF6B4423),
    Color(0xFFA9712B),
    Color(0xFFD9A441),
    Color(0xFFB5651D),
    Color(0xFF8E8E8E),
    Color(0xFF9B5DE5),
  ];

  static const List<Color> eyeColors = <Color>[
    Color(0xFF3B2A1E), // dark brown
    Color(0xFF6B4423), // brown
    Color(0xFF2E6B4F), // green
    Color(0xFF2C6E9B), // blue
    Color(0xFF6B4E9B), // violet
    Color(0xFF7A6A5A), // hazel
    Color(0xFF5A6472), // grey
  ];

  static const List<Color> shirtColors = <Color>[
    Color(0xFF4CC9F0),
    Color(0xFF06D6A0),
    Color(0xFFEF476F),
    Color(0xFFFFD166),
    Color(0xFF9B5DE5),
    Color(0xFFF15BB5),
    Color(0xFFFF9E00),
    Color(0xFF0891B2),
  ];

  /// The favourite-colour palette mirrors the shirt palette for consistency.
  static const List<Color> favoriteColors = shirtColors;

  AvatarConfig copyWith({
    AvatarGender? gender,
    Color? skin,
    HairStyle? hair,
    Color? hairColor,
    Color? eyeColor,
    Color? shirt,
    Color? favoriteColor,
    HearingDevice? device,
    HearingSide? hearingSide,
    bool? glasses,
  }) {
    return AvatarConfig(
      gender: gender ?? this.gender,
      skin: skin ?? this.skin,
      hair: hair ?? this.hair,
      hairColor: hairColor ?? this.hairColor,
      eyeColor: eyeColor ?? this.eyeColor,
      shirt: shirt ?? this.shirt,
      favoriteColor: favoriteColor ?? this.favoriteColor,
      device: device ?? this.device,
      hearingSide: hearingSide ?? this.hearingSide,
      glasses: glasses ?? this.glasses,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 2,
        'gender': gender.index,
        'skin': skin.value,
        'hair': hair.index,
        'hairColor': hairColor.value,
        'eyeColor': eyeColor.value,
        'shirt': shirt.value,
        'favoriteColor': favoriteColor.value,
        'device': device.index,
        'hearingSide': hearingSide.index,
        'glasses': glasses,
      };

  factory AvatarConfig.fromJson(Map<String, dynamic> j) {
    // Migrate the old v1 shape (bool hearingAid, no device/eye/favourite).
    HearingDevice device;
    if (j.containsKey('device')) {
      device = HearingDevice.values[(j['device'] as num?)?.toInt() ?? 1];
    } else {
      device = (j['hearingAid'] as bool? ?? true)
          ? HearingDevice.hearingAid
          : HearingDevice.none;
    }
    return AvatarConfig(
      gender: AvatarGender
          .values[(j['gender'] as num?)?.toInt() ?? AvatarGender.neutral.index],
      skin: Color((j['skin'] as num?)?.toInt() ?? 0xFFF1C9A5),
      hair: HairStyle.values[(j['hair'] as num?)?.toInt() ?? 0],
      hairColor: Color((j['hairColor'] as num?)?.toInt() ?? 0xFF3B2A1E),
      eyeColor: Color((j['eyeColor'] as num?)?.toInt() ?? 0xFF5A3A22),
      shirt: Color((j['shirt'] as num?)?.toInt() ?? 0xFF4CC9F0),
      favoriteColor: Color((j['favoriteColor'] as num?)?.toInt() ?? 0xFF06D6A0),
      device: device,
      hearingSide: HearingSide
          .values[(j['hearingSide'] as num?)?.toInt() ?? HearingSide.left.index],
      glasses: j['glasses'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarConfig &&
      other.gender == gender &&
      other.skin.value == skin.value &&
      other.hair == hair &&
      other.hairColor.value == hairColor.value &&
      other.eyeColor.value == eyeColor.value &&
      other.shirt.value == shirt.value &&
      other.favoriteColor.value == favoriteColor.value &&
      other.device == device &&
      other.hearingSide == hearingSide &&
      other.glasses == glasses;

  @override
  int get hashCode => Object.hash(gender, skin.value, hair, hairColor.value,
      eyeColor.value, shirt.value, favoriteColor.value, device, hearingSide,
      glasses);
}

/// Sensible default emotion for a routine pose, so demonstrations feel alive
/// even when a caller only specifies what the character is *doing*.
AvatarEmotion emotionForPose(AvatarPose pose) {
  switch (pose) {
    case AvatarPose.cheer:
    case AvatarPose.clap:
      return AvatarEmotion.excited;
    case AvatarPose.wave:
    case AvatarPose.point:
    case AvatarPose.walk:
    case AvatarPose.dress:
      return AvatarEmotion.happy;
    case AvatarPose.brush:
    case AvatarPose.wash:
    case AvatarPose.eat:
    case AvatarPose.bath:
    case AvatarPose.potty:
      return AvatarEmotion.calm;
    case AvatarPose.hold:
    case AvatarPose.sit:
    case AvatarPose.idle:
      return AvatarEmotion.calm;
    case AvatarPose.sleep:
      return AvatarEmotion.tired;
  }
}

/// The animated character widget. Drop it in any square box; it breathes,
/// blinks, expresses [emotion] and performs [pose].
class AvatarWidget extends StatefulWidget {
  const AvatarWidget({
    super.key,
    required this.config,
    this.pose = AvatarPose.idle,
    this.emotion,
    this.animate = true,
  });

  final AvatarConfig config;
  final AvatarPose pose;

  /// Overrides the emotion; when null it is derived from [pose].
  final AvatarEmotion? emotion;
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
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
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
        painter: _CharacterPainter(
          config: widget.config,
          pose: widget.pose,
          emotion: widget.emotion ?? emotionForPose(widget.pose),
          t: _c.value,
        ),
      ),
    );
  }
}

/// Internal descriptor of a facial expression, resolved from [AvatarEmotion].
class _Face {
  const _Face({
    required this.eyeOpen,
    required this.browLift,
    required this.browTilt,
    required this.mouth,
    required this.blush,
    required this.headTilt,
    required this.bounce,
    this.tear = false,
    this.sweat = false,
    this.sparkle = false,
    this.pupil = Offset.zero,
  });

  final double eyeOpen; // 0 closed .. 1 wide
  final double browLift; // fraction of r; positive = raised
  final double browTilt; // radians; + = angry (inner down), - = worried
  final _Mouth mouth;
  final double blush; // 0..1 opacity boost
  final double headTilt; // radians
  final double bounce; // breathing amplitude multiplier
  final bool tear;
  final bool sweat;
  final bool sparkle;
  final Offset pupil; // fractional pupil offset
}

enum _Mouth { smile, grin, openSmile, frown, grimace, flat, wavy, o }

class _CharacterPainter extends CustomPainter {
  _CharacterPainter({
    required this.config,
    required this.pose,
    required this.emotion,
    required this.t,
  });

  final AvatarConfig config;
  final AvatarPose pose;
  final AvatarEmotion emotion;
  final double t;

  // Scratch positions filled during paint for prop alignment.
  Offset _rHand = Offset.zero;
  Offset _lHand = Offset.zero;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;
    final face = _resolveFace();

    // Gentle vertical breathing / bounce, tuned per emotion.
    final wobble = math.sin(t * math.pi * 2);
    final breathe = wobble * s * 0.012 * face.bounce;
    final cy = size.height / 2 + breathe;

    // Chibi proportions: a big, expressive head over a small soft body.
    final headR = s * 0.185;
    final headC = Offset(cx, cy - s * 0.13);
    final bodyTop = headC.dy + headR * 0.82;

    _shadow(canvas, Offset(cx, cy + s * 0.37), s, face);
    _legs(canvas, cx, bodyTop, s);
    _body(canvas, cx, bodyTop, s);
    _arms(canvas, cx, bodyTop, headC, headR, s, face);

    // The whole head group tilts together (endearing + expressive).
    canvas.save();
    canvas.translate(headC.dx, headC.dy);
    canvas.rotate(face.headTilt);
    canvas.translate(-headC.dx, -headC.dy);

    _head(canvas, headC, headR);
    _hair(canvas, headC, headR);
    _face(canvas, headC, headR, face);
    if (config.glasses) _glasses(canvas, headC, headR, face);
    _devices(canvas, headC, headR);

    canvas.restore();

    _prop(canvas, headC, headR, s);
  }

  // ---- Expression resolution ----------------------------------------------

  _Face _resolveFace() {
    // A natural blink near the end of each loop (skipped when eyes are shut).
    final blinking = t > 0.94 && t < 0.985;
    final idlePupil = Offset(math.sin(t * math.pi * 2) * 0.06, 0);

    switch (emotion) {
      case AvatarEmotion.happy:
        return _Face(
          eyeOpen: blinking ? 0.08 : 1,
          browLift: 0.10,
          browTilt: 0,
          mouth: _Mouth.smile,
          blush: 0.5,
          headTilt: 0.02 * math.sin(t * math.pi * 2),
          bounce: 1,
          pupil: idlePupil,
        );
      case AvatarEmotion.calm:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.86,
          browLift: 0.06,
          browTilt: -0.04,
          mouth: _Mouth.grin,
          blush: 0.35,
          headTilt: 0.03 * math.sin(t * math.pi * 2),
          bounce: 0.8,
          pupil: idlePupil,
        );
      case AvatarEmotion.excited:
        return _Face(
          eyeOpen: 1,
          browLift: 0.20,
          browTilt: -0.02,
          mouth: _Mouth.openSmile,
          blush: 0.7,
          headTilt: 0.05 * math.sin(t * math.pi * 4),
          bounce: 2.2,
          sparkle: true,
          pupil: Offset(0, -0.05),
        );
      case AvatarEmotion.proud:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.9,
          browLift: 0.14,
          browTilt: -0.05,
          mouth: _Mouth.grin,
          blush: 0.6,
          headTilt: -0.03,
          bounce: 1.1,
          sparkle: true,
          pupil: const Offset(0, -0.04),
        );
      case AvatarEmotion.sad:
        return _Face(
          eyeOpen: 0.7,
          browLift: 0.02,
          browTilt: -0.30, // inner-up worried
          mouth: _Mouth.frown,
          blush: 0.25,
          headTilt: 0.08,
          bounce: 0.5,
          tear: true,
          pupil: const Offset(0, 0.12),
        );
      case AvatarEmotion.frustrated:
        return _Face(
          eyeOpen: 0.72,
          browLift: -0.06,
          browTilt: 0.34, // inner-down angry
          mouth: _Mouth.grimace,
          blush: 0.4,
          headTilt: -0.02,
          bounce: 0.7,
          pupil: Offset(math.sin(t * math.pi * 8) * 0.05, 0),
        );
      case AvatarEmotion.tired:
        return _Face(
          eyeOpen: 0.32,
          browLift: 0.0,
          browTilt: -0.10,
          mouth: _Mouth.flat,
          blush: 0.3,
          headTilt: 0.10 + 0.02 * math.sin(t * math.pi * 2),
          bounce: 0.6,
          pupil: const Offset(0, 0.06),
        );
      case AvatarEmotion.nervous:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.9,
          browLift: 0.10,
          browTilt: -0.22,
          mouth: _Mouth.wavy,
          blush: 0.35,
          headTilt: 0.02 * math.sin(t * math.pi * 6),
          bounce: 0.9,
          sweat: true,
          pupil: Offset(math.sin(t * math.pi * 5) * 0.10, 0.04),
        );
    }
  }

  // ---- Body ---------------------------------------------------------------

  void _shadow(Canvas canvas, Offset c, double s, _Face face) {
    final w = s * (0.42 - face.bounce * 0.01);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w, height: s * 0.09),
      Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
    );
  }

  void _body(Canvas canvas, double cx, double bodyTop, double s) {
    final w = s * 0.29;
    final h = s * 0.28;
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(cx - w / 2, bodyTop, w, h),
      topLeft: Radius.circular(s * 0.14),
      topRight: Radius.circular(s * 0.14),
      bottomLeft: Radius.circular(s * 0.08),
      bottomRight: Radius.circular(s * 0.08),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _lighten(config.shirt, 0.18),
            config.shirt,
            _darken(config.shirt, 0.14),
          ],
        ).createShader(rect.outerRect),
    );
    // Rounded collar.
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, bodyTop + s * 0.005),
          width: s * 0.16,
          height: s * 0.10),
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = _lighten(config.skin, 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02,
    );
    // Favourite-colour accent stripe.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w / 2, bodyTop + h * 0.62, w, h * 0.14),
        Radius.circular(s * 0.02),
      ),
      Paint()..color = config.favoriteColor.withOpacity(0.9),
    );
    // Soft top highlight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w / 2, bodyTop, w, h * 0.28),
        Radius.circular(s * 0.12),
      ),
      Paint()..color = Colors.white.withOpacity(0.10),
    );
  }

  void _legs(Canvas canvas, double cx, double bodyTop, double s) {
    final paint = Paint()
      ..color = const Color(0xFF39496A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.08
      ..style = PaintingStyle.stroke;
    final hipY = bodyTop + s * 0.28;
    double swing = 0;
    if (pose == AvatarPose.walk) {
      swing = math.sin(t * math.pi * 4) * s * 0.05;
    }
    if (pose == AvatarPose.sit || pose == AvatarPose.potty) {
      canvas.drawLine(Offset(cx - s * 0.07, hipY),
          Offset(cx - s * 0.15, hipY + s * 0.02), paint);
      canvas.drawLine(Offset(cx + s * 0.07, hipY),
          Offset(cx + s * 0.15, hipY + s * 0.02), paint);
      _shoe(canvas, Offset(cx - s * 0.16, hipY + s * 0.03), s);
      _shoe(canvas, Offset(cx + s * 0.16, hipY + s * 0.03), s);
      return;
    }
    canvas.drawLine(Offset(cx - s * 0.07, hipY),
        Offset(cx - s * 0.07 + swing, hipY + s * 0.11), paint);
    canvas.drawLine(Offset(cx + s * 0.07, hipY),
        Offset(cx + s * 0.07 - swing, hipY + s * 0.11), paint);
    _shoe(canvas, Offset(cx - s * 0.07 + swing, hipY + s * 0.13), s);
    _shoe(canvas, Offset(cx + s * 0.07 - swing, hipY + s * 0.13), s);
  }

  void _shoe(Canvas canvas, Offset c, double s) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: s * 0.10, height: s * 0.055),
      Paint()..color = _darken(config.favoriteColor, 0.1),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(c.dx, c.dy - s * 0.01),
          width: s * 0.08,
          height: s * 0.02),
      Paint()..color = Colors.white.withOpacity(0.55),
    );
  }

  void _arms(Canvas canvas, double cx, double bodyTop, Offset headC,
      double headR, double s, _Face face) {
    final paint = Paint()
      ..color = config.skin
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.062
      ..style = PaintingStyle.stroke;
    final shoulderY = bodyTop + s * 0.03;
    final lShoulder = Offset(cx - s * 0.13, shoulderY);
    final rShoulder = Offset(cx + s * 0.13, shoulderY);

    Offset lHand = Offset(cx - s * 0.17, shoulderY + s * 0.17);
    Offset rHand = Offset(cx + s * 0.17, shoulderY + s * 0.17);

    switch (pose) {
      case AvatarPose.wave:
        final w = math.sin(t * math.pi * 6) * s * 0.03;
        rHand = Offset(cx + s * 0.21 + w, headC.dy - s * 0.02);
        break;
      case AvatarPose.cheer:
        final w = math.sin(t * math.pi * 6) * s * 0.03;
        rHand = Offset(cx + s * 0.20 + w, headC.dy - s * 0.06);
        lHand = Offset(cx - s * 0.20 - w, headC.dy - s * 0.06);
        break;
      case AvatarPose.clap:
        final c = math.sin(t * math.pi * 8).abs() * s * 0.05;
        lHand = Offset(cx - s * 0.05 - c, shoulderY + s * 0.08);
        rHand = Offset(cx + s * 0.05 + c, shoulderY + s * 0.08);
        break;
      case AvatarPose.point:
        rHand = Offset(cx + s * 0.25, shoulderY + s * 0.06);
        break;
      case AvatarPose.hold:
        rHand = Offset(cx + s * 0.24, shoulderY + s * 0.14);
        lHand = Offset(cx - s * 0.24, shoulderY + s * 0.14);
        break;
      case AvatarPose.brush:
        final b = math.sin(t * math.pi * 10) * s * 0.02;
        rHand = Offset(cx + s * 0.05 + b, headC.dy + s * 0.07);
        break;
      case AvatarPose.wash:
      case AvatarPose.bath:
        final r = math.sin(t * math.pi * 8) * s * 0.02;
        lHand = Offset(cx - s * 0.03 + r, shoulderY + s * 0.14);
        rHand = Offset(cx + s * 0.03 - r, shoulderY + s * 0.14);
        break;
      case AvatarPose.eat:
        final e = math.sin(t * math.pi * 4) * 0.5 + 0.5;
        rHand = Offset(cx + s * 0.06, headC.dy + s * 0.11 - e * s * 0.06);
        break;
      case AvatarPose.dress:
        final d = math.sin(t * math.pi * 6) * s * 0.03;
        lHand = Offset(cx - s * 0.12 + d, shoulderY + s * 0.02);
        rHand = Offset(cx + s * 0.12 - d, shoulderY + s * 0.02);
        break;
      case AvatarPose.sleep:
        lHand = Offset(cx - s * 0.11, shoulderY + s * 0.15);
        rHand = Offset(cx + s * 0.11, shoulderY + s * 0.15);
        break;
      case AvatarPose.idle:
      case AvatarPose.walk:
      case AvatarPose.sit:
      case AvatarPose.potty:
        final sway = math.sin(t * math.pi * 2) * s * 0.012 * face.bounce;
        lHand = Offset(cx - s * 0.17, shoulderY + s * 0.17 + sway);
        rHand = Offset(cx + s * 0.17, shoulderY + s * 0.17 - sway);
        break;
    }

    _arm(canvas, lShoulder, lHand, paint, s);
    _arm(canvas, rShoulder, rHand, paint, s);
    final hand = Paint()..color = config.skin;
    canvas.drawCircle(lHand, s * 0.04, hand);
    canvas.drawCircle(rHand, s * 0.04, hand);
    _rHand = rHand;
    _lHand = lHand;
  }

  void _arm(Canvas canvas, Offset a, Offset b, Paint paint, double s) {
    final mid = Offset((a.dx + b.dx) / 2 + (b.dx - a.dx) * 0.12,
        (a.dy + b.dy) / 2 + s * 0.02);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy),
      paint,
    );
  }

  // ---- Head, hair, face ---------------------------------------------------

  void _head(Canvas canvas, Offset c, double r) {
    // Soft rounded head with a slightly tapered chin.
    final rect = Rect.fromCenter(
        center: c, width: r * 2, height: r * 2.05);
    final path = Path()
      ..addOval(rect);
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: <Color>[_lighten(config.skin, 0.14), config.skin],
        ).createShader(rect),
    );
    // Ears.
    final ear = Paint()..color = config.skin;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx - r * 0.98, c.dy + r * 0.06),
            width: r * 0.4,
            height: r * 0.5),
        ear);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx + r * 0.98, c.dy + r * 0.06),
            width: r * 0.4,
            height: r * 0.5),
        ear);
    // Rim light on the right edge for a 3D, sculpted feel.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.98),
      -math.pi * 0.42,
      math.pi * 0.7,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );
  }

  void _hair(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[_lighten(config.hairColor, 0.22), config.hairColor],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.35));
    final hi = Paint()..color = Colors.white.withOpacity(0.16);

    switch (config.hair) {
      case HairStyle.short:
        final path = Path()
          ..addArc(
              Rect.fromCircle(center: c, radius: r * 1.05), math.pi, math.pi)
          ..lineTo(c.dx + r * 0.75, c.dy + r * 0.12)
          ..quadraticBezierTo(c.dx + r * 0.4, c.dy - r * 0.15, c.dx + r * 0.1,
              c.dy - r * 0.05)
          ..quadraticBezierTo(
              c.dx - r * 0.2, c.dy + r * 0.05, c.dx - r * 0.75, c.dy + r * 0.12)
          ..close();
        canvas.drawPath(path, paint);
        _hairSheen(canvas, c, r, hi);
        break;
      case HairStyle.buzz:
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.99), math.pi,
            math.pi, false, paint..style = PaintingStyle.fill);
        break;
      case HairStyle.spiky:
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.0), math.pi,
            math.pi, false, paint);
        for (int i = -3; i <= 3; i++) {
          final x = c.dx + i * r * 0.28;
          canvas.drawPath(
            Path()
              ..moveTo(x - r * 0.17, c.dy - r * 0.35)
              ..lineTo(x, c.dy - r * 1.2)
              ..lineTo(x + r * 0.17, c.dy - r * 0.35)
              ..close(),
            paint,
          );
        }
        break;
      case HairStyle.curly:
        for (int i = -3; i <= 3; i++) {
          canvas.drawCircle(
              Offset(c.dx + i * r * 0.32, c.dy - r * 0.82), r * 0.36, paint);
        }
        canvas.drawCircle(Offset(c.dx, c.dy - r * 0.5), r * 0.95, paint);
        _hairSheen(canvas, c, r, hi);
        break;
      case HairStyle.ponytail:
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.04), math.pi,
            math.pi, false, paint..style = PaintingStyle.fill);
        final sway = math.sin(t * math.pi * 2) * r * 0.12;
        canvas.drawCircle(
            Offset(c.dx + r * 1.05 + sway, c.dy + r * 0.15), r * 0.45, paint);
        canvas.drawCircle(Offset(c.dx + r * 0.85, c.dy - r * 0.1), r * 0.16,
            Paint()..color = config.favoriteColor);
        _hairSheen(canvas, c, r, hi);
        break;
      case HairStyle.bun:
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 1.04), math.pi,
            math.pi, false, paint..style = PaintingStyle.fill);
        canvas.drawCircle(Offset(c.dx, c.dy - r * 1.08), r * 0.36, paint);
        canvas.drawCircle(Offset(c.dx, c.dy - r * 1.08), r * 0.42,
            Paint()
              ..color = config.favoriteColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.06);
        _hairSheen(canvas, c, r, hi);
        break;
    }
  }

  void _hairSheen(Canvas canvas, Offset c, double r, Paint hi) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(c.dx - r * 0.2, c.dy), radius: r * 0.7),
      math.pi * 1.15,
      math.pi * 0.5,
      false,
      hi
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08,
    );
  }

  void _face(Canvas canvas, Offset c, double r, _Face f) {
    final eyeY = c.dy + r * 0.02;
    final eyeDx = r * 0.42;
    final eyeR = r * 0.30;

    // Eyebrows.
    _brow(canvas, Offset(c.dx - eyeDx, eyeY - eyeR - r * 0.06), r, f, left: true);
    _brow(canvas, Offset(c.dx + eyeDx, eyeY - eyeR - r * 0.06), r, f,
        left: false);

    // Eyes.
    _eye(canvas, Offset(c.dx - eyeDx, eyeY), eyeR, f, mirror: false);
    _eye(canvas, Offset(c.dx + eyeDx, eyeY), eyeR, f, mirror: true);

    // Blush.
    if (f.blush > 0) {
      final blush = Paint()
        ..color = const Color(0xFFFF7E9D).withOpacity(0.18 + f.blush * 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx - r * 0.56, c.dy + r * 0.4),
              width: r * 0.34,
              height: r * 0.22),
          blush);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx + r * 0.56, c.dy + r * 0.4),
              width: r * 0.34,
              height: r * 0.22),
          blush);
    }

    // Nose hint.
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.34),
        r * 0.045, Paint()..color = _darken(config.skin, 0.10));

    _mouth(canvas, Offset(c.dx, c.dy + r * 0.62), r, f.mouth);

    // Emotion extras.
    if (f.tear) {
      final tearP = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFBFE9FF), Color(0xFF6FC5F5)],
        ).createShader(Rect.fromCircle(
            center: Offset(c.dx - eyeDx, c.dy + r * 0.5), radius: r * 0.2));
      final drop = (t * 2 % 1);
      canvas.drawCircle(
          Offset(c.dx - eyeDx + r * 0.04, eyeY + r * 0.3 + drop * r * 0.4),
          r * 0.09,
          tearP);
    }
    if (f.sweat) {
      final drop = (t * 1.5 % 1);
      canvas.drawCircle(
        Offset(c.dx + r * 0.86, c.dy - r * 0.35 + drop * r * 0.3),
        r * 0.08,
        Paint()..color = const Color(0xFF9FD8F5).withOpacity(0.85),
      );
    }
    if (f.sparkle) {
      _sparkle(canvas, Offset(c.dx + r * 0.85, c.dy - r * 0.55), r * 0.14);
      _sparkle(canvas, Offset(c.dx - r * 0.9, c.dy - r * 0.2), r * 0.1);
    }
  }

  void _brow(Canvas canvas, Offset center, double r, _Face f,
      {required bool left}) {
    final paint = Paint()
      ..color = _darken(config.hairColor, 0.05)
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // browTilt raises/lowers the inner end; mirror for the left brow.
    final tilt = left ? f.browTilt : -f.browTilt;
    final lift = -f.browLift * r;
    final inner = Offset(center.dx + (left ? r * 0.14 : -r * 0.14),
        center.dy + lift + math.sin(tilt) * r * 0.22);
    final outer = Offset(center.dx + (left ? -r * 0.16 : r * 0.16),
        center.dy + lift - math.sin(tilt) * r * 0.1);
    final mid = Offset((inner.dx + outer.dx) / 2,
        (inner.dy + outer.dy) / 2 - r * 0.06);
    canvas.drawPath(
      Path()
        ..moveTo(inner.dx, inner.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, outer.dx, outer.dy),
      paint,
    );
  }

  void _eye(Canvas canvas, Offset center, double r, _Face f,
      {required bool mirror}) {
    final open = f.eyeOpen.clamp(0.05, 1.0);
    final scleraW = r * 0.62;
    final scleraH = r * 0.78 * open;
    final scleraRect =
        Rect.fromCenter(center: center, width: scleraW, height: scleraH);

    if (open < 0.14) {
      // Closed / blinking — a soft happy lash line.
      final p = Paint()
        ..color = const Color(0xFF3A2B22)
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
          Rect.fromCenter(
              center: center, width: scleraW, height: r * 0.3),
          0.15,
          math.pi - 0.3,
          false,
          p);
      return;
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(scleraRect));

    // Sclera.
    canvas.drawOval(scleraRect, Paint()..color = const Color(0xFFF7FBFF));

    // Iris + pupil follow the look direction.
    final look = Offset(f.pupil.dx * r * (mirror ? -1 : 1), f.pupil.dy * r);
    final irisC = center + look + Offset(0, scleraH * 0.02);
    final irisR = r * 0.28;
    canvas.drawCircle(
      irisC,
      irisR,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _lighten(config.eyeColor, 0.28),
            config.eyeColor,
            _darken(config.eyeColor, 0.25),
          ],
          stops: const <double>[0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: irisC, radius: irisR)),
    );
    // Radial iris fibres for depth.
    canvas.drawCircle(
        irisC,
        irisR * 0.98,
        Paint()
          ..color = _darken(config.eyeColor, 0.35).withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.02);
    // Pupil.
    canvas.drawCircle(irisC, r * 0.14, Paint()..color = const Color(0xFF1A140F));
    // Catchlights (the soul of a Pixar eye).
    canvas.drawCircle(irisC + Offset(-irisR * 0.35, -irisR * 0.4), r * 0.09,
        Paint()..color = Colors.white.withOpacity(0.95));
    canvas.drawCircle(irisC + Offset(irisR * 0.35, irisR * 0.25), r * 0.045,
        Paint()..color = Colors.white.withOpacity(0.7));

    // Upper-lid shadow for roundness.
    canvas.drawArc(
      scleraRect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12,
    );
    canvas.restore();

    // Upper lash line over the top of the eye.
    canvas.drawArc(
      scleraRect.inflate(r * 0.01),
      math.pi + 0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = const Color(0xFF2A2018)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round,
    );
  }

  void _mouth(Canvas canvas, Offset c, double r, _Mouth type) {
    final line = Paint()
      ..color = const Color(0xFF8A3B2E)
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = const Color(0xFF7A2E28);
    final tongue = Paint()..color = const Color(0xFFF07A82);
    final teeth = Paint()..color = Colors.white;

    switch (type) {
      case _Mouth.smile:
        canvas.drawArc(
            Rect.fromCenter(center: c, width: r * 0.6, height: r * 0.55),
            0.2, math.pi - 0.4, false, line);
        break;
      case _Mouth.grin:
        canvas.drawArc(
            Rect.fromCenter(center: c, width: r * 0.44, height: r * 0.34),
            0.25, math.pi - 0.5, false, line);
        break;
      case _Mouth.openSmile:
      case _Mouth.o:
        final rect =
            Rect.fromCenter(center: c, width: r * 0.5, height: r * 0.5);
        final path = Path()
          ..moveTo(rect.left, rect.top + rect.height * 0.2)
          ..quadraticBezierTo(c.dx, rect.top - rect.height * 0.1, rect.right,
              rect.top + rect.height * 0.2)
          ..arcToPoint(Offset(rect.left, rect.top + rect.height * 0.2),
              radius: Radius.circular(rect.width * 0.55), clockwise: false);
        canvas.drawPath(path, fill);
        // Teeth strip.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + r * 0.05, rect.top,
                rect.width - r * 0.1, r * 0.12),
            Radius.circular(r * 0.05),
          ),
          teeth,
        );
        // Tongue.
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(c.dx, rect.bottom - r * 0.1),
                width: r * 0.28,
                height: r * 0.16),
            tongue);
        break;
      case _Mouth.frown:
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy + r * 0.2),
                width: r * 0.55,
                height: r * 0.45),
            math.pi + 0.3, math.pi - 0.6, false, line);
        break;
      case _Mouth.grimace:
        final rect =
            Rect.fromCenter(center: c, width: r * 0.6, height: r * 0.26);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(r * 0.05)), fill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: c, width: r * 0.58, height: r * 0.11),
                Radius.circular(r * 0.03)),
            teeth);
        // Gritted vertical lines.
        for (int i = -2; i <= 2; i++) {
          canvas.drawLine(
              Offset(c.dx + i * r * 0.13, c.dy - r * 0.055),
              Offset(c.dx + i * r * 0.13, c.dy + r * 0.055),
              Paint()
                ..color = const Color(0xFFBEC3C9)
                ..strokeWidth = r * 0.02);
        }
        break;
      case _Mouth.flat:
        canvas.drawLine(Offset(c.dx - r * 0.22, c.dy),
            Offset(c.dx + r * 0.22, c.dy), line);
        break;
      case _Mouth.wavy:
        final path = Path()..moveTo(c.dx - r * 0.26, c.dy);
        for (int i = 0; i <= 4; i++) {
          final x = c.dx - r * 0.26 + i * r * 0.13;
          final y = c.dy + (i.isEven ? -r * 0.05 : r * 0.05);
          path.lineTo(x, y);
        }
        canvas.drawPath(path, line);
        break;
    }
  }

  void _sparkle(Canvas canvas, Offset c, double size) {
    final pulse = 0.6 + 0.4 * math.sin(t * math.pi * 6);
    final paint = Paint()..color = Colors.white.withOpacity(0.9 * pulse);
    final path = Path()
      ..moveTo(c.dx, c.dy - size)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + size, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + size)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - size, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - size)
      ..close();
    canvas.drawPath(path, paint);
  }

  // ---- Assistive devices --------------------------------------------------

  void _devices(Canvas canvas, Offset c, double r) {
    final left = Offset(c.dx - r * 0.98, c.dy + r * 0.06);
    final right = Offset(c.dx + r * 0.98, c.dy + r * 0.06);
    final wearLeft = config.hearingSide != HearingSide.right;
    final wearRight = config.hearingSide != HearingSide.left;

    switch (config.device) {
      case HearingDevice.none:
        break;
      case HearingDevice.hearingAid:
        if (wearLeft) _hearingAidAt(canvas, left, r, mirror: false);
        if (wearRight) _hearingAidAt(canvas, right, r, mirror: true);
        break;
      case HearingDevice.baha:
        if (wearLeft) _bahaAt(canvas, left, c, r, mirror: false);
        if (wearRight) _bahaAt(canvas, right, c, r, mirror: true);
        break;
      case HearingDevice.cochlear:
        if (wearLeft) _cochlearAt(canvas, left, c, r, mirror: false);
        if (wearRight) _cochlearAt(canvas, right, c, r, mirror: true);
        break;
    }
  }

  void _hearingAidAt(Canvas canvas, Offset ear, double r,
      {required bool mirror}) {
    final dir = mirror ? -1.0 : 1.0;
    final body = Rect.fromCenter(
        center: Offset(ear.dx + dir * r * 0.02, ear.dy + r * 0.02),
        width: r * 0.22,
        height: r * 0.36);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(r * 0.1)),
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            _lighten(config.favoriteColor, 0.2),
            _darken(config.favoriteColor, 0.1),
          ],
        ).createShader(body),
    );
    // Over-ear hook.
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(ear.dx, ear.dy - r * 0.12), radius: r * 0.16),
      mirror ? math.pi * 0.1 : math.pi * 0.5,
      math.pi * 0.9,
      false,
      Paint()
        ..color = _darken(config.favoriteColor, 0.15)
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // Status light.
    canvas.drawCircle(Offset(body.center.dx, body.top + r * 0.06), r * 0.04,
        Paint()..color = const Color(0xFF8BFFE0));
  }

  void _bahaAt(Canvas canvas, Offset ear, Offset head, double r,
      {required bool mirror}) {
    final dir = mirror ? -1.0 : 1.0;
    // Soft headband arc sweeping to the back of the head.
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: r * 1.02),
      mirror ? -math.pi * 0.15 : math.pi * 1.15,
      math.pi * 0.3,
      false,
      Paint()
        ..color = _darken(config.favoriteColor, 0.1)
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // Round bone-anchored processor behind/above the ear.
    final proc = Offset(ear.dx + dir * r * 0.16, ear.dy - r * 0.14);
    canvas.drawCircle(
      proc,
      r * 0.19,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: <Color>[
            _lighten(config.favoriteColor, 0.3),
            config.favoriteColor,
            _darken(config.favoriteColor, 0.2),
          ],
        ).createShader(Rect.fromCircle(center: proc, radius: r * 0.19)),
    );
    canvas.drawCircle(
        proc, r * 0.19, Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.02);
    // Centre abutment dot + highlight.
    canvas.drawCircle(proc, r * 0.05, Paint()..color = const Color(0xFFE9F6FF));
    canvas.drawCircle(proc + Offset(-r * 0.06, -r * 0.06), r * 0.03,
        Paint()..color = Colors.white.withOpacity(0.9));
  }

  void _cochlearAt(Canvas canvas, Offset ear, Offset head, double r,
      {required bool mirror}) {
    final dir = mirror ? -1.0 : 1.0;
    // Behind-the-ear sound processor.
    final body = Rect.fromCenter(
        center: Offset(ear.dx + dir * r * 0.02, ear.dy + r * 0.02),
        width: r * 0.2,
        height: r * 0.34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(r * 0.09)),
      Paint()
        ..shader = LinearGradient(colors: <Color>[
          _lighten(config.favoriteColor, 0.15),
          _darken(config.favoriteColor, 0.12),
        ]).createShader(body),
    );
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(ear.dx, ear.dy - r * 0.12), radius: r * 0.15),
      mirror ? math.pi * 0.1 : math.pi * 0.5,
      math.pi * 0.9,
      false,
      Paint()
        ..color = _darken(config.favoriteColor, 0.15)
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // Coil (round magnet) higher on the head.
    final coil = Offset(ear.dx + dir * r * 0.34, ear.dy - r * 0.5);
    // Thin cable from processor to coil.
    canvas.drawPath(
      Path()
        ..moveTo(body.center.dx, body.top)
        ..quadraticBezierTo(
            ear.dx + dir * r * 0.1, ear.dy - r * 0.4, coil.dx, coil.dy),
      Paint()
        ..color = _darken(config.favoriteColor, 0.2)
        ..strokeWidth = r * 0.03
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(coil, r * 0.15, Paint()..color = config.favoriteColor);
    canvas.drawCircle(coil, r * 0.15, Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.02);
    canvas.drawCircle(coil, r * 0.06,
        Paint()..color = _lighten(config.favoriteColor, 0.35));
  }

  void _glasses(Canvas canvas, Offset c, double r, _Face f) {
    final eyeY = c.dy + r * 0.02;
    final eyeDx = r * 0.42;
    final frame = Paint()
      ..color = const Color(0xFF2B2B2B)
      ..strokeWidth = r * 0.055
      ..style = PaintingStyle.stroke;
    final lensRect = Size(r * 0.62, r * 0.56);
    for (final sign in <double>[-1, 1]) {
      final rect = Rect.fromCenter(
          center: Offset(c.dx + sign * eyeDx, eyeY),
          width: lensRect.width,
          height: lensRect.height);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(r * 0.14)),
          Paint()..color = Colors.white.withOpacity(0.10));
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(r * 0.14)), frame);
    }
    canvas.drawLine(Offset(c.dx - r * 0.1, eyeY),
        Offset(c.dx + r * 0.1, eyeY), frame);
    // Temple arms to the ears.
    canvas.drawLine(Offset(c.dx - eyeDx - r * 0.3, eyeY),
        Offset(c.dx - r * 0.9, eyeY + r * 0.04), frame);
    canvas.drawLine(Offset(c.dx + eyeDx + r * 0.3, eyeY),
        Offset(c.dx + r * 0.9, eyeY + r * 0.04), frame);
  }

  // ---- Held props ---------------------------------------------------------

  void _prop(Canvas canvas, Offset headC, double headR, double s) {
    switch (pose) {
      case AvatarPose.brush:
        final h = _rHand;
        canvas.drawLine(
            h,
            Offset(h.dx - s * 0.06, h.dy - s * 0.05),
            Paint()
              ..color = config.favoriteColor
              ..strokeWidth = s * 0.03
              ..strokeCap = StrokeCap.round);
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
      case AvatarPose.bath:
        final mid =
            Offset((_lHand.dx + _rHand.dx) / 2, (_lHand.dy + _rHand.dy) / 2);
        final b = Paint()..color = Colors.white.withOpacity(0.75);
        for (int i = 0; i < 6; i++) {
          final ang = i / 6 * math.pi * 2 + t * 4;
          final p = mid +
              Offset(math.cos(ang), math.sin(ang)) *
                  s *
                  0.05 *
                  (0.6 + 0.4 * math.sin(t * 6 + i));
          canvas.drawCircle(p, s * 0.017, b);
        }
        break;
      case AvatarPose.eat:
        final h = _rHand;
        canvas.drawLine(
            h,
            Offset(h.dx, h.dy - s * 0.06),
            Paint()
              ..color = const Color(0xFFCED4DA)
              ..strokeWidth = s * 0.025
              ..strokeCap = StrokeCap.round);
        canvas.drawCircle(Offset(h.dx, h.dy - s * 0.07), s * 0.025,
            Paint()..color = const Color(0xFFCED4DA));
        break;
      case AvatarPose.sleep:
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
        z.paint(canvas,
            Offset(headC.dx + headR * 0.6, headC.dy - headR - (t * s * 0.2)));
        break;
      case AvatarPose.hold:
        canvas.drawCircle(_rHand, s * 0.045, Paint()..color = config.skin);
        canvas.drawCircle(_lHand, s * 0.045, Paint()..color = config.skin);
        break;
      case AvatarPose.dress:
        // A shirt held up in front.
        final r = Rect.fromCenter(
            center: Offset((headC.dx), _rHand.dy + s * 0.02),
            width: s * 0.18,
            height: s * 0.14);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(s * 0.03)),
          Paint()..color = config.favoriteColor.withOpacity(0.9),
        );
        break;
      case AvatarPose.idle:
      case AvatarPose.wave:
      case AvatarPose.sit:
      case AvatarPose.walk:
      case AvatarPose.point:
      case AvatarPose.clap:
      case AvatarPose.cheer:
      case AvatarPose.potty:
        break;
    }
  }

  Color _lighten(Color c, double amt) =>
      Color.lerp(c, Colors.white, amt.clamp(0.0, 1.0))!;
  Color _darken(Color c, double amt) =>
      Color.lerp(c, Colors.black, amt.clamp(0.0, 1.0))!;

  @override
  bool shouldRepaint(covariant _CharacterPainter old) =>
      old.t != t ||
      old.pose != pose ||
      old.emotion != emotion ||
      old.config != config;
}
