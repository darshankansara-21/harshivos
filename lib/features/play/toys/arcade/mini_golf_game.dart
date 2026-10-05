part of '../arcade_games.dart';

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
  // A second obstacle joins from hole 6 onward so the back half of the round
  // keeps getting harder instead of plateauing at the hole-3 difficulty.
  Rect? _wall2;
  bool _moving = false;
  // The cup-sink distance check and rail-obstacle margins below run in
  // mixed-normalized coordinates (x as a fraction of canvas width, y as a
  // fraction of canvas height), but every circle is drawn with radius scaled
  // only by canvas width (see _GolfPainter). On a typical taller-than-wide
  // phone, a raw normalized distance check builds an invisible region far
  // taller than what the child actually sees — the same bug class already
  // fixed in space_dodge/maze_marble/pinball/air_hockey. Track the real
  // aspect ratio so collisions match what's drawn.
  double _aspect = 1.0; // height / width of the last laid-out canvas
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
    // A second rail joins from hole 6 onward, placed on the opposite side of
    // the green from the first so late holes genuinely need two bank shots
    // instead of the same single-obstacle puzzle repeated for 7 holes.
    if (_hole >= 6) {
      final ww2 = 0.14 + _rnd.nextDouble() * 0.16;
      final wx2 = (0.5 - ww2 / 2 + (_rnd.nextDouble() - 0.5) * 0.3)
          .clamp(_margin, 1 - _margin - ww2);
      final wy2 = 0.64 + (_rnd.nextDouble() - 0.5) * 0.1;
      _wall2 = Rect.fromLTWH(wx2, wy2, ww2, 0.045);
    } else {
      _wall2 = null;
    }
  }

  // Sinking requires a steadier, slower-rolling putt on later holes — holes
  // 1-5 keep the original forgiving threshold; holes 6-9 tighten it down to
  // a true plateau-free ramp so the last third of the round is noticeably
  // less forgiving of a hard putt than the first third.
  double get _sinkSpeedLimit {
    if (_hole <= 5) return 0.5;
    final t = ((_hole - 5) / 4).clamp(0.0, 1.0);
    return 0.5 - t * 0.18;
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

    // Rail obstacles — reflect off the shallower-penetration axis. Inflate
    // by the ball's true pixel radius on each axis (x by _ballR, y by
    // _ballR/_aspect) so the collision margin matches the rendered circle
    // instead of a width-only margin stretched/squashed by device aspect.
    final ballRY = _ballR / _aspect;
    for (final wall in <Rect?>[_wall, _wall2]) {
      if (wall == null) continue;
      final ex = Rect.fromLTRB(wall.left - _ballR, wall.top - ballRY,
          wall.right + _ballR, wall.bottom + ballRY);
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
    // Scale the y delta by the aspect ratio so the sink distance matches the
    // true pixel circle the painter draws, regardless of device aspect.
    final dx = _bx - _cupX, dy = (_by - _cupY) * _aspect;
    final d = math.sqrt(dx * dx + dy * dy);
    final speed = math.sqrt(_vx * _vx + _vy * _vy);
    if (d < _cupR) {
      if (speed < _sinkSpeedLimit) {
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
      winEmoji: '⛳',
      winText: 'Clubhouse champion!',
      accent: const Color(0xFF2E9E5B),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          if (w > 0) _aspect = h / w;
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
                wall2: _wall2,
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
    required this.wall2,
    required this.bits,
    required this.aim,
    required this.launch,
  });
  final double bx, by, ballR, cupX, cupY, cupR, cupPulse, margin;
  final Rect? wall;
  final Rect? wall2;
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
    final wl2 = wall2;
    if (wl2 != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  sx(wl2.left), sy(wl2.top), sx(wl2.width), sy(wl2.height)),
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

