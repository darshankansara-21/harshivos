import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/game_music_host.dart';
import '../../../services/audio/tone_player.dart';
import '../../companion/companion.dart';

/// Persistent per-game best scores. A tiny wrapper over SharedPreferences so
/// arcade games can show and beat a personal best without any Riverpod wiring.
class GameScores {
  GameScores._();
  static final GameScores instance = GameScores._();
  SharedPreferences? _prefs;

  Future<void> ensureLoaded() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  int best(String id) => _prefs?.getInt('best_$id') ?? 0;

  /// Records [score] if it beats the stored best; returns the resulting best.
  Future<int> submit(String id, int score) async {
    await ensureLoaded();
    if (score > best(id)) {
      await _prefs!.setInt('best_$id', score);
      return score;
    }
    return best(id);
  }
}

/// Lets a game emit companion events (collect / win / encourage) from anywhere
/// — including the physics tick — and flushes them to the host after the frame.
mixin _CompanionEmitter<T extends StatefulWidget> on State<T> {
  final List<ExperienceEvent> _pendingEvents = <ExperienceEvent>[];

  void emit(ExperienceEvent event) => _pendingEvents.add(event);

  void drainCompanion(BuildContext context) {
    if (_pendingEvents.isEmpty) return;
    final events = List<ExperienceEvent>.from(_pendingEvents);
    _pendingEvents.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final event in events) {
        CompanionEventNotification(event).dispatch(context);
      }
    });
  }
}

enum GameStatus { ready, playing, won, over }

/// Shared chrome for the goal-based mini games: a score + best pill, an
/// optional target, a transient combo banner, and win / game-over overlays
/// with an instant "Play again". Games fill the immersive toy canvas; the
/// companion sits in the corner (added by the host).
class _GameShell extends StatefulWidget {
  const _GameShell({
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
    this.winEmoji,
    this.winText,
    this.accent = const Color(0xFFFFD166),
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
  // Shown on an outright GameStatus.won instead of the generic '🎉'/'You did
  // it!' fallback — lets a game give its win screen its own distinct voice
  // instead of sharing one identical win message with every other game on
  // this shell. Null keeps the original generic text.
  final String? winEmoji;
  final String? winText;
  final VoidCallback onPlayAgain;
  final Widget child;
  final Color accent;

  /// One short line telling a child exactly what to do — shown on the start
  /// card so the objective is clear before the first tap.
  final String? introHow;

  /// Called when the child presses the big Start button on the intro card.
  final VoidCallback? onStart;

  @override
  State<_GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<_GameShell> {
  // See _ShellState's comment in arcade_games.dart: many games submit their
  // running score mid-run, which ratchets `best` up as soon as the score
  // first ties/beats the old record — well before the run ends. Freeze the
  // best as it stood when this run started so an exact tie with a
  // pre-existing record doesn't get falsely celebrated as a new best.
  late int _runStartBest = widget.best;

  @override
  void didUpdateWidget(covariant _GameShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != GameStatus.playing &&
        widget.status == GameStatus.playing) {
      _runStartBest = oldWidget.best;
    }
    // See _Shell's matching comment in arcade_games.dart: one discrete
    // haptic pulse when a run ends, not on every tap. Must gate on
    // hapticsEnabled itself since it bypasses TonePlayer.playCue.
    if (oldWidget.status == GameStatus.playing &&
        widget.status != GameStatus.playing &&
        TonePlayer.instance.hapticsEnabled) {
      if (widget.status == GameStatus.won) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final score = widget.score;
    final best = widget.best;
    final target = widget.target;
    final status = widget.status;
    final banner = widget.banner;
    final overEmoji = widget.overEmoji;
    final overText = widget.overText;
    final winEmoji = widget.winEmoji;
    final winText = widget.winText;
    final onPlayAgain = widget.onPlayAgain;
    final child = widget.child;
    final accent = widget.accent;
    final introHow = widget.introHow;
    final onStart = widget.onStart;
    final scoreText = target != null ? '$score / $target' : '$score';
    // See _Shell's matching comment in arcade_games.dart: marking the score
    // pill a live region lets TalkBack/VoiceOver re-announce it as the score
    // changes mid-run, which was previously silent to assistive tech.
    return GameMusicHost(
      playing: status == GameStatus.playing,
      bed: WonderMusicBed.playful,
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
                    Semantics(
                      container: true,
                      liveRegion: true,
                      child: Container(
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
                    ),
                    if (banner != null) ...<Widget>[
                      const SizedBox(height: 6),
                      // See _Shell's matching comment in arcade_games.dart:
                      // this pill is also reused for live status (lives,
                      // round progress, "out of lives!") via setState, which
                      // was previously silent to assistive tech on change.
                      Semantics(
                        container: true,
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            banner,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
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
                      // See _Shell's matching comment in arcade_games.dart:
                      // a one-shot merged announcement so a screen-reader
                      // user learns the win/lose screen appeared without
                      // having to manually swipe around to find it.
                      Semantics(
                        liveRegion: true,
                        label: status == GameStatus.won
                            ? '${winText ?? 'You did it!'} Score $score.'
                                '${best > 0 ? ' Best $best.' : ''}'
                                '${score > 0 && score > _runStartBest ? ' New best!' : ''}'
                            : '$overText Score $score.'
                                '${best > 0 ? ' Best $best.' : ''}',
                        child: const SizedBox.shrink(),
                      ),
                      Text(status == GameStatus.won ? (winEmoji ?? '🎉') : overEmoji,
                          style: const TextStyle(fontSize: 72)),
                      const SizedBox(height: 8),
                      Text(
                        status == GameStatus.won
                            ? (winText ?? 'You did it!')
                            : overText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        best > 0
                            ? 'Score $score   ·   Best $best'
                            : 'Score $score',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      if (score > 0 && score > _runStartBest) ...<Widget>[
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
                      // The start card's icon is the game's OWN emoji (every
                      // title is authored as 'emoji Name'), not `overEmoji` —
                      // that param is the lose/encourage screen's icon, a
                      // mismatch for a start-screen first impression. Mirrors
                      // `_GoalShell`'s existing correct pattern.
                      Text(title.split(' ').first,
                          style: const TextStyle(fontSize: 76)),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (introHow != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            introHow,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
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
                          onStart();
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

class FruitCatchGame extends StatefulWidget {
  const FruitCatchGame({super.key});
  @override
  State<FruitCatchGame> createState() => _FruitCatchGameState();
}

class _Faller {
  _Faller(this.x, this.y, this.vy, this.emoji, this.kind);
  double x;
  double y;
  double vy;
  final String emoji;
  final int kind; // 0 = fruit, 1 = golden bonus, 2 = bomb to avoid
}

class _FruitCatchGameState extends State<FruitCatchGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'fruit_catch';
  static const List<String> _fruits = <String>[
    '🍓',
    '🍎',
    '🍌',
    '🍇',
    '🍊',
    '🍑'
  ];
  static const int _target = 18;
  // This game never passed a `winText:` to the shell, so every single win
  // showed the shell's generic "You did it!" fallback, forever — the same
  // win-screen praise-variety gap already fixed catalog-wide elsewhere this
  // sprint, just missed here since there was no literal `winText:` to grep.
  static const List<String> _winPraisePool = <String>[
    'Fruit-catching champion!',
    'Basket master!',
    'Perfect harvest!',
    'Sweet catch!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  // The missed-fruit and bomb-catch flashes fired the exact same literal
  // every time, up to a dozen times per playthrough — the same flat-
  // repeated-banner gap batch 250 fixed catalog-wide across arcade/*.dart,
  // just missed here since mini_games.dart wasn't in that sweep's grep set.
  static const List<String> _missPool = <String>[
    'Missed it! Combo reset', 'So close! Combo reset',
    'Oops, slipped by! Combo reset', 'Almost! Combo reset',
  ];
  static const List<String> _bombPool = <String>[
    'Oops! -2 — dodge bombs', 'Ouch! -2 — dodge bombs',
    'Watch out! -2 — dodge bombs', 'Careful! -2 — dodge bombs',
  ];
  static const List<String> _bonusPool = <String>[
    'Bonus +3!', 'Sweet bonus +3!', 'Nice find! +3', 'Juicy! +3',
  ];
  final List<_Faller> _items = <_Faller>[];
  final List<_Particle> _splash = <_Particle>[];
  double _basketX = 0.5;
  double _spawnIn = 0.6;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // See BowlingGame's identical field for why: Sensory Settings' "Reduce
  // motion" toggle never reached hand-rolled particle bursts like this
  // game's catch splash.
  bool _reduceMotion = false;
  // Beating your own all-time best used to only ever surface quietly at the
  // very end, as a passive "★ N" number in the header that ticks up mid-run
  // with no fanfare — the single most replay-motivating moment (genuinely
  // doing better than you ever have) was silent. Fire one unmissable
  // celebration the instant this run's score first overtakes the prior
  // record, same spirit as merge_game's milestone banner but for the
  // session-best stat every game already tracks. Guarded so a brand-new
  // player's very first catch (where `_best` is still 0) isn't falsely
  // celebrated, and so it only fires once per run.
  bool _beatBest = false;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _spawn() {
    final r = _rnd.nextDouble();
    final kind = r < 0.12 ? 2 : (r < 0.24 ? 1 : 0);
    final emoji = kind == 2
        ? '💣'
        : kind == 1
            ? '🌟'
            : _fruits[_rnd.nextInt(_fruits.length)];
    // Fall speed escalates with score so the last stretch before the win
    // target genuinely feels harder than the opening catches, not a flat
    // plateau that never reaches a meaningfully faster end-state.
    final speed = 0.28 +
        _rnd.nextDouble() * 0.16 +
        math.min(0.26, _score * 0.0145) +
        (kind == 1 ? 0.12 : 0);
    _items.add(
        _Faller(0.08 + _rnd.nextDouble() * 0.84, -0.05, speed, emoji, kind));
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = _splash.length - 1; i >= 0; i--) {
      final p = _splash[i];
      p.pos += p.vel * dt;
      p.vel = Offset(p.vel.dx * 0.9, p.vel.dy * 0.9 + 0.8 * dt);
      p.life -= dt;
      if (p.life <= 0) _splash.removeAt(i);
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn =
          math.max(0.32, 0.7 - _score * 0.021) * (0.7 + _rnd.nextDouble() * 0.6);
      _spawn();
    }
    for (final f in _items) {
      f.y += f.vy * dt;
    }
    _items.removeWhere((f) {
      if (f.y >= 0.82 && f.y <= 0.97 && (f.x - _basketX).abs() < 0.13) {
        _onCatch(f);
        return true;
      }
      if (f.y > 1.05) {
        // A fruit falling past the basket is the same "unexplained setback"
        // gap class as balloon_pop's floated-away balloons: the bomb-catch
        // path already flashes 'Oops! Dodge bombs', so a silently reset
        // combo here would cost a child a streak for a reason they never
        // saw happen.
        if (f.kind != 2 && _combo > 0) {
          _flash(_missPool[_rnd.nextInt(_missPool.length)]);
          // The banner above is a purely visual setback cue — a blind or
          // low-vision child relying on audio got zero feedback that their
          // streak just broke, unlike the bomb-catch path a few lines down
          // which already pairs its 'Oops!' flash with a sound. Mirror that
          // convention here with the same gentle-retry cue used catalog-wide
          // for every other miss (bigger_number, weather_sort, hoop_toss,
          // etc.) so the setback is audible, not just readable. The
          // companion itself still got nothing though: unlike this same
          // miss in _ChoiceGoalGame/_PathFinderGameState (which both pair
          // their non-terminal misses with emit(incorrectAnswer) so Hari/
          // Pico can react), this path only ever emitted on the final
          // game-over, leaving every mid-game combo break uncommented on.
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
          emit(ExperienceEvent.incorrectAnswer);
        }
        if (f.kind != 2) _combo = 0;
        return true;
      }
      return false;
    });
  }

  void _onCatch(_Faller f) {
    if (f.kind == 2) {
      // A caught bomb must cost something, or "dodge the bombs" is an empty
      // instruction — previously it only reset the combo, the exact same
      // cost as simply letting a fruit fall past, so there was zero real
      // incentive to actually dodge rather than scoop up everything. A
      // small (non-punishing, clamped-at-zero) score deduction gives the
      // bomb genuine stakes without ever setting progress back below zero.
      _combo = 0;
      _score = math.max(0, _score - 2);
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      // Same companion-silence gap as the missed-fruit path above: a real
      // scoring penalty deserves the same emit(incorrectAnswer) the
      // catalog's non-terminal wrong-answer games already pair with it.
      emit(ExperienceEvent.incorrectAnswer);
      _flash(_bombPool[_rnd.nextInt(_bombPool.length)]);
      return;
    }
    _combo++;
    final gain = (f.kind == 1 ? 3 : 1) + (_combo >= 3 ? 1 : 0);
    _score += gain;
    _splashAt(
        f.x,
        f.y,
        f.kind == 1 ? const Color(0xFFFFD166) : const Color(0xFF43E97B),
        f.kind == 1 ? 14 : 9);
    TonePlayer.instance.playCue(SoundCue.fruit);
    emit(ExperienceEvent.bubblePopped);
    if (f.kind == 1) {
      _flash(_bonusPool[_rnd.nextInt(_bonusPool.length)]);
    } else if (_combo >= 3) {
      _flash('Combo x$_combo!');
    }
    if (!_beatBest && _best > 0 && _score > _best) {
      _beatBest = true;
      // Takes priority over the combo/bonus flash just set above — a new
      // all-time record is the bigger moment of the two.
      _banner = 'New personal best! 🏆';
      _bannerT = 1.6;
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
    if (_score >= _target) _end(GameStatus.won);
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.1;
  }

  void _splashAt(double x, double y, Color color, int n) {
    final effectiveN = _reduceMotion ? math.max(3, (n / 3).round()) : n;
    for (var i = 0; i < effectiveN; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.3 + _rnd.nextDouble() * 0.5;
      _splash.add(_Particle(
          Offset(x, y),
          Offset(math.cos(a) * sp, math.sin(a) * sp),
          color,
          0.4 + _rnd.nextDouble() * 0.3));
    }
  }

  void _end(GameStatus s) {
    _status = s;
    if (s == GameStatus.won) {
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
    }
    emit(s == GameStatus.won
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _moveTo(double px, double width) {
    setState(() => _basketX = (px / width).clamp(0.06, 0.94));
  }

  void _reset() {
    setState(() {
      _items.clear();
      _splash.clear();
      _score = 0;
      _combo = 0;
      _beatBest = false;
      _banner = null;
      _bannerT = 0;
      _spawnIn = 0.6;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _GameShell(
      title: '🧺 Catch',
      winEmoji: '🧺',
      winText: _winPraise,
      introHow: 'Drag the basket to catch the fruit — dodge the bombs!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF43E97B),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _moveTo(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _moveTo(d.localPosition.dx, w),
            onPanUpdate: (d) => _moveTo(d.localPosition.dx, w),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF15324A), Color(0xFF0B2436)],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  for (final f in _items)
                    Positioned(
                      left: f.x * w - 22,
                      top: f.y * h - 22,
                      child:
                          Text(f.emoji, style: const TextStyle(fontSize: 40)),
                    ),
                  Positioned.fill(
                    child: CustomPaint(painter: _SplashPainter(_splash)),
                  ),
                  Positioned(
                    left: _basketX * w - 40,
                    top: 0.85 * h,
                    child: const Text('🧺', style: TextStyle(fontSize: 64)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Balloon Pop — balloons drift up; tap them to pop before they float away.
// Reach the target to win. Pure popping joy, with a satisfying pop each time.
// ===========================================================================
class BalloonPopGame extends StatefulWidget {
  const BalloonPopGame({super.key});
  @override
  State<BalloonPopGame> createState() => _BalloonPopGameState();
}

class _Balloon {
  _Balloon(this.x, this.y, this.vy, this.sway, this.color, this.kind);
  double x;
  double y;
  double vy;
  double sway;
  final Color color;
  final int kind; // 0 = normal, 1 = golden bonus, 2 = bomb to avoid
}

class _BalloonPopGameState extends State<BalloonPopGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'balloon_pop';
  static const List<Color> _colors = <Color>[
    Color(0xFFEF476F),
    Color(0xFFFFD166),
    Color(0xFF06D6A0),
    Color(0xFF118AB2),
    Color(0xFF9B5DE5),
  ];
  static const int _target = 20;
  // Same missed gap as fruit_catch: no `winText:` was ever passed, so this
  // game always showed the shell's generic "You did it!" on every win.
  static const List<String> _winPraisePool = <String>[
    'Balloon-popping champion!',
    'Pop perfection!',
    'Streak superstar!',
    'Sky cleared!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  // Same flat-repeated-banner gap just fixed in fruit_catch above — these
  // fired the exact same literal on every miss/bonus, up to a dozen times
  // per playthrough.
  static const List<String> _missPool = <String>[
    'Floated away! Combo reset', 'Drifted off! Combo reset',
    'So close! Combo reset', 'Almost! Combo reset',
  ];
  static const List<String> _bombPool = <String>[
    'Oops! Avoid bombs', 'Ouch! Avoid bombs',
    'Watch out for bombs!', 'Careful! Avoid bombs',
  ];
  static const List<String> _bonusPool = <String>[
    'Bonus +3!', 'Sweet bonus +3!', 'Nice pop! +3', 'Brilliant! +3',
  ];
  final List<_Balloon> _items = <_Balloon>[];
  final List<_Particle> _pop = <_Particle>[];
  bool _reduceMotion = false;
  double _spawnIn = 0.4;
  double _t = 0;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // Same "beat your own all-time best" live-celebration pattern just added
  // to fruit_catch: the moment a run's score first overtakes the prior
  // record is the single most replay-motivating event this game has, and it
  // used to be entirely silent — only visible as the header's quiet "★ N"
  // ticking up mid-run. Guarded so it fires once per run and never on a
  // brand-new player's first pop (where `_best` is still 0).
  bool _beatBest = false;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = _pop.length - 1; i >= 0; i--) {
      final p = _pop[i];
      p.pos += p.vel * dt;
      p.vel = Offset(p.vel.dx * 0.88, p.vel.dy * 0.88 + 0.5 * dt);
      p.life -= dt;
      if (p.life <= 0) _pop.removeAt(i);
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn =
          math.max(0.3, 0.6 - _score * 0.008) * (0.7 + _rnd.nextDouble() * 0.6);
      final r = _rnd.nextDouble();
      final kind = r < 0.1 ? 2 : (r < 0.22 ? 1 : 0);
      final color = kind == 1
          ? const Color(0xFFFFD700)
          : kind == 2
              ? const Color(0xFF4A4A55)
              : _colors[_rnd.nextInt(_colors.length)];
      _items.add(_Balloon(
          0.1 + _rnd.nextDouble() * 0.8,
          1.1,
          0.16 +
              _rnd.nextDouble() * 0.12 +
              _score * 0.004 +
              (kind == 1 ? 0.1 : 0),
          _rnd.nextDouble() * 6.28,
          color,
          kind));
    }
    for (final b in _items) {
      b.y -= b.vy * dt;
    }
    _items.removeWhere((b) {
      if (b.y < -0.1) {
        // A balloon floating off the top with no feedback silently killed a
        // child's combo for a reason they never saw happen (unlike bombs,
        // which already flash "Oops!" on a bad tap) — flash the same kind of
        // setback message here so a reset streak is never a mystery.
        if (b.kind != 2) {
          if (_combo > 0) {
            _flash(_missPool[_rnd.nextInt(_missPool.length)]);
            // Same audio-parity gap as fruit_catch's identical miss path: the
            // flash above is visual-only, so a blind/low-vision child got no
            // signal their streak just broke, unlike the bomb-pop path which
            // already pairs its 'Oops!' flash with a sound. Reuse the same
            // gentle-retry miss cue used catalog-wide for every other miss.
            TonePlayer.instance.playCue(SoundCue.gentleRetry);
            // Pair the sound with the same companion emit the catalog's
            // non-terminal wrong-answer games (_ChoiceGoalGame,
            // _PathFinderGameState, fruit_catch's own missed-fruit path)
            // already give Hari/Pico so it can react to this combo break.
            emit(ExperienceEvent.incorrectAnswer);
          }
          _combo = 0;
        }
        return true;
      }
      return false;
    });
  }

  void _tap(double px, double py, double w, double h) {
    if (_status != GameStatus.playing) return;
    for (var i = _items.length - 1; i >= 0; i--) {
      final b = _items[i];
      final bx = (b.x + math.sin(_t * 1.5 + b.sway) * 0.03) * w;
      final by = b.y * h;
      if ((px - bx).abs() < 52 && (py - by).abs() < 62) {
        _resolvePop(_items.removeAt(i));
        return;
      }
    }
  }

  // Screen-reader bridge for the whole-screen tap-to-pop gesture above: picks
  // the real non-bomb balloon closest to floating off the top (smallest `y`)
  // so the discrete action drives the exact same `_resolvePop` scoring path a
  // sighted tap would, rather than offering no way to play at all.
  void _popNearestSafe() {
    if (_status != GameStatus.playing) return;
    _Balloon? nearest;
    var nearestIndex = -1;
    for (var i = 0; i < _items.length; i++) {
      final b = _items[i];
      if (b.kind == 2) continue;
      if (nearest == null || b.y < nearest.y) {
        nearest = b;
        nearestIndex = i;
      }
    }
    if (nearest == null) return;
    _resolvePop(_items.removeAt(nearestIndex));
  }

  void _resolvePop(_Balloon b) {
    final vx = b.x + math.sin(_t * 1.5 + b.sway) * 0.03;
    if (b.kind == 2) {
      _combo = 0;
      _popBurst(vx, b.y, const Color(0xFF9AA0B5), 10);
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      // Same companion-silence gap fixed above for the floated-away
      // miss: a bomb pop is a real penalty event that deserves the
      // same emit the catalog's other non-terminal misses already get.
      emit(ExperienceEvent.incorrectAnswer);
      _flash(_bombPool[_rnd.nextInt(_bombPool.length)]);
      return;
    }
    _combo++;
    _score += (b.kind == 1 ? 3 : 1) + (_combo >= 4 ? 1 : 0);
    _popBurst(vx, b.y, b.color, b.kind == 1 ? 18 : 12);
    TonePlayer.instance.playCue(SoundCue.balloon);
    emit(ExperienceEvent.bubblePopped);
    if (b.kind == 1) {
      _flash(_bonusPool[_rnd.nextInt(_bonusPool.length)]);
    } else if (_combo >= 4) {
      _flash('Combo x$_combo!');
    }
    if (!_beatBest && _best > 0 && _score > _best) {
      _beatBest = true;
      // Takes priority over the combo/bonus flash just set above — a
      // new all-time record is the bigger moment of the two.
      _banner = 'New personal best! 🏆';
      _bannerT = 1.6;
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
    if (_score >= _target) _end(GameStatus.won);
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.1;
  }

  void _popBurst(double x, double y, Color color, int n) {
    final effectiveN = _reduceMotion ? math.max(3, (n / 3).round()) : n;
    for (var i = 0; i < effectiveN; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.35 + _rnd.nextDouble() * 0.55;
      _pop.add(_Particle(
          Offset(x, y),
          Offset(math.cos(a) * sp, math.sin(a) * sp),
          color,
          0.35 + _rnd.nextDouble() * 0.3));
    }
  }

  void _end(GameStatus s) {
    _status = s;
    if (s == GameStatus.won) {
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
    }
    emit(s == GameStatus.won
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _reset() {
    setState(() {
      _items.clear();
      _pop.clear();
      _score = 0;
      _combo = 0;
      _beatBest = false;
      _banner = null;
      _bannerT = 0;
      _spawnIn = 0.4;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _GameShell(
      title: '🎈 Pop',
      winEmoji: '🎈',
      winText: _winPraise,
      introHow:
          'Tap the balloons to pop them — gold ones are worth bonus points. '
          'Avoid the dark bomb balloons, and pop fast for combos!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF06D6A0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Semantics(
            button: true,
            label: 'Balloons $_score of $_target. Pop the nearest safe '
                'balloon, avoiding bombs.',
            onTap: _popNearestSafe,
            excludeSemantics: true,
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _tap(d.localPosition.dx, d.localPosition.dy, w, h),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF1A1246), Color(0xFF241A5E)],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  for (final b in _items)
                    Positioned(
                      left: (b.x + math.sin(_t * 1.5 + b.sway) * 0.03) * w - 26,
                      top: b.y * h - 32,
                      child: _BalloonShape(color: b.color, kind: b.kind),
                    ),
                  Positioned.fill(
                    child: CustomPaint(painter: _SplashPainter(_pop)),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}

class _BalloonShape extends StatelessWidget {
  const _BalloonShape({required this.color, this.kind = 0});
  final Color color;
  final int kind;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 52,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(30),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 12),
            ],
          ),
          child: Text(
              kind == 1
                  ? '✨'
                  : kind == 2
                      ? '💣'
                      : '',
              style: const TextStyle(fontSize: 22)),
        ),
        Container(width: 2, height: 18, color: Colors.white24),
      ],
    );
  }
}

/// Shared normalized-space particle overlay for the catch/pop mini games.
class _SplashPainter extends CustomPainter {
  _SplashPainter(this.parts);
  final List<_Particle> parts;
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in parts) {
      final k = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(p.pos.dx * size.width, p.pos.dy * size.height),
          3 + 4 * k, Paint()..color = p.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_SplashPainter oldDelegate) => true;
}

// ===========================================================================
// Star Catch — a reaction game under a living night sky. One star glows with a
// shrinking countdown ring; tap it before it fades. Gold shooting stars are
// worth triple. Combos, floating score pops and drifting background stars give
// it its own identity. No fail state — a miss just resets your streak.
// ===========================================================================
class StarTapGame extends StatefulWidget {
  const StarTapGame({super.key});
  @override
  State<StarTapGame> createState() => _StarTapGameState();
}

class _StarPop {
  _StarPop(this.cell, this.text);
  final int cell;
  final String text;
  double t = 0.7;
}

class _StarTapGameState extends State<StarTapGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'star_tap';
  static const int _target = 15;
  static const int _cells = 9;
  // Same missed gap as fruit_catch/balloon_pop: no `winText:` was ever
  // passed, so this game always showed the shell's generic "You did it!".
  static const List<String> _winPraisePool = <String>[
    'Star-catching champion!',
    'Constellation complete!',
    'Lightning reflexes!',
    'Galaxy cleared!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  // Same flat-repeated-banner gap just fixed in fruit_catch/balloon_pop
  // above — these fired the exact same literal on every miss, up to a
  // dozen times per playthrough.
  static const List<String> _fadePool = <String>[
    'Star faded! Combo reset', 'Too slow! Combo reset',
    'Missed it! Combo reset', 'So close! Combo reset',
  ];
  static const List<String> _decoyPool = <String>[
    'Skip the red one!', 'That one is a decoy!',
    'Not the red star!', 'Careful, that\u2019s a decoy!',
  ];
  static const List<String> _emptyMissPool = <String>[
    'Missed! Combo reset', 'So close! Combo reset',
    'Try the glowing star!', 'Almost! Combo reset',
  ];
  int _active = 0;
  int _kind = 0; // 0 = normal, 1 = gold (+3), 2 = rainbow (+5, rare)
  int _decoy = -1; // a red star to avoid (-1 = none)
  double _life = 0;
  double _lifeMax = 1.6;
  double _t = 0;
  int _score = 0;
  int _combo = 0;
  int _wave = 0;
  double _shootT = 0; // shooting-star streak timer on a new wave
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  final List<_StarPop> _pops = <_StarPop>[];
  final List<Offset> _bgStars = <Offset>[];
  GameStatus _status = GameStatus.ready;
  // Every sibling tap/catch game in the catalog (fruit_catch's splash,
  // balloon_pop's pop, snake's orb burst, bowling's confetti) celebrates a
  // successful hit with a small particle burst — Star Catch only ever showed
  // a floating "+N" text, making its own "good catch" moment read flatter
  // than every neighbouring game despite being a pure reaction-tap game
  // built entirely around that one feeling. Reuses the catalog's shared
  // `_Particle` class and the same fractional-coordinate convention as
  // `_SplashPainter`.
  final List<_Particle> _particles = <_Particle>[];
  bool _reduceMotion = false;
  // Same "beat your own all-time best" live-celebration pattern added to
  // fruit_catch/balloon_pop: fires once per run the instant the score first
  // overtakes the prior record, guarded against a brand-new player's first
  // star (where `_best` is still 0).
  bool _beatBest = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 36; i++) {
      _bgStars.add(Offset(_rnd.nextDouble(), _rnd.nextDouble()));
    }
    _spawnStar();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  // Cell index -> fractional (0..1) centre, matching the GridView.count
  // layout built below (24/92/24/40 padding, 3 columns, 16px spacing).
  Offset _cellCenter(int i, double w, double h) {
    const cols = 3;
    final rows = (_cells / cols).ceil();
    final gridW = w - 48, gridH = h - 132;
    final cw = (gridW - 16 * (cols - 1)) / cols;
    final ch = (gridH - 16 * (rows - 1)) / rows;
    final col = i % cols, row = i ~/ cols;
    final cx = 24 + col * (cw + 16) + cw / 2;
    final cy = 92 + row * (ch + 16) + ch / 2;
    return Offset(cx / w, cy / h);
  }

  void _burst(Offset fracPos, Color color) {
    final n = _reduceMotion ? 4 : 14;
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.3 + _rnd.nextDouble() * 0.5;
      _particles.add(_Particle(fracPos,
          Offset(math.cos(a) * sp, math.sin(a) * sp), color,
          0.4 + _rnd.nextDouble() * 0.3));
    }
  }

  void _spawnStar() {
    _active = _rnd.nextInt(_cells);
    final roll = _rnd.nextDouble();
    // Rainbow stars are rare, fast and worth the most; gold are the mid tier.
    if (_score >= 10 && roll < 0.10) {
      _kind = 2;
    } else if (roll < 0.26) {
      _kind = 1;
    } else {
      _kind = 0;
    }
    // Special stars are faster; everything speeds up as the score climbs.
    _lifeMax = math.max(0.6, (1.5 - _score * 0.05)) * (_kind >= 1 ? 0.7 : 1);
    _life = _lifeMax;
    // A red decoy appears once a child is doing well; tapping it costs a
    // point, so the game becomes about looking, not just fast tapping.
    final decoyChance =
        _score >= 6 ? math.min(0.55, 0.18 + _score * 0.03) : 0.0;
    if (decoyChance > 0 && _rnd.nextDouble() < decoyChance) {
      var d = _rnd.nextInt(_cells);
      if (d == _active) d = (d + 1) % _cells;
      _decoy = d;
    } else {
      _decoy = -1;
    }
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (final p in _pops) {
      p.t -= dt;
    }
    if (_shootT > 0) _shootT -= dt;
    _pops.removeWhere((p) => p.t <= 0);
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.pos += p.vel * dt * 0.4;
      p.life -= dt;
      if (p.life <= 0) _particles.removeAt(i);
    }
    _life -= dt;
    if (_life <= 0) {
      // A star that fades away unclaimed is the same silent-setback gap as
      // balloon_pop/fruit_catch: the decoy-tap miss already flashes 'Skip
      // the red one!', so letting a combo vanish here with no message at
      // all would cost a streak for a reason a child never saw happen.
      if (_combo > 0) _flash(_fadePool[_rnd.nextInt(_fadePool.length)]);
      _combo = 0; // missed — the star faded away
      _spawnStar();
    }
  }

  Size? _lastSize;

  void _tapCell(int i) {
    if (_status != GameStatus.playing) return;
    if (i == _decoy) {
      _combo = 0;
      if (_score > 0) _score -= 1;
      _pops.add(_StarPop(i, '-1'));
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _flash(_decoyPool[_rnd.nextInt(_decoyPool.length)]);
      setState(() {});
      return;
    }
    if (i == _active) {
      _combo++;
      final quick = _lifeMax > 0 && (_life / _lifeMax) > 0.6;
      final base = _kind == 2 ? 5 : (_kind == 1 ? 3 : 1);
      final gain = base + (_combo >= 5 ? 1 : 0) + (quick ? 1 : 0);
      _score += gain;
      _pops.add(_StarPop(i, '+$gain'));
      final size = _lastSize;
      if (size != null) {
        final glow = _kind == 2
            ? const Color(0xFFB388FF)
            : (_kind == 1 ? const Color(0xFFFFE066) : const Color(0xFFFFD166));
        _burst(_cellCenter(i, size.width, size.height), glow);
      }
      TonePlayer.instance
          .playCue(_kind >= 1 ? SoundCue.coin : SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      if (_kind == 2) {
        _flash('Rainbow star +5! 🌈');
      } else if (_kind == 1) {
        _flash('Shooting star +3!');
      } else if (_combo >= 8) {
        _flash('On fire! x$_combo 🔥');
      } else if (quick) {
        _flash('Quick! +$gain');
      } else if (_combo >= 5) {
        _flash('Combo x$_combo!');
      }
      // Every 5 points starts a new wave with a shooting-star across the sky.
      final newWave = _score ~/ 5;
      if (newWave > _wave) {
        _wave = newWave;
        _shootT = 1.0;
      }
      if (!_beatBest && _best > 0 && _score > _best) {
        _beatBest = true;
        // Takes priority over the combo/wave flash just set above — a new
        // all-time record is the bigger moment of the two.
        _banner = 'New personal best! 🏆';
        _bannerT = 1.6;
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_score >= _target) {
        _end(GameStatus.won);
        return;
      }
      setState(_spawnStar);
    } else {
      // Tapping an empty cell is the same silent-setback gap the comment on
      // the star-fade timeout above already fixed: it resets a combo with
      // only a sound cue and no banner, so a child losing a streak here
      // never saw why. Match the star-fade/decoy-tap wording pattern.
      if (_combo > 0) _flash(_emptyMissPool[_rnd.nextInt(_emptyMissPool.length)]);
      _combo = 0;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
    }
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.1;
  }

  void _end(GameStatus s) {
    _status = s;
    if (s == GameStatus.won) {
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
    }
    emit(ExperienceEvent.gameCompleted);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _reset() {
    setState(() {
      _score = 0;
      _combo = 0;
      _wave = 0;
      _shootT = 0;
      _beatBest = false;
      _banner = null;
      _bannerT = 0;
      _pops.clear();
      _particles.clear();
      _decoy = -1;
      _status = GameStatus.playing;
      _spawnStar();
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _GameShell(
      title: '⭐ Star Catch',
      winEmoji: '⭐',
      winText: _winPraise,
      introHow:
          'Tap the glowing star fast! Gold and rainbow stars are worth more '
          '— but skip the red decoy. Reach 15 points to win!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(painter: _NightSkyPainter(_bgStars, _t, _shootT)),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 92, 24, 40),
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var i = 0; i < _cells; i++)
                      Semantics(
                        button: true,
                        // States only what a sighted child already sees in this
                        // cell this frame (empty / the lit star's own kind / the
                        // red decoy) — never which cell will light up next —
                        // preserving the real reaction-speed challenge for
                        // screen-reader users.
                        label: i == _active
                            ? (_kind == 2
                                ? 'Rainbow star, worth 5. Tap to catch!'
                                : _kind == 1
                                    ? 'Shooting star, worth 3. Tap to catch!'
                                    : 'Star. Tap to catch!')
                            : i == _decoy
                                ? 'Red decoy. Do not tap.'
                                : 'Empty.',
                        onTap: () => _tapCell(i),
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTapDown: (_) => _tapCell(i),
                          child: _StarCell(
                            active: i == _active,
                            decoy: i == _decoy,
                            kind: _kind,
                            lifeFraction: _lifeMax > 0 ? (_life / _lifeMax) : 0,
                            pop: _popFor(i),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _SplashPainter(_particles)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  _StarPop? _popFor(int cell) {
    for (final p in _pops) {
      if (p.cell == cell) return p;
    }
    return null;
  }
}

/// One tappable star cell — an empty socket, or the glowing active star with a
/// shrinking countdown ring and an optional floating score pop.
class _StarCell extends StatelessWidget {
  const _StarCell({
    required this.active,
    required this.kind,
    required this.lifeFraction,
    required this.pop,
    this.decoy = false,
  });
  final bool active;
  final int kind;
  final double lifeFraction;
  final _StarPop? pop;
  final bool decoy;

  @override
  Widget build(BuildContext context) {
    final gold = kind == 1;
    final glow = kind == 2
        ? const Color(0xFFB388FF)
        : (gold ? const Color(0xFFFFE066) : const Color(0xFFFFD166));
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(active ? 0.10 : 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withOpacity(active ? 0.0 : 0.06)),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(color: glow.withOpacity(0.55), blurRadius: 26)
                  ]
                : const <BoxShadow>[],
          ),
        ),
        if (decoy && !active) ...<Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.75), width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                      color: Colors.red.withOpacity(0.45), blurRadius: 20),
                ],
              ),
            ),
          ),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('\u{1F534}', maxLines: 1, style: TextStyle(fontSize: 36)),
          ),
        ],
        if (active) ...<Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: CircularProgressIndicator(
                value: lifeFraction.clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(glow),
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(kind == 2 ? '💫' : (gold ? '🌟' : '⭐'),
                maxLines: 1, style: const TextStyle(fontSize: 42)),
          ),
        ],
        if (pop != null)
          Transform.translate(
            offset: Offset(0, -22 * (1 - pop!.t / 0.7) - 6),
            child: Opacity(
              opacity: pop!.t.clamp(0.0, 0.7) / 0.7,
              child: Text(pop!.text,
                  style: TextStyle(
                      color: glow, fontSize: 22, fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}

/// A slow, twinkling night sky with a soft moon — Star Catch's own backdrop.
class _NightSkyPainter extends CustomPainter {
  _NightSkyPainter(this.stars, this.t, [this.shootT = 0]);
  final List<Offset> stars;
  final double t;
  final double shootT;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0A1733), Color(0xFF13294B)],
          ).createShader(Offset.zero & size));
    // Soft moon glow, upper right.
    final moon = Offset(size.width * 0.82, size.height * 0.12);
    canvas.drawCircle(
        moon, 42, Paint()..color = const Color(0xFFFFF3C4).withOpacity(0.16));
    canvas.drawCircle(moon, 22, Paint()..color = const Color(0xFFFDF6D8));
    // Twinkling background stars.
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 2 + i));
      canvas.drawCircle(Offset(s.dx * size.width, s.dy * size.height), 1.4 + tw,
          Paint()..color = Colors.white.withOpacity(0.25 + 0.4 * tw));
    }
    // A shooting star streaks across on each new wave.
    if (shootT > 0) {
      final p = (1 - shootT).clamp(0.0, 1.0);
      final head =
          Offset(size.width * (0.1 + p * 0.85), size.height * (0.1 + p * 0.5));
      final tail = head - const Offset(90, 50);
      canvas.drawLine(
          tail,
          head,
          Paint()
            ..shader = LinearGradient(colors: <Color>[
              Colors.white.withOpacity(0),
              Colors.white.withOpacity(0.9),
            ]).createShader(Rect.fromPoints(tail, head))
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
      canvas.drawCircle(head, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_NightSkyPainter oldDelegate) => true;
}

// ===========================================================================
// Snake — a modern slither-style worm. Your rainbow snake roams a big glowing
// arena, eating orbs to grow longer. Drag anywhere to steer toward your finger;
// hold Boost for a speed burst (it trims a little length). The camera follows
// you, friendly worms share the arena, and touching the glowing edge ends the
// run. Built for smooth, satisfying, sensory-friendly play.
// ===========================================================================
class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});
  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _Orb {
  _Orb(this.pos, this.color, this.r, {this.golden = false});
  Offset pos;
  final Color color;
  final double r;
  final bool golden;
}

class _AiWorm {
  _AiWorm(this.head, this.angle, this.hue, this.length);
  Offset head;
  double angle;
  double target = 0;
  double hue;
  int length;
  double turnTimer = 0;
  final List<Offset> path = <Offset>[];
}

class _Particle {
  _Particle(this.pos, this.vel, this.color, this.life) : maxLife = life;
  Offset pos;
  Offset vel;
  final Color color;
  double life;
  final double maxLife;
}

class _SnakeGameState extends State<SnakeGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'snake';
  static const int _targetScore = 30;
  static const double _arenaR = 900;
  static const double _spacing = 2.6; // path sample distance
  static const double _seg = 8; // body segment spacing
  static const double _baseSpeed = 165;
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Longest snake in the arena!" line (across-restarts
  // sibling of the per-round praise-variety fixes applied elsewhere this
  // sprint).
  static const List<String> _winPraisePool = <String>[
    'Longest snake in the arena!',
    'Top of the leaderboard!',
    'Slither champion!',
    'Unstoppable glide!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  // Same flat-repeated-banner gap fixed in fruit_catch/balloon_pop/star_tap
  // above — a rival takedown can happen many times in one run, and all
  // reinforcement waves fired the exact same literal every time.
  static const List<String> _rivalDownPool = <String>[
    'Snake down! +3', 'Rival down! +3', 'Takedown! +3', 'Got one! +3',
  ];
  static const List<String> _rivalInPool = <String>[
    'Rival incoming!', 'Another worm joins!', 'New rival ahead!', 'Watch out, newcomer!',
  ];
  // Golden orbs respawn after every catch, so a long run can eat several
  // with a sub-3 combo — the same flat-repeated-banner gap as above, just
  // on the low-combo branch of the golden-orb flash below.
  static const List<String> _goldenPool = <String>[
    'Golden! +3', 'Shiny! +3', 'Gold orb! +3', 'Sparkly! +3',
  ];

  Offset _head = Offset.zero;
  double _angle = 0;
  double _target = 0;
  final List<Offset> _path = <Offset>[];
  int _length = 24;
  bool _boost = false;
  double _boostAcc = 0;
  double _t = 0;
  final List<_Orb> _orbs = <_Orb>[];
  final List<_AiWorm> _ai = <_AiWorm>[];
  final List<_Particle> _particles = <_Particle>[];
  bool _reduceMotion = false;
  // Score thresholds at which one more rival worm joins the arena (capped).
  static const List<int> _aiReinforceScores = <int>[8, 18];
  int _aiReinforcementsSpawned = 0;
  int _score = 0;
  int _best = 0;
  // Same pattern as FruitCatchGame/BalloonPopGame/StarTapGame: a simple
  // incrementing score toward a fixed target is a judgment-free "beat your
  // own best" moment, fired once per run the first time it happens.
  bool _beatBest = false;
  int _combo = 0;
  double _comboT = 0;
  double _bannerT = 0;
  String? _banner;
  String _overReason = 'Stay inside the glowing edge.';
  Size _view = const Size(360, 640);
  GameStatus _status = GameStatus.ready;

  static const List<Color> _orbColors = <Color>[
    Color(0xFFFF4D6D),
    Color(0xFFFFD166),
    Color(0xFF06D6A0),
    Color(0xFF4CC9F0),
    Color(0xFF9B5DE5),
    Color(0xFFFF9E00),
  ];

  @override
  void initState() {
    super.initState();
    _seedWorld();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _seedWorld() {
    _head = Offset.zero;
    _angle = 0;
    _target = 0;
    _path
      ..clear()
      ..add(_head);
    _length = 24;
    _boost = false;
    _boostAcc = 0;
    _score = 0;
    _beatBest = false;
    _combo = 0;
    _comboT = 0;
    _particles.clear();
    _orbs.clear();
    for (var i = 0; i < 240; i++) {
      _orbs.add(_randomOrb());
    }
    _ai.clear();
    for (var i = 0; i < 5; i++) {
      _ai.add(_spawnAiWorm());
    }
    _aiReinforcementsSpawned = 0;
  }

  _AiWorm _spawnAiWorm() {
    // Spawn away from the player so a worm never appears on top of the head.
    Offset pos;
    var tries = 0;
    do {
      final a = _rnd.nextDouble() * math.pi * 2;
      final d = _arenaR * (0.3 + _rnd.nextDouble() * 0.5);
      pos = Offset(math.cos(a) * d, math.sin(a) * d);
      tries++;
    } while ((pos - _head).distance < 240 && tries < 8);
    final w = _AiWorm(pos, _rnd.nextDouble() * math.pi * 2,
        _rnd.nextDouble() * 360, 14 + _rnd.nextInt(10));
    w.target = w.angle;
    w.path.add(w.head);
    return w;
  }

  _Orb _randomOrb() {
    final a = _rnd.nextDouble() * math.pi * 2;
    final d = math.sqrt(_rnd.nextDouble()) * (_arenaR - 24);
    // Roughly one orb in eleven is a golden orb: rarer, larger, worth more.
    if (_rnd.nextInt(11) == 0) {
      return _Orb(Offset(math.cos(a) * d, math.sin(a) * d),
          const Color(0xFFFFE066), 7.0 + _rnd.nextDouble() * 2,
          golden: true);
    }
    return _Orb(
        Offset(math.cos(a) * d, math.sin(a) * d),
        _orbColors[_rnd.nextInt(_orbColors.length)],
        3.5 + _rnd.nextDouble() * 3.5);
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_comboT > 0) {
      _comboT -= dt;
      if (_comboT <= 0) _combo = 0;
    }
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.pos += p.vel * dt;
      p.vel *= 0.88;
      p.life -= dt;
      if (p.life <= 0) _particles.removeAt(i);
    }

    // Real challenge escalation: as score climbs toward the 30-point win,
    // reinforcement rivals join the arena so the threat genuinely grows
    // instead of staying at a flat 5 lazy worms for the whole run.
    while (_aiReinforcementsSpawned < _aiReinforceScores.length &&
        _score >= _aiReinforceScores[_aiReinforcementsSpawned]) {
      _ai.add(_spawnAiWorm());
      _aiReinforcementsSpawned++;
      _flash(_rivalInPool[_rnd.nextInt(_rivalInPool.length)]);
    }

    // Steer toward the target heading with a capped turn rate.
    double diff = _target - _angle;
    while (diff > math.pi) diff -= math.pi * 2;
    while (diff < -math.pi) diff += math.pi * 2;
    _angle += diff.clamp(-3.6 * dt, 3.6 * dt);

    final speed = _baseSpeed *
        (1.0 + math.min(_score, 40) * 0.012) *
        (_boost && _length > 26 ? 1.85 : 1.0);
    _head += Offset(math.cos(_angle), math.sin(_angle)) * speed * dt;

    if (_path.isEmpty || (_head - _path.first).distance >= _spacing) {
      _path.insert(0, _head);
    }
    _trimPath(_length * _seg + _seg);

    // Boost slowly trims length and drops a glowing orb behind.
    if (_boost && _length > 26) {
      _boostAcc += dt;
      if (_boostAcc >= 0.14) {
        _boostAcc = 0;
        _length -= 1;
        _orbs.add(_Orb(_path.isNotEmpty ? _path.last : _head,
            const Color(0xFFFFE066), 4.5));
      }
    }

    // Eat nearby orbs.
    for (var i = _orbs.length - 1; i >= 0; i--) {
      if ((_orbs[i].pos - _head).distance < 15) {
        final golden = _orbs[i].golden;
        final orbPos = _orbs[i].pos;
        final orbColor = _orbs[i].color;
        _orbs.removeAt(i);
        _burst(orbPos, golden ? const Color(0xFFFFE066) : orbColor,
            golden ? 16 : 9, golden ? 220 : 150);
        // Rapid, back-to-back eating builds a combo that fades if you pause.
        _combo = _comboT > 0 ? _combo + 1 : 1;
        _comboT = 1.4;
        final comboBonus = _combo >= 3 ? 1 : 0;
        if (golden) {
          _length += 5;
          _score += 3 + comboBonus;
          _flash(_combo >= 3
              ? 'Golden! Combo x$_combo'
              : _goldenPool[_rnd.nextInt(_goldenPool.length)]);
          TonePlayer.instance.playCue(SoundCue.coin);
        } else {
          _length += 2;
          _score += 1 + comboBonus;
          if (_combo >= 5) {
            _flash('Combo x$_combo!');
          } else if (_score % 10 == 0) {
            _flash('Length $_length!');
          }
          TonePlayer.instance.playCue(SoundCue.snakeEat);
        }
        if (!_beatBest && _best > 0 && _score > _best) {
          _beatBest = true;
          // Takes priority over the combo/golden flash just set above — a
          // new all-time record is the bigger moment of the two.
          _flash('New personal best! 🏆');
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        emit(ExperienceEvent.bubblePopped);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted && b != _best) setState(() => _best = b);
        });
        _orbs.add(_randomOrb());
        if (_score >= _targetScore) {
          _finish(GameStatus.won);
          return;
        }
      }
    }

    _updateAi(dt);

    // Slither rules: your head hitting another snake's body ends the run.
    for (final w in _ai) {
      for (var i = 4; i < w.path.length; i += 2) {
        if ((w.path[i] - _head).distance < 10) {
          _overReason = 'You ran into another snake!';
          _gameOver();
          return;
        }
      }
    }
    // A rival that runs into YOUR body bursts into a shower of orbs to eat.
    for (var wi = _ai.length - 1; wi >= 0; wi--) {
      final w = _ai[wi];
      var hit = false;
      for (var i = 10; i < _path.length; i += 2) {
        if ((_path[i] - w.head).distance < 10) {
          hit = true;
          break;
        }
      }
      if (hit) {
        for (var i = 0; i < w.path.length; i += 6) {
          _orbs.add(_Orb(w.path[i], const Color(0xFF06D6A0), 4.5));
        }
        _burst(w.head, const Color(0xFF06D6A0), 22, 260);
        _ai.removeAt(wi);
        _ai.add(_spawnAiWorm());
        _score += 3;
        _flash(_rivalDownPool[_rnd.nextInt(_rivalDownPool.length)]);
        TonePlayer.instance.playCue(SoundCue.success);
        if (!_beatBest && _best > 0 && _score > _best) {
          _beatBest = true;
          _flash('New personal best! 🏆');
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        // A rival going down is a great mid-run moment, not the actual end
        // of the game — _finish (below) already fires the full "You did
        // it!" celebration once the run really ends, so this only gets the
        // lighter big-positive-moment reaction (matches the golden-orb
        // catch above and other games' in-run pickups).
        emit(ExperienceEvent.bubblePopped);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted && b != _best) setState(() => _best = b);
        });
        if (_score >= _targetScore) {
          _finish(GameStatus.won);
          return;
        }
      }
    }

    // Glowing edge ends the run.
    if (_head.distance > _arenaR) {
      _overReason = 'You touched the glowing edge!';
      _gameOver();
    }
  }

  void _trimPath(double maxLen) {
    double acc = 0;
    for (var i = 1; i < _path.length; i++) {
      acc += (_path[i] - _path[i - 1]).distance;
      if (acc >= maxLen) {
        _path.removeRange(i + 1, _path.length);
        return;
      }
    }
  }

  void _updateAi(double dt) {
    // Rivals genuinely get faster and sharper-turning as the run progresses
    // toward the win target, instead of staying at one flat difficulty the
    // whole game — mirrors the player's own speed-up curve below.
    final difficulty = math.min(_score, _targetScore) / _targetScore;
    final aiSpeed = 120 * (1.0 + difficulty * 0.5);
    final aiTurnRate = 2.4 * (1.0 + difficulty * 0.4);
    final aiTurnMin = 0.6 - difficulty * 0.25;
    final aiTurnSpan = 1.4 - difficulty * 0.5;
    for (final w in _ai) {
      w.turnTimer -= dt;
      if (w.turnTimer <= 0) {
        w.turnTimer = aiTurnMin + _rnd.nextDouble() * aiTurnSpan;
        w.target = w.angle + (_rnd.nextDouble() - 0.5) * 1.6;
      }
      if (w.head.distance > _arenaR * 0.86) {
        w.target = math.atan2(-w.head.dy, -w.head.dx);
      }
      double d = w.target - w.angle;
      while (d > math.pi) d -= math.pi * 2;
      while (d < -math.pi) d += math.pi * 2;
      w.angle += d.clamp(-aiTurnRate * dt, aiTurnRate * dt);
      w.head += Offset(math.cos(w.angle), math.sin(w.angle)) * aiSpeed * dt;
      if (w.path.isEmpty || (w.head - w.path.first).distance >= _spacing) {
        w.path.insert(0, w.head);
      }
      for (var i = _orbs.length - 1; i >= 0; i--) {
        if ((_orbs[i].pos - w.head).distance < 13) {
          _orbs.removeAt(i);
          w.length += 2;
          _orbs.add(_randomOrb());
          break;
        }
      }
      double acc = 0;
      for (var i = 1; i < w.path.length; i++) {
        acc += (w.path[i] - w.path[i - 1]).distance;
        if (acc >= w.length * _seg) {
          w.path.removeRange(i + 1, w.path.length);
          break;
        }
      }
    }
  }

  void _burst(Offset pos, Color color, int n, double speed) {
    final effectiveN = _reduceMotion ? math.max(4, (n / 3).round()) : n;
    for (var i = 0; i < effectiveN; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = speed * (0.4 + _rnd.nextDouble());
      _particles.add(_Particle(pos, Offset(math.cos(a), math.sin(a)) * sp,
          color, 0.4 + _rnd.nextDouble() * 0.4));
    }
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.1;
  }

  void _finish(GameStatus status) {
    final prev = GameScores.instance.best(_id);
    _status = status;
    if (status == GameStatus.won) {
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
    }
    TonePlayer.instance.playCue(
        status == GameStatus.won ? SoundCue.success : SoundCue.gameOver);
    emit(status == GameStatus.won || _score > prev
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _gameOver() {
    _burst(_head, const Color(0xFFFF4D6D), 26, 300);
    _finish(GameStatus.over);
  }

  void _steerTo(Offset local) {
    final v = local - Offset(_view.width / 2, _view.height / 2);
    if (v.distance > 6) _target = math.atan2(v.dy, v.dx);
  }

  void _reset() {
    setState(() {
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
      _seedWorld();
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _GameShell(
      title: '🐍 Snake · Orbs',
      score: _score,
      best: _best,
      target: _targetScore,
      status: _status,
      banner: _banner,
      overEmoji: '🐍',
      overText: _overReason,
      winEmoji: '🏆',
      winText: _winPraise,
      accent: const Color(0xFF06D6A0),
      introHow: 'Glide your snake to eat glowing orbs and grow — hold to boost!\n'
          'Gold orbs are worth more, and luring a rival into your body '
          'defeats it for bonus points. Avoid the edges and their heads!',
      onStart: () => setState(() => _status = GameStatus.playing),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          _view = Size(c.maxWidth, c.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (d) => _steerTo(d.localPosition),
                onPanUpdate: (d) => _steerTo(d.localPosition),
                child: CustomPaint(
                  painter: _SnakePainter(_head, _angle, _path, _length, _seg,
                      _orbs, _ai, _arenaR, _t, _particles, _boost),
                  size: Size.infinite,
                ),
              ),
              Positioned(
                left: 20,
                bottom: 20,
                child: Listener(
                  onPointerDown: (_) => _boost = true,
                  onPointerUp: (_) => _boost = false,
                  onPointerCancel: (_) => _boost = false,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                    child: const Icon(Icons.keyboard_double_arrow_up_rounded,
                        color: Colors.white, size: 40),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                top: 176,
                child: _SnakeLeaderboard(playerScore: _score, ai: _ai),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 150,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Eat orbs to grow · Gold = bonus · Cut off rival snakes · Don\'t hit them or the edge',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SnakeLeaderboard extends StatelessWidget {
  const _SnakeLeaderboard({required this.playerScore, required this.ai});
  final int playerScore;
  final List<_AiWorm> ai;

  @override
  Widget build(BuildContext context) {
    final rivals = <MapEntry<String, int>>[
      for (var i = 0; i < ai.length; i++)
        MapEntry('Worm ${i + 1}', math.max(0, (ai[i].length - 16) ~/ 2)),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('ORB RACE',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('You  $playerScore / 30',
                style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ),
          for (var i = 0; i < rivals.length && i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text('${i + 1}  ${rivals[i].key}  ${rivals[i].value}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _SnakePainter extends CustomPainter {
  _SnakePainter(this.head, this.angle, this.path, this.length, this.seg,
      this.orbs, this.ai, this.arenaR, this.t, this.particles, this.boost);
  final Offset head;
  final double angle;
  final List<Offset> path;
  final int length;
  final double seg;
  final List<_Orb> orbs;
  final List<_AiWorm> ai;
  final double arenaR;
  final double t;
  final List<_Particle> particles;
  final bool boost;

  List<Offset> _resample(List<Offset> pts, double spacing, int count) {
    final out = <Offset>[];
    if (pts.isEmpty) return out;
    out.add(pts[0]);
    double carry = 0;
    for (var i = 1; i < pts.length && out.length < count; i++) {
      var a = pts[i - 1];
      final b = pts[i];
      var d = (b - a).distance;
      while (carry + d >= spacing && out.length < count) {
        final f = (spacing - carry) / d;
        final p = Offset.lerp(a, b, f)!;
        out.add(p);
        a = p;
        d = (b - a).distance;
        carry = 0;
      }
      carry += d;
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final cam = head;
    Offset toScreen(Offset w) => w - cam + center;

    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0B1020));
    // Scrolling dot texture.
    final dot = Paint()..color = Colors.white.withOpacity(0.05);
    const gap = 46.0;
    final sx = (-cam.dx) % gap;
    final sy = (-cam.dy) % gap;
    for (double x = sx - gap; x < size.width + gap; x += gap) {
      for (double y = sy - gap; y < size.height + gap; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.5, dot);
      }
    }
    // Arena boundary glow.
    canvas.drawCircle(
        toScreen(Offset.zero),
        arenaR,
        Paint()
          ..color = const Color(0xFFFF4D6D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Orbs.
    for (final o in orbs) {
      final s = toScreen(o.pos);
      if (s.dx < -20 ||
          s.dx > size.width + 20 ||
          s.dy < -20 ||
          s.dy > size.height + 20) {
        continue;
      }
      canvas.drawCircle(
          s,
          o.r * 2.4,
          Paint()
            ..color = o.color.withOpacity(o.golden ? 0.6 : 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, o.golden ? 8 : 4));
      canvas.drawCircle(s, o.r, Paint()..color = o.color);
      if (o.golden) {
        // A bright core + sparkle ring so golden orbs read as special.
        canvas.drawCircle(s, o.r * 0.45, Paint()..color = Colors.white);
        canvas.drawCircle(
            s,
            o.r + 3 + (math.sin(t * 6 + s.dx) + 1) * 1.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = const Color(0xFFFFF3B0).withOpacity(0.8));
      }
    }

    // Eat / death particle bursts — the juice.
    for (final p in particles) {
      final s = toScreen(p.pos);
      if (s.dx < -16 ||
          s.dx > size.width + 16 ||
          s.dy < -16 ||
          s.dy > size.height + 16) {
        continue;
      }
      final k = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
          s,
          2 + 3.5 * k,
          Paint()
            ..color = p.color.withOpacity(k)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // Friendly AI worms.
    for (final w in ai) {
      final body = _resample(w.path, seg, w.length);
      for (var i = body.length - 1; i >= 0; i--) {
        final r = 7.0 * (1 - i / (body.length + 6) * 0.35);
        canvas.drawCircle(toScreen(body[i]), r,
            Paint()..color = HSVColor.fromAHSV(1, w.hue, 0.55, 0.9).toColor());
      }
    }

    // Player worm — a smooth rainbow body.
    final body = _resample(path, seg, length);
    for (var i = body.length - 1; i >= 0; i--) {
      final s = toScreen(body[i]);
      final r = 9.5 * (1 - i / (body.length + 6) * 0.3);
      var hue = (i * 6 - t * 60) % 360;
      if (hue < 0) hue += 360;
      canvas.drawCircle(
          s,
          r + 2,
          Paint()
            ..color =
                HSVColor.fromAHSV(1, hue, 0.7, 1).toColor().withOpacity(0.22));
      canvas.drawCircle(
          s, r, Paint()..color = HSVColor.fromAHSV(1, hue, 0.78, 1).toColor());
    }
    // Head + eyes looking forward.
    final hs = toScreen(head);
    if (boost) {
      canvas.drawCircle(
          hs,
          26,
          Paint()
            ..color = const Color(0xFF9EE7FF).withOpacity(0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    }
    canvas.drawCircle(hs, 12, Paint()..color = const Color(0xFFFFF3C4));
    final perp = Offset(-math.sin(angle), math.cos(angle));
    final fwd = Offset(math.cos(angle), math.sin(angle));
    for (final sgn in <double>[-1, 1]) {
      final ec = hs + perp * 5 * sgn + fwd * 3;
      canvas.drawCircle(ec, 4, Paint()..color = Colors.white);
      canvas.drawCircle(ec + fwd * 1.5, 2, Paint()..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(_SnakePainter oldDelegate) => true;
}

// ===========================================================================
// Racing — dodge oncoming traffic and grab coins. Tap left/right (or swipe)
// to change lanes; survive longer and the road speeds up. Endless high score.
// ===========================================================================
class RacingGame extends StatefulWidget {
  const RacingGame({super.key});
  @override
  State<RacingGame> createState() => _RacingGameState();
}

class _Racer {
  _Racer(this.lane, this.y, this.coin, this.boost, this.emoji);
  int lane;
  double y;
  final bool coin;
  final bool boost;
  final String emoji;
}

class _RacingGameState extends State<RacingGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'racing';
  static const List<double> _laneX = <double>[0.22, 0.5, 0.78];
  static const List<String> _traffic = <String>['🚗', '🚙', '🚕', '🚚'];
  static const double _raceLen = 1000; // metres to the chequered flag
  static const int _fieldSize = 4; // you + 3 rivals
  // Pool of win phrases so a replaying child doesn't always see the same
  // "P1 — you won the race!" line (across-restarts sibling of the per-round
  // praise-variety fixes applied elsewhere this sprint).
  static const List<String> _winPraisePool = <String>[
    'P1 — you won the race!',
    'Champion driver!',
    'First across the line!',
    'Pole position pro!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  // While boosted, barging through several traffic cars in a row used to
  // flash the exact same 'Smash! +5' literal every single time — the same
  // flat-repeated-banner gap fixed on the golden-orb/rival-takedown events
  // above, just missed in this file.
  static const List<String> _smashPool = <String>[
    'Smash! +5', 'Barge! +5', 'Crunch! +5', 'Plow through! +5',
  ];
  final List<_Racer> _cars = <_Racer>[];
  // The rival pack we are racing against.
  final List<double> _rivals = <double>[]; // metres travelled
  final List<double> _rivalMps = <double>[]; // pace per rival
  final List<int> _rivalLane = <int>[];
  // Rivals used to sit in one fixed lane for the whole race — visually a
  // static backdrop rather than cars actually racing. Track an eased visual
  // lane position (mirroring the player's own `_lanePos` slide-and-bank) plus
  // a per-rival countdown to the next lane change, so the pack genuinely
  // jostles for position like a real race instead of gliding in parallel rails.
  final List<double> _rivalLanePos = <double>[];
  final List<double> _rivalLaneTimer = <double>[];
  int _lane = 1;
  double _lanePos = 1.0; // eased visual lane position — slides, never teleports
  double _spawnIn = 0.9;
  double _t = 0;
  double _speed = 0.55; // visual road scroll
  double _distance = 0; // our progress down the track
  double _boostT = 0;
  double _shuntT = 0; // temporary slow-down after a knock
  int _finishPlace = 0;
  int _score = 0;
  int _best = 0;
  // Same pattern as FruitCatchGame/SnakeGame: pickups only ever add to
  // `_score` during the race, so a live "beat your own best" check is a
  // genuine judgment-free win the moment it happens, well before the
  // final placement bonus/win screen at `_finish`.
  bool _beatBest = false;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  // Linearly interpolates between the three lane x-positions for a
  // fractional lane value (e.g. 0.5 is halfway between lane 0 and lane 1).
  static double _laneX3(double lanePos) {
    final clamped = lanePos.clamp(0.0, 2.0);
    final i = clamped.floor().clamp(0, 1);
    final frac = clamped - i;
    return _laneX[i] + (_laneX[i + 1] - _laneX[i]) * frac;
  }

  int get _place {
    var ahead = 0;
    for (final r in _rivals) {
      if (r > _distance) ahead++;
    }
    return ahead + 1;
  }

  double get _mps {
    var v = 95.0 + _score * 0.04; // pace lifts a little as you score
    if (_boostT > 0) v += 75;
    if (_shuntT > 0) v *= 0.42;
    return v;
  }

  @override
  void initState() {
    super.initState();
    _startRace();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _startRace() {
    _cars.clear();
    _rivals
      ..clear()
      ..addAll(<double>[40, 100, 170]);
    _rivalMps.clear();
    _rivalLane
      ..clear()
      ..addAll(<int>[0, 2, 1]);
    _rivalLanePos
      ..clear()
      ..addAll(<double>[0, 2, 1]);
    _rivalLaneTimer
      ..clear()
      ..addAll(<double>[0, 0, 0]);
    for (var i = 0; i < 3; i++) {
      _rivalMps.add(88 + _rnd.nextDouble() * 20); // 88..108 mps
      _rivalLaneTimer[i] = 1.2 + _rnd.nextDouble() * 2.0;
    }
    _lane = 1;
    _lanePos = 1.0;
    _distance = 0;
    _speed = 0.55;
    _boostT = 0;
    _shuntT = 0;
    _finishPlace = 0;
    _score = 0;
    _beatBest = false;
    _spawnIn = 0.9;
    _t = 0;
    _banner = null;
    _bannerT = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_boostT > 0) _boostT -= dt;
    if (_shuntT > 0) _shuntT -= dt;

    // Ease the visual car smoothly towards the target lane instead of
    // teleporting — a real car banks into the turn over a few frames.
    final laneDiff = _lane - _lanePos;
    if (laneDiff.abs() > 0.0005) {
      final ease = 1 - math.exp(-dt * 10);
      _lanePos += laneDiff * ease;
    } else {
      _lanePos = _lane.toDouble();
    }

    // Advance ourselves and the rival pack down the track.
    final remaining = (_raceLen - _distance).clamp(0.0, _raceLen);
    final mps = _mps;
    final sprintBonus = (1.0 - remaining / _raceLen).clamp(0.0, 1.0) * 18.0;
    final finishPush = (1.0 - remaining / _raceLen).clamp(0.0, 1.0);
    _distance += (mps + sprintBonus) * dt;
    _speed = 0.5 + (mps + sprintBonus) / 240;
    for (var i = 0; i < _rivals.length; i++) {
      final leadGap = _distance - _rivals[i];
      final rivalPace = _rivalMps[i] + (leadGap > 0 ? 12 : 8);
      _rivals[i] += rivalPace * dt;

      // Rivals periodically swap lanes so the pack looks and behaves like a
      // real race (overtaking manoeuvres) instead of 3 cars glued to fixed
      // rails for the whole run. Ease toward the new lane exactly like the
      // player's own `_lanePos`, so rival banking reads the same way.
      _rivalLaneTimer[i] -= dt;
      if (_rivalLaneTimer[i] <= 0) {
        final choices = <int>[0, 1, 2]..remove(_rivalLane[i]);
        _rivalLane[i] = choices[_rnd.nextInt(choices.length)];
        _rivalLaneTimer[i] = 1.8 + _rnd.nextDouble() * 2.4;
      }
      final rivalLaneDiff = _rivalLane[i] - _rivalLanePos[i];
      if (rivalLaneDiff.abs() > 0.0005) {
        final ease = 1 - math.exp(-dt * 8);
        _rivalLanePos[i] += rivalLaneDiff * ease;
      } else {
        _rivalLanePos[i] = _rivalLane[i].toDouble();
      }
    }
    if (_distance >= _raceLen) {
      _finish();
      return;
    }

    // Spawn + advance traffic in screen space.
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.45, 0.95 - _distance / _raceLen * 0.4) *
          (0.7 + _rnd.nextDouble() * 0.6);
      final lane = _rnd.nextInt(3);
      final roll = _rnd.nextDouble();
      final boost = roll < 0.08 && _distance > 120;
      final coin = !boost && roll < 0.32 + (_distance / _raceLen) * 0.18;
      _cars.add(_Racer(
          lane,
          -0.1,
          coin,
          boost,
          boost
              ? '⚡'
              : (coin ? '🪙' : _traffic[_rnd.nextInt(_traffic.length)])));
    }
    for (final c in _cars) {
      c.y += _speed * dt;
    }
    _cars.removeWhere((c) {
      if (c.y >= 0.78 && c.y <= 0.92 && c.lane == _lane) {
        if (c.boost) {
          _boostT = 3.5 + finishPush * 1.5;
          final pickup = 12 + (finishPush * 10).round();
          _score += pickup;
          TonePlayer.instance.playCue(SoundCue.success);
          // Layer the engine rev behind the success chime, same two-sound
          // pattern coin/bowling use, so a boost actually sounds like the
          // car accelerating, not just another generic pickup.
          TonePlayer.instance.playCue(SoundCue.engine);
          emit(ExperienceEvent.bubblePopped);
          _flash('⚡ Boost! +$pickup');
          _checkBeatBest();
          return true;
        }
        if (c.coin) {
          final pickup = 10 + (finishPush * 12).round();
          _score += pickup;
          TonePlayer.instance.playCue(SoundCue.coin);
          emit(ExperienceEvent.bubblePopped);
          _flash('💰 +$pickup');
          _checkBeatBest();
          return true;
        }
        if (_boostT > 0) {
          // Boosting barges traffic aside instead of losing pace.
          _score += 5;
          TonePlayer.instance.playCue(SoundCue.crash);
          _flash(_smashPool[_rnd.nextInt(_smashPool.length)]);
          _checkBeatBest();
          return true;
        }
        // A knock is not fatal: near the finish, it hurts more, but momentum is
        // restored quickly so the child never feels stuck in the middle of a race.
        _shuntT = 1.1 + finishPush * 0.35;
        final loss = 30 + (finishPush * 18).round();
        _distance = math.max(0, _distance - loss);
        TonePlayer.instance.playCue(SoundCue.crash);
        emit(ExperienceEvent.incorrectAnswer);
        _flash('Shunt! -${loss}m');
        return true;
      }
      return c.y > 1.05;
    });
  }

  void _finish() {
    _finishPlace = _place;
    // Only an actual 1st-place finish earns the shell's generic "🎉 You did
    // it!" win celebration; finishing P2-P4 is a real race result, not a
    // win, so it gets the honest "Finished P#" banner via GameStatus.over.
    _status = _finishPlace == 1 ? GameStatus.won : GameStatus.over;
    if (_status == GameStatus.won) {
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
    }
    _score += <int>[60, 30, 15, 5][(_finishPlace - 1).clamp(0, 3)];
    TonePlayer.instance
        .playCue(_finishPlace == 1 ? SoundCue.success : SoundCue.gameOver);
    emit(_finishPlace == 1
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 0.9;
  }

  // Takes priority over the boost/coin/barge flash just set by the caller —
  // a new all-time record is the bigger moment of the two. `_best` only
  // ever updates once, at `_finish`, so this is safe to compare against
  // throughout the whole race.
  void _checkBeatBest() {
    if (!_beatBest && _best > 0 && _score > _best) {
      _beatBest = true;
      _flash('New personal best! 🏆');
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
  }

  void _move(int delta) {
    if (_status != GameStatus.playing) return;
    setState(() => _lane = (_lane + delta).clamp(0, 2));
    TonePlayer.instance.playClick(pitch: 1.2);
  }

  // A racing game that only ever sounds like clicks, coins and crashes is
  // missing the one cue that actually says "car" — `SoundCue.engine` (a
  // buzzy stacked-sine rev synthesized specifically for this purpose in
  // tone_player.dart) was defined but never referenced anywhere in the whole
  // catalog. Give the race its own launch "vroom" at the green light,
  // mirroring quick_tap's readyGo chirp and bowling's roll-start cue.
  void _playStartVroom() {
    TonePlayer.instance.playCue(SoundCue.engine);
  }

  void _reset() {
    setState(() {
      _startRace();
      _status = GameStatus.playing;
    });
    _playStartVroom();
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    final remaining = (_raceLen - _distance).clamp(0, _raceLen);
    return _GameShell(
      title: '🏎️ Street Racer',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner ??
          (_boostT > 0
              ? '⚡ BOOST · P$_place'
              : 'P$_place/$_fieldSize · ${remaining.round()}m to flag'),
      // A finish is recorded as GameStatus.won only for an outright P1; P2-P4
      // finish as GameStatus.over, but both are a completed race, not a
      // "didn't finish" — show the real placing on the over screen, and the
      // shell's winText/winEmoji (not the hardcoded generic) carry the P1
      // trophy message on the won screen.
      overEmoji: '🏁',
      overText:
          _finishPlace > 0 ? 'Finished P$_finishPlace' : 'Race on!',
      winEmoji: '🏆',
      winText: _winPraise,
      accent: const Color(0xFFFF6B6B),
      introHow: 'Reach the 🏁 chequered flag ahead of 3 rivals.\n'
          'Tap left/right to change lanes, grab 🪙 coins and ⚡ boosts, '
          'and dodge traffic — late-race pickups are worth more, while a shunt '
          'costs pace without ending the race.',
      onStart: () {
        setState(() => _status = GameStatus.playing);
        _playStartVroom();
      },
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          // Finish line rolls into view over the final 150 m.
          final finishY =
              remaining <= 150 ? 0.08 + (1 - remaining / 150) * 0.72 : -1.0;
          return Semantics(
            label: 'P$_place of $_fieldSize. Move left or right to change '
                'lanes.',
            customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
              const CustomSemanticsAction(label: 'Move left'): () => _move(-1),
              const CustomSemanticsAction(label: 'Move right'): () => _move(1),
            },
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _move(d.localPosition.dx < w / 2 ? -1 : 1),
            onHorizontalDragEnd: (d) =>
                _move((d.primaryVelocity ?? 0) < 0 ? -1 : 1),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoadPainter(
                      _t * _speed,
                      progress: (_distance / _raceLen).clamp(0.0, 1.0),
                      finishY: finishY,
                    ),
                  ),
                ),
                // Rival racers, placed by how far ahead/behind us they are.
                for (var i = 0; i < _rivals.length; i++)
                  if (() {
                    final ry = 0.8 - (_rivals[i] - _distance) / 320;
                    return ry >= -0.02 && ry <= 0.95;
                  }())
                    Positioned(
                      left: _laneX3(_rivalLanePos[i]) * w - 22,
                      top: (0.8 - (_rivals[i] - _distance) / 320) * h - 26,
                      child: Opacity(
                        opacity: 0.9,
                        child: Transform.rotate(
                          // Bank into the lane change exactly like the
                          // player's own car, so an overtaking rival reads
                          // as actually steering, not just sliding sideways.
                          angle: (_rivalLane[i] - _rivalLanePos[i]) * 0.5,
                          child: const Text('🚘', style: TextStyle(fontSize: 42)),
                        ),
                      ),
                    ),
                for (final car in _cars)
                  Positioned(
                    left: _laneX[car.lane] * w - 24,
                    top: car.y * h - 28,
                    child:
                        Text(car.emoji, style: const TextStyle(fontSize: 44)),
                  ),
                Positioned(
                  left: _laneX3(_lanePos) * w - 26,
                  top: 0.8 * h,
                  child: Transform.rotate(
                    // Bank into the turn: tilt proportional to how far the
                    // eased position still has to travel to the target lane.
                    angle: (_lane - _lanePos) * 0.5,
                    child: const Text('🏎️', style: TextStyle(fontSize: 52)),
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.scroll, {this.progress = 0, this.finishY = -1});
  final double scroll;
  final double progress; // 0..1 down the track
  final double finishY; // normalized y of the finish line, or <0 if hidden

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF23262E));
    final dash = Paint()
      ..color = Colors.white54
      ..strokeWidth = 4;
    const period = 46.0;
    final off = (scroll * size.height) % period;
    for (final fx in <double>[1 / 3, 2 / 3]) {
      final x = size.width * fx;
      for (double y = -period + off; y < size.height; y += period) {
        canvas.drawLine(Offset(x, y + 8), Offset(x, y + 30), dash);
      }
    }

    // Chequered finish line sweeping down as we approach the flag.
    if (finishY >= 0) {
      final y = finishY * size.height;
      const cell = 22.0;
      final cols = (size.width / cell).ceil();
      for (var cx = 0; cx < cols; cx++) {
        final dark = cx.isEven;
        canvas.drawRect(
          Rect.fromLTWH(cx * cell, y - cell, cell, cell),
          Paint()..color = dark ? Colors.black : Colors.white,
        );
        canvas.drawRect(
          Rect.fromLTWH(cx * cell, y, cell, cell),
          Paint()..color = dark ? Colors.white : Colors.black,
        );
      }
    }

    // Slim progress bar down the right edge of the track.
    final barH = size.height * 0.6;
    final barTop = size.height * 0.2;
    final barX = size.width - 10;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX - 3, barTop, 6, barH), const Radius.circular(3)),
      Paint()..color = Colors.white24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(
              barX - 3, barTop + barH * (1 - progress), 6, barH * progress),
          const Radius.circular(3)),
      Paint()..color = const Color(0xFFFFD166),
    );
  }

  @override
  bool shouldRepaint(_RoadPainter oldDelegate) => true;
}

// ===========================================================================
// Bowling — a perspective ten-pin lane. Flick the ball up the lane to knock
// the pins down; toppling pins topple their neighbours for real strikes. Ten
// frames, with strike and spare bonuses.
// ===========================================================================
class BowlingGame extends StatefulWidget {
  const BowlingGame({super.key});
  @override
  State<BowlingGame> createState() => _BowlingGameState();
}

enum _BowlPhase { aim, rolling, settle }

class _BowlPin {
  _BowlPin(this.x, this.y);
  final double x; // normalized canvas x (0..1)
  final double y; // normalized canvas y (0..1); smaller = farther away
  bool down = false;
  double fallT = 0; // 0 = standing, grows to 1 while toppling
  double fallDir = 1; // topple direction (sign of x offset from ball)
}

class _BowlingGameState extends State<BowlingGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'bowling';

  // Lane geometry (normalized canvas). The lane is a trapezoid: narrow far
  // (pins) and wide near (foul line) to read as real perspective.
  static const double _yFar = 0.12; // back of the lane
  static const double _yFoul = 0.84; // where the ball starts
  static const double _farHalf = 0.13; // half-width of lane at the far end
  static const double _nearHalf = 0.30; // half-width of lane at the foul line

  final List<_BowlPin> _pins = <_BowlPin>[];
  final List<_Particle> _confetti = <_Particle>[];
  final math.Random _rnd = math.Random();
  // Pool of win phrases so a replaying child doesn't always see the same
  // "Great bowling!" line on win screen (across-restarts sibling of the
  // per-round praise-variety fixes applied elsewhere this sprint).
  static const List<String> _winPraisePool = <String>[
    'Great bowling!',
    'Perfect game feel!',
    'Pin-crushing champion!',
    'Strike master!',
  ];
  String _winPraise = _winPraisePool[0];
  _BowlPhase _phase = _BowlPhase.aim;
  double _ballX = 0.5;
  double _ballY = _yFoul;
  double _vx = 0;
  double _vy = 0;
  double _settleT = 0;

  int _frame = 1;
  int _ballInFrame = 1; // 1, 2, or (frame 10 only) 3
  // Real ten-pin rule: a strike or spare in the 10th frame earns bonus
  // ball(s) on a freshly-racked set of pins instead of ending the game early.
  bool _f10Bonus = false;
  int _pinsBeforeBall = 0; // standing pins when the current ball was thrown
  int _score = 0;
  int _best = 0;
  // Same pattern as FruitCatchGame/SnakeGame/RacingGame: the 10-frame total
  // only ever accumulates and `_best` is a prior full-game total, so the
  // instant the running total passes it is a genuine judgment-free win,
  // worth celebrating well before frame 10 actually ends the game.
  bool _beatBest = false;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // Sensory Settings' "Reduce motion" toggle only shortens Flutter's own
  // implicit animations/page transitions by default — the strike/spare
  // confetti burst below ignored it entirely, so it's read here and used
  // to thin (never fully silence) the burst.
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _rack();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  double _laneHalf(double y) {
    final t = ((y - _yFar) / (_yFoul - _yFar)).clamp(0.0, 1.0);
    return _farHalf + (_nearHalf - _farHalf) * t;
  }

  // Perspective scale: things near the foul line are big, far ones shrink.
  double _scaleFor(double y) {
    final t = ((y - _yFar) / (_yFoul - _yFar)).clamp(0.0, 1.0);
    return 0.5 + 0.5 * t;
  }

  void _rack() {
    _pins.clear();
    // Ten pins in a triangle. Apex (#1) nearest the bowler, back row farthest.
    const rowsY = <double>[0.30, 0.25, 0.20, 0.15];
    for (var row = 0; row < 4; row++) {
      final y = rowsY[row];
      final count = row + 1;
      final spread = _laneHalf(y) * 0.9;
      final startX = 0.5 - (count - 1) * spread / 3;
      for (var i = 0; i < count; i++) {
        _pins.add(_BowlPin(startX + i * spread / 3 * 2, y));
      }
    }
    _resetBall();
  }

  void _resetBall() {
    _ballX = 0.5;
    _ballY = _yFoul;
    _vx = 0;
    _vy = 0;
    _phase = _BowlPhase.aim;
  }

  int get _standing => _pins.where((p) => !p.down).length;

  // A burst of confetti at the pin deck — the strike/spare celebration a
  // text banner alone can't deliver. Rises and fans out, then fades.
  void _burst(Color color, {int count = 22}) {
    final effectiveCount =
        _reduceMotion ? math.max(4, (count / 3).round()) : count;
    for (var i = 0; i < effectiveCount; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.25 + _rnd.nextDouble() * 0.55;
      _confetti.add(_Particle(
          const Offset(0.5, 0.16),
          Offset(math.cos(a) * sp, math.sin(a) * sp - 0.3),
          color,
          0.7 + _rnd.nextDouble() * 0.5));
    }
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = _confetti.length - 1; i >= 0; i--) {
      final p = _confetti[i];
      p.pos += p.vel * dt;
      p.vel += const Offset(0, 0.9) * dt; // gentle gravity
      p.life -= dt;
      if (p.life <= 0) _confetti.removeAt(i);
    }
    // Advance any toppling pins.
    for (final p in _pins) {
      if (p.down && p.fallT < 1) p.fallT = (p.fallT + dt * 3.2).clamp(0.0, 1.0);
    }
    if (_phase != _BowlPhase.rolling) {
      if (_phase == _BowlPhase.settle) {
        _settleT -= dt;
        if (_settleT <= 0) _endBall();
      }
      return;
    }

    // Roll the ball up the lane with gentle friction and a soft curve.
    _ballX += _vx * dt;
    _ballY += _vy * dt;
    _vx *= (1 - dt * 0.6);
    _vy *= (1 - dt * 0.35);

    // Gutter: rode off the side of the lane.
    final half = _laneHalf(_ballY);
    if ((_ballX - 0.5).abs() > half) {
      _ballX = 0.5 + half * (_ballX > 0.5 ? 1 : -1);
      _vx = 0;
      _vy *= 0.4; // drags in the gutter
    }

    _checkPinHits();
    _propagateTopple();

    if (_ballY <= _yFar + 0.01 || _vy > -0.02) {
      _phase = _BowlPhase.settle;
      _settleT = 0.7; // let pins finish toppling before scoring
    }
  }

  void _checkPinHits() {
    for (final p in _pins) {
      if (p.down) continue;
      if ((p.x - _ballX).abs() < 0.05 && (p.y - _ballY).abs() < 0.055) {
        p.down = true;
        p.fallDir = (p.x >= _ballX) ? 1 : -1;
        _vx += p.fallDir * 0.04; // ball deflects a touch
        _vy *= 0.9;
        TonePlayer.instance.playThock();
      }
    }
  }

  // A toppling pin knocks over close standing neighbours — how strikes happen.
  // The rack's row spacing (see rowsY in _rack) is exactly 0.05, so a strict
  // `< 0.05` cutoff here lands right on a floating-point coin-flip: some row
  // pairs round down (propagate fine) and others round up (never propagate),
  // silently breaking the front-to-back chain reaction for roughly half the
  // pins. Use a visibly looser 0.052 so every genuine row-to-row neighbour
  // reliably topples regardless of rounding direction.
  void _propagateTopple() {
    for (var pass = 0; pass < 2; pass++) {
      for (final f in _pins) {
        if (!f.down) continue;
        for (final s in _pins) {
          if (s.down) continue;
          if ((s.x - f.x).abs() < 0.055 && (s.y - f.y).abs() < 0.052) {
            s.down = true;
            s.fallDir = (s.x >= f.x) ? 1 : -1;
            TonePlayer.instance.playThock();
          }
        }
      }
    }
  }

  void _throw(double vx, double vy) {
    if (_phase != _BowlPhase.aim || _status != GameStatus.playing) return;
    _pinsBeforeBall = _standing;
    // Always give a satisfying forward roll, even on a timid swipe.
    _vy = vy.clamp(-2.2, -0.85);
    _vx = vx.clamp(-0.6, 0.6);
    _phase = _BowlPhase.rolling;
    TonePlayer.instance.playCue(SoundCue.bowling);
  }

  void _endBall() {
    final knockedThisBall = _pinsBeforeBall - _standing;
    _score += knockedThisBall;
    final knockedAll = _standing == 0;
    final isFinalFrame = _frame == 10;

    if (_ballInFrame == 1) {
      if (knockedAll) {
        // Strike. A great in-run moment, but NOT the end of the 10-frame
        // game — the companion's full "You did it!" celebration is reserved
        // for actually finishing all 10 frames (see _nextFrame), so this
        // only fires the lighter big-positive-moment reaction.
        _score += 5;
        _flash('STRIKE! 🎳');
        _burst(const Color(0xFFFFD166));
        emit(ExperienceEvent.bubblePopped);
        TonePlayer.instance.playCue(SoundCue.completion);
        if (isFinalFrame) {
          // Earns two bonus balls on a fresh rack instead of ending the game.
          _f10Bonus = true;
          _ballInFrame = 2;
          _rack();
        } else {
          _nextFrame();
        }
      } else {
        // Second ball at the standing pins.
        _flash(knockedThisBall > 0 ? '$knockedThisBall down!' : 'Roll again');
        if (knockedThisBall > 0) emit(ExperienceEvent.correctAnswer);
        _ballInFrame = 2;
        _resetBall();
      }
    } else if (_ballInFrame == 2 && isFinalFrame && _f10Bonus) {
      // Bonus ball 2 after a 10th-frame strike: a 3rd ball always follows,
      // on a fresh rack if this one clears the lane too.
      if (knockedAll) {
        _score += 5;
        _flash('STRIKE! 🎳');
        _burst(const Color(0xFFFFD166));
        TonePlayer.instance.playCue(SoundCue.completion);
        _rack();
      } else {
        _flash(knockedThisBall > 0 ? '$knockedThisBall down!' : 'Roll again');
        _resetBall();
      }
      _ballInFrame = 3;
    } else if (_ballInFrame == 2 && knockedAll) {
      // Spare. Same reasoning as the strike above: a strong in-run moment,
      // not the actual end of the game, so it gets the lighter reaction.
      _score += 3;
      _flash('SPARE! ✨');
      _burst(const Color(0xFF7FE0FF));
      emit(ExperienceEvent.bubblePopped);
      TonePlayer.instance.playCue(SoundCue.completion);
      if (isFinalFrame) {
        // Earns one bonus ball on a fresh rack instead of ending the game.
        _f10Bonus = true;
        _ballInFrame = 3;
        _rack();
      } else {
        _nextFrame();
      }
    } else {
      // Ordinary closing ball: frame 10's non-bonus 2nd ball, or any bonus
      // ball 3 — both always end the game.
      _flash(knockedThisBall > 0 ? '$knockedThisBall down!' : 'Good try');
      _nextFrame();
    }
    // Takes priority over whichever flash was just set above — a new
    // all-time running total is the bigger moment of the two.
    _checkBeatBest();
    setState(() {});
  }

  void _nextFrame() {
    if (_frame >= 10) {
      _status = GameStatus.won;
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
      // The real end of the 10-frame game: this is the one moment that
      // should earn the companion's full "You did it!" celebration, not the
      // individual strikes/spares along the way.
      emit(ExperienceEvent.gameCompleted);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      return;
    }
    _frame++;
    _ballInFrame = 1;
    _f10Bonus = false;
    _rack();
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  void _checkBeatBest() {
    if (!_beatBest && _best > 0 && _score > _best) {
      _beatBest = true;
      _flash('New personal best! 🏆');
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
  }

  void _start() {
    setState(() => _status = GameStatus.playing);
  }

  void _reset() {
    setState(() {
      _score = 0;
      _beatBest = false;
      _frame = 1;
      _ballInFrame = 1;
      _f10Bonus = false;
      _banner = null;
      _bannerT = 0;
      _confetti.clear();
      _status = GameStatus.playing;
      _rack();
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _GameShell(
      title: '🎳 Ten-Pin Bowling',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      winEmoji: '🎳',
      winText: _winPraise,
      accent: const Color(0xFF4CC9F0),
      introHow: 'Flick the ball up the lane to knock the pins down.\n'
          'Ten frames — go for a STRIKE!',
      onStart: _start,
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          if (_phase != _BowlPhase.aim || _status != GameStatus.playing) return;
          // Slide the ball across the foul line to aim while dragging.
          final box = context.size;
          if (box == null) return;
          final nx = (d.localPosition.dx / box.width).clamp(0.0, 1.0);
          final half = _laneHalf(_yFoul);
          setState(() => _ballX = nx.clamp(0.5 - half, 0.5 + half).toDouble());
        },
        onPanEnd: (d) {
          if (_phase != _BowlPhase.aim || _status != GameStatus.playing) return;
          final box = context.size;
          final h = box?.height ?? 600;
          final w = box?.width ?? 400;
          // Convert the flick velocity (px/s) into normalized lane velocity.
          final vy =
              -(d.velocity.pixelsPerSecond.dy.abs() / h).clamp(0.85, 2.2) - 0.2;
          final vx = (d.velocity.pixelsPerSecond.dx / w).clamp(-0.6, 0.6);
          _throw(vx, vy.toDouble());
        },
        onTap: () {
          // A plain tap still bowls straight, so it is never a dead end.
          if (_phase == _BowlPhase.aim) _throw(0, -1.4);
        },
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _BowlPainter(
                  pins: _pins,
                  ballX: _ballX,
                  ballY: _ballY,
                  phase: _phase,
                  laneHalf: _laneHalf,
                  scaleFor: _scaleFor,
                  yFar: _yFar,
                  yFoul: _yFoul,
                  confetti: _confetti,
                ),
                size: Size.infinite,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _phase == _BowlPhase.aim
                        ? (_frame == 10 && _f10Bonus
                            ? 'Bonus ball!  ·  Flick the ball up ⬆'
                            : 'Frame $_frame/10  ·  Flick the ball up ⬆')
                        : 'Frame $_frame/10  ·  Rolling…',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BowlPainter extends CustomPainter {
  _BowlPainter({
    required this.pins,
    required this.ballX,
    required this.ballY,
    required this.phase,
    required this.laneHalf,
    required this.scaleFor,
    required this.yFar,
    required this.yFoul,
    required this.confetti,
  });
  final List<_BowlPin> pins;
  final double ballX;
  final double ballY;
  final _BowlPhase phase;
  final double Function(double) laneHalf;
  final double Function(double) scaleFor;
  final double yFar;
  final double yFoul;
  final List<_Particle> confetti;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Backdrop.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF141034), Color(0xFF241A46)],
          ).createShader(Offset.zero & size));

    double sx(double x) => x * w;
    double sy(double y) => y * h;

    // Perspective lane (trapezoid) with gutters.
    final farL = 0.5 - laneHalf(yFar), farR = 0.5 + laneHalf(yFar);
    final nearL = 0.5 - laneHalf(yFoul), nearR = 0.5 + laneHalf(yFoul);
    final topY = sy(yFar - 0.04), botY = sy(yFoul + 0.12);
    // Gutters.
    final gutter = Paint()..color = const Color(0xFF0C0A1E);
    canvas.drawPath(
        Path()
          ..moveTo(sx(farL) - 8, topY)
          ..lineTo(sx(nearL) - 22, botY)
          ..lineTo(sx(nearL), botY)
          ..lineTo(sx(farL), topY)
          ..close(),
        gutter);
    canvas.drawPath(
        Path()
          ..moveTo(sx(farR) + 8, topY)
          ..lineTo(sx(nearR) + 22, botY)
          ..lineTo(sx(nearR), botY)
          ..lineTo(sx(farR), topY)
          ..close(),
        gutter);
    // Lane surface.
    final lane = Path()
      ..moveTo(sx(farL), topY)
      ..lineTo(sx(farR), topY)
      ..lineTo(sx(nearR), botY)
      ..lineTo(sx(nearL), botY)
      ..close();
    canvas.drawPath(
        lane,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFB07B3E), Color(0xFFE7C088)],
          ).createShader(Rect.fromLTRB(0, topY, w, botY)));
    // Lane boards (perspective lines).
    canvas.save();
    canvas.clipPath(lane);
    final board = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1.5;
    for (var i = 1; i < 8; i++) {
      final t = i / 8;
      canvas.drawLine(Offset(sx(farL + (farR - farL) * t), topY),
          Offset(sx(nearL + (nearR - nearL) * t), botY), board);
    }
    // Aiming arrows near the foul line.
    final arrow = Paint()..color = const Color(0xFF8A5A24).withOpacity(0.8);
    for (var i = -2; i <= 2; i++) {
      final ax = sx(0.5 + i * 0.05);
      final ay = sy(0.62);
      canvas.drawPath(
          Path()
            ..moveTo(ax, ay - 10)
            ..lineTo(ax - 5, ay + 6)
            ..lineTo(ax + 5, ay + 6)
            ..close(),
          arrow);
    }
    canvas.restore();

    // Foul line.
    canvas.drawLine(
        Offset(sx(nearL), sy(yFoul)),
        Offset(sx(nearR), sy(yFoul)),
        Paint()
          ..color = const Color(0xFFEF476F)
          ..strokeWidth = 3);

    // Dashed aim guide, dragged ball-side first, up toward the pin deck —
    // `phase` used to be threaded all the way into this painter and never
    // actually read, so aiming (the single most important moment in
    // bowling) had no visual guide at all: a child dragging the ball left
    // or right had no way to see where their flick was about to send it
    // until the ball was already rolling.
    if (phase == _BowlPhase.aim) {
      final guide = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..strokeWidth = 3;
      const dash = 12.0, gap = 9.0;
      final guideTop = sy(yFar + 0.03);
      var y = sy(yFoul) - 6;
      while (y - dash > guideTop) {
        canvas.drawLine(
            Offset(sx(ballX), y), Offset(sx(ballX), y - dash), guide);
        y -= dash + gap;
      }
    }

    // Pins (painter order: far first so near pins overlap).
    final sorted = List<_BowlPin>.from(pins)
      ..sort((a, b) => a.y.compareTo(b.y));
    for (final p in sorted) {
      final c = Offset(sx(p.x), sy(p.y));
      final s = scaleFor(p.y);
      if (p.down) {
        // Toppled pin: lie down + fade.
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(p.fallDir * p.fallT * 1.4);
        final o = (1 - p.fallT * 0.7);
        _drawPin(canvas, Offset.zero, s, o);
        canvas.restore();
      } else {
        _drawPin(canvas, c, s, 1);
      }
    }

    // Ball with perspective scaling and a rolling highlight.
    final bs = scaleFor(ballY);
    final bc = Offset(sx(ballX), sy(ballY));
    final br = 22 * bs;
    canvas.drawCircle(bc.translate(0, br * 0.5), br * 0.9,
        Paint()..color = Colors.black.withOpacity(0.28));
    canvas.drawCircle(
        bc,
        br,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: const <Color>[Color(0xFF7FE0FF), Color(0xFF1B4A8A)],
          ).createShader(Rect.fromCircle(center: bc, radius: br)));
    canvas.drawCircle(bc.translate(-br * 0.3, -br * 0.3), br * 0.18,
        Paint()..color = Colors.white.withOpacity(0.85));

    // Strike/spare confetti burst at the pin deck.
    for (final p in confetti) {
      final k = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(sx(p.pos.dx), sy(p.pos.dy)), 2.5 + 3.5 * k,
          Paint()..color = p.color.withOpacity(k));
    }
  }

  void _drawPin(Canvas canvas, Offset c, double s, double opacity) {
    final body = Paint()..color = Colors.white.withOpacity(opacity);
    final neck = Paint()..color = const Color(0xFFEF476F).withOpacity(opacity);
    final ph = 30.0 * s, pw = 15.0 * s;
    // Shadow.
    canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(0, ph * 0.5),
            width: pw * 1.1,
            height: pw * 0.4),
        Paint()..color = Colors.black.withOpacity(0.2 * opacity));
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: pw, height: ph),
        Radius.circular(pw * 0.5));
    canvas.drawRRect(r, body);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c.translate(0, -ph * 0.28),
                width: pw,
                height: ph * 0.22),
            Radius.circular(pw * 0.3)),
        neck);
  }

  @override
  bool shouldRepaint(_BowlPainter oldDelegate) => true;
}
