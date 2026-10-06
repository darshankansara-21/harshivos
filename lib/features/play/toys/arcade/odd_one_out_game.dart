part of '../arcade_games.dart';

/// Odd One Out — every tile is the same except one. Tap the tile that is
/// different (a different shape or colour). The grid grows and the difference
/// gets subtler. A wrong tap costs a life; ten right to win.
class OddOneOutGame extends StatefulWidget {
  const OddOneOutGame({super.key});
  @override
  State<OddOneOutGame> createState() => _OddOneOutGameState();
}

class _OddOneOutGameState extends State<OddOneOutGame> with _Emit {
  static const String _id = 'odd_one_out';
  static const int _target = 10;
  static const List<Color> _palette = <Color>[
    Color(0xFFE63946), Color(0xFF48CAE4), Color(0xFFFFD166),
    Color(0xFF80ED99), Color(0xFF9B5DE5), Color(0xFFFF8ED8),
  ];
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Sharp eyes!',
    'Eagle vision!',
    'Spot-on!',
    'Detail detective!',
  ];
  String _winPraise = _winPraisePool.first;

  int _cols = 2;
  int _oddIndex = 0;
  int _baseShape = 0, _oddShape = 0;
  Color _baseColor = _palette[0], _oddColor = _palette[1];
  int _score = 0, _lives = 3, _best = 0;
  int _wrong = -1;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int get _count => _cols * _cols;

  // Screen-reader users can't see shape/colour, so expose the same
  // description a sighted child reads visually (shape + colour per tile)
  // instead of announcing the answer — they compare descriptions themselves,
  // same as comparing tiles by eye.
  static const List<String> _shapeNames = <String>[
    'circle', 'square', 'triangle', 'star', 'heart', 'diamond',
  ];
  static const List<String> _colorNames = <String>[
    'red', 'blue', 'yellow', 'green', 'purple', 'pink',
  ];

  String _colorName(Color c) {
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < _palette.length; i++) {
      final p = _palette[i];
      final dist = ((p.red - c.red) * (p.red - c.red) +
              (p.green - c.green) * (p.green - c.green) +
              (p.blue - c.blue) * (p.blue - c.blue))
          .toDouble();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    final baseHsl = HSLColor.fromColor(_palette[best]);
    final hsl = HSLColor.fromColor(c);
    final shade = (hsl.lightness - baseHsl.lightness).abs() < 0.03
        ? ''
        : hsl.lightness > baseHsl.lightness
            ? 'light '
            : 'dark ';
    return '$shade${_colorNames[best]}';
  }

  Color _subtleOddColor(Color base) {
    final progress = (_score / (_target - 1)).clamp(0.0, 1.0);
    final delta = 0.24 - progress * 0.14;
    final hsl = HSLColor.fromColor(base);
    final lighten = (0.88 - hsl.lightness) >= (hsl.lightness - 0.12);
    return hsl
        .withLightness(
            (hsl.lightness + (lighten ? delta : -delta)).clamp(0.12, 0.88))
        .toColor();
  }

  void _newRound() {
    _wrong = -1;
    _cols = (2 + _score ~/ 3).clamp(2, 5);
    _baseShape = _rnd.nextInt(6);
    _baseColor = _palette[_rnd.nextInt(_palette.length)];
    _oddIndex = _rnd.nextInt(_count);
    // Half the time differ by shape, half by colour.
    if (_rnd.nextBool()) {
      _oddShape = (_baseShape + 1 + _rnd.nextInt(5)) % 6;
      _oddColor = _baseColor;
    } else {
      _oddShape = _baseShape;
      _oddColor = _subtleOddColor(_baseColor);
    }
  }

  void _tap(int i) {
    if (_status != GameStatus.playing) return;
    if (i == _oddIndex) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'You found it!';
      GameScores.instance.submit(_id, _score).then((v) {
        if (mounted) setState(() => _best = v);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrong = i;
      _lives--;
      if (_lives <= 0) {
        _status = GameStatus.over;
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
        _banner = 'Out of lives!';
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'Look closely…';
        // Without this, the red flash on a missed tile stayed stuck for the
        // rest of the round — the whole time a child kept searching for the
        // real odd one out — instead of the brief mistake cue every other
        // sort/match game in the catalog gives.
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _wrong == i) setState(() => _wrong = -1);
        });
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _banner = null;
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🧐 Odd One Out',
      introHow:
          'Every tile is the same except one. Tap the one that is different. '
          'Ten right to win!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Spot the different one  ·  ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '🧐',
      winText: _winPraise,
      accent: const Color(0xFF80ED99),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final top = h * 0.14, gh = h * 0.82;
          final cellW = w / _cols, cellH = gh / _cols;
          // Screen-reader overlay: one Semantics button per tile describing
          // its shape + colour, so a blind child can compare descriptions
          // the same way a sighted child compares tiles by eye, instead of
          // this whole game being silently unplayable without sight.
          final tiles = <Widget>[];
          for (var i = 0; i < _count; i++) {
            final gx = i % _cols, gy = i ~/ _cols;
            final isOdd = i == _oddIndex;
            final shapeName = _shapeNames[isOdd ? _oddShape : _baseShape];
            final colorName = _colorName(isOdd ? _oddColor : _baseColor);
            tiles.add(Positioned(
              left: gx * cellW,
              top: top + gy * cellH,
              width: cellW,
              height: cellH,
              child: Semantics(
                label: 'Row ${gy + 1} column ${gx + 1}: $colorName $shapeName',
                button: true,
                onTap: () => _tap(i),
                child: const SizedBox.expand(),
              ),
            ));
          }
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (d.localPosition.dy < h * 0.14) return;
                  final gx = (d.localPosition.dx / w * _cols).floor().clamp(0, _cols - 1);
                  final gy = (((d.localPosition.dy - h * 0.14) / (h * 0.82)) * _cols)
                      .floor()
                      .clamp(0, _cols - 1);
                  _tap(gy * _cols + gx);
                },
                child: CustomPaint(
                  painter: _OddOneOutPainter(
                    cols: _cols,
                    count: _count,
                    oddIndex: _oddIndex,
                    baseShape: _baseShape,
                    oddShape: _oddShape,
                    baseColor: _baseColor,
                    oddColor: _oddColor,
                    wrong: _wrong,
                  ),
                  size: Size.infinite,
                ),
              ),
              ...tiles,
            ],
          );
        },
      ),
    );
  }
}

class _OddOneOutPainter extends CustomPainter {
  _OddOneOutPainter({
    required this.cols,
    required this.count,
    required this.oddIndex,
    required this.baseShape,
    required this.oddShape,
    required this.baseColor,
    required this.oddColor,
    required this.wrong,
  });
  final int cols, count, oddIndex, baseShape, oddShape, wrong;
  final Color baseColor, oddColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF141A22), Color(0xFF0B0F15)],
          ).createShader(Offset.zero & size));

    final top = h * 0.14, gh = h * 0.82;
    final cellW = w / cols, cellH = gh / cols;
    final r = math.min(cellW, cellH) * 0.32;
    for (var i = 0; i < count; i++) {
      final gx = i % cols, gy = i ~/ cols;
      final c = Offset(gx * cellW + cellW / 2, top + gy * cellH + cellH / 2);
      if (wrong == i) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: c, width: cellW * 0.9, height: cellH * 0.9),
                const Radius.circular(10)),
            Paint()..color = const Color(0xFFE23B3B).withOpacity(0.4));
      }
      final isOdd = i == oddIndex;
      _paintPolyShape(canvas, c, r, isOdd ? oddShape : baseShape,
          Paint()..color = isOdd ? oddColor : baseColor);
    }
  }

  @override
  bool shouldRepaint(_OddOneOutPainter oldDelegate) => true;
}
