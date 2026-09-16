import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/toy/toy_ticker.dart';
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

enum GameStatus { playing, won, over }

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

  @override
  Widget build(BuildContext context) {
    final scoreText = target != null ? '$score / $target' : '$score';
    return Stack(
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
        if (status != GameStatus.playing)
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
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}


// ===========================================================================
// Fruit Catch — drag the basket to catch falling fruit. Reach the target to
// win. Never punishes misses, so it stays gentle and encouraging.
// ===========================================================================
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
  GameStatus _status = GameStatus.playing;

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
  GameStatus _status = GameStatus.playing;

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
// Star Tap — a reaction game. One star glows at a time; tap it before it
// fades and a new one appears. Reach the target to win. Trains attention and
// quick response without any fail state.
// ===========================================================================
class StarTapGame extends StatefulWidget {
  const StarTapGame({super.key});
  @override
  State<StarTapGame> createState() => _StarTapGameState();
}

class _StarTapGameState extends State<StarTapGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'star_tap';
  static const int _target = 15;
  static const int _cells = 9;
  final math.Random _rnd = math.Random();
  int _active = 0;
  double _life = 0;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    _active = _rnd.nextInt(_cells);
    _life = 1.6;
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _life -= dt;
    if (_life <= 0) {
      _combo = 0; // missed — the star faded away
      _active = _rnd.nextInt(_cells);
      _life = math.max(0.7, 1.5 - _score * 0.05);
    }
  }

  void _tapCell(int i) {
    if (_status != GameStatus.playing) return;
    if (i == _active) {
      _combo++;
      _score += 1 + (_combo >= 5 ? 1 : 0);
      TonePlayer.instance.playCue(SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      if (_combo >= 5) _flash('Combo x$_combo!');
      if (_score >= _target) {
        _end(GameStatus.won);
        return;
      }
      setState(() {
        _active = _rnd.nextInt(_cells);
        _life = math.max(0.7, 1.5 - _score * 0.05);
      });
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
      _status = GameStatus.playing;
      _active = _rnd.nextInt(_cells);
      _life = 1.6;
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    return _GameShell(
      title: '⭐ Tap',
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0E1F3A), Color(0xFF13294B)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (var i = 0; i < _cells; i++)
                GestureDetector(
                  onTapDown: (_) => _tapCell(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: i == _active
                          ? const Color(0xFFFFD166)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: i == _active
                          ? <BoxShadow>[
                              const BoxShadow(
                                  color: Color(0xAAFFD166), blurRadius: 24)
                            ]
                          : const <BoxShadow>[],
                    ),
                    child: Center(
                      child: Text(
                        i == _active ? '⭐' : '',
                        style: const TextStyle(fontSize: 44),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Snake — a real, classic Snake. Steer with swipes or arrow keys; eat fruit to
// grow and speed up. Solid walls, your own body, rocks and roaming monster
// hunters all end the run — so it's a genuine challenge, with a gentle instant
// "Play again". Chase golden fruit for bonus points.
// ===========================================================================
class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});
  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeMonster {
  _SnakeMonster(this.pos);
  math.Point<int> pos;
}

class _SnakeGameState extends State<SnakeGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'snake';
  static const int _cols = 13;
  static const int _rows = 17;
  static const double _monsterStep = 0.34; // seconds between monster hops
  final math.Random _rnd = math.Random();
  List<math.Point<int>> _snake = <math.Point<int>>[];
  List<math.Point<int>> _prevSnake = <math.Point<int>>[];
  final Set<math.Point<int>> _obstacles = <math.Point<int>>{};
  final List<_SnakeMonster> _monsters = <_SnakeMonster>[];
  double _monsterAcc = 0;
  math.Point<int> _dir = const math.Point<int>(1, 0);
  math.Point<int> _nextDir = const math.Point<int>(1, 0);
  Offset _swipeAcc = Offset.zero;
  final FocusNode _focus = FocusNode();
  late math.Point<int> _food;
  int _foodKind = 0; // 0 = normal apple, 1 = golden bonus (time-limited)
  double _goldenT = 0;
  double _acc = 0;
  double _t = 0;
  double _step = 0.2;
  double _sinceEat = 0;
  int _score = 0;
  int _combo = 0;
  int _apples = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    _seed();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _seed() {
    const cy = _rows ~/ 2;
    _snake = <math.Point<int>>[
      math.Point<int>(6, cy),
      math.Point<int>(5, cy),
      math.Point<int>(4, cy),
      math.Point<int>(3, cy),
      math.Point<int>(2, cy),
    ];
    _prevSnake = List<math.Point<int>>.of(_snake);
    _dir = const math.Point<int>(1, 0);
    _nextDir = _dir;
    _obstacles.clear();
    _monsters.clear();
    _monsterAcc = 0;
    _foodKind = 0;
    _goldenT = 0;
    _placeFood();
  }

  void _placeFood({bool golden = false}) {
    math.Point<int> p;
    do {
      p = math.Point<int>(_rnd.nextInt(_cols), _rnd.nextInt(_rows));
    } while (_snake.contains(p) ||
        _obstacles.contains(p) ||
        _monsters.any((m) => m.pos == p));
    _food = p;
    _foodKind = golden ? 1 : 0;
    _goldenT = golden ? 5.0 : 0;
  }

  void _spawnMonster() {
    final head = _snake.first;
    math.Point<int> p;
    var tries = 0;
    do {
      p = math.Point<int>(_rnd.nextInt(_cols), _rnd.nextInt(_rows));
      tries++;
    } while ((_snake.contains(p) ||
            _obstacles.contains(p) ||
            p == _food ||
            _monsters.any((m) => m.pos == p) ||
            (p.x - head.x).abs() + (p.y - head.y).abs() < 5) &&
        tries < 60);
    if (tries < 60) _monsters.add(_SnakeMonster(p));
  }

  // Monsters hunt the snake: mostly step toward the head, sometimes wander.
  void _moveMonsters() {
    final head = _snake.first;
    const dirs = <math.Point<int>>[
      math.Point<int>(1, 0),
      math.Point<int>(-1, 0),
      math.Point<int>(0, 1),
      math.Point<int>(0, -1),
    ];
    for (final m in _monsters) {
      final options = <math.Point<int>>[];
      for (final d in dirs) {
        final np = math.Point<int>(m.pos.x + d.x, m.pos.y + d.y);
        if (np.x < 0 || np.x >= _cols || np.y < 0 || np.y >= _rows) continue;
        if (_obstacles.contains(np)) continue;
        if (_monsters.any((o) => o != m && o.pos == np)) continue;
        options.add(np);
      }
      if (options.isEmpty) continue;
      math.Point<int> choice;
      if (_rnd.nextDouble() < 0.62) {
        options.sort((a, b) =>
            ((a.x - head.x).abs() + (a.y - head.y).abs()) -
            ((b.x - head.x).abs() + (b.y - head.y).abs()));
        choice = options.first;
      } else {
        choice = options[_rnd.nextInt(options.length)];
      }
      m.pos = choice;
      if (_snake.contains(choice)) {
        _gameOver();
        return;
      }
    }
  }

  void _addObstacle() {
    math.Point<int> p;
    var tries = 0;
    do {
      p = math.Point<int>(_rnd.nextInt(_cols), _rnd.nextInt(_rows));
      tries++;
    } while ((_snake.contains(p) ||
            _obstacles.contains(p) ||
            p == _food ||
            (p.x - _snake.first.x).abs() + (p.y - _snake.first.y).abs() < 3) &&
        tries < 40);
    if (tries < 40) _obstacles.add(p);
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _sinceEat += dt;
    if (_foodKind == 1) {
      _goldenT -= dt;
      if (_goldenT <= 0) _placeFood();
    }
    if (_monsters.isNotEmpty) {
      _monsterAcc += dt;
      while (_monsterAcc >= _monsterStep) {
        _monsterAcc -= _monsterStep;
        _moveMonsters();
        if (_status != GameStatus.playing) return;
      }
    }
    _acc += dt;
    while (_acc >= _step) {
      _acc -= _step;
      _advance();
    }
  }

  void _advance() {
    _prevSnake = List<math.Point<int>>.of(_snake);
    _dir = _nextDir;
    final head = _snake.first;
    final nx = head.x + _dir.x;
    final ny = head.y + _dir.y;
    // Solid walls — running into the edge ends the run.
    if (nx < 0 || nx >= _cols || ny < 0 || ny >= _rows) {
      _gameOver();
      return;
    }
    final next = math.Point<int>(nx, ny);
    if (_snake.contains(next) ||
        _obstacles.contains(next) ||
        _monsters.any((m) => m.pos == next)) {
      _gameOver();
      return;
    }
    _snake.insert(0, next);
    if (next == _food) {
      _apples++;
      _combo = _sinceEat < 2.5 ? _combo + 1 : 1;
      _sinceEat = 0;
      _score += (_foodKind == 1 ? 3 : 1) + (_combo >= 3 ? 1 : 0);
      TonePlayer.instance.playCue(SoundCue.snakeEat);
      emit(ExperienceEvent.bubblePopped);
      if (_foodKind == 1) {
        _flash('Golden +3!');
      } else if (_combo >= 3) {
        _flash('Combo x$_combo!');
      }
      _step = math.max(0.085, _step - 0.006);
      if (_score >= 6 && _apples % 5 == 0 && _obstacles.length < 6) {
        _addObstacle();
      }
      // Roaming hunters ramp the danger as the score climbs.
      if (_score >= 8 && _monsters.isEmpty) {
        _spawnMonster();
      } else if (_score >= 24 && _monsters.length < 2) {
        _spawnMonster();
      }
      _placeFood(golden: _apples % 5 == 4);
    } else {
      _snake.removeLast();
    }
  }

  void _gameOver() {
    final prev = GameScores.instance.best(_id);
    _status = GameStatus.over;
    TonePlayer.instance.playCue(SoundCue.gameOver);
    emit(_score > prev
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.0;
  }

  void _steer(Offset delta) {
    if (delta.dx.abs() > delta.dy.abs()) {
      final d = math.Point<int>(delta.dx > 0 ? 1 : -1, 0);
      if (d.x != -_dir.x) _nextDir = d;
    } else {
      final d = math.Point<int>(0, delta.dy > 0 ? 1 : -1);
      if (d.y != -_dir.y) _nextDir = d;
    }
  }

  // Accumulate drag so each deliberate ~16px swipe registers one clean turn,
  // instead of every jittery micro-delta flipping direction.
  void _onDrag(Offset delta) {
    _swipeAcc += delta;
    const t = 16.0;
    if (_swipeAcc.dx.abs() >= t || _swipeAcc.dy.abs() >= t) {
      _steer(_swipeAcc);
      _swipeAcc = Offset.zero;
    }
  }

  void _setDir(int dx, int dy) {
    if (dx != -_dir.x && dy != -_dir.y) _nextDir = math.Point<int>(dx, dy);
  }

  void _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _setDir(-1, 0);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _setDir(1, 0);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _setDir(0, -1);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _setDir(0, 1);
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _combo = 0;
      _apples = 0;
      _step = 0.2;
      _sinceEat = 0;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
      _seed();
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    return _GameShell(
      title: '🐍 Snake',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🐍',
      accent: const Color(0xFF06D6A0),
      onPlayAgain: _reset,
      child: KeyboardListener(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => _onDrag(d.delta),
          onPanEnd: (_) => _swipeAcc = Offset.zero,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF0B2436), Color(0xFF0E3020)],
              ),
            ),
            child: CustomPaint(
              painter: _SnakePainter(_snake, _prevSnake,
                  (_acc / _step).clamp(0.0, 1.0), _food, _foodKind,
                  _obstacles.toList(),
                  _monsters.map((m) => m.pos).toList(), _dir, _cols, _rows, _t),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}


class _SnakePainter extends CustomPainter {
  _SnakePainter(this.snake, this.prevSnake, this.progress, this.food,
      this.foodKind, this.obstacles, this.monsters, this.dir, this.cols,
      this.rows, this.t);
  final List<math.Point<int>> snake;
  final List<math.Point<int>> prevSnake;
  final double progress;
  final math.Point<int> food;
  final int foodKind;
  final List<math.Point<int>> obstacles;
  final List<math.Point<int>> monsters;
  final math.Point<int> dir;
  final int cols;
  final int rows;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / cols, size.height / rows);
    final boardW = cell * cols;
    final boardH = cell * rows;
    final ox = (size.width - boardW) / 2;
    final oy = (size.height - boardH) / 2 + 24;

    Rect cellRect(math.Point<int> p) => Rect.fromLTWH(
        ox + p.x * cell + 1, oy + p.y * cell + 1, cell - 2, cell - 2);

    // Subtle board grid so the play space reads clearly.
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(ox + c * cell, oy),
          Offset(ox + c * cell, oy + boardH), grid);
    }
    for (var r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(ox, oy + r * cell),
          Offset(ox + boardW, oy + r * cell), grid);
    }

    // Solid wall border — a clear signal the edges are deadly.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(ox, oy, boardW, boardH), const Radius.circular(6)),
      Paint()
        ..color = const Color(0xFF63C7A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Obstacles — solid rocks that end the run on contact.
    for (final o in obstacles) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cellRect(o), Radius.circular(cell / 5)),
        Paint()..color = const Color(0xFF6B7280),
      );
    }

    // Monster hunters — they chase the snake and end the run on contact.
    for (final m in monsters) {
      final mc = cellRect(m).center;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: mc, width: cell - 2, height: cell - 2),
            Radius.circular(cell / 4)),
        Paint()..color = const Color(0xFFB5179E),
      );
      final eye = Paint()..color = Colors.white;
      final pupil = Paint()..color = const Color(0xFF2A0A2A);
      final ex = cell / 6;
      canvas.drawCircle(Offset(mc.dx - ex, mc.dy - cell / 10), cell / 9, eye);
      canvas.drawCircle(Offset(mc.dx + ex, mc.dy - cell / 10), cell / 9, eye);
      canvas.drawCircle(
          Offset(mc.dx - ex, mc.dy - cell / 10), cell / 20, pupil);
      canvas.drawCircle(
          Offset(mc.dx + ex, mc.dy - cell / 10), cell / 20, pupil);
    }

    // Food — golden bonus glows brighter than the normal red apple, and
    // gently pulses so it feels alive and draws the eye.
    final foodColor =
        foodKind == 1 ? const Color(0xFFFFD700) : const Color(0xFFEF476F);
    final pulse = 0.5 + 0.5 * math.sin(t * 5);
    final fc = cellRect(food).center;
    canvas.drawCircle(
        fc,
        cell * (0.5 + pulse * 0.22),
        Paint()
          ..color = foodColor.withOpacity(0.35)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, foodKind == 1 ? 8 : 5));
    canvas.drawRRect(
        RRect.fromRectAndRadius(cellRect(food), Radius.circular(cell / 2)),
        Paint()..color = foodColor);

    // Snake — smooth glide between grid cells so movement never teleports.
    Offset segCenter(int i) {
      final to = snake[i];
      math.Point<int> from = i < prevSnake.length ? prevSnake[i] : to;
      if ((from.x - to.x).abs() > 1 || (from.y - to.y).abs() > 1) from = to;
      final gx = from.x + (to.x - from.x) * progress;
      final gy = from.y + (to.y - from.y) * progress;
      return Offset(ox + gx * cell + cell / 2, oy + gy * cell + cell / 2);
    }

    for (var i = snake.length - 1; i >= 0; i--) {
      final f = 1 - i / (snake.length + 2);
      final color = Color.lerp(
          const Color(0xFF06D6A0), const Color(0xFF118AB2), 1 - f)!;
      final r = Rect.fromCenter(
          center: segCenter(i), width: cell - 2, height: cell - 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cell / 3)),
        Paint()..color = color,
      );
    }
    // Eyes on the head, pupils looking the way the snake travels.
    if (snake.isNotEmpty) {
      final hc = segCenter(0);
      final eye = Paint()..color = Colors.white;
      final pupil = Paint()..color = const Color(0xFF0B2436);
      final lx = hc.dx - cell / 6;
      final rx = hc.dx + cell / 6;
      final ey = hc.dy - cell / 8;
      canvas.drawCircle(Offset(lx, ey), cell / 9, eye);
      canvas.drawCircle(Offset(rx, ey), cell / 9, eye);
      final px = dir.x * cell / 18;
      final py = dir.y * cell / 18;
      canvas.drawCircle(Offset(lx + px, ey + py), cell / 18, pupil);
      canvas.drawCircle(Offset(rx + px, ey + py), cell / 18, pupil);
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
  _Racer(this.lane, this.y, this.coin, this.emoji);
  int lane;
  double y;
  final bool coin;
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
  int _score = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.playing;

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
    _speed = 0.55 + _score * 0.003;
    _aliveAcc += dt;
    if (_aliveAcc >= 0.6) {
      _aliveAcc -= 0.6;
      _score++;
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.5, 1.0 - _score * 0.004) *
          (0.7 + _rnd.nextDouble() * 0.6);
      final lane = _rnd.nextInt(3);
      final coin = _rnd.nextDouble() < 0.3;
      _cars.add(_Racer(lane, -0.1, coin,
          coin ? '🪙' : _traffic[_rnd.nextInt(_traffic.length)]));
    }
    for (final c in _cars) {
      c.y += _speed * dt;
    }
    _cars.removeWhere((c) {
      if (c.y >= 0.78 && c.y <= 0.92 && c.lane == _lane) {
        if (c.coin) {
          _score += 5;
          TonePlayer.instance.playCue(SoundCue.coin);
          emit(ExperienceEvent.bubblePopped);
          _flash('+5 coin!');
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
      title: '🏎️ Race',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🏁',
      overText: 'Crash!',
      accent: const Color(0xFFFF6B6B),
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
// Bowling — line up the aim, pick your power, and roll. Five rolls; knock as
// many pins as you can. A strike (all 10) earns a big celebration.
// ===========================================================================
class BowlingGame extends StatefulWidget {
  const BowlingGame({super.key});
  @override
  State<BowlingGame> createState() => _BowlingGameState();
}

enum _BowlPhase { aim, power, rolling }

class _Pin {
  _Pin(this.x, this.y);
  final double x;
  final double y;
  bool down = false;
}

class _BowlingGameState extends State<BowlingGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'bowling';
  final List<_Pin> _pins = <_Pin>[];
  _BowlPhase _phase = _BowlPhase.aim;
  double _aim = 0;
  double _aimDir = 1;
  double _power = 0;
  double _powerDir = 1;
  double _ballX = 0.5;
  double _ballY = 0.86;
  double _vx = 0;
  double _vy = 0;
  int _rollsLeft = 5;
  int _total = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    _rack();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _rack() {
    _pins.clear();
    const topY = 0.22;
    const dy = 0.055;
    const dx = 0.07;
    for (var row = 0; row < 4; row++) {
      final count = row + 1;
      final y = topY + row * dy;
      final startX = 0.5 - (count - 1) * dx / 2;
      for (var i = 0; i < count; i++) {
        _pins.add(_Pin(startX + i * dx, y));
      }
    }
    _ballX = 0.5;
    _ballY = 0.86;
    _vx = 0;
    _vy = 0;
    _phase = _BowlPhase.aim;
    _aim = 0;
    _aimDir = 1;
    _power = 0;
    _powerDir = 1;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    switch (_phase) {
      case _BowlPhase.aim:
        _aim += _aimDir * dt * 1.3;
        if (_aim > 1) {
          _aim = 1;
          _aimDir = -1;
        } else if (_aim < -1) {
          _aim = -1;
          _aimDir = 1;
        }
      case _BowlPhase.power:
        _power += _powerDir * dt * 1.5;
        if (_power > 1) {
          _power = 1;
          _powerDir = -1;
        } else if (_power < 0) {
          _power = 0;
          _powerDir = 1;
        }
      case _BowlPhase.rolling:
        _ballX += _vx * dt;
        _ballY += _vy * dt;
        for (final p in _pins) {
          if (!p.down &&
              (p.x - _ballX).abs() < 0.05 &&
              (p.y - _ballY).abs() < 0.05) {
            p.down = true;
            TonePlayer.instance.playThock();
          }
        }
        if (_ballY < 0.08 || _ballX < 0 || _ballX > 1) _endRoll();
    }
  }

  void _tap() {
    if (_status != GameStatus.playing) return;
    if (_phase == _BowlPhase.aim) {
      setState(() => _phase = _BowlPhase.power);
    } else if (_phase == _BowlPhase.power) {
      final speed = 0.7 + _power * 1.1;
      _vy = -speed;
      _vx = _aim * 0.5 * speed;
      TonePlayer.instance.playCue(SoundCue.bowling);
      setState(() => _phase = _BowlPhase.rolling);
    }
  }

  void _endRoll() {
    final knocked = _pins.where((p) => p.down).length;
    _total += knocked;
    _rollsLeft--;
    if (knocked == 10) {
      _flash('STRIKE! 🎳');
      emit(ExperienceEvent.gameCompleted);
      TonePlayer.instance.playCue(SoundCue.completion);
    } else if (knocked >= 6) {
      _flash('Nice! $knocked pins');
      emit(ExperienceEvent.bubblePopped);
    } else {
      _flash('$knocked pins');
      emit(ExperienceEvent.correctAnswer);
    }
    if (_rollsLeft <= 0) {
      _status = GameStatus.won;
      GameScores.instance.submit(_id, _total).then((b) {
        if (mounted) setState(() => _best = b);
      });
    } else {
      _rack();
    }
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.3;
  }

  void _reset() {
    setState(() {
      _total = 0;
      _rollsLeft = 5;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
      _rack();
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    final hint = _phase == _BowlPhase.aim
        ? 'Tap to lock the aim'
        : _phase == _BowlPhase.power
            ? 'Tap to set the power'
            : 'Rolling…';
    return _GameShell(
      title: '🎳 Bowl',
      score: _total,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🎳',
      overText: 'Nice game!',
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _BowlPainter(
                  pins: _pins,
                  ballX: _ballX,
                  ballY: _ballY,
                  aim: _aim,
                  power: _power,
                  phase: _phase,
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
                    '$hint   ·   Rolls left: $_rollsLeft',
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
    required this.aim,
    required this.power,
    required this.phase,
  });
  final List<_Pin> pins;
  final double ballX;
  final double ballY;
  final double aim;
  final double power;
  final _BowlPhase phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF1A1030));
    final laneRect = Rect.fromLTWH(w * 0.15, 0, w * 0.7, h);
    canvas.drawRRect(
        RRect.fromRectAndRadius(laneRect, const Radius.circular(20)),
        Paint()..color = const Color(0xFFC9A26B));

    for (final p in pins) {
      final c = Offset(p.x * w, p.y * h);
      if (p.down) {
        canvas.drawCircle(c, 6, Paint()..color = Colors.white24);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: c, width: 14, height: 26),
                const Radius.circular(6)),
            Paint()..color = Colors.white);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: c.translate(0, -9), width: 14, height: 7),
                const Radius.circular(4)),
            Paint()..color = const Color(0xFFEF476F));
      }
    }

    final ballC = Offset(ballX * w, ballY * h);
    canvas.drawCircle(ballC, 16, Paint()..color = const Color(0xFF22223B));
    canvas.drawCircle(
        ballC,
        16,
        Paint()
          ..color = const Color(0xFF4CC9F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);

    if (phase == _BowlPhase.aim) {
      canvas.drawLine(
          ballC,
          Offset((ballX + aim * 0.4) * w, h * 0.4),
          Paint()
            ..color = Colors.white70
            ..strokeWidth = 3);
    }
    if (phase == _BowlPhase.power) {
      final barRect = Rect.fromLTWH(w * 0.82, h * 0.42, 14, h * 0.36);
      canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(7)),
          Paint()..color = Colors.white24);
      final fillH = barRect.height * power;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(barRect.left, barRect.bottom - fillH,
                  barRect.width, fillH),
              const Radius.circular(7)),
          Paint()..color = const Color(0xFF06D6A0));
    }
  }

  @override
  bool shouldRepaint(_BowlPainter oldDelegate) => true;
}
