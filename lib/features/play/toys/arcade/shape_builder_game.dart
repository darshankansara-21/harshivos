part of '../arcade_games.dart';

/// Shape Builder — assemble the picture by tapping the slot that matches each
/// piece. Houses, rockets and more. Build five to win.
class ShapeBuilderGame extends StatefulWidget {
  const ShapeBuilderGame({super.key});
  @override
  State<ShapeBuilderGame> createState() => _ShapeBuilderGameState();
}

class _BuildSlot {
  _BuildSlot(this.shape, this.cx, this.cy, this.r, this.color);
  final int shape;
  final double cx, cy, r;
  final Color color;
  bool filled = false;
}

class _ShapeBuilderGameState extends State<ShapeBuilderGame> with _Emit {
  static const String _id = 'shape_builder';
  static const int _target = 5;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Master builder!', 'Construction champ!', 'Great building!', 'Shape master!',
  ];
  String _winPraise = _winPraisePool[0];
  List<_BuildSlot> _slots = <_BuildSlot>[];
  List<int> _order = <int>[];
  final List<int> _figOrder = <int>[0, 1, 2, 3, 4];
  int _placed = 0;
  int _fig = 0;
  int _score = 0;
  int _best = 0;
  // A run that quits after completing some figures but before the full
  // 5-figure win still submits its partial `_score` (see below) — the same
  // "stat that can never move" bug class already fixed catalog-wide (mini_
  // golf/jigsaw_four/basketball/color_mixer/counting_baskets): without this
  // flag, crossing a prior personal best mid-run was only ever reflected
  // silently in the `best` HUD number, never celebrated like every other
  // beat-your-own-record moment in the catalog.
  bool _beatBest = false;
  // `_score` (figures built) permanently caps at the 5-figure `_target` the
  // moment a run is won, so `_best` goes static forever after the first
  // completed playthrough — the same "stat that can never move again" bug
  // class already fixed in mini_golf's stroke count, jigsaw_four's rebuild
  // time, slide_puzzle's move count, counting_baskets' miss count and
  // star_path's round time. Tracks the whole 5-figure run's wall-clock
  // build time and keeps a separate, lower-is-better personal best via
  // `GameScores.submitLow`, giving a replaying child a real "build it
  // faster" goal that keeps recurring after the first win.
  static const String _timeId = '${_id}_time_ms';
  int _roundStartMs = 0;
  int _bestTimeMs = 0;
  int _finishMs = 0;
  int _wrongFlash = -1;
  String? _banner;
  // The post-figure best/"Built it!" banner was only ever cleared by
  // `_reset()`, so once one figure finished its text stayed glued on
  // screen through the whole next figure's build.
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

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) {
        setState(() {
          _best = GameScores.instance.best(_id);
          _bestTimeMs = GameScores.instance.bestLow(_timeId);
        });
      }
    });
  }

  // shapes: 0 circle,1 square,2 triangle,3 star,4 heart,5 diamond
  void _buildFigure() {
    final figs = <List<_BuildSlot>>[
      // House
      <_BuildSlot>[
        _BuildSlot(1, 0.5, 0.56, 0.16, const Color(0xFFFFD166)),
        _BuildSlot(2, 0.5, 0.33, 0.18, const Color(0xFFFF6B6B)),
      ],
      // Rocket
      <_BuildSlot>[
        _BuildSlot(2, 0.5, 0.22, 0.12, const Color(0xFFFF6B6B)),
        _BuildSlot(1, 0.5, 0.45, 0.13, const Color(0xFF66D9E8)),
        _BuildSlot(5, 0.5, 0.68, 0.14, const Color(0xFFFFD166)),
      ],
      // Tree
      <_BuildSlot>[
        _BuildSlot(2, 0.5, 0.3, 0.16, const Color(0xFF63E6BE)),
        _BuildSlot(2, 0.5, 0.48, 0.2, const Color(0xFF63E6BE)),
        _BuildSlot(1, 0.5, 0.72, 0.08, const Color(0xFF8A5A2B)),
      ],
      // Flower
      <_BuildSlot>[
        _BuildSlot(0, 0.5, 0.4, 0.1, const Color(0xFFFFD166)),
        _BuildSlot(4, 0.32, 0.4, 0.1, const Color(0xFFFF6B6B)),
        _BuildSlot(4, 0.68, 0.4, 0.1, const Color(0xFFFF6B6B)),
        _BuildSlot(1, 0.5, 0.68, 0.06, const Color(0xFF63E6BE)),
      ],
      // Star badge
      <_BuildSlot>[
        _BuildSlot(0, 0.5, 0.45, 0.2, const Color(0xFF66D9E8)),
        _BuildSlot(3, 0.5, 0.45, 0.12, const Color(0xFFFFD166)),
      ],
    ];
    _slots = figs[_figOrder[_fig % _figOrder.length]];
    for (final s in _slots) {
      s.filled = false;
    }
    _order = List<int>.generate(_slots.length, (i) => i);
    _placed = 0;
    _wrongFlash = -1;
  }

  int get _currentShape =>
      _placed < _order.length ? _slots[_order[_placed]].shape : -1;

  // The tap-tolerance pad around each slot's drawn radius was a flat 0.03 for
  // every figure, 1 through 5, of every playthrough — the same flat-precision
  // gap already fixed in `letter_trace_game.dart`/`mirror_draw_game.dart`.
  // Narrowing it as the score climbs gives this game a real difficulty curve
  // (later figures demand a more precise tap) instead of staying identical
  // throughout. `_figCount` figures total; clamp floor keeps the last figure
  // still comfortably tappable.
  static const int _figCount = 5;
  double get _tolerancePad =>
      (0.03 - _score * (0.03 - 0.016) / _figCount).clamp(0.016, 0.03);

  static const List<String> _shapeNames = <String>[
    'circle',
    'square',
    'triangle',
    'star',
    'heart',
    'diamond',
  ];

  void _tap(Offset p, double w, double h) {
    if (_status != GameStatus.playing || _placed >= _slots.length) return;
    for (var i = 0; i < _slots.length; i++) {
      final s = _slots[i];
      if (s.filled) continue;
      // Hit-test in pixel space, width-calibrated on BOTH axes: the painter
      // draws every shape's radius as `s.r * w` (sized off width only), so a
      // y-tolerance normalized by `h` would desync the vertical hit zone from
      // the visible shape on any non-square (portrait) screen — the same
      // aspect-ratio hit-test bug class already fixed in `bug_catch`,
      // `bigger_number`, `maze_marble`, etc.
      final dx = p.dx - s.cx * w;
      final dy = p.dy - s.cy * h;
      final tol = (s.r + _tolerancePad) * w;
      if (dx.abs() < tol && dy.abs() < tol) {
        if (s.shape == _currentShape) {
          s.filled = true;
          _placed++;
          TonePlayer.instance.playNote(2 + _placed * 2, seconds: 0.16);
          if (_placed >= _slots.length) {
            _score++;
            TonePlayer.instance.playCue(SoundCue.success);
            emit(ExperienceEvent.bubblePopped);
            final crossedBest = _score > _best && !_beatBest && _best > 0;
            GameScores.instance.submit(_id, _score).then((b) {
              if (mounted) setState(() => _best = b);
            });
            if (crossedBest) {
              _beatBest = true;
              _flashBanner('New personal best! 🏆');
              TonePlayer.instance.playCue(SoundCue.milestone);
              emit(ExperienceEvent.personalBest);
            } else {
              _flashBanner('Built it! 🛠️');
            }
            if (_score >= _target) {
              _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
              _status = GameStatus.won;
              _finishMs = DateTime.now().millisecondsSinceEpoch - _roundStartMs;
              final beatTime = _bestTimeMs > 0 && _finishMs < _bestTimeMs;
              GameScores.instance.submitLow(_timeId, _finishMs).then((v) {
                if (mounted) setState(() => _bestTimeMs = v);
              });
              TonePlayer.instance.playCue(SoundCue.success);
              emit(ExperienceEvent.gameCompleted);
              // A faster all-time build is its own genuine achievement,
              // distinct from — and able to keep recurring after — the
              // five-figure win itself, so it gets its own milestone chime.
              if (beatTime) {
                TonePlayer.instance.playCue(SoundCue.milestone);
                emit(ExperienceEvent.personalBest);
              }
            } else {
              _fig++;
              _buildFigure();
            }
          }
          setState(() {});
        } else {
          setState(() => _wrongFlash = i);
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
          // This game has no lives system — every wrong tap is the only
          // negative feedback a child gets, so (unlike lives-based games
          // that reserve the companion emit for the terminal mistake) it
          // must pair the sound with emit() every time, matching the
          // no-lives convention already used by _ChoiceGoalGame and
          // _PathFinderGameState. Was previously sound-only, leaving
          // Hari/Pico silent on every single mistake in this game.
          emit(ExperienceEvent.incorrectAnswer);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && _wrongFlash == i) setState(() => _wrongFlash = -1);
          });
        }
        return;
      }
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _fig = 0;
      _beatBest = false;
      _finishMs = 0;
      _roundStartMs = DateTime.now().millisecondsSinceEpoch;
      _figOrder.shuffle(_rnd);
      _banner = null;
      _bannerTimer?.cancel();
      _buildFigure();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    if (_slots.isEmpty) _buildFigure();
    return _Shell(
      title: '🛠️ Shape Builder',
      introHow:
          'A piece appears at the bottom. Tap the matching empty slot to place it and build the picture!',
      onStart: () => setState(() {
        _figOrder.shuffle(_rnd);
        _buildFigure();
        _finishMs = 0;
        _roundStartMs = DateTime.now().millisecondsSinceEpoch;
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Place the piece',
      winEmoji: '🛠️',
      // A fresh win that doesn't beat the all-time build-time record still
      // deserves to see its own time and the record to chase, matching the
      // star_path_game convention; a win mid-run reload with _finishMs still
      // 0 (shouldn't normally happen) falls back to the plain praise line.
      winText: _finishMs <= 0
          ? _winPraise
          : (_bestTimeMs > 0 && _finishMs < _bestTimeMs
              ? '$_winPraise New fastest build: ${(_finishMs / 1000).toStringAsFixed(1)}s! 🏆'
              : '$_winPraise ${(_finishMs / 1000).toStringAsFixed(1)}s'
                  '${_bestTimeMs > 0 ? ' (best ${(_bestTimeMs / 1000).toStringAsFixed(1)}s)' : ''}'),
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _tap(d.localPosition, w, h),
                child: CustomPaint(
                  painter: _BuilderPainter(
                    slots: _slots,
                    currentShape: _currentShape,
                    wrongFlash: _wrongFlash,
                  ),
                  size: Size.infinite,
                ),
              ),
              // Static per-round slot positions (`_buildFigure` sets fixed
              // `cx`/`cy` for the current figure and they don't move), so a
              // screen-reader-accessible overlay per empty slot — the same
              // static-zone pattern as `bubble_shooter_game.dart`'s aim
              // columns — lets a child using assistive tech find and tap the
              // matching shape outline directly.
              for (var i = 0; i < _slots.length; i++)
                if (!_slots[i].filled)
                  Positioned(
                    left: _slots[i].cx * w - (_slots[i].r + 0.03) * w,
                    top: _slots[i].cy * h - (_slots[i].r + 0.03) * w,
                    width: (_slots[i].r + 0.03) * w * 2,
                    height: (_slots[i].r + 0.03) * w * 2,
                    child: Semantics(
                      label:
                          '${_shapeNames[_slots[i].shape]} slot${_slots[i].shape == _currentShape ? ', current piece' : ''}',
                      button: true,
                      onTap: () => _tap(
                          Offset(_slots[i].cx * w, _slots[i].cy * h), w, h),
                      child: const SizedBox.expand(),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _BuilderPainter extends CustomPainter {
  _BuilderPainter({
    required this.slots,
    required this.currentShape,
    required this.wrongFlash,
  });
  final List<_BuildSlot> slots;
  final int currentShape, wrongFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF26314A), Color(0xFF161C2C)],
          ).createShader(Offset.zero & size));
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      final c = Offset(s.cx * w, s.cy * h);
      final r = s.r * w;
      if (s.filled) {
        _paintPolyShape(canvas, c, r, s.shape, Paint()..color = s.color);
      } else {
        _paintPolyShape(
            canvas,
            c,
            r,
            s.shape,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = wrongFlash == i
                  ? const Color(0xFFE23B3B)
                  : Colors.white.withOpacity(0.4));
      }
    }
    // Current piece tray.
    if (currentShape >= 0) {
      final tray = Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.9), width: w * 0.9, height: h * 0.16);
      canvas.drawRRect(
          RRect.fromRectAndRadius(tray, const Radius.circular(16)),
          Paint()..color = Colors.white.withOpacity(0.08));
      _paintPolyShape(canvas, tray.center, h * 0.05, currentShape,
          Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_BuilderPainter old) => true;
}

