part of '../arcade_games.dart';

class BubbleShooterGame extends StatefulWidget {
  const BubbleShooterGame({super.key});
  @override
  State<BubbleShooterGame> createState() => _BubbleShooterGameState();
}

class _BubbleShooterGameState extends State<BubbleShooterGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'bubble_shooter';
  static const int _cols = 7;
  static const List<Color> _pal = <Color>[
    Color(0xFFEF476F),
    Color(0xFFFFD166),
    Color(0xFF06D6A0),
    Color(0xFF4CC9F0),
    Color(0xFF9B5DE5),
  ];
  // Every other match-by-colour game in the catalog (pattern_weaver,
  // sorting_train, shadow_match, odd_one_out, shape_sort_chute) already pairs
  // its palette with a distinct shape glyph so matching never depends on
  // colour perception alone — this was the one game left relying purely on
  // 5 similarly-bright candy hues (red/violet and teal/sky are an easy
  // confusion for red-green or blue-yellow colour-blind children) to tell
  // which bubbles can legally pop together. Shapes 1-5 (square/triangle/
  // star/heart/diamond) are used, skipping 0 (circle) since every bubble is
  // already drawn as a circle and a circle-on-circle glyph would be invisible.
  static const List<int> _shapeForColor = <int>[1, 2, 3, 4, 5];
  final math.Random _rnd = math.Random();
  late List<List<Color?>> _grid;
  final List<_Shard> _pops = <_Shard>[]; // pixel-space pop particles
  bool _reduceMotion = false;
  int _rows = 0;
  double _w = 0;
  double _h = 0;
  double _cell = 0;
  double _r = 0;
  bool _init = false;
  Offset? _pos; // flying bubble centre, null when idle
  Offset _vel = Offset.zero;
  Color _shot = _pal[0];
  Color _next = _pal[1];
  int _score = 0;
  int _best = 0;
  String _overPraise = _gentleTryAgainPool[0];
  String? _banner;
  // Every pop/ceiling-drop/personal-best banner was only ever cleared by
  // `_reset()` — the first pop of a run glued its text on screen forever,
  // silently hiding every later pop/drop's own feedback.
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Without this, the game never escalates: the ceiling of bubbles sits
  // still forever and a patient child can match forever at the exact same
  // flat difficulty — there's no sense of mounting pressure or a reason to
  // hurry, unlike every other arcade game in the catalog. Every few shots we
  // drop the whole field one row, genre-standard "ceiling descends" pressure.
  static const int _shotsPerDrop = 8;
  int _shotsFired = 0;
  // Mirrors stack_game/block_blast_game's live "beat your own all-time best"
  // celebration. Bubble Shooter has no win cap either — score is a pure
  // pop-count climb until the ceiling reaches the floor — so crossing a
  // prior personal best mid-run deserves the same judgment-free moment.
  bool _beatBest = false;

  @override
  void initState() {
    super.initState();
    _shot = _pal[_rnd.nextInt(_pal.length)];
    _next = _pal[_rnd.nextInt(_pal.length)];
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _layout(double w, double h) {
    // Height (e.g. a system bar/gesture-nav inset appearing or disappearing)
    // can change without the width changing. The grid only needs to be
    // regenerated when the width changes, but `_w`/`_h` must always track the
    // real current size — the painter and `_fire()` read `_h` directly to
    // place the launcher at the true bottom of the screen, and a stale value
    // would draw/fire from the wrong spot after such a resize.
    final rebuild = !_init || (w - _w).abs() >= 0.5;
    _w = w;
    _h = h;
    if (!rebuild) return;
    _cell = w / _cols;
    _r = _cell / 2;
    _rows = math.max(6, (h / _cell).floor());
    _grid =
        List<List<Color?>>.generate(_rows, (_) => List<Color?>.filled(_cols, null));
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < _cols; c++) {
        _grid[r][c] = _pal[_rnd.nextInt(_pal.length)];
      }
    }
    _init = true;
  }

  Offset _center(int r, int c) =>
      Offset((c + 0.5) * _cell, (r + 0.5) * _cell);

  bool _hitsBubble(Offset p) {
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (_grid[r][c] != null &&
            (_center(r, c) - p).distance < _cell * 0.9) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      final s = _pops[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 300 * dt;
      s.life -= dt;
      if (s.life <= 0) _pops.removeAt(i);
    }
    if (_pos == null) return;
    var p = _pos! + _vel * dt;
    if (p.dx < _r) {
      p = Offset(_r, p.dy);
      _vel = Offset(_vel.dx.abs(), _vel.dy);
    } else if (p.dx > _w - _r) {
      p = Offset(_w - _r, p.dy);
      _vel = Offset(-_vel.dx.abs(), _vel.dy);
    }
    _pos = p;
    if (p.dy <= _r || _hitsBubble(p)) {
      _snap(p);
    }
  }

  void _snap(Offset p) {
    double bestD = double.infinity;
    int br = -1, bc = -1;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (_grid[r][c] != null) continue;
        final d = (_center(r, c) - p).distance;
        if (d < bestD) {
          bestD = d;
          br = r;
          bc = c;
        }
      }
    }
    _pos = null;
    if (br < 0) {
      _gameOver();
      return;
    }
    _grid[br][bc] = _shot;
    final group = _flood(br, bc, _shot);
    if (group.length >= 3) {
      for (final cell in group) {
        final ctr = _center(cell.x, cell.y);
        final shardCount = _reduceMotion ? 2 : 5;
        for (var s = 0; s < shardCount; s++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 60 + _rnd.nextDouble() * 150;
          _pops.add(_Shard(
              ctr.dx, ctr.dy, math.cos(a) * sp, math.sin(a) * sp, _shot));
        }
        _grid[cell.x][cell.y] = null;
      }
      _score += group.length;
      _banner = 'Pop ${group.length}!';
      _bannerT = 1.1;
      TonePlayer.instance.playCue(SoundCue.bubble);
      emit(ExperienceEvent.bubblePopped);
      if (_status == GameStatus.playing &&
          !_beatBest &&
          _best > 0 &&
          _score > _best) {
        _beatBest = true;
        // Takes priority over the pop-count banner just set above — a new
        // all-time record is the bigger moment of the two.
        _banner = 'New personal best! 🏆';
        _bannerT = 1.3;
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      GameScores.instance.submit(_id, _score).then((b) {
        // Resolves after this frame's setState has already run, so updating
        // `_best` without triggering a rebuild left a new best silently
        // stale on screen until some unrelated later interaction repainted.
        if (mounted && b != _best) setState(() => _best = b);
      });
    } else {
      TonePlayer.instance.playCue(SoundCue.ball);
    }
    _shot = _next;
    _next = _pal[_rnd.nextInt(_pal.length)];
    if (br >= _rows - 1) {
      _gameOver();
      return;
    }
    if (_status == GameStatus.playing &&
        _shotsFired > 0 &&
        _shotsFired % _shotsPerDrop == 0) {
      _dropCeiling();
    }
  }

  List<math.Point<int>> _flood(int r, int c, Color color) {
    final seen = <String>{};
    final out = <math.Point<int>>[];
    final stack = <math.Point<int>>[math.Point<int>(r, c)];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final key = '${p.x},${p.y}';
      if (seen.contains(key)) continue;
      if (p.x < 0 || p.x >= _rows || p.y < 0 || p.y >= _cols) continue;
      if (_grid[p.x][p.y] != color) continue;
      seen.add(key);
      out.add(p);
      stack.add(math.Point<int>(p.x + 1, p.y));
      stack.add(math.Point<int>(p.x - 1, p.y));
      stack.add(math.Point<int>(p.x, p.y + 1));
      stack.add(math.Point<int>(p.x, p.y - 1));
    }
    return out;
  }

  void _fire(Offset target) {
    if (_status != GameStatus.playing || _pos != null || !_init) return;
    final origin = Offset(_w / 2, _h - _cell);
    var dir = target - origin;
    if (dir.dy > -8) dir = Offset(dir.dx, -8);
    final n = dir / dir.distance;
    _vel = n * 640;
    _pos = origin;
    _shotsFired++;
    // The shot itself was completely silent — feedback only arrived once the
    // bubble landed. `SoundCue.laser` already has its own distinct synth
    // built for exactly this "launch" moment but was never wired into any
    // game; this is the shooting toy it belongs to.
    TonePlayer.instance.playCue(SoundCue.laser);
  }

  // Shift every row down one and fill a fresh row at the top, so the whole
  // field visibly creeps closer to the floor. If that push leaves the bottom
  // row occupied, the field has reached the floor and the run ends — exactly
  // the same "bubbles reached the floor" loss condition `_snap` already uses,
  // just triggered by the ceiling advancing instead of a bad shot.
  void _dropCeiling() {
    if (_grid[_rows - 1].any((c) => c != null)) {
      _gameOver();
      return;
    }
    for (var r = _rows - 1; r > 0; r--) {
      _grid[r] = _grid[r - 1];
    }
    _grid[0] = List<Color?>.generate(_cols, (_) => _pal[_rnd.nextInt(_pal.length)]);
    TonePlayer.instance.playCue(SoundCue.milestone);
    _banner = 'Ceiling drops!';
    _bannerT = 1.1;
  }

  void _gameOver() {
    final prev = GameScores.instance.best(_id);
    _status = GameStatus.over;
    _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
    TonePlayer.instance.playCue(SoundCue.gameOver);
    emit(_score > prev
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _reset() {
    setState(() {
      _init = false;
      _pos = null;
      _pops.clear();
      _score = 0;
      _shotsFired = 0;
      _banner = null;
      _bannerT = 0;
      _beatBest = false;
      _status = GameStatus.playing;
      _shot = _pal[_rnd.nextInt(_pal.length)];
      _next = _pal[_rnd.nextInt(_pal.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '🫧 Bubble Shooter',
      introHow: 'Aim and shoot to match 3 bubbles of the same colour. '
          'The ceiling drops lower every 8 shots, so don\'t let bubbles reach the floor!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🫧',
      overText: _overPraise,
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          _layout(c.maxWidth, c.maxHeight);
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _fire(d.localPosition),
                child: CustomPaint(
                  painter: _BubblePainter(_grid, _rows, _cols, _cell, _r, _pos,
                      _shot, _next, _w, _h, _pops),
                  size: Size.infinite,
                ),
              ),
              // Bubble Shooter aims continuously (any tap position becomes a
              // launch direction), so there's no fixed set of discrete
              // targets to track like `piano_tiles`'s lanes or
              // `beat_builder`'s grid cells. The closest honest mapping for a
              // screen-reader user is one static overlay per column (the
              // grid the bubbles themselves snap to), announcing which
              // column a tap aims toward and firing straight up that column.
              if (_init)
                for (var col = 0; col < _cols; col++)
                  Positioned(
                    left: col * _cell,
                    top: 0,
                    width: _cell,
                    height: _h,
                    child: Semantics(
                      button: true,
                      label: 'Aim column ${col + 1}',
                      onTap: () => _fire(_center(0, col)),
                      child: const SizedBox.expand(),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.grid, this.rows, this.cols, this.cell, this.r, this.pos,
      this.shot, this.next, this.w, this.h, this.pops);
  final List<List<Color?>> grid;
  final int rows;
  final int cols;
  final double cell;
  final double r;
  final Offset? pos;
  final Color shot;
  final Color next;
  final double w;
  final double h;
  final List<_Shard> pops;

  void _ball(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, r - 1.5, Paint()..color = color);
    canvas.drawCircle(
        center.translate(-r * 0.28, -r * 0.28),
        r * 0.3,
        Paint()..color = Colors.white.withOpacity(0.4));
    // Colour-blind-safe shape redundancy: every palette colour also carries
    // its own distinct glyph, so which bubbles can pop together never
    // depends on distinguishing similarly-bright hues alone.
    final idx = _BubbleShooterGameState._pal.indexOf(color);
    if (idx >= 0) {
      _paintPolyShape(
          canvas,
          center,
          r * 0.36,
          _BubbleShooterGameState._shapeForColor[idx],
          Paint()..color = Colors.white.withOpacity(0.55));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0E1830), Color(0xFF060B18)],
          ).createShader(Offset.zero & size));
    for (var rr = 0; rr < rows; rr++) {
      for (var cc = 0; cc < cols; cc++) {
        final col = grid[rr][cc];
        if (col != null) {
          _ball(canvas, Offset((cc + 0.5) * cell, (rr + 0.5) * cell), col);
        }
      }
    }
    // Launcher + next colour.
    final origin = Offset(w / 2, h - cell);
    if (pos != null) {
      _ball(canvas, pos!, shot);
    } else {
      _ball(canvas, origin, shot);
    }
    _ball(canvas, Offset(w / 2 + cell * 1.2, h - cell * 0.6), next);
    // Pop particles.
    for (final s in pops) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x, s.y), r * 0.5 * k + 2,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => true;
}

// ===========================================================================
// Quick Tap — a pure reaction game. Wait on red, and the instant the screen
// flashes green, tap as fast as you can. Tapping too early costs the round.
// Faster reactions score more; five rounds make a run.
// ===========================================================================
