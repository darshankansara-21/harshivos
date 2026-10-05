part of '../arcade_games.dart';

class BlockBlastGame extends StatefulWidget {
  const BlockBlastGame({super.key});
  @override
  State<BlockBlastGame> createState() => _BlockBlastGameState();
}

class _BlockPiece {
  _BlockPiece(this.cells, this.color);
  final List<math.Point<int>> cells;
  final Color color;
}

class _BlockBlastGameState extends State<BlockBlastGame> with _Emit {
  static const String _id = 'block_blast';
  static const int _n = 8;
  final math.Random _rnd = math.Random();
  late List<List<Color?>> _grid;
  final List<_BlockPiece?> _hand = <_BlockPiece?>[null, null, null];
  int _sel = -1;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  static const List<Color> _pieceColors = <Color>[
    Color(0xFFEF476F), Color(0xFFFFD166), Color(0xFF06D6A0),
    Color(0xFF4CC9F0), Color(0xFF9B5DE5), Color(0xFFFF9E00),
  ];

  static final List<List<math.Point<int>>> _shapes = <List<math.Point<int>>>[
    <math.Point<int>>[math.Point<int>(0, 0)],
    <math.Point<int>>[math.Point<int>(0, 0), math.Point<int>(0, 1)],
    <math.Point<int>>[math.Point<int>(0, 0), math.Point<int>(1, 0)],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(0, 1), math.Point<int>(0, 2)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(1, 0), math.Point<int>(2, 0)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(0, 1),
      math.Point<int>(1, 0), math.Point<int>(1, 1)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(1, 0), math.Point<int>(1, 1)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 1), math.Point<int>(1, 0), math.Point<int>(1, 1)
    ],
    <math.Point<int>>[
      math.Point<int>(0, 0), math.Point<int>(0, 1),
      math.Point<int>(0, 2), math.Point<int>(0, 3)
    ],
  ];

  @override
  void initState() {
    super.initState();
    _grid = List<List<Color?>>.generate(_n, (_) => List<Color?>.filled(_n, null));
    _refill();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  _BlockPiece _randomPiece() => _BlockPiece(
      _shapes[_rnd.nextInt(_shapes.length)],
      _pieceColors[_rnd.nextInt(_pieceColors.length)]);

  void _refill() {
    for (var i = 0; i < 3; i++) {
      _hand[i] = _randomPiece();
    }
    _sel = -1;
  }

  bool _fits(_BlockPiece p, int r, int c) {
    for (final o in p.cells) {
      final rr = r + o.x, cc = c + o.y;
      if (rr < 0 || rr >= _n || cc < 0 || cc >= _n) return false;
      if (_grid[rr][cc] != null) return false;
    }
    return true;
  }

  bool _fitsAnywhere(_BlockPiece p) {
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (_fits(p, r, c)) return true;
      }
    }
    return false;
  }

  void _place(int r, int c) {
    if (_status != GameStatus.playing || _sel < 0) return;
    final p = _hand[_sel];
    if (p == null || !_fits(p, r, c)) return;
    for (final o in p.cells) {
      _grid[r + o.x][c + o.y] = p.color;
    }
    _score += p.cells.length;
    _hand[_sel] = null;
    _sel = -1;
    TonePlayer.instance.playCue(SoundCue.stack);
    _clearLines();
    emit(ExperienceEvent.bubblePopped);
    if (_hand.every((h) => h == null)) _refill();
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted && b != _best) _best = b;
    });
    final playable =
        _hand.whereType<_BlockPiece>().any((pc) => _fitsAnywhere(pc));
    if (!playable) {
      _gameOver();
    }
    setState(() {});
  }

  void _clearLines() {
    final fullRows = <int>[];
    final fullCols = <int>[];
    for (var r = 0; r < _n; r++) {
      if (List<Color?>.generate(_n, (c) => _grid[r][c]).every((v) => v != null)) {
        fullRows.add(r);
      }
    }
    for (var c = 0; c < _n; c++) {
      if (List<Color?>.generate(_n, (r) => _grid[r][c]).every((v) => v != null)) {
        fullCols.add(c);
      }
    }
    if (fullRows.isEmpty && fullCols.isEmpty) return;
    for (final r in fullRows) {
      for (var c = 0; c < _n; c++) {
        _grid[r][c] = null;
      }
    }
    for (final c in fullCols) {
      for (var r = 0; r < _n; r++) {
        _grid[r][c] = null;
      }
    }
    final cleared = fullRows.length + fullCols.length;
    _score += cleared * 10;
    _banner = 'Clear +${cleared * 10}!';
    TonePlayer.instance.playCue(SoundCue.success);
  }

  void _gameOver() {
    final prev = GameScores.instance.best(_id);
    _status = GameStatus.over;
    TonePlayer.instance.playCue(SoundCue.gameOver);
    emit(_score > prev
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _reset() {
    setState(() {
      _grid =
          List<List<Color?>>.generate(_n, (_) => List<Color?>.filled(_n, null));
      _score = 0;
      _banner = null;
      _status = GameStatus.playing;
      _refill();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🟦 Block Blast',
      // The actual mechanic is tap-to-select then tap-to-place (there is no
      // Draggable gesture anywhere in this file) — the old "Drag the blocks"
      // wording promised a gesture the game never implements, a genuine
      // first-interaction claim-vs-reality mismatch for a child's very first
      // try.
      introHow: 'Tap a block below to pick it, then tap the grid to place it!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🟦',
      overText: 'No moves left!',
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF141A2E), Color(0xFF0B1020)],
          ),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 112),
            Padding(
              padding: const EdgeInsets.all(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.count(
                  crossAxisCount: _n,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var r = 0; r < _n; r++)
                      for (var c = 0; c < _n; c++)
                        GestureDetector(
                          onTapDown: (_) => _place(r, c),
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(
                                'bb-$r-$c-${_grid[r][c]?.hashCode ?? 0}'),
                            tween: Tween<double>(
                                begin: _grid[r][c] != null ? 1.25 : 1.0,
                                end: 1.0),
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            builder: (ctx, s, child) =>
                                Transform.scale(scale: s, child: child),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _grid[r][c] ??
                                    Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[for (var i = 0; i < 3; i++) _handSlot(i)],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _handSlot(int i) {
    final p = _hand[i];
    return GestureDetector(
      onTap: () => setState(() => _sel = p == null ? -1 : i),
      child: Container(
        width: 90,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_sel == i ? 0.18 : 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _sel == i ? Colors.white : Colors.white24,
              width: _sel == i ? 2 : 1),
        ),
        child:
            p == null ? const SizedBox.shrink() : CustomPaint(painter: _PiecePainter(p)),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.piece);
  final _BlockPiece piece;

  @override
  void paint(Canvas canvas, Size size) {
    var maxR = 0, maxC = 0;
    for (final o in piece.cells) {
      maxR = math.max(maxR, o.x);
      maxC = math.max(maxC, o.y);
    }
    final cell =
        math.min(size.width / (maxC + 1), size.height / (maxR + 1)) * 0.7;
    final ox = (size.width - cell * (maxC + 1)) / 2;
    final oy = (size.height - cell * (maxR + 1)) / 2;
    for (final o in piece.cells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                ox + o.y * cell + 1, oy + o.x * cell + 1, cell - 2, cell - 2),
            const Radius.circular(3)),
        Paint()..color = piece.color,
      );
    }
  }

  @override
  bool shouldRepaint(_PiecePainter oldDelegate) => true;
}

// ===========================================================================
// Bubble Shooter — aim and tap to launch a bubble up the board. Land three or
// more of the same colour touching and they pop. Clear the board; if a bubble
// settles on the bottom row the round ends.
// ===========================================================================
