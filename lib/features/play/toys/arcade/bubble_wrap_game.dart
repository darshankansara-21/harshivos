part of '../arcade_games.dart';

/// Bubble Wrap — a no-fail sensory popper. Tap or drag across the sheet to pop
/// every bubble with a satisfying burst; clear a sheet and a fresh one rolls in.
class BubbleWrapGame extends StatefulWidget {
  const BubbleWrapGame({super.key});
  @override
  State<BubbleWrapGame> createState() => _BubbleWrapGameState();
}

class _BubbleWrapGameState extends State<BubbleWrapGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'bubble_wrap';
  static const int _cols = 7;
  static const int _rows = 10;
  static const int _sheet = _cols * _rows;
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  late List<bool> _popped;
  int _sheetPopped = 0;
  int _total = 0;
  int _best = 0;
  double _refillT = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Mirrors stack_game/block_blast_game/brick_break_game's live "beat your
  // own all-time best" celebration. Bubble Wrap never truly "wins" — sheets
  // refill forever and `_total` climbs without a cap — so crossing a prior
  // personal best mid-run deserves the same judgment-free moment.
  bool _beatBest = false;

  @override
  void initState() {
    super.initState();
    _popped = List<bool>.filled(_sheet, false);
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.4 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_refillT > 0) {
      _refillT -= dt;
      if (_refillT <= 0) {
        _popped = List<bool>.filled(_sheet, false);
        _sheetPopped = 0;
      }
    }
  }

  void _popAt(Offset p, double w, double h) {
    if (_status != GameStatus.playing || _refillT > 0) return;
    final col = (p.dx / w * _cols).floor();
    final row = (p.dy / h * _rows).floor();
    if (col < 0 || col >= _cols || row < 0 || row >= _rows) return;
    final idx = row * _cols + col;
    if (_popped[idx]) return;
    setState(() {
      _popped[idx] = true;
      _sheetPopped++;
      _total++;
    });
    final cx = (col + 0.5) / _cols, cy = (row + 0.5) / _rows;
    final bitCount = _reduceMotion ? 3 : 6;
    for (var i = 0; i < bitCount; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.1 + _rnd.nextDouble() * 0.25;
      _bits.add(_Shard(cx, cy, math.cos(a) * sp, math.sin(a) * sp,
          const Color(0xFFBFE3FF)));
    }
    TonePlayer.instance.playCue(SoundCue.bubble);
    final crossedBest = _total > _best && !_beatBest && _best > 0;
    if (_total > _best) {
      _best = _total;
      GameScores.instance.submit(_id, _total);
    }
    if (_sheetPopped >= _sheet) {
      emit(ExperienceEvent.bubblePopped);
      TonePlayer.instance.playCue(SoundCue.success);
      _flash('Sheet clear! 🎉 Fresh one coming…');
      _refillT = 1.0;
    }
    if (crossedBest) {
      _beatBest = true;
      // Flashed last so it wins over the sheet-clear banner above when both
      // land on the same pop — a new all-time record is the bigger moment.
      _flash('New personal best! 🏆');
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
  }

  void _reset() {
    setState(() {
      _popped = List<bool>.filled(_sheet, false);
      _sheetPopped = 0;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _refillT = 0;
      _beatBest = false;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '🫧 Bubble Wrap',
      introHow:
          'Tap or drag across the sheet to pop every bubble. Clear it and a fresh sheet rolls in — no rush, no fail.',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _sheetPopped,
      best: _best,
      target: _sheet,
      status: _status,
      banner: _banner ?? 'Popped $_sheetPopped/$_sheet · total $_total',
      // Bubble Wrap is deliberately no-fail: sheets refill forever and
      // `_status` never becomes `GameStatus.won` (see the intro's "no rush,
      // no fail"), so the shell's win screen can never actually show —
      // `winEmoji`/`winText` here were dead code that would never render.
      // The sheet-clear moment is already celebrated honestly via the
      // `_flash('Sheet clear! 🎉 …')` banner above instead.
      accent: const Color(0xFF5FB2E6),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final cw = w / _cols, ch = h / _rows;
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _popAt(d.localPosition, w, h),
                onPanStart: (d) => _popAt(d.localPosition, w, h),
                onPanUpdate: (d) => _popAt(d.localPosition, w, h),
                child: CustomPaint(
                  painter: _BubbleWrapPainter(
                    popped: _popped,
                    cols: _cols,
                    rows: _rows,
                    bits: _bits,
                  ),
                  size: Size.infinite,
                ),
              ),
              // Every bubble is a plain canvas circle with no widget-tree
              // counterpart, so a screen-reader user had no way to discover
              // or pop any cell. Fixed-position overlays (the sheet never
              // scrolls or drifts, matching beat_builder's static grid, not
              // balloon_math's live-tracked drifters) announce each
              // bubble's row/column and popped state and reuse the same
              // row/col hit-test math already baked into `_popAt`.
              for (var row = 0; row < _rows; row++)
                for (var col = 0; col < _cols; col++)
                  Positioned(
                    left: col * cw,
                    top: row * ch,
                    width: cw,
                    height: ch,
                    child: Semantics(
                      label: 'Bubble, row ${row + 1}, column ${col + 1}, '
                          '${_popped[row * _cols + col] ? 'popped' : 'unpopped'}',
                      button: true,
                      onTap: () =>
                          _popAt(Offset((col + 0.5) * cw, (row + 0.5) * ch), w, h),
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

class _BubbleWrapPainter extends CustomPainter {
  _BubbleWrapPainter({
    required this.popped,
    required this.cols,
    required this.rows,
    required this.bits,
  });
  final List<bool> popped;
  final int cols, rows;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFB9DCEB), Color(0xFF8FC2DC)],
          ).createShader(Offset.zero & size));
    final cw = w / cols, ch = h / rows;
    final r = math.min(cw, ch) * 0.42;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final c = Offset((col + 0.5) * cw, (row + 0.5) * ch);
        if (popped[row * cols + col]) {
          canvas.drawCircle(c, r * 0.8,
              Paint()..color = Colors.black.withOpacity(0.08));
          canvas.drawCircle(c, r * 0.5,
              Paint()..color = Colors.black.withOpacity(0.06));
        } else {
          canvas.drawCircle(c, r,
              Paint()..color = Colors.white.withOpacity(0.55));
          canvas.drawCircle(c, r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = Colors.white.withOpacity(0.8));
          canvas.drawCircle(c.translate(-r * 0.3, -r * 0.3), r * 0.28,
              Paint()..color = Colors.white.withOpacity(0.9));
        }
      }
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 4 * k,
          Paint()..color = s.color.withOpacity(k * 0.8));
    }
  }

  @override
  bool shouldRepaint(_BubbleWrapPainter old) => true;
}

