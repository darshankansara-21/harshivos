import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  GameStatus _status = GameStatus.playing;

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
  _Orb(this.pos, this.color, this.r);
  Offset pos;
  final Color color;
  final double r;
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
  double _bannerT = 0;
  String? _banner;
  Size _view = const Size(360, 640);
  GameStatus _status = GameStatus.playing;

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
    _orbs.clear();
    for (var i = 0; i < 240; i++) {
      _orbs.add(_randomOrb());
    }
    _ai.clear();
    for (var i = 0; i < 5; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final d = _arenaR * (0.25 + _rnd.nextDouble() * 0.5);
      final w = _AiWorm(Offset(math.cos(a) * d, math.sin(a) * d),
          _rnd.nextDouble() * math.pi * 2, _rnd.nextDouble() * 360,
          16 + _rnd.nextInt(40));
      w.target = w.angle;
      w.path.add(w.head);
      _ai.add(w);
    }
  }

  _Orb _randomOrb() {
    final a = _rnd.nextDouble() * math.pi * 2;
    final d = math.sqrt(_rnd.nextDouble()) * (_arenaR - 24);
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

    // Steer toward the target heading with a capped turn rate.
    double diff = _target - _angle;
    while (diff > math.pi) diff -= math.pi * 2;
    while (diff < -math.pi) diff += math.pi * 2;
    _angle += diff.clamp(-3.6 * dt, 3.6 * dt);

    final speed = _baseSpeed * (_boost && _length > 26 ? 1.85 : 1.0);
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
        _orbs.removeAt(i);
        _length += 2;
        _score += 1;
        if (_score % 10 == 0) _flash('Length $_length!');
        TonePlayer.instance.playCue(SoundCue.snakeEat);
        emit(ExperienceEvent.bubblePopped);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted && b != _best) setState(() => _best = b);
        });
        _orbs.add(_randomOrb());
      }
    }

    _updateAi(dt);

    // Glowing edge ends the run.
    if (_head.distance > _arenaR) {
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
      title: '🐍 Snake',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🐍',
      accent: const Color(0xFF06D6A0),
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
                top: 96,
                child: _SnakeLeaderboard(playerLen: _length, ai: _ai),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SnakeLeaderboard extends StatelessWidget {
  const _SnakeLeaderboard({required this.playerLen, required this.ai});
  final int playerLen;
  final List<_AiWorm> ai;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, int>>[
      MapEntry('You', playerLen),
      for (var i = 0; i < ai.length; i++)
        MapEntry('Worm ${i + 1}', ai[i].length),
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
          for (var i = 0; i < entries.length && i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                  '${i + 1}  ${entries[i].key}  ${entries[i].value}',
                  style: TextStyle(
                      color: entries[i].key == 'You'
                          ? const Color(0xFFFFD166)
                          : Colors.white70,
                      fontSize: 12,
                      fontWeight: entries[i].key == 'You'
                          ? FontWeight.w900
                          : FontWeight.w600)),
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
            ..color = o.color.withOpacity(0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(s, o.r, Paint()..color = o.color);
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
