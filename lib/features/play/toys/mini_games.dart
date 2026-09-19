import 'dart:math' as math;

import 'package:flutter/material.dart';
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
class _GameShell extends StatelessWidget {
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
  final VoidCallback onPlayAgain;
  final Widget child;
  final Color accent;

  /// One short line telling a child exactly what to do — shown on the start
  /// card so the objective is clear before the first tap.
  final String? introHow;

  /// Called when the child presses the big Start button on the intro card.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final scoreText = target != null ? '$score / $target' : '$score';
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
                      child: Text(
                        banner!,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
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
                    Text(status == GameStatus.won ? '🎉' : overEmoji,
                        style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: 8),
                    Text(
                      status == GameStatus.won ? 'You did it!' : overText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      best > 0 ? 'Score $score   ·   Best $best' : 'Score $score',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    if (score > 0 && score >= best) ...<Widget>[
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
                          introHow!,
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
                      onPressed: onStart == null
                          ? null
                          : () {
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
  static const List<String> _fruits = <String>['🍓', '🍎', '🍌', '🍇', '🍊', '🍑'];
  static const int _target = 18;
  final math.Random _rnd = math.Random();
  final List<_Faller> _items = <_Faller>[];
  double _basketX = 0.5;
  double _spawnIn = 0.6;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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
    final speed = 0.28 +
        _rnd.nextDouble() * 0.16 +
        _score * 0.006 +
        (kind == 1 ? 0.12 : 0);
    _items.add(_Faller(0.08 + _rnd.nextDouble() * 0.84, -0.05, speed, emoji, kind));
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.32, 0.7 - _score * 0.01) *
          (0.7 + _rnd.nextDouble() * 0.6);
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
        if (f.kind != 2) _combo = 0;
        return true;
      }
      return false;
    });
  }

  void _onCatch(_Faller f) {
    if (f.kind == 2) {
      _combo = 0;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _flash('Oops! Dodge bombs');
      return;
    }
    _combo++;
    final gain = (f.kind == 1 ? 3 : 1) + (_combo >= 3 ? 1 : 0);
    _score += gain;
    TonePlayer.instance.playCue(SoundCue.fruit);
    emit(ExperienceEvent.bubblePopped);
    if (f.kind == 1) {
      _flash('Bonus +3!');
    } else if (_combo >= 3) {
      _flash('Combo x$_combo!');
    }
    if (_score >= _target) _end(GameStatus.won);
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.1;
  }

  void _end(GameStatus s) {
    _status = s;
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
      _score = 0;
      _combo = 0;
      _banner = null;
      _bannerT = 0;
      _spawnIn = 0.6;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    return _GameShell(
      title: '🧺 Catch',
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
                      child: Text(f.emoji,
                          style: const TextStyle(fontSize: 40)),
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
    Color(0xFFEF476F), Color(0xFFFFD166), Color(0xFF06D6A0),
    Color(0xFF118AB2), Color(0xFF9B5DE5),
  ];
  static const int _target = 20;
  final math.Random _rnd = math.Random();
  final List<_Balloon> _items = <_Balloon>[];
  double _spawnIn = 0.4;
  double _t = 0;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.3, 0.6 - _score * 0.008) *
          (0.7 + _rnd.nextDouble() * 0.6);
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
          0.16 + _rnd.nextDouble() * 0.12 + _score * 0.004 + (kind == 1 ? 0.1 : 0),
          _rnd.nextDouble() * 6.28,
          color,
          kind));
    }
    for (final b in _items) {
      b.y -= b.vy * dt;
    }
    _items.removeWhere((b) {
      if (b.y < -0.1) {
        if (b.kind != 2) _combo = 0;
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
        _items.removeAt(i);
        if (b.kind == 2) {
          _combo = 0;
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
          _flash('Oops! Avoid bombs');
          return;
        }
        _combo++;
        _score += (b.kind == 1 ? 3 : 1) + (_combo >= 4 ? 1 : 0);
        TonePlayer.instance.playCue(SoundCue.balloon);
        emit(ExperienceEvent.bubblePopped);
        if (b.kind == 1) {
          _flash('Bonus +3!');
        } else if (_combo >= 4) {
          _flash('Combo x$_combo!');
        }
        if (_score >= _target) _end(GameStatus.won);
        return;
      }
    }
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.1;
  }

  void _end(GameStatus s) {
    _status = s;
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
      _score = 0;
      _combo = 0;
      _banner = null;
      _bannerT = 0;
      _spawnIn = 0.4;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    return _GameShell(
      title: '🎈 Pop',
      introHow: 'Tap the balloons to pop them. Pop fast for combos!',
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
          return GestureDetector(
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
                ],
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
          child: Text(kind == 1 ? '✨' : kind == 2 ? '💣' : '',
              style: const TextStyle(fontSize: 22)),
        ),
        Container(width: 2, height: 18, color: Colors.white24),
      ],
    );
  }
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
  final math.Random _rnd = math.Random();
  int _active = 0;
  int _kind = 0; // 0 = normal star, 1 = gold shooting star (worth 3)
  double _life = 0;
  double _lifeMax = 1.6;
  double _t = 0;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  final List<_StarPop> _pops = <_StarPop>[];
  final List<Offset> _bgStars = <Offset>[];
  GameStatus _status = GameStatus.ready;

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

  void _spawnStar() {
    _active = _rnd.nextInt(_cells);
    _kind = _rnd.nextDouble() < 0.22 ? 1 : 0;
    // Gold stars are faster; everything speeds up as the score climbs.
    _lifeMax = math.max(0.6, (1.5 - _score * 0.05)) * (_kind == 1 ? 0.7 : 1);
    _life = _lifeMax;
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
    _pops.removeWhere((p) => p.t <= 0);
    _life -= dt;
    if (_life <= 0) {
      _combo = 0; // missed — the star faded away
      _spawnStar();
    }
  }

  void _tapCell(int i) {
    if (_status != GameStatus.playing) return;
    if (i == _active) {
      _combo++;
      final gain = (_kind == 1 ? 3 : 1) + (_combo >= 5 ? 1 : 0);
      _score += gain;
      _pops.add(_StarPop(i, '+$gain'));
      TonePlayer.instance
          .playCue(_kind == 1 ? SoundCue.coin : SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      if (_kind == 1) {
        _flash('Shooting star +3!');
      } else if (_combo >= 5) {
        _flash('Combo x$_combo!');
      }
      if (_score >= _target) {
        _end(GameStatus.won);
        return;
      }
      setState(_spawnStar);
    } else {
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
    emit(ExperienceEvent.gameCompleted);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _reset() {
    setState(() {
      _score = 0;
      _combo = 0;
      _banner = null;
      _bannerT = 0;
      _pops.clear();
      _status = GameStatus.playing;
      _spawnStar();
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    return _GameShell(
      title: '⭐ Star Catch',
      introHow: 'Tap the glowing star as fast as you can!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: _NightSkyPainter(_bgStars, _t)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 92, 24, 40),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (var i = 0; i < _cells; i++)
                  GestureDetector(
                    onTapDown: (_) => _tapCell(i),
                    child: _StarCell(
                      active: i == _active,
                      kind: _kind,
                      lifeFraction: _lifeMax > 0 ? (_life / _lifeMax) : 0,
                      pop: _popFor(i),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
  });
  final bool active;
  final int kind;
  final double lifeFraction;
  final _StarPop? pop;

  @override
  Widget build(BuildContext context) {
    final gold = kind == 1;
    final glow = gold ? const Color(0xFFFFE066) : const Color(0xFFFFD166);
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
                ? <BoxShadow>[BoxShadow(color: glow.withOpacity(0.55), blurRadius: 26)]
                : const <BoxShadow>[],
          ),
        ),
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
          Text(gold ? '🌟' : '⭐', style: const TextStyle(fontSize: 42)),
        ],
        if (pop != null)
          Transform.translate(
            offset: Offset(0, -22 * (1 - pop!.t / 0.7) - 6),
            child: Opacity(
              opacity: pop!.t.clamp(0.0, 0.7) / 0.7,
              child: Text(pop!.text,
                  style: TextStyle(
                      color: glow,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}

/// A slow, twinkling night sky with a soft moon — Star Catch's own backdrop.
class _NightSkyPainter extends CustomPainter {
  _NightSkyPainter(this.stars, this.t);
  final List<Offset> stars;
  final double t;

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
    canvas.drawCircle(moon, 42,
        Paint()..color = const Color(0xFFFFF3C4).withOpacity(0.16));
    canvas.drawCircle(moon, 22, Paint()..color = const Color(0xFFFDF6D8));
    // Twinkling background stars.
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 2 + i));
      canvas.drawCircle(
          Offset(s.dx * size.width, s.dy * size.height),
          1.4 + tw,
          Paint()..color = Colors.white.withOpacity(0.25 + 0.4 * tw));
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

class _SnakeGameState extends State<SnakeGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'snake';
  static const int _targetScore = 30;
  static const double _arenaR = 900;
  static const double _spacing = 2.6; // path sample distance
  static const double _seg = 8; // body segment spacing
  static const double _baseSpeed = 165;
  final math.Random _rnd = math.Random();

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
  int _score = 0;
  int _best = 0;
  int _combo = 0;
  double _comboT = 0;
  double _bannerT = 0;
  String? _banner;
  String _overReason = 'Stay inside the glowing edge.';
  Size _view = const Size(360, 640);
  GameStatus _status = GameStatus.ready;

  static const List<Color> _orbColors = <Color>[
    Color(0xFFFF4D6D), Color(0xFFFFD166), Color(0xFF06D6A0),
    Color(0xFF4CC9F0), Color(0xFF9B5DE5), Color(0xFFFF9E00),
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
    _combo = 0;
    _comboT = 0;
    _orbs.clear();
    for (var i = 0; i < 240; i++) {
      _orbs.add(_randomOrb());
    }
    _ai.clear();
    for (var i = 0; i < 5; i++) {
      _ai.add(_spawnAiWorm());
    }
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
          const Color(0xFFFFE066), 7.0 + _rnd.nextDouble() * 2, golden: true);
    }
    return _Orb(Offset(math.cos(a) * d, math.sin(a) * d),
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
        _orbs.removeAt(i);
        // Rapid, back-to-back eating builds a combo that fades if you pause.
        _combo = _comboT > 0 ? _combo + 1 : 1;
        _comboT = 1.4;
        final comboBonus = _combo >= 3 ? 1 : 0;
        if (golden) {
          _length += 5;
          _score += 3 + comboBonus;
          _flash(_combo >= 3 ? 'Golden! Combo x$_combo' : 'Golden! +3');
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
        _ai.removeAt(wi);
        _ai.add(_spawnAiWorm());
        _score += 3;
        _flash('Snake down! +3');
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
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
    for (final w in _ai) {
      w.turnTimer -= dt;
      if (w.turnTimer <= 0) {
        w.turnTimer = 0.6 + _rnd.nextDouble() * 1.4;
        w.target = w.angle + (_rnd.nextDouble() - 0.5) * 1.6;
      }
      if (w.head.distance > _arenaR * 0.86) {
        w.target = math.atan2(-w.head.dy, -w.head.dx);
      }
      double d = w.target - w.angle;
      while (d > math.pi) d -= math.pi * 2;
      while (d < -math.pi) d += math.pi * 2;
      w.angle += d.clamp(-2.4 * dt, 2.4 * dt);
      w.head += Offset(math.cos(w.angle), math.sin(w.angle)) * 120 * dt;
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

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.1;
  }

  void _finish(GameStatus status) {
    final prev = GameScores.instance.best(_id);
    _status = status;
    TonePlayer.instance.playCue(
        status == GameStatus.won ? SoundCue.success : SoundCue.gameOver);
    emit(status == GameStatus.won || _score > prev
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _gameOver() => _finish(GameStatus.over);

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
    return _GameShell(
      title: '🐍 Snake · Orbs',
      score: _score,
      best: _best,
      target: _targetScore,
      status: _status,
      banner: _banner,
      overEmoji: '🐍',
      overText: _overReason,
      accent: const Color(0xFF06D6A0),
      introHow: 'Glide your snake to eat glowing orbs and grow.\n'
          'Gold orbs = bonus. Avoid the edges and rival snakes!',
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
                      _orbs, _ai, _arenaR, _t),
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
                    child: const Icon(
                        Icons.keyboard_double_arrow_up_rounded,
                        color: Colors.white,
                        size: 40),
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
              child: Text(
                    '${i + 1}  ${rivals[i].key}  ${rivals[i].value}',
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
      this.orbs, this.ai, this.arenaR, this.t);
  final Offset head;
  final double angle;
  final List<Offset> path;
  final int length;
  final double seg;
  final List<_Orb> orbs;
  final List<_AiWorm> ai;
  final double arenaR;
  final double t;

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
            ..maskFilter = MaskFilter.blur(
                BlurStyle.normal, o.golden ? 8 : 4));
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
  final math.Random _rnd = math.Random();
  final List<_Racer> _cars = <_Racer>[];
  int _lane = 1;
  double _spawnIn = 0.9;
  double _t = 0;
  double _aliveAcc = 0;
  double _speed = 0.55;
  double _boostT = 0;
  int _score = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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
    if (_boostT > 0) _boostT -= dt;
    _speed = 0.55 + _score * 0.003;
    _aliveAcc += dt;
    if (_aliveAcc >= 0.6) {
      _aliveAcc -= 0.6;
      _score += _boostT > 0 ? 2 : 1;
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.5, 1.0 - _score * 0.004) *
          (0.7 + _rnd.nextDouble() * 0.6);
      final lane = _rnd.nextInt(3);
      final roll = _rnd.nextDouble();
      final boost = roll < 0.08;
      final coin = !boost && roll < 0.38;
      _cars.add(_Racer(lane, -0.1, coin, boost,
          boost ? '⚡' : (coin ? '🪙' : _traffic[_rnd.nextInt(_traffic.length)])));
    }
    for (final c in _cars) {
      c.y += _speed * dt;
    }
    _cars.removeWhere((c) {
      if (c.y >= 0.78 && c.y <= 0.92 && c.lane == _lane) {
        if (c.boost) {
          _boostT = 4.0;
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.bubblePopped);
          _flash('⚡ Boost!');
          return true;
        }
        if (c.coin) {
          _score += 5;
          TonePlayer.instance.playCue(SoundCue.coin);
          emit(ExperienceEvent.bubblePopped);
          _flash('+5 coin!');
          return true;
        }
        if (_boostT > 0) {
          // Boosting smashes through traffic instead of crashing.
          _score += 2;
          TonePlayer.instance.playCue(SoundCue.crash);
          _flash('Smash! +2');
          return true;
        }
        _crash();
        return true;
      }
      return c.y > 1.05;
    });
  }

  void _crash() {
    final prev = GameScores.instance.best(_id);
    _status = GameStatus.over;
    TonePlayer.instance.playCue(SoundCue.crash);
    emit(_score > prev
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

  void _move(int delta) {
    if (_status != GameStatus.playing) return;
    setState(() => _lane = (_lane + delta).clamp(0, 2));
    TonePlayer.instance.playClick(pitch: 1.2);
  }

  void _reset() {
    setState(() {
      _cars.clear();
      _lane = 1;
      _score = 0;
      _speed = 0.55;
      _boostT = 0;
      _spawnIn = 0.9;
      _aliveAcc = 0;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    return _GameShell(
      title: '🏎️ Street Racer',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner ?? (_boostT > 0 ? '⚡ BOOST' : null),
      overEmoji: '🏁',
      overText: 'Crash!',
      accent: const Color(0xFFFF6B6B),
      introHow: 'Tap left or right to switch lanes.\n'
          'Dodge traffic, grab 🪙 coins and ⚡ boosts!',
      onStart: () => setState(() => _status = GameStatus.playing),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _move(d.localPosition.dx < w / 2 ? -1 : 1),
            onHorizontalDragEnd: (d) =>
                _move((d.primaryVelocity ?? 0) < 0 ? -1 : 1),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                    child: CustomPaint(painter: _RoadPainter(_t * _speed))),
                for (final car in _cars)
                  Positioned(
                    left: _laneX[car.lane] * w - 24,
                    top: car.y * h - 28,
                    child: Text(car.emoji,
                        style: const TextStyle(fontSize: 44)),
                  ),
                Positioned(
                  left: _laneX[_lane] * w - 26,
                  top: 0.8 * h,
                  child: const Text('🏎️', style: TextStyle(fontSize: 52)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.scroll);
  final double scroll;

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
  _BowlPhase _phase = _BowlPhase.aim;
  double _ballX = 0.5;
  double _ballY = _yFoul;
  double _vx = 0;
  double _vy = 0;
  double _settleT = 0;

  int _frame = 1;
  int _ballInFrame = 1; // 1 or 2
  int _pinsBeforeBall = 0; // standing pins when the current ball was thrown
  int _score = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
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
  void _propagateTopple() {
    for (var pass = 0; pass < 2; pass++) {
      for (final f in _pins) {
        if (!f.down) continue;
        for (final s in _pins) {
          if (s.down) continue;
          if ((s.x - f.x).abs() < 0.055 && (s.y - f.y).abs() < 0.05) {
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
    if (_ballInFrame == 1 && knockedAll) {
      // Strike.
      _score += 5;
      _flash('STRIKE! 🎳');
      emit(ExperienceEvent.gameCompleted);
      TonePlayer.instance.playCue(SoundCue.completion);
      _nextFrame();
    } else if (_ballInFrame == 2 && knockedAll) {
      // Spare.
      _score += 3;
      _flash('SPARE! ✨');
      emit(ExperienceEvent.gameCompleted);
      TonePlayer.instance.playCue(SoundCue.completion);
      _nextFrame();
    } else if (_ballInFrame == 1) {
      // Second ball at the standing pins.
      _flash(knockedThisBall > 0 ? '$knockedThisBall down!' : 'Roll again');
      if (knockedThisBall > 0) emit(ExperienceEvent.correctAnswer);
      _ballInFrame = 2;
      _resetBall();
    } else {
      _flash(knockedThisBall > 0 ? '$knockedThisBall down!' : 'Good try');
      _nextFrame();
    }
    setState(() {});
  }

  void _nextFrame() {
    if (_frame >= 10) {
      _status = GameStatus.won;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      return;
    }
    _frame++;
    _ballInFrame = 1;
    _rack();
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  void _start() {
    setState(() => _status = GameStatus.playing);
  }

  void _reset() {
    setState(() {
      _score = 0;
      _frame = 1;
      _ballInFrame = 1;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
      _rack();
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    return _GameShell(
      title: '🎳 Ten-Pin Bowling',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🎳',
      overText: 'Great bowling!',
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
          setState(() =>
              _ballX = nx.clamp(0.5 - half, 0.5 + half).toDouble());
        },
        onPanEnd: (d) {
          if (_phase != _BowlPhase.aim || _status != GameStatus.playing) return;
          final box = context.size;
          final h = box?.height ?? 600;
          final w = box?.width ?? 400;
          // Convert the flick velocity (px/s) into normalized lane velocity.
          final vy = -(d.velocity.pixelsPerSecond.dy.abs() / h)
                  .clamp(0.85, 2.2) -
              0.2;
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
                        ? 'Frame $_frame/10  ·  Flick the ball up ⬆'
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
  });
  final List<_BowlPin> pins;
  final double ballX;
  final double ballY;
  final _BowlPhase phase;
  final double Function(double) laneHalf;
  final double Function(double) scaleFor;
  final double yFar;
  final double yFoul;

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
      canvas.drawLine(
          Offset(sx(farL + (farR - farL) * t), topY),
          Offset(sx(nearL + (nearR - nearL) * t), botY),
          board);
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
    canvas.drawLine(Offset(sx(nearL), sy(yFoul)), Offset(sx(nearR), sy(yFoul)),
        Paint()
          ..color = const Color(0xFFEF476F)
          ..strokeWidth = 3);

    // Pins (painter order: far first so near pins overlap).
    final sorted = List<_BowlPin>.from(pins)..sort((a, b) => a.y.compareTo(b.y));
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
    canvas.drawCircle(bc.translate(0, br * 0.5),
        br * 0.9, Paint()..color = Colors.black.withOpacity(0.28));
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
  }

  void _drawPin(Canvas canvas, Offset c, double s, double opacity) {
    final body = Paint()..color = Colors.white.withOpacity(opacity);
    final neck = Paint()..color = const Color(0xFFEF476F).withOpacity(opacity);
    final ph = 30.0 * s, pw = 15.0 * s;
    // Shadow.
    canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(0, ph * 0.5), width: pw * 1.1, height: pw * 0.4),
        Paint()..color = Colors.black.withOpacity(0.2 * opacity));
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: pw, height: ph),
        Radius.circular(pw * 0.5));
    canvas.drawRRect(r, body);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c.translate(0, -ph * 0.28), width: pw, height: ph * 0.22),
            Radius.circular(pw * 0.3)),
        neck);
  }

  @override
  bool shouldRepaint(_BowlPainter oldDelegate) => true;
}
