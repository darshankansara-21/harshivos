import 'package:flutter/material.dart';

import 'toys/toys_draw.dart';
import 'toys/toys_fidget.dart';
import 'toys/toys_interactive.dart';
import 'toys/toys_light.dart';
import 'toys/toys_more.dart';
import 'toys/toys_particles.dart';
import 'toys/toys_water.dart';
import 'toys/toys_weather.dart';
import 'toys/snack_studio.dart';
import 'toys/mini_games.dart';
import 'toys/arcade_games.dart';

/// Maps a toy id to its playable widget. Toys absent from this map are
/// scaffolded "coming soon" entries in the catalogue.
typedef ToyBuilder = Widget Function();

const Map<String, ToyBuilder> toyBuilders = <String, ToyBuilder>{
  'bubble_pop': BubblePopToy.new,
  'particle_galaxy': ParticleGalaxyToy.new,
  'water_ripples': WaterRipplesToy.new,
  'fireworks': FireworksToy.new,
  'paint_light': PaintWithLightToy.new,
  'sand_garden': SandGardenToy.new,
  'magnetic_balls': MagneticBallsToy.new,
  'fluid_sim': FluidSimulatorToy.new,
  'lava_lamp': LavaLampToy.new,
  'kaleidoscope': KaleidoscopeToy.new,
  'music_garden': MusicGardenToy.new,
  'fidget_cube': FidgetCubeToy.new,
  'calm_clouds': CalmCloudsToy.new,
  'rainbow_rain': RainbowRainToy.new,
  'slime': SlimeStretchToy.new,
  'color_mix': ColorMixingLabToy.new,
  'car_track': CarTrackBuilderToy.new,
  'spin_universe': SpinUniverseToy.new,
  'marble_run': InfiniteMarbleRunToy.new,
  'snack_studio': SnackStudioToy.new,
  'fruit_catch': FruitCatchGame.new,
  'balloon_pop': BalloonPopGame.new,
  'star_tap': StarTapGame.new,
  'snake': SnakeGame.new,
  'racing': RacingGame.new,
  'bowling': BowlingGame.new,
  'whack': WhackGame.new,
  'sky_hop': SkyHopGame.new,
  'stack': StackGame.new,
  'merge': MergeGame.new,
  'echo': EchoGame.new,
  'tictactoe': TicTacToeGame.new,
  'brick_break': BrickBreakGame.new,
  'space_dodge': SpaceDodgeGame.new,
  'memory_flip': MemoryFlipGame.new,
  'ball_sort': BallSortGame.new,
  'tap_order': TapOrderGame.new,
  'piano_tiles': PianoTilesGame.new,
  'block_blast': BlockBlastGame.new,
  'bubble_shooter': BubbleShooterGame.new,
};

bool toyIsPlayable(String id) => toyBuilders.containsKey(id);

Widget buildToy(String id) => (toyBuilders[id] ?? _missingToy)();

Widget _missingToy() => const SizedBox.shrink();
