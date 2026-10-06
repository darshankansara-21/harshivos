part of '../arcade_games.dart';

/// Letter Trace — follow the dotted path to trace a letter or number. Drag over
/// each dot to light it; fill them all and the glyph is complete. Trace five to
/// win. A calm fine-motor game built from simple straight strokes.
class LetterTraceGame extends StatefulWidget {
  const LetterTraceGame({super.key});
  @override
  State<LetterTraceGame> createState() => _LetterTraceGameState();
}

class _TraceDot {
  _TraceDot(this.x, this.y, this.strokeIdx);
  final double x, y; // screen-normalized [0,1]
  final int strokeIdx; // which stroke this dot belongs to, in glyph order
  bool lit = false;
}

class _LetterTraceGameState extends State<LetterTraceGame> with _Emit {
  static const String _id = 'letter_trace';
  static const int _target = 5;
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Great writing!" line on win screen.
  static const List<String> _winPraisePool = <String>[
    'Great writing!',
    'Perfect penmanship!',
    'Letters mastered!',
    'Five traced beautifully!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  // Pool of per-letter completion phrases so tracing the next letter doesn't
  // always flash the identical "Nice tracing! Next letter" line.
  static const List<String> _nextLetterPool = <String>[
    'Nice tracing! Next letter',
    'Well traced! One more',
    'Lovely lines! Next letter',
    'Great strokes! Keep going',
  ];

  // Each glyph is a set of straight strokes in a [0,1] box (x right, y down).
  static const Map<String, List<List<List<double>>>> _glyphs =
      <String, List<List<List<double>>>>{
    'A': <List<List<double>>>[
      <List<double>>[[0, 1], [0.5, 0]],
      <List<double>>[[0.5, 0], [1, 1]],
      <List<double>>[[0.22, 0.56], [0.78, 0.56]],
    ],
    'H': <List<List<double>>>[
      <List<double>>[[0, 0], [0, 1]],
      <List<double>>[[1, 0], [1, 1]],
      <List<double>>[[0, 0.5], [1, 0.5]],
    ],
    'L': <List<List<double>>>[
      <List<double>>[[0, 0], [0, 1]],
      <List<double>>[[0, 1], [1, 1]],
    ],
    'T': <List<List<double>>>[
      <List<double>>[[0, 0], [1, 0]],
      <List<double>>[[0.5, 0], [0.5, 1]],
    ],
    'E': <List<List<double>>>[
      <List<double>>[[1, 0], [0, 0]],
      <List<double>>[[0, 0], [0, 1]],
      <List<double>>[[0, 0.5], [0.7, 0.5]],
      <List<double>>[[0, 1], [1, 1]],
    ],
    'N': <List<List<double>>>[
      <List<double>>[[0, 1], [0, 0]],
      <List<double>>[[0, 0], [1, 1]],
      <List<double>>[[1, 1], [1, 0]],
    ],
    'V': <List<List<double>>>[
      <List<double>>[[0, 0], [0.5, 1]],
      <List<double>>[[0.5, 1], [1, 0]],
    ],
    'Z': <List<List<double>>>[
      <List<double>>[[0, 0], [1, 0]],
      <List<double>>[[1, 0], [0, 1]],
      <List<double>>[[0, 1], [1, 1]],
    ],
    '1': <List<List<double>>>[
      <List<double>>[[0.25, 0.22], [0.5, 0]],
      <List<double>>[[0.5, 0], [0.5, 1]],
    ],
    '7': <List<List<double>>>[
      <List<double>>[[0, 0], [1, 0]],
      <List<double>>[[1, 0], [0.4, 1]],
    ],
    '4': <List<List<double>>>[
      <List<double>>[[0.7, 0], [0.1, 0.62]],
      <List<double>>[[0.1, 0.62], [1, 0.62]],
      <List<double>>[[0.7, 0], [0.7, 1]],
    ],
  };
  late final List<String> _pool = _glyphs.keys.toList();
  // Shuffled no-repeat bag of glyph indices. With 11 glyphs and a win target
  // of only 5, plain `Random.nextInt()` with replacement risked the same
  // letter repeating 2-3 times in one playthrough while most of the other 10
  // never appeared at all — the same gap class already fixed in this tier's
  // own sibling files (`mirror_draw_game`'s `_bag`, `sorting_train_game`'s
  // `_bag`, `color_mixer_game`'s `_bag`) and catalog-wide in dot_to_dot /
  // kindness_match / weather_sort, just missed here.
  final List<int> _bag = <int>[];

  // The catch radius around the next dot narrows a little each letter so the
  // challenge actually ramps toward the target instead of staying identical
  // for all five letters of a playthrough — same per-round-tightening shape
  // as `steady_hand_game.dart`'s corridor `_widths` narrowing by level.
  // That narrowing only ever read the current round's `_score`, so a
  // veteran with a high all-time `_best` restarted every playthrough at the
  // identical easy 0.09 tolerance as a first-timer — the same
  // "flat-forever difficulty never fed by career `_best`" bug class already
  // closed for the quiz-game family. Nudge the effective score a little
  // from letter 1 for a seasoned player, capped small so it stays genuinely
  // traceable even for them.
  int get _careerSkillRamp => (_best ~/ 2).clamp(0, 2);
  double get _catchTolerance =>
      (0.09 - (_score + _careerSkillRamp) * 0.006).clamp(0.065, 0.09);

  final List<_TraceDot> _dots = <_TraceDot>[];
  String _glyph = 'A';
  int _score = 0;
  int _best = 0;
  bool _beatBest = false;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // height/width of the drawing canvas, refreshed every touch so the hit-test
  // below can compare real pixel distance instead of a mismatched mix of
  // width- and height-normalized units (the dots are drawn as true circles).
  double _aspect = 1;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  String _drawGlyph() {
    if (_bag.isEmpty) {
      _bag.addAll(List<int>.generate(_pool.length, (i) => i)..shuffle(_rnd));
    }
    return _pool[_bag.removeLast()];
  }

  void _newGlyph() {
    _glyph = _drawGlyph();
    _dots.clear();
    // Map glyph box into a centred region of the screen.
    const ox = 0.3, oy = 0.28, sw = 0.4, sh = 0.5;
    final strokes = _glyphs[_glyph]!;
    for (var si = 0; si < strokes.length; si++) {
      final stroke = strokes[si];
      final a = stroke.first, b = stroke.last;
      final len = math.sqrt(
          math.pow(b[0] - a[0], 2) + math.pow(b[1] - a[1], 2)).toDouble();
      final n = math.max(2, (len / 0.2).ceil());
      for (var i = 0; i <= n; i++) {
        final t = i / n;
        final gx = a[0] + (b[0] - a[0]) * t;
        final gy = a[1] + (b[1] - a[1]) * t;
        final sx = ox + gx * sw, sy = oy + gy * sh;
        // Avoid duplicate dots at shared stroke endpoints.
        if (_dots.any((d) =>
            (d.x - sx).abs() < 0.015 && (d.y - sy).abs() < 0.015)) {
          continue;
        }
        _dots.add(_TraceDot(sx, sy, si));
      }
    }
  }

  // Index of the one dot the child must trace to next, in path order. `_dots`
  // is built stroke-by-stroke, in-order along each stroke, so "first unlit
  // dot in list order" is exactly "next point on the path".
  int get _nextDotIdx => _dots.indexWhere((d) => !d.lit);

  void _touch(double nx, double ny) {
    if (_status != GameStatus.playing) return;
    final idx = _nextDotIdx;
    if (idx < 0) return;
    final next = _dots[idx];
    // Only the next dot on the path can be lit — the whole point of
    // "follow the dotted path" is tracing the shape in order. Matching
    // against the globally-nearest unlit dot (the prior behaviour) let a
    // quick diagonal swipe light far-apart dots out of sequence, skipping
    // the actual stroke and defeating the fine-motor tracing this game
    // promises in its own intro text.
    final bestD = _catchTolerance;
    // Scale the y-delta by aspect so this compares real pixel distance —
    // nx/ny are width/height-normalized respectively, so a plain isotropic
    // sqrt here would make the vertical catch radius wider or narrower
    // than the horizontal one depending on device aspect ratio.
    final dist = math.sqrt(
        math.pow(next.x - nx, 2) + math.pow((next.y - ny) * _aspect, 2));
    if (dist < bestD) _lightDot(next);
  }

  // Shared "a dot just got lit" logic, used both by the drag/tap hit-test in
  // `_touch` and by the Semantics activation path below (which lights a
  // specific dot directly rather than nearest-distance matching).
  void _lightDot(_TraceDot best) {
    best.lit = true;
    // Tracing a letter is a pen-on-paper motion, not a quiz "right answer" —
    // use the dedicated `paper` grain cue (same one `memory_flip_game.dart`
    // uses for its card-flip texture) instead of the generic ascending
    // `correct` chime shared by 30+ unrelated quiz-style games, so every dot
    // lit along the stroke actually sounds like writing.
    TonePlayer.instance.playCue(SoundCue.paper);
    if (_dots.every((d) => d.lit)) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      // A run abandoned mid-way (quitting after e.g. 3 of 5 letters) still
      // silently persisted a new best - the same "stat that can never move"
      // bug class already fixed catalog-wide. Celebrate the moment a prior
      // personal best is actually crossed.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (crossedBest) _beatBest = true;
      if (_score >= _target) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _banner = crossedBest
            ? 'New personal best! 🏆'
            : _nextLetterPool[_rnd.nextInt(_nextLetterPool.length)];
        if (crossedBest) {
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        _newGlyph();
      }
    } else {
      _banner = null;
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _beatBest = false;
      _bag.clear();
      _banner = null;
      _newGlyph();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final lit = _dots.where((d) => d.lit).length;
    return _Shell(
      title: '✍️ Letter Trace',
      introHow:
          'Drag along the dotted path to trace the letter. Light up every dot, '
          'then trace the next one. Five to win!',
      onStart: () => setState(() {
        _newGlyph();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Trace the "$_glyph"  ·  $lit/${_dots.length}'
              : 'Trace the dotted letters'),
      winEmoji: '✍️',
      winText: _winPraise,
      accent: const Color(0xFF80ED99),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          void handle(Offset p) {
            _aspect = h / w;
            _touch((p.dx / w).clamp(0.0, 1.0), (p.dy / h).clamp(0.0, 1.0));
          }

          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => handle(d.localPosition),
                onPanUpdate: (d) => handle(d.localPosition),
                onTapDown: (d) => handle(d.localPosition),
                child: CustomPaint(
                  painter: _LetterTracePainter(
                      dots: _dots, glyph: _glyph, nextIdx: _nextDotIdx),
                  size: Size.infinite,
                ),
              ),
              // Dots are re-rolled only on `_newGlyph` (a fresh letter), so
              // their positions are static for the current round — same
              // static-zone overlay pattern as `shape_builder_game.dart`'s
              // slots. Only the one next dot on the path is exposed, matching
              // the sequential-tracing rule now enforced in `_touch`: a
              // screen-reader user should be guided along the stroke order
              // too, not offered every remaining dot to activate at once.
              if (_nextDotIdx >= 0)
                Builder(builder: (context) {
                  final d = _dots[_nextDotIdx];
                  return Positioned(
                    left: d.x * w - 0.035 * w,
                    top: d.y * h - 0.035 * w,
                    width: 0.07 * w,
                    height: 0.07 * w,
                    child: Semantics(
                      label: 'Next trace dot, stroke ${d.strokeIdx + 1}',
                      button: true,
                      onTap: () => _lightDot(d),
                      child: const SizedBox.expand(),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _LetterTracePainter extends CustomPainter {
  _LetterTracePainter({required this.dots, required this.glyph, required this.nextIdx});
  final List<_TraceDot> dots;
  final String glyph;
  final int nextIdx;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF13241B), Color(0xFF0A1510)],
          ).createShader(Offset.zero & size));

    // Faint ghost glyph letter behind the dots.
    final ghost = TextPainter(
      text: TextSpan(
          text: glyph,
          style: TextStyle(
              fontSize: h * 0.52,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.05))),
      textDirection: TextDirection.ltr,
    )..layout();
    ghost.paint(canvas, Offset(w / 2 - ghost.width / 2, h * 0.24));

    // Ink trail: connect consecutive lit dots within the same stroke so the
    // letter visibly gets "written" rather than just lighting up disjoint dots.
    final inkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF57CC99).withOpacity(0.85);
    for (var i = 1; i < dots.length; i++) {
      final prev = dots[i - 1], cur = dots[i];
      if (prev.strokeIdx == cur.strokeIdx && prev.lit && cur.lit) {
        canvas.drawLine(Offset(prev.x * w, prev.y * h),
            Offset(cur.x * w, cur.y * h), inkPaint);
      }
    }

    for (var i = 0; i < dots.length; i++) {
      final d = dots[i];
      final c = Offset(d.x * w, d.y * h);
      if (d.lit) {
        canvas.drawCircle(
            c, 13, Paint()..color = const Color(0xFF80ED99).withOpacity(0.3));
        canvas.drawCircle(c, 8, Paint()..color = const Color(0xFF57CC99));
      } else if (i == nextIdx) {
        // Tracing is now enforced in path order, so the one dot a tap will
        // actually light needs to read as visibly "next" — a plain identical
        // white ring for every remaining dot gave no clue which one the
        // enforced order wants, undercutting the whole fix.
        canvas.drawCircle(
            c, 14, Paint()..color = Colors.white.withOpacity(0.25));
        canvas.drawCircle(
            c,
            9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white);
      } else {
        canvas.drawCircle(
            c,
            9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.white54);
      }
    }
  }

  @override
  bool shouldRepaint(_LetterTracePainter oldDelegate) => true;
}
