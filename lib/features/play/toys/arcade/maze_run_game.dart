part of '../arcade_games.dart';

/// Maze Run — swipe to slide the dot through the maze. Grab the key, then reach
/// the glowing exit. Each maze you solve is bigger. Solve five to win.
class MazeRunGame extends StatefulWidget {
  const MazeRunGame({super.key});
  @override
  State<MazeRunGame> createState() => _MazeRunGameState();
}

class _MazeRunGameState extends State<MazeRunGame> with _Emit {
  static const String _id = 'maze_run';
  static const int _target = 5;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Maze master!',
    'Puzzle champion!',
    'Clever navigator!',
    'Exit found!',
  ];
  String _winPraise = _winPraisePool.first;
  // Pool of per-maze completion phrases so solving a maze doesn't always
  // flash the identical "Solved! Bigger maze…" line.
  static const List<String> _nextMazePool = <String>[
    'Solved! Bigger maze…',
    'Found it! Next maze',
    'Nice navigating! New maze',
    'Exit found! Harder next',
  ];
  int _cols = 5, _rows = 6;
  List<int> _cell = <int>[]; // bitmask: 1=up,2=right,4=down,8=left
  int _px = 0, _py = 0;
  int _exit = 0;
  int _key = 0;
  bool _hasKey = false;
  int _level = 1;
  int _solved = 0;
  int _best = 0;
  // Every other scoring arcade game (bubble_wrap/hoop_toss/echo...) already
  // celebrates the moment a run's score passes the child's all-time best
  // with a banner + milestone chime + ExperienceEvent.personalBest — mazes
  // solved this run (`_solved`) only ever submitted the new best silently.
  // Guard it the same way (reset in `_reset()`) so beating one's own
  // longest streak of solved mazes gets the same celebration every sibling
  // game gives.
  bool _beatBest = false;
  String? _banner;
  // The post-solve best/next-maze banner was only ever cleared by
  // `_reset()`, so once a level solved it stayed glued on screen through
  // the whole next maze.
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
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _genMaze() {
    _cols = (4 + _level).clamp(4, 8);
    _rows = (5 + _level).clamp(5, 10);
    final n = _cols * _rows;
    _cell = List<int>.filled(n, 0);
    final visited = List<bool>.filled(n, false);
    final stack = <int>[0];
    visited[0] = true;
    while (stack.isNotEmpty) {
      final c = stack.last;
      final cx = c % _cols, cy = c ~/ _cols;
      final nb = <List<int>>[];
      if (cy > 0 && !visited[c - _cols]) nb.add(<int>[0, c - _cols]);
      if (cx < _cols - 1 && !visited[c + 1]) nb.add(<int>[1, c + 1]);
      if (cy < _rows - 1 && !visited[c + _cols]) nb.add(<int>[2, c + _cols]);
      if (cx > 0 && !visited[c - 1]) nb.add(<int>[3, c - 1]);
      if (nb.isEmpty) {
        stack.removeLast();
        continue;
      }
      final pick = nb[_rnd.nextInt(nb.length)];
      final dir = pick[0], nIdx = pick[1];
      _cell[c] |= (1 << dir);
      _cell[nIdx] |= (1 << ((dir + 2) % 4));
      visited[nIdx] = true;
      stack.add(nIdx);
    }
    _px = 0;
    _py = 0;
    _exit = n - 1;
    do {
      _key = _rnd.nextInt(n);
    } while (_key == 0 || _key == _exit);
    _hasKey = false;
  }

  void _slide(int dx, int dy) {
    if (_status != GameStatus.playing) return;
    final dir = dy < 0 ? 0 : (dx > 0 ? 1 : (dy > 0 ? 2 : 3));
    var moved = false;
    while (true) {
      final c = _py * _cols + _px;
      if ((_cell[c] & (1 << dir)) == 0) break;
      _px += dx;
      _py += dy;
      moved = true;
      final nc = _py * _cols + _px;
      if (nc == _key && !_hasKey) {
        _hasKey = true;
        TonePlayer.instance.playCue(SoundCue.success);
        _banner = 'Key! 🔑 Now find the exit';
      }
      if (nc == _exit && _hasKey) {
        _solve();
        return;
      }
    }
    if (moved) {
      setState(() {});
      TonePlayer.instance.playPop(0.7);
    } else {
      // A swipe straight into a closed wall (dot never moves at all) was
      // previously completely silent — the only feedback for a valid move
      // was a pop sound, so a blocked swipe looked identical to a swipe that
      // was never registered at all. A child can't tell "that wall is
      // closed, try another direction" from "nothing happened, swipe
      // harder". A short, distinct gentle-retry cue (the same one every
      // other game in the catalog uses for a blocked/wrong input) confirms
      // the swipe was heard without being a celebratory or scary sound.
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
    }
  }

  void _solve() {
    _solved++;
    _level++;
    emit(ExperienceEvent.bubblePopped);
    TonePlayer.instance.playCue(SoundCue.success);
    final crossedBest = _solved > _best && !_beatBest && _best > 0;
    GameScores.instance.submit(_id, _solved).then((b) {
      if (mounted) setState(() => _best = b);
    });
    if (_solved >= _target) {
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
      setState(() {
        _banner = 'Maze master!';
        _status = GameStatus.won;
      });
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else if (crossedBest) {
      _beatBest = true;
      // Flashed instead of the routine "Solved! Bigger maze…" line so
      // beating a prior all-time solved count isn't lost under the usual
      // per-maze phrase.
      setState(() {
        _flashBanner('New personal best! 🏆');
        _genMaze();
      });
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    } else {
      setState(() {
        _flashBanner(_nextMazePool[_rnd.nextInt(_nextMazePool.length)]);
        _genMaze();
      });
    }
  }

  void _reset() {
    setState(() {
      _level = 1;
      _solved = 0;
      _beatBest = false;
      _banner = null;
      _bannerTimer?.cancel();
      _genMaze();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    if (_cell.isEmpty) _genMaze();
    return _Shell(
      title: '🧩 Maze Run',
      introHow:
          'Swipe up, down, left or right to slide the dot. Grab the key, then reach the glowing exit!',
      onStart: () => setState(() {
        _genMaze();
        _status = GameStatus.playing;
      }),
      score: _solved,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? (_hasKey ? 'Find the exit!' : 'Grab the key 🔑'),
      winEmoji: '🧩',
      winText: _winPraise,
      accent: const Color(0xFF7BD389),
      onPlayAgain: _reset,
      child: Semantics(
        label: _hasKey
            ? 'Maze. Find the exit. Swipe or slide left, right, up or down.'
            : 'Maze. Grab the key. Swipe or slide left, right, up or down.',
        customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
          const CustomSemanticsAction(label: 'Slide left'): () => _slide(-1, 0),
          const CustomSemanticsAction(label: 'Slide right'): () => _slide(1, 0),
          const CustomSemanticsAction(label: 'Slide up'): () => _slide(0, -1),
          const CustomSemanticsAction(label: 'Slide down'): () => _slide(0, 1),
        },
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanEnd: (d) {
          final v = d.velocity.pixelsPerSecond;
          if (v.distance < 40) return;
          if (v.dx.abs() > v.dy.abs()) {
            _slide(v.dx > 0 ? 1 : -1, 0);
          } else {
            _slide(0, v.dy > 0 ? 1 : -1);
          }
        },
        child: CustomPaint(
          painter: _MazePainter(
            cols: _cols,
            rows: _rows,
            cell: _cell,
            px: _px,
            py: _py,
            exit: _exit,
            key: _key,
            hasKey: _hasKey,
          ),
          size: Size.infinite,
        ),
        ),
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  _MazePainter({
    required this.cols,
    required this.rows,
    required this.cell,
    required this.px,
    required this.py,
    required this.exit,
    required this.key,
    required this.hasKey,
  });
  final int cols, rows, px, py, exit, key;
  final List<int> cell;
  final bool hasKey;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF14241A));
    if (cell.isEmpty) return;
    final pad = w * 0.06;
    final gw = w - pad * 2, gh = h - pad * 2;
    final cw = gw / cols, ch = gh / rows;
    final wall = Paint()
      ..color = const Color(0xFF7BD389)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    Offset cellTL(int cx, int cy) => Offset(pad + cx * cw, pad + cy * ch);
    // Key.
    if (!hasKey) {
      final kc = Offset(pad + (key % cols + 0.5) * cw, pad + (key ~/ cols + 0.5) * ch);
      canvas.drawCircle(kc, math.min(cw, ch) * 0.22,
          Paint()..color = const Color(0xFFFFD166));
    }
    // Exit.
    final ec = Offset(pad + (exit % cols + 0.5) * cw, pad + (exit ~/ cols + 0.5) * ch);
    canvas.drawCircle(ec, math.min(cw, ch) * 0.36,
        Paint()..color = (hasKey ? const Color(0xFF63E6BE) : Colors.white24));
    // Walls (draw edges that are closed).
    for (var cy = 0; cy < rows; cy++) {
      for (var cx = 0; cx < cols; cx++) {
        final m = cell[cy * cols + cx];
        final tl = cellTL(cx, cy);
        final tr = tl + Offset(cw, 0);
        final bl = tl + Offset(0, ch);
        final br = tl + Offset(cw, ch);
        if (m & 1 == 0) canvas.drawLine(tl, tr, wall); // up
        if (m & 2 == 0) canvas.drawLine(tr, br, wall); // right
        if (m & 4 == 0) canvas.drawLine(bl, br, wall); // down
        if (m & 8 == 0) canvas.drawLine(tl, bl, wall); // left
      }
    }
    // Player dot.
    final pc = Offset(pad + (px + 0.5) * cw, pad + (py + 0.5) * ch);
    canvas.drawCircle(pc, math.min(cw, ch) * 0.3,
        Paint()..color = const Color(0xFFFFE066));
    canvas.drawCircle(pc.translate(-cw * 0.08, -ch * 0.08),
        math.min(cw, ch) * 0.1, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MazePainter old) => true;
}

