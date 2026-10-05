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

  double _bx = 0.5, _by = 0.84, _bvx = 0, _bvy = 0, _spin = 0;
  double _keeperX = 0.5, _keeperTarget = 0.5;
  bool _flying = false;
  bool _dragging = false;
  double _aimX = 0.5, _aimY = 0.84;
  int _score = 0, _misses = 0, _best = 0;
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
    _by = 0.84;
    _bvx = 0;
    _bvy = 0;
    _spin = 0;
    _flying = false;
    _keeperTarget = 0.5;
  }

  double _keeperReach() => (0.085 + _score * 0.004).clamp(0.085, 0.14);

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _keeperX += (_keeperTarget - _keeperX) * (_flying ? 6.0 : 2.5) * dt;
    _keeperX = _keeperX.clamp(_goalL + 0.03, _goalR - 0.03);
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
      _banner = 'GOAL!  ⚽';
      _bannerT = 1.3;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
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
    final err = (0.26 - _score * 0.015).clamp(0.04, 0.26);
    _keeperTarget =
        (predX + (_rnd.nextDouble() - 0.5) * 2 * err).clamp(_goalL + 0.03, _goalR - 0.03);
    // The strike itself was silent — the ball visibly flies for several frames
    // before the goal/miss result plays, so the kick needs its own feedback.
    TonePlayer.instance.playCue(SoundCue.ball);
    _flying = true;
  }

  void _reset() {
    setState(() {
      _score = 0;
      _misses = 0;
      _banner = null;
      _bannerT = 0;
      _resetBall();
      _keeperX = 0.5;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
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
      overText: 'Out of shots — nice try!',
      winEmoji: '⚽',
      winText: 'Full time!',
      accent: const Color(0xFF80ED99),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
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
              ),
              size: Size.infinite,
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
  });
  final double bx, by, keeperX, goalY, goalL, goalR, aimX, aimY;
  final bool dragging;

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
  }

  @override
  bool shouldRepaint(_SoccerPainter oldDelegate) => true;
}
