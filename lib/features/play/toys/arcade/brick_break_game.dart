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

enum _PowerType { wide, slow, life }

class _PowerUp {
  _PowerUp(this.x, this.y, this.type);
  double x;
  double y;
  final _PowerType type;
}

class _BrickBreakGameState extends State<BrickBreakGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'brick_break';
  static const int _cols = 6;
  // Most bricks are 1-HP, so a non-combo destroy is the dominant routine
  // event — it could fire the exact same "Nice hit!" banner dozens of times
  // in a single run, the same flat-repeated-praise gap already fixed in
  // sky_hop/echo_drums. A small pool keeps every destroy feeling fresh
  // without touching scoring, physics, or combo logic at all.
  static const List<String> _hitPraise = <String>[
    'Nice hit!',
    'Nice shot!',
    'Clean break!',
    'Smashed it!',
    'Good aim!',
  ];
  final math.Random _rnd = math.Random();
  int _rowCount = 4;
  List<int> _bricks = List<int>.filled(_cols * 4, 1);
  final List<_Shard> _shards = <_Shard>[];
  bool _reduceMotion = false;
  final List<_PowerUp> _powerUps = <_PowerUp>[];
  double _paddleX = 0.5; // centre, 0..1
  double _bx = 0.5, _by = 0.6; // ball centre
  double _vx = 0.34, _vy = -0.55; // ball velocity (per second)
  double _speedMul = 1;
  double _wideT = 0; // seconds left of widened paddle
  double _slowT = 0; // seconds left of slowed ball (time-dilated, not re-scaled)
  bool _started = false;
  int _score = 0;
  int _best = 0;
  int _lives = 3;
  int _level = 1;
  int _combo = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Mirrors stack_game/block_blast_game/bubble_shooter_game's live "beat your
  // own all-time best" celebration. Brick Break has no win cap either — level
  // ramps forever and score climbs purely with hits/combos until lives run
  // out — so crossing a prior personal best mid-run deserves the same
  // judgment-free moment.
  bool _beatBest = false;

  static const double _paddleW = 0.24;
  static const double _ballR = 0.022;
  static const int _maxLives = 5;
  double _aspect = 1.0; // height / width of the last laid-out canvas

  double get _effectivePaddleW => _wideT > 0 ? _paddleW * 1.45 : _paddleW;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _buildBricks() {
    // The shared `introHow` card tells every child "Golden bricks need two
    // hits" before their very first serve, but the full-density pattern
    // below never actually turns one on until level 4+ (deliberately, so row
    // count/speed/heavy-bricks escalate one at a time — see _nextLevel). A
    // child playing only their first level or two would never see the
    // mechanic the intro just promised them, a concrete clarity gap. Seed
    // exactly one easy preview golden brick at level 2 — low enough stakes
    // (speed/rows are still their gentlest) that it just teaches the
    // "needs a second hit" idea honestly, without front-loading the later
    // escalation the rest of the pattern is intentionally paced around.
    final previewIdx =
        _level == 2 ? (_rowCount - 1) * _cols + _cols ~/ 2 : -1;
    _bricks = List<int>.generate(_cols * _rowCount, (index) {
      final row = index ~/ _cols;
      final isHeavy = _level > 3 && row >= _rowCount - 2 && (index + _level) % 4 == 0;
      return (isHeavy || index == previewIdx) ? 2 : 1;
    });
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
    _combo = 0;
    // Every lost ball deserves the companion's gentle encouraging
    // reaction, not just the one that happens to end the game.
    emit(ExperienceEvent.incorrectAnswer);
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
    _combo = 0;
    // Space the three escalations apart instead of stacking them all on the
    // same level-up: ball speed only climbs on even levels, row count ramps
    // out early and then holds at its cap, and heavy (2-hit) bricks are
    // introduced one level after row count maxes out — so a child never
    // faces a faster ball, more rows, AND tougher bricks all at once.
    if (_level.isEven) _speedMul = math.min(1.8, _speedMul + 0.12);
    _rowCount = math.min(6, 3 + _level);
    _buildBricks();
    _flash('Level $_level!');
    TonePlayer.instance.playCue(SoundCue.success);
    // Clearing a level is a milestone in this endless, ever-escalating game,
    // not a true run-ending win — the loud `gameCompleted` celebration is
    // reserved for `_loseLife`'s actual high-score-beat gate below. Every
    // level-up firing the full "You did it!" fanfare would be the same
    // mistimed-tier bug already fixed in memory_flip/snack_studio.
    emit(ExperienceEvent.bubblePopped);
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
    if (_wideT > 0) _wideT -= dt;
    if (_slowT > 0) _slowT -= dt;
    for (var i = _powerUps.length - 1; i >= 0; i--) {
      final p = _powerUps[i];
      p.y += 0.22 * dt;
      const paddleY = 0.9;
      if (p.y >= paddleY - 0.02 &&
          p.y <= paddleY + 0.03 &&
          (p.x - _paddleX).abs() < _effectivePaddleW / 2 + 0.03) {
        _collectPowerUp(p.type);
        _powerUps.removeAt(i);
      } else if (p.y > 1) {
        _powerUps.removeAt(i);
      }
    }
    if (!_started) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    // Slow power-up time-dilates the ball only, so paddle/capsule speed stay normal.
    final ballDt = dt * (_slowT > 0 ? 0.62 : 1.0);
    _bx += _vx * ballDt;
    _by += _vy * ballDt;
    // The ball is painted as a true pixel circle of radius `_ballR * w`
    // (width-based, see _BrickPainter). Every y-axis collision margin below
    // must use `_ballRY` (the same pixel radius converted into height-
    // normalized units) instead of `_ballR` directly — otherwise the hitbox
    // is stretched/squashed vertically on any non-square canvas, the same
    // aspect-ratio distortion bug already fixed in several other arcade
    // games (mini_golf, pinball, air_hockey, basketball, maze_marble).
    final ballRY = _ballR / _aspect;
    if (_bx < _ballR) {
      _bx = _ballR;
      _vx = _vx.abs();
    } else if (_bx > 1 - _ballR) {
      _bx = 1 - _ballR;
      _vx = -_vx.abs();
    }
    if (_by < 0.08 + ballRY) {
      _by = 0.08 + ballRY;
      _vy = _vy.abs();
    }
    // Paddle bounce.
    const paddleY = 0.9;
    if (_vy > 0 &&
        _by + ballRY >= paddleY &&
        _by < paddleY + 0.03 &&
        (_bx - _paddleX).abs() < _effectivePaddleW / 2 + _ballR) {
      _vy = -_vy.abs();
      // Steer based on where it hit the paddle.
      _vx += (_bx - _paddleX) * 1.2;
      _vx = _vx.clamp(-0.7, 0.7);
      TonePlayer.instance.playCue(SoundCue.ball);
    }
    // Brick collisions.
    for (var i = 0; i < _bricks.length; i++) {
      if (_bricks[i] <= 0) continue;
      final r = i ~/ _cols;
      final c = i % _cols;
      const bw = 1.0 / _cols;
      final left = c * bw;
      final top = 0.1 + r * 0.05;
      final rect = Rect.fromLTWH(left + 0.008, top, bw - 0.016, 0.042);
      if (_bx > rect.left - _ballR &&
          _bx < rect.right + _ballR &&
          _by > rect.top - ballRY &&
          _by < rect.bottom + ballRY) {
        final remaining = _bricks[i] - 1;
        _bricks[i] = remaining;
        _combo = remaining <= 0 ? _combo + 1 : 0;
        _vy = -_vy.abs();
        _vx += (_bx - (c + 0.5) * bw) * 1.2;
        _vx = _vx.clamp(-0.8, 0.8);
        _score += remaining <= 0 ? 10 + _level * 3 + _combo : 4 + _level;
        final cx = c * (1.0 / _cols) + (1.0 / _cols) / 2;
        final cy = 0.1 + r * 0.05 + 0.021;
        final col =
            HSVColor.fromAHSV(1, (r * 55).toDouble(), 0.6, 0.95).toColor();
        final shardCount = remaining <= 0 ? 9 : 6;
        final effectiveShardCount =
            _reduceMotion ? math.max(3, (shardCount / 3).round()) : shardCount;
        for (var s = 0; s < effectiveShardCount; s++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.25 + _rnd.nextDouble() * 0.35;
          _shards.add(_Shard(
              cx, cy, math.cos(a) * sp, math.sin(a) * sp - 0.1, col));
        }
        if (remaining <= 0) {
          _flash(_combo > 1
              ? 'Combo x$_combo!'
              : _hitPraise[_rnd.nextInt(_hitPraise.length)]);
          TonePlayer.instance.playCue(SoundCue.brick);
          // A destroyed brick has a chance to drop a helpful capsule — turns
          // clearing the field into a real risk/reward decision, not just aim.
          if (_rnd.nextDouble() < 0.16) {
            final roll = _rnd.nextDouble();
            final type = roll < 0.45
                ? _PowerType.wide
                : (roll < 0.85 ? _PowerType.slow : _PowerType.life);
            if (type != _PowerType.life || _lives < _maxLives) {
              _powerUps.add(_PowerUp(cx, cy, type));
            }
          }
        } else {
          _flash('Cracked!');
          TonePlayer.instance.playCue(SoundCue.ball);
        }
        emit(ExperienceEvent.bubblePopped);
        if (_status == GameStatus.playing &&
            !_beatBest &&
            _best > 0 &&
            _score > _best) {
          _beatBest = true;
          // Takes priority over the combo/crack banner just set above — a
          // new all-time record is the bigger moment of the two.
          _flash('New personal best! 🏆');
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted && b != _best) setState(() => _best = b);
        });
        if (!_bricks.any((hp) => hp > 0)) {
          _nextLevel();
        }
        break;
      }
    }
    if (_by > 1) {
      _loseLife();
    }
  }

  void _collectPowerUp(_PowerType type) {
    switch (type) {
      case _PowerType.wide:
        _wideT = 8;
        _flash('Wide paddle!');
        break;
      case _PowerType.slow:
        _slowT = 6;
        _flash('Slow-mo ball!');
        break;
      case _PowerType.life:
        _lives = math.min(_maxLives, _lives + 1);
        _flash('Extra life! ♥');
        break;
    }
    TonePlayer.instance.playCue(SoundCue.success);
    emit(ExperienceEvent.bubblePopped);
  }

  void _aim(double localX, double width) {
    setState(() {
      _started = true;
      _paddleX =
          (localX / width).clamp(_effectivePaddleW / 2, 1 - _effectivePaddleW / 2);
    });
  }

  void _reset() {
    setState(() {
      _level = 1;
      _lives = 3;
      _speedMul = 1;
      _rowCount = 4;
      _combo = 0;
      _wideT = 0;
      _slowT = 0;
      _powerUps.clear();
      _buildBricks();
      _shards.clear();
      _paddleX = 0.5;
      _serveBall();
      _score = 0;
      _banner = null;
      _bannerT = 0;
      _beatBest = false;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final activeIcons = <String>[
      if (_wideT > 0) '↔️',
      if (_slowT > 0) '🐢',
    ].join(' ');
    return _Shell(
      title: '🧱 Brick Break',
      introHow: 'Move the paddle to bounce the ball and smash every brick! '
          'Golden bricks need two hits. Catch falling capsules for a helpful boost. '
          'Missing the ball costs one of your 3 lives.',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner ??
          (_started
              ? '♥ $_lives   ·   Level $_level${activeIcons.isEmpty ? '' : '   ·   $activeIcons'}'
              // "Drag to move · release the ball" was painted only onto the
              // canvas before the first serve, so it was silent to screen
              // readers. Mirroring it into the shared, semantics-announced
              // banner closes that gap without duplicating the on-canvas hint.
              : 'Drag to move · release the ball'),
      overEmoji: '🧱',
      overText: 'Out of balls! Reached Level $_level',
      accent: const Color(0xFFFF6B6B),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          if (w > 0) _aspect = constraints.maxHeight / w;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => _aim(d.localPosition.dx, constraints.maxWidth),
            onPanDown: (d) => _aim(d.localPosition.dx, constraints.maxWidth),
            child: CustomPaint(
              painter: _BrickPainter(_bricks, _cols, _paddleX,
                  _effectivePaddleW, _bx, _by, _ballR, _started, _shards,
                  _powerUps),
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
      this.by, this.ballR, this.started, this.shards, this.powerUps);
  final List<int> bricks;
  final int cols;
  final double paddleX;
  final double paddleW;
  final double bx;
  final double by;
  final double ballR;
  final bool started;
  final List<_Shard> shards;
  final List<_PowerUp> powerUps;

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
      if (bricks[i] <= 0) continue;
      final r = i ~/ cols;
      final c = i % cols;
      final left = (c * bw + 0.008) * w;
      final top = (0.1 + r * 0.05) * h;
      final strength = bricks[i];
      final brickW = (bw - 0.016) * w;
      final brickH = 0.042 * h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, brickW, brickH),
            const Radius.circular(4)),
        Paint()
          ..color = (strength > 1
                  ? const Color(0xFFFFC857)
                  : HSVColor.fromAHSV(1, (r * 55).toDouble(), 0.6, 0.95).toColor())
          ..strokeWidth = strength > 1 ? 2 : 1
          ..style = PaintingStyle.fill,
      );
      if (strength > 1) {
        final hpPainter = TextPainter(
          text: TextSpan(
              text: '2',
              style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr,
        )..layout();
        hpPainter.paint(canvas, Offset(left + brickW / 2 - hpPainter.width / 2, top + brickH / 2 - hpPainter.height / 2));
      }
    }
    // Falling power-up capsules.
    for (final p in powerUps) {
      final c = Offset(p.x * w, p.y * h);
      final color = switch (p.type) {
        _PowerType.wide => const Color(0xFF4CC9F0),
        _PowerType.slow => const Color(0xFF9B5DE5),
        _PowerType.life => const Color(0xFFFF6B9D),
      };
      final label = switch (p.type) {
        _PowerType.wide => '↔',
        _PowerType.slow => '🐢',
        _PowerType.life => '♥',
      };
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: w * 0.052, height: w * 0.052),
              const Radius.circular(6)),
          Paint()..color = color);
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
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
