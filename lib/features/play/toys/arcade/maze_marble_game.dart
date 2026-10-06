part of '../arcade_games.dart';

/// Maze Marble — drag to roll a marble down through the gates to the goal cup.
/// Steer it through the opening in each wall; clear six boards to win. The
/// gaps get narrower as you go, so a steady hand matters.
class MazeMarbleGame extends StatefulWidget {
  const MazeMarbleGame({super.key});
  @override
  State<MazeMarbleGame> createState() => _MazeMarbleGameState();
}

class _MazeWall {
  _MazeWall(this.y, this.gapX, this.gapW);
  final double y;
  final double gapX;
  final double gapW;
}

class _MazeMarbleGameState extends State<MazeMarbleGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'maze_marble';
  static const int _target = 6;
  static const double _r = 0.045;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Nice rolling!',
    'Marble master!',
    'Smooth steering!',
    'Perfect run!',
  ];
  String _winPraise = _winPraisePool.first;
  // Every other physics game that ends a round at a fixed spot (mini_golf's
  // cup sink, hoop_toss's peg) bursts a few shards of colour on success —
  // Maze Marble's goal cup never did, despite sharing the exact same
  // `_Shard` class and painter convention. Mirror it here.
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;

  final List<_MazeWall> _walls = <_MazeWall>[];
  double _mx = 0.5, _my = 0.1, _vx = 0, _vy = 0;
  double _tx = 0.5, _ty = 0.1;
  bool _dragging = false;
  double _goalX = 0.5;
  final double _goalY = 0.93;
  // All physics below runs in mixed-normalized coordinates (x as a fraction
  // of canvas width, y as a fraction of canvas height), but every size the
  // painter draws (marble radius, wall thickness, goal radius) is a true
  // pixel circle scaled only by canvas *width*. On a typical taller-than-wide
  // phone that mismatch silently distorts every isotropic radius check below
  // (edges, wall collisions, goal detection) — stopping/bouncing the marble
  // at a distance that doesn't match what's actually drawn. Track the real
  // aspect ratio so physics matches the rendering, the same fix already
  // applied to space_dodge's hit test.
  double _aspect = 1.0; // height / width of the last laid-out canvas
  int _level = 1;
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

  void _buildLevel() {
    _walls.clear();
    final rows = (_level + 1).clamp(2, 5);
    final gapW = (0.28 - _level * 0.02).clamp(0.16, 0.28);
    for (var i = 0; i < rows; i++) {
      final y = 0.24 + i * (0.56 / (rows - 1));
      final gapX = 0.1 + _rnd.nextDouble() * (0.8 - gapW);
      _walls.add(_MazeWall(y, gapX, gapW));
    }
    _goalX = 0.12 + _rnd.nextDouble() * 0.76;
    _mx = 0.5;
    _my = 0.1;
    _vx = 0;
    _vy = 0;
    _tx = _mx;
    _ty = _my;
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
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    // Drag acts like tilting a tray: pull the marble toward the finger.
    if (_dragging) {
      _vx += (_tx - _mx) * 14 * dt;
      _vy += (_ty - _my) * 14 * dt;
    }
    final damp = (1 - 3.2 * dt).clamp(0.0, 1.0);
    _vx *= damp;
    _vy *= damp;
    // Cap speed so collisions stay stable.
    const maxV = 1.6;
    final sp = math.sqrt(_vx * _vx + _vy * _vy);
    if (sp > maxV) {
      _vx = _vx / sp * maxV;
      _vy = _vy / sp * maxV;
    }
    // Integrate in substeps for robust collisions.
    const steps = 4;
    final h = dt / steps;
    for (var s = 0; s < steps; s++) {
      _mx += _vx * h;
      _my += _vy * h;
      _resolveEdges();
      for (final w in _walls) {
        _resolveWall(w);
      }
    }
    final dx = _mx - _goalX, dy = (_my - _goalY) * _aspect;
    if (dx * dx + dy * dy < 0.07 * 0.07) {
      _reachGoal();
    }
    setState(() {});
  }

  // Every other physics-bounce game in the catalog (air_hockey, mini_golf,
  // pinball, toys_light's ball pit) plays a tactile cue on impact, and
  // `SoundCue.marble` exists specifically for this sound identity — yet this
  // game, literally named Maze Marble, never once called it: every wall and
  // edge bounce was completely silent. Gate on incoming speed (not just
  // "touching a wall") so a marble resting/sliding gently along a wall after
  // it has mostly stopped doesn't buzz every frame; a real bounce clears it
  // easily, matching the threshold style used by `toys_light.dart`.
  static const double _bounceSpeed = 0.18;

  void _resolveEdges() {
    if (_mx < _r) {
      _mx = _r;
      if (_vx.abs() > _bounceSpeed) {
        TonePlayer.instance.playCue(SoundCue.marble);
      }
      _vx = -_vx * 0.4;
    } else if (_mx > 1 - _r) {
      _mx = 1 - _r;
      if (_vx.abs() > _bounceSpeed) {
        TonePlayer.instance.playCue(SoundCue.marble);
      }
      _vx = -_vx * 0.4;
    }
    // The vertical margin must shrink by the aspect ratio so the real pixel
    // gap kept from the top/bottom matches the marble's rendered radius
    // (which is scaled only by width), instead of leaving a visible gap.
    final ry = _r / _aspect;
    if (_my < ry) {
      _my = ry;
      if (_vy.abs() > _bounceSpeed) {
        TonePlayer.instance.playCue(SoundCue.marble);
      }
      _vy = -_vy * 0.4;
    } else if (_my > 1 - ry) {
      _my = 1 - ry;
      if (_vy.abs() > _bounceSpeed) {
        TonePlayer.instance.playCue(SoundCue.marble);
      }
      _vy = -_vy * 0.4;
    }
  }

  // Circle-vs-bar collision for each solid half of a gated wall.
  void _resolveWall(_MazeWall w) {
    const t = 0.014;
    _collideBar(0, w.gapX, w.y, t);
    _collideBar(w.gapX + w.gapW, 1, w.y, t);
  }

  void _collideBar(double x0, double x1, double y, double t) {
    final cx = _mx.clamp(x0, x1);
    final dx = _mx - cx;
    // Scale the y delta into the same width-normalized units as dx/_r/t so
    // the collision distance matches the true pixel circle the painter
    // draws, regardless of device aspect ratio.
    final dy = (_my - y) * _aspect;
    final d2 = dx * dx + dy * dy;
    final rr = _r + t;
    if (d2 < rr * rr && d2 > 1e-9) {
      final d = math.sqrt(d2);
      final nx = dx / d, ny = dy / d;
      final push = rr - d;
      _mx += nx * push;
      _my += ny * push / _aspect;
      final vyScaled = _vy * _aspect;
      final vn = _vx * nx + vyScaled * ny;
      if (vn < 0) {
        if (-vn > _bounceSpeed) {
          TonePlayer.instance.playCue(SoundCue.marble);
        }
        _vx -= vn * nx * 1.3;
        _vy -= vn * ny * 1.3 / _aspect;
      }
    }
  }

  void _reachGoal() {
    _score++;
    final bitCount = _reduceMotion ? 5 : 14;
    for (var i = 0; i < bitCount; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.35;
      _bits.add(_Shard(_goalX, _goalY, math.cos(a) * sp, math.sin(a) * sp,
          const Color(0xFF2EC4B6)));
    }
    TonePlayer.instance.playCue(SoundCue.success);
    emit(ExperienceEvent.bubblePopped);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
    if (_score >= _target) {
      _status = GameStatus.won;
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else {
      _level++;
      _banner = 'Through! Board $_level';
      _bannerT = 1.2;
      _buildLevel();
    }
  }

  void _reset() {
    setState(() {
      _level = 1;
      _score = 0;
      _banner = null;
      _bannerT = 0;
      _bits.clear();
      _buildLevel();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔵 Maze Marble',
      introHow:
          'Drag to roll the marble down through the gate in each wall and into '
          'the goal cup. Six boards to win!',
      onStart: () => setState(() {
        _buildLevel();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Steer through the gates to the cup',
      winEmoji: '🔵',
      winText: _winPraise,
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          if (w > 0) _aspect = h / w;
          _reduceMotion = MediaQuery.disableAnimationsOf(context);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              _dragging = true;
              _tx = (d.localPosition.dx / w).clamp(0.0, 1.0);
              _ty = (d.localPosition.dy / h).clamp(0.0, 1.0);
            },
            onPanUpdate: (d) {
              _tx = (d.localPosition.dx / w).clamp(0.0, 1.0);
              _ty = (d.localPosition.dy / h).clamp(0.0, 1.0);
            },
            onPanEnd: (_) => _dragging = false,
            // A cancelled pan (gesture arena interruption) never calls
            // onPanEnd, so without this _dragging would stay stuck true
            // forever and the marble would keep getting pulled toward the
            // last finger position long after the touch ended.
            onPanCancel: () => _dragging = false,
            child: CustomPaint(
              painter: _MazeMarblePainter(
                walls: _walls,
                mx: _mx,
                my: _my,
                goalX: _goalX,
                goalY: _goalY,
                dragging: _dragging,
                tx: _tx,
                ty: _ty,
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

class _MazeMarblePainter extends CustomPainter {
  _MazeMarblePainter({
    required this.walls,
    required this.mx,
    required this.my,
    required this.goalX,
    required this.goalY,
    required this.dragging,
    required this.tx,
    required this.ty,
    required this.bits,
  });
  final List<_MazeWall> walls;
  final double mx, my, goalX, goalY, tx, ty;
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
            colors: <Color>[Color(0xFF13203A), Color(0xFF0A1322)],
          ).createShader(Offset.zero & size));

    // Walls with a rounded gate opening.
    final wallPaint = Paint()..color = const Color(0xFF5C7C9E);
    for (final wa in walls) {
      final y = wa.y * h;
      final gx0 = wa.gapX * w, gx1 = (wa.gapX + wa.gapW) * w;
      final th = 0.028 * h;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(0, y - th / 2, gx0, y + th / 2),
              Radius.circular(th / 2)),
          wallPaint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(gx1, y - th / 2, w, y + th / 2),
              Radius.circular(th / 2)),
          wallPaint);
    }

    // Goal cup.
    final gc = Offset(goalX * w, goalY * h);
    canvas.drawCircle(gc, 0.062 * w,
        Paint()..color = const Color(0xFF2EC4B6).withOpacity(0.3));
    canvas.drawCircle(
        gc,
        0.052 * w,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF2EC4B6));
    final tp = TextPainter(
      text: const TextSpan(text: '🏁', style: TextStyle(fontSize: 22)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, gc - Offset(tp.width / 2, tp.height / 2));

    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }

    // Drag hint line.
    if (dragging) {
      canvas.drawLine(
          Offset(mx * w, my * h),
          Offset(tx * w, ty * h),
          Paint()
            ..color = Colors.white24
            ..strokeWidth = 2);
    }

    // Marble.
    final mc = Offset(mx * w, my * h);
    final mr = 0.045 * w;
    canvas.drawCircle(mc + const Offset(0, 3),
        mr, Paint()..color = Colors.black.withOpacity(0.35));
    canvas.drawCircle(
        mc,
        mr,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.3),
            colors: <Color>[Color(0xFFBDE7FF), Color(0xFF2B7FC9)],
          ).createShader(Rect.fromCircle(center: mc, radius: mr)));
    canvas.drawCircle(mc + Offset(-mr * 0.3, -mr * 0.3), mr * 0.28,
        Paint()..color = Colors.white.withOpacity(0.8));
  }

  @override
  bool shouldRepaint(_MazeMarblePainter oldDelegate) => true;
}
