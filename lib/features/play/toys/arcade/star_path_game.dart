part of '../arcade_games.dart';

/// Star Path — drag from star to star, in order, to draw a glowing constellation
/// in the night sky. Reach the next star to extend the line. Complete five
/// constellations to win. A calm, flowing connect-the-stars game.
class StarPathGame extends StatefulWidget {
  const StarPathGame({super.key});
  @override
  State<StarPathGame> createState() => _StarPathGameState();
}

class _StarPathGameState extends State<StarPathGame> with _Emit {
  static const String _id = 'star_path';
  static const int _target = 5;

  // Ordered constellations in a centred [0,1] field.
  static const List<List<List<double>>> _shapes = <List<List<double>>>[
    // Kite
    <List<double>>[[0.5, 0.15], [0.78, 0.45], [0.5, 0.85], [0.22, 0.45], [0.5, 0.15]],
    // Arrow
    <List<double>>[[0.2, 0.5], [0.6, 0.5], [0.45, 0.3], [0.6, 0.5], [0.45, 0.7]],
    // Crown / W
    <List<double>>[[0.15, 0.3], [0.32, 0.72], [0.5, 0.35], [0.68, 0.72], [0.85, 0.3]],
    // Fish
    <List<double>>[[0.22, 0.5], [0.5, 0.3], [0.7, 0.5], [0.5, 0.7], [0.22, 0.5], [0.85, 0.35]],
    // House
    <List<double>>[[0.3, 0.75], [0.3, 0.45], [0.5, 0.25], [0.7, 0.45], [0.7, 0.75], [0.3, 0.75]],
  ];

  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Stargazer!', 'Star mapper!', 'Constellation champ!', 'Night sky master!',
  ];
  String _winPraise = _winPraisePool[0];
  late List<int> _order; // shuffled shape indices, replayed each pass
  int _orderPos = 0;
  late List<List<double>> _stars;
  int _shapeIdx = 0;
  int _linked = 1; // stars connected so far (first is the start)
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _order = _shuffledOrder();
    _shapeIdx = _order[0];
    _stars = _shapes[_shapeIdx];
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  // A fresh shuffle each call; re-rolls if it would repeat the shape just
  // shown so two constellations never land back-to-back.
  List<int> _shuffledOrder() {
    final order = List<int>.generate(_shapes.length, (i) => i)..shuffle(_rnd);
    if (order.first == _shapeIdx) {
      final i = 1 + _rnd.nextInt(order.length - 1);
      final tmp = order[0];
      order[0] = order[i];
      order[i] = tmp;
    }
    return order;
  }

  void _newShape() {
    _orderPos++;
    if (_orderPos >= _order.length) {
      _order = _shuffledOrder();
      _orderPos = 0;
    }
    _shapeIdx = _order[_orderPos];
    _stars = _shapes[_shapeIdx];
    _linked = 1;
  }

  // height/width of the drawing canvas, refreshed on every touch so the
  // hit-test below can compare real pixel distance instead of a mismatched
  // mix of width- and height-normalized units (the stars are drawn as true
  // isotropic circles, same radius on both axes).
  double _aspect = 1;

  void _touch(double nx, double ny) {
    if (_status != GameStatus.playing || _linked >= _stars.length) return;
    final s = _stars[_linked];
    if ((s[0] - nx).abs() < 0.07 && ((s[1] - ny) * _aspect).abs() < 0.07) {
      _linked++;
      TonePlayer.instance.playNote((_linked * 2) % 12, seconds: 0.2);
      if (_linked >= _stars.length) {
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
          _banner = 'Beautiful! Next constellation';
          _newShape();
        }
      }
      setState(() {});
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _order = List<int>.generate(_shapes.length, (i) => i)..shuffle(_rnd);
      _orderPos = 0;
      _shapeIdx = _order[0];
      _stars = _shapes[_shapeIdx];
      _linked = 1;
      _banner = null;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '⭐ Star Path',
      introHow:
          'Drag from star to star, in order, to draw the constellation. Reach '
          'the next star to connect it. Five to win!',
      onStart: () => setState(() {
        _linked = 1;
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Connect the stars  ·  $_linked/${_stars.length}'
              : 'Trace the star paths'),
      winEmoji: '⭐',
      winText: _winPraise,
      accent: const Color(0xFFFFE066),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          void handle(Offset p) {
            _aspect = h / w;
            _touch((p.dx / w).clamp(0.0, 1.0), (p.dy / h).clamp(0.0, 1.0));
          }
          Widget? nextStarOverlay;
          if (_status == GameStatus.playing && _linked < _stars.length) {
            final s = _stars[_linked];
            const r = 24.0;
            nextStarOverlay = Positioned(
              left: s[0] * w - r,
              top: s[1] * h - r,
              width: r * 2,
              height: r * 2,
              child: Semantics(
                label: 'Next star, ${_linked + 1} of ${_stars.length}',
                onTap: () => _touch(s[0], s[1]),
                child: const SizedBox.expand(),
              ),
            );
          }
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => handle(d.localPosition),
                onPanUpdate: (d) => handle(d.localPosition),
                onTapDown: (d) => handle(d.localPosition),
                child: CustomPaint(
                  painter: _StarPathPainter(stars: _stars, linked: _linked),
                  size: Size.infinite,
                ),
              ),
              if (nextStarOverlay != null) nextStarOverlay,
            ],
          );
        },
      ),
    );
  }
}

class _StarPathPainter extends CustomPainter {
  _StarPathPainter({required this.stars, required this.linked});
  final List<List<double>> stars;
  final int linked;

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = i / 10 * math.pi * 2 - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0B1026), Color(0xFF05070F)],
          ).createShader(Offset.zero & size));

    // Connected line so far.
    final line = Paint()
      ..color = const Color(0xFFFFE066)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < linked; i++) {
      canvas.drawLine(Offset(stars[i - 1][0] * w, stars[i - 1][1] * h),
          Offset(stars[i][0] * w, stars[i][1] * h), line);
    }

    for (var i = 0; i < stars.length; i++) {
      final c = Offset(stars[i][0] * w, stars[i][1] * h);
      final done = i < linked;
      final next = i == linked;
      if (done || next) {
        canvas.drawCircle(c, 20,
            Paint()..color = const Color(0xFFFFE066).withOpacity(next ? 0.35 : 0.2));
      }
      _star(canvas, c, next ? 15 : 11,
          done ? const Color(0xFFFFF3B0) : (next ? Colors.white : Colors.white54));
    }
  }

  @override
  bool shouldRepaint(_StarPathPainter oldDelegate) => true;
}
