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

  // Position -> tile value; 0 is the empty space. Solved = [1..8, 0].
  List<int> _tiles = <int>[1, 2, 3, 4, 5, 6, 7, 8, 0];
  int _score = 0;
  int _moves = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  bool get _solved {
    for (var i = 0; i < 8; i++) {
      if (_tiles[i] != i + 1) return false;
    }
    return true;
  }

  void _shuffle() {
    _tiles = <int>[1, 2, 3, 4, 5, 6, 7, 8, 0];
    _moves = 0;
    var blank = 8;
    for (var i = 0; i < 80; i++) {
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
    TonePlayer.instance.playCue(SoundCue.wood);
    if (_solved) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _banner = 'Solved! Next board';
        _shuffle();
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _banner = null;
      _shuffle();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
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
              : 'Slide the numbers into order'),
      winEmoji: '🔀',
      winText: 'Puzzle master!',
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
