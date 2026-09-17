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
    this.rankByScore = true,
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
  final List<bool> _isBomb = List<bool>.filled(_holes, false);
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
        if (_mole[i] <= 0) {
          // A hamster that ducks away unhit breaks the combo; an avoided bomb
          // is fine.
          if (!_isBomb[i]) _combo = 0;
          _isBomb[i] = false;
        }
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
        final h = free[_rnd.nextInt(free.length)];
        // Roughly one in five pop-ups is a bomb to avoid.
        _isBomb[h] = _rnd.nextInt(5) == 0;
        _mole[h] = math.max(0.6, 1.4 - _score * 0.02);
      }
    }
  }

  void _hit(int i) {
    if (_status != GameStatus.playing) return;
    if (_mole[i] > 0) {
      final wasBomb = _isBomb[i];
      _mole[i] = 0;
      _isBomb[i] = false;
      if (wasBomb) {
        _combo = 0;
        _score = math.max(0, _score - 1);
        _banner = 'Ouch! Avoid 💣';
        _bannerT = 1.0;
        TonePlayer.instance.playCue(SoundCue.crash);
        emit(ExperienceEvent.incorrectAnswer);
        return;
      }
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
        _isBomb[i] = false;
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
                      child: Text(_isBomb[i] ? '💣' : '🐹',
                          style: const TextStyle(fontSize: 46)),
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
  _Pipe(this.x, this.gapY, this.coinY);
  double x;
  double gapY;
  final double coinY;
  bool scored = false;
  bool coinTaken = false;
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
      final gapY = 0.2 + _rnd.nextDouble() * 0.6;
      // Coin sits off-centre inside the gap, so grabbing it is a small risk.
      final coinY = gapY + (_rnd.nextDouble() - 0.5) * _gap * 0.7;
      _pipes.add(_Pipe(1.1, gapY, coinY));
    }
    for (final p in _pipes) {
      p.x -= 0.42 * dt;
      if (!p.scored && p.x < 0.28) {
        p.scored = true;
        _score++;
        TonePlayer.instance.playCue(SoundCue.coin);
        emit(ExperienceEvent.bubblePopped);
      }
      if (!p.coinTaken &&
          (p.x - 0.3).abs() < 0.06 &&
          (_birdY - p.coinY).abs() < 0.05) {
        p.coinTaken = true;
        _score += 2;
        TonePlayer.instance.playCue(SoundCue.coin);
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
      if (!p.coinTaken) {
        final coinC = Offset(cx, p.coinY * h);
        canvas.drawCircle(coinC, w * 0.028,
            Paint()..color = const Color(0xFFFFD166));
        canvas.drawCircle(
            coinC,
            w * 0.028,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFB8860B));
      }
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
  int _perfectStreak = 0;
  String? _banner;
  double _bannerT = 0;
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
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
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
    // A near-perfect drop keeps the full width and builds a streak bonus.
    final misalign = (_curLeft - top.left).abs();
    if (misalign < 0.012) {
      _perfectStreak++;
      _tower.add(_Block(top.left, top.width));
      _curWidth = top.width;
      _score += 1 + _perfectStreak.clamp(1, 5);
      _banner = 'Perfect x$_perfectStreak!';
      _bannerT = 1.0;
      TonePlayer.instance.playCue(SoundCue.success);
    } else {
      _perfectStreak = 0;
      _tower.add(_Block(l, overlap));
      _curWidth = overlap;
      _score++;
      TonePlayer.instance.playCue(SoundCue.stack);
    }
    _speed = math.min(1.1, _speed + 0.03);
    _curLeft = _dir > 0 ? 0 : 1 - _curWidth;
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
      _perfectStreak = 0;
      _banner = null;
      _bannerT = 0;
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
      banner: _banner,
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
    // Longer sequences flash faster, so recall gets harder as you go.
    final onT = math.max(0.16, 0.35 - _seq.length * 0.015);
    final stepLen = onT + 0.2;
    final step = _showT % stepLen;
    if (_showAt < _seq.length) {
      if (step < onT) {
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
      rankByScore: false,
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
  final math.Random _rnd = math.Random();
  int _rowCount = 4;
  List<bool> _bricks = List<bool>.filled(_cols * 4, true);
  double _paddleX = 0.5; // centre, 0..1
  double _bx = 0.5, _by = 0.6; // ball centre
  double _vx = 0.34, _vy = -0.55; // ball velocity (per second)
  double _speedMul = 1;
  bool _started = false;
  int _score = 0;
  int _best = 0;
  int _lives = 3;
  int _level = 1;
  String? _banner;
  double _bannerT = 0;
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

  void _buildBricks() {
    _bricks = List<bool>.filled(_cols * _rowCount, true);
  }

  void _serveBall() {
    _bx = 0.5;
    _by = 0.6;
    _vx = 0.34 * _speedMul * (_rnd.nextBool() ? 1 : -1);
    _vy = -0.55 * _speedMul;
    _started = false;
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.2;
  }

  void _loseLife() {
    _lives--;
    if (_lives <= 0) {
      _status = GameStatus.over;
      TonePlayer.instance.playCue(SoundCue.gameOver);
      final prev = GameScores.instance.best(_id);
      emit(_score > prev
          ? ExperienceEvent.gameCompleted
          : ExperienceEvent.incorrectAnswer);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
    } else {
      TonePlayer.instance.playCue(SoundCue.crash);
      _flash('Ball lost · $_lives left');
      _serveBall();
    }
  }

  void _nextLevel() {
    _level++;
    _speedMul = math.min(1.8, _speedMul + 0.12);
    _rowCount = math.min(6, 3 + _level);
    _buildBricks();
    _flash('Level $_level!');
    TonePlayer.instance.playCue(SoundCue.success);
    emit(ExperienceEvent.gameCompleted);
    _serveBall();
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing || !_started) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
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
          _nextLevel();
        }
        break;
      }
    }
    if (_by > 1) {
      _loseLife();
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
      _level = 1;
      _lives = 3;
      _speedMul = 1;
      _rowCount = 4;
      _buildBricks();
      _paddleX = 0.5;
      _serveBall();
      _score = 0;
      _banner = null;
      _bannerT = 0;
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
      banner: _banner ?? '♥ $_lives   ·   Level $_level',
      overEmoji: '🧱',
      overText: 'Out of balls!',
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
  _Meteor(this.x, this.y, this.r, this.vy, {this.kind = 0});
  double x, y, r, vy;
  final int kind; // 0 = rock (deadly), 1 = gem (+bonus), 2 = shield pickup
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
  int _bonus = 0;
  int _lastMilestone = 0;
  bool _shield = false;
  String? _banner;
  double _bannerT = 0;
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
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _score = _elapsed.floor() * 5 + _bonus;
    if (_score ~/ 50 > _lastMilestone) {
      _lastMilestone = _score ~/ 50;
      TonePlayer.instance.playCue(SoundCue.coin);
      emit(ExperienceEvent.bubblePopped);
    }
    final speed = 0.35 + _elapsed * 0.02;
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.28, 0.7 - _elapsed * 0.015);
      final roll = _rnd.nextDouble();
      final kind = roll < 0.14 ? 1 : (roll < 0.19 ? 2 : 0);
      final r = kind == 0 ? 0.03 + _rnd.nextDouble() * 0.05 : 0.032;
      _meteors.add(_Meteor(_rnd.nextDouble(), -0.1, r, speed, kind: kind));
    }
    for (final m in _meteors) {
      m.y += m.vy * dt;
      final dx = (m.x - _shipX);
      final dy = (m.y - 0.85);
      if (dx * dx + dy * dy < (m.r + _shipR) * (m.r + _shipR)) {
        if (m.kind == 1) {
          _bonus += 15;
          m.y = 2; // consumed
          TonePlayer.instance.playCue(SoundCue.coin);
          _flash('Gem +15');
          emit(ExperienceEvent.bubblePopped);
          continue;
        }
        if (m.kind == 2) {
          _shield = true;
          m.y = 2;
          TonePlayer.instance.playCue(SoundCue.success);
          _flash('Shield up!');
          continue;
        }
        if (_shield) {
          _shield = false;
          m.y = 2;
          TonePlayer.instance.playCue(SoundCue.metal);
          _flash('Shield saved you!');
          continue;
        }
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

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.0;
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
      _bonus = 0;
      _lastMilestone = 0;
      _shield = false;
      _banner = null;
      _bannerT = 0;
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
      banner: _shield ? (_banner ?? '🛡 Shielded') : _banner,
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
              painter: _SpacePainter(_meteors, _stars, _shipX, _shipR, _shield),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.meteors, this.stars, this.shipX, this.shipR, this.shield);
  final List<_Meteor> meteors;
  final List<Offset> stars;
  final double shipX;
  final double shipR;
  final bool shield;

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
      final c = Offset(m.x * w, m.y * h);
      final rr = m.r * w;
      if (m.kind == 1) {
        // Gem bonus — a bright diamond.
        final p = Path()
          ..moveTo(c.dx, c.dy - rr)
          ..lineTo(c.dx + rr, c.dy)
          ..lineTo(c.dx, c.dy + rr)
          ..lineTo(c.dx - rr, c.dy)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF06D6A0));
        canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white);
      } else if (m.kind == 2) {
        // Shield pickup — a glowing ring.
        canvas.drawCircle(c, rr,
            Paint()..color = const Color(0xFF4CC9F0).withOpacity(0.5));
        canvas.drawCircle(
            c,
            rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFF4CC9F0));
      } else {
        canvas.drawCircle(c, rr, rock);
        canvas.drawCircle(c, rr * 0.6,
            Paint()..color = const Color(0xFF5D4037));
      }
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
    if (shield) {
      canvas.drawCircle(
          Offset(sx, sy),
          shipR * w * 1.7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF4CC9F0).withOpacity(0.9));
    }
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
  static const List<String> _facePool = <String>[
    '🍎', '⭐', '🐢', '🎈', '🌸', '🚗', '🐬', '🎵', '🦋', '🍩'
  ];
  static const int _maxLevel = 5;
  late List<String> _cards;
  late List<bool> _matched;
  int _first = -1;
  int _second = -1;
  bool _locked = false;
  int _moves = 0;
  int _pairs = 0;
  int _level = 1;
  int _streak = 0;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.playing;

  int get _pairsThisLevel => (5 + _level).clamp(4, _facePool.length);

  @override
  void initState() {
    super.initState();
    _deal();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _deal() {
    final faces = _facePool.take(_pairsThisLevel).toList();
    _cards = <String>[...faces, ...faces];
    _cards.shuffle();
    _matched = List<bool>.filled(_cards.length, false);
    _first = -1;
    _second = -1;
    _locked = false;
    _moves = 0;
    _pairs = 0;
    _status = GameStatus.playing;
  }

  void _flash(String s) {
    _banner = s;
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _banner = null);
    });
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
          _streak++;
          _score += 10 + (_streak >= 3 ? 5 : 0);
          TonePlayer.instance.playCue(SoundCue.learnGood);
          if (_streak >= 3) _flash('Streak x$_streak!');
          _first = -1;
          _second = -1;
          if (_pairs >= _pairsThisLevel) {
            if (_level >= _maxLevel) {
              _status = GameStatus.won;
              TonePlayer.instance.playCue(SoundCue.success);
              emit(ExperienceEvent.gameCompleted);
              GameScores.instance.submit(_id, _score).then((b) {
                if (mounted) setState(() => _best = b);
              });
            } else {
              _level++;
              _score += 20;
              _flash('Level $_level!');
              TonePlayer.instance.playCue(SoundCue.milestone);
              emit(ExperienceEvent.gameCompleted);
              _locked = true;
              Future<void>.delayed(const Duration(milliseconds: 650), () {
                if (!mounted) return;
                setState(_deal);
              });
            }
          } else {
            emit(ExperienceEvent.bubblePopped);
          }
        } else {
          _streak = 0;
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

  void _reset() => setState(() {
        _level = 1;
        _streak = 0;
        _score = 0;
        _banner = null;
        _deal();
      });

  @override
  Widget build(BuildContext context) {
    drain(context);
    final cols = _cards.length <= 12 ? 3 : 4;
    return _Shell(
      title: '🧠 Memory Flip',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner ?? 'Level $_level',
      overEmoji: '🧠',
      overText: 'Great memory!',
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
              crossAxisCount: cols,
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
                        style: TextStyle(fontSize: cols == 3 ? 40 : 30),
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

// ===========================================================================
// Ball Sort — pour coloured balls between tubes until each tube holds a single
// colour. A calm, deeply satisfying sorting puzzle that quietly trains planning
// and colour sorting. Levels add more colours as you go.
// ===========================================================================
class BallSortGame extends StatefulWidget {
  const BallSortGame({super.key});
  @override
  State<BallSortGame> createState() => _BallSortGameState();
}

class _BallSortGameState extends State<BallSortGame> with _Emit {
  static const String _id = 'ball_sort';
  static const int _cap = 4;
  static const List<Color> _colorsPal = <Color>[
    Color(0xFFEF476F), Color(0xFFFFD166), Color(0xFF06D6A0),
    Color(0xFF4CC9F0), Color(0xFF9B5DE5), Color(0xFFFF9E00),
  ];
  final math.Random _rnd = math.Random();
  late List<List<int>> _tubes;
  int _selected = -1;
  int _level = 0;
  int _colorsN = 3;
  int _score = 0;
  int _best = 0;
  String? _banner;
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
    _colorsN = math.min(6, 3 + _level ~/ 2);
    _tubes = List<List<int>>.generate(_colorsN + 2, (_) => <int>[]);
    final balls = <int>[];
    for (var c = 0; c < _colorsN; c++) {
      for (var k = 0; k < _cap; k++) {
        balls.add(c);
      }
    }
    balls.shuffle(_rnd);
    var idx = 0;
    for (var t = 0; t < _colorsN; t++) {
      for (var k = 0; k < _cap; k++) {
        _tubes[t].add(balls[idx++]);
      }
    }
    _selected = -1;
  }

  bool _solved() {
    for (final t in _tubes) {
      if (t.isEmpty) continue;
      if (t.length != _cap || t.any((c) => c != t.first)) return false;
    }
    return true;
  }

  void _tapTube(int i) {
    if (_status != GameStatus.playing) return;
    if (_selected == -1) {
      if (_tubes[i].isNotEmpty) setState(() => _selected = i);
      return;
    }
    if (_selected == i) {
      setState(() => _selected = -1);
      return;
    }
    final from = _tubes[_selected];
    final to = _tubes[i];
    final ball = from.isNotEmpty ? from.last : -1;
    if (ball != -1 && to.length < _cap && (to.isEmpty || to.last == ball)) {
      setState(() {
        from.removeLast();
        to.add(ball);
        _selected = -1;
      });
      TonePlayer.instance.playCue(SoundCue.water);
      if (_solved()) {
        _score++;
        _level++;
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        _banner = 'Level $_level!';
        setState(_deal);
      }
    } else {
      setState(() => _selected = _tubes[i].isNotEmpty ? i : -1);
    }
  }

  void _reset() {
    setState(() {
      _level = 0;
      _score = 0;
      _banner = null;
      _status = GameStatus.playing;
      _deal();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🧪 Ball Sort',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF06D6A0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1A2036), Color(0xFF0E1424)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 40),
            child: FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (var i = 0; i < _tubes.length; i++) _tube(i),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tube(int i) {
    const ball = 34.0;
    final t = _tubes[i];
    final selected = _selected == i;
    return GestureDetector(
      onTap: () => _tapTube(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, selected ? -16 : 0, 0),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10), bottom: Radius.circular(28)),
          border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2.5 : 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var s = _cap - 1; s >= 0; s--)
              Container(
                width: ball,
                height: ball,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s < t.length
                      ? _colorsPal[t[s]]
                      : Colors.white.withOpacity(0.04),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Tap Order — a Schulte grid. Numbers 1–25 are scattered; tap them in order as
// fast as you can. A classic attention / visual-search trainer that's calm and
// forgiving: a wrong tap just gives a gentle nudge, never ends the game.
// ===========================================================================
class TapOrderGame extends StatefulWidget {
  const TapOrderGame({super.key});
  @override
  State<TapOrderGame> createState() => _TapOrderGameState();
}

class _TapOrderGameState extends State<TapOrderGame> with _Emit {
  static const String _id = 'tap_order';
  final math.Random _rnd = math.Random();
  late List<int> _cells; // number shown at each of the 25 cells
  int _next = 1;
  int _score = 0;
  int _round = 1;
  int _best = 0;
  String? _banner;
  int _wrongCell = -1;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    _shuffle();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _shuffle() {
    _cells = List<int>.generate(25, (i) => i + 1)..shuffle(_rnd);
    _next = 1;
  }

  void _tap(int cell) {
    if (_status != GameStatus.playing) return;
    if (_cells[cell] == _next) {
      _score++;
      _next++;
      TonePlayer.instance.playNote(_next % 10, seconds: 0.16);
      emit(ExperienceEvent.bubblePopped);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) setState(() => _best = b);
      });
      if (_next > 25) {
        _round++;
        _banner = 'Round $_round!';
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
        setState(_shuffle);
      } else {
        setState(() {});
      }
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      setState(() => _wrongCell = cell);
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _wrongCell = -1);
      });
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _round = 1;
      _banner = null;
      _status = GameStatus.playing;
      _shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔢 Tap Order',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF10233A), Color(0xFF0A1626)],
          ),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 116),
            Text('Tap $_next',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var i = 0; i < 25; i++)
                      GestureDetector(
                        onTapDown: (_) => _tap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _wrongCell == i
                                ? const Color(0xFFEF476F)
                                : _cells[i] < _next
                                    ? const Color(0xFF06D6A0).withOpacity(0.3)
                                    : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _cells[i] < _next ? '' : '${_cells[i]}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Piano Tiles — tap the falling tiles in their column before they slip past the
// bottom. Each tap plays a note so a melody builds; it speeds up as you go.
// ===========================================================================
class PianoTilesGame extends StatefulWidget {
  const PianoTilesGame({super.key});
  @override
  State<PianoTilesGame> createState() => _PianoTilesGameState();
}

class _PRow {
  _PRow(this.col, this.y);
  final int col;
  double y;
}

class _PianoTilesGameState extends State<PianoTilesGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'piano_tiles';
  static const int _cols = 4;
  static const double _gap = 0.26;
  final math.Random _rnd = math.Random();
  final List<_PRow> _rows = <_PRow>[];
  double _speed = 0.42;
  double _spawnIn = 0;
  int _score = 0;
  int _best = 0;
  int _lastCol = -1;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 4; i++) {
      _rows.add(_PRow(_pickCol(), -0.05 - i * _gap));
    }
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int _pickCol() {
    var c = _rnd.nextInt(_cols);
    if (c == _lastCol) c = (c + 1) % _cols;
    _lastCol = c;
    return c;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    for (final r in _rows) {
      r.y += _speed * dt;
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = _gap / _speed;
      _rows.add(_PRow(_pickCol(), -0.08));
    }
    for (final r in _rows) {
      if (r.y > 1.02) {
        _gameOver();
        return;
      }
    }
  }

  void _tapCol(int c) {
    if (_status != GameStatus.playing) return;
    _PRow? target;
    for (final r in _rows) {
      if (r.y > 0.04 && (target == null || r.y > target.y)) target = r;
    }
    if (target == null) return;
    if (target.col == c) {
      _rows.remove(target);
      _score++;
      TonePlayer.instance.playNote(_score % 10, seconds: 0.18);
      emit(ExperienceEvent.bubblePopped);
      _speed = math.min(0.95, _speed + 0.006);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) setState(() => _best = b);
      });
    } else {
      _gameOver();
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

  void _reset() {
    setState(() {
      _rows.clear();
      _speed = 0.42;
      _spawnIn = 0;
      _score = 0;
      _lastCol = -1;
      _status = GameStatus.playing;
      for (var i = 0; i < 4; i++) {
        _rows.add(_PRow(_pickCol(), -0.05 - i * _gap));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎹 Piano Tiles',
      score: _score,
      best: _best,
      status: _status,
      overEmoji: '🎹',
      overText: 'Missed a tile!',
      accent: const Color(0xFF9B5DE5),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tapCol(
                (d.localPosition.dx / c.maxWidth * _cols)
                    .floor()
                    .clamp(0, _cols - 1)),
            child: CustomPaint(
              painter: _PianoPainter(_rows, _cols),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _PianoPainter extends CustomPainter {
  _PianoPainter(this.rows, this.cols);
  final List<_PRow> rows;
  final int cols;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF4F1FB));
    final cw = size.width / cols;
    final div = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (var i = 1; i < cols; i++) {
      canvas.drawLine(Offset(cw * i, 0), Offset(cw * i, size.height), div);
    }
    final th = size.height * 0.22;
    for (final r in rows) {
      final x = r.col * cw;
      final y = r.y * size.height - th;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 4, y, cw - 8, th - 6), const Radius.circular(8)),
        Paint()..color = const Color(0xFF3A2E5C),
      );
    }
  }

  @override
  bool shouldRepaint(_PianoPainter oldDelegate) => true;
}

// ===========================================================================
// Block Blast — pick a block piece and tap where it goes on the 8×8 grid. Fill
// a whole row or column to clear it and score big. When no piece fits, the
// board is done. A calm spatial puzzle.
// ===========================================================================
class BlockBlastGame extends StatefulWidget {
  const BlockBlastGame({super.key});
  @override
  State<BlockBlastGame> createState() => _BlockBlastGameState();
}

class _BlockPiece {
  _BlockPiece(this.cells, this.color);
  final List<math.Point<int>> cells;
  final Color color;
}

class _BlockBlastGameState extends State<BlockBlastGame> with _Emit {
  static const String _id = 'block_blast';
  static const int _n = 8;
  final math.Random _rnd = math.Random();
  late List<List<Color?>> _grid;
  final List<_BlockPiece?> _hand = <_BlockPiece?>[null, null, null];
  int _sel = -1;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.playing;

  static const List<Color> _pieceColors = <Color>[
    Color(0xFFEF476F), Color(0xFFFFD166), Color(0xFF06D6A0),
    Color(0xFF4CC9F0), Color(0xFF9B5DE5), Color(0xFFFF9E00),
  ];

  static final List<List<math.Point<int>>> _shapes = <List<math.Point<int>>>[
    <math.Point<int>>[math.Point<int>(0, 0)],
    <math.Point<int>>[math.Point<int>(0, 0), math.Point<int>(0, 1)],
    <math.Point<int>>[math.Point<int>(0, 0), math.Point<int>(1, 0)],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(0, 1), math.Point<int>(0, 2)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(1, 0), math.Point<int>(2, 0)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(0, 1),
      math.Point<int>(1, 0), math.Point<int>(1, 1)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(1, 0), math.Point<int>(1, 1)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 1), math.Point<int>(1, 0), math.Point<int>(1, 1)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(0, 1),
      math.Point<int>(0, 2), math.Point<int>(0, 3)
    ],
  ];

  @override
  void initState() {
    super.initState();
    _grid = List<List<Color?>>.generate(_n, (_) => List<Color?>.filled(_n, null));
    _refill();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  _BlockPiece _randomPiece() => _BlockPiece(
      _shapes[_rnd.nextInt(_shapes.length)],
      _pieceColors[_rnd.nextInt(_pieceColors.length)]);

  void _refill() {
    for (var i = 0; i < 3; i++) {
      _hand[i] = _randomPiece();
    }
    _sel = -1;
  }

  bool _fits(_BlockPiece p, int r, int c) {
    for (final o in p.cells) {
      final rr = r + o.x, cc = c + o.y;
      if (rr < 0 || rr >= _n || cc < 0 || cc >= _n) return false;
      if (_grid[rr][cc] != null) return false;
    }
    return true;
  }

  bool _fitsAnywhere(_BlockPiece p) {
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (_fits(p, r, c)) return true;
      }
    }
    return false;
  }

  void _place(int r, int c) {
    if (_status != GameStatus.playing || _sel < 0) return;
    final p = _hand[_sel];
    if (p == null || !_fits(p, r, c)) return;
    for (final o in p.cells) {
      _grid[r + o.x][c + o.y] = p.color;
    }
    _score += p.cells.length;
    _hand[_sel] = null;
    _sel = -1;
    TonePlayer.instance.playCue(SoundCue.stack);
    _clearLines();
    emit(ExperienceEvent.bubblePopped);
    if (_hand.every((h) => h == null)) _refill();
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted && b != _best) _best = b;
    });
    final playable =
        _hand.whereType<_BlockPiece>().any((pc) => _fitsAnywhere(pc));
    if (!playable) {
      _gameOver();
    }
    setState(() {});
  }

  void _clearLines() {
    final fullRows = <int>[];
    final fullCols = <int>[];
    for (var r = 0; r < _n; r++) {
      if (List<Color?>.generate(_n, (c) => _grid[r][c]).every((v) => v != null)) {
        fullRows.add(r);
      }
    }
    for (var c = 0; c < _n; c++) {
      if (List<Color?>.generate(_n, (r) => _grid[r][c]).every((v) => v != null)) {
        fullCols.add(c);
      }
    }
    if (fullRows.isEmpty && fullCols.isEmpty) return;
    for (final r in fullRows) {
      for (var c = 0; c < _n; c++) {
        _grid[r][c] = null;
      }
    }
    for (final c in fullCols) {
      for (var r = 0; r < _n; r++) {
        _grid[r][c] = null;
      }
    }
    final cleared = fullRows.length + fullCols.length;
    _score += cleared * 10;
    _banner = 'Clear +${cleared * 10}!';
    TonePlayer.instance.playCue(SoundCue.success);
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

  void _reset() {
    setState(() {
      _grid =
          List<List<Color?>>.generate(_n, (_) => List<Color?>.filled(_n, null));
      _score = 0;
      _banner = null;
      _status = GameStatus.playing;
      _refill();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🟦 Block Blast',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🟦',
      overText: 'No moves left!',
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF141A2E), Color(0xFF0B1020)],
          ),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 112),
            Padding(
              padding: const EdgeInsets.all(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.count(
                  crossAxisCount: _n,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var r = 0; r < _n; r++)
                      for (var c = 0; c < _n; c++)
                        GestureDetector(
                          onTapDown: (_) => _place(r, c),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  _grid[r][c] ?? Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[for (var i = 0; i < 3; i++) _handSlot(i)],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _handSlot(int i) {
    final p = _hand[i];
    return GestureDetector(
      onTap: () => setState(() => _sel = p == null ? -1 : i),
      child: Container(
        width: 90,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_sel == i ? 0.18 : 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _sel == i ? Colors.white : Colors.white24,
              width: _sel == i ? 2 : 1),
        ),
        child:
            p == null ? const SizedBox.shrink() : CustomPaint(painter: _PiecePainter(p)),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.piece);
  final _BlockPiece piece;

  @override
  void paint(Canvas canvas, Size size) {
    var maxR = 0, maxC = 0;
    for (final o in piece.cells) {
      maxR = math.max(maxR, o.x);
      maxC = math.max(maxC, o.y);
    }
    final cell =
        math.min(size.width / (maxC + 1), size.height / (maxR + 1)) * 0.7;
    final ox = (size.width - cell * (maxC + 1)) / 2;
    final oy = (size.height - cell * (maxR + 1)) / 2;
    for (final o in piece.cells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                ox + o.y * cell + 1, oy + o.x * cell + 1, cell - 2, cell - 2),
            const Radius.circular(3)),
        Paint()..color = piece.color,
      );
    }
  }

  @override
  bool shouldRepaint(_PiecePainter oldDelegate) => true;
}

// ===========================================================================
// Bubble Shooter — aim and tap to launch a bubble up the board. Land three or
// more of the same colour touching and they pop. Clear the board; if a bubble
// settles on the bottom row the round ends.
// ===========================================================================
class BubbleShooterGame extends StatefulWidget {
  const BubbleShooterGame({super.key});
  @override
  State<BubbleShooterGame> createState() => _BubbleShooterGameState();
}

class _BubbleShooterGameState extends State<BubbleShooterGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'bubble_shooter';
  static const int _cols = 7;
  static const List<Color> _pal = <Color>[
    Color(0xFFEF476F),
    Color(0xFFFFD166),
    Color(0xFF06D6A0),
    Color(0xFF4CC9F0),
    Color(0xFF9B5DE5),
  ];
  final math.Random _rnd = math.Random();
  late List<List<Color?>> _grid;
  int _rows = 0;
  double _w = 0;
  double _h = 0;
  double _cell = 0;
  double _r = 0;
  bool _init = false;
  Offset? _pos; // flying bubble centre, null when idle
  Offset _vel = Offset.zero;
  Color _shot = _pal[0];
  Color _next = _pal[1];
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    _shot = _pal[_rnd.nextInt(_pal.length)];
    _next = _pal[_rnd.nextInt(_pal.length)];
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _layout(double w, double h) {
    if (_init && (w - _w).abs() < 0.5) return;
    _w = w;
    _h = h;
    _cell = w / _cols;
    _r = _cell / 2;
    _rows = math.max(6, (h / _cell).floor());
    _grid =
        List<List<Color?>>.generate(_rows, (_) => List<Color?>.filled(_cols, null));
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < _cols; c++) {
        _grid[r][c] = _pal[_rnd.nextInt(_pal.length)];
      }
    }
    _init = true;
  }

  Offset _center(int r, int c) =>
      Offset((c + 0.5) * _cell, (r + 0.5) * _cell);

  bool _hitsBubble(Offset p) {
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (_grid[r][c] != null &&
            (_center(r, c) - p).distance < _cell * 0.9) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing || _pos == null) return;
    var p = _pos! + _vel * dt;
    if (p.dx < _r) {
      p = Offset(_r, p.dy);
      _vel = Offset(_vel.dx.abs(), _vel.dy);
    } else if (p.dx > _w - _r) {
      p = Offset(_w - _r, p.dy);
      _vel = Offset(-_vel.dx.abs(), _vel.dy);
    }
    _pos = p;
    if (p.dy <= _r || _hitsBubble(p)) {
      _snap(p);
    }
  }

  void _snap(Offset p) {
    double bestD = double.infinity;
    int br = -1, bc = -1;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (_grid[r][c] != null) continue;
        final d = (_center(r, c) - p).distance;
        if (d < bestD) {
          bestD = d;
          br = r;
          bc = c;
        }
      }
    }
    _pos = null;
    if (br < 0) {
      _gameOver();
      return;
    }
    _grid[br][bc] = _shot;
    final group = _flood(br, bc, _shot);
    if (group.length >= 3) {
      for (final cell in group) {
        _grid[cell.x][cell.y] = null;
      }
      _score += group.length;
      _banner = 'Pop ${group.length}!';
      TonePlayer.instance.playCue(SoundCue.bubble);
      emit(ExperienceEvent.bubblePopped);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) _best = b;
      });
    } else {
      TonePlayer.instance.playCue(SoundCue.ball);
    }
    _shot = _next;
    _next = _pal[_rnd.nextInt(_pal.length)];
    if (br >= _rows - 1) {
      _gameOver();
    }
  }

  List<math.Point<int>> _flood(int r, int c, Color color) {
    final seen = <String>{};
    final out = <math.Point<int>>[];
    final stack = <math.Point<int>>[math.Point<int>(r, c)];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final key = '${p.x},${p.y}';
      if (seen.contains(key)) continue;
      if (p.x < 0 || p.x >= _rows || p.y < 0 || p.y >= _cols) continue;
      if (_grid[p.x][p.y] != color) continue;
      seen.add(key);
      out.add(p);
      stack.add(math.Point<int>(p.x + 1, p.y));
      stack.add(math.Point<int>(p.x - 1, p.y));
      stack.add(math.Point<int>(p.x, p.y + 1));
      stack.add(math.Point<int>(p.x, p.y - 1));
    }
    return out;
  }

  void _fire(Offset target) {
    if (_status != GameStatus.playing || _pos != null || !_init) return;
    final origin = Offset(_w / 2, _h - _cell);
    var dir = target - origin;
    if (dir.dy > -8) dir = Offset(dir.dx, -8);
    final n = dir / dir.distance;
    _vel = n * 640;
    _pos = origin;
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

  void _reset() {
    setState(() {
      _init = false;
      _pos = null;
      _score = 0;
      _banner = null;
      _status = GameStatus.playing;
      _shot = _pal[_rnd.nextInt(_pal.length)];
      _next = _pal[_rnd.nextInt(_pal.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🫧 Bubble Shooter',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🫧',
      overText: 'Bubbles reached the floor!',
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          _layout(c.maxWidth, c.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _fire(d.localPosition),
            child: CustomPaint(
              painter: _BubblePainter(_grid, _rows, _cols, _cell, _r, _pos,
                  _shot, _next, _w, _h),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.grid, this.rows, this.cols, this.cell, this.r, this.pos,
      this.shot, this.next, this.w, this.h);
  final List<List<Color?>> grid;
  final int rows;
  final int cols;
  final double cell;
  final double r;
  final Offset? pos;
  final Color shot;
  final Color next;
  final double w;
  final double h;

  void _ball(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, r - 1.5, Paint()..color = color);
    canvas.drawCircle(
        center.translate(-r * 0.28, -r * 0.28),
        r * 0.3,
        Paint()..color = Colors.white.withOpacity(0.4));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0E1830), Color(0xFF060B18)],
          ).createShader(Offset.zero & size));
    for (var rr = 0; rr < rows; rr++) {
      for (var cc = 0; cc < cols; cc++) {
        final col = grid[rr][cc];
        if (col != null) {
          _ball(canvas, Offset((cc + 0.5) * cell, (rr + 0.5) * cell), col);
        }
      }
    }
    // Launcher + next colour.
    final origin = Offset(w / 2, h - cell);
    if (pos != null) {
      _ball(canvas, pos!, shot);
    } else {
      _ball(canvas, origin, shot);
    }
    _ball(canvas, Offset(w / 2 + cell * 1.2, h - cell * 0.6), next);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => true;
}

// ===========================================================================
// Quick Tap — a pure reaction game. Wait on red, and the instant the screen
// flashes green, tap as fast as you can. Tapping too early costs the round.
// Faster reactions score more; five rounds make a run.
// ===========================================================================
class QuickTapGame extends StatefulWidget {
  const QuickTapGame({super.key});
  @override
  State<QuickTapGame> createState() => _QuickTapGameState();
}

class _QuickTapGameState extends State<QuickTapGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'quick_tap';
  static const int _rounds = 5;
  final math.Random _rnd = math.Random();
  int _phase = 0; // 0 = waiting (red), 1 = go (green), 2 = too soon
  double _waitT = 0;
  double _reactT = 0;
  int _round = 0;
  int _score = 0;
  int _best = 0;
  int _lastMs = 0;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    _startRound();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _startRound() {
    _phase = 0;
    _waitT = 0.9 + _rnd.nextDouble() * 2.2;
    _reactT = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_phase == 0) {
      _waitT -= dt;
      if (_waitT <= 0) _phase = 1;
    } else if (_phase == 1) {
      _reactT += dt;
    }
  }

  void _tap() {
    if (_status != GameStatus.playing) return;
    if (_phase == 2) {
      setState(_startRound);
      return;
    }
    if (_phase == 0) {
      _phase = 2; // tapped before green
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      setState(() {});
      return;
    }
    // Green — score by reaction speed.
    _lastMs = (_reactT * 1000).round();
    final pts = math.max(5, 120 - _lastMs ~/ 10);
    _score += pts;
    _round++;
    TonePlayer.instance.playCue(SoundCue.correct);
    emit(ExperienceEvent.bubblePopped);
    if (_round >= _rounds) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
    } else {
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) _best = b;
      });
      _startRound();
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _round = 0;
      _score = 0;
      _lastMs = 0;
      _status = GameStatus.playing;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final Color bg = _phase == 1
        ? const Color(0xFF06D6A0)
        : _phase == 2
            ? const Color(0xFFF4A259)
            : const Color(0xFFC0392B);
    final String big = _phase == 1
        ? 'TAP!'
        : _phase == 2
            ? 'Too soon!'
            : 'Wait…';
    final String sub = _phase == 2
        ? 'Tap to try this round again'
        : _phase == 1
            ? 'Go go go!'
            : 'Tap the moment it turns green';
    return _Shell(
      title: '⚡ Quick Tap',
      score: _score,
      best: _best,
      target: _rounds,
      status: _status,
      banner: _lastMs > 0 ? 'Round $_round · ${_lastMs}ms' : 'Round ${_round + 1}',
      overEmoji: '⚡',
      overText: 'Fast fingers!',
      accent: Colors.white,
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          color: bg,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(big,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(sub,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}






