part of '../arcade_games.dart';

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
