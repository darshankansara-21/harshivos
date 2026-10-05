part of '../arcade_games.dart';

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
  bool _reduceMotion = false;
  double _px = 0.5, _py = 0.5, _pvx = 0, _pvy = 0;
  double _ppx = 0.5, _ppy = 0.84; // player mallet (bottom half)
  double _prevPpx = 0.5, _prevPpy = 0.84;
  double _aix = 0.5, _aiy = 0.16; // ai mallet (top half)
  // The puck/paddle collision below runs in mixed-normalized coordinates (x
  // as a fraction of canvas width, y as a fraction of canvas height), but
  // every circle is drawn with radius scaled only by canvas width (see
  // _HockeyPainter). On a typical taller-than-wide phone, a raw normalized
  // dx/dy distance check builds an invisible hit-ellipse far taller than the
  // circle the child actually sees — the same bug class already fixed in
  // space_dodge/maze_marble/pinball. Track the real aspect ratio so
  // collisions match what's drawn.
  double _aspect = 1.0; // height / width of the last laid-out canvas
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
    final dx = _px - cx;
    // Scale the y delta into the same width-normalized units as dx/minD so
    // the collision distance matches the true pixel circles the painter
    // draws, regardless of device aspect ratio.
    final dy = (_py - cy) * _aspect;
    final d = math.sqrt(dx * dx + dy * dy);
    const minD = _puckR + _paddleR;
    if (d < minD && d > 1e-4) {
      final nx = dx / d, ny = dy / d;
      _px = cx + nx * minD;
      _py = cy + ny * minD / _aspect;
      final vyScaled = vy * _aspect;
      final push = 0.55 + math.max(0.0, vx * nx + vyScaled * ny);
      _pvx = nx * push + vx * 0.3;
      _pvy = (ny * push + vyScaled * 0.3) / _aspect;
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
    final bitCount = _reduceMotion ? 5 : 16;
    for (var i = 0; i < bitCount; i++) {
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
    } else if (_aiScore >= _target) {
      // The match-losing goal must sound distinct from a routine concede,
      // never just the same gentle-retry cue as every other AI score.
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
      _flash('They scored · $_playerScore–$_aiScore');
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
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
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
      overEmoji: '🏒',
      overText: 'Good game! Lost $_playerScore–$_aiScore',
      winEmoji: '🏆',
      winText: 'You win the match!',
      accent: const Color(0xFF28C2D1),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          if (w > 0) _aspect = h / w;
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

