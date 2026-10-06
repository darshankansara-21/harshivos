part of '../arcade_games.dart';

/// Shape Sort Chute — a shape drifts down from the top. Drag it left or right so
/// it drops into the hole of the matching shape. Wrong hole or a miss costs a
/// life. Three lives, twelve sorted to win.
class ShapeSortChuteGame extends StatefulWidget {
  const ShapeSortChuteGame({super.key});
  @override
  State<ShapeSortChuteGame> createState() => _ShapeSortChuteGameState();
}

class _ShapeSortChuteGameState extends State<ShapeSortChuteGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'shape_sort_chute';
  static const int _target = 12;
  static const List<Color> _shapeColors = <Color>[
    Color(0xFF4CC9F0), // circle
    Color(0xFFFFD166), // square
    Color(0xFF80ED99), // triangle
    Color(0xFFFF8ED8), // star
  ];
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Good sorting!', 'Sorting star!', 'Shape expert!', 'Great sorting!',
  ];
  String _winPraise = _winPraisePool[0];
  String _overPraise = _gentleTryAgainPool[0];
  List<int> _holes = <int>[0, 1, 2]; // shape index per hole (3 holes)
  int _shape = 0;
  double _x = 0.5, _y = 0.0, _fall = 0.28;
  int _score = 0, _lives = 3, _best = 0;
  int _flashHole = -1;
  double _flashT = 0;
  bool _flashGood = false;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // Every other aim-into-a-matching-target game in the catalog
  // (hoop_toss, sorting_train, basketball, bug_catch, penalty_dash...)
  // bursts a few shards of colour on a correct hit; this chute only ever
  // flashed the hole colour for 0.4s, making a correct sort feel flatter
  // than every sibling sort/aim game. Mirror the established convention.
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  // Same pattern as ball_sort/sorting_train/counting_baskets: a simple
  // incrementing score toward a fixed target is a judgment-free "beat your
  // own best" moment, fired once per run the first time it happens — this
  // file was missing that lens entirely, flatly repeating the routine
  // "Wrong hole!"/good-sort flash even on an all-time-record-breaking sort.
  bool _beatBest = false;
  // Same "flat-forever opening pace every replay" bug already fixed in
  // brick_break/stack/sky_hop/target_toss/etc.: `_fall`'s opener only ever
  // scaled with this run's own `_score` (always 0 at `_arrange()`'s very
  // first call), so a returning child who has sorted a hundred shapes faces
  // the exact same gentle drift a first-time player gets. Scale the opener
  // with career `_best` instead, capped well short of the in-run ceiling so
  // a skilled returning player meets a slightly livelier opening drop while
  // a fresh/low-`_best` child still gets the original gentle pace.
  double get _careerPaceRamp => (_best / _target).clamp(0.0, 1.0) * 0.12;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _arrange() {
    // Three holes, three distinct shapes; the falling shape is one of them.
    final pool = <int>[0, 1, 2, 3]..shuffle(_rnd);
    _holes = pool.take(3).toList();
    _shape = _holes[_rnd.nextInt(3)];
    _x = 0.5;
    _y = 0.0;
    _fall = 0.26 + _careerPaceRamp + _score * 0.012;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_flashT > 0) _flashT -= dt;
    _y += _fall * dt;
    if (_y >= 0.82) {
      _land();
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.5 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    setState(() {});
  }

  void _burst(double x, double y, Color color) {
    final n = _reduceMotion ? 4 : 12;
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.3;
      _bits.add(_Shard(x, y, math.cos(a) * sp, math.sin(a) * sp, color));
    }
  }

  void _land() {
    final hole = (_x * 3).floor().clamp(0, 2);
    if (_holes[hole] == _shape) {
      _flashHole = hole;
      _flashGood = true;
      _flashT = 0.4;
      _score++;
      TonePlayer.instance.playCue(SoundCue.wood);
      emit(ExperienceEvent.bubblePopped);
      _burst((hole + 0.5) / 3, 0.82, _shapeColors[_shape]);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (!_beatBest && _best > 0 && _score > _best) {
        _beatBest = true;
        // Takes priority over the good-sort flash this method already set
        // above — a new all-time record is the bigger moment of the two.
        _banner = 'New personal best! 🏆';
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_score >= _target) {
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
        return;
      }
    } else {
      _flashHole = hole;
      _flashGood = false;
      _flashT = 0.4;
      _lives--;
      if (_lives <= 0) {
        // The life-ending miss must sound distinct from a routine miss,
        // never just the same gentle-retry cue as every other wrong drop.
        _status = GameStatus.over;
        _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
        _banner = 'Out of lives!';
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
        return;
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'Wrong hole!';
      }
    }
    _arrange();
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _banner = null;
      _bits.clear();
      _beatBest = false;
      _arrange();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '🔻 Shape Sort Chute',
      introHow:
          'Drag the falling shape so it drops into the hole with the matching '
          'shape. Sort twelve to win!',
      onStart: () => setState(() {
        _arrange();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Sort the shapes  ·  ${'💛' * _lives}',
      overEmoji: '💪',
      overText: _overPraise,
      winEmoji: '🔻',
      winText: _winPraise,
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          void move(double dx) =>
              setState(() => _x = (dx / w).clamp(0.08, 0.92));
          const shapeNames = <String>['circle', 'square', 'triangle', 'star'];
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => move(d.localPosition.dx),
                onPanUpdate: (d) => move(d.localPosition.dx),
                onTapDown: (d) => move(d.localPosition.dx),
                child: CustomPaint(
                  painter: _ShapeSortChutePainter(
                    holes: _holes,
                    shape: _shape,
                    x: _x,
                    y: _y,
                    colors: _shapeColors,
                    flashHole: _flashT > 0 ? _flashHole : -1,
                    flashGood: _flashGood,
                    bits: _bits,
                  ),
                  size: Size.infinite,
                ),
              ),
              // Screen-reader access: each hole is a fixed per-round drop
              // zone (set once in `_arrange`, like `shape_builder`'s slots),
              // so steer the falling shape straight over a hole on tap.
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: w * (i / 3),
                  top: 0,
                  width: w / 3,
                  bottom: 0,
                  child: Semantics(
                    label: '${shapeNames[_holes[i]]} hole',
                    button: true,
                    onTap: () => move(w * (i / 3 + 1 / 6)),
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

class _ShapeSortChutePainter extends CustomPainter {
  _ShapeSortChutePainter({
    required this.holes,
    required this.shape,
    required this.x,
    required this.y,
    required this.colors,
    required this.flashHole,
    required this.flashGood,
    required this.bits,
  });
  final List<int> holes;
  final int shape;
  final double x, y;
  final List<Color> colors;
  final int flashHole;
  final bool flashGood;
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
            colors: <Color>[Color(0xFF17202B), Color(0xFF0D1218)],
          ).createShader(Offset.zero & size));

    // Chute holes along the bottom.
    final hy = h * 0.88;
    for (var i = 0; i < 3; i++) {
      final cx = w * (i / 3 + 1 / 6);
      final highlight = flashHole == i;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx, hy), width: w / 3 - 12, height: h * 0.16),
              const Radius.circular(12)),
          Paint()
            ..color = highlight
                ? (flashGood ? const Color(0xFF2E7D4F) : const Color(0xFF7D2E2E))
                : Colors.white10);
      _paintPolyShape(canvas, Offset(cx, hy), w * 0.07, holes[i],
          Paint()..color = colors[holes[i]].withOpacity(0.9));
    }

    // Falling shape.
    _paintPolyShape(canvas, Offset(x * w, y * h), w * 0.08, shape,
        Paint()..color = colors[shape]);

    for (final b in bits) {
      final k = (b.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(b.x * w, b.y * h), 2 + 3 * k,
          Paint()..color = b.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_ShapeSortChutePainter oldDelegate) => true;
}
