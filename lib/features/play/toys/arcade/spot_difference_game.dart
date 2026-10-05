part of '../arcade_games.dart';

/// Spot the Difference — one tile in the grid is a different colour. Tap the
/// odd one out. The grid grows as you go. Ten right to win.
class SpotDifferenceGame extends StatefulWidget {
  const SpotDifferenceGame({super.key});
  @override
  State<SpotDifferenceGame> createState() => _SpotDifferenceGameState();
}

class _SpotDifferenceGameState extends State<SpotDifferenceGame> with _Emit {
  static const String _id = 'spot_difference';
  static const int _target = 10;
  final math.Random _rnd = math.Random();
  int _cols = 3, _rows = 3;
  int _odd = 0;
  Color _base = const Color(0xFF66D9E8);
  Color _oddColor = const Color(0xFFFF6B6B);
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  int _wrongFlash = -1;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _newRound();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newRound() {
    final n = (3 + _score ~/ 3).clamp(3, 5);
    _cols = n;
    _rows = n;
    _odd = _rnd.nextInt(n * n);
    final hue = _rnd.nextDouble() * 360;
    _base = HSVColor.fromAHSV(1, hue, 0.6, 0.85).toColor();
    // The odd tile is a subtly different shade; closer as score rises.
    final delta = (0.32 - _score * 0.02).clamp(0.14, 0.32);
    _oddColor = HSVColor.fromAHSV(1, (hue + 18) % 360, 0.6, 0.85 - delta).toColor();
    _wrongFlash = -1;
  }

  void _pick(int idx) {
    if (_status != GameStatus.playing) return;
    if (idx == _odd) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Spotted it! 🔍';
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrongFlash = idx;
      _lives--;
      if (_lives <= 0) {
        // The life-ending miss is the real end of the run — it must sound
        // distinct from a routine miss, never just the same gentle-retry cue.
        _status = GameStatus.over;
        _banner = 'Out of lives!';
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'Look closely…';
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
      title: '🔍 Spot the Difference',
      introHow:
          'One tile is a slightly different colour from the rest. Tap the odd one out!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Find the odd tile · ${'💛' * _lives}',
      overEmoji: 'u{1F4AA}',
      overText: 'Out of lives — nice try!',
      winEmoji: '🔍',
      winText: 'Eagle eyes!',
      accent: const Color(0xFF66D9E8),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final col = (d.localPosition.dx / w * _cols).floor();
              final row = (d.localPosition.dy / h * _rows).floor();
              if (col < 0 || col >= _cols || row < 0 || row >= _rows) return;
              _pick(row * _cols + col);
            },
            child: CustomPaint(
              painter: _SpotPainter(
                cols: _cols,
                rows: _rows,
                odd: _odd,
                base: _base,
                oddColor: _oddColor,
                wrongFlash: _wrongFlash,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter({
    required this.cols,
    required this.rows,
    required this.odd,
    required this.base,
    required this.oddColor,
    required this.wrongFlash,
  });
  final int cols, rows, odd, wrongFlash;
  final Color base, oddColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF12131A));
    final cw = w / cols, ch = h / rows;
    for (var r = 0; r < rows; r++) {
      for (var cc = 0; cc < cols; cc++) {
        final idx = r * cols + cc;
        final rect = Rect.fromLTWH(cc * cw + 6, r * ch + 6, cw - 12, ch - 12);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(14)),
            Paint()..color = idx == odd ? oddColor : base);
        if (idx == wrongFlash) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(14)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4
                ..color = const Color(0xFFE23B3B));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SpotPainter old) => true;
}

