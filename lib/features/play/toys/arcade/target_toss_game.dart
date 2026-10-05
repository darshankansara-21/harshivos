part of '../arcade_games.dart';

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
      winEmoji: '🎯',
      winText: 'Sharp shooter!',
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
            // See basketball_game.dart: a cancelled drag never reaches
            // onPanEnd, so clear the aim here too instead of leaving a
            // stuck throw line hanging over the bean bag.
            onPanCancel: () => _aim = null,
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

