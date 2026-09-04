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
  // Appended at the END so persisted pose indices stay stable.
  school,
  run,
  jump,
  think,
  listen,
  stretch,
  breathe,
  drink,
  help,
  takeBreak,
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
  // Appended at the END so persisted emotion indices stay stable.
  silly,
  loving,
  relaxed,
  sleepy,
  curious,
  thinking,
  confused,
  surprised,
  worried,
  angry,
  scared,
  overwhelmed,
  shy,
  kind,
  listening,
  encouraging,
}

/// Hari is the universal HARSHIVOS friend. These aliases let every screen speak
/// in Hari's language — `Hari(emotion: HariEmotion.excited, pose: HariPose.jump)`
/// — while reusing the one shared character rig underneath.
typedef HariEmotion = AvatarEmotion;
typedef HariPose = AvatarPose;

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

  /// HARI — the universal HARSHIVOS friend. A warm, culturally-neutral look
  /// with a signature soft hoodie. Hari is never defined by a device (none by
  /// default); families add one only when personalising their own avatar.
  static const AvatarConfig hari = AvatarConfig(
    gender: AvatarGender.neutral,
    skin: Color(0xFFF3C7A0),
    hair: HairStyle.short,
    hairColor: Color(0xFF4A2F1C),
    eyeColor: Color(0xFF4A2E1C),
    shirt: Color(0xFFEFF2F7),
    favoriteColor: Color(0xFF3AA0FF),
    device: HearingDevice.none,
    hearingSide: HearingSide.both,
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
    case AvatarPose.school:
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
    case AvatarPose.run:
    case AvatarPose.jump:
      return AvatarEmotion.excited;
    case AvatarPose.think:
      return AvatarEmotion.thinking;
    case AvatarPose.listen:
      return AvatarEmotion.listening;
    case AvatarPose.stretch:
    case AvatarPose.breathe:
    case AvatarPose.drink:
    case AvatarPose.takeBreak:
      return AvatarEmotion.calm;
    case AvatarPose.help:
      return AvatarEmotion.worried;
    case AvatarPose.sleep:
      return AvatarEmotion.sleepy;
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

/// The universal HARSHIVOS friend. A thin, friendly wrapper over the shared
/// character rig so every screen can speak in Hari's language:
///
///   Hari(emotion: HariEmotion.excited, pose: HariPose.jump)
///
/// Pass [config] to render a family's personalised "My Avatar" instead of the
/// default mascot; otherwise Hari appears, with an optional [device].
class Hari extends StatelessWidget {
  const Hari({
    super.key,
    this.emotion = HariEmotion.happy,
    this.pose = HariPose.idle,
    this.device = HearingDevice.none,
    this.hearingSide = HearingSide.left,
    this.config,
    this.animate = true,
  });

  final HariEmotion emotion;
  final HariPose pose;
  final HearingDevice device;
  final HearingSide hearingSide;
  final AvatarConfig? config;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final resolved = config ??
        AvatarConfig.hari.copyWith(device: device, hearingSide: hearingSide);
    return AvatarWidget(
      config: resolved,
      emotion: emotion,
      pose: pose,
      animate: animate,
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
    this.cheeks = false,
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
  final bool cheeks; // raised-cheek highlight for a genuine smile
  final Offset pupil; // fractional pupil offset
}

enum _Mouth { smile, grin, openSmile, bigGrin, frown, grimace, flat, wavy, o }

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

    // Childlike chibi proportions: a big, expressive head over a soft body.
    final headR = s * 0.20;
    final headC = Offset(cx, cy - s * 0.115);
    final bodyTop = headC.dy + headR * 0.80;

    _shadow(canvas, Offset(cx, cy + s * 0.37), s, face);
    _legs(canvas, cx, bodyTop, s);
    _body(canvas, cx, bodyTop, s);
    _arms(canvas, cx, bodyTop, headC, headR, s, face);

    // A small childlike neck connects head to hoodie.
    _neck(canvas, cx, headC, headR, bodyTop, s);

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
          // Happy squint + raised cheeks + a wide grin read as JOY, not the
          // wide-eyed round-mouth look that reads as surprise.
          eyeOpen: blinking ? 0.08 : 0.8,
          browLift: 0.14,
          browTilt: -0.04,
          mouth: _Mouth.bigGrin,
          blush: 0.85,
          headTilt: 0.05 * math.sin(t * math.pi * 4),
          bounce: 2.2,
          sparkle: true,
          cheeks: true,
          pupil: const Offset(0, 0.02),
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
      case AvatarEmotion.silly:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.86,
          browLift: 0.16,
          browTilt: -0.03,
          mouth: _Mouth.bigGrin,
          blush: 0.85,
          headTilt: 0.14 * math.sin(t * math.pi * 3),
          bounce: 1.8,
          sparkle: true,
          cheeks: true,
          pupil: Offset(math.sin(t * math.pi * 3) * 0.12, -0.03),
        );
      case AvatarEmotion.loving:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.62,
          browLift: 0.10,
          browTilt: -0.05,
          mouth: _Mouth.smile,
          blush: 0.95,
          headTilt: 0.05,
          bounce: 0.9,
          sparkle: true,
          cheeks: true,
          pupil: const Offset(0, 0.02),
        );
      case AvatarEmotion.relaxed:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.7,
          browLift: 0.05,
          browTilt: -0.05,
          mouth: _Mouth.grin,
          blush: 0.4,
          headTilt: 0.04 * math.sin(t * math.pi * 2),
          bounce: 0.75,
          cheeks: true,
          pupil: idlePupil,
        );
      case AvatarEmotion.sleepy:
        return _Face(
          eyeOpen: 0.26,
          browLift: 0.0,
          browTilt: -0.10,
          mouth: _Mouth.o,
          blush: 0.3,
          headTilt: 0.12 + 0.03 * math.sin(t * math.pi * 2),
          bounce: 0.55,
          pupil: const Offset(0, 0.10),
        );
      case AvatarEmotion.curious:
        return _Face(
          eyeOpen: blinking ? 0.08 : 1.0,
          browLift: 0.20,
          browTilt: -0.06,
          mouth: _Mouth.o,
          blush: 0.4,
          headTilt: 0.12,
          bounce: 1.0,
          pupil: const Offset(0.14, -0.06),
        );
      case AvatarEmotion.thinking:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.82,
          browLift: 0.08,
          browTilt: 0.04,
          mouth: _Mouth.flat,
          blush: 0.3,
          headTilt: -0.06,
          bounce: 0.8,
          pupil: const Offset(0.16, -0.12),
        );
      case AvatarEmotion.confused:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.9,
          browLift: 0.12,
          browTilt: -0.10,
          mouth: _Mouth.wavy,
          blush: 0.35,
          headTilt: 0.16,
          bounce: 0.9,
          pupil: Offset(math.sin(t * math.pi * 2) * 0.12, -0.02),
        );
      case AvatarEmotion.surprised:
        return _Face(
          eyeOpen: 1.0,
          browLift: 0.24,
          browTilt: -0.05,
          mouth: _Mouth.o,
          blush: 0.5,
          headTilt: -0.03,
          bounce: 1.3,
          pupil: const Offset(0, -0.04),
        );
      case AvatarEmotion.worried:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.92,
          browLift: 0.06,
          browTilt: -0.28,
          mouth: _Mouth.frown,
          blush: 0.3,
          headTilt: 0.07,
          bounce: 0.7,
          pupil: const Offset(0, 0.08),
        );
      case AvatarEmotion.angry:
        return _Face(
          eyeOpen: 0.7,
          browLift: -0.08,
          browTilt: 0.42,
          mouth: _Mouth.grimace,
          blush: 0.55,
          headTilt: -0.04,
          bounce: 0.9,
          pupil: const Offset(0, 0.02),
        );
      case AvatarEmotion.scared:
        return _Face(
          eyeOpen: 1.0,
          browLift: 0.16,
          browTilt: -0.30,
          mouth: _Mouth.o,
          blush: 0.25,
          headTilt: 0.04,
          bounce: 0.7,
          sweat: true,
          pupil: Offset(math.sin(t * math.pi * 9) * 0.06, 0.02),
        );
      case AvatarEmotion.overwhelmed:
        return _Face(
          eyeOpen: 0.5,
          browLift: 0.04,
          browTilt: -0.24,
          mouth: _Mouth.wavy,
          blush: 0.4,
          headTilt: 0.10,
          bounce: 0.5,
          sweat: true,
          tear: true,
          pupil: const Offset(0, 0.10),
        );
      case AvatarEmotion.shy:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.66,
          browLift: 0.08,
          browTilt: -0.10,
          mouth: _Mouth.grin,
          blush: 1.0,
          headTilt: 0.14,
          bounce: 0.8,
          cheeks: true,
          pupil: const Offset(-0.16, 0.06),
        );
      case AvatarEmotion.kind:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.8,
          browLift: 0.10,
          browTilt: -0.06,
          mouth: _Mouth.smile,
          blush: 0.6,
          headTilt: 0.06,
          bounce: 0.9,
          cheeks: true,
          pupil: const Offset(0, 0.03),
        );
      case AvatarEmotion.listening:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.95,
          browLift: 0.12,
          browTilt: -0.05,
          mouth: _Mouth.grin,
          blush: 0.4,
          headTilt: 0.16,
          bounce: 0.85,
          pupil: const Offset(0.12, 0),
        );
      case AvatarEmotion.encouraging:
        return _Face(
          eyeOpen: blinking ? 0.08 : 0.9,
          browLift: 0.16,
          browTilt: -0.05,
          mouth: _Mouth.bigGrin,
          blush: 0.7,
          headTilt: -0.04,
          bounce: 1.3,
          sparkle: true,
          cheeks: true,
          pupil: const Offset(0, -0.02),
        );
    }
  }

  // ---- Body ---------------------------------------------------------------

  // A soft dark outline colour that unifies the silhouette (clean, modern,
  // and readable at small sizes).
  Color get _ink => const Color(0xFF2E2748);

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
    final w = s * 0.33;
    final h = s * 0.30;
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(cx - w / 2, bodyTop, w, h),
      topLeft: Radius.circular(s * 0.16),
      topRight: Radius.circular(s * 0.16),
      bottomLeft: Radius.circular(s * 0.15),
      bottomRight: Radius.circular(s * 0.15),
    );
    // Hood resting behind the neck (peeks above the collar).
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, bodyTop + s * 0.005),
          width: s * 0.30,
          height: s * 0.18),
      math.pi + 0.25,
      math.pi - 0.5,
      false,
      Paint()
        ..color = _darken(config.shirt, 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..strokeCap = StrokeCap.round,
    );
    // Outline + soft hoodie fill.
    canvas.drawRRect(rect.inflate(s * 0.014), Paint()..color = _ink);
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _lighten(config.shirt, 0.20),
            config.shirt,
            _darken(config.shirt, 0.12),
          ],
        ).createShader(rect.outerRect),
    );
    // Front pocket.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, bodyTop + h * 0.66),
            width: w * 0.58,
            height: h * 0.26),
        Radius.circular(s * 0.03),
      ),
      Paint()..color = _darken(config.shirt, 0.09),
    );
    // Favourite-colour cuff at the hem.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w / 2, bodyTop + h - s * 0.035, w, s * 0.045),
        Radius.circular(s * 0.02),
      ),
      Paint()..color = config.favoriteColor.withOpacity(0.92),
    );
    // Soft shoulder highlight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            cx - w / 2 + s * 0.02, bodyTop + s * 0.015, w * 0.5, h * 0.26),
        Radius.circular(s * 0.11),
      ),
      Paint()..color = Colors.white.withOpacity(0.12),
    );
    // Rounded shoulders so the hoodie has visible breadth and the sleeves
    // have a believable origin.
    for (final sx in <double>[-1, 1]) {
      final sc = Offset(cx + sx * w * 0.44, bodyTop + s * 0.03);
      canvas.drawCircle(sc, s * 0.058 + s * 0.012, Paint()..color = _ink);
      canvas.drawCircle(
          sc, s * 0.058, Paint()..color = _lighten(config.shirt, 0.08));
    }
    _chestHeart(canvas, Offset(cx, bodyTop + h * 0.33), s * 0.058);
  }

  void _neck(Canvas canvas, double cx, Offset headC, double headR,
      double bodyTop, double s) {
    final top = headC.dy + headR * 0.70;
    final bottom = bodyTop + s * 0.03;
    final w = s * 0.095;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - w / 2, top, cx + w / 2, bottom),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(rect.inflate(s * 0.008), Paint()..color = _ink);
    canvas.drawRRect(rect, Paint()..color = _darken(config.skin, 0.05));
    // Soft chin shadow for depth.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, top + s * 0.005),
          width: w * 1.7,
          height: s * 0.03),
      Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012),
    );
  }

  void _chestHeart(Canvas canvas, Offset c, double size) {
    final path = _heartPath(c, size);
    canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(0.95));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF5C8A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.34
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _heartPath(Offset c, double size) {
    return Path()
      ..moveTo(c.dx, c.dy + size * 0.38)
      ..cubicTo(c.dx - size * 1.05, c.dy - size * 0.30, c.dx - size * 0.5,
          c.dy - size * 1.05, c.dx, c.dy - size * 0.34)
      ..cubicTo(c.dx + size * 0.5, c.dy - size * 1.05, c.dx + size * 1.05,
          c.dy - size * 0.30, c.dx, c.dy + size * 0.38)
      ..close();
  }

  void _legs(Canvas canvas, double cx, double bodyTop, double s) {
    final hipY = bodyTop + s * 0.30;
    const legColor = Color(0xFF3C4A6B);
    final sit = pose == AvatarPose.sit || pose == AvatarPose.potty;
    final walking = pose == AvatarPose.walk ||
        pose == AvatarPose.school ||
        pose == AvatarPose.run;
    final swing = walking
        ? math.sin(t * math.pi * (pose == AvatarPose.run ? 8 : 4)) * s * 0.06
        : 0.0;

    void legPart(Offset hip, Offset knee, Offset ankle, Offset toe) {
      _fillLimb(canvas, hip, knee, s * 0.052, s * 0.044, legColor, s);
      _fillLimb(canvas, knee, ankle, s * 0.044, s * 0.038, legColor, s);
      _foot(canvas, ankle, toe, s);
    }

    if (sit) {
      final lHip = Offset(cx - s * 0.08, hipY);
      final rHip = Offset(cx + s * 0.08, hipY);
      final lKnee = Offset(cx - s * 0.14, hipY + s * 0.03);
      final rKnee = Offset(cx + s * 0.14, hipY + s * 0.03);
      final lAnkle = Offset(cx - s * 0.15, hipY + s * 0.10);
      final rAnkle = Offset(cx + s * 0.15, hipY + s * 0.10);
      legPart(lHip, lKnee, lAnkle, lAnkle + Offset(-s * 0.07, 0));
      legPart(rHip, rKnee, rAnkle, rAnkle + Offset(s * 0.07, 0));
      return;
    }
    final lHip = Offset(cx - s * 0.075, hipY);
    final rHip = Offset(cx + s * 0.075, hipY);
    final lKnee = Offset(lHip.dx + swing * 0.4, hipY + s * 0.07);
    final rKnee = Offset(rHip.dx - swing * 0.4, hipY + s * 0.07);
    final lAnkle = Offset(lHip.dx + swing, hipY + s * 0.14);
    final rAnkle = Offset(rHip.dx - swing, hipY + s * 0.14);
    legPart(lHip, lKnee, lAnkle, lAnkle + Offset(-s * 0.06, 0));
    legPart(rHip, rKnee, rAnkle, rAnkle + Offset(s * 0.06, 0));
  }

  // A directional child shoe: rounded sole pointing toward [toe].
  void _foot(Canvas canvas, Offset ankle, Offset toe, double s) {
    final dir = toe - ankle;
    final len = dir.distance;
    final n = len < 1e-3 ? const Offset(1, 0) : dir / len;
    final heel = ankle - n * s * 0.012;
    final tip = ankle + n * s * 0.085 + Offset(0, s * 0.008);
    canvas.drawLine(
        heel,
        tip,
        Paint()
          ..color = _ink
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.078
          ..style = PaintingStyle.stroke);
    canvas.drawLine(
        heel,
        tip,
        Paint()
          ..color = _darken(config.favoriteColor, 0.05)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.056
          ..style = PaintingStyle.stroke);
    canvas.drawCircle(
        tip, s * 0.03, Paint()..color = _lighten(config.favoriteColor, 0.16));
    canvas.drawLine(
        heel + Offset(0, s * 0.028),
        tip + Offset(0, s * 0.022),
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.012
          ..style = PaintingStyle.stroke);
  }

  void _arms(Canvas canvas, double cx, double bodyTop, Offset headC,
      double headR, double s, _Face face) {
    final shoulderY = bodyTop + s * 0.02;
    final lShoulder = Offset(cx - s * 0.14, shoulderY);
    final rShoulder = Offset(cx + s * 0.14, shoulderY);

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
      case AvatarPose.walk:
      case AvatarPose.school:
        // Arms swing opposite the legs for a believable stride.
        final sw = math.sin(t * math.pi * 4) * s * 0.06;
        lHand = Offset(cx - s * 0.14, shoulderY + s * 0.17 - sw);
        rHand = Offset(cx + s * 0.14, shoulderY + s * 0.17 + sw);
        break;
      case AvatarPose.idle:
      case AvatarPose.sit:
      case AvatarPose.potty:
        final sway = math.sin(t * math.pi * 2) * s * 0.012 * face.bounce;
        lHand = Offset(cx - s * 0.205, shoulderY + s * 0.19 + sway);
        rHand = Offset(cx + s * 0.205, shoulderY + s * 0.19 - sway);
        break;
      case AvatarPose.jump:
        lHand = Offset(cx - s * 0.20, headC.dy - s * 0.03);
        rHand = Offset(cx + s * 0.20, headC.dy - s * 0.03);
        break;
      case AvatarPose.run:
        final sw = math.sin(t * math.pi * 8) * s * 0.09;
        lHand = Offset(cx - s * 0.12, shoulderY + s * 0.10 - sw);
        rHand = Offset(cx + s * 0.12, shoulderY + s * 0.10 + sw);
        break;
      case AvatarPose.think:
        rHand = Offset(cx + s * 0.05, headC.dy + s * 0.13);
        lHand = Offset(cx - s * 0.16, shoulderY + s * 0.16);
        break;
      case AvatarPose.listen:
        rHand = Offset(cx + s * 0.18, headC.dy + s * 0.02);
        lHand = Offset(cx - s * 0.16, shoulderY + s * 0.16);
        break;
      case AvatarPose.stretch:
        final st = math.sin(t * math.pi * 2) * s * 0.02;
        lHand = Offset(cx - s * 0.18, headC.dy - s * 0.07 - st);
        rHand = Offset(cx + s * 0.18, headC.dy - s * 0.07 - st);
        break;
      case AvatarPose.breathe:
        final br = math.sin(t * math.pi * 2) * s * 0.02;
        lHand = Offset(cx - s * 0.06, shoulderY + s * 0.14 + br);
        rHand = Offset(cx + s * 0.06, shoulderY + s * 0.14 + br);
        break;
      case AvatarPose.drink:
        rHand = Offset(cx + s * 0.04, headC.dy + s * 0.11);
        lHand = Offset(cx - s * 0.16, shoulderY + s * 0.16);
        break;
      case AvatarPose.help:
        final w = math.sin(t * math.pi * 5) * s * 0.02;
        rHand = Offset(cx + s * 0.13 + w, headC.dy - s * 0.12);
        lHand = Offset(cx - s * 0.16, shoulderY + s * 0.16);
        break;
      case AvatarPose.takeBreak:
        lHand = Offset(cx - s * 0.05, shoulderY + s * 0.06);
        rHand = Offset(cx + s * 0.11, shoulderY + s * 0.02);
        break;
    }

    final open = pose == AvatarPose.wave ||
        pose == AvatarPose.cheer ||
        pose == AvatarPose.clap ||
        pose == AvatarPose.hold ||
        pose == AvatarPose.point ||
        pose == AvatarPose.jump ||
        pose == AvatarPose.stretch ||
        pose == AvatarPose.help;
    _limb(canvas, lShoulder, lHand, s, left: true);
    _limb(canvas, rShoulder, rHand, s, left: false);
    _hand(canvas, lHand, lShoulder, s, open: open);
    _hand(canvas, rHand, rShoulder, s, open: open);
    _rHand = rHand;
    _lHand = lHand;
  }

  /// One arm as a sleeve (hoodie) + forearm (skin), both FILLED tapered
  /// shapes with rounded joints — real volume, not a stroke.
  void _limb(Canvas canvas, Offset shoulder, Offset hand, double s,
      {required bool left}) {
    final dir = hand - shoulder;
    final len = dir.distance;
    final n = len < 1e-3 ? const Offset(0, 1) : dir / len;
    final perp = Offset(-n.dy, n.dx);
    final outward = left ? -1.0 : 1.0;
    final elbow = shoulder + n * (len * 0.46) + perp * (s * 0.035 * outward);
    _fillLimb(canvas, shoulder, elbow, s * 0.056, s * 0.046, config.shirt, s);
    _fillLimb(canvas, elbow, hand, s * 0.044, s * 0.037, config.skin, s);
  }

  /// A filled tapered limb segment with rounded joints, ink outline and a soft
  /// form highlight down one edge.
  void _fillLimb(Canvas canvas, Offset a, Offset b, double wa, double wb,
      Color color, double s) {
    final ink = s * 0.013;
    final inkP = Paint()..color = _ink;
    canvas.drawPath(_quad(a, b, wa + ink, wb + ink), inkP);
    canvas.drawCircle(a, wa + ink, inkP);
    canvas.drawCircle(b, wb + ink, inkP);
    final cp = Paint()..color = color;
    canvas.drawPath(_quad(a, b, wa, wb), cp);
    canvas.drawCircle(a, wa, cp);
    canvas.drawCircle(b, wb, cp);
    final d = b - a;
    final n = d.distance < 1e-3 ? const Offset(0, 1) : d / d.distance;
    final perp = Offset(-n.dy, n.dx);
    canvas.drawPath(
      _quad(a + perp * (wa * 0.42), b + perp * (wb * 0.42), wa * 0.26,
          wb * 0.26),
      Paint()..color = Colors.white.withOpacity(0.10),
    );
  }

  Path _quad(Offset a, Offset b, double wa, double wb) {
    final d = b - a;
    final n = d.distance < 1e-3 ? const Offset(0, 1) : d / d.distance;
    final perp = Offset(-n.dy, n.dx);
    return Path()
      ..moveTo(a.dx + perp.dx * wa, a.dy + perp.dy * wa)
      ..lineTo(b.dx + perp.dx * wb, b.dy + perp.dy * wb)
      ..lineTo(b.dx - perp.dx * wb, b.dy - perp.dy * wb)
      ..lineTo(a.dx - perp.dx * wa, a.dy - perp.dy * wa)
      ..close();
  }

  /// A soft, friendly hand — outlined rounded palm with plump round-capped
  /// fingers (never thin sticks). [open] fans the fingers for a wave / reach.
  void _hand(Canvas canvas, Offset wrist, Offset from, double s,
      {bool open = false}) {
    final ang = math.atan2(wrist.dy - from.dy, wrist.dx - from.dx);
    final palmR = s * 0.052;
    final ink = Paint()..color = _ink;
    final skin = Paint()..color = config.skin;

    if (open) {
      const count = 4;
      const spread = 0.30;
      // Ink layer then skin layer = plump, defined fingers.
      for (final outline in <bool>[true, false]) {
        final p = Paint()
          ..color = outline ? _ink : config.skin
          ..strokeCap = StrokeCap.round
          ..strokeWidth = palmR * (outline ? 0.84 : 0.62);
        for (int i = 0; i < count; i++) {
          final fa = ang + (i - (count - 1) / 2) * spread;
          final base = wrist + Offset(math.cos(fa), math.sin(fa)) * palmR * 0.7;
          final tip = wrist + Offset(math.cos(fa), math.sin(fa)) * palmR * 1.6;
          canvas.drawLine(base, tip, p);
        }
        final ta = ang - 1.15;
        final tBase = wrist + Offset(math.cos(ta), math.sin(ta)) * palmR * 0.5;
        final tTip = wrist + Offset(math.cos(ta), math.sin(ta)) * palmR * 1.3;
        canvas.drawLine(
            tBase, tTip, p..strokeWidth = palmR * (outline ? 0.96 : 0.74));
      }
      canvas.drawCircle(wrist, palmR + s * 0.008, ink);
      canvas.drawCircle(wrist, palmR, skin);
    } else {
      canvas.drawCircle(wrist, palmR * 1.05 + s * 0.008, ink);
      canvas.drawCircle(wrist, palmR * 1.05, skin);
      final ta = ang - 1.0;
      final thumb = wrist + Offset(math.cos(ta), math.sin(ta)) * palmR * 0.85;
      canvas.drawCircle(thumb, palmR * 0.52 + s * 0.006, ink);
      canvas.drawCircle(thumb, palmR * 0.52, skin);
    }
    // Soft knuckle shading for form.
    canvas.drawArc(
      Rect.fromCircle(center: wrist, radius: palmR * 0.82),
      ang - 1.2,
      1.4,
      false,
      Paint()
        ..color = _darken(config.skin, 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = palmR * 0.16
        ..strokeCap = StrokeCap.round,
    );
  }

  // ---- Head, hair, face ---------------------------------------------------

  void _head(Canvas canvas, Offset c, double r) {
    // Ears behind the head, outlined.
    for (final sign in <double>[-1, 1]) {
      final e = Rect.fromCenter(
          center: Offset(c.dx + sign * r * 0.92, c.dy + r * 0.14),
          width: r * 0.44,
          height: r * 0.54);
      canvas.drawOval(e.inflate(r * 0.045), Paint()..color = _ink);
      canvas.drawOval(e, Paint()..color = config.skin);
      canvas.drawArc(
          e.deflate(r * 0.09),
          sign < 0 ? -0.6 : math.pi - 0.6,
          1.6,
          false,
          Paint()
            ..color = _darken(config.skin, 0.14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.025);
    }
    // Soft, path-based child face (rounded cranium, full cheeks, gentle chin).
    final face = _facePath(c, r);
    canvas.drawPath(
      face,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.42),
          radius: 1.15,
          colors: <Color>[
            _lighten(config.skin, 0.17),
            config.skin,
            _darken(config.skin, 0.05),
          ],
          stops: const <double>[0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
    );
    canvas.drawPath(
      face,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeJoin = StrokeJoin.round,
    );
    // Form light + jaw occlusion, clipped to the face.
    canvas.save();
    canvas.clipPath(face);
    canvas.drawCircle(
      Offset(c.dx - r * 0.52, c.dy - r * 0.46),
      r * 0.55,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
    );
    canvas.drawCircle(
      Offset(c.dx + r * 0.32, c.dy + r * 0.78),
      r * 0.5,
      Paint()
        ..color = _darken(config.skin, 0.10).withOpacity(0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2),
    );
    canvas.restore();
  }

  /// A soft child face silhouette: rounded cranium, full cheeks, gentle chin.
  Path _facePath(Offset c, double r) {
    return Path()
      ..moveTo(c.dx, c.dy - r * 1.0)
      ..cubicTo(c.dx + r * 0.86, c.dy - r * 1.0, c.dx + r * 1.0,
          c.dy - r * 0.25, c.dx + r * 0.94, c.dy + r * 0.30)
      ..cubicTo(c.dx + r * 0.9, c.dy + r * 0.74, c.dx + r * 0.52,
          c.dy + r * 1.03, c.dx, c.dy + r * 1.05)
      ..cubicTo(c.dx - r * 0.52, c.dy + r * 1.03, c.dx - r * 0.9,
          c.dy + r * 0.74, c.dx - r * 0.94, c.dy + r * 0.30)
      ..cubicTo(c.dx - r * 1.0, c.dy - r * 0.25, c.dx - r * 0.86,
          c.dy - r * 1.0, c.dx, c.dy - r * 1.0)
      ..close();
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
        // A soft rounded cap with lock scallops at the fringe, above the brows.
        final cap = Path()
          ..moveTo(c.dx - r * 0.96, c.dy + r * 0.06)
          ..cubicTo(c.dx - r * 1.04, c.dy - r * 0.72, c.dx - r * 0.5,
              c.dy - r * 1.16, c.dx, c.dy - r * 1.13)
          ..cubicTo(c.dx + r * 0.5, c.dy - r * 1.16, c.dx + r * 1.04,
              c.dy - r * 0.72, c.dx + r * 0.96, c.dy + r * 0.06)
          ..cubicTo(c.dx + r * 0.72, c.dy - r * 0.34, c.dx + r * 0.54,
              c.dy - r * 0.30, c.dx + r * 0.36, c.dy - r * 0.44)
          ..cubicTo(c.dx + r * 0.22, c.dy - r * 0.30, c.dx + r * 0.10,
              c.dy - r * 0.34, c.dx - r * 0.04, c.dy - r * 0.48)
          ..cubicTo(c.dx - r * 0.20, c.dy - r * 0.32, c.dx - r * 0.34,
              c.dy - r * 0.34, c.dx - r * 0.50, c.dy - r * 0.46)
          ..cubicTo(c.dx - r * 0.70, c.dy - r * 0.34, c.dx - r * 0.86,
              c.dy - r * 0.18, c.dx - r * 0.96, c.dy + r * 0.06)
          ..close();
        canvas.drawPath(cap, paint);
        canvas.drawPath(
          cap,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.04
            ..strokeJoin = StrokeJoin.round,
        );
        // A soft parted lock highlight for texture.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.1, c.dy - r * 0.95)
            ..cubicTo(c.dx + r * 0.3, c.dy - r * 0.9, c.dx + r * 0.5,
                c.dy - r * 0.5, c.dx + r * 0.34, c.dy - r * 0.44)
            ..cubicTo(c.dx + r * 0.4, c.dy - r * 0.7, c.dx + r * 0.1,
                c.dy - r * 0.86, c.dx - r * 0.1, c.dy - r * 0.95)
            ..close(),
          Paint()..color = Colors.white.withOpacity(0.12),
        );
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
    final eyeY = c.dy + r * 0.04;
    final eyeDx = r * 0.40;
    final eyeR = r * 0.36;

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

    // Raised-cheek highlights make a smile read as genuine joy.
    if (f.cheeks) {
      final hl = Paint()
        ..color = Colors.white.withOpacity(0.14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06);
      canvas.drawCircle(Offset(c.dx - r * 0.5, c.dy + r * 0.34), r * 0.18, hl);
      canvas.drawCircle(Offset(c.dx + r * 0.5, c.dy + r * 0.34), r * 0.18, hl);
    }

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
    final scleraW = r * 0.70;
    final scleraH = r * 0.86 * open;
    final scleraRect =
        Rect.fromCenter(center: center, width: scleraW, height: scleraH);

    if (open < 0.14) {
      // Closed / blinking — a soft happy lash line.
      final p = Paint()
        ..color = const Color(0xFF3A2B22)
        ..strokeWidth = r * 0.10
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
          Rect.fromCenter(center: center, width: scleraW, height: r * 0.32),
          0.15,
          math.pi - 0.3,
          false,
          p);
      return;
    }

    // Soft dark eye outline ring for definition.
    canvas.drawOval(
        scleraRect.inflate(r * 0.03), Paint()..color = _ink.withOpacity(0.5));

    canvas.save();
    canvas.clipPath(Path()..addOval(scleraRect));

    // Sclera.
    canvas.drawOval(scleraRect, Paint()..color = const Color(0xFFF7FBFF));

    // Iris + pupil follow the look direction.
    final look = Offset(f.pupil.dx * r * (mirror ? -1 : 1), f.pupil.dy * r);
    final irisC = center + look + Offset(0, scleraH * 0.02);
    final irisR = r * 0.34;
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
    canvas.drawCircle(irisC, r * 0.17, Paint()..color = const Color(0xFF1A140F));
    // Catchlights (the soul of a warm eye).
    canvas.drawCircle(irisC + Offset(-irisR * 0.34, -irisR * 0.4), r * 0.12,
        Paint()..color = Colors.white.withOpacity(0.96));
    canvas.drawCircle(irisC + Offset(irisR * 0.34, irisR * 0.28), r * 0.06,
        Paint()..color = Colors.white.withOpacity(0.75));

    // Upper-lid shadow for roundness.
    canvas.drawArc(
      scleraRect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
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
        ..strokeWidth = r * 0.07
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
      case _Mouth.bigGrin:
        // A broad, upturned open smile — wider than tall so it reads as a
        // joyful laugh rather than a round 'surprised' O.
        final rect =
            Rect.fromCenter(center: c, width: r * 0.74, height: r * 0.46);
        final path = Path()
          ..moveTo(rect.left, rect.center.dy - rect.height * 0.12)
          ..quadraticBezierTo(c.dx, rect.top - rect.height * 0.28, rect.right,
              rect.center.dy - rect.height * 0.12)
          ..quadraticBezierTo(c.dx, rect.bottom + rect.height * 0.18, rect.left,
              rect.center.dy - rect.height * 0.12)
          ..close();
        canvas.drawPath(path, fill);
        // Upper teeth strip following the smile curve.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + r * 0.07,
                rect.center.dy - rect.height * 0.22, rect.width - r * 0.14,
                r * 0.13),
            Radius.circular(r * 0.05),
          ),
          teeth,
        );
        // Tongue peeking at the bottom.
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(c.dx, rect.bottom - r * 0.05),
                width: r * 0.32,
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
        // Hands are now drawn with fingers by _hand(); nothing extra needed.
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
      case AvatarPose.school:
        // A backpack — the universal 'going to school' signal.
        final bx = headC.dx;
        final bodyTop = headC.dy + headR * 0.82;
        final strap = Paint()
          ..color = _darken(config.favoriteColor, 0.05)
          ..strokeWidth = s * 0.028
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(bx - s * 0.09, bodyTop + s * 0.01),
            Offset(bx - s * 0.05, bodyTop + s * 0.20), strap);
        canvas.drawLine(Offset(bx + s * 0.09, bodyTop + s * 0.01),
            Offset(bx + s * 0.05, bodyTop + s * 0.20), strap);
        final pack = Rect.fromCenter(
            center: Offset(bx + s * 0.21, bodyTop + s * 0.13),
            width: s * 0.16,
            height: s * 0.22);
        canvas.drawRRect(
          RRect.fromRectAndRadius(pack, Radius.circular(s * 0.045)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _lighten(config.favoriteColor, 0.2),
                config.favoriteColor,
                _darken(config.favoriteColor, 0.18),
              ],
            ).createShader(pack),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(pack.center.dx, pack.center.dy + s * 0.03),
                width: s * 0.10,
                height: s * 0.09),
            Radius.circular(s * 0.02),
          ),
          Paint()..color = _darken(config.favoriteColor, 0.12),
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
      case AvatarPose.run:
      case AvatarPose.jump:
      case AvatarPose.think:
      case AvatarPose.listen:
      case AvatarPose.stretch:
      case AvatarPose.breathe:
      case AvatarPose.help:
      case AvatarPose.takeBreak:
        break;
      case AvatarPose.drink:
        final h = _rHand;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(h.dx, h.dy - s * 0.02),
                width: s * 0.06,
                height: s * 0.075),
            Radius.circular(s * 0.012),
          ),
          Paint()..color = const Color(0xFF7FD1FF),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(h.dx, h.dy - s * 0.05),
                width: s * 0.062,
                height: s * 0.014),
            Radius.circular(s * 0.006),
          ),
          Paint()..color = Colors.white.withOpacity(0.7),
        );
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
