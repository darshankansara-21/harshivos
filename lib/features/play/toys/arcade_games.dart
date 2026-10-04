import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/game_music_host.dart';
import '../../../services/audio/tone_player.dart';
import '../../companion/companion.dart';
import 'mini_games.dart' show GameScores, GameStatus;

part 'arcade/whack_game.dart';
part 'arcade/sky_hop_game.dart';
part 'arcade/stack_game.dart';
part 'arcade/merge_game.dart';
part 'arcade/echo_game.dart';
part 'arcade/tic_tac_toe_game.dart';
part 'arcade/brick_break_game.dart';
part 'arcade/space_dodge_game.dart';
part 'arcade/memory_flip_game.dart';
part 'arcade/ball_sort_game.dart';
part 'arcade/tap_order_game.dart';
part 'arcade/piano_tiles_game.dart';
part 'arcade/block_blast_game.dart';
part 'arcade/bubble_shooter_game.dart';
part 'arcade/quick_tap_game.dart';
part 'arcade/pinball_game.dart';
part 'arcade/basketball_game.dart';
part 'arcade/mini_golf_game.dart';
part 'arcade/air_hockey_game.dart';
part 'arcade/target_toss_game.dart';
part 'arcade/bubble_wrap_game.dart';
part 'arcade/drum_garden_game.dart';
part 'arcade/color_mixer_game.dart';
part 'arcade/fishing_game.dart';
part 'arcade/maze_run_game.dart';
part 'arcade/beat_builder_game.dart';
part 'arcade/catch_beat_game.dart';
part 'arcade/firefly_count_game.dart';
part 'arcade/sorting_train_game.dart';
part 'arcade/shadow_match_game.dart';
part 'arcade/pattern_weaver_game.dart';
part 'arcade/balloon_math_game.dart';
part 'arcade/dot_to_dot_game.dart';
part 'arcade/rhythm_clap_game.dart';
part 'arcade/shape_builder_game.dart';
part 'arcade/memory_pairs_deluxe_game.dart';
part 'arcade/bug_catch_game.dart';
part 'arcade/spot_difference_game.dart';
part 'arcade/weather_sort_game.dart';
part 'arcade/maze_marble_game.dart';
part 'arcade/piano_song_game.dart';
part 'arcade/letter_trace_game.dart';
part 'arcade/soccer_kick_game.dart';
part 'arcade/xylophone_tap_game.dart';
part 'arcade/jigsaw_four_game.dart';
part 'arcade/counting_baskets_game.dart';
part 'arcade/star_path_game.dart';
part 'arcade/feelings_match_game.dart';
part 'arcade/penalty_dash_game.dart';
part 'arcade/shape_sort_chute_game.dart';
part 'arcade/balloon_bounce_game.dart';
part 'arcade/count_pop_game.dart';
part 'arcade/mirror_draw_game.dart';
part 'arcade/calm_breaths_game.dart';
part 'arcade/hoop_toss_game.dart';
part 'arcade/echo_drums_game.dart';
part 'arcade/slide_puzzle_game.dart';


/// Shared chrome for the arcade games — score + best pill, optional target, a
/// transient combo banner, and win / game-over overlays with instant replay.
/// Mirrors the Play game shell so every game feels part of one world.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.title,
    required this.score,
    required this.onPlayAgain,
    required this.child,
    this.best = 0,
    this.target,
    this.status = GameStatus.playing,
    this.banner,
    this.overEmoji = '💪',
    this.overText = 'Good try!',
    this.accent = const Color(0xFFFFD166),
    this.rankByScore = true,
    this.introHow,
    this.onStart,
  });

  final String title;
  final int score;
  final int best;
  final int? target;
  final GameStatus status;
  final String? banner;
  final String overEmoji;
  final String overText;
  final VoidCallback onPlayAgain;
  final Widget child;
  final Color accent;
  final bool rankByScore;
  final String? introHow;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final scoreText = target != null ? '$score / $target' : '$score';
    return GameMusicHost(
      playing: status == GameStatus.playing,
      bed: WonderMusicBed.arcade,
      child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 72),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      best > 0
                          ? '$title   $scoreText   ★ $best'
                          : '$title   $scoreText',
                      style: TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (banner != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(banner!,
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (status == GameStatus.won || status == GameStatus.over)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(status == GameStatus.won ? '🎉' : overEmoji,
                        style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: 8),
                    Text(status == GameStatus.won ? 'You did it!' : overText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(best > 0 ? 'Score $score   ·   Best $best' : 'Score $score',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    if (rankByScore && score > 0 && score >= best) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD166),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('🏆 New best!',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onPlayAgain,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Play again'),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) => TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.grid_view_rounded,
                            color: Colors.white70, size: 20),
                        label: const Text('Back to games',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (status == GameStatus.ready && onStart != null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withOpacity(0.55),
                    accent.withOpacity(0.28),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(overEmoji, style: const TextStyle(fontSize: 76)),
                    const SizedBox(height: 6),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900)),
                    if (introHow != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(introHow!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.35)),
                      ),
                    ],
                    if (best > 0) ...<Widget>[
                      const SizedBox(height: 12),
                      Text('Best  ★ $best',
                          style: TextStyle(
                              color: accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () {
                        TonePlayer.instance.playCue(SoundCue.gameStart);
                        onStart!();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 14),
                        textStyle: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text('Play'),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) => TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back to games',
                            style: TextStyle(color: Colors.white60)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
    );
  }
}

/// Lets a game emit companion events from anywhere and flush them after frame.
mixin _Emit<T extends StatefulWidget> on State<T> {
  final List<ExperienceEvent> _pending = <ExperienceEvent>[];
  void emit(ExperienceEvent e) => _pending.add(e);
  void drain(BuildContext context) {
    if (_pending.isEmpty) return;
    final events = List<ExperienceEvent>.from(_pending);
    _pending.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final e in events) {
        CompanionEventNotification(e).dispatch(context);
      }
    });
  }
}

// ===========================================================================
// Whack — moles pop from holes; tap them before they duck back. Endless, and
// the moles get quicker as your score climbs.
// ===========================================================================
