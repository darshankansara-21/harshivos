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

  List<int> _holes = <int>[0, 1, 2]; // shape index per hole (3 holes)
  int _shape = 0;
  double _x = 0.5, _y = 0.0, _fall = 0.28;
  int _score = 0, _lives = 3, _best = 0;
  int _flashHole = -1;
  double _flashT = 0;
  bool _flashGood = false;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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
    _fall = 0.26 + _score * 0.012;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_flashT > 0) _flashT -= dt;
    _y += _fall * dt;
    if (_y >= 0.82) {
      _land();
    }
    setState(() {});
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
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
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
      _arrange();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
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
      overEmoji: '🔻',
      overText: 'Good sorting!',
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          void move(double dx) =>
              setState(() => _x = (dx / w).clamp(0.08, 0.92));
          return GestureDetector(
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
              ),
              size: Size.infinite,
            ),
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
  });
  final List<int> holes;
  final int shape;
  final double x, y;
  final List<Color> colors;
  final int flashHole;
  final bool flashGood;

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
  }

  @override
  bool shouldRepaint(_ShapeSortChutePainter oldDelegate) => true;
}
