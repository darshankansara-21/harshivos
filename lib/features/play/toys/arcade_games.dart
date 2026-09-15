import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/tone_player.dart';
import '../../companion/companion.dart';
import 'mini_games.dart' show GameScores, GameStatus;

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
class WhackGame extends StatefulWidget {
  const WhackGame({super.key});
  @override
  State<WhackGame> createState() => _WhackGameState();
}

class _WhackGameState extends State<WhackGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'whack';
  static const int _holes = 9;
  final math.Random _rnd = math.Random();
  final List<double> _mole = List<double>.filled(_holes, 0); // seconds left
  double _spawnIn = 0.7;
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
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = 0; i < _holes; i++) {
      if (_mole[i] > 0) {
        _mole[i] -= dt;
        if (_mole[i] <= 0) _combo = 0; // ducked away unhit
      }
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.35, 0.8 - _score * 0.01) *
          (0.6 + _rnd.nextDouble() * 0.7);
      final free = <int>[
        for (var i = 0; i < _holes; i++)
          if (_mole[i] <= 0) i
      ];
      if (free.isNotEmpty) {
        _mole[free[_rnd.nextInt(free.length)]] =
            math.max(0.6, 1.4 - _score * 0.02);
      }
    }
  }

  void _hit(int i) {
    if (_status != GameStatus.playing) return;
    if (_mole[i] > 0) {
      _mole[i] = 0;
      _combo++;
      _score += 1 + (_combo >= 5 ? 1 : 0);
      TonePlayer.instance.playCue(SoundCue.wood);
      emit(ExperienceEvent.bubblePopped);
      if (_combo >= 5) {
        _banner = 'Combo x$_combo!';
        _bannerT = 1.0;
      }
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) setState(() => _best = b);
      });
    }
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < _holes; i++) {
        _mole[i] = 0;
      }
      _score = 0;
      _combo = 0;
      _banner = null;
      _bannerT = 0;
      _spawnIn = 0.7;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔨 Whack',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF8D5A3B),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF3B2A1A), Color(0xFF241810)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 60),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (var i = 0; i < _holes; i++)
                GestureDetector(
                  onTapDown: (_) => _hit(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A120A),
                      borderRadius: BorderRadius.circular(80),
                      border: Border.all(color: const Color(0xFF4A3420), width: 3),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedScale(
                      scale: _mole[i] > 0 ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: const Text('🐹', style: TextStyle(fontSize: 46)),
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
// Sky Hop — one-tap flappy. Tap to flap the bird up through the gaps. Each gap
// cleared scores a point; touching a pipe or the ground ends the run.
// ===========================================================================
class SkyHopGame extends StatefulWidget {
  const SkyHopGame({super.key});
  @override
  State<SkyHopGame> createState() => _SkyHopGameState();
}

class _Pipe {
  _Pipe(this.x, this.gapY);
  double x;
  double gapY;
  bool scored = false;
}

class _SkyHopGameState extends State<SkyHopGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'sky_hop';
  static const double _gap = 0.28; // fraction of height
  final math.Random _rnd = math.Random();
  final List<_Pipe> _pipes = <_Pipe>[];
  double _birdY = 0.5;
  double _vy = 0;
  double _spawnIn = 0;
  int _score = 0;
  int _best = 0;
  bool _started = false;
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
    if (_status != GameStatus.playing || !_started) return;
    _vy += 1.6 * dt; // gravity
    _birdY += _vy * dt;
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = 1.6;
      _pipes.add(_Pipe(1.1, 0.2 + _rnd.nextDouble() * 0.6));
    }
    for (final p in _pipes) {
      p.x -= 0.42 * dt;
      if (!p.scored && p.x < 0.28) {
        p.scored = true;
        _score++;
        TonePlayer.instance.playCue(SoundCue.coin);
        emit(ExperienceEvent.bubblePopped);
      }
      if ((p.x - 0.3).abs() < 0.11 &&
          (_birdY < p.gapY - _gap / 2 || _birdY > p.gapY + _gap / 2)) {
        _over();
        return;
      }
    }
    _pipes.removeWhere((p) => p.x < -0.2);
    if (_birdY > 0.98 || _birdY < 0.02) _over();
  }

  void _flap() {
    if (_status != GameStatus.playing) return;
    _started = true;
    _vy = -0.62;
    TonePlayer.instance.playClick(pitch: 1.3);
  }

  void _over() {
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

  void _reset() {
    setState(() {
      _pipes.clear();
      _birdY = 0.5;
      _vy = 0;
      _spawnIn = 0;
      _score = 0;
      _started = false;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🐤 Sky Hop',
      score: _score,
      best: _best,
      status: _status,
      overEmoji: '🐤',
      overText: 'Splash!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _flap(),
        child: CustomPaint(
          painter: _SkyHopPainter(_pipes, _birdY, _gap, _started),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SkyHopPainter extends CustomPainter {
  _SkyHopPainter(this.pipes, this.birdY, this.gap, this.started);
  final List<_Pipe> pipes;
  final double birdY;
  final double gap;
  final bool started;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF4EC5F1), Color(0xFFA8E6CF)],
          ).createShader(Offset.zero & size));
    final pipePaint = Paint()..color = const Color(0xFF2E9E5B);
    for (final p in pipes) {
      final cx = p.x * w;
      final gy = p.gapY * h;
      final half = gap / 2 * h;
      canvas.drawRect(
          Rect.fromLTRB(cx - w * 0.09, 0, cx + w * 0.09, gy - half), pipePaint);
      canvas.drawRect(
          Rect.fromLTRB(cx - w * 0.09, gy + half, cx + w * 0.09, h), pipePaint);
    }
    final bx = w * 0.3;
    final by = birdY * h;
    canvas.drawCircle(Offset(bx, by), w * 0.05, Paint()..color = const Color(0xFFFFD166));
    canvas.drawCircle(
        Offset(bx + w * 0.02, by - w * 0.015), 3, Paint()..color = Colors.black);
    if (!started) {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'Tap to flap',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.6));
    }
  }

  @override
  bool shouldRepaint(_SkyHopPainter oldDelegate) => true;
}

// ===========================================================================
// Stack — a block slides back and forth; tap to drop it on the tower. Overhang
// is trimmed, so precise stacking keeps the block wide. Miss entirely and the
// tower topples.
// ===========================================================================
class StackGame extends StatefulWidget {
  const StackGame({super.key});
  @override
  State<StackGame> createState() => _StackGameState();
}

class _Block {
  _Block(this.left, this.width);
  double left;
  double width;
}

class _StackGameState extends State<StackGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'stack';
  final List<_Block> _tower = <_Block>[];
  double _curLeft = 0.1;
  double _curWidth = 0.44;
  double _dir = 1;
  double _speed = 0.55;
  int _score = 0;
  int _best = 0;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    _tower.add(_Block(0.28, 0.44));
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _curLeft += _dir * _speed * dt;
    if (_curLeft + _curWidth > 1) {
      _curLeft = 1 - _curWidth;
      _dir = -1;
    } else if (_curLeft < 0) {
      _curLeft = 0;
      _dir = 1;
    }
  }

  void _drop() {
    if (_status != GameStatus.playing) return;
    final top = _tower.last;
    final l = math.max(_curLeft, top.left);
    final r = math.min(_curLeft + _curWidth, top.left + top.width);
    final overlap = r - l;
    if (overlap <= 0) {
      _over();
      return;
    }
    _tower.add(_Block(l, overlap));
    _curWidth = overlap;
    _score++;
    _speed = math.min(1.1, _speed + 0.03);
    _curLeft = _dir > 0 ? 0 : 1 - _curWidth;
    TonePlayer.instance.playCue(SoundCue.stack);
    emit(ExperienceEvent.bubblePopped);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted && b != _best) setState(() => _best = b);
    });
  }

  void _over() {
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

  void _reset() {
    setState(() {
      _tower
        ..clear()
        ..add(_Block(0.28, 0.44));
      _curLeft = 0.1;
      _curWidth = 0.44;
      _dir = 1;
      _speed = 0.55;
      _score = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🧱 Stack',
      score: _score,
      best: _best,
      status: _status,
      overEmoji: '🧱',
      overText: 'Toppled!',
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _drop(),
        child: CustomPaint(
          painter: _StackPainter(_tower, _curLeft, _curWidth),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _StackPainter extends CustomPainter {
  _StackPainter(this.tower, this.curLeft, this.curWidth);
  final List<_Block> tower;
  final double curLeft;
  final double curWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF11294B), Color(0xFF0B1B33)],
          ).createShader(Offset.zero & size));
    const blockH = 26.0;
    final baseY = h - 70;
    // Show the most recent ~14 blocks so the tower appears to descend.
    final visible = tower.length > 14 ? 14 : tower.length;
    for (var i = 0; i < visible; i++) {
      final idx = tower.length - visible + i;
      final b = tower[idx];
      final y = baseY - (visible - 1 - i) * blockH;
      final hue = (idx * 28) % 360;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(b.left * w, y, b.width * w, blockH - 3),
            const Radius.circular(5)),
        Paint()..color = HSVColor.fromAHSV(1, hue.toDouble(), 0.55, 0.95).toColor(),
      );
    }
    // Moving block above the tower.
    final movingY = baseY - visible * blockH;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(curLeft * w, movingY, curWidth * w, blockH - 3),
          const Radius.circular(5)),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_StackPainter oldDelegate) => true;
}

// ===========================================================================
// Merge — slide the board; equal numbers merge and double. Reach 64 to win.
// A gentle, original take on the classic sliding-merge puzzle.
// ===========================================================================
class MergeGame extends StatefulWidget {
  const MergeGame({super.key});
  @override
  State<MergeGame> createState() => _MergeGameState();
}

class _MergeGameState extends State<MergeGame> with _Emit {
  static const String _id = 'merge';
  static const int _n = 4;
  static const int _target = 64;
  final math.Random _rnd = math.Random();
  late List<List<int>> _g;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    _g = List<List<int>>.generate(_n, (_) => List<int>.filled(_n, 0));
    _spawn();
    _spawn();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _spawn() {
    final empty = <List<int>>[];
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (_g[r][c] == 0) empty.add(<int>[r, c]);
      }
    }
    if (empty.isEmpty) return;
    final cell = empty[_rnd.nextInt(empty.length)];
    _g[cell[0]][cell[1]] = _rnd.nextDouble() < 0.85 ? 2 : 4;
  }

  List<int> _slide(List<int> row) {
    final nums = row.where((v) => v != 0).toList();
    final out = <int>[];
    for (var i = 0; i < nums.length; i++) {
      if (i + 1 < nums.length && nums[i] == nums[i + 1]) {
        final merged = nums[i] * 2;
        out.add(merged);
        _score += merged;
        if (merged >= _target) _status = GameStatus.won;
        i++;
      } else {
        out.add(nums[i]);
      }
    }
    while (out.length < _n) {
      out.add(0);
    }
    return out;
  }

  void _move(int dir) {
    if (_status != GameStatus.playing) return;
    final before = _g.map((r) => r.join(',')).join('|');
    // 0 left, 1 right, 2 up, 3 down — normalise to a left-slide.
    List<List<int>> g = _g;
    for (var k = 0; k < dir; k++) {
      g = _rotate(g);
    }
    // For right/down we reverse rows to reuse the left-slide.
    final reverse = dir == 1 || dir == 2;
    g = <List<int>>[
      for (final row in g)
        (reverse ? _slide(row.reversed.toList()).reversed.toList() : _slide(row))
    ];
    for (var k = 0; k < ((4 - dir) % 4); k++) {
      g = _rotate(g);
    }
    _g = g;
    final after = _g.map((r) => r.join(',')).join('|');
    if (before != after) {
      _spawn();
      TonePlayer.instance.playCue(SoundCue.wood);
      emit(ExperienceEvent.bubblePopped);
    }
    if (_status == GameStatus.won) {
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
    } else if (_isStuck()) {
      _status = GameStatus.over;
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
    }
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
    setState(() {});
  }

  List<List<int>> _rotate(List<List<int>> g) {
    final out = List<List<int>>.generate(_n, (_) => List<int>.filled(_n, 0));
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        out[c][_n - 1 - r] = g[r][c];
      }
    }
    return out;
  }

  bool _isStuck() {
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (_g[r][c] == 0) return false;
        if (c + 1 < _n && _g[r][c] == _g[r][c + 1]) return false;
        if (r + 1 < _n && _g[r][c] == _g[r + 1][c]) return false;
      }
    }
    return true;
  }

  void _reset() {
    setState(() {
      _g = List<List<int>>.generate(_n, (_) => List<int>.filled(_n, 0));
      _score = 0;
      _banner = null;
      _status = GameStatus.playing;
      _spawn();
      _spawn();
    });
  }

  Color _tileColor(int v) {
    if (v == 0) return Colors.white.withOpacity(0.05);
    final hue = (math.log(v) / math.ln2 * 28) % 360;
    return HSVColor.fromAHSV(1, hue, 0.6, 0.95).toColor();
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔢 Merge',
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🔢',
      overText: 'Board full!',
      accent: const Color(0xFFF7B801),
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (d) =>
            _move((d.primaryVelocity ?? 0) < 0 ? 1 : 0),
        onVerticalDragEnd: (d) => _move((d.primaryVelocity ?? 0) < 0 ? 2 : 3),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF2A2036), Color(0xFF1A1226)],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.count(
                  crossAxisCount: _n,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var r = 0; r < _n; r++)
                      for (var c = 0; c < _n; c++)
                        Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tileColor(_g[r][c]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _g[r][c] == 0 ? '' : '${_g[r][c]}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Echo — watch the colour sequence, then repeat it. Each round adds one more.
// Reach a sequence of 8 to win. A calm memory challenge.
// ===========================================================================
class EchoGame extends StatefulWidget {
  const EchoGame({super.key});
  @override
  State<EchoGame> createState() => _EchoGameState();
}

class _EchoGameState extends State<EchoGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'echo';
  static const int _target = 8;
  static const List<Color> _pads = <Color>[
    Color(0xFFEF476F),
    Color(0xFF06D6A0),
    Color(0xFF118AB2),
    Color(0xFFFFD166),
  ];
  final math.Random _rnd = math.Random();
  final List<int> _seq = <int>[];
  int _inputAt = 0;
  int _flash = -1;
  int _showAt = 0;
  double _showT = 0;
  bool _showing = false;
  int _best = 0;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
    _nextRound();
  }

  void _nextRound() {
    _seq.add(_rnd.nextInt(4));
    _inputAt = 0;
    _showAt = 0;
    _showT = 0;
    _showing = true;
    _flash = -1;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing || !_showing) return;
    _showT += dt;
    // Each step: 0.35s on, 0.2s off.
    final step = _showT % 0.55;
    if (_showAt < _seq.length) {
      if (step < 0.35) {
        if (_flash != _seq[_showAt]) {
          _flash = _seq[_showAt];
          TonePlayer.instance.playNote(_seq[_showAt] + 2, seconds: 0.2);
        }
      } else if (_flash != -1) {
        _flash = -1;
        _showAt++;
        _showT = 0;
      }
    } else {
      _showing = false;
      _flash = -1;
    }
  }

  void _tap(int pad) {
    if (_status != GameStatus.playing || _showing) return;
    TonePlayer.instance.playNote(pad + 2, seconds: 0.18);
    if (_seq[_inputAt] == pad) {
      _inputAt++;
      if (_inputAt >= _seq.length) {
        if (_seq.length >= _target) {
          setState(() => _status = GameStatus.won);
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.gameCompleted);
          GameScores.instance.submit(_id, _seq.length);
          return;
        }
        GameScores.instance.submit(_id, _seq.length).then((b) {
          if (mounted) setState(() => _best = b);
        });
        emit(ExperienceEvent.bubblePopped);
        setState(_nextRound);
      }
    } else {
      setState(() => _status = GameStatus.over);
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
      GameScores.instance.submit(_id, _seq.length - 1).then((b) {
        if (mounted) setState(() => _best = b);
      });
    }
  }

  void _reset() {
    setState(() {
      _seq.clear();
      _status = GameStatus.playing;
      _nextRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎵 Echo',
      score: _seq.length,
      target: _target,
      best: _best,
      status: _status,
      overEmoji: '🎵',
      overText: 'Missed the tune',
      accent: const Color(0xFF9B5DE5),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1B1140), Color(0xFF120C2E)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 120, 28, 90),
            child: Column(
              children: <Widget>[
                Text(_showing ? 'Watch…' : 'Your turn!',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    physics: const NeverScrollableScrollPhysics(),
                    children: <Widget>[
                      for (var i = 0; i < 4; i++)
                        GestureDetector(
                          onTapDown: (_) => _tap(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 90),
                            decoration: BoxDecoration(
                              color: _flash == i
                                  ? _pads[i]
                                  : _pads[i].withOpacity(0.35),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _flash == i
                                  ? <BoxShadow>[
                                      BoxShadow(color: _pads[i], blurRadius: 24)
                                    ]
                                  : const <BoxShadow>[],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Tic-Tac-Toe — you are ⭐, Pico is 🐾. A friendly opponent that blocks and
// wins when it can. First to three in a row.
// ===========================================================================
class TicTacToeGame extends StatefulWidget {
  const TicTacToeGame({super.key});
  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> with _Emit {
  static const String _id = 'tictactoe';
  final List<int> _b = List<int>.filled(9, 0); // 0 empty, 1 player, 2 ai
  int _best = 0; // wins
  GameStatus _status = GameStatus.playing;
  String _overText = 'Draw';

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int _winner(List<int> b) {
    const lines = <List<int>>[
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final l in lines) {
      if (b[l[0]] != 0 && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]]) {
        return b[l[0]];
      }
    }
    return 0;
  }

  int? _findMove(int player) {
    for (var i = 0; i < 9; i++) {
      if (_b[i] == 0) {
        final copy = List<int>.from(_b);
        copy[i] = player;
        if (_winner(copy) == player) return i;
      }
    }
    return null;
  }

  void _aiMove() {
    var move = _findMove(2) ?? _findMove(1);
    if (move == null) {
      const prefs = <int>[4, 0, 2, 6, 8, 1, 3, 5, 7];
      for (final p in prefs) {
        if (_b[p] == 0) {
          move = p;
          break;
        }
      }
    }
    if (move != null) {
      _b[move] = 2;
      TonePlayer.instance.playCue(SoundCue.wood);
    }
  }

  void _finish(int w) {
    if (w == 1) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
      GameScores.instance.submit(_id, _best + 1).then((b) {
        if (mounted) setState(() => _best = b);
      });
    } else if (w == 2) {
      _status = GameStatus.over;
      _overText = 'Pico wins!';
      emit(ExperienceEvent.incorrectAnswer);
    } else {
      _status = GameStatus.over;
      _overText = 'Draw!';
      emit(ExperienceEvent.correctAnswer);
    }
  }

  void _tap(int i) {
    if (_status != GameStatus.playing || _b[i] != 0) return;
    setState(() {
      _b[i] = 1;
      TonePlayer.instance.playCue(SoundCue.wood);
      var w = _winner(_b);
      if (w == 0 && _b.contains(0)) {
        _aiMove();
        w = _winner(_b);
      }
      if (w != 0 || !_b.contains(0)) _finish(w);
    });
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < 9; i++) {
        _b[i] = 0;
      }
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '⭕ Tic-Tac-Toe',
      score: _best,
      best: _best,
      status: _status,
      overEmoji: '🐾',
      overText: _overText,
      accent: const Color(0xFF43E97B),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF12314A), Color(0xFF0C2233)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AspectRatio(
              aspectRatio: 1,
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  for (var i = 0; i < 9; i++)
                    GestureDetector(
                      onTapDown: (_) => _tap(i),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _b[i] == 1 ? '⭐' : _b[i] == 2 ? '🐾' : '',
                          style: const TextStyle(fontSize: 52),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Brick Break — slide the paddle to bounce the ball and clear every brick.
// A physics classic: wall + paddle bounces, brick hits, lose if the ball
// drops. Clear the wall to win.
// ===========================================================================
class BrickBreakGame extends StatefulWidget {
  const BrickBreakGame({super.key});
  @override
  State<BrickBreakGame> createState() => _BrickBreakGameState();
}

class _BrickBreakGameState extends State<BrickBreakGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'brick_break';
  static const int _cols = 6;
  static const int _rows = 4;
  final List<bool> _bricks = List<bool>.filled(_cols * _rows, true);
  double _paddleX = 0.5; // centre, 0..1
  double _bx = 0.5, _by = 0.6; // ball centre
  double _vx = 0.34, _vy = -0.55; // ball velocity (per second)
  bool _started = false;
  int _score = 0;
  int _best = 0;
  GameStatus _status = GameStatus.playing;

  static const double _paddleW = 0.24;
  static const double _ballR = 0.022;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing || !_started) return;
    _bx += _vx * dt;
    _by += _vy * dt;
    if (_bx < _ballR) {
      _bx = _ballR;
      _vx = _vx.abs();
    } else if (_bx > 1 - _ballR) {
      _bx = 1 - _ballR;
      _vx = -_vx.abs();
    }
    if (_by < 0.08 + _ballR) {
      _by = 0.08 + _ballR;
      _vy = _vy.abs();
    }
    // Paddle bounce.
    const paddleY = 0.9;
    if (_vy > 0 &&
        _by + _ballR >= paddleY &&
        _by < paddleY + 0.03 &&
        (_bx - _paddleX).abs() < _paddleW / 2 + _ballR) {
      _vy = -_vy.abs();
      // Steer based on where it hit the paddle.
      _vx += (_bx - _paddleX) * 1.2;
      _vx = _vx.clamp(-0.7, 0.7);
      TonePlayer.instance.playCue(SoundCue.ball);
    }
    // Brick collisions.
    for (var i = 0; i < _bricks.length; i++) {
      if (!_bricks[i]) continue;
      final r = i ~/ _cols;
      final c = i % _cols;
      const bw = 1.0 / _cols;
      final left = c * bw;
      final top = 0.1 + r * 0.05;
      final rect = Rect.fromLTWH(left + 0.008, top, bw - 0.016, 0.042);
      if (_bx > rect.left - _ballR &&
          _bx < rect.right + _ballR &&
          _by > rect.top - _ballR &&
          _by < rect.bottom + _ballR) {
        _bricks[i] = false;
        _vy = -_vy;
        _score++;
        TonePlayer.instance.playCue(SoundCue.brick);
        emit(ExperienceEvent.bubblePopped);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted && b != _best) setState(() => _best = b);
        });
        if (!_bricks.contains(true)) {
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.gameCompleted);
        }
        break;
      }
    }
    if (_by > 1) {
      _status = GameStatus.over;
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
    }
  }

  void _aim(double localX, double width) {
    setState(() {
      _started = true;
      _paddleX = (localX / width).clamp(_paddleW / 2, 1 - _paddleW / 2);
    });
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < _bricks.length; i++) {
        _bricks[i] = true;
      }
      _paddleX = 0.5;
      _bx = 0.5;
      _by = 0.6;
      _vx = 0.34;
      _vy = -0.55;
      _started = false;
      _score = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🧱 Brick Break',
      score: _score,
      best: _best,
      status: _status,
      overEmoji: '🧱',
      overText: 'Ball dropped!',
      accent: const Color(0xFFFF6B6B),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => _aim(d.localPosition.dx, constraints.maxWidth),
            onPanDown: (d) => _aim(d.localPosition.dx, constraints.maxWidth),
            child: CustomPaint(
              painter: _BrickPainter(_bricks, _cols, _paddleX, _paddleW, _bx,
                  _by, _ballR, _started),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BrickPainter extends CustomPainter {
  _BrickPainter(this.bricks, this.cols, this.paddleX, this.paddleW, this.bx,
      this.by, this.ballR, this.started);
  final List<bool> bricks;
  final int cols;
  final double paddleX;
  final double paddleW;
  final double bx;
  final double by;
  final double ballR;
  final bool started;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF20123A), Color(0xFF0E0820)],
          ).createShader(Offset.zero & size));
    final bw = 1.0 / cols;
    for (var i = 0; i < bricks.length; i++) {
      if (!bricks[i]) continue;
      final r = i ~/ cols;
      final c = i % cols;
      final left = (c * bw + 0.008) * w;
      final top = (0.1 + r * 0.05) * h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, (bw - 0.016) * w, 0.042 * h),
            const Radius.circular(4)),
        Paint()
          ..color =
              HSVColor.fromAHSV(1, (r * 55).toDouble(), 0.6, 0.95).toColor(),
      );
    }
    // Paddle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(paddleX * w, 0.92 * h),
              width: paddleW * w,
              height: 0.024 * h),
          const Radius.circular(8)),
      Paint()..color = const Color(0xFF4CC9F0),
    );
    // Ball.
    canvas.drawCircle(
        Offset(bx * w, by * h), ballR * w, Paint()..color = Colors.white);
    if (!started) {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'Drag to move · release the ball',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.72));
    }
  }

  @override
  bool shouldRepaint(_BrickPainter oldDelegate) => true;
}

// ===========================================================================
// Space Dodge — steer the rocket and survive the meteor field. The longer you
// last the faster it gets; drifting into a meteor ends the run. Endless, score
// climbs with distance.
// ===========================================================================
class SpaceDodgeGame extends StatefulWidget {
  const SpaceDodgeGame({super.key});
  @override
  State<SpaceDodgeGame> createState() => _SpaceDodgeGameState();
}

class _Meteor {
  _Meteor(this.x, this.y, this.r, this.vy);
  double x, y, r, vy;
}

class _SpaceDodgeGameState extends State<SpaceDodgeGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'space_dodge';
  final math.Random _rnd = math.Random();
  final List<_Meteor> _meteors = <_Meteor>[];
  final List<Offset> _stars = <Offset>[];
  double _shipX = 0.5;
  double _elapsed = 0;
  double _spawnIn = 0.6;
  int _score = 0;
  int _best = 0;
  int _lastMilestone = 0;
  GameStatus _status = GameStatus.playing;

  static const double _shipR = 0.045;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 40; i++) {
      _stars.add(Offset(_rnd.nextDouble(), _rnd.nextDouble()));
    }
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _elapsed += dt;
    _score = _elapsed.floor() * 5;
    if (_score ~/ 50 > _lastMilestone) {
      _lastMilestone = _score ~/ 50;
      TonePlayer.instance.playCue(SoundCue.coin);
      emit(ExperienceEvent.bubblePopped);
    }
    final speed = 0.35 + _elapsed * 0.02;
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.28, 0.7 - _elapsed * 0.015);
      final r = 0.03 + _rnd.nextDouble() * 0.05;
      _meteors.add(_Meteor(_rnd.nextDouble(), -0.1, r, speed));
    }
    for (final m in _meteors) {
      m.y += m.vy * dt;
      final dx = (m.x - _shipX);
      final dy = (m.y - 0.85);
      if (dx * dx + dy * dy < (m.r + _shipR) * (m.r + _shipR)) {
        _status = GameStatus.over;
        TonePlayer.instance.playCue(SoundCue.crash);
        final prev = GameScores.instance.best(_id);
        emit(_score > prev
            ? ExperienceEvent.gameCompleted
            : ExperienceEvent.incorrectAnswer);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        return;
      }
    }
    _meteors.removeWhere((m) => m.y > 1.2);
  }

  void _steer(double localX, double width) {
    _shipX = (localX / width).clamp(_shipR, 1 - _shipR);
  }

  void _reset() {
    setState(() {
      _meteors.clear();
      _shipX = 0.5;
      _elapsed = 0;
      _spawnIn = 0.6;
      _score = 0;
      _lastMilestone = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🚀 Space Dodge',
      score: _score,
      best: _best,
      status: _status,
      overEmoji: '💥',
      overText: 'Boom!',
      accent: const Color(0xFF9B5DE5),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => _steer(d.localPosition.dx, constraints.maxWidth),
            onPanDown: (d) => _steer(d.localPosition.dx, constraints.maxWidth),
            child: CustomPaint(
              painter: _SpacePainter(_meteors, _stars, _shipX, _shipR),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.meteors, this.stars, this.shipX, this.shipR);
  final List<_Meteor> meteors;
  final List<Offset> stars;
  final double shipX;
  final double shipR;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0B1030), Color(0xFF05030F)],
          ).createShader(Offset.zero & size));
    final star = Paint()..color = Colors.white70;
    for (final s in stars) {
      canvas.drawCircle(Offset(s.dx * w, s.dy * h), 1.4, star);
    }
    final rock = Paint()..color = const Color(0xFF8D6E63);
    for (final m in meteors) {
      canvas.drawCircle(Offset(m.x * w, m.y * h), m.r * w, rock);
      canvas.drawCircle(Offset(m.x * w, m.y * h), m.r * w,
          Paint()..color = const Color(0xFF5D4037));
    }
    // Rocket.
    final sx = shipX * w;
    final sy = 0.85 * h;
    final path = Path()
      ..moveTo(sx, sy - shipR * w)
      ..lineTo(sx - shipR * w * 0.7, sy + shipR * w)
      ..lineTo(sx + shipR * w * 0.7, sy + shipR * w)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF4CC9F0));
    canvas.drawCircle(Offset(sx, sy), shipR * w * 0.35,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SpacePainter oldDelegate) => true;
}

// ===========================================================================
// Memory Flip — flip two cards at a time to find matching pairs. Match all six
// pairs to win. A calm concentration game with no timer pressure.
// ===========================================================================
class MemoryFlipGame extends StatefulWidget {
  const MemoryFlipGame({super.key});
  @override
  State<MemoryFlipGame> createState() => _MemoryFlipGameState();
}

class _MemoryFlipGameState extends State<MemoryFlipGame> with _Emit {
  static const String _id = 'memory_flip';
  static const List<String> _faces = <String>[
    '🍎', '⭐', '🐢', '🎈', '🌸', '🚗'
  ];
  late List<String> _cards;
  late List<bool> _matched;
  int _first = -1;
  int _second = -1;
  bool _locked = false;
  int _moves = 0;
  int _pairs = 0;
  int _best = 0; // fewest moves (lower is better) stored as 999 - moves
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    _deal();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _deal() {
    _cards = <String>[..._faces, ..._faces];
    _cards.shuffle();
    _matched = List<bool>.filled(_cards.length, false);
    _first = -1;
    _second = -1;
    _locked = false;
    _moves = 0;
    _pairs = 0;
    _status = GameStatus.playing;
  }

  void _tap(int i) {
    if (_locked || _matched[i] || i == _first || _status != GameStatus.playing) {
      return;
    }
    TonePlayer.instance.playCue(SoundCue.wood);
    setState(() {
      if (_first == -1) {
        _first = i;
      } else {
        _second = i;
        _moves++;
        if (_cards[_first] == _cards[_second]) {
          _matched[_first] = true;
          _matched[_second] = true;
          _pairs++;
          TonePlayer.instance.playCue(SoundCue.learnGood);
          _first = -1;
          _second = -1;
          if (_pairs >= _faces.length) {
            _status = GameStatus.won;
            TonePlayer.instance.playCue(SoundCue.success);
            emit(ExperienceEvent.gameCompleted);
            final score = math.max(0, 999 - _moves);
            GameScores.instance.submit(_id, score).then((b) {
              if (mounted) setState(() => _best = b);
            });
          } else {
            emit(ExperienceEvent.bubblePopped);
          }
        } else {
          _locked = true;
          Future<void>.delayed(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            setState(() {
              _first = -1;
              _second = -1;
              _locked = false;
            });
          });
        }
      }
    });
  }

  void _reset() => setState(_deal);

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🧠 Memory Flip',
      score: _pairs,
      target: _faces.length,
      best: _best > 0 ? _moves : 0,
      status: _status,
      overEmoji: '🧠',
      overText: 'Nice memory!',
      accent: const Color(0xFF06D6A0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF10233A), Color(0xFF0A1626)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 70),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (var i = 0; i < _cards.length; i++)
                  GestureDetector(
                    onTapDown: (_) => _tap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _matched[i]
                            ? const Color(0xFF06D6A0).withOpacity(0.35)
                            : (i == _first || i == _second)
                                ? Colors.white
                                : const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        (_matched[i] || i == _first || i == _second)
                            ? _cards[i]
                            : '',
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


