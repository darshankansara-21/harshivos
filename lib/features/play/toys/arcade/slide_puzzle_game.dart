part of '../arcade_games.dart';

/// Slide Puzzle — tap a tile next to the empty space to slide it. Put the
/// numbers 1–8 back in order to solve the board. Solve three boards to win.
class SlidePuzzleGame extends StatefulWidget {
  const SlidePuzzleGame({super.key});
  @override
  State<SlidePuzzleGame> createState() => _SlidePuzzleGameState();
}

class _SlidePuzzleGameState extends State<SlidePuzzleGame> with _Emit {
  static const String _id = 'slide_puzzle';
  static const int _target = 3;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Puzzle master!', 'Sliding star!', 'Puzzle pro!', 'Great solving!',
  ];
  String _winPraise = _winPraisePool[0];
  // Pool of per-board completion phrases so solving a slide puzzle board
  // doesn't always flash the identical "Solved! Next board" line.
  static const List<String> _nextBoardPool = <String>[
    'Solved! Next board',
    'Nice sliding! New board',
    'Puzzle solved! One more',
    'Great work! Next board',
  ];
  // Position -> tile value; 0 is the empty space. Solved = [1..8, 0].
  List<int> _tiles = <int>[1, 2, 3, 4, 5, 6, 7, 8, 0];
  int _score = 0;
  int _moves = 0;
  int _best = 0;
  // `_moves` is shown live in the banner every round ("Board X · Y moves"),
  // dangling a "fewer moves is better" promise exactly like mini_golf's
  // stroke count — but it only ever reset per board and was never summed or
  // compared against anything, so a genuinely tighter 3-board run (the real
  // skill signal this stat implies) could never be recognized or beaten.
  // Mirror mini_golf's `_strokesId`/`submitLow`/`bestLow` pattern: track the
  // whole run's total moves and a separate, lower-is-better personal best.
  static const String _movesId = '${_id}_moves';
  int _totalMoves = 0;
  int _bestMoves = 0;
  String? _banner;
  // The post-board "Next board" banner was only ever cleared by `_reset()`,
  // so once one board solved it stayed glued on screen through the next.
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
          _bestMoves = GameScores.instance.bestLow(_movesId);
        });
      }
    });
  }

  bool get _solved {
    for (var i = 0; i < 8; i++) {
      if (_tiles[i] != i + 1) return false;
    }
    return true;
  }

  // Board 1 of every single run used the identical 70-move scramble
  // regardless of a returning player's all-time best — the same
  // "flat-forever opening pace never fed by career `_best`" bug class
  // already closed catalog-wide (skee_ball's bands, stack's opening speed,
  // balloon_bounce's gravity). Small, capped head start so a proven solver
  // meets a slightly deeper opening scramble from board one.
  double get _careerSkillRamp => (_best / _target).clamp(0.0, 1.0) * 25;

  void _shuffle() {
    _tiles = <int>[1, 2, 3, 4, 5, 6, 7, 8, 0];
    _moves = 0;
    var blank = 8;
    // All 3 boards used the exact same 80-move scramble, so the "challenge
    // curve" CLAUDE.md asks for was flat: board 3 never felt any harder to
    // untangle than board 1, unlike every other multi-round game in this
    // catalog (mini_golf's tighter sink window, memory_deluxe's growing
    // board, fruit_catch's rising fall speed). A deeper random walk away
    // from solved statistically needs more real moves to undo, so scale the
    // scramble length with the board already solved (_score).
    final scrambleMoves = 70 + _score * 35 + _careerSkillRamp.round();
    for (var i = 0; i < scrambleMoves; i++) {
      final n = _neighbours(blank);
      final pick = n[_rnd.nextInt(n.length)];
      _tiles[blank] = _tiles[pick];
      _tiles[pick] = 0;
      blank = pick;
    }
    if (_solved) _shuffle();
  }

  List<int> _neighbours(int p) {
    final r = p ~/ 3, c = p % 3;
    final out = <int>[];
    if (r > 0) out.add(p - 3);
    if (r < 2) out.add(p + 3);
    if (c > 0) out.add(p - 1);
    if (c < 2) out.add(p + 1);
    return out;
  }

  void _tapCell(int p) {
    if (_status != GameStatus.playing) return;
    final blank = _tiles.indexOf(0);
    if (!_neighbours(p).contains(blank)) {
      // A tap on a tile that isn't next to the empty space moves nothing —
      // without ANY cue here, that tap is silent and visually identical to
      // a touch that never registered at all, so a child can't tell "that
      // tile can't move yet" from "my finger missed the board". A light
      // generic tap cue (the same one used for other no-op taps elsewhere
      // in the catalog) confirms the touch landed, just didn't move a tile.
      if (_tiles[p] != 0) TonePlayer.instance.playCue(SoundCue.tap);
      return;
    }
    _tiles[blank] = _tiles[p];
    _tiles[p] = 0;
    _moves++;
    _totalMoves++;
    TonePlayer.instance.playCue(SoundCue.wood);
    if (_solved) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        _status = GameStatus.won;
        // A full 3-board run that genuinely beats the fewest-total-moves
        // record is the real "did you solve it better" moment this game's
        // own move counter is built around — give it the same milestone
        // chime + companion celebration every other beat-your-best moment
        // in the catalog gets, layered onto (not replacing) the win fanfare.
        final beatMoves = _bestMoves > 0 && _totalMoves < _bestMoves;
        GameScores.instance.submitLow(_movesId, _totalMoves).then((b) {
          if (mounted) setState(() => _bestMoves = b);
        });
        if (beatMoves) {
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _flashBanner(_nextBoardPool[_rnd.nextInt(_nextBoardPool.length)]);
        _shuffle();
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _totalMoves = 0;
      _banner = null;
      _bannerTimer?.cancel();
      _shuffle();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final beatMoves = _status == GameStatus.won &&
        _bestMoves > 0 &&
        _totalMoves < _bestMoves;
    final runWinText = beatMoves
        ? '$_winPraise New best run: $_totalMoves moves! 🏆'
        : '$_winPraise $_totalMoves moves'
            '${_bestMoves > 0 ? ' (best $_bestMoves)' : ''}';
    return _Shell(
      title: '🔀 Slide Puzzle',
      introHow:
          'Tap a tile next to the empty space to slide it. Put 1 to 8 back in '
          'order. Solve three boards to win!',
      onStart: () => setState(() {
        _shuffle();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Board ${_score + 1}  ·  $_moves moves'
                  '${_bestMoves > 0 ? ' · best run $_bestMoves' : ''}'
              : 'Slide the numbers into order'),
      winEmoji: '🔀',
      winText: runWinText,
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final board = math.min(w * 0.86, h * 0.56);
          final ox = (w - board) / 2, oy = (h - board) / 2 + h * 0.04;
          final cell = board / 3;
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final lx = d.localPosition.dx - ox, ly = d.localPosition.dy - oy;
                  if (lx < 0 || ly < 0 || lx > board || ly > board) return;
                  final col = (lx / cell).floor().clamp(0, 2);
                  final row = (ly / cell).floor().clamp(0, 2);
                  _tapCell(row * 3 + col);
                },
                child: CustomPaint(
                  painter: _SlidePuzzlePainter(
                      tiles: _tiles, ox: ox, oy: oy, cell: cell),
                  size: Size.infinite,
                ),
              ),
              // The board's current arrangement (which number sits in which
              // cell) is drawn only onto the canvas, so it was completely
              // invisible to screen readers — a blind child had no way to
              // touch-explore the grid and discover the puzzle state. These
              // invisible Semantics overlays let TalkBack/VoiceOver announce
              // each cell's tile (or the empty space) as a finger explores
              // the board, and each one is independently tappable too.
              for (var p = 0; p < 9; p++)
                Positioned(
                  left: ox + (p % 3) * cell,
                  top: oy + (p ~/ 3) * cell,
                  width: cell,
                  height: cell,
                  child: Semantics(
                    label: _tiles[p] == 0 ? 'Empty space' : 'Tile ${_tiles[p]}',
                    button: _tiles[p] != 0,
                    onTap: () => _tapCell(p),
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

class _SlidePuzzlePainter extends CustomPainter {
  _SlidePuzzlePainter({
    required this.tiles,
    required this.ox,
    required this.oy,
    required this.cell,
  });
  final List<int> tiles;
  final double ox, oy, cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF17202B), Color(0xFF0C1118)],
          ).createShader(Offset.zero & size));

    // Board frame.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(ox - 6, oy - 6, cell * 3 + 12, cell * 3 + 12),
            const Radius.circular(14)),
        Paint()..color = Colors.black26);

    for (var p = 0; p < 9; p++) {
      final v = tiles[p];
      if (v == 0) continue;
      final r = p ~/ 3, col = p % 3;
      final rect = Rect.fromLTWH(
          ox + col * cell + 4, oy + r * cell + 4, cell - 8, cell - 8);
      final hue = (v / 8) * 300;
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)),
          Paint()..color = HSVColor.fromAHSV(1, hue, 0.45, 0.95).toColor());
      // Tile fill is a very light pastel (HSV value 0.95) at every hue, so
      // white digits were near-invisible — the one thing a child must read
      // to solve the puzzle. A dark, high-contrast ink reads clearly against
      // every hue in this pastel range instead.
      final tp = TextPainter(
        text: TextSpan(
            text: '$v',
            style: TextStyle(
                color: const Color(0xFF2B2140),
                fontSize: cell * 0.4,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_SlidePuzzlePainter oldDelegate) => true;
}
