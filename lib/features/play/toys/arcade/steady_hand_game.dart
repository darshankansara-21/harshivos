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
  bool _holding = false;
  double _dotX = 0.12, _dotY = 0.8;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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
  }

  double _distToPath(double x, double y) {
    var best = double.infinity;
    for (var i = 0; i < _path.length - 1; i++) {
      best = math.min(best, _distToSeg(x, y, _path[i], _path[i + 1]));
    }
    return best;
  }

  double _distToSeg(double px, double py, List<double> a, List<double> b) {
    final ax = a[0], ay = a[1], bx = b[0], by = b[1];
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt(math.pow(px - cx, 2) + math.pow(py - cy, 2)).toDouble();
  }

  void _fail() {
    _lives--;
    _holding = false;
    _dotX = _path.first[0];
    _dotY = _path.first[1];
    TonePlayer.instance.playCue(SoundCue.gentleRetry);
    _banner = 'Touched the wall — back to start';
    if (_lives <= 0) _status = GameStatus.over;
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
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else {
      _level++;
      _banner = 'Steady! Next path';
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
          'without touching the walls. Three paths to win!',
      onStart: () => setState(() {
        _startLevel();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Follow the path  ·  ${'💛' * _lives}',
      overEmoji: '🖐️',
      overText: 'So steady!',
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              final nx = d.localPosition.dx / w, ny = d.localPosition.dy / h;
              if ((nx - _path.first[0]).abs() < _halfW * 1.6 &&
                  (ny - _path.first[1]).abs() < _halfW * 1.6) {
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
              if (_distToPath(nx, ny) > _halfW) {
                _fail();
                return;
              }
              setState(() {
                _dotX = nx;
                _dotY = ny;
              });
              final end = _path.last;
              if ((nx - end[0]).abs() < _halfW && (ny - end[1]).abs() < _halfW) {
                _levelDone();
              }
            },
            onPanEnd: (_) => setState(() => _holding = false),
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
