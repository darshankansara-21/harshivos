part of '../arcade_games.dart';

/// Jigsaw Four — drag the scattered picture pieces into their slots to rebuild
/// the scene. Each piece shows its own fragment, so match the edges. Boards grow
/// from four pieces up to nine; finish three pictures to win.
class JigsawFourGame extends StatefulWidget {
  const JigsawFourGame({super.key});
  @override
  State<JigsawFourGame> createState() => _JigsawFourGameState();
}

class _JigPiece {
  _JigPiece(this.homeCol, this.homeRow, this.x, this.y);
  final int homeCol, homeRow;
  double x, y; // current top-left (normalized)
  bool placed = false;
}

class _JigsawFourGameState extends State<JigsawFourGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'jigsaw_four';
  static const int _target = 3;
  // Board region (normalized) where the assembled picture sits.
  static const double _bx0 = 0.12, _by0 = 0.12, _bw = 0.76, _bh = 0.48;
  static const List<List<int>> _grids = <List<int>>[
    <int>[2, 2], // cols,rows -> 4
    <int>[3, 2], // 6
    <int>[3, 3], // 9
  ];
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Great fitting!" line on win screen.
  static const List<String> _winPraisePool = <String>[
    'Great fitting!',
    'Puzzle master!',
    'Piece perfect!',
    'All pictures complete!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  // Pool of per-level completion phrases so finishing a picture doesn't
  // always flash the identical "Picture done! Next one" line.
  static const List<String> _nextPicturePool = <String>[
    'Picture done! Next one',
    'All pieces placed! Next',
    'Nice fitting! New picture',
    'Puzzle solved! One more',
  ];

  final List<_JigPiece> _pieces = <_JigPiece>[];
  // Every other matching/fitting-completion game in the catalog (memory
  // flip's pair match, maze marble's goal sink, block blast's line clear)
  // celebrates with a small particle burst — jigsaw only ever played a
  // sound on finishing a picture, with zero visual payoff. Mirror the
  // shared `_Shard` convention (defined in brick_break_game.dart, usable
  // here since every arcade/*.dart file shares one `part of` library).
  final List<_Shard> _shards = <_Shard>[];
  bool _reduceMotion = false;
  int _level = 0;
  int _sceneSeed = 0;
  int _score = 0;
  int _best = 0;
  // `_level` only ever started a fresh playthrough at index 0 (the easiest
  // 2x2 grid), so a veteran with a high all-time `_best` rebuilt the same
  // trivial first picture every single run regardless of career skill — the
  // same "flat-forever difficulty never fed by career `_best`" bug class
  // already closed for the quiz-game family. Nudge the opening level up a
  // little for a seasoned player, capped so it never skips straight past
  // the hardest grid this game has.
  int get _careerSkillRamp => (_best ~/ 2).clamp(0, _grids.length - 1);
  // Jigsaw has no fail state at all — a round always eventually finishes
  // all 3 pictures, so the regular higher-is-better `best` (picture count)
  // freezes at `_target` forever after the very first completed round,
  // exactly the "stat that can never move again" bug class fixed for
  // mini_golf's stroke count. Time-to-complete is the genuine open-ended
  // skill measure here (a faster rebuild is a better result, and there's
  // always room to shave more time off), so track it as a separate
  // lower-is-better personal best via `GameScores.submitLow`.
  static const String _timeId = '${_id}_time_ms';
  double _elapsedMs = 0;
  int _bestTimeMs = 0;
  int _finishMs = 0;
  int _cols = 2, _rows = 2;
  int? _dragging;
  // Screen-reader-only selection: a blind child cannot perform the pixel
  // precision pan gesture the sighted drag relies on, so taps on a piece
  // select it, then a tap on a slot moves the selected piece there and runs
  // the exact same `_drop` home-position check the sighted drag uses.
  int? _selected;
  String? _banner;
  // The "Next picture" banner was only ever cleared by `_reset()` — once a
  // level advanced, its text glued itself on screen for that whole level.
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

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

  double get _cellW => _bw / _cols;
  double get _cellH => _bh / _rows;

  void _burst(double cx, double cy, [Color? color]) {
    final n = _reduceMotion ? 4 : 14;
    for (var k = 0; k < n; k++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.3;
      _shards.add(_Shard(cx, cy, math.cos(a) * sp, math.sin(a) * sp,
          color ?? _JigsawPainter._suns[_rnd.nextInt(_JigsawPainter._suns.length)]));
    }
  }

  @override
  void onTick(double dt) {
    if (_status == GameStatus.playing) _elapsedMs += dt * 1000;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = _shards.length - 1; i >= 0; i--) {
      final s = _shards[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) _shards.removeAt(i);
    }
  }

  void _buildBoard() {
    final gridIndex = (_level + _careerSkillRamp).clamp(0, _grids.length - 1);
    _cols = _grids[gridIndex][0];
    _rows = _grids[gridIndex][1];
    _sceneSeed = _rnd.nextInt(1 << 30);
    _pieces.clear();
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        // Scatter into the tray below the board.
        final x = 0.08 + _rnd.nextDouble() * (0.84 - _cellW);
        final y = 0.66 + _rnd.nextDouble() * (0.3 - _cellH);
        _pieces.add(_JigPiece(c, r, x, y));
      }
    }
    _pieces.shuffle(_rnd);
  }

  int? _pieceAt(double nx, double ny) {
    for (var i = _pieces.length - 1; i >= 0; i--) {
      final p = _pieces[i];
      if (p.placed) continue;
      if (nx >= p.x && nx <= p.x + _cellW && ny >= p.y && ny <= p.y + _cellH) {
        return i;
      }
    }
    return null;
  }

  void _drop(_JigPiece p) {
    final homeX = _bx0 + p.homeCol * _cellW;
    final homeY = _by0 + p.homeRow * _cellH;
    if ((p.x - homeX).abs() < _cellW * 0.4 && (p.y - homeY).abs() < _cellH * 0.4) {
      p.x = homeX;
      p.y = homeY;
      p.placed = true;
      TonePlayer.instance.playCue(SoundCue.wood);
      if (_pieces.every((e) => e.placed)) {
        _score++;
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.bubblePopped);
        _burst(_bx0 + _bw / 2, _by0 + _bh / 2);
        GameScores.instance.submit(_id, _score).then((v) {
          if (mounted) setState(() => _best = v);
        });
        if (_score >= _target) {
          _status = GameStatus.won;
          _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.gameCompleted);
          _finishMs = _elapsedMs.round();
          final beatTime = _bestTimeMs > 0 && _finishMs < _bestTimeMs;
          GameScores.instance.submitLow(_timeId, _finishMs).then((v) {
            if (mounted) setState(() => _bestTimeMs = v);
          });
          // A faster all-time rebuild is its own genuine achievement,
          // distinct from — and able to keep recurring after — the
          // picture-count celebration above, so it gets its own banner and
          // milestone chime rather than being silently absorbed.
          if (beatTime) {
            _banner = 'Fastest rebuild yet! 🏆';
            TonePlayer.instance.playCue(SoundCue.milestone);
            emit(ExperienceEvent.personalBest);
            // Layer a gold milestone burst onto the picture-complete burst
            // above, mirroring slide_puzzle's distinctly-colored
            // personal-best celebration so a genuine new record reads as
            // its own moment, not just the routine completion fanfare.
            _burst(_bx0 + _bw / 2, _by0 + _bh / 2, const Color(0xFFFFD166));
          }
        } else {
          _level++;
          _banner = _nextPicturePool[_rnd.nextInt(_nextPicturePool.length)];
          _bannerT = 1.3;
          _buildBoard();
        }
      }
    }
  }

  void _reset() {
    setState(() {
      _level = 0;
      _score = 0;
      _banner = null;
      _bannerT = 0;
      _elapsedMs = 0;
      _finishMs = 0;
      _shards.clear();
      _buildBoard();
      _status = GameStatus.playing;
    });
  }

  /// Screen-reader path: move the selected piece to slot (col,row) and run
  /// the same home-position check a sighted drag-and-drop uses.
  void _placeSelectedAt(int col, int row) {
    final i = _selected;
    if (i == null) return;
    setState(() {
      _selected = null;
      final p = _pieces[i];
      if (p.placed) return;
      p.x = _bx0 + col * _cellW;
      p.y = _by0 + row * _cellH;
      _drop(p);
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final left = _pieces.where((p) => !p.placed).length;
    return _Shell(
      title: '🧩 Jigsaw Four',
      introHow:
          'Drag each piece into its matching slot to rebuild the picture. '
          'Finish three pictures to win!',
      onStart: () => setState(() {
        _elapsedMs = 0;
        _buildBoard();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Picture ${_score + 1}  ·  $left pieces to place'
              : 'Rebuild the pictures'),
      winEmoji: '🧩',
      // Mirrors mini_golf's roundWinText convention: show this round's own
      // time plus (once one exists) the all-time best, and call out a
      // genuine new record distinctly from a routine finish.
      winText: _finishMs <= 0
          ? _winPraise
          : (_bestTimeMs > 0 && _finishMs < _bestTimeMs
              ? '$_winPraise New fastest: ${(_finishMs / 1000).toStringAsFixed(1)}s! 🏆'
              : '$_winPraise ${(_finishMs / 1000).toStringAsFixed(1)}s'
                  '${_bestTimeMs > 0 ? ' (best ${(_bestTimeMs / 1000).toStringAsFixed(1)}s)' : ''}'),
      accent: const Color(0xFF48CAE4),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return Stack(children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              final nx = d.localPosition.dx / w, ny = d.localPosition.dy / h;
              _dragging = _pieceAt(nx, ny);
            },
            onPanUpdate: (d) {
              final i = _dragging;
              if (i == null) return;
              setState(() {
                _pieces[i].x =
                    (d.localPosition.dx / w - _cellW / 2).clamp(0.0, 1 - _cellW);
                _pieces[i].y =
                    (d.localPosition.dy / h - _cellH / 2).clamp(0.0, 1 - _cellH);
              });
            },
            onPanEnd: (_) {
              final i = _dragging;
              _dragging = null;
              if (i != null) setState(() => _drop(_pieces[i]));
            },
            // A cancelled pan (gesture arena interruption) never calls
            // onPanEnd, so without this a piece mid-drag would stay stuck in
            // its last dragged position forever — never snapped home, never
            // dropped, and drawn on top of every other piece indefinitely —
            // until a later drag happened to grab it again.
            onPanCancel: () {
              final i = _dragging;
              _dragging = null;
              if (i != null) setState(() => _drop(_pieces[i]));
            },
            child: CustomPaint(
              painter: _JigsawPainter(
                pieces: _pieces,
                cols: _cols,
                rows: _rows,
                cellW: _cellW,
                cellH: _cellH,
                picture: _sceneSeed,
                dragging: _dragging,
              ),
              size: Size.infinite,
            ),
          ),
          _a11yOverlay(w, h),
          IgnorePointer(
            child: CustomPaint(
              painter: _JigsawShardPainter(_shards),
              size: Size.infinite,
            ),
          ),
          ]);
        },
      ),
    );
  }

  /// Screen-reader overlay: one button per loose piece (select it) and one
  /// button per board slot (place the selected piece there). Labels never
  /// reveal a piece's true home, only its current state — exactly the same
  /// information a sighted child has before they've tried fitting it.
  Widget _a11yOverlay(double w, double h) {
    final kids = <Widget>[];
    for (var i = 0; i < _pieces.length; i++) {
      final p = _pieces[i];
      if (p.placed) continue;
      kids.add(Positioned(
        left: p.x * w,
        top: p.y * h,
        width: _cellW * w,
        height: _cellH * h,
        child: Semantics(
          button: true,
          label: 'Puzzle piece ${i + 1}, not yet placed.'
              '${_selected == i ? ' Selected.' : ''}',
          onTap: () => setState(() => _selected = (_selected == i) ? null : i),
          excludeSemantics: true,
          child: const SizedBox.expand(),
        ),
      ));
    }
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final filled = _pieces.any(
            (p) => p.placed && p.homeCol == c && p.homeRow == r);
        kids.add(Positioned(
          left: (_bx0 + c * _cellW) * w,
          top: (_by0 + r * _cellH) * h,
          width: _cellW * w,
          height: _cellH * h,
          child: Semantics(
            button: true,
            label: filled
                ? 'Slot row ${r + 1} column ${c + 1}, filled.'
                : 'Slot row ${r + 1} column ${c + 1}, empty.',
            onTap: () => _placeSelectedAt(c, r),
            excludeSemantics: true,
            child: const SizedBox.expand(),
          ),
        ));
      }
    }
    return Stack(children: kids);
  }
}

class _JigsawPainter extends CustomPainter {
  _JigsawPainter({
    required this.pieces,
    required this.cols,
    required this.rows,
    required this.cellW,
    required this.cellH,
    required this.picture,
    required this.dragging,
  });
  final List<_JigPiece> pieces;
  final int cols, rows;
  final double cellW, cellH;
  final int picture;
  final int? dragging;

  static const List<Color> _skyTops = <Color>[
    Color(0xFF8ECAE6), Color(0xFFFFC8DD), Color(0xFF3A0CA3), Color(0xFFB8E0D2), Color(0xFFFFE5B4),
  ];
  static const List<Color> _skyBottoms = <Color>[
    Color(0xFF219EBC), Color(0xFFBDE0FE), Color(0xFF7209B7), Color(0xFF52B788), Color(0xFFFFB4A2),
  ];
  static const List<Color> _suns = <Color>[
    Color(0xFFFFB703), Color(0xFFFFD166), Color(0xFFF72585), Color(0xFFFFEE32), Color(0xFFFF9F1C),
  ];
  static const List<Color> _hills = <Color>[
    Color(0xFF52B788), Color(0xFF80ED99), Color(0xFF4CC9F0), Color(0xFF6A994E), Color(0xFF99D98C),
  ];
  static const List<Color> _walls = <Color>[
    Color(0xFFFFF1E6), Color(0xFFE9EDC9), Color(0xFFD6E2E9), Color(0xFFFAEDCD), Color(0xFFE8E8E4),
  ];
  static const List<Color> _roofs = <Color>[
    Color(0xFFBC4749), Color(0xFF6D597A), Color(0xFF355070), Color(0xFFB56576), Color(0xFF8B5E3C),
  ];

  void _scene(Canvas canvas, Rect r, int seed) {
    final rnd = math.Random(seed);
    final skyTop = _skyTops[rnd.nextInt(_skyTops.length)];
    final skyBottom = _skyBottoms[rnd.nextInt(_skyBottoms.length)];
    final sun = _suns[rnd.nextInt(_suns.length)];
    final hillColor = _hills[rnd.nextInt(_hills.length)];
    final wall = _walls[rnd.nextInt(_walls.length)];
    final roofColor = _roofs[rnd.nextInt(_roofs.length)];
    final sunX = 0.18 + rnd.nextDouble() * 0.2;
    final sunY = 0.16 + rnd.nextDouble() * 0.16;
    final sunR = 0.08 + rnd.nextDouble() * 0.06;
    final hillPeakY = 0.46 + rnd.nextDouble() * 0.14;
    final hillDipY = 0.6 + rnd.nextDouble() * 0.14;
    final houseX = 0.58 + rnd.nextDouble() * 0.14;
    final houseScale = 0.85 + rnd.nextDouble() * 0.3;
    canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[skyTop, skyBottom],
          ).createShader(r));
    // Sun.
    canvas.drawCircle(Offset(r.left + r.width * sunX, r.top + r.height * sunY),
        r.width * sunR, Paint()..color = sun);
    // Rolling hills.
    final hill = Paint()..color = hillColor;
    final p1 = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + r.height * 0.68)
      ..quadraticBezierTo(r.left + r.width * 0.3, r.top + r.height * hillPeakY,
          r.left + r.width * 0.6, r.top + r.height * 0.66)
      ..quadraticBezierTo(r.left + r.width * 0.82, r.top + r.height * hillDipY,
          r.right, r.top + r.height * 0.6)
      ..lineTo(r.right, r.bottom)
      ..close();
    canvas.drawPath(p1, hill);
    // A little house.
    final hw = r.width * 0.18 * houseScale, hh = r.height * 0.2 * houseScale;
    final hx = r.left + r.width * houseX, hy = r.top + r.height * 0.6;
    canvas.drawRect(Rect.fromLTWH(hx, hy, hw, hh), Paint()..color = wall);
    final roof = Path()
      ..moveTo(hx - hw * 0.1, hy)
      ..lineTo(hx + hw * 0.5, hy - hh * 0.5)
      ..lineTo(hx + hw * 1.1, hy)
      ..close();
    canvas.drawPath(roof, Paint()..color = roofColor);
    canvas.drawRect(
        Rect.fromLTWH(hx + hw * 0.35, hy + hh * 0.4, hw * 0.3, hh * 0.6),
        Paint()..color = const Color(0xFF6D4C41));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1B2430), Color(0xFF10151C)],
          ).createShader(Offset.zero & size));

    final boardPx = Rect.fromLTWH(_JigsawFourGameState._bx0 * w,
        _JigsawFourGameState._by0 * h, _JigsawFourGameState._bw * w,
        _JigsawFourGameState._bh * h);

    // Empty slot outlines.
    final slot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white24;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(boardPx.left + c * cellW * w,
                    boardPx.top + r * cellH * h, cellW * w, cellH * h),
                const Radius.circular(6)),
            slot);
      }
    }

    // Pieces (placed first, then loose, dragged last on top).
    final order = List<int>.generate(pieces.length, (i) => i);
    order.sort((a, b) {
      if (a == dragging) return 1;
      if (b == dragging) return -1;
      final pa = pieces[a].placed ? 0 : 1;
      final pb = pieces[b].placed ? 0 : 1;
      return pa - pb;
    });
    final boardSize = Size(_JigsawFourGameState._bw * w, _JigsawFourGameState._bh * h);
    for (final i in order) {
      final p = pieces[i];
      final rect = Rect.fromLTWH(p.x * w, p.y * h, cellW * w, cellH * h);
      canvas.save();
      canvas.clipRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)));
      final origin = Offset(
          rect.left - p.homeCol * cellW * w, rect.top - p.homeRow * cellH * h);
      _scene(canvas, origin & boardSize, picture);
      canvas.restore();
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.placed ? 1 : 2.5
            ..color = p.placed ? Colors.white24 : Colors.white);
    }
  }

  @override
  bool shouldRepaint(_JigsawPainter oldDelegate) => true;
}

/// Picture-complete celebration burst, mirroring the `_MemoryShardPainter`
/// convention shared across every other fitting/matching game.
class _JigsawShardPainter extends CustomPainter {
  _JigsawShardPainter(this.shards);
  final List<_Shard> shards;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final s in shards) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_JigsawShardPainter oldDelegate) => true;
}
