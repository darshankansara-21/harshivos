part of '../arcade_games.dart';

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
  // The rim-knob collision below runs in mixed-normalized coordinates (x as
  // a fraction of canvas width, y as a fraction of canvas height), but the
  // ball is drawn as a true pixel circle scaled only by canvas width (see
  // _BasketPainter). On a typical taller-than-wide phone, a raw normalized
  // distance check builds an invisible hit-ellipse far taller than the ball
  // the child actually sees — the same bug class already fixed in
  // space_dodge/maze_marble/pinball/air_hockey/mini_golf. Track the real
  // aspect ratio so the rim collision matches what's drawn.
  double _aspect = 1.0; // height / width of the last laid-out canvas
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

    // Rim knobs — bouncing off these makes near-misses thrilling. Scale the
    // y delta by the aspect ratio so the collision distance matches the true
    // pixel circle the painter draws, regardless of device aspect ratio.
    for (final sgn in <double>[-1, 1]) {
      final rimX = _hoopX + sgn * _rimHalf;
      final dx = _bx - rimX, dy = (_by - _hoopY) * _aspect;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < _ballR + 0.012 && d > 0.0001) {
        final nx = dx / d, ny = dy / d;
        _bx = rimX + nx * (_ballR + 0.012);
        _by = _hoopY + ny * (_ballR + 0.012) / _aspect;
        final vyScaled = _vy * _aspect;
        final dot = _vx * nx + vyScaled * ny;
        _vx = (_vx - 2 * dot * nx) * 0.6;
        _vy = (vyScaled - 2 * dot * ny) * 0.6 / _aspect;
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
      winEmoji: '🏀',
      winText: 'Nothing but net!',
      accent: const Color(0xFFFF9E00),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          if (w > 0) _aspect = h / w;
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

