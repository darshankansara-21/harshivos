part of '../arcade_games.dart';

/// Soccer Kick — drag back from the ball and release to strike a free kick past
/// the diving keeper. Aim for the corners; the keeper reads your shot better as
/// you score. Ten goals to win, five misses is full time.
class SoccerKickGame extends StatefulWidget {
  const SoccerKickGame({super.key});
  @override
  State<SoccerKickGame> createState() => _SoccerKickGameState();
}

class _SoccerKickGameState extends State<SoccerKickGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'soccer_kick';
  static const int _target = 10;
  static const double _goalY = 0.18;
  static const double _goalL = 0.26;
  static const double _goalR = 0.74;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Full time!', 'Golden boot!', 'Top scorer!', 'Match winner!',
  ];
  String _winPraise = _winPraisePool[0];
  String _overPraise = _gentleTryAgainPool[0];
  double _bx = 0.5, _by = 0.84, _bvx = 0, _bvy = 0, _spin = 0;
  double _keeperX = 0.5, _keeperTarget = 0.5;
  bool _flying = false;
  bool _dragging = false;
  double _aimX = 0.5, _aimY = 0.84;
  int _score = 0, _misses = 0, _best = 0;
  bool _beatBest = false;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Every other aim-into-a-goal game in the catalog (basketball, air_hockey,
  // penalty_dash) bursts a few shards of colour on a score; this one only
  // ever flashed the "GOAL!" banner text + a sound, flatter than every
  // sibling scoring moment. Mirror the established `_Shard` convention.
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _resetBall() {
    _bx = 0.5;
    _by = 0.84;
    _bvx = 0;
    _bvy = 0;
    _spin = 0;
    _flying = false;
    _keeperTarget = 0.5;
  }

  // The keeper's reach/accuracy only ever escalated within a single run (via
  // `_score`) — a child who has already scored hundreds of career goals
  // faced the exact identical opening-keeper difficulty as their very first
  // kick ever, `_best` tracked purely as a display stat with zero feedback
  // into challenge. Same flat-forever difficulty-curve gap already fixed
  // catalog-wide via capped `_careerPaceRamp`/`_careerDangerRamp` getters
  // (basketball's hoop speed, whack's danger level, etc.) — ramp the
  // keeper's reach and prediction accuracy up a little with career goals,
  // capped well short of unbeatable so Pico's keeper always stays genuinely
  // scoreable, never a wall.
  double get _careerKeeperRamp => (_best * 0.0008).clamp(0.0, 0.05);

  double _keeperReach() =>
      (0.085 + _score * 0.004 + _careerKeeperRamp).clamp(0.085, 0.16);

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _keeperX += (_keeperTarget - _keeperX) * (_flying ? 6.0 : 2.5) * dt;
    _keeperX = _keeperX.clamp(_goalL + 0.03, _goalR - 0.03);
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.5 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_flying) {
      _bvx += _spin * dt;
      _bx += _bvx * dt;
      _by += _bvy * dt;
      if (_bx < 0.04 || _bx > 0.96) {
        _bvx = -_bvx * 0.5;
        _bx = _bx.clamp(0.04, 0.96);
      }
      if (_by <= _goalY) {
        _resolveShot();
      } else if (_by > 0.92) {
        _missShot('Wide!');
      }
    }
    setState(() {});
  }

  void _resolveShot() {
    _flying = false;
    final onTarget = _bx > _goalL && _bx < _goalR;
    final saved = (_bx - _keeperX).abs() < _keeperReach();
    if (onTarget && !saved) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      final n = _reduceMotion ? 4 : 12;
      for (var i = 0; i < n; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard(_bx, _goalY, math.cos(a) * sp, math.sin(a) * sp,
            const Color(0xFF80ED99)));
      }
      _banner = 'GOAL!  ⚽';
      _bannerT = 1.3;
      // Every sibling aim-into-a-goal scorer (basketball, block_blast,
      // skee_ball, dot_to_dot) gives a mid-run score crossing the prior
      // all-time best its own milestone fanfare — this one tracked `_best`
      // but never checked for or celebrated the crossing, leaving every
      // record-breaking goal as flat as a routine one.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (crossedBest) {
        _beatBest = true;
        _banner = 'New personal best! 🏆';
        _bannerT = 1.3;
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_score >= _target) {
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
        return;
      }
      _resetBall();
    } else {
      _missShot(saved ? 'Saved!' : 'Wide!');
    }
  }

  void _missShot(String why) {
    _flying = false;
    _misses++;
    if (_misses >= 5) {
      // The game-ending miss must sound distinct from a routine miss,
      // never just the same gentle-retry cue as every other shot.
      _status = GameStatus.over;
      _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
      _banner = 'Out of shots!';
      _bannerT = 1.2;
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = why;
      _bannerT = 1.2;
      _resetBall();
    }
  }

  // Shared by the real kick and the dotted aim preview so they can never
  // disagree. The ball always launches *upward* toward the goal (vy is
  // forced negative) no matter which way the finger actually sits relative
  // to the ball — the painter used to recompute its own raw (ball - aim)
  // direction for the preview line, which pointed straight back down
  // whenever that vertical sign was flipped to go up for the real shot, so
  // the arrow told the child the exact opposite of where the ball was about
  // to fly. Funnelling both through this one function keeps them identical.
  Offset _launchVel(double dx, double dy) {
    const k = 3.2;
    return Offset(dx * k, -dy.abs() * k - 0.2);
  }

  void _launch() {
    final dx = _bx - _aimX;
    final dy = _by - _aimY;
    final power = math.sqrt(dx * dx + dy * dy);
    if (power < 0.03 || dy <= 0) return; // must pull back/down
    final v = _launchVel(dx, dy);
    _bvx = v.dx;
    _bvy = v.dy;
    _spin = (_rnd.nextDouble() - 0.5) * 0.25 + _bvx * 0.12;
    final t = (_goalY - _by) / _bvy;
    final predX = (_bx + _bvx * t).clamp(_goalL, _goalR);
    final err =
        (0.26 - _score * 0.015 - _careerKeeperRamp * 2).clamp(0.04, 0.26);
    _keeperTarget =
        (predX + (_rnd.nextDouble() - 0.5) * 2 * err).clamp(_goalL + 0.03, _goalR - 0.03);
    // The strike itself was silent — the ball visibly flies for several frames
    // before the goal/miss result plays, so the kick needs its own feedback.
    TonePlayer.instance.playCue(SoundCue.ball);
    _flying = true;
  }

  // Screen-reader bridge: dragging back to aim is a continuous analog
  // gesture a switch/VoiceOver user can't perform. Give them a direct
  // action that pulls back for the far corner, away from the keeper's
  // current position, through the same _aimX/_aimY + _launch path (a
  // slingshot pull: the ball flies *opposite* the pulled-back point).
  void _kickToCorner() {
    if (_flying || _status != GameStatus.playing) return;
    // Keeper on the right → pull back right so the ball flies left, and
    // vice versa, so the shot aims for the corner the keeper isn't in.
    _aimX = _keeperX >= 0.5 ? _bx + 0.22 : _bx - 0.22;
    _aimY = _by - 0.14;
    _launch();
  }

  void _reset() {
    setState(() {
      _score = 0;
      _misses = 0;
      _beatBest = false;
      _banner = null;
      _bannerT = 0;
      _bits.clear();
      _resetBall();
      _keeperX = 0.5;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '⚽ Soccer Kick',
      introHow:
          'Drag back from the ball and let go to shoot. Aim for the corners to '
          'beat the keeper — ten goals to win!',
      onStart: () => setState(() {
        _resetBall();
        _keeperX = 0.5;
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Goals $_score/$_target  ·  ${'🧤' * (5 - _misses)}',
      overEmoji: '💪',
      overText: _overPraise,
      winEmoji: '⚽',
      winText: _winPraise,
      accent: const Color(0xFF80ED99),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return Semantics(
            button: true,
            label: 'Goals $_score of $_target. Tap to kick for the corner '
                'away from the keeper.',
            onTap: _kickToCorner,
            excludeSemantics: true,
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              if (_flying) return;
              _dragging = true;
              _aimX = (d.localPosition.dx / w).clamp(0.0, 1.0);
              _aimY = (d.localPosition.dy / h).clamp(0.0, 1.0);
            },
            onPanUpdate: (d) {
              if (_flying) return;
              _aimX = (d.localPosition.dx / w).clamp(0.0, 1.0);
              _aimY = (d.localPosition.dy / h).clamp(0.0, 1.0);
              setState(() {});
            },
            onPanEnd: (_) {
              if (_flying) return;
              _dragging = false;
              _launch();
            },
            // If the drag is cancelled mid-gesture (onPanEnd never fires),
            // the reticle would otherwise stay frozen in "actively
            // dragging" position forever. Drop back to idle.
            onPanCancel: () {
              if (_flying) return;
              setState(() => _dragging = false);
            },
            child: CustomPaint(
              painter: _SoccerPainter(
                bx: _bx,
                by: _by,
                keeperX: _keeperX,
                goalY: _goalY,
                goalL: _goalL,
                goalR: _goalR,
                dragging: _dragging && !_flying,
                aimX: _aimX,
                aimY: _aimY,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
            ),
          );
        },
      ),
    );
  }
}

class _SoccerPainter extends CustomPainter {
  _SoccerPainter({
    required this.bx,
    required this.by,
    required this.keeperX,
    required this.goalY,
    required this.goalL,
    required this.goalR,
    required this.dragging,
    required this.aimX,
    required this.aimY,
    required this.bits,
  });
  final double bx, by, keeperX, goalY, goalL, goalR, aimX, aimY;
  final bool dragging;
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
            colors: <Color>[Color(0xFF2E7D32), Color(0xFF1B5E20)],
          ).createShader(Offset.zero & size));
    // Mown stripes.
    final stripe = Paint()..color = Colors.white.withOpacity(0.04);
    for (var i = 0; i < 8; i++) {
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(0, h * i / 8, w, h / 8), stripe);
      }
    }
    final gy = goalY * h;
    // Net.
    final netRect = Rect.fromLTRB(goalL * w, gy - h * 0.1, goalR * w, gy);
    final net = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (double x = netRect.left; x <= netRect.right; x += 12) {
      canvas.drawLine(Offset(x, netRect.top), Offset(x, netRect.bottom), net);
    }
    for (double y = netRect.top; y <= netRect.bottom; y += 12) {
      canvas.drawLine(Offset(netRect.left, y), Offset(netRect.right, y), net);
    }
    // Posts + crossbar.
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(goalL * w, gy), Offset(goalL * w, gy - h * 0.1), post);
    canvas.drawLine(Offset(goalR * w, gy), Offset(goalR * w, gy - h * 0.1), post);
    canvas.drawLine(Offset(goalL * w, gy), Offset(goalR * w, gy), post);

    // Keeper.
    final kc = Offset(keeperX * w, gy - h * 0.012);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: kc, width: w * 0.1, height: h * 0.075),
            const Radius.circular(10)),
        Paint()..color = const Color(0xFFFFD166));
    canvas.drawCircle(Offset(kc.dx - w * 0.055, kc.dy), 7,
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(kc.dx + w * 0.055, kc.dy), 7,
        Paint()..color = Colors.white);

    // Aim guide.
    if (dragging) {
      final b = Offset(bx * w, by * h);
      final a = Offset(aimX * w, aimY * h);
      final rawDir = b - a;
      // The real kick's vertical velocity is always -|dy| (see
      // _SoccerKickGameState._launchVel) — it launches upward no matter
      // which way the vertical pull actually points. The preview used to
      // show the raw (ball - aim) vector unconditionally, so for the only
      // drag direction that actually fires a shot (finger above the ball)
      // the arrow pointed straight down, away from the goal, while the ball
      // flew up — telling the child the opposite of what was about to
      // happen. Mirror the same unconditional abs() here so they can never
      // disagree.
      final dir = Offset(rawDir.dx, -rawDir.dy.abs());
      final tip = b + dir * 2.2;
      canvas.drawLine(
          b,
          tip,
          Paint()
            ..color = Colors.white70
            ..strokeWidth = 3);
      canvas.drawCircle(tip, 6, Paint()..color = Colors.white54);
    }

    // Ball.
    final ball = Offset(bx * w, by * h);
    final br = 0.035 * w;
    canvas.drawCircle(
        ball + const Offset(0, 3), br, Paint()..color = Colors.black26);
    canvas.drawCircle(ball, br, Paint()..color = Colors.white);
    final pent = Paint()..color = const Color(0xFF222222);
    canvas.drawCircle(ball, br * 0.3, pent);
    for (var i = 0; i < 5; i++) {
      final a = i / 5 * math.pi * 2 - math.pi / 2;
      canvas.drawCircle(
          ball + Offset(math.cos(a), math.sin(a)) * br * 0.62, br * 0.14, pent);
    }

    for (final b in bits) {
      final k = (b.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(b.x * w, b.y * h), 2 + 3 * k,
          Paint()..color = b.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_SoccerPainter oldDelegate) => true;
}
