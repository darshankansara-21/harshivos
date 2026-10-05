part of '../arcade_games.dart';

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
  // Real pinball flippers stay raised as long as the button is held, not
  // just for a fixed flash. Track which finger(s) are currently holding each
  // side independently so two-finger simultaneous flips both register (a
  // single GestureDetector tap recognizer only tracks one primary pointer
  // at a time and would silently drop a genuinely simultaneous second flip).
  final Set<int> _leftHeldPointers = <int>{};
  final Set<int> _rightHeldPointers = <int>{};
  double _flashT = 0;
  int _flashBumper = -1;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Rapid, back-to-back bumper hits build a combo multiplier that fades if
  // the ball drifts away from the bumpers for too long — rewards keeping the
  // ball alive in the "pinball storm" at the top of the table, like a real
  // table's chained-shot bonus.
  int _combo = 0;
  double _comboT = 0;

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
    if (_comboT > 0) {
      _comboT -= dt;
      if (_comboT <= 0) _combo = 0;
    }
    // While a side is actually held, snap its flipper fully up and keep it
    // there — a real flipper stays raised the whole time the button is down,
    // so a child can hold it to catch/trap a rolling ball, not just tap it.
    // Only decay back down once every finger on that side has lifted.
    if (_leftHeldPointers.isNotEmpty) {
      _leftT = 1;
    } else if (_leftT > 0) {
      _leftT = math.max(0, _leftT - dt * 3.3);
    }
    if (_rightHeldPointers.isNotEmpty) {
      _rightT = 1;
    } else if (_rightT > 0) {
      _rightT = math.max(0, _rightT - dt * 3.3);
    }
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
        // Chaining bumper hits within the combo window builds a multiplier;
        // letting the ball wander for too long resets it to 1x.
        _combo = _comboT > 0 ? _combo + 1 : 1;
        _comboT = 1.1;
        final gain = 10 + (_combo - 1) * 5;
        _score += gain;
        _flashT = 0.25 + (_combo >= 3 ? 0.15 : 0);
        _flashBumper = i;
        final sparkCount = _combo >= 3 ? 14 : 9;
        for (var k = 0; k < sparkCount; k++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.15 + _rnd.nextDouble() * 0.28;
          _sparks.add(_Shard(_bx, _by, math.cos(a) * sp, math.sin(a) * sp,
              const Color(0xFFFFF07C)));
        }
        TonePlayer.instance.playCue(SoundCue.ball);
        emit(ExperienceEvent.bubblePopped);
        _flash(_combo >= 2 ? 'Combo x$_combo! +$gain' : '+$gain');
      }
    }

    // Flipper ramps + centre drain. A resting flipper still blocks a gentle
    // roll (slowRoll), but a ball falling with real speed only bounces back
    // if that side's flipper was actually flipped recently (kick > 0) —
    // otherwise it drains past, same as a missed real-table flip. Without
    // this check tapping was purely cosmetic: the ball auto-bounced off
    // either side regardless of timing, so flipping never mattered outside
    // the narrow centre gap.
    if (_by > 0.86 && _vy > 0) {
      final centreGap = _bx > 0.44 && _bx < 0.56;
      if (!centreGap && _bx > _left && _bx < _right) {
        final leftSide = _bx < 0.5;
        final kick = leftSide ? _leftT : _rightT;
        final slowRoll = _vy < 0.55;
        if (kick > 0 || slowRoll) {
          _by = 0.86;
          _vy = -(0.52 + kick * 0.55);
          _vx += leftSide ? 0.12 : -0.12;
          TonePlayer.instance.playCue(SoundCue.wood);
        }
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
    _combo = 0;
    _comboT = 0;
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

  // Each finger is tracked independently by pointer id so two simultaneous
  // flips (one per hand) both register, and a side only drops once every
  // finger that raised it has actually lifted.
  void _pointerDown(int pointerId, bool left) {
    if (left) {
      _leftHeldPointers.add(pointerId);
    } else {
      _rightHeldPointers.add(pointerId);
    }
    _flip(left);
  }

  void _pointerUp(int pointerId) {
    _leftHeldPointers.remove(pointerId);
    _rightHeldPointers.remove(pointerId);
  }

  void _reset() {
    setState(() {
      _score = 0;
      _balls = 3;
      _combo = 0;
      _comboT = 0;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
      _sparks.clear();
      _leftHeldPointers.clear();
      _rightHeldPointers.clear();
      _leftT = 0;
      _rightT = 0;
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
          'Hold the left or right side to flip — keep holding to catch the ball. Bounce the bumpers and keep the ball alive!',
      onStart: () => setState(() => _status = GameStatus.playing),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _pointerDown(e.pointer, e.localPosition.dx < w / 2),
            onPointerUp: (e) => _pointerUp(e.pointer),
            onPointerCancel: (e) => _pointerUp(e.pointer),
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
