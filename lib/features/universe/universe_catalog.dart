import 'package:flutter/material.dart';

import '../antistress/toys/bubble_wrap.dart';
import '../antistress/toys/click_pen.dart';
import '../antistress/toys/combo_lock.dart';
import '../antistress/toys/dimmer_knob.dart';
import '../antistress/toys/fidget_spinner.dart';
import '../antistress/toys/gears.dart';
import '../antistress/toys/keypad.dart';
import '../antistress/toys/kinetic_dots.dart';
import '../antistress/toys/latch_bolt.dart';
import '../antistress/toys/lava_blobs.dart';
import '../antistress/toys/newtons_cradle.dart';
import '../antistress/toys/pendulum_waves.dart';
import '../antistress/toys/pop_it.dart';
import '../antistress/toys/rotary_dial.dart';
import '../antistress/toys/sand_fall.dart';
import '../antistress/toys/slinky.dart';
import '../antistress/toys/spin_wheel.dart';
import '../antistress/toys/stress_ball.dart';
import '../antistress/toys/switch_board.dart';
import '../antistress/toys/water_drop.dart';
import '../antistress/toys/zipper.dart';
import '../learn/emotion_match_game.dart';
import '../learn/matching_pairs_game.dart';
import '../play/toy_registry.dart';
import '../sensorylab/experiences/aurora_paint.dart';
import '../sensorylab/experiences/fluid_flow.dart';
import '../sensorylab/experiences/magnet_play.dart';
import '../sensorylab/experiences/particle_galaxy.dart';
import '../sensorylab/experiences/sand_zen.dart';
import '../sensorylab/experiences/slime.dart';

/// A child-facing bucket. These are honest: `communication` and `lifeSkills`
/// have zero *toys* today — that is the real gap, surfaced deliberately.
enum ToyCategory { sensory, fidget, creative, calm, learning, communication, lifeSkills }

/// The ways a child can touch a toy — powers the audit report.
enum ToyInput { tap, drag, hold, twist, tilt, multiTouch, sound }

/// Rough time a child can stay engaged before it "ends".
/// [endless] = open-ended, never fails; [deep] ≈ 5–10 min; [quick] ≈ 1–3 min.
enum ToyEngagement { endless, deep, quick }

/// How the toy is opened.
/// [widget] = a raw interactive widget shown inside the immersive player;
/// [screen] = a self-contained full screen we push directly.
enum ToyLaunch { widget, screen }

/// One entry in the unified Toy Universe — a single source of truth that spans
/// the Antistress, Play, Sensory Lab and Learn features so every toy can be
/// surfaced, previewed and audited in one place.
@immutable
class UniverseToy {
  const UniverseToy({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.category,
    required this.inputs,
    required this.engagement,
    required this.build,
    this.launch = ToyLaunch.widget,
    this.working = true,
    this.isNew = false,
  });

  final String id;
  final String name;
  final String emoji;
  final Color color;
  final ToyCategory category;
  final List<ToyInput> inputs;
  final ToyEngagement engagement;
  final ToyLaunch launch;
  final bool working;
  final bool isNew;

  /// Builds the live toy widget — used both for the immersive player and for
  /// the long-press live preview.
  final Widget Function() build;
}

extension ToyCategoryLabel on ToyCategory {
  String get label {
    switch (this) {
      case ToyCategory.sensory:
        return 'Sensory';
      case ToyCategory.fidget:
        return 'Fidget';
      case ToyCategory.creative:
        return 'Creative';
      case ToyCategory.calm:
        return 'Calm';
      case ToyCategory.learning:
        return 'Learning';
      case ToyCategory.communication:
        return 'Communication';
      case ToyCategory.lifeSkills:
        return 'Life Skills';
    }
  }

  String get emoji {
    switch (this) {
      case ToyCategory.sensory:
        return '🌈';
      case ToyCategory.fidget:
        return '🌀';
      case ToyCategory.creative:
        return '🎨';
      case ToyCategory.calm:
        return '☁️';
      case ToyCategory.learning:
        return '🧠';
      case ToyCategory.communication:
        return '💬';
      case ToyCategory.lifeSkills:
        return '🪥';
    }
  }
}

extension ToyInputLabel on ToyInput {
  String get label {
    switch (this) {
      case ToyInput.tap:
        return 'tap';
      case ToyInput.drag:
        return 'drag';
      case ToyInput.hold:
        return 'hold';
      case ToyInput.twist:
        return 'twist';
      case ToyInput.tilt:
        return 'tilt';
      case ToyInput.multiTouch:
        return 'multi-touch';
      case ToyInput.sound:
        return 'sound';
    }
  }
}

extension ToyEngagementLabel on ToyEngagement {
  String get label {
    switch (this) {
      case ToyEngagement.endless:
        return 'Endless';
      case ToyEngagement.deep:
        return '5–10 min';
      case ToyEngagement.quick:
        return '1–3 min';
    }
  }
}

// Convenience shorthands to keep the catalogue readable.
Widget Function() _play(String id) => () => buildToy(id);

/// The full, flat catalogue of every playable toy in HARSHIVOS.
/// One list. No hunting through menus. This is the toy box.
final List<UniverseToy> kToyUniverse = <UniverseToy>[
  // ---- Antistress: fidget & mechanical (21) ----
  const UniverseToy(
    id: 'as_pop_it', name: 'Pop It', emoji: '🫧', color: Color(0xFFEF476F),
    category: ToyCategory.fidget, inputs: [ToyInput.tap, ToyInput.drag],
    engagement: ToyEngagement.endless, build: PopItToy.new,
  ),
  const UniverseToy(
    id: 'as_bubble_wrap', name: 'Bubble Wrap', emoji: '🎈', color: Color(0xFF06D6A0),
    category: ToyCategory.fidget, inputs: [ToyInput.tap, ToyInput.drag],
    engagement: ToyEngagement.endless, build: BubbleWrapToy.new,
  ),
  const UniverseToy(
    id: 'as_stress_ball', name: 'Stress Ball', emoji: '🔴', color: Color(0xFFFF6B6B),
    category: ToyCategory.fidget, inputs: [ToyInput.hold, ToyInput.drag],
    engagement: ToyEngagement.endless, build: StressBallToy.new,
  ),
  const UniverseToy(
    id: 'as_spinner', name: 'Fidget Spinner', emoji: '🌀', color: Color(0xFF118AB2),
    category: ToyCategory.fidget, inputs: [ToyInput.drag],
    engagement: ToyEngagement.endless, build: FidgetSpinnerToy.new,
  ),
  const UniverseToy(
    id: 'as_spin_wheel', name: 'Spin Wheel', emoji: '🎡', color: Color(0xFFFFD166),
    category: ToyCategory.fidget, inputs: [ToyInput.drag],
    engagement: ToyEngagement.endless, build: SpinWheelToy.new,
  ),
  const UniverseToy(
    id: 'as_gears', name: 'Gears', emoji: '⚙️', color: Color(0xFF8D99AE),
    category: ToyCategory.fidget, inputs: [ToyInput.drag, ToyInput.twist],
    engagement: ToyEngagement.endless, build: GearsToy.new,
  ),
  const UniverseToy(
    id: 'as_switch_board', name: 'Switch Board', emoji: '🔌', color: Color(0xFF06D6A0),
    category: ToyCategory.fidget, inputs: [ToyInput.tap],
    engagement: ToyEngagement.endless, build: SwitchBoardToy.new,
  ),
  const UniverseToy(
    id: 'as_keypad', name: 'Keypad', emoji: '🔢', color: Color(0xFF4CC9F0),
    category: ToyCategory.fidget, inputs: [ToyInput.tap, ToyInput.sound],
    engagement: ToyEngagement.deep, build: KeypadToy.new,
  ),
  const UniverseToy(
    id: 'as_click_pen', name: 'Click Pen', emoji: '🖊️', color: Color(0xFFFFD166),
    category: ToyCategory.fidget, inputs: [ToyInput.tap, ToyInput.sound],
    engagement: ToyEngagement.endless, build: ClickPenToy.new,
  ),
  const UniverseToy(
    id: 'as_latch_bolt', name: 'Latch & Bolt', emoji: '🔩', color: Color(0xFF8D99AE),
    category: ToyCategory.fidget, inputs: [ToyInput.drag],
    engagement: ToyEngagement.deep, build: LatchBoltToy.new,
  ),
  const UniverseToy(
    id: 'as_zipper', name: 'Zipper', emoji: '🤐', color: Color(0xFFEF476F),
    category: ToyCategory.fidget, inputs: [ToyInput.drag],
    engagement: ToyEngagement.endless, build: ZipperToy.new,
  ),
  const UniverseToy(
    id: 'as_combo_lock', name: 'Combo Lock', emoji: '🔒', color: Color(0xFF118AB2),
    category: ToyCategory.fidget, inputs: [ToyInput.twist, ToyInput.drag],
    engagement: ToyEngagement.deep, build: ComboLockToy.new,
  ),
  const UniverseToy(
    id: 'as_newtons_cradle', name: "Newton's Cradle", emoji: '⚪', color: Color(0xFFCED4DA),
    category: ToyCategory.fidget, inputs: [ToyInput.drag],
    engagement: ToyEngagement.endless, build: NewtonsCradleToy.new,
  ),
  const UniverseToy(
    id: 'as_slinky', name: 'Slinky', emoji: '🌈', color: Color(0xFF9B5DE5),
    category: ToyCategory.fidget, inputs: [ToyInput.drag],
    engagement: ToyEngagement.endless, build: SlinkyToy.new,
  ),
  const UniverseToy(
    id: 'as_pendulum', name: 'Pendulum Waves', emoji: '〰️', color: Color(0xFF00BBF9),
    category: ToyCategory.sensory, inputs: [ToyInput.tap],
    engagement: ToyEngagement.endless, build: PendulumWavesToy.new,
  ),
  const UniverseToy(
    id: 'as_lava_blobs', name: 'Lava Blobs', emoji: '🫠', color: Color(0xFFF15BB5),
    category: ToyCategory.sensory, inputs: [ToyInput.drag, ToyInput.tilt],
    engagement: ToyEngagement.endless, build: LavaBlobsToy.new,
  ),
  const UniverseToy(
    id: 'as_water_drop', name: 'Water Drops', emoji: '💧', color: Color(0xFF00BBF9),
    category: ToyCategory.sensory, inputs: [ToyInput.tap],
    engagement: ToyEngagement.endless, build: WaterDropToy.new,
  ),
  const UniverseToy(
    id: 'as_dimmer', name: 'Dimmer Knob', emoji: '💡', color: Color(0xFFFFD166),
    category: ToyCategory.fidget, inputs: [ToyInput.twist, ToyInput.drag],
    engagement: ToyEngagement.deep, build: DimmerKnobToy.new,
  ),
  const UniverseToy(
    id: 'as_sand_fall', name: 'Falling Sand', emoji: '🏜️', color: Color(0xFFFFB703),
    category: ToyCategory.sensory, inputs: [ToyInput.drag],
    engagement: ToyEngagement.endless, build: SandFallToy.new,
  ),
  const UniverseToy(
    id: 'as_kinetic_dots', name: 'Kinetic Dots', emoji: '✨', color: Color(0xFF9B5DE5),
    category: ToyCategory.sensory, inputs: [ToyInput.drag, ToyInput.multiTouch],
    engagement: ToyEngagement.endless, build: KineticDotsToy.new,
  ),
  const UniverseToy(
    id: 'as_rotary_dial', name: 'Rotary Dial', emoji: '☎️', color: Color(0xFF06D6A0),
    category: ToyCategory.fidget, inputs: [ToyInput.twist, ToyInput.sound],
    engagement: ToyEngagement.deep, build: RotaryDialToy.new,
  ),

  // ---- Play hub: sensory & creative (19) ----
  UniverseToy(
    id: 'bubble_pop', name: 'Bubble Pop World', emoji: '🫧', color: const Color(0xFF43E97B),
    category: ToyCategory.sensory, inputs: const [ToyInput.tap, ToyInput.sound],
    engagement: ToyEngagement.endless, build: _play('bubble_pop'),
  ),
  UniverseToy(
    id: 'particle_galaxy', name: 'Particle Galaxy', emoji: '🌌', color: const Color(0xFF6C3CE0),
    category: ToyCategory.sensory, inputs: const [ToyInput.drag, ToyInput.multiTouch],
    engagement: ToyEngagement.endless, build: _play('particle_galaxy'),
  ),
  UniverseToy(
    id: 'water_ripples', name: 'Water Ripples', emoji: '💧', color: const Color(0xFF36D1DC),
    category: ToyCategory.sensory, inputs: const [ToyInput.tap, ToyInput.drag],
    engagement: ToyEngagement.endless, build: _play('water_ripples'),
  ),
  UniverseToy(
    id: 'fireworks', name: 'Fireworks Touch', emoji: '🎆', color: const Color(0xFFFA709A),
    category: ToyCategory.sensory, inputs: const [ToyInput.tap, ToyInput.sound],
    engagement: ToyEngagement.endless, build: _play('fireworks'), isNew: true,
  ),
  UniverseToy(
    id: 'paint_light', name: 'Paint With Light', emoji: '✨', color: const Color(0xFFA18CD1),
    category: ToyCategory.creative, inputs: const [ToyInput.drag, ToyInput.multiTouch],
    engagement: ToyEngagement.endless, build: _play('paint_light'),
  ),
  UniverseToy(
    id: 'sand_garden', name: 'Sand Garden', emoji: '🏜️', color: const Color(0xFFE6B980),
    category: ToyCategory.sensory, inputs: const [ToyInput.drag],
    engagement: ToyEngagement.endless, build: _play('sand_garden'),
  ),
  UniverseToy(
    id: 'magnetic_balls', name: 'Magnetic Balls', emoji: '🧲', color: const Color(0xFF4FACFE),
    category: ToyCategory.sensory, inputs: const [ToyInput.drag, ToyInput.multiTouch],
    engagement: ToyEngagement.endless, build: _play('magnetic_balls'),
  ),
  UniverseToy(
    id: 'fluid_sim', name: 'Fluid Simulator', emoji: '🌊', color: const Color(0xFF21D4FD),
    category: ToyCategory.sensory, inputs: const [ToyInput.drag, ToyInput.multiTouch],
    engagement: ToyEngagement.endless, build: _play('fluid_sim'),
  ),
  UniverseToy(
    id: 'lava_lamp', name: 'Sensory Lava Lamp', emoji: '🔮', color: const Color(0xFFFF6B6B),
    category: ToyCategory.calm, inputs: const [ToyInput.tap],
    engagement: ToyEngagement.endless, build: _play('lava_lamp'),
  ),
  UniverseToy(
    id: 'kaleidoscope', name: 'Kaleidoscope Mirror', emoji: '🔷', color: const Color(0xFFF857A6),
    category: ToyCategory.sensory, inputs: const [ToyInput.drag, ToyInput.multiTouch],
    engagement: ToyEngagement.endless, build: _play('kaleidoscope'),
  ),
  UniverseToy(
    id: 'music_garden', name: 'Music Garden', emoji: '🌸', color: const Color(0xFFFBC2EB),
    category: ToyCategory.creative, inputs: const [ToyInput.tap, ToyInput.sound],
    engagement: ToyEngagement.deep, build: _play('music_garden'),
  ),
  UniverseToy(
    id: 'fidget_cube', name: 'Fidget Cube', emoji: '🎲', color: const Color(0xFF30CFD0),
    category: ToyCategory.fidget, inputs: const [ToyInput.tap, ToyInput.twist],
    engagement: ToyEngagement.endless, build: _play('fidget_cube'),
  ),
  UniverseToy(
    id: 'calm_clouds', name: 'Calm Clouds', emoji: '☁️', color: const Color(0xFF89F7FE),
    category: ToyCategory.calm, inputs: const [ToyInput.drag],
    engagement: ToyEngagement.endless, build: _play('calm_clouds'),
  ),
  UniverseToy(
    id: 'rainbow_rain', name: 'Rainbow Rain', emoji: '🌈', color: const Color(0xFF43CEA2),
    category: ToyCategory.calm, inputs: const [ToyInput.tap, ToyInput.sound],
    engagement: ToyEngagement.endless, build: _play('rainbow_rain'),
  ),
  UniverseToy(
    id: 'slime', name: 'Slime Stretch', emoji: '🟢', color: const Color(0xFF96E6A1),
    category: ToyCategory.sensory, inputs: const [ToyInput.drag, ToyInput.hold],
    engagement: ToyEngagement.endless, build: _play('slime'),
  ),
  UniverseToy(
    id: 'color_mix', name: 'Color Mixing Lab', emoji: '🎨', color: const Color(0xFFFAD961),
    category: ToyCategory.creative, inputs: const [ToyInput.tap, ToyInput.drag],
    engagement: ToyEngagement.deep, build: _play('color_mix'),
  ),
  UniverseToy(
    id: 'car_track', name: 'Car Track Builder', emoji: '🏎️', color: const Color(0xFFFF512F),
    category: ToyCategory.creative, inputs: const [ToyInput.tap, ToyInput.drag],
    engagement: ToyEngagement.deep, build: _play('car_track'), isNew: true,
  ),
  UniverseToy(
    id: 'spin_universe', name: 'Spin Universe', emoji: '🪐', color: const Color(0xFF6F0000),
    category: ToyCategory.sensory, inputs: const [ToyInput.drag],
    engagement: ToyEngagement.endless, build: _play('spin_universe'),
  ),
  UniverseToy(
    id: 'marble_run', name: 'Infinite Marble Run', emoji: '🔵', color: const Color(0xFF2193B0),
    category: ToyCategory.creative, inputs: const [ToyInput.tap, ToyInput.drag],
    engagement: ToyEngagement.deep, build: _play('marble_run'),
  ),

  // ---- Sensory Lab: premium physics experiences (6) ----
  const UniverseToy(
    id: 'lab_fluid_flow', name: 'Liquid Light', emoji: '💧', color: Color(0xFF4CC9F0),
    category: ToyCategory.sensory, inputs: [ToyInput.drag, ToyInput.multiTouch],
    engagement: ToyEngagement.endless, build: FluidFlowExperience.new, isNew: true,
  ),
  const UniverseToy(
    id: 'lab_galaxy', name: 'Galaxy', emoji: '🌌', color: Color(0xFF9B5DE5),
    category: ToyCategory.sensory, inputs: [ToyInput.drag, ToyInput.multiTouch],
    engagement: ToyEngagement.endless, build: ParticleGalaxyExperience.new, isNew: true,
  ),
  const UniverseToy(
    id: 'lab_slime', name: 'Lab Slime', emoji: '🫠', color: Color(0xFF06D6A0),
    category: ToyCategory.sensory, inputs: [ToyInput.drag, ToyInput.hold],
    engagement: ToyEngagement.endless, build: SlimeExperience.new, isNew: true,
  ),
  const UniverseToy(
    id: 'lab_aurora', name: 'Aurora', emoji: '🌈', color: Color(0xFF36E0C0),
    category: ToyCategory.creative, inputs: [ToyInput.drag],
    engagement: ToyEngagement.endless, build: AuroraPaintExperience.new, isNew: true,
  ),
  const UniverseToy(
    id: 'lab_sand_zen', name: 'Zen Sand', emoji: '🏝️', color: Color(0xFFFFB703),
    category: ToyCategory.calm, inputs: [ToyInput.drag],
    engagement: ToyEngagement.endless, build: SandZenExperience.new, isNew: true,
  ),
  const UniverseToy(
    id: 'lab_magnets', name: 'Magnets', emoji: '🧲', color: Color(0xFFEF476F),
    category: ToyCategory.sensory, inputs: [ToyInput.drag],
    engagement: ToyEngagement.endless, build: MagnetPlayExperience.new, isNew: true,
  ),

  // ---- Learn: guided games (2, self-contained screens) ----
  UniverseToy(
    id: 'learn_emotion_match', name: 'Emotion Match', emoji: '🎭', color: const Color(0xFFA18CD1),
    category: ToyCategory.learning, inputs: const [ToyInput.tap],
    engagement: ToyEngagement.quick, launch: ToyLaunch.screen,
    build: () => const EmotionMatchGame(),
  ),
  UniverseToy(
    id: 'learn_matching_pairs', name: 'Matching Pairs', emoji: '🃏', color: const Color(0xFF43E97B),
    category: ToyCategory.learning, inputs: const [ToyInput.tap],
    engagement: ToyEngagement.quick, launch: ToyLaunch.screen,
    build: () => const MatchingPairsGame(),
  ),
];

/// Toy id → toy, for O(1) lookups from favorites/recents.
final Map<String, UniverseToy> kToyUniverseById = <String, UniverseToy>{
  for (final t in kToyUniverse) t.id: t,
};

/// Live count of working toys per category (drives the header chips). Categories
/// with zero toys are intentionally omitted here but surfaced as gaps elsewhere.
Map<ToyCategory, int> toyCountsByCategory() {
  final counts = <ToyCategory, int>{};
  for (final t in kToyUniverse) {
    if (!t.working) continue;
    counts[t.category] = (counts[t.category] ?? 0) + 1;
  }
  return counts;
}

/// Categories that exist in the product vocabulary but have **no toys yet** —
/// the honest gaps to fill next.
List<ToyCategory> emptyToyCategories() {
  final present = kToyUniverse.map((t) => t.category).toSet();
  return ToyCategory.values.where((c) => !present.contains(c)).toList();
}
