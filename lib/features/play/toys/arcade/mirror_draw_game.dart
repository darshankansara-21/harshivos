part of '../arcade_games.dart';

/// Mirror Draw — trace the dotted path on the left and it mirrors to the right,
/// so a symmetric picture appears as you draw. Light every dot to finish the
/// pattern. Five symmetric pictures to win. Calm, creative fine-motor play.
class MirrorDrawGame extends StatefulWidget {
  const MirrorDrawGame({super.key});
  @override
  State<MirrorDrawGame> createState() => _MirrorDrawGameState();
}

class _MirrorDot {
  _MirrorDot(this.x, this.y);
  final double x, y; // left-half point (x in [0,0.5])
  bool lit = false;
}

class _MirrorDrawGameState extends State<MirrorDrawGame> with _Emit {
  static const String _id = 'mirror_draw';
  static const int _target = 5;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Lovely art!',
    'Symmetry star!',
    'Beautiful work!',
    'Artist supreme!',
  ];
  String _winPraise = _winPraisePool.first;
  // Pool of per-shape completion phrases so finishing a symmetry drawing
  // doesn't always flash the identical "Beautiful symmetry! Next" line.
  static const List<String> _nextShapePool = <String>[
    'Beautiful symmetry! Next',
    'Lovely mirroring! Next',
    'Nice matching! New shape',
    'Well drawn! Keep going',
  ];

  // Half-figures in the left pane, each a polyline of [x,y] with x in [0,0.5].
  static const List<List<List<double>>> _half = <List<List<double>>>[
    // Butterfly wing
    <List<double>>[[0.5, 0.5], [0.2, 0.25], [0.1, 0.45], [0.22, 0.6], [0.5, 0.6]],
    // Heart half
    <List<double>>[[0.5, 0.3], [0.32, 0.18], [0.14, 0.32], [0.3, 0.6], [0.5, 0.78]],
    // Tree half
    <List<double>>[[0.5, 0.8], [0.5, 0.5], [0.26, 0.5], [0.4, 0.32], [0.5, 0.2]],
    // Diamond half
    <List<double>>[[0.5, 0.2], [0.2, 0.5], [0.5, 0.8]],
    // Vase half
    <List<double>>[[0.5, 0.2], [0.34, 0.3], [0.44, 0.5], [0.3, 0.72], [0.5, 0.8]],
  ];

  final List<_MirrorDot> _dots = <_MirrorDot>[];
  // Shuffled no-repeat bag of shape indices. With exactly 5 pictures and a
  // win target of 5, plain Random()-with-replacement risked the same shape
  // repeating 2-5 times in one playthrough while another never appeared at
  // all — the same gap class already fixed in dot_to_dot / sorting_train /
  // kindness_match / weather_sort.
  final List<int> _bag = <int>[];
  int _shapeIdx = 0;
  int _score = 0;
  int _best = 0;
  bool _beatBest = false;
  String? _banner;
  // The post-shape best/next-shape banner was only ever cleared by
  // `_reset()`, so once a shape completed it stayed glued on screen through
  // the whole next shape's tracing.
  Timer? _bannerTimer;
  GameStatus _status = GameStatus.ready;

  void _flashBanner(String text, {Duration duration = const Duration(milliseconds: 1300)}) {
    _banner = text;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(duration, () {
      if (mounted) setState(() => _banner = null);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }
  // Height/width ratio of the last-seen canvas. The dots are drawn as a
  // true isotropic circle (same fixed pixel radius on both axes), but
  // `_touch` is fed coordinates normalized independently by width (x) and
  // height (y). On a portrait phone (h > w) a flat tolerance compared
  // against both deltas untouched makes the vertical hit box wider in
  // pixels than the horizontal one — the same aspect-ratio hit-test bug
  // class fixed in bug_catch/shape_builder/counting_baskets/letter_trace/
  // star_path. Track the aspect ratio and scale the y-delta by it so both
  // axes compare in width-normalized, pixel-equivalent units.
  double _aspect = 1;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int _drawShape() {
    if (_bag.isEmpty) {
      _bag.addAll(List<int>.generate(_half.length, (i) => i)..shuffle(_rnd));
    }
    return _bag.removeLast();
  }

  void _newShape() {
    _shapeIdx = _drawShape();
    _dots.clear();
    final poly = _half[_shapeIdx];
    for (var i = 0; i < poly.length - 1; i++) {
      final a = poly[i], b = poly[i + 1];
      final len = math.sqrt(
          math.pow(b[0] - a[0], 2) + math.pow(b[1] - a[1], 2)).toDouble();
      final n = math.max(1, (len / 0.12).ceil());
      for (var k = 0; k <= n; k++) {
        final t = k / n;
        final x = a[0] + (b[0] - a[0]) * t;
        final y = a[1] + (b[1] - a[1]) * t;
        if (_dots.any((d) => (d.x - x).abs() < 0.02 && (d.y - y).abs() < 0.02)) {
          continue;
        }
        _dots.add(_MirrorDot(x, y));
      }
    }
  }

  // Index of the one dot the child must trace to next, in path order. `_dots`
  // is built polyline-point-by-point in order inside `_newShape`, so "first
  // unlit dot in list order" is exactly "next point on the path" — same
  // convention as `letter_trace_game.dart`.
  int get _nextDotIdx => _dots.indexWhere((d) => !d.lit);

  // Catch tolerance for lighting the next dot. Flat at 0.06 on both axes
  // regardless of score meant picture 1 and picture 5 of the same
  // playthrough were exactly as forgiving to trace — no real difficulty
  // curve at all, the same flat-pacing gap just fixed in
  // `letter_trace_game.dart`'s `_catchTolerance`. Narrows a little as
  // `_score` climbs across the five pictures, clamped so the last picture
  // still stays comfortably tappable for small fingers.
  // That narrowing only ever read the current round's `_score`, so a
  // veteran with a high all-time `_best` restarted every playthrough at the
  // identical easy 0.06 tolerance as a first-timer — the same
  // "flat-forever difficulty never fed by career `_best`" bug class already
  // closed for the quiz-game family. Nudge the effective score a little
  // from picture 1 for a seasoned player, capped small so it stays
  // genuinely traceable even for them.
  int get _careerSkillRamp => (_best ~/ 2).clamp(0, 3);
  double get _catchTolerance =>
      (0.06 - (_score + _careerSkillRamp) * 0.004).clamp(0.045, 0.06);

  void _touch(double nx, double ny) {
    if (_status != GameStatus.playing || nx > 0.5) return;
    final idx = _nextDotIdx;
    if (idx < 0) return;
    final next = _dots[idx];
    // Only the next dot on the path can be lit. The prior behaviour matched
    // whichever unlit dot was globally nearest the touch point, so a quick
    // diagonal swipe across the left pane could light dots scattered across
    // the picture out of sequence — the same "trace order isn't enforced"
    // gap class just fixed in `letter_trace_game.dart`, and just as fatal to
    // this game's own "trace the dots" pitch (a child could "finish" a
    // picture without ever drawing its real symmetric shape).
    final tol = _catchTolerance;
    if ((next.x - nx).abs() < tol && (next.y - ny).abs() * _aspect < tol) {
      _lightDot(next);
    }
  }

  // Shared "a dot just got lit" logic, used both by the drag/tap hit-test in
  // `_touch` and by the Semantics activation path below (which lights a
  // specific dot directly rather than nearest-distance matching).
  void _lightDot(_MirrorDot d) {
    d.lit = true;
    // Tracing a symmetric picture is a pen-on-paper motion, not a quiz
    // "right answer" — use the dedicated `paper` grain cue (same one
    // `memory_flip_game.dart` uses for its card-flip texture, and
    // `letter_trace_game.dart` now uses for its own dot-tracing) instead of
    // the generic ascending `correct` chime shared by 30+ unrelated
    // quiz-style games.
    TonePlayer.instance.playCue(SoundCue.paper);
    if (_dots.every((e) => e.lit)) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      // A run abandoned mid-way (quitting after e.g. 3 of 5 shapes) still
      // silently persisted a new best - the same "stat that can never move"
      // bug class already fixed catalog-wide. Celebrate the moment a prior
      // personal best is actually crossed.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((v) {
        if (mounted) setState(() => _best = v);
      });
      if (crossedBest) _beatBest = true;
      if (_score >= _target) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        // The winning (final) shape is exactly as likely to be the one that
        // crosses `_best` as any other — but only the non-winning branch
        // below ever played the milestone chime, so a perfect personal-best
        // run silently skipped the one celebration it most deserved (the
        // same win-branch-skips-personal-best bug already fixed in
        // xylophone_tap_game/drum_garden_game).
        if (crossedBest) {
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
      } else {
        final text = crossedBest
            ? 'New personal best! 🏆'
            : _nextShapePool[_rnd.nextInt(_nextShapePool.length)];
        _flashBanner(text);
        if (crossedBest) {
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        _newShape();
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _beatBest = false;
      _bag.clear();
      _banner = null;
      _bannerTimer?.cancel();
      _newShape();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final lit = _dots.where((d) => d.lit).length;
    return _Shell(
      title: '🎨 Mirror Draw',
      introHow:
          'Trace the dots on the left — they mirror to the right to make a '
          'symmetric picture. Light them all. Five pictures to win!',
      onStart: () => setState(() {
        _newShape();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Trace the left side  ·  $lit/${_dots.length}'
              : 'Draw symmetric pictures'),
      winEmoji: '🎨',
      winText: _winPraise,
      accent: const Color(0xFFB197FC),
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
                  painter: _MirrorDrawPainter(dots: _dots, nextIdx: _nextDotIdx),
                  size: Size.infinite,
                ),
              ),
              // Dots are re-rolled only on `_newShape` (a fresh picture), so
              // their positions are static for the current round — same
              // static-zone overlay pattern as `letter_trace_game.dart`'s
              // trace dots. Tracing is now enforced in path order, so only
              // the one next dot is exposed here too — a screen-reader user
              // should be guided along the path, not offered every remaining
              // dot to activate at once (and the right side is a pure
              // mirrored render, never a separate touch target).
              if (_nextDotIdx >= 0)
                Builder(builder: (context) {
                  final d = _dots[_nextDotIdx];
                  return Positioned(
                    left: d.x * w - 0.035 * w,
                    top: d.y * h - 0.035 * w,
                    width: 0.07 * w,
                    height: 0.07 * w,
                    child: Semantics(
                      label: 'Next mirror dot',
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

class _MirrorDrawPainter extends CustomPainter {
  _MirrorDrawPainter({required this.dots, required this.nextIdx});
  final List<_MirrorDot> dots;
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
            colors: <Color>[Color(0xFF221A33), Color(0xFF120D1C)],
          ).createShader(Offset.zero & size));

    // Mirror axis.
    canvas.drawLine(
        Offset(w / 2, 0),
        Offset(w / 2, h),
        Paint()
          ..color = Colors.white12
          ..strokeWidth = 1);

    // Ink trail: connect consecutive lit dots on both the traced left half
    // and its mirrored right half, so a real symmetric picture visibly takes
    // shape as the child draws — same convention as
    // `letter_trace_game.dart`'s stroke trail. Before this, lighting a dot
    // only ever drew an isolated dot: the game's own intro promises "a
    // symmetric picture appears as you draw", but no actual picture — no
    // connected lines — ever formed, undercutting the whole "draw" pitch.
    // `_dots` is built point-by-point along the half-figure polyline in
    // `_newShape`, so consecutive list entries are always adjacent on the
    // path (no per-segment grouping needed, unlike the multi-stroke
    // letter glyphs).
    final inkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB197FC).withOpacity(0.85);
    for (var i = 1; i < dots.length; i++) {
      final prev = dots[i - 1], cur = dots[i];
      if (prev.lit && cur.lit) {
        final pLeft = Offset(prev.x * w, prev.y * h);
        final cLeft = Offset(cur.x * w, cur.y * h);
        canvas.drawLine(pLeft, cLeft, inkPaint);
        canvas.drawLine(Offset(w - pLeft.dx, pLeft.dy),
            Offset(w - cLeft.dx, cLeft.dy), inkPaint);
      }
    }

    for (var i = 0; i < dots.length; i++) {
      final d = dots[i];
      final left = Offset(d.x * w, d.y * h);
      final right = Offset((1 - d.x) * w, d.y * h);
      if (d.lit) {
        for (final c in <Offset>[left, right]) {
          canvas.drawCircle(
              c, 12, Paint()..color = const Color(0xFFB197FC).withOpacity(0.35));
          canvas.drawCircle(c, 7, Paint()..color = const Color(0xFFB197FC));
        }
      } else if (i == nextIdx) {
        // Tracing is now enforced in path order, so the one dot a touch will
        // actually light needs to read as visibly "next" — a plain identical
        // white ring for every remaining dot gave no clue which one the
        // enforced order wants, undercutting the whole fix (same convention
        // as `letter_trace_game.dart`'s next-dot ring).
        canvas.drawCircle(
            left, 14, Paint()..color = Colors.white.withOpacity(0.25));
        canvas.drawCircle(
            left,
            9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white);
      } else {
        canvas.drawCircle(
            left,
            8,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.white60);
      }
    }
  }

  @override
  bool shouldRepaint(_MirrorDrawPainter oldDelegate) => true;
}
