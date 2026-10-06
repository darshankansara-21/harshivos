part of '../arcade_games.dart';

/// Steady Hand — grab the dot at the start and drag it along the winding path to
/// the end without leaving the corridor. Touch a wall and you go back to start
/// and lose a life. The path gets narrower each level; clear three to win.
class SteadyHandGame extends StatefulWidget {
  const SteadyHandGame({super.key});
  @override
  State<SteadyHandGame> createState() => _SteadyHandGameState();
}

class _SteadyHandGameState extends State<SteadyHandGame> with _Emit {
  static const String _id = 'steady_hand';
  static const int _target = 3;

  // Winding corridor centrelines (normalized) per level.
  static const List<List<List<double>>> _paths = <List<List<double>>>[
    <List<double>>[[0.12, 0.8], [0.3, 0.3], [0.55, 0.7], [0.8, 0.25]],
    <List<double>>[[0.1, 0.2], [0.4, 0.75], [0.6, 0.25], [0.88, 0.8]],
    <List<double>>[[0.12, 0.5], [0.32, 0.2], [0.5, 0.75], [0.7, 0.25], [0.9, 0.6]],
  ];
  static const List<double> _widths = <double>[0.08, 0.065, 0.05];

  int _level = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'So steady!', 'Rock steady!', 'Calm hands!', 'Precision master!',
  ];
  String _winPraise = _winPraisePool[0];
  // Pool of per-path completion phrases so finishing a steady-hand path
  // doesn't always flash the identical "Steady! Next path" line.
  static const List<String> _nextPathPool = <String>[
    'Steady! Next path',
    'Smooth hands! Next path',
    'Nice and calm! New path',
    'Well guided! Keep going',
  ];
  bool _holding = false;
  double _dotX = 0.12, _dotY = 0.8;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // A sighted child can see the dot drifting toward the corridor wall and
  // correct before it actually touches — a blind/low-vision child had zero
  // signal of that until the sudden, unavoidable wall-touch failure. Fire a
  // one-shot creak once drift crosses well into the danger zone (before the
  // real failure threshold) so there is real time to react, then re-arm once
  // the dot drifts back toward the centreline so a later excursion warns
  // again too — the same `_edgeWarned` pattern already used in balance_ball.
  bool _edgeWarned = false;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  List<List<double>> get _path => _paths[_level];
  double get _halfW => _widths[_level];

  void _startLevel() {
    _dotX = _path.first[0];
    _dotY = _path.first[1];
    _holding = false;
    _edgeWarned = false;
  }

  // The corridor the painter draws is a stroked path with strokeWidth
  // `halfW * 2 * w` — a true-pixel band, isotropic in real screen pixels.
  // But the path's own vertices (and this distance check) live in
  // mixed-normalized space (x as a fraction of width, y as a fraction of
  // height). On a typical taller-than-wide phone, a plain isotropic
  // sqrt(dx*dx+dy*dy) here would under/over-tolerate drift depending on a
  // segment's direction. Scale the y-axis by `aspect` (height/width) before
  // measuring, so the comparison against the width-calibrated `_halfW`
  // matches what is actually drawn in every direction.
  double _distToPath(double x, double y, double aspect) {
    var best = double.infinity;
    for (var i = 0; i < _path.length - 1; i++) {
      best = math.min(best, _distToSeg(x, y, _path[i], _path[i + 1], aspect));
    }
    return best;
  }

  double _distToSeg(
      double px, double py, List<double> a, List<double> b, double aspect) {
    final ax = a[0], ay = a[1] * aspect, bx = b[0], by = b[1] * aspect;
    final pys = py * aspect;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (pys - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt(math.pow(px - cx, 2) + math.pow(pys - cy, 2)).toDouble();
  }

  void _fail() {
    _lives--;
    _holding = false;
    _edgeWarned = false;
    _dotX = _path.first[0];
    _dotY = _path.first[1];
    if (_lives <= 0) {
      // The life-ending wall-touch must sound distinct from a routine
      // bump, never just the same gentle-retry cue as every other miss.
      _status = GameStatus.over;
      _banner = 'Out of lives!';
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = 'Touched the wall — back to start';
    }
    setState(() {});
  }

  void _levelDone() {
    _score++;
    TonePlayer.instance.playCue(SoundCue.success);
    emit(ExperienceEvent.bubblePopped);
    GameScores.instance.submit(_id, _score).then((v) {
      if (mounted) setState(() => _best = v);
    });
    if (_score >= _target) {
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else {
      _level++;
      _banner = _nextPathPool[_rnd.nextInt(_nextPathPool.length)];
      _startLevel();
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _level = 0;
      _score = 0;
      _lives = 3;
      _banner = null;
      _startLevel();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🖐️ Steady Hand',
      introHow:
          'Grab the dot at the start and drag it along the path to the end '
          'without touching the walls. Three paths to win! Touching a wall '
          'costs one of your 3 lives.',
      onStart: () => setState(() {
        _startLevel();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Follow the path  ·  ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '🖐️',
      winText: _winPraise,
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final aspect = h / w;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              final nx = d.localPosition.dx / w, ny = d.localPosition.dy / h;
              // Both axes of this grab box are width-calibrated (matching the
              // drawn start marker's pixel radius), so the y-threshold must be
              // divided by aspect to mean the same real pixel distance as x.
              if ((nx - _path.first[0]).abs() < _halfW * 1.6 &&
                  (ny - _path.first[1]).abs() < _halfW * 1.6 / aspect) {
                setState(() {
                  _holding = true;
                  _dotX = nx;
                  _dotY = ny;
                });
              }
            },
            onPanUpdate: (d) {
              if (!_holding || _status != GameStatus.playing) return;
              final nx = d.localPosition.dx / w, ny = d.localPosition.dy / h;
              final dist = _distToPath(nx, ny, aspect);
              if (dist > _halfW) {
                _fail();
                return;
              }
              if (dist > _halfW * 0.72) {
                if (!_edgeWarned) {
                  _edgeWarned = true;
                  TonePlayer.instance.playCue(SoundCue.wood);
                }
              } else if (dist < _halfW * 0.4) {
                _edgeWarned = false;
              }
              setState(() {
                _dotX = nx;
                _dotY = ny;
              });
              final end = _path.last;
              if ((nx - end[0]).abs() < _halfW &&
                  (ny - end[1]).abs() < _halfW / aspect) {
                _levelDone();
              }
            },
            onPanEnd: (_) => setState(() => _holding = false),
            // A cancelled pan (gesture arena interruption) never calls
            // onPanEnd, so without this `_holding` would stay stuck true
            // forever — the dot would render as "held" with no finger on
            // it, and the very next unrelated gesture anywhere on screen
            // would immediately start dragging it (bypassing the "grab the
            // dot" requirement) since onPanUpdate only gates on `_holding`.
            onPanCancel: () => setState(() => _holding = false),
            child: CustomPaint(
              painter: _SteadyHandPainter(
                path: _path,
                halfW: _halfW,
                dotX: _dotX,
                dotY: _dotY,
                holding: _holding,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _SteadyHandPainter extends CustomPainter {
  _SteadyHandPainter({
    required this.path,
    required this.halfW,
    required this.dotX,
    required this.dotY,
    required this.holding,
  });
  final List<List<double>> path;
  final double halfW, dotX, dotY;
  final bool holding;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF14202B), Color(0xFF0A1118)],
          ).createShader(Offset.zero & size));

    final p = Path()..moveTo(path.first[0] * w, path.first[1] * h);
    for (var i = 1; i < path.length; i++) {
      p.lineTo(path[i][0] * w, path[i][1] * h);
    }
    // Corridor (stroke width = 2*halfW), then a thinner inner glow.
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = halfW * 2 * w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF2A3F52));
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = halfW * 1.2 * w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF16242F));

    // Start + end markers.
    canvas.drawCircle(Offset(path.first[0] * w, path.first[1] * h), halfW * w * 0.8,
        Paint()..color = const Color(0xFF80ED99).withOpacity(0.5));
    final end = Offset(path.last[0] * w, path.last[1] * h);
    canvas.drawCircle(end, halfW * w * 0.85,
        Paint()..color = const Color(0xFFFFD166).withOpacity(0.6));
    final flag = TextPainter(
      text: const TextSpan(text: '🏁', style: TextStyle(fontSize: 18)),
      textDirection: TextDirection.ltr,
    )..layout();
    flag.paint(canvas, end - Offset(flag.width / 2, flag.height / 2));

    // The dot.
    final dc = Offset(dotX * w, dotY * h);
    canvas.drawCircle(dc, halfW * w * 0.7,
        Paint()..color = holding ? const Color(0xFF4CC9F0) : Colors.white70);
    canvas.drawCircle(dc, halfW * w * 0.7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SteadyHandPainter oldDelegate) => true;
}
