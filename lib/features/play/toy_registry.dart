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
import 'toys/goal_games.dart';
import 'toys/trace_game.dart';

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
  'color_quest': ColorQuestGame.new,
  'shape_scout': ShapeScoutGame.new,
  'number_splash': NumberSplashGame.new,
  'path_finder': PathFinderGame.new,
  'goal_keeper': GoalKeeperGame.new,
  'trace_it': TraceGame.new,
  'quick_tap': QuickTapGame.new,
  'pinball': PinballGame.new,
  'basketball': BasketballGame.new,
  'mini_golf': MiniGolfGame.new,
  'air_hockey': AirHockeyGame.new,
  'target_toss': TargetTossGame.new,
  'bubble_wrap': BubbleWrapGame.new,
  'drum_garden': DrumGardenGame.new,
  'color_mixer': ColorMixerGame.new,
  'fishing': FishingGame.new,
  'maze_run': MazeRunGame.new,
  'beat_builder': BeatBuilderGame.new,
  'catch_beat': CatchBeatGame.new,
  'firefly_count': FireflyCountGame.new,
  'sorting_train': SortingTrainGame.new,
  'shadow_match': ShadowMatchGame.new,
  'pattern_weaver': PatternWeaverGame.new,
  'balloon_math': BalloonMathGame.new,
  'dot_to_dot': DotToDotGame.new,
  'rhythm_clap': RhythmClapGame.new,
  'shape_builder': ShapeBuilderGame.new,
  'memory_deluxe': MemoryPairsDeluxeGame.new,
  'bug_catch': BugCatchGame.new,
  'spot_difference': SpotDifferenceGame.new,
  'weather_sort': WeatherSortGame.new,
  'maze_marble': MazeMarbleGame.new,
  'piano_song': PianoSongGame.new,
  'letter_trace': LetterTraceGame.new,
  'soccer_kick': SoccerKickGame.new,
  'xylophone_tap': XylophoneTapGame.new,
  'jigsaw_four': JigsawFourGame.new,
  'counting_baskets': CountingBasketsGame.new,
  'star_path': StarPathGame.new,
  'feelings_match': FeelingsMatchGame.new,
  'penalty_dash': PenaltyDashGame.new,
  'shape_sort_chute': ShapeSortChuteGame.new,
  'balloon_bounce': BalloonBounceGame.new,
  'count_pop': CountPopGame.new,
  'mirror_draw': MirrorDrawGame.new,
  'calm_breaths': CalmBreathsGame.new,
  'hoop_toss': HoopTossGame.new,
  'echo_drums': EchoDrumsGame.new,
  'slide_puzzle': SlidePuzzleGame.new,
  'add_it_up': AddItUpGame.new,
  'steady_hand': SteadyHandGame.new,
  'kindness_match': KindnessMatchGame.new,
  'skee_ball': SkeeBallGame.new,
  'tone_match': ToneMatchGame.new,
  'odd_one_out': OddOneOutGame.new,
  'bigger_number': BiggerNumberGame.new,
  'balance_ball': BalanceBallGame.new,
  'calm_choices': CalmChoicesGame.new,
};

bool toyIsPlayable(String id) => toyBuilders.containsKey(id);

Widget buildToy(String id) => (toyBuilders[id] ?? _missingToy)();

Widget _missingToy() => const SizedBox.shrink();
