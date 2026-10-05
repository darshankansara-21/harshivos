part of '../arcade_games.dart';

/// Drum Garden — six singing pads. Tap freely to make music, then follow the
/// growing tune (a musical Simon). Match an 8-note tune to win.
class DrumGardenGame extends StatefulWidget {
  const DrumGardenGame({super.key});
  @override
  State<DrumGardenGame> createState() => _DrumGardenGameState();
}

class _DrumGardenGameState extends State<DrumGardenGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'drum_garden';
  static const int _pads = 6;
  static const int _cols = 3;
  static const int _target = 8;
  static const List<int> _notes = <int>[0, 2, 4, 7, 9, 11];
  static const List<Color> _colors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFB84D),
    Color(0xFFFFE066),
    Color(0xFF8CE99A),
    Color(0xFF66D9E8),
    Color(0xFFB197FC),
  ];
  final math.Random _rnd = math.Random();
  final List<int> _seq = <int>[];
  int _inputIdx = 0;
  int _phase = 0; // 0 free, 1 showing, 2 input, 3 result
  int _showIdx = 0;
  double _showT = 0;
  double _nextT = 0;
  int _flashPad = -1;
  double _flashT = 0;
  int _lives = 3;
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

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  void _startRound() {
    _seq.add(_rnd.nextInt(_pads));
    _phase = 1;
    _showIdx = 0;
    _showT = 0.5;
    _inputIdx = 0;
  }

  void _replaySequence() {
    _phase = 1;
    _showIdx = 0;
    _showT = 0.5;
    _inputIdx = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_flashT > 0) {
      _flashT -= dt;
      if (_flashT <= 0) _flashPad = -1;
    }
    if (_phase == 1) {
      _showT -= dt;
      if (_showT <= 0) {
        if (_showIdx < _seq.length) {
          _flashPad = _seq[_showIdx];
          _flashT = 0.4;
          TonePlayer.instance.playNote(_notes[_seq[_showIdx]], seconds: 0.3);
          _showIdx++;
          _showT = 0.62;
        } else {
          _phase = 2;
          _inputIdx = 0;
        }
      }
    } else if (_phase == 3) {
      _nextT -= dt;
      if (_nextT <= 0) _startRound();
    }
  }

  void _tapPad(int i) {
    if (_status != GameStatus.playing) return;
    if (_phase == 1) return; // watching the tune
    _flashPad = i;
    _flashT = 0.3;
    TonePlayer.instance.playNote(_notes[i], seconds: 0.28);
    if (_phase != 2) return; // free play between rounds
    if (i == _seq[_inputIdx]) {
      _inputIdx++;
      if (_inputIdx >= _seq.length) {
        _phase = 3;
        _nextT = 0.8;
        emit(ExperienceEvent.bubblePopped);
        if (_seq.length >= _target) {
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _flash('Nice! 🥁 Tune of ${_seq.length}');
          GameScores.instance.submit(_id, _seq.length).then((b) {
            if (mounted) setState(() => _best = b);
          });
        }
      }
    } else {
      _lives--;
      if (_lives <= 0) {
        // Out of lives ends the run — give it its own distinct game-over cue
        // instead of reusing the routine wrong-tap retry sound.
        _status = GameStatus.over;
        _flash('Out of lives!');
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        _flash('Listen again · ${'💛' * _lives}');
        _replaySequence();
      }
    }
  }

  void _reset() {
    setState(() {
      _seq.clear();
      _inputIdx = 0;
      _phase = 0;
      _flashPad = -1;
      _flashT = 0;
      _lives = 3;
      _banner = null;
      _bannerT = 0;
      _nextT = 0;
      _status = GameStatus.playing;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final phaseLabel = _phase == 1
        ? 'Listen… 🎵'
        : _phase == 2
            ? 'Your turn! ${_inputIdx}/${_seq.length}'
            : 'Tap the pads';
    return _Shell(
      title: '🥁 Drum Garden',
      introHow:
          'Tap the singing pads to make music, then repeat the tune you hear. It grows each round!',
      onStart: () => setState(() {
        _status = GameStatus.playing;
        _startRound();
      }),
      score: _seq.isEmpty ? 0 : _seq.length,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? '$phaseLabel · ${'💛' * _lives}',
      overEmoji: '🥁',
      overText: 'Keep the beat!',
      winEmoji: '🥁',
      winText: 'What a tune!',
      accent: const Color(0xFFB197FC),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final col = (d.localPosition.dx / w * _cols).floor();
              final row = (d.localPosition.dy / h * 2).floor();
              final idx = row * _cols + col;
              if (idx >= 0 && idx < _pads) _tapPad(idx);
            },
            child: CustomPaint(
              painter: _DrumPainter(
                cols: _cols,
                pads: _pads,
                colors: _colors,
                flashPad: _flashPad,
                flashT: _flashT,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _DrumPainter extends CustomPainter {
  _DrumPainter({
    required this.cols,
    required this.pads,
    required this.colors,
    required this.flashPad,
    required this.flashT,
  });
  final int cols, pads;
  final List<Color> colors;
  final int flashPad;
  final double flashT;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF241B3A), Color(0xFF15102A)],
          ).createShader(Offset.zero & size));
    final rows = (pads / cols).ceil();
    final cw = w / cols, ch = h / rows;
    for (var i = 0; i < pads; i++) {
      final col = i % cols, row = i ~/ cols;
      final c = Offset((col + 0.5) * cw, (row + 0.5) * ch);
      final r = math.min(cw, ch) * 0.38;
      final lit = flashPad == i ? (flashT / 0.4).clamp(0.0, 1.0) : 0.0;
      canvas.drawCircle(c, r + lit * 10,
          Paint()..color = colors[i].withOpacity(0.25 + lit * 0.4));
      canvas.drawCircle(c, r, Paint()..color = colors[i].withOpacity(0.85));
      canvas.drawCircle(c, r * 0.6,
          Paint()..color = Colors.white.withOpacity(0.15 + lit * 0.5));
      canvas.drawCircle(c, r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withOpacity(0.3 + lit * 0.6));
    }
  }

  @override
  bool shouldRepaint(_DrumPainter old) => true;
}

