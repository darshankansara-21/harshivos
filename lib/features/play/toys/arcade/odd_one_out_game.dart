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
      var c = _palette[_rnd.nextInt(_palette.length)];
      while (c == _baseColor) {
        c = _palette[_rnd.nextInt(_palette.length)];
      }
      _oddColor = c;
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
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrong = i;
      _lives--;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = 'Look closely…';
      if (_lives <= 0) _status = GameStatus.over;
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
      overEmoji: '🧐',
      overText: 'Sharp eyes!',
      accent: const Color(0xFF80ED99),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
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
