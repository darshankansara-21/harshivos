import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/game_music_host.dart';
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
  final List<double> _splat = List<double>.filled(_holes, 0); // hit burst timer
  double _spawnIn = 0.7;
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
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = 0; i < _holes; i++) {
      if (_splat[i] > 0) _splat[i] -= dt;
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
      _splat[i] = 0.35;
      TonePlayer.instance.playCue(SoundCue.wood);
      emit(ExperienceEvent.bubblePopped);
      // Milestone cheers give the endless whack a sense of achievement.
      if (_score == 10 || _score == 25 || (_score >= 50 && _score % 25 == 0)) {
        _banner = '$_score moles! 🎉';
        _bannerT = 1.3;
        TonePlayer.instance.playCue(SoundCue.milestone);
      } else if (_combo >= 5) {
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
        _splat[i] = 0;
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
      introHow: 'Tap the moles as they pop up — but never the bombs!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        AnimatedScale(
                          scale: _mole[i] > 0 ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          child: Text(_isBomb[i] ? '💣' : '🐹',
                              style: const TextStyle(fontSize: 46)),
                        ),
                        if (_splat[i] > 0)
                          Opacity(
                            opacity: (_splat[i] / 0.35).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 1 + (1 - _splat[i] / 0.35) * 1.5,
                              child: const Text('💥',
                                  style: TextStyle(fontSize: 44)),
                            ),
                          ),
                      ],
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
  final List<_Shard> _bits = <_Shard>[];
  double _birdY = 0.5;
  double _vy = 0;
  double _spawnIn = 0;
  int _score = 0;
  int _best = 0;
  bool _started = false;
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
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 0.6 * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
    }
    if (!_started) return;
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
        for (var k = 0; k < 8; k++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.1 + _rnd.nextDouble() * 0.22;
          _bits.add(_Shard(p.x, p.coinY, math.cos(a) * sp, math.sin(a) * sp,
              const Color(0xFFFFE066)));
        }
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
    for (var k = 0; k < 4; k++) {
      _bits.add(_Shard(0.3, _birdY + 0.03, -0.14 - _rnd.nextDouble() * 0.1,
          0.05 + _rnd.nextDouble() * 0.1, Colors.white));
    }
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
      _bits.clear();
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
      introHow: 'Tap to flap and fly through the gaps. Grab the coins!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
          painter: _SkyHopPainter(_pipes, _birdY, _gap, _started, _bits),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SkyHopPainter extends CustomPainter {
  _SkyHopPainter(this.pipes, this.birdY, this.gap, this.started, this.bits);
  final List<_Pipe> pipes;
  final double birdY;
  final double gap;
  final bool started;
  final List<_Shard> bits;

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
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), w * 0.012 * k + 1.5,
          Paint()..color = s.color.withOpacity(k));
    }
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
  final math.Random _rnd = math.Random();
  final List<_Block> _tower = <_Block>[];
  final List<_Shard> _bits = <_Shard>[];
  Size _view = const Size(360, 640);
  double _curLeft = 0.1;
  double _curWidth = 0.44;
  double _dir = 1;
  double _speed = 0.55;
  int _score = 0;
  int _best = 0;
  int _perfectStreak = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

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
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 400 * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
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
    final nb = _tower.last;
    _impact((nb.left + nb.width / 2) * _view.width, _view.height - 70,
        misalign < 0.012);
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

  void _impact(double x, double y, bool perfect) {
    final color =
        perfect ? const Color(0xFFFFD166) : const Color(0xFF9EE7FF);
    for (var i = 0; i < (perfect ? 12 : 7); i++) {
      final a = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 2.4;
      final sp = 80 + _rnd.nextDouble() * 170;
      _bits.add(_Shard(x, y, math.cos(a) * sp, math.sin(a) * sp, color));
    }
  }

  void _reset() {
    setState(() {
      _tower
        ..clear()
        ..add(_Block(0.28, 0.44));
      _bits.clear();
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
      introHow: 'Tap to drop each block. Stack them as high as you can!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🧱',
      overText: 'Toppled!',
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          _view = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _drop(),
            child: CustomPaint(
              painter: _StackPainter(_tower, _curLeft, _curWidth, _bits),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _StackPainter extends CustomPainter {
  _StackPainter(this.tower, this.curLeft, this.curWidth, this.bits);
  final List<_Block> tower;
  final double curLeft;
  final double curWidth;
  final List<_Shard> bits;

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
    // Drop-impact sparks.
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x, s.y), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
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
  int _maxTile = 2;
  int _milestone = 0;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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
        if (merged > _maxTile) {
          _maxTile = merged;
          _milestone = merged;
        }
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
    _banner = null;
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
    if (_milestone > 0 && _status != GameStatus.won) {
      _banner = 'New best: $_milestone! 🎉';
      TonePlayer.instance.playCue(SoundCue.milestone);
      _milestone = 0;
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
      _maxTile = 2;
      _milestone = 0;
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
      introHow: 'Slide to move the tiles. Matching numbers merge into bigger ones!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
                        TweenAnimationBuilder<double>(
                          key: ValueKey('merge-$r-$c-${_g[r][c]}'),
                          tween: Tween<double>(
                              begin: _g[r][c] == 0 ? 1.0 : 1.18, end: 1.0),
                          duration: const Duration(milliseconds: 170),
                          curve: Curves.easeOutBack,
                          builder: (ctx, s, child) =>
                              Transform.scale(scale: s, child: child),
                          child: Container(
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
  int _tapFlash = -1;
  double _tapFlashT = 0;
  int _showAt = 0;
  double _showT = 0;
  bool _showing = false;
  int _best = 0;
  GameStatus _status = GameStatus.ready;

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
    if (_status != GameStatus.playing) return;
    if (_tapFlashT > 0) {
      _tapFlashT -= dt;
      if (_tapFlashT <= 0) _tapFlash = -1;
    }
    if (!_showing) return;
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
    _tapFlash = pad;
    _tapFlashT = 0.22;
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
      introHow: 'Watch the colours light up, then tap them back in order.',
      onStart: () => setState(() => _status = GameStatus.playing),
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
                Text(_showing ? 'Watch…' : 'Your turn!  $_inputAt/${_seq.length}',
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
                              color: (_flash == i || _tapFlash == i)
                                  ? _pads[i]
                                  : _pads[i].withOpacity(0.35),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: (_flash == i || _tapFlash == i)
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
  final math.Random _rnd = math.Random();
  final List<int> _b = List<int>.filled(9, 0); // 0 empty, 1 player, 2 ai
  List<int> _winLine = const <int>[];
  int _best = 0; // wins
  GameStatus _status = GameStatus.ready;
  String _overText = 'Draw';

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int _winner(List<int> b) {
    for (final l in _lines) {
      if (b[l[0]] != 0 && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]]) {
        return b[l[0]];
      }
    }
    return 0;
  }

  static const List<List<int>> _lines = <List<int>>[
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  List<int> _winLineFor(List<int> b) {
    for (final l in _lines) {
      if (b[l[0]] != 0 && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]]) return l;
    }
    return const <int>[];
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
    // Always take a win; but Pico only blocks most of the time so a child can
    // actually win — a perfect opponent is no fun for this audience.
    var move = _findMove(2);
    if (move == null && _rnd.nextDouble() < 0.65) move = _findMove(1);
    if (move == null) {
      const prefs = <int>[4, 0, 2, 6, 8, 1, 3, 5, 7];
      final avail = <int>[for (final p in prefs) if (_b[p] == 0) p];
      if (avail.isNotEmpty) {
        // Favour good squares but mix in some chance so it's beatable.
        move = _rnd.nextDouble() < 0.6
            ? avail.first
            : avail[_rnd.nextInt(avail.length)];
      }
    }
    if (move != null) {
      _b[move] = 2;
      TonePlayer.instance.playClick(pitch: 0.7);
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
      if (w != 0 || !_b.contains(0)) {
        _winLine = _winLineFor(_b);
        _finish(w);
      }
    });
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < 9; i++) {
        _b[i] = 0;
      }
      _winLine = const <int>[];
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '⭕ Tic-Tac-Toe',
      introHow: 'Get three in a row before the computer does!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
                          color: _winLine.contains(i)
                              ? const Color(0xFFFFD166).withOpacity(0.35)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: _winLine.contains(i)
                              ? Border.all(
                                  color: const Color(0xFFFFD166), width: 3)
                              : null,
                        ),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('ttt-$i-${_b[i]}'),
                          tween: Tween<double>(
                              begin: _b[i] != 0 ? 1.4 : 1.0, end: 1.0),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          builder: (c, s, child) =>
                              Transform.scale(scale: s, child: child),
                          child: Text(
                            _b[i] == 1 ? '⭐' : _b[i] == 2 ? '🐾' : '',
                            style: const TextStyle(fontSize: 52),
                          ),
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

class _Shard {
  _Shard(this.x, this.y, this.vx, this.vy, this.color) : life = 0.5;
  double x, y, vx, vy;
  final Color color;
  double life;
}

class _BrickBreakGameState extends State<BrickBreakGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'brick_break';
  static const int _cols = 6;
  final math.Random _rnd = math.Random();
  int _rowCount = 4;
  List<bool> _bricks = List<bool>.filled(_cols * 4, true);
  final List<_Shard> _shards = <_Shard>[];
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
  GameStatus _status = GameStatus.ready;

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
    if (_status != GameStatus.playing) return;
    for (var i = _shards.length - 1; i >= 0; i--) {
      final s = _shards[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 0.8 * dt;
      s.life -= dt;
      if (s.life <= 0) _shards.removeAt(i);
    }
    if (!_started) return;
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
        final cx = c * (1.0 / _cols) + (1.0 / _cols) / 2;
        final cy = 0.1 + r * 0.05 + 0.021;
        final col =
            HSVColor.fromAHSV(1, (r * 55).toDouble(), 0.6, 0.95).toColor();
        for (var s = 0; s < 7; s++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.25 + _rnd.nextDouble() * 0.35;
          _shards.add(_Shard(
              cx, cy, math.cos(a) * sp, math.sin(a) * sp - 0.1, col));
        }
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
      _shards.clear();
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
      introHow: 'Move the paddle to bounce the ball and smash every brick!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
                  _by, _ballR, _started, _shards),
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
      this.by, this.ballR, this.started, this.shards);
  final List<bool> bricks;
  final int cols;
  final double paddleX;
  final double paddleW;
  final double bx;
  final double by;
  final double ballR;
  final bool started;
  final List<_Shard> shards;

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
    // Brick shards.
    for (final s in shards) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      final sz = 3 + 5 * k;
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(s.x * w, s.y * h), width: sz, height: sz),
          Paint()..color = s.color.withOpacity(k));
    }
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
  final List<_Shard> _shards = <_Shard>[];
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
  GameStatus _status = GameStatus.ready;

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
    // Rocket thruster trail.
    if (_rnd.nextDouble() < 0.9) {
      _shards.add(_Shard(
          _shipX + (_rnd.nextDouble() - 0.5) * 0.03,
          0.9,
          (_rnd.nextDouble() - 0.5) * 0.08,
          0.25 + _rnd.nextDouble() * 0.18,
          _rnd.nextBool()
              ? const Color(0xFFFFB703)
              : const Color(0xFFFB5607)));
    }
    for (var i = _shards.length - 1; i >= 0; i--) {
      final s = _shards[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) _shards.removeAt(i);
    }
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
          _burstAt(m.x, m.y, const Color(0xFF06D6A0), 12);
          m.y = 2; // consumed
          TonePlayer.instance.playCue(SoundCue.coin);
          _flash('Gem +15');
          emit(ExperienceEvent.bubblePopped);
          continue;
        }
        if (m.kind == 2) {
          _shield = true;
          _burstAt(m.x, m.y, const Color(0xFF4CC9F0), 12);
          m.y = 2;
          TonePlayer.instance.playCue(SoundCue.success);
          _flash('Shield up!');
          continue;
        }
        if (_shield) {
          _shield = false;
          _burstAt(m.x, m.y, const Color(0xFF4CC9F0), 16);
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

  void _burstAt(double x, double y, Color color, int n) {
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.2 + _rnd.nextDouble() * 0.4;
      _shards.add(_Shard(x, y, math.cos(a) * sp, math.sin(a) * sp, color));
    }
  }

  void _steer(double localX, double width) {
    _shipX = (localX / width).clamp(_shipR, 1 - _shipR);
  }

  void _reset() {
    setState(() {
      _meteors.clear();
      _shards.clear();
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
      introHow: 'Steer to dodge the meteors. Grab 💎 gems and shields!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
              painter: _SpacePainter(_meteors, _stars, _shipX, _shipR, _shield,
                  _shards),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(
      this.meteors, this.stars, this.shipX, this.shipR, this.shield, this.shards);
  final List<_Meteor> meteors;
  final List<Offset> stars;
  final double shipX;
  final double shipR;
  final bool shield;
  final List<_Shard> shards;

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
    // Thruster / collect particles behind the ship.
    for (final s in shards) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(s.x * w, s.y * h),
          2 + 3 * k,
          Paint()
            ..color = s.color.withOpacity(k)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
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
  int _pairs = 0;
  int _level = 1;
  int _streak = 0;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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
    _pairs = 0;
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
        _status = GameStatus.playing;
      });

  @override
  Widget build(BuildContext context) {
    drain(context);
    final cols = _cards.length <= 12 ? 3 : 4;
    return _Shell(
      title: '🧠 Memory Flip',
      introHow: 'Flip two cards to find matching pairs. Clear them all!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
                    child: TweenAnimationBuilder<double>(
                      // Re-keys when a card becomes matched, firing a pop.
                      key: ValueKey('mem-$i-${_matched[i]}'),
                      tween: Tween<double>(
                          begin: _matched[i] ? 1.35 : 1.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
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
                          border: _matched[i]
                              ? Border.all(
                                  color: const Color(0xFFFFD166), width: 2)
                              : null,
                          boxShadow: _matched[i]
                              ? <BoxShadow>[
                                  BoxShadow(
                                      color: const Color(0xFF06D6A0)
                                          .withOpacity(0.5),
                                      blurRadius: 14)
                                ]
                              : const <BoxShadow>[],
                        ),
                        child: Text(
                          (_matched[i] || i == _first || i == _second)
                              ? _cards[i]
                              : '',
                          style: TextStyle(fontSize: cols == 3 ? 40 : 30),
                        ),
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
  GameStatus _status = GameStatus.ready;

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
      introHow: 'Tap a tube, then another, to pour. Sort each colour together!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
              TweenAnimationBuilder<double>(
                key: ValueKey('bs-$i-$s-${s < t.length ? t[s] : -1}'),
                tween: Tween<double>(
                    begin: s < t.length ? 1.3 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (ctx, sc, child) =>
                    Transform.scale(scale: sc, child: child),
                child: Container(
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
  GameStatus _status = GameStatus.ready;

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
      introHow: 'Tap the numbers in order — 1, 2, 3… as fast as you can!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('tap-$i-${_cells[i] < _next}'),
                          tween: Tween<double>(
                              begin: _cells[i] < _next ? 1.25 : 1.0, end: 1.0),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          builder: (c, s, child) =>
                              Transform.scale(scale: s, child: child),
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
  _PRow(this.col, this.y, this.note);
  final int col;
  double y;
  final int note;
}

class _PianoTilesGameState extends State<PianoTilesGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'piano_tiles';
  static const int _cols = 4;
  static const double _gap = 0.26;
  // A gentle pentatonic motif — tapping tiles in time plays a real little tune.
  static const List<int> _melody = <int>[
    0, 2, 4, 7, 4, 2, 0, 2, 4, 5, 7, 9, 7, 5, 4, 2
  ];
  final math.Random _rnd = math.Random();
  final List<_PRow> _rows = <_PRow>[];
  int _mPos = 0;
  int _flashCol = -1;
  double _flashT = 0;
  double _speed = 0.42;
  double _spawnIn = 0;
  int _score = 0;
  int _best = 0;
  int _lastCol = -1;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 4; i++) {
      _rows.add(_spawnRow(-0.05 - i * _gap));
    }
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  _PRow _spawnRow(double y) {
    final row = _PRow(_pickCol(), y, _melody[_mPos % _melody.length]);
    _mPos++;
    return row;
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
    if (_flashT > 0) _flashT -= dt;
    for (final r in _rows) {
      r.y += _speed * dt;
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = _gap / _speed;
      _rows.add(_spawnRow(-0.08));
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
      TonePlayer.instance.playNote(target.note, seconds: 0.22);
      _flashCol = c;
      _flashT = 0.26;
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
      _mPos = 0;
      _flashCol = -1;
      _flashT = 0;
      _status = GameStatus.playing;
      for (var i = 0; i < 4; i++) {
        _rows.add(_spawnRow(-0.05 - i * _gap));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎹 Piano Tiles',
      introHow: 'Tap the black tiles in time — don’t miss one!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
              painter: _PianoPainter(_rows, _cols, _flashCol, _flashT),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _PianoPainter extends CustomPainter {
  _PianoPainter(this.rows, this.cols, this.flashCol, this.flashT);
  final List<_PRow> rows;
  final int cols;
  final int flashCol;
  final double flashT;

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
    // Column hit-flash so every note lands with a visible pulse.
    if (flashCol >= 0 && flashT > 0) {
      final k = (flashT / 0.26).clamp(0.0, 1.0);
      canvas.drawRect(
          Rect.fromLTWH(flashCol * cw, 0, cw, size.height),
          Paint()..color = const Color(0xFF9B5DE5).withOpacity(0.22 * k));
    }
    final th = size.height * 0.22;
    for (final r in rows) {
      final x = r.col * cw;
      final y = r.y * size.height - th;
      // Tile hue rises with its pitch so the child sees the melody climb.
      final hue = 250 + r.note * 9.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 4, y, cw - 8, th - 6), const Radius.circular(8)),
        Paint()..color = HSVColor.fromAHSV(1, hue % 360, 0.45, 0.42).toColor(),
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
  GameStatus _status = GameStatus.ready;

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
      introHow: 'Drag the blocks onto the grid. Fill rows to clear them!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(
                                'bb-$r-$c-${_grid[r][c]?.hashCode ?? 0}'),
                            tween: Tween<double>(
                                begin: _grid[r][c] != null ? 1.25 : 1.0,
                                end: 1.0),
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            builder: (ctx, s, child) =>
                                Transform.scale(scale: s, child: child),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _grid[r][c] ??
                                    Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
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
  final List<_Shard> _pops = <_Shard>[]; // pixel-space pop particles
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
  GameStatus _status = GameStatus.ready;

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
    if (_status != GameStatus.playing) return;
    for (var i = _pops.length - 1; i >= 0; i--) {
      final s = _pops[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 300 * dt;
      s.life -= dt;
      if (s.life <= 0) _pops.removeAt(i);
    }
    if (_pos == null) return;
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
        final ctr = _center(cell.x, cell.y);
        for (var s = 0; s < 5; s++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 60 + _rnd.nextDouble() * 150;
          _pops.add(_Shard(
              ctr.dx, ctr.dy, math.cos(a) * sp, math.sin(a) * sp, _shot));
        }
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
      _pops.clear();
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
      introHow: 'Aim and shoot to match 3 bubbles of the same colour!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
                  _shot, _next, _w, _h, _pops),
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
      this.shot, this.next, this.w, this.h, this.pops);
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
  final List<_Shard> pops;

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
    // Pop particles.
    for (final s in pops) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x, s.y), r * 0.5 * k + 2,
          Paint()..color = s.color.withOpacity(k));
    }
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
  int _phase = 0; // 0 waiting(red) 1 go(green) 2 too-soon 3 result
  double _waitT = 0;
  double _reactT = 0;
  double _resultT = 0;
  double _flashT = 0;
  String _rating = '';
  int _round = 0;
  int _score = 0;
  int _best = 0;
  int _lastMs = 0;
  GameStatus _status = GameStatus.ready;

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
    if (_flashT > 0) _flashT -= dt;
    if (_phase == 0) {
      _waitT -= dt;
      if (_waitT <= 0) _phase = 1;
    } else if (_phase == 1) {
      _reactT += dt;
    } else if (_phase == 3) {
      _resultT -= dt;
      if (_resultT <= 0) _startRound();
    }
  }

  String _ratingFor(int ms) => ms < 250
      ? '⚡ Lightning!'
      : ms < 400
          ? 'Fast!'
          : ms < 600
              ? 'Nice'
              : 'Got it';

  void _tap() {
    if (_status != GameStatus.playing) return;
    if (_phase == 3) return; // result showing
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
    _rating = _ratingFor(_lastMs);
    _flashT = 0.3;
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
      _phase = 3;
      _resultT = 0.9;
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _round = 0;
      _score = 0;
      _lastMs = 0;
      _rating = '';
      _flashT = 0;
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
            : _phase == 3
                ? const Color(0xFF118AB2)
                : const Color(0xFFC0392B);
    final String big = _phase == 1
        ? 'TAP!'
        : _phase == 2
            ? 'Too soon!'
            : _phase == 3
                ? '${_lastMs}ms'
                : 'Wait…';
    final String sub = _phase == 2
        ? 'Tap to try this round again'
        : _phase == 3
            ? _rating
            : _phase == 1
                ? 'Go go go!'
                : (_lastMs > 0
                    ? 'Last: ${_lastMs}ms · $_rating'
                    : 'Tap the moment it turns green');
    return _Shell(
      title: '⚡ Quick Tap',
      introHow: 'Wait for green, then tap fast! Never tap on red.',
      onStart: () => setState(() => _status = GameStatus.playing),
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
          color: Color.lerp(
              bg, Colors.white, _flashT > 0 ? (_flashT / 0.3) * 0.5 : 0),
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

// ===========================================================================
// Pinball — a gentle child's table: the ball falls under soft gravity, tap the
// left or right half to flip, bounce off the glowing bumpers to score, and use
// the flippers to keep the ball out of the centre drain. Three balls per game.
// ===========================================================================
class PinballGame extends StatefulWidget {
  const PinballGame({super.key});
  @override
  State<PinballGame> createState() => _PinballGameState();
}

class _Bumper {
  const _Bumper(this.x, this.y, this.r);
  final double x;
  final double y;
  final double r;
}

class _PinballGameState extends State<PinballGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'pinball';
  static const double _left = 0.08;
  static const double _right = 0.92;
  static const double _top = 0.07;
  static const double _rB = 0.03;
  static const List<_Bumper> _bumpers = <_Bumper>[
    _Bumper(0.30, 0.26, 0.075),
    _Bumper(0.64, 0.22, 0.075),
    _Bumper(0.50, 0.44, 0.085),
    _Bumper(0.22, 0.54, 0.055),
    _Bumper(0.78, 0.54, 0.055),
  ];
  final math.Random _rnd = math.Random();
  final List<_Shard> _sparks = <_Shard>[];
  double _bx = 0.86;
  double _by = 0.86;
  double _vx = 0;
  double _vy = 0;
  int _score = 0;
  int _best = 0;
  int _balls = 3;
  double _leftT = 0; // 0 down .. 1 fully flipped
  double _rightT = 0;
  double _flashT = 0;
  int _flashBumper = -1;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _launch();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _launch() {
    _bx = 0.86;
    _by = 0.84;
    _vx = -0.10 - _rnd.nextDouble() * 0.08;
    _vy = -0.80;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_flashT > 0) _flashT -= dt;
    if (_leftT > 0) _leftT = math.max(0, _leftT - dt * 5);
    if (_rightT > 0) _rightT = math.max(0, _rightT - dt * 5);
    for (var i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 0.5 * dt;
      s.life -= dt;
      if (s.life <= 0) _sparks.removeAt(i);
    }

    _vy += 0.85 * dt; // gentle gravity
    _bx += _vx * dt;
    _by += _vy * dt;

    // Walls.
    if (_bx < _left + _rB) {
      _bx = _left + _rB;
      _vx = _vx.abs() * 0.92;
    }
    if (_bx > _right - _rB) {
      _bx = _right - _rB;
      _vx = -_vx.abs() * 0.92;
    }
    if (_by < _top + _rB) {
      _by = _top + _rB;
      _vy = _vy.abs() * 0.92;
    }

    // Bumpers.
    for (var i = 0; i < _bumpers.length; i++) {
      final b = _bumpers[i];
      final dx = _bx - b.x;
      final dy = _by - b.y;
      final d = math.sqrt(dx * dx + dy * dy);
      final minD = _rB + b.r;
      if (d < minD && d > 0.0001) {
        final nx = dx / d, ny = dy / d;
        _bx = b.x + nx * minD;
        _by = b.y + ny * minD;
        final boost = math.max(
            math.sqrt(_vx * _vx + _vy * _vy) * 1.05, 0.62);
        _vx = nx * boost;
        _vy = ny * boost;
        _score += 10;
        _flashT = 0.25;
        _flashBumper = i;
        for (var k = 0; k < 9; k++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.15 + _rnd.nextDouble() * 0.28;
          _sparks.add(_Shard(_bx, _by, math.cos(a) * sp, math.sin(a) * sp,
              const Color(0xFFFFF07C)));
        }
        TonePlayer.instance.playCue(SoundCue.ball);
        emit(ExperienceEvent.bubblePopped);
        _flash('+10');
      }
    }

    // Flipper ramps + centre drain.
    if (_by > 0.86 && _vy > 0) {
      final centreGap = _bx > 0.44 && _bx < 0.56;
      if (!centreGap && _bx > _left && _bx < _right) {
        final leftSide = _bx < 0.5;
        final kick = leftSide ? _leftT : _rightT;
        _by = 0.86;
        _vy = -(0.52 + kick * 0.55);
        _vx += leftSide ? 0.12 : -0.12;
        TonePlayer.instance.playCue(SoundCue.wood);
      }
    }

    if (_by > 1.04) {
      _loseBall();
    }

    final sp = math.sqrt(_vx * _vx + _vy * _vy);
    if (sp > 1.4) {
      _vx *= 1.4 / sp;
      _vy *= 1.4 / sp;
    }
  }

  void _loseBall() {
    _balls--;
    if (_balls <= 0) {
      _status = GameStatus.over;
      emit(_score > 0
          ? ExperienceEvent.gameCompleted
          : ExperienceEvent.incorrectAnswer);
      TonePlayer.instance.playCue(SoundCue.gameOver);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
    } else {
      _flash('Ball ${4 - _balls}');
      _launch();
    }
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 0.8;
  }

  void _flip(bool left) {
    if (_status != GameStatus.playing) return;
    if (left) {
      _leftT = 1;
    } else {
      _rightT = 1;
    }
    TonePlayer.instance.playClick(pitch: 0.9);
    if (_by > 0.82) {
      final onSide = left ? _bx < 0.5 : _bx >= 0.5;
      if (onSide) {
        _vy = -0.9;
        _vx += left ? 0.18 : -0.18;
      }
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _balls = 3;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
      _sparks.clear();
      _launch();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎱 Pinball',
      score: _score,
      best: _best,
      status: _status,
      banner: _banner ?? 'Balls: $_balls',
      overEmoji: '🎱',
      overText: 'Table over!',
      accent: const Color(0xFFFFC857),
      introHow:
          'Tap the left or right side to flip. Bounce the bumpers and keep the ball alive!',
      onStart: () => setState(() => _status = GameStatus.playing),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _flip(d.localPosition.dx < w / 2),
            child: CustomPaint(
              painter: _PinballPainter(
                bx: _bx,
                by: _by,
                rB: _rB,
                bumpers: _bumpers,
                flashBumper: _flashT > 0 ? _flashBumper : -1,
                leftT: _leftT,
                rightT: _rightT,
                left: _left,
                right: _right,
                top: _top,
                sparks: _sparks,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _PinballPainter extends CustomPainter {
  _PinballPainter({
    required this.bx,
    required this.by,
    required this.rB,
    required this.bumpers,
    required this.flashBumper,
    required this.leftT,
    required this.rightT,
    required this.left,
    required this.right,
    required this.top,
    required this.sparks,
  });
  final double bx, by, rB, leftT, rightT, left, right, top;
  final List<_Bumper> bumpers;
  final int flashBumper;
  final List<_Shard> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1A1140), Color(0xFF2A1A5A)],
          ).createShader(Offset.zero & size));
    double sx(double x) => x * w;
    double sy(double y) => y * h;

    final wall = Paint()
      ..color = const Color(0xFF6C5CE7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(sx(left), sy(top)), Offset(sx(left), sy(0.9)), wall);
    canvas.drawLine(
        Offset(sx(right), sy(top)), Offset(sx(right), sy(0.9)), wall);
    canvas.drawLine(Offset(sx(left), sy(top)), Offset(sx(right), sy(top)), wall);

    for (var i = 0; i < bumpers.length; i++) {
      final b = bumpers[i];
      final c = Offset(sx(b.x), sy(b.y));
      final r = b.r * w;
      final hit = i == flashBumper;
      final col = hit ? const Color(0xFFFFF07C) : const Color(0xFFFF6BAA);
      canvas.drawCircle(
          c,
          r * 1.35,
          Paint()
            ..color = col.withOpacity(hit ? 0.6 : 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawCircle(c, r, Paint()..color = col);
      canvas.drawCircle(
          c, r * 0.5, Paint()..color = Colors.white.withOpacity(0.75));
    }

    void flipper(bool leftSide, double t) {
      final pivotX = leftSide ? 0.30 : 0.70;
      final dir = leftSide ? 1.0 : -1.0;
      final tipX = pivotX + dir * 0.17;
      const downY = 0.95, upY = 0.895;
      final tipY = downY - (downY - upY) * t;
      canvas.drawLine(
          Offset(sx(pivotX), sy(0.93)),
          Offset(sx(tipX), sy(tipY)),
          Paint()
            ..color = const Color(0xFFFFC857)
            ..strokeWidth = 13
            ..strokeCap = StrokeCap.round);
    }

    flipper(true, leftT);
    flipper(false, rightT);

    for (final s in sparks) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(sx(s.x), sy(s.y)),
          2 + 3 * k,
          Paint()
            ..color = s.color.withOpacity(k)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }

    final bc = Offset(sx(bx), sy(by));
    canvas.drawCircle(
        bc,
        rB * w * 1.5,
        Paint()
          ..color = Colors.white.withOpacity(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(
        bc,
        rB * w,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: const <Color>[Colors.white, Color(0xFF9AA0B5)],
          ).createShader(Rect.fromCircle(center: bc, radius: rB * w)));
  }

  @override
  bool shouldRepaint(_PinballPainter old) => true;
}

// ===========================================================================
// Basketball — aim and shoot. Drag from the ball toward the hoop to set the
// arc (a dotted preview shows the shot), release to shoot. Swish for +2, bank
// it off the backboard for +1. The hoop starts still, then slides as you warm
// up. First to 12 baskets wins.
// ===========================================================================
class BasketballGame extends StatefulWidget {
  const BasketballGame({super.key});
  @override
  State<BasketballGame> createState() => _BasketballGameState();
}

class _BasketballGameState extends State<BasketballGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'basketball';
  static const int _target = 12;
  static const double _ballR = 0.05;
  static const double _hoopY = 0.30;
  static const double _rimHalf = 0.075;
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  double _bx = 0.5, _by = 0.82;
  double _vx = 0, _vy = 0;
  double _spin = 0;
  bool _flying = false;
  bool _touchedBoard = false;
  double _hoopX = 0.5;
  double _hoopDir = 1;
  double _hoopSpeed = 0;
  double _netT = 0;
  double _resetT = 0;
  Offset? _aim;
  int _score = 0;
  int _shots = 0;
  int _streak = 0;
  int _best = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _resetBall() {
    _bx = 0.5;
    _by = 0.82;
    _vx = 0;
    _vy = 0;
    _spin = 0;
    _flying = false;
    _touchedBoard = false;
    _aim = null;
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.2;
  }

  // Shared by the shot and the dotted preview so they always match.
  Offset _launchVel(Offset aim) {
    var v = aim * 4.0;
    final m = v.distance;
    if (m > 2.2) v = v * (2.2 / m);
    return v;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_netT > 0) _netT -= dt;
    if (_hoopSpeed > 0) {
      _hoopX += _hoopDir * _hoopSpeed * dt;
      if (_hoopX < 0.22) {
        _hoopX = 0.22;
        _hoopDir = 1;
      } else if (_hoopX > 0.78) {
        _hoopX = 0.78;
        _hoopDir = -1;
      }
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.6 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_resetT > 0) {
      _resetT -= dt;
      if (_resetT <= 0) _resetBall();
      return;
    }
    if (!_flying) return;

    final prevY = _by;
    _vy += 1.3 * dt; // gravity
    _bx += _vx * dt;
    _by += _vy * dt;
    _spin += _vx * dt * 6;

    if (_bx < _ballR) {
      _bx = _ballR;
      _vx = _vx.abs() * 0.7;
    } else if (_bx > 1 - _ballR) {
      _bx = 1 - _ballR;
      _vx = -_vx.abs() * 0.7;
    }

    // Backboard — a flat panel above and behind the rim; bank shots off it.
    const boardY = _hoopY - 0.04;
    if (_vy < 0 &&
        _by - _ballR < boardY &&
        _by - _ballR > boardY - 0.12 &&
        (_bx - _hoopX).abs() < 0.09) {
      _by = boardY + _ballR;
      _vy = _vy.abs() * 0.55;
      _touchedBoard = true;
      TonePlayer.instance.playCue(SoundCue.wood);
    }

    // Rim knobs — bouncing off these makes near-misses thrilling.
    for (final sgn in <double>[-1, 1]) {
      final rimX = _hoopX + sgn * _rimHalf;
      final dx = _bx - rimX, dy = _by - _hoopY;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < _ballR + 0.012 && d > 0.0001) {
        final nx = dx / d, ny = dy / d;
        _bx = rimX + nx * (_ballR + 0.012);
        _by = _hoopY + ny * (_ballR + 0.012);
        final dot = _vx * nx + _vy * ny;
        _vx = (_vx - 2 * dot * nx) * 0.6;
        _vy = (_vy - 2 * dot * ny) * 0.6;
        TonePlayer.instance.playCue(SoundCue.metal);
      }
    }

    // Swish / basket — ball drops through the rim plane inside the rim.
    if (prevY <= _hoopY &&
        _by > _hoopY &&
        _vy > 0 &&
        (_bx - _hoopX).abs() < _rimHalf - _ballR * 0.35) {
      _scoreBasket();
      return;
    }

    if (_by > 1.05 || (_vy > 0 && _by > 0.95 && _vx.abs() < 0.02 && _bx == _ballR)) {
      _flying = false;
      _streak = 0;
      _resetT = 0.4;
      _flash('Miss — try again');
    }
  }

  void _scoreBasket() {
    _flying = false;
    _score++;
    _streak++;
    _netT = 0.5;
    final swish = !_touchedBoard;
    for (var i = 0; i < 16; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.2 + _rnd.nextDouble() * 0.4;
      _bits.add(_Shard(_hoopX, _hoopY + 0.03, math.cos(a) * sp,
          math.sin(a) * sp, swish ? const Color(0xFFFFD166) : const Color(0xFFFF9E00)));
    }
    TonePlayer.instance.playCue(SoundCue.success);
    emit(ExperienceEvent.bubblePopped);
    _flash(swish
        ? (_streak >= 3 ? 'SWISH! Streak x$_streak 🔥' : 'SWISH! +2')
        : 'Bank it! +1');
    if (_score >= 4) _hoopSpeed = 0.14;
    if (_score >= 8) _hoopSpeed = 0.22;
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
    if (_score >= _target) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else {
      _resetT = 0.6;
    }
  }

  void _aimAt(Offset p, double w, double h) {
    if (_flying || _resetT > 0 || _status != GameStatus.playing) return;
    _aim = Offset(p.dx / w - _bx, p.dy / h - _by);
  }

  void _shoot() {
    final a = _aim;
    _aim = null;
    if (a == null || _flying || _resetT > 0) return;
    if (a.dy > -0.03) return; // must aim upward toward the hoop
    final v = _launchVel(a);
    _vx = v.dx;
    _vy = v.dy;
    _flying = true;
    _touchedBoard = false;
    _shots++;
    TonePlayer.instance.playCue(SoundCue.ball);
  }

  void _reset() {
    setState(() {
      _score = 0;
      _shots = 0;
      _streak = 0;
      _hoopX = 0.5;
      _hoopSpeed = 0;
      _hoopDir = 1;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _resetT = 0;
      _status = GameStatus.playing;
      _resetBall();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🏀 Basketball',
      introHow:
          'Drag from the ball toward the hoop to aim, then let go to shoot. Swish it for 2 points!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? (_shots > 0 ? 'Baskets $_score/$_target · shots $_shots' : 'Aim and shoot!'),
      overEmoji: '🏀',
      overText: 'Nothing but net!',
      accent: const Color(0xFFFF9E00),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _aimAt(d.localPosition, w, h),
            onPanUpdate: (d) => _aimAt(d.localPosition, w, h),
            onPanEnd: (_) => _shoot(),
            child: CustomPaint(
              painter: _BasketPainter(
                bx: _bx,
                by: _by,
                ballR: _ballR,
                spin: _spin,
                hoopX: _hoopX,
                hoopY: _hoopY,
                rimHalf: _rimHalf,
                netT: _netT,
                bits: _bits,
                aim: _flying ? null : _aim,
                launch: _aim == null ? Offset.zero : _launchVel(_aim!),
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BasketPainter extends CustomPainter {
  _BasketPainter({
    required this.bx,
    required this.by,
    required this.ballR,
    required this.spin,
    required this.hoopX,
    required this.hoopY,
    required this.rimHalf,
    required this.netT,
    required this.bits,
    required this.aim,
    required this.launch,
  });
  final double bx, by, ballR, spin, hoopX, hoopY, rimHalf, netT;
  final List<_Shard> bits;
  final Offset? aim;
  final Offset launch;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double sx(double x) => x * w;
    double sy(double y) => y * h;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF123A6B), Color(0xFF0B2342)],
          ).createShader(Offset.zero & size));

    // Backboard.
    final boardTop = sy(hoopY - 0.16);
    final boardRect = Rect.fromLTWH(
        sx(hoopX) - w * 0.1, boardTop, w * 0.2, (sy(hoopY - 0.02) - boardTop));
    canvas.drawRRect(
        RRect.fromRectAndRadius(boardRect, const Radius.circular(6)),
        Paint()..color = Colors.white.withOpacity(0.92));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(sx(hoopX), sy(hoopY - 0.07)),
                width: w * 0.09,
                height: h * 0.05),
            const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFF6B35));

    // Net (animated flip when scored).
    final rimL = sx(hoopX - rimHalf), rimR = sx(hoopX + rimHalf);
    final netPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.5;
    final wobble = netT > 0 ? math.sin(netT * 30) * 6 : 0.0;
    for (var i = 0; i <= 6; i++) {
      final t = i / 6;
      final topX = rimL + (rimR - rimL) * t;
      final botX = sx(hoopX) + (topX - sx(hoopX)) * 0.4 + wobble;
      canvas.drawLine(Offset(topX, sy(hoopY)),
          Offset(botX, sy(hoopY) + h * 0.07), netPaint);
    }

    // Rim.
    canvas.drawLine(Offset(rimL, sy(hoopY)), Offset(rimR, sy(hoopY)),
        Paint()
          ..color = const Color(0xFFFF6B35)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);

    // Aim trajectory preview.
    if (aim != null && aim!.dy < -0.03) {
      var px = bx, py = by;
      var vx = launch.dx, vy = launch.dy;
      final dot = Paint()..color = Colors.white.withOpacity(0.55);
      for (var i = 0; i < 24; i++) {
        vy += 1.3 * 0.05;
        px += vx * 0.05;
        py += vy * 0.05;
        if (py > 1 || px < 0 || px > 1) break;
        if (i.isEven) canvas.drawCircle(Offset(sx(px), sy(py)), 3, dot);
      }
    }

    // Ball with seams.
    final bc = Offset(sx(bx), sy(by));
    final r = ballR * w;
    canvas.drawCircle(bc, r, Paint()..color = const Color(0xFFEE7B30));
    canvas.save();
    canvas.translate(bc.dx, bc.dy);
    canvas.rotate(spin);
    final seam = Paint()
      ..color = const Color(0xFF7A3A12)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-r, 0), Offset(r, 0), seam);
    canvas.drawLine(Offset(0, -r), Offset(0, r), seam);
    canvas.drawArc(Rect.fromCircle(center: Offset(-r, 0), radius: r), -0.9, 1.8,
        false, seam);
    canvas.drawArc(Rect.fromCircle(center: Offset(r, 0), radius: r),
        math.pi - 0.9, 1.8, false, seam);
    canvas.restore();

    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(sx(s.x), sy(s.y)), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_BasketPainter old) => true;
}

/// Mini Golf — flick to putt across a felt green, bank off rails and obstacles,
/// and drop the ball in the cup. Nine holes; fewer strokes feel better.
class MiniGolfGame extends StatefulWidget {
  const MiniGolfGame({super.key});
  @override
  State<MiniGolfGame> createState() => _MiniGolfGameState();
}

class _MiniGolfGameState extends State<MiniGolfGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'mini_golf';
  static const int _target = 9; // holes in a round
  static const double _ballR = 0.03;
  static const double _cupR = 0.05;
  static const double _margin = 0.05;
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  double _bx = 0.5, _by = 0.86;
  double _vx = 0, _vy = 0;
  double _cupX = 0.5, _cupY = 0.2;
  double _cupPulse = 0;
  Rect? _wall;
  bool _moving = false;
  double _nextT = 0;
  int _hole = 1;
  int _strokes = 0;
  int _score = 0; // holes sunk
  int _best = 0;
  Offset? _aim;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  void _setupHole() {
    _bx = 0.5;
    _by = 0.86;
    _vx = 0;
    _vy = 0;
    _moving = false;
    _aim = null;
    _cupX = 0.2 + _rnd.nextDouble() * 0.6;
    _cupY = 0.13 + _rnd.nextDouble() * 0.18;
    // A rail obstacle appears from hole 3 onward to force bank shots.
    if (_hole >= 3) {
      final ww = 0.16 + _rnd.nextDouble() * 0.18;
      final wx = (0.5 - ww / 2 + (_rnd.nextDouble() - 0.5) * 0.34)
          .clamp(_margin, 1 - _margin - ww);
      final wy = 0.42 + (_rnd.nextDouble() - 0.5) * 0.14;
      _wall = Rect.fromLTWH(wx, wy, ww, 0.045);
    } else {
      _wall = null;
    }
  }

  // Shared by the putt and the aim preview so they always match.
  Offset _puttVel(Offset aim) {
    var v = aim * 3.0;
    final m = v.distance;
    if (m > 1.9) v = v * (1.9 / m);
    return v;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_cupPulse > 0) _cupPulse -= dt;
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_nextT > 0) {
      _nextT -= dt;
      if (_nextT <= 0) _startNextHole();
      return;
    }
    if (!_moving) return;

    _bx += _vx * dt;
    _by += _vy * dt;
    final damp = (1 - 1.5 * dt).clamp(0.0, 1.0);
    _vx *= damp;
    _vy *= damp;

    // Perimeter rails.
    const lo = _margin + _ballR, hi = 1 - _margin - _ballR;
    if (_bx < lo) {
      _bx = lo;
      _vx = _vx.abs() * 0.7;
      TonePlayer.instance.playCue(SoundCue.wood);
    } else if (_bx > hi) {
      _bx = hi;
      _vx = -_vx.abs() * 0.7;
      TonePlayer.instance.playCue(SoundCue.wood);
    }
    if (_by < lo) {
      _by = lo;
      _vy = _vy.abs() * 0.7;
      TonePlayer.instance.playCue(SoundCue.wood);
    } else if (_by > hi) {
      _by = hi;
      _vy = -_vy.abs() * 0.7;
      TonePlayer.instance.playCue(SoundCue.wood);
    }

    // Rail obstacle — reflect off the shallower-penetration axis.
    final wall = _wall;
    if (wall != null) {
      final ex = wall.inflate(_ballR);
      if (_bx > ex.left && _bx < ex.right && _by > ex.top && _by < ex.bottom) {
        final penL = _bx - ex.left, penR = ex.right - _bx;
        final penT = _by - ex.top, penB = ex.bottom - _by;
        if (math.min(penL, penR) < math.min(penT, penB)) {
          _bx = penL < penR ? ex.left : ex.right;
          _vx = -_vx * 0.7;
        } else {
          _by = penT < penB ? ex.top : ex.bottom;
          _vy = -_vy * 0.7;
        }
        TonePlayer.instance.playCue(SoundCue.wood);
      }
    }

    // The cup — sink only when rolling slowly, otherwise a thrilling lip-out.
    final dx = _bx - _cupX, dy = _by - _cupY;
    final d = math.sqrt(dx * dx + dy * dy);
    final speed = math.sqrt(_vx * _vx + _vy * _vy);
    if (d < _cupR) {
      if (speed < 0.5) {
        _sink();
        return;
      } else {
        _cupPulse = 0.3;
        TonePlayer.instance.playCue(SoundCue.metal);
      }
    }

    if (speed < 0.02) {
      _vx = 0;
      _vy = 0;
      _moving = false;
    }
  }

  void _sink() {
    _moving = false;
    _score++;
    _cupPulse = 0.6;
    for (var i = 0; i < 16; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.35;
      _bits.add(_Shard(_cupX, _cupY, math.cos(a) * sp, math.sin(a) * sp,
          const Color(0xFFFFE08A)));
    }
    TonePlayer.instance.playCue(SoundCue.success);
    emit(ExperienceEvent.bubblePopped);
    _flash(_strokes <= 1
        ? 'Hole in one! 🏌️'
        : (_strokes == 2 ? 'Birdie! Sunk in 2' : 'Sunk in $_strokes'));
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
    if (_score >= _target) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else {
      _nextT = 0.9;
    }
  }

  void _startNextHole() {
    _hole++;
    _strokes = 0;
    _setupHole();
  }

  void _aimAt(Offset p, double w, double h) {
    if (_moving || _nextT > 0 || _status != GameStatus.playing) return;
    _aim = Offset(p.dx / w - _bx, p.dy / h - _by);
  }

  void _putt() {
    final a = _aim;
    _aim = null;
    if (a == null || _moving || _nextT > 0) return;
    if (a.distance < 0.02) return;
    final v = _puttVel(a);
    _vx = v.dx;
    _vy = v.dy;
    _moving = true;
    _strokes++;
    TonePlayer.instance.playCue(SoundCue.ball);
  }

  void _reset() {
    setState(() {
      _hole = 1;
      _strokes = 0;
      _score = 0;
      _nextT = 0;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _setupHole();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '⛳ Mini Golf',
      introHow:
          'Drag from the ball toward the cup to aim and set power, then release to putt. Bank off the rails!',
      onStart: () => setState(() {
        _setupHole();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Hole $_hole/$_target · strokes $_strokes',
      overEmoji: '⛳',
      overText: 'Clubhouse champion!',
      accent: const Color(0xFF2E9E5B),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _aimAt(d.localPosition, w, h),
            onPanUpdate: (d) => _aimAt(d.localPosition, w, h),
            onPanEnd: (_) => _putt(),
            child: CustomPaint(
              painter: _GolfPainter(
                bx: _bx,
                by: _by,
                ballR: _ballR,
                cupX: _cupX,
                cupY: _cupY,
                cupR: _cupR,
                cupPulse: _cupPulse,
                margin: _margin,
                wall: _wall,
                bits: _bits,
                aim: _moving ? null : _aim,
                launch: _aim == null ? Offset.zero : _puttVel(_aim!),
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _GolfPainter extends CustomPainter {
  _GolfPainter({
    required this.bx,
    required this.by,
    required this.ballR,
    required this.cupX,
    required this.cupY,
    required this.cupR,
    required this.cupPulse,
    required this.margin,
    required this.wall,
    required this.bits,
    required this.aim,
    required this.launch,
  });
  final double bx, by, ballR, cupX, cupY, cupR, cupPulse, margin;
  final Rect? wall;
  final List<_Shard> bits;
  final Offset? aim;
  final Offset launch;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double sx(double x) => x * w;
    double sy(double y) => y * h;

    // Felt green.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2E9E5B), Color(0xFF1C6B3C)],
          ).createShader(Offset.zero & size));
    // Mow stripes.
    final stripe = Paint()..color = Colors.white.withOpacity(0.04);
    for (var i = 0; i < 8; i++) {
      if (i.isEven) {
        canvas.drawRect(
            Rect.fromLTWH(0, h * (i / 8), w, h / 8), stripe);
      }
    }

    // Wooden rails around the course.
    final rail = Paint()
      ..color = const Color(0xFF8A5A2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sx(margin);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(sx(margin / 2), sy(margin / 2 * (w / h)),
                w - sx(margin / 2), h - sy(margin / 2 * (w / h))),
            const Radius.circular(10)),
        rail);

    // Rail obstacle.
    final wl = wall;
    if (wl != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(sx(wl.left), sy(wl.top), sx(wl.width), sy(wl.height)),
              const Radius.circular(6)),
          Paint()..color = const Color(0xFF8A5A2B));
    }

    // Cup with flag.
    final cup = Offset(sx(cupX), sy(cupY));
    final pulse = cupPulse > 0 ? 1 + cupPulse * 0.5 : 1.0;
    canvas.drawCircle(cup, cupR * w * pulse,
        Paint()..color = const Color(0xFF123A1E));
    canvas.drawCircle(cup, cupR * w * 0.7 * pulse,
        Paint()..color = const Color(0xFF0A2412));
    // Flag pole + pennant.
    final poleTop = Offset(cup.dx, cup.dy - h * 0.14);
    canvas.drawLine(cup, poleTop,
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 2);
    final flag = Path()
      ..moveTo(poleTop.dx, poleTop.dy)
      ..lineTo(poleTop.dx + w * 0.09, poleTop.dy + h * 0.016)
      ..lineTo(poleTop.dx, poleTop.dy + h * 0.032)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFE23B3B));

    // Aim preview — direction dots + power.
    if (aim != null && aim!.distance > 0.02) {
      final dir = launch.distance < 1e-4 ? const Offset(0, -1) : launch / launch.distance;
      final power = launch.distance / 1.9;
      final dot = Paint()..color = Colors.white.withOpacity(0.6);
      for (var i = 1; i <= 7; i++) {
        final t = i / 7 * (0.1 + power * 0.28);
        final p = Offset(bx + dir.dx * t, by + dir.dy * t);
        if (p.dx < 0 || p.dx > 1 || p.dy < 0 || p.dy > 1) break;
        canvas.drawCircle(Offset(sx(p.dx), sy(p.dy)), 3, dot);
      }
    }

    // Ball with a soft shadow and a dimple highlight.
    final bc = Offset(sx(bx), sy(by));
    final r = ballR * w;
    canvas.drawCircle(bc.translate(2, 3), r, Paint()..color = Colors.black26);
    canvas.drawCircle(bc, r, Paint()..color = Colors.white);
    canvas.drawCircle(bc.translate(-r * 0.3, -r * 0.3), r * 0.3,
        Paint()..color = Colors.white);
    canvas.drawCircle(bc, r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black12);

    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(sx(s.x), sy(s.y)), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_GolfPainter old) => true;
}

/// Air Hockey — drag your mallet to slam the puck past the AI into the top
/// goal. Low-friction puck physics, a defending AI, first to 7 wins.
class AirHockeyGame extends StatefulWidget {
  const AirHockeyGame({super.key});
  @override
  State<AirHockeyGame> createState() => _AirHockeyGameState();
}

class _AirHockeyGameState extends State<AirHockeyGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'air_hockey';
  static const int _target = 7;
  static const double _puckR = 0.042;
  static const double _paddleR = 0.075;
  static const double _goalL = 0.33;
  static const double _goalR = 0.67;
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  double _px = 0.5, _py = 0.5, _pvx = 0, _pvy = 0;
  double _ppx = 0.5, _ppy = 0.84; // player mallet (bottom half)
  double _prevPpx = 0.5, _prevPpy = 0.84;
  double _aix = 0.5, _aiy = 0.16; // ai mallet (top half)
  int _playerScore = 0, _aiScore = 0, _best = 0;
  double _resetT = 0;
  double _goalGlow = 0; // >0 player glow, <0 ai glow
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  void _serve({required bool towardPlayer}) {
    _px = 0.5;
    _py = 0.5;
    final ang = (_rnd.nextDouble() - 0.5) * 0.7;
    final sp = 0.55;
    _pvx = math.sin(ang) * sp;
    _pvy = math.cos(ang) * sp * (towardPlayer ? 1 : -1);
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_goalGlow > 0) _goalGlow -= dt;
    if (_goalGlow < 0) _goalGlow += dt;
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_resetT > 0) {
      _resetT -= dt;
      if (_resetT <= 0) _serve(towardPlayer: _rnd.nextBool());
      return;
    }

    _px += _pvx * dt;
    _py += _pvy * dt;
    final damp = (1 - 0.3 * dt).clamp(0.0, 1.0);
    _pvx *= damp;
    _pvy *= damp;

    if (_px < _puckR) {
      _px = _puckR;
      _pvx = _pvx.abs() * 0.92;
      TonePlayer.instance.playCue(SoundCue.wood);
    } else if (_px > 1 - _puckR) {
      _px = 1 - _puckR;
      _pvx = -_pvx.abs() * 0.92;
      TonePlayer.instance.playCue(SoundCue.wood);
    }
    if (_py < _puckR) {
      if (_px > _goalL && _px < _goalR) {
        _goal(player: true);
        return;
      }
      _py = _puckR;
      _pvy = _pvy.abs() * 0.92;
      TonePlayer.instance.playCue(SoundCue.wood);
    } else if (_py > 1 - _puckR) {
      if (_px > _goalL && _px < _goalR) {
        _goal(player: false);
        return;
      }
      _py = 1 - _puckR;
      _pvy = -_pvy.abs() * 0.92;
      TonePlayer.instance.playCue(SoundCue.wood);
    }

    final ppvx = (_ppx - _prevPpx) / math.max(dt, 1e-3);
    final ppvy = (_ppy - _prevPpy) / math.max(dt, 1e-3);
    _prevPpx = _ppx;
    _prevPpy = _ppy;
    _collide(_ppx, _ppy, ppvx, ppvy);

    _updateAi(dt);
    _collide(_aix, _aiy, 0, 0);

    final sp = math.sqrt(_pvx * _pvx + _pvy * _pvy);
    if (sp > 1.5) {
      _pvx *= 1.5 / sp;
      _pvy *= 1.5 / sp;
    }
  }

  void _collide(double cx, double cy, double vx, double vy) {
    final dx = _px - cx, dy = _py - cy;
    final d = math.sqrt(dx * dx + dy * dy);
    const minD = _puckR + _paddleR;
    if (d < minD && d > 1e-4) {
      final nx = dx / d, ny = dy / d;
      _px = cx + nx * minD;
      _py = cy + ny * minD;
      final push = 0.55 + math.max(0.0, vx * nx + vy * ny);
      _pvx = nx * push + vx * 0.3;
      _pvy = ny * push + vy * 0.3;
      TonePlayer.instance.playCue(SoundCue.ball);
    }
  }

  void _updateAi(double dt) {
    double targetX, targetY;
    if (_py < 0.52) {
      targetX = _px;
      targetY = (_py - 0.09).clamp(0.06, 0.44);
    } else {
      targetX = 0.5;
      targetY = 0.14;
    }
    final ease = (3.2 * dt).clamp(0.0, 1.0);
    _aix += (targetX - _aix) * ease;
    _aiy += (targetY - _aiy) * ease;
    _aix = _aix.clamp(_paddleR, 1 - _paddleR);
    _aiy = _aiy.clamp(0.06, 0.46);
  }

  void _goal({required bool player}) {
    if (player) {
      _playerScore++;
      _goalGlow = 0.8;
    } else {
      _aiScore++;
      _goalGlow = -0.8;
    }
    final gy = player ? 0.0 : 1.0;
    for (var i = 0; i < 16; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.2 + _rnd.nextDouble() * 0.4;
      _bits.add(_Shard(_px, gy, math.cos(a) * sp, math.sin(a) * sp,
          player ? const Color(0xFFFFD166) : const Color(0xFFFF7B7B)));
    }
    _px = 0.5;
    _py = 0.5;
    _pvx = 0;
    _pvy = 0;
    emit(ExperienceEvent.bubblePopped);
    if (player) {
      TonePlayer.instance.playCue(SoundCue.success);
      _flash('GOAL! $_playerScore–$_aiScore');
      GameScores.instance.submit(_id, _playerScore).then((b) {
        if (mounted) setState(() => _best = b);
      });
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _flash('They scored · $_playerScore–$_aiScore');
    }
    if (_playerScore >= _target) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else if (_aiScore >= _target) {
      _status = GameStatus.over;
    } else {
      _resetT = 0.8;
    }
  }

  void _movePaddle(Offset p, double w, double h) {
    if (_status != GameStatus.playing) return;
    _ppx = (p.dx / w).clamp(_paddleR, 1 - _paddleR);
    _ppy = (p.dy / h).clamp(0.52, 1 - _paddleR);
  }

  void _reset() {
    setState(() {
      _playerScore = 0;
      _aiScore = 0;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _resetT = 0;
      _goalGlow = 0;
      _px = 0.5;
      _py = 0.5;
      _pvx = 0;
      _pvy = 0;
      _ppx = 0.5;
      _ppy = 0.84;
      _aix = 0.5;
      _aiy = 0.16;
      _status = GameStatus.playing;
      _serve(towardPlayer: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🏒 Air Hockey',
      introHow:
          'Drag your mallet at the bottom to slam the puck into the top goal. First to 7!',
      onStart: () => setState(() {
        _status = GameStatus.playing;
        _serve(towardPlayer: true);
      }),
      score: _playerScore,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'You $_playerScore  ·  AI $_aiScore',
      overEmoji: _playerScore >= _target ? '🏆' : '🏒',
      overText: _playerScore >= _target ? 'You win the match!' : 'Good game!',
      accent: const Color(0xFF28C2D1),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _movePaddle(d.localPosition, w, h),
            onPanUpdate: (d) => _movePaddle(d.localPosition, w, h),
            child: CustomPaint(
              painter: _HockeyPainter(
                px: _px,
                py: _py,
                ppx: _ppx,
                ppy: _ppy,
                aix: _aix,
                aiy: _aiy,
                puckR: _puckR,
                paddleR: _paddleR,
                goalL: _goalL,
                goalR: _goalR,
                goalGlow: _goalGlow,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _HockeyPainter extends CustomPainter {
  _HockeyPainter({
    required this.px,
    required this.py,
    required this.ppx,
    required this.ppy,
    required this.aix,
    required this.aiy,
    required this.puckR,
    required this.paddleR,
    required this.goalL,
    required this.goalR,
    required this.goalGlow,
    required this.bits,
  });
  final double px, py, ppx, ppy, aix, aiy, puckR, paddleR, goalL, goalR, goalGlow;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double sx(double x) => x * w;
    double sy(double y) => y * h;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0E2A4E), Color(0xFF123F63)],
          ).createShader(Offset.zero & size));
    final line = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), line);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.16, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 3, Paint()..color = Colors.white54);

    // Goal mouths.
    void goal(double y, double glow, Color c) {
      final p = Paint()..color = c.withOpacity(0.35 + glow.abs() * 0.5);
      canvas.drawRect(Rect.fromLTWH(sx(goalL), y, sx(goalR - goalL), 6), p);
    }

    goal(0, goalGlow > 0 ? goalGlow : 0, const Color(0xFFFFD166));
    goal(h - 6, goalGlow < 0 ? -goalGlow : 0, const Color(0xFFFF7B7B));

    // Mallets.
    void mallet(double cx, double cy, Color c) {
      canvas.drawCircle(Offset(sx(cx), sy(cy)), paddleR * w,
          Paint()..color = c);
      canvas.drawCircle(Offset(sx(cx), sy(cy)), paddleR * w * 0.5,
          Paint()..color = Colors.white.withOpacity(0.85));
      canvas.drawCircle(Offset(sx(cx), sy(cy)), paddleR * w,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.black26);
    }

    mallet(aix, aiy, const Color(0xFF4F7BFF));
    mallet(ppx, ppy, const Color(0xFFFF5E5E));

    // Puck.
    final pc = Offset(sx(px), sy(py));
    canvas.drawCircle(pc.translate(1, 2), puckR * w, Paint()..color = Colors.black38);
    canvas.drawCircle(pc, puckR * w, Paint()..color = const Color(0xFF14181F));
    canvas.drawCircle(pc.translate(-puckR * w * 0.3, -puckR * w * 0.3),
        puckR * w * 0.35, Paint()..color = Colors.white24);

    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(sx(s.x), sy(s.y)), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_HockeyPainter old) => true;
}

/// Target Toss — flick a bean bag at a sliding bullseye. Center rings score
/// more; the board speeds up as you climb to 24 points.
class TargetTossGame extends StatefulWidget {
  const TargetTossGame({super.key});
  @override
  State<TargetTossGame> createState() => _TargetTossGameState();
}

class _TargetTossGameState extends State<TargetTossGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'target_toss';
  static const int _target = 24;
  static const double _ballR = 0.035;
  static const double _targetY = 0.22;
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  double _bx = 0.5, _by = 0.86, _vx = 0, _vy = 0;
  bool _flying = false;
  double _tx = 0.5; // target centre x
  double _tDir = 1;
  double _tSpeed = 0.18;
  double _hitPulse = 0;
  double _resetT = 0;
  int _score = 0;
  int _throws = 0;
  int _best = 0;
  Offset? _aim;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.3;
  }

  Offset _throwVel(Offset aim) {
    var v = aim * 3.4;
    final m = v.distance;
    if (m > 2.1) v = v * (2.1 / m);
    return v;
  }

  void _resetBall() {
    _bx = 0.5;
    _by = 0.86;
    _vx = 0;
    _vy = 0;
    _flying = false;
    _aim = null;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_hitPulse > 0) _hitPulse -= dt;
    // Slide the target.
    _tx += _tDir * _tSpeed * dt;
    if (_tx < 0.16) {
      _tx = 0.16;
      _tDir = 1;
    } else if (_tx > 0.84) {
      _tx = 0.84;
      _tDir = -1;
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.5 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_resetT > 0) {
      _resetT -= dt;
      if (_resetT <= 0) _resetBall();
      return;
    }
    if (!_flying) return;

    final prevY = _by;
    _vy += 0.35 * dt; // gentle gravity
    _bx += _vx * dt;
    _by += _vy * dt;

    if (prevY > _targetY && _by <= _targetY) {
      final d = (_bx - _tx).abs();
      if (d < 0.14) {
        _registerHit(d);
        return;
      }
    }
    if (_by < -0.05 || _bx < -0.05 || _bx > 1.05 || _by > 1.1) {
      _flying = false;
      _resetT = 0.3;
      _flash('Missed — toss again');
    }
  }

  void _registerHit(double d) {
    _flying = false;
    int pts;
    String label;
    if (d < 0.03) {
      pts = 5;
      label = 'Bullseye! +5';
    } else if (d < 0.06) {
      pts = 3;
      label = 'Great! +3';
    } else if (d < 0.1) {
      pts = 2;
      label = 'Nice +2';
    } else {
      pts = 1;
      label = '+1';
    }
    _score += pts;
    _hitPulse = 0.5;
    for (var i = 0; i < 14; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.35;
      _bits.add(_Shard(_tx, _targetY, math.cos(a) * sp, math.sin(a) * sp,
          const Color(0xFFFFD166)));
    }
    TonePlayer.instance.playCue(SoundCue.success);
    emit(ExperienceEvent.bubblePopped);
    _flash(label);
    _tSpeed = 0.18 + (_score / _target) * 0.26;
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
    if (_score >= _target) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else {
      _resetT = 0.5;
    }
  }

  void _aimAt(Offset p, double w, double h) {
    if (_flying || _resetT > 0 || _status != GameStatus.playing) return;
    _aim = Offset(p.dx / w - _bx, p.dy / h - _by);
  }

  void _toss() {
    final a = _aim;
    _aim = null;
    if (a == null || _flying || _resetT > 0) return;
    if (a.dy > -0.03) return;
    final v = _throwVel(a);
    _vx = v.dx;
    _vy = v.dy;
    _flying = true;
    _throws++;
    TonePlayer.instance.playCue(SoundCue.ball);
  }

  void _reset() {
    setState(() {
      _score = 0;
      _throws = 0;
      _tSpeed = 0.18;
      _tx = 0.5;
      _tDir = 1;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _resetT = 0;
      _status = GameStatus.playing;
      _resetBall();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎯 Target Toss',
      introHow:
          'Drag from the bean bag toward the moving target, then let go. Hit the centre for 5!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Points $_score/$_target · tosses $_throws',
      overEmoji: '🎯',
      overText: 'Sharp shooter!',
      accent: const Color(0xFFE23B5B),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _aimAt(d.localPosition, w, h),
            onPanUpdate: (d) => _aimAt(d.localPosition, w, h),
            onPanEnd: (_) => _toss(),
            child: CustomPaint(
              painter: _TargetPainter(
                bx: _bx,
                by: _by,
                ballR: _ballR,
                tx: _tx,
                targetY: _targetY,
                hitPulse: _hitPulse,
                bits: _bits,
                aim: _flying ? null : _aim,
                launch: _aim == null ? Offset.zero : _throwVel(_aim!),
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _TargetPainter extends CustomPainter {
  _TargetPainter({
    required this.bx,
    required this.by,
    required this.ballR,
    required this.tx,
    required this.targetY,
    required this.hitPulse,
    required this.bits,
    required this.aim,
    required this.launch,
  });
  final double bx, by, ballR, tx, targetY, hitPulse;
  final List<_Shard> bits;
  final Offset? aim;
  final Offset launch;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double sx(double x) => x * w;
    double sy(double y) => y * h;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2A1733), Color(0xFF3E1F33)],
          ).createShader(Offset.zero & size));

    // Target board (concentric rings).
    final tc = Offset(sx(tx), sy(targetY));
    final pulse = hitPulse > 0 ? 1 + hitPulse * 0.4 : 1.0;
    const rings = <Color>[
      Color(0xFF2E7D32),
      Color(0xFFFFFFFF),
      Color(0xFF1565C0),
      Color(0xFFD32F2F),
    ];
    final radii = <double>[0.14, 0.1, 0.06, 0.03];
    for (var i = 0; i < rings.length; i++) {
      canvas.drawCircle(tc, radii[i] * w * pulse, Paint()..color = rings[i]);
    }
    canvas.drawCircle(tc, 0.012 * w * pulse, Paint()..color = Colors.yellow);

    // Aim preview.
    if (aim != null && aim!.dy < -0.03) {
      var px = bx, py = by;
      var vx = launch.dx, vy = launch.dy;
      final dot = Paint()..color = Colors.white.withOpacity(0.55);
      for (var i = 0; i < 22; i++) {
        vy += 0.35 * 0.05;
        px += vx * 0.05;
        py += vy * 0.05;
        if (py < 0 || px < 0 || px > 1) break;
        if (i.isEven) canvas.drawCircle(Offset(sx(px), sy(py)), 3, dot);
      }
    }

    // Bean bag.
    final bc = Offset(sx(bx), sy(by));
    final r = ballR * w;
    canvas.drawCircle(bc.translate(1, 2), r, Paint()..color = Colors.black38);
    canvas.drawCircle(bc, r, Paint()..color = const Color(0xFFF4A64B));
    canvas.drawLine(Offset(bc.dx - r, bc.dy), Offset(bc.dx + r, bc.dy),
        Paint()
          ..color = const Color(0xFF8A4B16)
          ..strokeWidth = 2);

    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(sx(s.x), sy(s.y)), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_TargetPainter old) => true;
}

/// Bubble Wrap — a no-fail sensory popper. Tap or drag across the sheet to pop
/// every bubble with a satisfying burst; clear a sheet and a fresh one rolls in.
class BubbleWrapGame extends StatefulWidget {
  const BubbleWrapGame({super.key});
  @override
  State<BubbleWrapGame> createState() => _BubbleWrapGameState();
}

class _BubbleWrapGameState extends State<BubbleWrapGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'bubble_wrap';
  static const int _cols = 7;
  static const int _rows = 10;
  static const int _sheet = _cols * _rows;
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  late List<bool> _popped;
  int _sheetPopped = 0;
  int _total = 0;
  int _best = 0;
  double _refillT = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _popped = List<bool>.filled(_sheet, false);
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.4 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_refillT > 0) {
      _refillT -= dt;
      if (_refillT <= 0) {
        _popped = List<bool>.filled(_sheet, false);
        _sheetPopped = 0;
      }
    }
  }

  void _popAt(Offset p, double w, double h) {
    if (_status != GameStatus.playing || _refillT > 0) return;
    final col = (p.dx / w * _cols).floor();
    final row = (p.dy / h * _rows).floor();
    if (col < 0 || col >= _cols || row < 0 || row >= _rows) return;
    final idx = row * _cols + col;
    if (_popped[idx]) return;
    setState(() {
      _popped[idx] = true;
      _sheetPopped++;
      _total++;
    });
    final cx = (col + 0.5) / _cols, cy = (row + 0.5) / _rows;
    for (var i = 0; i < 6; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.1 + _rnd.nextDouble() * 0.25;
      _bits.add(_Shard(cx, cy, math.cos(a) * sp, math.sin(a) * sp,
          const Color(0xFFBFE3FF)));
    }
    TonePlayer.instance.playCue(SoundCue.bubble);
    if (_total > _best) {
      _best = _total;
      GameScores.instance.submit(_id, _total);
    }
    if (_sheetPopped >= _sheet) {
      emit(ExperienceEvent.bubblePopped);
      TonePlayer.instance.playCue(SoundCue.success);
      _flash('Sheet clear! 🎉 Fresh one coming…');
      _refillT = 1.0;
    }
  }

  void _reset() {
    setState(() {
      _popped = List<bool>.filled(_sheet, false);
      _sheetPopped = 0;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _refillT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🫧 Bubble Wrap',
      introHow:
          'Tap or drag across the sheet to pop every bubble. Clear it and a fresh sheet rolls in — no rush, no fail.',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _sheetPopped,
      best: _best,
      target: _sheet,
      status: _status,
      banner: _banner ?? 'Popped $_sheetPopped/$_sheet · total $_total',
      overEmoji: '🫧',
      overText: 'So satisfying!',
      accent: const Color(0xFF5FB2E6),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _popAt(d.localPosition, w, h),
            onPanStart: (d) => _popAt(d.localPosition, w, h),
            onPanUpdate: (d) => _popAt(d.localPosition, w, h),
            child: CustomPaint(
              painter: _BubbleWrapPainter(
                popped: _popped,
                cols: _cols,
                rows: _rows,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BubbleWrapPainter extends CustomPainter {
  _BubbleWrapPainter({
    required this.popped,
    required this.cols,
    required this.rows,
    required this.bits,
  });
  final List<bool> popped;
  final int cols, rows;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFB9DCEB), Color(0xFF8FC2DC)],
          ).createShader(Offset.zero & size));
    final cw = w / cols, ch = h / rows;
    final r = math.min(cw, ch) * 0.42;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final c = Offset((col + 0.5) * cw, (row + 0.5) * ch);
        if (popped[row * cols + col]) {
          canvas.drawCircle(c, r * 0.8,
              Paint()..color = Colors.black.withOpacity(0.08));
          canvas.drawCircle(c, r * 0.5,
              Paint()..color = Colors.black.withOpacity(0.06));
        } else {
          canvas.drawCircle(c, r,
              Paint()..color = Colors.white.withOpacity(0.55));
          canvas.drawCircle(c, r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = Colors.white.withOpacity(0.8));
          canvas.drawCircle(c.translate(-r * 0.3, -r * 0.3), r * 0.28,
              Paint()..color = Colors.white.withOpacity(0.9));
        }
      }
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 4 * k,
          Paint()..color = s.color.withOpacity(k * 0.8));
    }
  }

  @override
  bool shouldRepaint(_BubbleWrapPainter old) => true;
}

/// Drum Garden — six singing pads. Tap freely to make music, then follow the
/// growing tune (a musical Simon). Match an 8-note tune to win.
class DrumGardenGame extends StatefulWidget {
  const DrumGardenGame({super.key});
  @override
  State<DrumGardenGame> createState() => _DrumGardenGameState();
}

class _DrumGardenGameState extends State<DrumGardenGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'drum_garden';
  static const int _pads = 6;
  static const int _cols = 3;
  static const int _target = 8;
  static const List<int> _notes = <int>[0, 2, 4, 7, 9, 11];
  static const List<Color> _colors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFB84D),
    Color(0xFFFFE066),
    Color(0xFF8CE99A),
    Color(0xFF66D9E8),
    Color(0xFFB197FC),
  ];
  final math.Random _rnd = math.Random();
  final List<int> _seq = <int>[];
  int _inputIdx = 0;
  int _phase = 0; // 0 free, 1 showing, 2 input, 3 result
  int _showIdx = 0;
  double _showT = 0;
  double _nextT = 0;
  int _flashPad = -1;
  double _flashT = 0;
  int _lives = 3;
  int _best = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  void _startRound() {
    _seq.add(_rnd.nextInt(_pads));
    _phase = 1;
    _showIdx = 0;
    _showT = 0.5;
    _inputIdx = 0;
  }

  void _replaySequence() {
    _phase = 1;
    _showIdx = 0;
    _showT = 0.5;
    _inputIdx = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_flashT > 0) {
      _flashT -= dt;
      if (_flashT <= 0) _flashPad = -1;
    }
    if (_phase == 1) {
      _showT -= dt;
      if (_showT <= 0) {
        if (_showIdx < _seq.length) {
          _flashPad = _seq[_showIdx];
          _flashT = 0.4;
          TonePlayer.instance.playNote(_notes[_seq[_showIdx]], seconds: 0.3);
          _showIdx++;
          _showT = 0.62;
        } else {
          _phase = 2;
          _inputIdx = 0;
        }
      }
    } else if (_phase == 3) {
      _nextT -= dt;
      if (_nextT <= 0) _startRound();
    }
  }

  void _tapPad(int i) {
    if (_status != GameStatus.playing) return;
    if (_phase == 1) return; // watching the tune
    _flashPad = i;
    _flashT = 0.3;
    TonePlayer.instance.playNote(_notes[i], seconds: 0.28);
    if (_phase != 2) return; // free play between rounds
    if (i == _seq[_inputIdx]) {
      _inputIdx++;
      if (_inputIdx >= _seq.length) {
        _phase = 3;
        _nextT = 0.8;
        emit(ExperienceEvent.bubblePopped);
        if (_seq.length >= _target) {
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _flash('Nice! 🥁 Tune of ${_seq.length}');
          GameScores.instance.submit(_id, _seq.length).then((b) {
            if (mounted) setState(() => _best = b);
          });
        }
      }
    } else {
      _lives--;
      if (_lives <= 0) {
        _status = GameStatus.over;
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
      } else {
        _flash('Listen again · ${'💛' * _lives}');
        _replaySequence();
      }
    }
  }

  void _reset() {
    setState(() {
      _seq.clear();
      _inputIdx = 0;
      _phase = 0;
      _flashPad = -1;
      _flashT = 0;
      _lives = 3;
      _banner = null;
      _bannerT = 0;
      _nextT = 0;
      _status = GameStatus.playing;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final phaseLabel = _phase == 1
        ? 'Listen… 🎵'
        : _phase == 2
            ? 'Your turn! ${_inputIdx}/${_seq.length}'
            : 'Tap the pads';
    return _Shell(
      title: '🥁 Drum Garden',
      introHow:
          'Tap the singing pads to make music, then repeat the tune you hear. It grows each round!',
      onStart: () => setState(() {
        _status = GameStatus.playing;
        _startRound();
      }),
      score: _seq.isEmpty ? 0 : _seq.length,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? '$phaseLabel · ${'💛' * _lives}',
      overEmoji: '🥁',
      overText: _seq.length >= _target ? 'What a tune!' : 'Keep the beat!',
      accent: const Color(0xFFB197FC),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final col = (d.localPosition.dx / w * _cols).floor();
              final row = (d.localPosition.dy / h * 2).floor();
              final idx = row * _cols + col;
              if (idx >= 0 && idx < _pads) _tapPad(idx);
            },
            child: CustomPaint(
              painter: _DrumPainter(
                cols: _cols,
                pads: _pads,
                colors: _colors,
                flashPad: _flashPad,
                flashT: _flashT,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _DrumPainter extends CustomPainter {
  _DrumPainter({
    required this.cols,
    required this.pads,
    required this.colors,
    required this.flashPad,
    required this.flashT,
  });
  final int cols, pads;
  final List<Color> colors;
  final int flashPad;
  final double flashT;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF241B3A), Color(0xFF15102A)],
          ).createShader(Offset.zero & size));
    final rows = (pads / cols).ceil();
    final cw = w / cols, ch = h / rows;
    for (var i = 0; i < pads; i++) {
      final col = i % cols, row = i ~/ cols;
      final c = Offset((col + 0.5) * cw, (row + 0.5) * ch);
      final r = math.min(cw, ch) * 0.38;
      final lit = flashPad == i ? (flashT / 0.4).clamp(0.0, 1.0) : 0.0;
      canvas.drawCircle(c, r + lit * 10,
          Paint()..color = colors[i].withOpacity(0.25 + lit * 0.4));
      canvas.drawCircle(c, r, Paint()..color = colors[i].withOpacity(0.85));
      canvas.drawCircle(c, r * 0.6,
          Paint()..color = Colors.white.withOpacity(0.15 + lit * 0.5));
      canvas.drawCircle(c, r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withOpacity(0.3 + lit * 0.6));
    }
  }

  @override
  bool shouldRepaint(_DrumPainter old) => true;
}

/// Color Mixer — drop primary paints into the bowl to match the target colour.
/// Teaches mixing (red + yellow = orange) through play. Match eight to win.
class ColorMixerGame extends StatefulWidget {
  const ColorMixerGame({super.key});
  @override
  State<ColorMixerGame> createState() => _ColorMixerGameState();
}

class _ColorMixerGameState extends State<ColorMixerGame> with _Emit {
  static const String _id = 'color_mixer';
  static const int _target = 8;
  // Primaries as (r,g,b) 0..1: red, yellow, blue, white.
  static const List<List<double>> _dye = <List<double>>[
    <double>[0.90, 0.20, 0.22],
    <double>[0.98, 0.85, 0.22],
    <double>[0.20, 0.45, 0.90],
    <double>[0.96, 0.96, 0.96],
  ];
  static const List<String> _dyeName = <String>['Red', 'Yellow', 'Blue', 'White'];
  static const List<Color> _dyeColor = <Color>[
    Color(0xFFE63339),
    Color(0xFFFAD938),
    Color(0xFF3373E6),
    Color(0xFFF5F5F5),
  ];
  // Recipes: name + primary indices.
  static const List<List<int>> _recipes = <List<int>>[
    <int>[0, 1], // orange
    <int>[1, 2], // green
    <int>[0, 2], // purple
    <int>[0, 1, 2], // brown
    <int>[0, 3], // pink
    <int>[2, 3], // sky
  ];
  static const List<String> _recipeName = <String>[
    'Orange', 'Green', 'Purple', 'Brown', 'Pink', 'Sky blue',
  ];
  final math.Random _rnd = math.Random();
  final List<int> _drops = <int>[];
  int _recipe = 0;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  List<double> _mixOf(List<int> drops) {
    if (drops.isEmpty) return <double>[0.96, 0.96, 0.96];
    var r = 0.0, g = 0.0, b = 0.0;
    for (final d in drops) {
      r += _dye[d][0];
      g += _dye[d][1];
      b += _dye[d][2];
    }
    return <double>[r / drops.length, g / drops.length, b / drops.length];
  }

  List<double> get _targetRgb => _mixOf(_recipes[_recipe]);

  Color _toColor(List<double> c) =>
      Color.fromARGB(255, (c[0] * 255).round(), (c[1] * 255).round(),
          (c[2] * 255).round());

  void _newTarget() {
    _recipe = _rnd.nextInt(_recipes.length);
    _drops.clear();
  }

  void _addDrop(int i) {
    if (_status != GameStatus.playing) return;
    setState(() {
      _drops.add(i);
      TonePlayer.instance.playPop(0.6 + _drops.length * 0.03);
      final mix = _mixOf(_drops);
      final t = _targetRgb;
      final dist = math.sqrt(math.pow(mix[0] - t[0], 2) +
          math.pow(mix[1] - t[1], 2) +
          math.pow(mix[2] - t[2], 2));
      if (_drops.length >= 2 && dist < 0.14) {
        _score++;
        _banner = 'Matched ${_recipeName[_recipe]}! 🎨';
        emit(ExperienceEvent.bubblePopped);
        TonePlayer.instance.playCue(SoundCue.success);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        if (_score >= _target) {
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _newTarget();
        }
      }
    });
  }

  void _clearBowl() {
    if (_status != GameStatus.playing) return;
    setState(() => _drops.clear());
  }

  void _reset() {
    setState(() {
      _score = 0;
      _banner = null;
      _newTarget();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final target = _toColor(_targetRgb);
    final mix = _toColor(_mixOf(_drops));
    return _Shell(
      title: '🎨 Color Mixer',
      introHow:
          'Tap the paint drops to pour them in and match the target colour. Red + yellow = orange!',
      onStart: () => setState(() {
        _newTarget();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Make ${_recipeName[_recipe]}',
      overEmoji: '🎨',
      overText: 'Master mixer!',
      accent: const Color(0xFFE0407A),
      onPlayAgain: _reset,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Column(
              children: <Widget>[
                Text('Make ${_recipeName[_recipe]}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: target,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 3),
                  ),
                ),
              ],
            ),
            Column(
              children: <Widget>[
                const Text('Your bowl',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(begin: mix, end: mix),
                  duration: const Duration(milliseconds: 250),
                  builder: (context, c, _) => Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: c ?? mix,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Colors.black38, blurRadius: 8)
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(_drops.isEmpty ? 'empty' : '${_drops.length}',
                        style: TextStyle(
                            color: Colors.black.withOpacity(0.45),
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < _dye.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => _addDrop(i),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _dyeColor[i],
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white70, width: 2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_dyeName[i],
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: _clearBowl,
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
              label: const Text('Empty the bowl',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fishing — tap the water to cast, wait for a nibble, then tap the moment the
/// bobber dips to land the fish. Golden fish are worth more; catch 10 to win.
class FishingGame extends StatefulWidget {
  const FishingGame({super.key});
  @override
  State<FishingGame> createState() => _FishingGameState();
}

class _Fish {
  _Fish(this.x, this.y, this.vx, this.gold);
  double x, y, vx;
  final bool gold;
}

class _FishingGameState extends State<FishingGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'fishing';
  static const int _target = 10;
  static const double _waterTop = 0.42;
  final math.Random _rnd = math.Random();
  final List<_Fish> _fish = <_Fish>[];
  final List<_Shard> _bits = <_Shard>[];
  double _hookX = 0.5;
  final double _hookY = 0.6;
  double _biteT = 0; // >0 while a fish nibbles (tap window)
  bool _biteGold = false;
  double _bobT = 0; // bob animation
  int _score = 0;
  int _best = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  void _spawnFish() {
    final fromLeft = _rnd.nextBool();
    final y = _waterTop + 0.08 + _rnd.nextDouble() * 0.4;
    final speed = 0.08 + _rnd.nextDouble() * 0.12;
    _fish.add(_Fish(fromLeft ? -0.05 : 1.05, y, fromLeft ? speed : -speed,
        _rnd.nextInt(4) == 0));
  }

  double get _window => math.max(0.55, 1.2 - _score * 0.06);

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _bobT += dt;
    while (_fish.length < 4) {
      _spawnFish();
    }
    for (var i = _fish.length - 1; i >= 0; i--) {
      final f = _fish[i];
      f.x += f.vx * dt;
      if (f.x < -0.1 || f.x > 1.1) _fish.removeAt(i);
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.5 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_biteT > 0) {
      _biteT -= dt;
      if (_biteT <= 0) {
        _flash('It got away…');
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
      }
      return;
    }
    // Look for a fish reaching the hook to start a nibble.
    for (final f in _fish) {
      if ((f.x - _hookX).abs() < 0.05 && (f.y - _hookY).abs() < 0.12) {
        _biteT = _window;
        _biteGold = f.gold;
        _fish.remove(f);
        TonePlayer.instance.playCue(SoundCue.bubble);
        break;
      }
    }
  }

  void _tap(Offset p, double w, double h) {
    if (_status != GameStatus.playing) return;
    if (_biteT > 0) {
      final pts = _biteGold ? 3 : 1;
      _score += pts;
      for (var i = 0; i < 14; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard(_hookX, _hookY, math.cos(a) * sp, math.sin(a) * sp,
            _biteGold ? const Color(0xFFFFD166) : const Color(0xFF9BE3FF)));
      }
      _biteT = 0;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _flash(_biteGold ? 'Golden catch! +3 🐟' : 'Caught it! +1 🐟');
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      }
    } else {
      _hookX = (p.dx / w).clamp(0.05, 0.95);
      TonePlayer.instance.playPop(0.5);
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _fish.clear();
      _bits.clear();
      _biteT = 0;
      _hookX = 0.5;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎣 Fishing',
      introHow:
          'Tap the water to move your bobber. When a fish nibbles and the bobber dips, tap fast to catch it!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_biteT > 0 ? 'A bite! Tap now!' : 'Caught $_score/$_target'),
      overEmoji: '🎣',
      overText: 'Reel master!',
      accent: const Color(0xFF2FA7C4),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d.localPosition, w, h),
            child: CustomPaint(
              painter: _FishingPainter(
                waterTop: _waterTop,
                hookX: _hookX,
                hookY: _hookY,
                biteT: _biteT,
                window: _window,
                bobT: _bobT,
                fish: _fish,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _FishingPainter extends CustomPainter {
  _FishingPainter({
    required this.waterTop,
    required this.hookX,
    required this.hookY,
    required this.biteT,
    required this.window,
    required this.bobT,
    required this.fish,
    required this.bits,
  });
  final double waterTop, hookX, hookY, biteT, window, bobT;
  final List<_Fish> fish;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double sx(double x) => x * w;
    double sy(double y) => y * h;
    // Sky.
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, sy(waterTop)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF8FD3F4), Color(0xFFBDE8F7)],
          ).createShader(Rect.fromLTWH(0, 0, w, sy(waterTop))));
    // Water.
    canvas.drawRect(
        Rect.fromLTWH(0, sy(waterTop), w, h - sy(waterTop)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2FA7C4), Color(0xFF12506B)],
          ).createShader(Rect.fromLTWH(0, sy(waterTop), w, h - sy(waterTop))));
    // Surface ripples.
    final surf = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..moveTo(0, sy(waterTop));
    for (var x = 0.0; x <= w; x += 12) {
      path.lineTo(x, sy(waterTop) + math.sin(x / 26 + bobT * 2) * 3);
    }
    canvas.drawPath(path, surf);

    // Fish.
    for (final f in fish) {
      final c = Offset(sx(f.x), sy(f.y));
      final dir = f.vx >= 0 ? 1.0 : -1.0;
      final body = Paint()
        ..color = f.gold ? const Color(0xFFFFD166) : const Color(0xFF7FDBFF);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: w * 0.08, height: w * 0.05), body);
      final tail = Path()
        ..moveTo(c.dx - dir * w * 0.04, c.dy)
        ..lineTo(c.dx - dir * w * 0.07, c.dy - w * 0.025)
        ..lineTo(c.dx - dir * w * 0.07, c.dy + w * 0.025)
        ..close();
      canvas.drawPath(tail, body);
      canvas.drawCircle(
          Offset(c.dx + dir * w * 0.025, c.dy - w * 0.008), 2, Paint()..color = Colors.black87);
    }

    // Line + bobber (dips during a bite).
    final dip = biteT > 0 ? math.sin(bobT * 30) * 0.02 + 0.03 : 0.0;
    final bob = Offset(sx(hookX), sy(hookY + dip));
    canvas.drawLine(Offset(sx(hookX), 0), bob,
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5);
    canvas.drawCircle(bob, w * 0.03, Paint()..color = Colors.white);
    canvas.drawCircle(bob, w * 0.03,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFE23B3B));
    if (biteT > 0) {
      canvas.drawCircle(bob, w * 0.03 + (1 - biteT / window) * w * 0.08,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withOpacity(biteT / window));
    }

    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(sx(s.x), sy(s.y)), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_FishingPainter old) => true;
}

/// Maze Run — swipe to slide the dot through the maze. Grab the key, then reach
/// the glowing exit. Each maze you solve is bigger. Solve five to win.
class MazeRunGame extends StatefulWidget {
  const MazeRunGame({super.key});
  @override
  State<MazeRunGame> createState() => _MazeRunGameState();
}

class _MazeRunGameState extends State<MazeRunGame> with _Emit {
  static const String _id = 'maze_run';
  static const int _target = 5;
  final math.Random _rnd = math.Random();
  int _cols = 5, _rows = 6;
  List<int> _cell = <int>[]; // bitmask: 1=up,2=right,4=down,8=left
  int _px = 0, _py = 0;
  int _exit = 0;
  int _key = 0;
  bool _hasKey = false;
  int _level = 1;
  int _solved = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _genMaze() {
    _cols = (4 + _level).clamp(4, 8);
    _rows = (5 + _level).clamp(5, 10);
    final n = _cols * _rows;
    _cell = List<int>.filled(n, 0);
    final visited = List<bool>.filled(n, false);
    final stack = <int>[0];
    visited[0] = true;
    while (stack.isNotEmpty) {
      final c = stack.last;
      final cx = c % _cols, cy = c ~/ _cols;
      final nb = <List<int>>[];
      if (cy > 0 && !visited[c - _cols]) nb.add(<int>[0, c - _cols]);
      if (cx < _cols - 1 && !visited[c + 1]) nb.add(<int>[1, c + 1]);
      if (cy < _rows - 1 && !visited[c + _cols]) nb.add(<int>[2, c + _cols]);
      if (cx > 0 && !visited[c - 1]) nb.add(<int>[3, c - 1]);
      if (nb.isEmpty) {
        stack.removeLast();
        continue;
      }
      final pick = nb[_rnd.nextInt(nb.length)];
      final dir = pick[0], nIdx = pick[1];
      _cell[c] |= (1 << dir);
      _cell[nIdx] |= (1 << ((dir + 2) % 4));
      visited[nIdx] = true;
      stack.add(nIdx);
    }
    _px = 0;
    _py = 0;
    _exit = n - 1;
    do {
      _key = _rnd.nextInt(n);
    } while (_key == 0 || _key == _exit);
    _hasKey = false;
  }

  void _slide(int dx, int dy) {
    if (_status != GameStatus.playing) return;
    final dir = dy < 0 ? 0 : (dx > 0 ? 1 : (dy > 0 ? 2 : 3));
    var moved = false;
    while (true) {
      final c = _py * _cols + _px;
      if ((_cell[c] & (1 << dir)) == 0) break;
      _px += dx;
      _py += dy;
      moved = true;
      final nc = _py * _cols + _px;
      if (nc == _key && !_hasKey) {
        _hasKey = true;
        TonePlayer.instance.playCue(SoundCue.success);
        _banner = 'Key! 🔑 Now find the exit';
      }
      if (nc == _exit && _hasKey) {
        _solve();
        return;
      }
    }
    if (moved) {
      setState(() {});
      TonePlayer.instance.playPop(0.7);
    }
  }

  void _solve() {
    _solved++;
    _level++;
    emit(ExperienceEvent.bubblePopped);
    TonePlayer.instance.playCue(SoundCue.success);
    GameScores.instance.submit(_id, _solved).then((b) {
      if (mounted) setState(() => _best = b);
    });
    if (_solved >= _target) {
      setState(() {
        _banner = 'Maze master!';
        _status = GameStatus.won;
      });
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else {
      setState(() {
        _banner = 'Solved! Bigger maze…';
        _genMaze();
      });
    }
  }

  void _reset() {
    setState(() {
      _level = 1;
      _solved = 0;
      _banner = null;
      _genMaze();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    if (_cell.isEmpty) _genMaze();
    return _Shell(
      title: '🧩 Maze Run',
      introHow:
          'Swipe up, down, left or right to slide the dot. Grab the key, then reach the glowing exit!',
      onStart: () => setState(() {
        _genMaze();
        _status = GameStatus.playing;
      }),
      score: _solved,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? (_hasKey ? 'Find the exit!' : 'Grab the key 🔑'),
      overEmoji: '🧩',
      overText: 'Maze master!',
      accent: const Color(0xFF7BD389),
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanEnd: (d) {
          final v = d.velocity.pixelsPerSecond;
          if (v.distance < 40) return;
          if (v.dx.abs() > v.dy.abs()) {
            _slide(v.dx > 0 ? 1 : -1, 0);
          } else {
            _slide(0, v.dy > 0 ? 1 : -1);
          }
        },
        child: CustomPaint(
          painter: _MazePainter(
            cols: _cols,
            rows: _rows,
            cell: _cell,
            px: _px,
            py: _py,
            exit: _exit,
            key: _key,
            hasKey: _hasKey,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  _MazePainter({
    required this.cols,
    required this.rows,
    required this.cell,
    required this.px,
    required this.py,
    required this.exit,
    required this.key,
    required this.hasKey,
  });
  final int cols, rows, px, py, exit, key;
  final List<int> cell;
  final bool hasKey;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF14241A));
    if (cell.isEmpty) return;
    final pad = w * 0.06;
    final gw = w - pad * 2, gh = h - pad * 2;
    final cw = gw / cols, ch = gh / rows;
    final wall = Paint()
      ..color = const Color(0xFF7BD389)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    Offset cellTL(int cx, int cy) => Offset(pad + cx * cw, pad + cy * ch);
    // Key.
    if (!hasKey) {
      final kc = Offset(pad + (key % cols + 0.5) * cw, pad + (key ~/ cols + 0.5) * ch);
      canvas.drawCircle(kc, math.min(cw, ch) * 0.22,
          Paint()..color = const Color(0xFFFFD166));
    }
    // Exit.
    final ec = Offset(pad + (exit % cols + 0.5) * cw, pad + (exit ~/ cols + 0.5) * ch);
    canvas.drawCircle(ec, math.min(cw, ch) * 0.36,
        Paint()..color = (hasKey ? const Color(0xFF63E6BE) : Colors.white24));
    // Walls (draw edges that are closed).
    for (var cy = 0; cy < rows; cy++) {
      for (var cx = 0; cx < cols; cx++) {
        final m = cell[cy * cols + cx];
        final tl = cellTL(cx, cy);
        final tr = tl + Offset(cw, 0);
        final bl = tl + Offset(0, ch);
        final br = tl + Offset(cw, ch);
        if (m & 1 == 0) canvas.drawLine(tl, tr, wall); // up
        if (m & 2 == 0) canvas.drawLine(tr, br, wall); // right
        if (m & 4 == 0) canvas.drawLine(bl, br, wall); // down
        if (m & 8 == 0) canvas.drawLine(tl, bl, wall); // left
      }
    }
    // Player dot.
    final pc = Offset(pad + (px + 0.5) * cw, pad + (py + 0.5) * ch);
    canvas.drawCircle(pc, math.min(cw, ch) * 0.3,
        Paint()..color = const Color(0xFFFFE066));
    canvas.drawCircle(pc.translate(-cw * 0.08, -ch * 0.08),
        math.min(cw, ch) * 0.1, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MazePainter old) => true;
}

/// Beat Builder — a 4x8 step sequencer. Tap cells to switch on drums; a
/// playhead loops and plays your beat. Fill the grid for a full groove.
class BeatBuilderGame extends StatefulWidget {
  const BeatBuilderGame({super.key});
  @override
  State<BeatBuilderGame> createState() => _BeatBuilderGameState();
}

class _BeatBuilderGameState extends State<BeatBuilderGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'beat_builder';
  static const int _rowsN = 4;
  static const int _steps = 8;
  static const double _tempo = 0.26;
  static const List<int> _rowNotes = <int>[0, 3, 7, 11];
  static const List<Color> _rowColors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF8CE99A),
    Color(0xFF66D9E8),
  ];
  final List<bool> _grid = List<bool>.filled(_rowsN * _steps, false);
  int _step = 0;
  double _stepT = 0;
  int _active = 0;
  int _best = 0;
  String? _banner;
  double _bannerT = 0;
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
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _stepT += dt;
    if (_stepT >= _tempo) {
      _stepT -= _tempo;
      _step = (_step + 1) % _steps;
      for (var r = 0; r < _rowsN; r++) {
        if (_grid[r * _steps + _step]) {
          TonePlayer.instance.playNote(_rowNotes[r], seconds: 0.18);
        }
      }
    }
  }

  void _toggle(Offset p, double w, double h) {
    if (_status != GameStatus.playing) return;
    final col = (p.dx / w * _steps).floor();
    final row = (p.dy / h * _rowsN).floor();
    if (col < 0 || col >= _steps || row < 0 || row >= _rowsN) return;
    final idx = row * _steps + col;
    setState(() {
      _grid[idx] = !_grid[idx];
      _active = _grid.where((b) => b).length;
      if (_grid[idx]) {
        TonePlayer.instance.playNote(_rowNotes[row], seconds: 0.2);
      }
      if (_active > _best) {
        _best = _active;
        GameScores.instance.submit(_id, _active);
      }
      if (_active == _rowsN * _steps) {
        _banner = 'Full groove! 🔥';
        _bannerT = 1.6;
        emit(ExperienceEvent.bubblePopped);
      }
    });
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < _grid.length; i++) {
        _grid[i] = false;
      }
      _active = 0;
      _step = 0;
      _stepT = 0;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎛️ Beat Builder',
      introHow:
          'Tap the squares to switch drums on and off. The line sweeps across and plays your beat on a loop!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _active,
      best: _best,
      target: _rowsN * _steps,
      status: _status,
      banner: _banner ?? 'Beat: $_active drums on',
      overEmoji: '🎛️',
      overText: 'Nice groove!',
      accent: const Color(0xFF66D9E8),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _toggle(d.localPosition, w, h),
            child: CustomPaint(
              painter: _BeatPainter(
                grid: _grid,
                rows: _rowsN,
                steps: _steps,
                step: _step,
                colors: _rowColors,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BeatPainter extends CustomPainter {
  _BeatPainter({
    required this.grid,
    required this.rows,
    required this.steps,
    required this.step,
    required this.colors,
  });
  final List<bool> grid;
  final int rows, steps, step;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF1A1030));
    final cw = w / steps, ch = h / rows;
    // Playhead column.
    canvas.drawRect(Rect.fromLTWH(step * cw, 0, cw, h),
        Paint()..color = Colors.white.withOpacity(0.10));
    for (var r = 0; r < rows; r++) {
      for (var s = 0; s < steps; s++) {
        final rect = Rect.fromLTWH(s * cw + 3, r * ch + 3, cw - 6, ch - 6);
        final on = grid[r * steps + s];
        final playing = on && s == step;
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            Paint()
              ..color = on
                  ? colors[r].withOpacity(playing ? 1.0 : 0.85)
                  : Colors.white.withOpacity(0.06));
        if (playing) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(9)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BeatPainter old) => true;
}

/// Catch-the-Beat — colour orbs drop in four lanes. Tap a lane the instant its
/// orb crosses the glowing line. Keep a combo and catch 20 to win.
class CatchBeatGame extends StatefulWidget {
  const CatchBeatGame({super.key});
  @override
  State<CatchBeatGame> createState() => _CatchBeatGameState();
}

class _Orb {
  _Orb(this.lane, this.y);
  final int lane;
  double y;
  bool dead = false;
}

class _CatchBeatGameState extends State<CatchBeatGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'catch_beat';
  static const int _lanes = 4;
  static const int _target = 20;
  static const double _hitY = 0.82;
  static const double _window = 0.1;
  static const List<int> _laneNotes = <int>[0, 4, 7, 11];
  static const List<Color> _laneColors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF8CE99A),
    Color(0xFF66D9E8),
  ];
  final math.Random _rnd = math.Random();
  final List<_Orb> _orbs = <_Orb>[];
  final List<_Shard> _bits = <_Shard>[];
  double _spawnT = 0;
  double _fall = 0.55;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _lives = 3;
  int _best = 0;
  int _laneFlash = -1;
  double _laneFlashT = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.2;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_laneFlashT > 0) {
      _laneFlashT -= dt;
      if (_laneFlashT <= 0) _laneFlash = -1;
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    _spawnT -= dt;
    if (_spawnT <= 0) {
      _orbs.add(_Orb(_rnd.nextInt(_lanes), -0.05));
      _spawnT = math.max(0.5, 1.1 - _score * 0.03);
    }
    for (var i = _orbs.length - 1; i >= 0; i--) {
      final o = _orbs[i];
      o.y += _fall * dt;
      if (o.dead) {
        _orbs.removeAt(i);
        continue;
      }
      if (o.y > _hitY + _window) {
        // Missed.
        o.dead = true;
        _combo = 0;
        _lives--;
        _flash('Missed!');
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        if (_lives <= 0) {
          _status = GameStatus.over;
        }
        _orbs.removeAt(i);
      }
    }
  }

  void _tapLane(int lane) {
    if (_status != GameStatus.playing) return;
    _laneFlash = lane;
    _laneFlashT = 0.2;
    _Orb? best;
    var bestDist = 999.0;
    for (final o in _orbs) {
      if (o.lane != lane || o.dead) continue;
      final d = (o.y - _hitY).abs();
      if (d < bestDist) {
        bestDist = d;
        best = o;
      }
    }
    if (best != null && bestDist <= _window) {
      best.dead = true;
      _score++;
      _combo++;
      if (_combo > _bestCombo) _bestCombo = _combo;
      _fall = (0.55 + _score * 0.02).clamp(0.55, 1.1);
      for (var i = 0; i < 10; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard((lane + 0.5) / _lanes, _hitY, math.cos(a) * sp,
            math.sin(a) * sp, _laneColors[lane]));
      }
      TonePlayer.instance.playNote(_laneNotes[lane], seconds: 0.22);
      emit(ExperienceEvent.bubblePopped);
      if (bestDist < _window * 0.4) {
        _flash(_combo >= 3 ? 'Perfect! x$_combo 🔥' : 'Perfect!');
      } else if (_combo >= 3) {
        _flash('Combo x$_combo');
      }
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      }
    }
  }

  void _reset() {
    setState(() {
      _orbs.clear();
      _bits.clear();
      _spawnT = 0;
      _fall = 0.55;
      _score = 0;
      _combo = 0;
      _lives = 3;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎶 Catch the Beat',
      introHow:
          'Orbs fall in four lanes. Tap a lane right when its orb hits the glowing line. Keep your combo!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Caught $_score/$_target · ${'💛' * _lives}',
      overEmoji: '🎶',
      overText: _score >= _target ? 'Rhythm star!' : 'Nice rhythm!',
      accent: const Color(0xFF66D9E8),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _tapLane((d.localPosition.dx / w * _lanes).floor().clamp(0, _lanes - 1)),
            child: CustomPaint(
              painter: _CatchPainter(
                lanes: _lanes,
                hitY: _hitY,
                orbs: _orbs,
                colors: _laneColors,
                laneFlash: _laneFlash,
                laneFlashT: _laneFlashT,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _CatchPainter extends CustomPainter {
  _CatchPainter({
    required this.lanes,
    required this.hitY,
    required this.orbs,
    required this.colors,
    required this.laneFlash,
    required this.laneFlashT,
    required this.bits,
  });
  final int lanes;
  final double hitY;
  final List<_Orb> orbs;
  final List<Color> colors;
  final int laneFlash;
  final double laneFlashT;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF13112A));
    final lw = w / lanes;
    for (var i = 0; i < lanes; i++) {
      if (i.isOdd) {
        canvas.drawRect(Rect.fromLTWH(i * lw, 0, lw, h),
            Paint()..color = Colors.white.withOpacity(0.03));
      }
      if (laneFlash == i) {
        canvas.drawRect(Rect.fromLTWH(i * lw, 0, lw, h),
            Paint()..color = colors[i].withOpacity(laneFlashT / 0.2 * 0.25));
      }
    }
    // Hit line.
    canvas.drawLine(Offset(0, hitY * h), Offset(w, hitY * h),
        Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..strokeWidth = 3);
    for (var i = 0; i < lanes; i++) {
      canvas.drawCircle(Offset((i + 0.5) * lw, hitY * h), lw * 0.3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = colors[i].withOpacity(0.6));
    }
    for (final o in orbs) {
      if (o.dead) continue;
      canvas.drawCircle(Offset((o.lane + 0.5) * lw, o.y * h), lw * 0.3,
          Paint()..color = colors[o.lane]);
      canvas.drawCircle(
          Offset((o.lane + 0.5) * lw - lw * 0.08, o.y * h - lw * 0.08),
          lw * 0.1,
          Paint()..color = Colors.white.withOpacity(0.7));
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_CatchPainter old) => true;
}

/// Firefly Count — count the glowing fireflies and tap the matching number.
/// Gentle number practice; the count grows as you go. Ten right to win.
class FireflyCountGame extends StatefulWidget {
  const FireflyCountGame({super.key});
  @override
  State<FireflyCountGame> createState() => _FireflyCountGameState();
}

class _Fly {
  _Fly(this.x, this.y, this.phase, this.vx, this.vy);
  double x, y, phase, vx, vy;
}

class _FireflyCountGameState extends State<FireflyCountGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'firefly_count';
  static const int _target = 10;
  final math.Random _rnd = math.Random();
  final List<_Fly> _flies = <_Fly>[];
  List<int> _options = <int>[2, 3, 4];
  int _count = 3;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  int _wrongFlash = -1;
  double _wrongT = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newRound() {
    final maxN = (4 + _score ~/ 2).clamp(4, 9);
    _count = 2 + _rnd.nextInt(maxN - 1);
    _flies.clear();
    for (var i = 0; i < _count; i++) {
      _flies.add(_Fly(0.15 + _rnd.nextDouble() * 0.7, 0.12 + _rnd.nextDouble() * 0.5,
          _rnd.nextDouble() * math.pi * 2, (_rnd.nextDouble() - 0.5) * 0.06,
          (_rnd.nextDouble() - 0.5) * 0.06));
    }
    final opts = <int>{_count};
    while (opts.length < 3) {
      final d = _count + _rnd.nextInt(5) - 2;
      if (d >= 1 && d != _count) opts.add(d);
    }
    _options = opts.toList()..shuffle(_rnd);
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_wrongT > 0) {
      _wrongT -= dt;
      if (_wrongT <= 0) _wrongFlash = -1;
    }
    for (final f in _flies) {
      f.phase += dt * 3;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      if (f.x < 0.08 || f.x > 0.92) f.vx = -f.vx;
      if (f.y < 0.1 || f.y > 0.62) f.vy = -f.vy;
    }
  }

  void _pick(int value, int idx) {
    if (_status != GameStatus.playing) return;
    if (value == _count) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Yes! $_count fireflies ✨';
      _bannerT = 1.2;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrongFlash = idx;
      _wrongT = 0.5;
      _lives--;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = 'Count again…';
      _bannerT = 1.0;
      if (_lives <= 0) _status = GameStatus.over;
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _banner = null;
      _bannerT = 0;
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '✨ Firefly Count',
      introHow:
          'Count the glowing fireflies, then tap the number that matches. Get ten right!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'How many fireflies? · ${'💛' * _lives}',
      overEmoji: '✨',
      overText: 'Counting star!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (d.localPosition.dy < h * 0.68) return;
              final i = (d.localPosition.dx / w * 3).floor().clamp(0, 2);
              _pick(_options[i], i);
            },
            child: CustomPaint(
              painter: _FireflyPainter(
                flies: _flies,
                options: _options,
                wrongFlash: _wrongFlash,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _FireflyPainter extends CustomPainter {
  _FireflyPainter({
    required this.flies,
    required this.options,
    required this.wrongFlash,
  });
  final List<_Fly> flies;
  final List<int> options;
  final int wrongFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1B2450), Color(0xFF0C1030)],
          ).createShader(Offset.zero & size));
    for (final f in flies) {
      final glow = 0.6 + 0.4 * math.sin(f.phase);
      final c = Offset(f.x * w, f.y * h);
      canvas.drawCircle(c, 14 * glow,
          Paint()..color = const Color(0xFFFFF3B0).withOpacity(0.25 * glow));
      canvas.drawCircle(c, 6, Paint()..color = const Color(0xFFFFE066));
    }
    // Number pads.
    final padTop = h * 0.7;
    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(w * (i / 3) + 10, padTop, w / 3 - 20, h * 0.26);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(16)),
          Paint()
            ..color = wrongFlash == i
                ? const Color(0xFFE23B3B)
                : Colors.white.withOpacity(0.12));
      final tp = TextPainter(
        text: TextSpan(
            text: '${options[i]}',
            style: const TextStyle(
                color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_FireflyPainter old) => true;
}

/// Sorting Train — each parcel is a colour. Tap the wagon that matches to load
/// it. Sort twelve parcels to complete the train.
class SortingTrainGame extends StatefulWidget {
  const SortingTrainGame({super.key});
  @override
  State<SortingTrainGame> createState() => _SortingTrainGameState();
}

class _SortingTrainGameState extends State<SortingTrainGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'sorting_train';
  static const int _target = 12;
  static const List<Color> _colors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
  ];
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  int _item = 0;
  double _bob = 0;
  int _score = 0;
  int _best = 0;
  int _wrongFlash = -1;
  double _wrongT = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _item = _rnd.nextInt(_colors.length);
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _bob += dt * 2;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_wrongT > 0) {
      _wrongT -= dt;
      if (_wrongT <= 0) _wrongFlash = -1;
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.5 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
  }

  void _drop(int wagon) {
    if (_status != GameStatus.playing) return;
    if (wagon == _item) {
      _score++;
      for (var i = 0; i < 12; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard((wagon + 0.5) / _colors.length, 0.8, math.cos(a) * sp,
            math.sin(a) * sp, _colors[wagon]));
      }
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Loaded! 🚃';
      _bannerT = 1.0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _item = _rnd.nextInt(_colors.length);
      }
    } else {
      _wrongFlash = wagon;
      _wrongT = 0.4;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = 'Match the colour!';
      _bannerT = 1.0;
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _item = _rnd.nextInt(_colors.length);
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🚂 Sorting Train',
      introHow:
          'A coloured parcel floats on top. Tap the wagon with the same colour to load it!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Load $_score/$_target parcels',
      overEmoji: '🚂',
      overText: 'All aboard!',
      accent: const Color(0xFF63E6BE),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (d.localPosition.dy < h * 0.62) return;
              final i = (d.localPosition.dx / w * _colors.length)
                  .floor()
                  .clamp(0, _colors.length - 1);
              _drop(i);
            },
            child: CustomPaint(
              painter: _TrainPainter(
                colors: _colors,
                item: _item,
                bob: _bob,
                wrongFlash: _wrongFlash,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _TrainPainter extends CustomPainter {
  _TrainPainter({
    required this.colors,
    required this.item,
    required this.bob,
    required this.wrongFlash,
    required this.bits,
  });
  final List<Color> colors;
  final int item;
  final double bob;
  final int wrongFlash;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF162032));
    // Parcel floating on top.
    final pc = Offset(w * 0.5, h * 0.3 + math.sin(bob) * 8);
    final box = Rect.fromCenter(center: pc, width: w * 0.18, height: w * 0.18);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(10)),
        Paint()..color = colors[item]);
    canvas.drawLine(Offset(box.left, pc.dy), Offset(box.right, pc.dy),
        Paint()..color = Colors.white70..strokeWidth = 3);
    canvas.drawLine(Offset(pc.dx, box.top), Offset(pc.dx, box.bottom),
        Paint()..color = Colors.white70..strokeWidth = 3);
    // Wagons.
    final lw = w / colors.length;
    for (var i = 0; i < colors.length; i++) {
      final rect = Rect.fromLTWH(i * lw + 8, h * 0.68, lw - 16, h * 0.22);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()..color = colors[i].withOpacity(wrongFlash == i ? 0.4 : 0.9));
      // wheels
      canvas.drawCircle(Offset(rect.left + lw * 0.25, rect.bottom + 8), 7,
          Paint()..color = Colors.black54);
      canvas.drawCircle(Offset(rect.right - lw * 0.25, rect.bottom + 8), 7,
          Paint()..color = Colors.black54);
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_TrainPainter old) => true;
}

void _paintPolyShape(Canvas canvas, Offset c, double r, int shape, Paint p) {
  switch (shape) {
    case 0: // circle
      canvas.drawCircle(c, r, p);
    case 1: // square
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: r * 1.8, height: r * 1.8),
              const Radius.circular(6)),
          p);
    case 2: // triangle
      final tri = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy + r * 0.8)
        ..lineTo(c.dx - r, c.dy + r * 0.8)
        ..close();
      canvas.drawPath(tri, p);
    case 3: // star
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final rr = i.isEven ? r : r * 0.45;
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
        i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
      }
      star.close();
      canvas.drawPath(star, p);
    case 4: // heart
      final heart = Path()..moveTo(c.dx, c.dy + r * 0.7);
      heart.cubicTo(c.dx + r * 1.4, c.dy - r * 0.4, c.dx + r * 0.4,
          c.dy - r * 1.1, c.dx, c.dy - r * 0.35);
      heart.cubicTo(c.dx - r * 0.4, c.dy - r * 1.1, c.dx - r * 1.4,
          c.dy - r * 0.4, c.dx, c.dy + r * 0.7);
      canvas.drawPath(heart, p);
    case 5: // diamond
      final dia = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 0.8, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r * 0.8, c.dy)
        ..close();
      canvas.drawPath(dia, p);
  }
}

/// Shadow Match — a bright shape sits on top. Tap its matching shadow below.
/// Visual matching that gets trickier. Ten right to win.
class ShadowMatchGame extends StatefulWidget {
  const ShadowMatchGame({super.key});
  @override
  State<ShadowMatchGame> createState() => _ShadowMatchGameState();
}

class _ShadowMatchGameState extends State<ShadowMatchGame> with _Emit {
  static const String _id = 'shadow_match';
  static const int _target = 10;
  static const List<Color> _tint = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
    Color(0xFFB197FC),
    Color(0xFFFF9E00),
  ];
  final math.Random _rnd = math.Random();
  int _shape = 0;
  Color _shapeColor = _tint[0];
  List<int> _options = <int>[0, 1, 2, 3];
  int _answer = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  int _wrongFlash = -1;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _newRound();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newRound() {
    _shape = _rnd.nextInt(6);
    _shapeColor = _tint[_rnd.nextInt(_tint.length)];
    final opts = <int>{_shape};
    while (opts.length < 4) {
      opts.add(_rnd.nextInt(6));
    }
    _options = opts.toList()..shuffle(_rnd);
    _answer = _options.indexOf(_shape);
    _wrongFlash = -1;
  }

  void _pick(int idx) {
    if (_status != GameStatus.playing) return;
    if (idx == _answer) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Match! 🌟';
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrongFlash = idx;
      _lives--;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = 'Look at the shape…';
      if (_lives <= 0) _status = GameStatus.over;
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _banner = null;
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🫥 Shadow Match',
      introHow:
          'A bright shape is on top. Tap the shadow underneath that has the same shape!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Find the shadow · ${'💛' * _lives}',
      overEmoji: '🫥',
      overText: 'Sharp eyes!',
      accent: const Color(0xFFB197FC),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (d.localPosition.dy < h * 0.5) return;
              final i = (d.localPosition.dx / w * 4).floor().clamp(0, 3);
              _pick(i);
            },
            child: CustomPaint(
              painter: _ShadowPainter(
                shape: _shape,
                shapeColor: _shapeColor,
                options: _options,
                wrongFlash: _wrongFlash,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _ShadowPainter extends CustomPainter {
  _ShadowPainter({
    required this.shape,
    required this.shapeColor,
    required this.options,
    required this.wrongFlash,
  });
  final int shape;
  final Color shapeColor;
  final List<int> options;
  final int wrongFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2A2140), Color(0xFF17122A)],
          ).createShader(Offset.zero & size));
    // The bright shape.
    _paintPolyShape(canvas, Offset(w * 0.5, h * 0.26), w * 0.12, shape,
        Paint()..color = shapeColor);
    // Shadow options along the bottom.
    final lw = w / 4;
    for (var i = 0; i < 4; i++) {
      final c = Offset((i + 0.5) * lw, h * 0.72);
      if (wrongFlash == i) {
        canvas.drawCircle(c, w * 0.13,
            Paint()..color = const Color(0xFFE23B3B).withOpacity(0.4));
      }
      _paintPolyShape(canvas, c, w * 0.1, options[i],
          Paint()..color = Colors.black.withOpacity(0.72));
    }
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => true;
}

/// Pattern Weaver — a repeating bead pattern with one bead missing. Tap the
/// colour that comes next. Patterns get longer. Ten right to win.
class PatternWeaverGame extends StatefulWidget {
  const PatternWeaverGame({super.key});
  @override
  State<PatternWeaverGame> createState() => _PatternWeaverGameState();
}

class _PatternWeaverGameState extends State<PatternWeaverGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'pattern_weaver';
  static const int _target = 10;
  static const List<Color> _palette = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
  ];
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  List<int> _pattern = <int>[0, 1];
  int _visible = 4;
  int _answer = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  int _wrongFlash = -1;
  double _wrongT = 0;
  double _pop = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int get _colorCount => _score >= 6 ? 4 : 3;

  void _newRound() {
    final period = 2 + _rnd.nextInt(_score >= 4 ? 3 : 2); // 2..4
    _pattern = <int>[];
    for (var i = 0; i < period; i++) {
      int c;
      do {
        c = _rnd.nextInt(_colorCount);
      } while (i > 0 && c == _pattern[i - 1] && period > 2);
      _pattern.add(c);
    }
    _visible = period * 2;
    _answer = _pattern[_visible % period];
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_wrongT > 0) {
      _wrongT -= dt;
      if (_wrongT <= 0) _wrongFlash = -1;
    }
    if (_pop > 0) _pop -= dt;
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
  }

  void _pick(int color, int idx) {
    if (_status != GameStatus.playing) return;
    if (color == _answer) {
      _score++;
      _pop = 0.4;
      for (var i = 0; i < 12; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard(0.5, 0.32, math.cos(a) * sp, math.sin(a) * sp,
            _palette[color]));
      }
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'You wove it! 🧶';
      _bannerT = 1.0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrongFlash = idx;
      _wrongT = 0.5;
      _lives--;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = 'Look at the pattern…';
      _bannerT = 1.0;
      if (_lives <= 0) _status = GameStatus.over;
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _banner = null;
      _bannerT = 0;
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🧶 Pattern Weaver',
      introHow:
          'Look at the repeating colours, then tap the one that comes next in the pattern!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'What comes next? · ${'💛' * _lives}',
      overEmoji: '🧶',
      overText: 'Pattern pro!',
      accent: const Color(0xFF63E6BE),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (d.localPosition.dy < h * 0.6) return;
              final i =
                  (d.localPosition.dx / w * _colorCount).floor().clamp(0, _colorCount - 1);
              _pick(i, i);
            },
            child: CustomPaint(
              painter: _PatternPainter(
                palette: _palette,
                pattern: _pattern,
                visible: _visible,
                colorCount: _colorCount,
                wrongFlash: _wrongFlash,
                pop: _pop,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.palette,
    required this.pattern,
    required this.visible,
    required this.colorCount,
    required this.wrongFlash,
    required this.pop,
    required this.bits,
  });
  final List<Color> palette;
  final List<int> pattern;
  final int visible, colorCount, wrongFlash;
  final double pop;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1E2A3A), Color(0xFF131C28)],
          ).createShader(Offset.zero & size));
    final period = pattern.length;
    final n = visible + 1;
    final slot = w / (n + 1);
    final r = math.min(slot * 0.38, h * 0.08);
    final y = h * 0.32;
    // String line.
    canvas.drawLine(Offset(slot * 0.5, y), Offset(w - slot * 0.5, y),
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 2);
    for (var i = 0; i < n; i++) {
      final cx = slot * (i + 1);
      if (i < visible) {
        canvas.drawCircle(Offset(cx, y), r,
            Paint()..color = palette[pattern[i % period]]);
        canvas.drawCircle(Offset(cx, y), r * 0.4,
            Paint()..color = Colors.white.withOpacity(0.25));
      } else {
        // The missing bead.
        final pr = r * (1 + pop * 0.6);
        canvas.drawCircle(Offset(cx, y), pr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white70);
        final tp = TextPainter(
          text: const TextSpan(
              text: '?',
              style: TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, y - tp.height / 2));
      }
    }
    // Option pads.
    final padTop = h * 0.62;
    final pw = w / colorCount;
    for (var i = 0; i < colorCount; i++) {
      final rect = Rect.fromLTWH(i * pw + 10, padTop, pw - 20, h * 0.3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(16)),
          Paint()
            ..color = wrongFlash == i
                ? const Color(0xFFE23B3B)
                : palette[i]);
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => true;
}

/// Balloon Math — solve the sum by tapping the balloon with the right answer.
/// Balloons drift up; addition then subtraction. Ten right to win.
class BalloonMathGame extends StatefulWidget {
  const BalloonMathGame({super.key});
  @override
  State<BalloonMathGame> createState() => _BalloonMathGameState();
}

class _Balloon {
  _Balloon(this.x, this.y, this.value, this.color, this.sway);
  double x, y;
  final int value;
  final Color color;
  final double sway;
}

class _BalloonMathGameState extends State<BalloonMathGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'balloon_math';
  static const int _target = 10;
  static const List<Color> _colors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
    Color(0xFFB197FC),
  ];
  final math.Random _rnd = math.Random();
  final List<_Balloon> _balloons = <_Balloon>[];
  final List<_Shard> _bits = <_Shard>[];
  int _a = 1, _b = 1;
  bool _sub = false;
  int _answer = 2;
  double _t = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newProblem() {
    _sub = _score >= 5 && _rnd.nextBool();
    if (_sub) {
      _a = 2 + _rnd.nextInt(8);
      _b = 1 + _rnd.nextInt(_a);
      _answer = _a - _b;
    } else {
      _a = 1 + _rnd.nextInt(6);
      _b = 1 + _rnd.nextInt(6);
      _answer = _a + _b;
    }
    _balloons.clear();
    final values = <int>{_answer};
    while (values.length < 4) {
      final d = _answer + _rnd.nextInt(7) - 3;
      if (d >= 0 && d != _answer) values.add(d);
    }
    final vlist = values.toList()..shuffle(_rnd);
    for (var i = 0; i < vlist.length; i++) {
      _balloons.add(_Balloon(0.18 + i * 0.22, 0.6 + _rnd.nextDouble() * 0.5,
          vlist[i], _colors[i % _colors.length], _rnd.nextDouble() * math.pi * 2));
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
    for (final b in _balloons) {
      b.y -= dt * 0.12;
      b.x += math.sin(_t * 1.5 + b.sway) * dt * 0.02;
      if (b.y < -0.1) b.y = 1.1; // wrap, keep the answer in play
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
    }
  }

  void _tap(Offset p, double w, double h) {
    if (_status != GameStatus.playing) return;
    for (final b in _balloons) {
      if ((b.x - p.dx / w).abs() < 0.1 && (b.y - p.dy / h).abs() < 0.1) {
        if (b.value == _answer) {
          _score++;
          for (var i = 0; i < 14; i++) {
            final a = _rnd.nextDouble() * math.pi * 2;
            final sp = 0.15 + _rnd.nextDouble() * 0.35;
            _bits.add(_Shard(b.x, b.y, math.cos(a) * sp, math.sin(a) * sp, b.color));
          }
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.bubblePopped);
          _banner = 'Pop! $_a ${_sub ? '−' : '+'} $_b = $_answer';
          _bannerT = 1.2;
          GameScores.instance.submit(_id, _score).then((v) {
            if (mounted) setState(() => _best = v);
          });
          if (_score >= _target) {
            _status = GameStatus.won;
            TonePlayer.instance.playCue(SoundCue.gameStart);
            emit(ExperienceEvent.gameCompleted);
          } else {
            _newProblem();
          }
        } else {
          _lives--;
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
          _banner = 'Try again…';
          _bannerT = 1.0;
          if (_lives <= 0) _status = GameStatus.over;
        }
        setState(() {});
        return;
      }
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _newProblem();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎈 Balloon Math',
      introHow:
          'Work out the sum, then pop the balloon with the right answer before it floats away!',
      onStart: () => setState(() {
        _newProblem();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? '$_a ${_sub ? '−' : '+'} $_b = ?  · ${'💛' * _lives}',
      overEmoji: '🎈',
      overText: 'Math whiz!',
      accent: const Color(0xFFFF6B6B),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d.localPosition, w, h),
            child: CustomPaint(
              painter: _BalloonMathPainter(
                a: _a,
                b: _b,
                sub: _sub,
                balloons: _balloons,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BalloonMathPainter extends CustomPainter {
  _BalloonMathPainter({
    required this.a,
    required this.b,
    required this.sub,
    required this.balloons,
    required this.bits,
  });
  final int a, b;
  final bool sub;
  final List<_Balloon> balloons;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF9BD7F0), Color(0xFFD9F0FA)],
          ).createShader(Offset.zero & size));
    for (final b in balloons) {
      final c = Offset(b.x * w, b.y * h);
      canvas.drawLine(c, c + Offset(0, h * 0.06),
          Paint()..color = Colors.white70..strokeWidth = 1.5);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: w * 0.15, height: w * 0.18),
          Paint()..color = b.color);
      canvas.drawOval(
          Rect.fromCenter(
              center: c.translate(-w * 0.03, -w * 0.04),
              width: w * 0.04,
              height: w * 0.05),
          Paint()..color = Colors.white.withOpacity(0.5));
      final tp = TextPainter(
        text: TextSpan(
            text: '${b.value}',
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
    // Problem card.
    final card = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.12), width: w * 0.5, height: h * 0.1);
    canvas.drawRRect(RRect.fromRectAndRadius(card, const Radius.circular(14)),
        Paint()..color = Colors.white.withOpacity(0.9));
    final tp = TextPainter(
      text: TextSpan(
          text: '$a ${sub ? '−' : '+'} $b = ?',
          style: const TextStyle(
              color: Color(0xFF123050), fontSize: 30, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, card.center - Offset(tp.width / 2, tp.height / 2));
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 4 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_BalloonMathPainter old) => true;
}

/// Dot-to-Dot — tap the numbered dots in order to draw the hidden shape. Each
/// finished picture has more dots. Complete five to win.
class DotToDotGame extends StatefulWidget {
  const DotToDotGame({super.key});
  @override
  State<DotToDotGame> createState() => _DotToDotGameState();
}

class _DotToDotGameState extends State<DotToDotGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'dot_to_dot';
  static const int _target = 5;
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  List<Offset> _dots = <Offset>[];
  int _next = 0;
  int _fig = 0;
  int _score = 0;
  int _best = 0;
  double _pulse = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _buildFigure() {
    // Points around a circle; star alternates radius. More points each figure.
    final count = 3 + _fig; // 3,4,5,6,7
    final star = _fig >= 2;
    _dots = <Offset>[];
    final pts = star ? count * 2 : count;
    for (var i = 0; i < pts; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / pts;
      final rr = star && i.isOdd ? 0.16 : 0.32;
      _dots.add(Offset(0.5 + math.cos(a) * rr, 0.42 + math.sin(a) * rr * 1.1));
    }
    _next = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _pulse += dt * 4;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
    }
  }

  void _tap(Offset p, double w, double h) {
    if (_status != GameStatus.playing || _next >= _dots.length) return;
    final target = _dots[_next];
    if ((target.dx - p.dx / w).abs() < 0.08 && (target.dy - p.dy / h).abs() < 0.08) {
      _next++;
      TonePlayer.instance.playNote(2 + _next, seconds: 0.14);
      if (_next >= _dots.length) {
        _score++;
        for (var i = 0; i < 18; i++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.15 + _rnd.nextDouble() * 0.4;
          _bits.add(_Shard(0.5, 0.42, math.cos(a) * sp, math.sin(a) * sp,
              const Color(0xFFFFD166)));
        }
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.bubblePopped);
        _banner = 'Picture done! 🎉';
        _bannerT = 1.2;
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        if (_score >= _target) {
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _fig++;
          _buildFigure();
        }
      }
      setState(() {});
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _fig = 0;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _buildFigure();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    if (_dots.isEmpty) _buildFigure();
    return _Shell(
      title: '🔢 Dot-to-Dot',
      introHow:
          'Tap the numbered dots in order — 1, 2, 3… — to draw the hidden picture!',
      onStart: () => setState(() {
        _buildFigure();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Tap dot ${_next + 1}',
      overEmoji: '🔢',
      overText: 'Artist!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d.localPosition, w, h),
            child: CustomPaint(
              painter: _DotPainter(
                dots: _dots,
                next: _next,
                pulse: _pulse,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.dots,
    required this.next,
    required this.pulse,
    required this.bits,
  });
  final List<Offset> dots;
  final int next;
  final double pulse;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF20283A), Color(0xFF141A28)],
          ).createShader(Offset.zero & size));
    Offset sp(Offset o) => Offset(o.dx * w, o.dy * h);
    // Connected lines.
    final line = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < next; i++) {
      canvas.drawLine(sp(dots[i - 1]), sp(dots[i]), line);
    }
    if (next == dots.length && dots.isNotEmpty) {
      canvas.drawLine(sp(dots.last), sp(dots.first), line);
    }
    // Dots.
    for (var i = 0; i < dots.length; i++) {
      final c = sp(dots[i]);
      final done = i < next;
      final isNext = i == next;
      final r = isNext ? 16 + math.sin(pulse) * 3 : 13.0;
      canvas.drawCircle(c, r,
          Paint()..color = done
              ? const Color(0xFFFFD166)
              : (isNext ? Colors.white : Colors.white54));
      if (!done) {
        final tp = TextPainter(
          text: TextSpan(
              text: '${i + 1}',
              style: TextStyle(
                  color: isNext ? Colors.black : const Color(0xFF20283A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 4 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => true;
}

