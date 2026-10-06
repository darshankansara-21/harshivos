part of '../arcade_games.dart';

/// Pattern Weaver — a repeating bead pattern with one bead missing. Tap the
/// colour that comes next. Patterns get longer. Ten right to win.
class PatternWeaverGame extends StatefulWidget {
  const PatternWeaverGame({super.key});
  @override
  State<PatternWeaverGame> createState() => _PatternWeaverGameState();
}

class _PatternWeaverGameState extends State<PatternWeaverGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'pattern_weaver';
  static const int _target = 10;
  static const List<Color> _palette = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
  ];
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Pattern pro!',
    'Weaving wizard!',
    'Sharp sequencer!',
    'Pattern master!',
  ];
  String _winPraise = _winPraisePool.first;
  String _overPraise = _gentleTryAgainPool[0];
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;

  // Screen-reader users can't see the bead colours, so describe each visible
  // bead by its paired colour+shape (matching _shapeForColor in the painter,
  // where colour index == shape index) and expose the full pattern sequence
  // plus each answer pad's own appearance — never which pad is correct — so
  // a blind child must spot the repeat themselves exactly as a sighted
  // child reads the beads by eye.
  static const List<String> _colorNames = <String>['red', 'yellow', 'teal', 'sky blue'];
  static const List<String> _shapeNames = <String>['circle', 'square', 'triangle', 'star'];
  String _beadName(int c) => '${_colorNames[c]} ${_shapeNames[c]}';
  List<int> _pattern = <int>[0, 1];
  int _visible = 4;
  int _answer = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  bool _beatBest = false;
  int _wrongFlash = -1;
  double _wrongT = 0;
  double _pop = 0;
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

  int get _colorCount => _score >= 6 ? 4 : 3;

  // The header promises "patterns get longer" across the whole ten-round
  // climb, but the old code only ever widened the period band once (at
  // score 4) and then stayed flat for the remaining six rounds to the win —
  // the same claimed-escalation-but-absent bug class as counting_baskets.
  // This steps the ceiling up every three correct answers so the longest
  // possible pattern keeps growing all the way to the target.
  int get _maxPeriod => (2 + _score ~/ 3).clamp(2, 5);

  void _newRound() {
    final period = 2 + _rnd.nextInt(_maxPeriod - 1); // 2.._maxPeriod
    _pattern = <int>[];
    for (var i = 0; i < period; i++) {
      int c;
      do {
        c = _rnd.nextInt(_colorCount);
      } while (i > 0 && c == _pattern[i - 1] && period > 2);
      _pattern.add(c);
    }
    // `_visible` used to always equal exactly `period * 2`, so the missing
    // bead's index-within-period (`_visible % period`) was always 0 — the
    // correct answer was always, mathematically, whatever colour/shape sat
    // in the very first slot of the pattern. A child could learn "the
    // answer always matches the leftmost bead" after a few rounds and win
    // without ever actually tracking the repeat, defeating the whole
    // pattern-recognition premise. Showing two full cycles plus a random
    // partial-cycle offset keeps the repeat genuinely visible (so it's still
    // solvable) while moving the missing slot around the period, so the
    // answer is sometimes pattern[1], pattern[2], etc. — not always [0].
    final offset = _rnd.nextInt(period);
    _visible = period * 2 + offset;
    _answer = _pattern[offset];
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_wrongT > 0) {
      _wrongT -= dt;
      if (_wrongT <= 0) _wrongFlash = -1;
    }
    if (_pop > 0) _pop -= dt;
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
  }

  void _pick(int color, int idx) {
    if (_status != GameStatus.playing) return;
    if (color == _answer) {
      _score++;
      _pop = 0.4;
      final bitCount = _reduceMotion ? 4 : 12;
      for (var i = 0; i < bitCount; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard(0.5, 0.32, math.cos(a) * sp, math.sin(a) * sp,
            _palette[color]));
      }
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'You wove it! 🧶';
      _bannerT = 1.0;
      // A child who runs out of lives right after this tap still deserves
      // the companion's loudest celebration if it's a genuine all-time
      // record, not just the routine correct-tap chime.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (crossedBest) {
        _beatBest = true;
        _banner = 'New personal best! 🏆';
        _bannerT = 1.0;
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_score >= _target) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrongFlash = idx;
      _wrongT = 0.5;
      _lives--;
      // Every wrong tap deserves the companion's gentle encouraging
      // reaction, not just the one that happens to end the game.
      emit(ExperienceEvent.incorrectAnswer);
      if (_lives <= 0) {
        // The life-ending miss is the real end of the run — it must sound
        // distinct from a routine miss, never just the same gentle-retry cue.
        _status = GameStatus.over;
        _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
        _banner = 'Out of lives!';
        _bannerT = 1.2;
        TonePlayer.instance.playCue(SoundCue.gameOver);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'Look at the pattern…';
        _bannerT = 1.0;
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _beatBest = false;
      _banner = null;
      _bannerT = 0;
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '🧶 Pattern Weaver',
      introHow:
          'Look at the repeating colours, then tap the one that comes next in the pattern! '
          'A wrong tap costs one of your 3 lives.',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'What comes next? · ${'💛' * _lives}',
      overEmoji: '💪',
      overText: _overPraise,
      winEmoji: '🧶',
      winText: _winPraise,
      accent: const Color(0xFF63E6BE),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          // Build a left-to-right description of every visible bead, with
          // the still-blank missing bead called out by its own position so
          // a screen-reader user can find the repeat without ever being
          // told the answer outright.
          final period = _pattern.length;
          final beadDesc = <String>[];
          for (var i = 0; i < _visible; i++) {
            beadDesc.add(_beadName(_pattern[i % period]));
          }
          beadDesc.add('missing bead');
          final overlays = <Widget>[
            Positioned(
              left: 0,
              top: 0,
              width: w,
              height: h * 0.6,
              child: Semantics(
                label: 'Pattern so far: ${beadDesc.join(', ')}',
                child: const SizedBox.expand(),
              ),
            ),
          ];
          for (var i = 0; i < _colorCount; i++) {
            final cw = w / _colorCount;
            overlays.add(Positioned(
              left: i * cw,
              top: h * 0.6,
              width: cw,
              height: h * 0.4,
              child: Semantics(
                label: 'Option ${i + 1}: ${_beadName(i)}',
                button: true,
                onTap: () => _pick(i, i),
                child: const SizedBox.expand(),
              ),
            ));
          }
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (d.localPosition.dy < h * 0.6) return;
                  final i = (d.localPosition.dx / w * _colorCount)
                      .floor()
                      .clamp(0, _colorCount - 1);
                  _pick(i, i);
                },
                child: CustomPaint(
                  painter: _PatternPainter(
                    palette: _palette,
                    pattern: _pattern,
                    visible: _visible,
                    colorCount: _colorCount,
                    wrongFlash: _wrongFlash,
                    pop: _pop,
                    bits: _bits,
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

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.palette,
    required this.pattern,
    required this.visible,
    required this.colorCount,
    required this.wrongFlash,
    required this.pop,
    required this.bits,
  });
  final List<Color> palette;
  final List<int> pattern;
  final int visible, colorCount, wrongFlash;
  final double pop;
  final List<_Shard> bits;

  // One fixed shape per colour (circle/square/triangle/star) so a
  // colour-blind child can read the pattern by silhouette alone — this was
  // the one remaining matching game drawing both its beads and its answer
  // pads as flat colour-only swatches, the same gap already fixed for
  // sorting_train/odd_one_out/shadow_match via the shared _paintPolyShape
  // helper.
  static const List<int> _shapeForColor = <int>[0, 1, 2, 3];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1E2A3A), Color(0xFF131C28)],
          ).createShader(Offset.zero & size));
    final period = pattern.length;
    final n = visible + 1;
    final slot = w / (n + 1);
    final r = math.min(slot * 0.38, h * 0.08);
    final y = h * 0.32;
    // String line.
    canvas.drawLine(Offset(slot * 0.5, y), Offset(w - slot * 0.5, y),
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 2);
    for (var i = 0; i < n; i++) {
      final cx = slot * (i + 1);
      if (i < visible) {
        final colIdx = pattern[i % period];
        canvas.drawCircle(Offset(cx, y), r, Paint()..color = palette[colIdx]);
        _paintPolyShape(canvas, Offset(cx, y), r * 0.45, _shapeForColor[colIdx],
            Paint()..color = Colors.white.withOpacity(0.85));
      } else {
        // The missing bead.
        final pr = r * (1 + pop * 0.6);
        canvas.drawCircle(Offset(cx, y), pr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white70);
        final tp = TextPainter(
          text: const TextSpan(
              text: '?',
              style: TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, y - tp.height / 2));
      }
    }
    // Option pads.
    final padTop = h * 0.62;
    final pw = w / colorCount;
    for (var i = 0; i < colorCount; i++) {
      final rect = Rect.fromLTWH(i * pw + 10, padTop, pw - 20, h * 0.3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(16)),
          Paint()
            ..color = wrongFlash == i
                ? const Color(0xFFE23B3B)
                : palette[i]);
      if (wrongFlash != i) {
        _paintPolyShape(canvas, rect.center, math.min(rect.width, rect.height) * 0.22,
            _shapeForColor[i], Paint()..color = Colors.white.withOpacity(0.85));
      }
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => true;
}

