part of '../arcade_games.dart';

/// Shadow Match — a bright shape sits on top. Tap its matching shadow below.
/// Visual matching that gets trickier. Ten right to win.
class ShadowMatchGame extends StatefulWidget {
  const ShadowMatchGame({super.key});
  @override
  State<ShadowMatchGame> createState() => _ShadowMatchGameState();
}

class _ShadowMatchGameState extends State<ShadowMatchGame> with _Emit {
  static const String _id = 'shadow_match';
  static const int _target = 10;
  static const List<Color> _tint = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
    Color(0xFFB197FC),
    Color(0xFFFF9E00),
  ];
  final math.Random _rnd = math.Random();
  int _shape = 0;
  Color _shapeColor = _tint[0];
  List<int> _options = <int>[0, 1, 2, 3];
  int _answer = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  int _wrongFlash = -1;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  // Screen-reader users can't see the bright shape or its black shadows, so
  // expose the same shape name a sighted child reads visually per option —
  // never which one is correct — so they compare descriptions themselves,
  // exactly as a sighted child compares shapes by eye.
  static const List<String> _shapeNames = <String>[
    'circle', 'square', 'triangle', 'star', 'heart', 'diamond',
  ];

  @override
  void initState() {
    super.initState();
    _newRound();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  // More shadows to scan gets genuinely harder: 4 options at the start,
  // climbing to all 6 possible shapes by the final rounds, so the last
  // stretch before winning is a real step up from round 1 (was previously a
  // flat 4-option round every time despite the game claiming "gets trickier").
  int get _optionCount => (4 + _score ~/ 4).clamp(4, 6);

  void _newRound() {
    _shape = _rnd.nextInt(6);
    _shapeColor = _tint[_rnd.nextInt(_tint.length)];
    final count = _optionCount;
    final opts = <int>{_shape};
    while (opts.length < count) {
      opts.add(_rnd.nextInt(6));
    }
    _options = opts.toList()..shuffle(_rnd);
    _answer = _options.indexOf(_shape);
    _wrongFlash = -1;
  }

  void _pick(int idx) {
    if (_status != GameStatus.playing) return;
    if (idx == _answer) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Match! 🌟';
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
      // A miss is a brief, honest mistake cue — not a state that sticks
      // around for the rest of the child's search for the right shadow.
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted && _wrongFlash == idx) setState(() => _wrongFlash = -1);
      });
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
        _banner = 'Look at the shape…';
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
      title: '🫥 Shadow Match',
      introHow:
          'A bright shape is on top. Tap the shadow underneath that has the same shape!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Find the shadow · ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '🫥',
      winText: 'Sharp eyes!',
      accent: const Color(0xFFB197FC),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final n = _options.length;
          final lw = w / n;
          // Screen-reader overlay: the top shape is announced on its own
          // (informational, matches what a sighted child already sees), and
          // each bottom shadow gets its own tappable Semantics button naming
          // only its own shape — never which one matches — so a blind child
          // must compare announced names the same way a sighted child
          // compares silhouettes by eye.
          final overlays = <Widget>[
            Positioned(
              left: 0,
              top: 0,
              width: w,
              height: h * 0.5,
              child: Semantics(
                label: 'Shape to match: ${_shapeNames[_shape]}',
                child: const SizedBox.expand(),
              ),
            ),
          ];
          for (var i = 0; i < n; i++) {
            overlays.add(Positioned(
              left: i * lw,
              top: h * 0.5,
              width: lw,
              height: h * 0.5,
              child: Semantics(
                label: 'Shadow ${i + 1}: ${_shapeNames[_options[i]]}',
                button: true,
                onTap: () => _pick(i),
                child: const SizedBox.expand(),
              ),
            ));
          }
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (d.localPosition.dy < h * 0.5) return;
                  final i = (d.localPosition.dx / w * n).floor().clamp(0, n - 1);
                  _pick(i);
                },
                child: CustomPaint(
                  painter: _ShadowPainter(
                    shape: _shape,
                    shapeColor: _shapeColor,
                    options: _options,
                    wrongFlash: _wrongFlash,
                  ),
                  size: Size.infinite,
                ),
              ),
              ...overlays,
            ],
          );
        },
      ),
    );
  }
}

class _ShadowPainter extends CustomPainter {
  _ShadowPainter({
    required this.shape,
    required this.shapeColor,
    required this.options,
    required this.wrongFlash,
  });
  final int shape;
  final Color shapeColor;
  final List<int> options;
  final int wrongFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2A2140), Color(0xFF17122A)],
          ).createShader(Offset.zero & size));
    // The bright shape.
    _paintPolyShape(canvas, Offset(w * 0.5, h * 0.26), w * 0.12, shape,
        Paint()..color = shapeColor);
    // Shadow options along the bottom.
    final n = options.length;
    final lw = w / n;
    final r = math.min(w * 0.1, lw * 0.4);
    for (var i = 0; i < n; i++) {
      final c = Offset((i + 0.5) * lw, h * 0.72);
      if (wrongFlash == i) {
        canvas.drawCircle(c, r * 1.3,
            Paint()..color = const Color(0xFFE23B3B).withOpacity(0.4));
      }
      _paintPolyShape(canvas, c, r, options[i],
          Paint()..color = Colors.black.withOpacity(0.72));
    }
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => true;
}

