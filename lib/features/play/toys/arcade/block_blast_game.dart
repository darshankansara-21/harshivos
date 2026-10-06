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

class _BlockBlastGameState extends State<BlockBlastGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
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
  // Cells of the last attempted-but-rejected placement, briefly flashed red
  // so tapping a cell a selected piece can't fit into (off the edge or
  // already filled) isn't total silence — the same "no-op tap gives zero
  // feedback" bug class fixed in slide_puzzle/color_mixer, applied here.
  List<math.Point<int>> _invalidCells = const <math.Point<int>>[];
  int _invalidToken = 0;
  // Every placement scored the exact same flat `cleared * 10`, so chaining
  // line clears back-to-back (the genre-defining "combo" reward every real
  // block-puzzle game — Tetris, Block Blast, etc. — gives for consecutive
  // clears) was completely absent; a child clearing lines on consecutive
  // placements earned nothing extra for the skillful streak over someone
  // clearing once every ten placements. Tracks how many PLACEMENTS in a row
  // have each cleared at least one line; resets the moment a placement
  // doesn't clear anything, mirroring stack_game's `_perfectStreak` pattern.
  int _comboStreak = 0;
  // Mirrors stack_game/whack_game/space_dodge_game/sky_hop_game's live "beat
  // your own all-time best" celebration. Block Blast has no win cap — score
  // climbs purely with placements and line-clear combos until the board
  // fills — so crossing a prior personal best mid-run is a real,
  // judgment-free moment worth its own banner, not just a stat on the
  // eventual game-over screen.
  bool _beatBest = false;
  // Line-clear is this spatial puzzle's one big payoff moment, yet it only
  // ever flashed a text banner + sound — every "big moment" elsewhere in the
  // catalog (mini_golf's cup sink, soccer_kick's goal, stack's perfect drop)
  // also bursts a few shards of colour. Reuses the shared `_Shard` class and
  // the identical onTick-decay convention via `ToyTicker`.
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;

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

  @override
  void onTick(double dt) {
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
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
    if (p == null) return;
    if (!_fits(p, r, c)) {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      final token = ++_invalidToken;
      setState(() {
        _invalidCells =
            p.cells.map((o) => math.Point<int>(r + o.x, c + o.y)).toList();
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && token == _invalidToken) {
          setState(() => _invalidCells = const <math.Point<int>>[]);
        }
      });
      return;
    }
    for (final o in p.cells) {
      _grid[r + o.x][c + o.y] = p.color;
    }
    _score += p.cells.length;
    _hand[_sel] = null;
    _sel = -1;
    TonePlayer.instance.playCue(SoundCue.stack);
    _clearLines();
    _checkBeatBest();
    emit(ExperienceEvent.bubblePopped);
    if (_hand.every((h) => h == null)) _refill();
    GameScores.instance.submit(_id, _score).then((b) {
      // Resolves after this frame's setState has already run, so updating
      // `_best` without triggering a rebuild left a new best silently stale
      // on screen until some unrelated later interaction happened to repaint.
      if (mounted && b != _best) setState(() => _best = b);
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
    if (fullRows.isEmpty && fullCols.isEmpty) {
      _comboStreak = 0;
      return;
    }
    // Capture each cleared line's own colour + normalised midpoint before
    // the cells are wiped below, so the burst matches what was actually on
    // the board instead of a single fixed colour.
    for (final r in fullRows) {
      final color = _grid[r][_n ~/ 2] ?? _grid[r].firstWhere((v) => v != null)!;
      _spawnClearBurst((_n ~/ 2 + 0.5) / _n, (r + 0.5) / _n, color);
    }
    for (final c in fullCols) {
      final color = _grid[_n ~/ 2][c] ?? _grid.map((row) => row[c]).firstWhere((v) => v != null)!;
      _spawnClearBurst((c + 0.5) / _n, (_n ~/ 2 + 0.5) / _n, color);
    }
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
    _comboStreak++;
    final mult = _comboStreak.clamp(1, 5);
    final gain = cleared * 10 * mult;
    _score += gain;
    _banner = mult > 1 ? 'Clear +$gain! Combo x$mult 🔥' : 'Clear +$gain!';
    TonePlayer.instance.playCue(mult > 1 ? SoundCue.milestone : SoundCue.success);
  }

  // Score also climbs from plain placements (`_score += p.cells.length` in
  // `_place`), not only from line clears — this used to live inside
  // `_clearLines()` and returned early before ever reaching it whenever a
  // placement didn't complete a full row/column, so a child who crossed
  // their own all-time best purely through placement points (never once
  // clearing a line before the board filled up) silently never got the
  // celebration every other open-ended-score game in the catalog gives.
  // Called once per placement after all of this turn's scoring is final, so
  // it can never disagree with (or double-fire alongside) a clear's own
  // combo banner — this check runs last and simply overrides it when both
  // happen on the same tap.
  void _checkBeatBest() {
    if (_status == GameStatus.playing &&
        !_beatBest &&
        _best > 0 &&
        _score > _best) {
      _beatBest = true;
      // Takes priority over the combo banner just set above — a new
      // all-time record is the bigger moment of the two.
      _banner = 'New personal best! 🏆';
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
  }

  void _spawnClearBurst(double x, double y, Color color) {
    final bitCount = _reduceMotion ? 4 : 12;
    for (var i = 0; i < bitCount; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.35;
      _bits.add(_Shard(x, y, math.cos(a) * sp, math.sin(a) * sp, color));
    }
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
      _invalidCells = const <math.Point<int>>[];
      _invalidToken++;
      _comboStreak = 0;
      _beatBest = false;
      _bits.clear();
      _status = GameStatus.playing;
      _refill();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
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
                child: Stack(
                  children: <Widget>[
                    GridView.count(
                  crossAxisCount: _n,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var r = 0; r < _n; r++)
                      for (var c = 0; c < _n; c++)
                        Semantics(
                          button: true,
                          // Only the cell's own current state is spoken
                          // (empty vs filled) plus whether a piece is ready to
                          // place there — never whether this is a *valid*
                          // fit for the selected piece, so the real spatial
                          // planning challenge (does this shape fit here?)
                          // stays intact for screen-reader users exactly as a
                          // sighted child must work it out visually.
                          label: 'Row ${r + 1}, column ${c + 1}, '
                              '${_grid[r][c] != null ? 'filled' : 'empty'}.'
                              '${_sel >= 0 ? ' Tap to place the selected block here.' : ''}',
                          onTap: () => _place(r, c),
                          excludeSemantics: true,
                          child: GestureDetector(
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
                                color: _invalidCells.contains(
                                        math.Point<int>(r, c))
                                    ? Colors.redAccent.withOpacity(0.55)
                                    : _grid[r][c] ??
                                        Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          ),
                        ),
                  ],
                    ),
                    // Celebratory shard burst on a line clear, matching the
                    // "big moment" `_Shard` convention used catalog-wide
                    // (mini_golf's cup sink, stack's perfect drop, etc).
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _BlockBurstPainter(_bits),
                        size: Size.infinite,
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
    // Only the piece's own size (cell count) is spoken, never its shape or
    // where it fits — the real "which shape goes where" planning challenge
    // stays exactly as hard for screen-reader users as it is for sighted
    // children reading the shape by eye.
    final label = p == null
        ? 'Empty block slot.'
        : 'Block piece, ${p.cells.length} cell${p.cells.length == 1 ? '' : 's'}.'
            '${_sel == i ? ' Selected.' : ''}';
    return Semantics(
      button: true,
      label: label,
      onTap: () => setState(() => _sel = p == null ? -1 : i),
      excludeSemantics: true,
      child: GestureDetector(
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
          child: p == null
              ? const SizedBox.shrink()
              : CustomPaint(painter: _PiecePainter(p)),
        ),
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

class _BlockBurstPainter extends CustomPainter {
  _BlockBurstPainter(this.bits);
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_BlockBurstPainter oldDelegate) => true;
}

// ===========================================================================
// Bubble Shooter — aim and tap to launch a bubble up the board. Land three or
// more of the same colour touching and they pop. Clear the board; if a bubble
// settles on the bottom row the round ends.
// ===========================================================================
