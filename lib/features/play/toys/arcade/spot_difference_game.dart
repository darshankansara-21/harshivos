part of '../arcade_games.dart';

/// Spot the Difference — one tile in the grid is a different colour. Tap the
/// odd one out. The grid grows as you go. Ten right to win.
class SpotDifferenceGame extends StatefulWidget {
  const SpotDifferenceGame({super.key});
  @override
  State<SpotDifferenceGame> createState() => _SpotDifferenceGameState();
}

class _SpotDifferenceGameState extends State<SpotDifferenceGame> with _Emit {
  static const String _id = 'spot_difference';
  static const int _target = 10;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Eagle eyes!', 'Sharp spotter!', 'Great eyes!', 'Detail detective!',
  ];
  String _winPraise = _winPraisePool[0];
  String _overPraise = _gentleTryAgainPool[0];
  // banner (up to ten times in one round); vary it like the win praise.
  static const List<String> _spottedPool = <String>[
    'Spotted it! 🔍', 'Sharp eyes!', 'Found it!', 'Nice spot!',
  ];
  int _cols = 3, _rows = 3;
  int _odd = 0;
  Color _base = const Color(0xFF66D9E8);
  Color _oddColor = const Color(0xFFFF6B6B);
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  bool _beatBest = false;
  int _wrongFlash = -1;
  String? _banner;
  // Every spot/miss/best banner was only ever cleared by `_reset()`, so the
  // very first tap's text glued itself on screen for the rest of the run.
  Timer? _bannerTimer;
  GameStatus _status = GameStatus.ready;

  void _flashBanner(String text, {Duration duration = const Duration(milliseconds: 1100)}) {
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
  // The grid-size and colour-closeness ramps below only ever read the
  // current round's `_score`, so a veteran with a high all-time `_best`
  // restarted every single playthrough at the identical easy 3x3 round 1 —
  // the same "flat-forever difficulty never fed by career `_best`" bug
  // class already closed for the quiz-game family. Nudge the effective
  // score a little from round 1 for a seasoned player, capped small so
  // round 1 stays genuinely playable even for them.
  int get _careerSkillRamp => (_best ~/ 3).clamp(0, 3);

  @override
  void initState() {
    super.initState();
    _newRound();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newRound() {
    final n = (3 + (_score + _careerSkillRamp) ~/ 3).clamp(3, 5);
    _cols = n;
    _rows = n;
    _odd = _rnd.nextInt(n * n);
    final hue = _rnd.nextDouble() * 360;
    _base = HSVColor.fromAHSV(1, hue, 0.6, 0.85).toColor();
    // The odd tile is a subtly different shade; closer as score rises.
    final delta = (0.32 - (_score + _careerSkillRamp) * 0.02).clamp(0.14, 0.32);
    _oddColor = HSVColor.fromAHSV(1, (hue + 18) % 360, 0.6, 0.85 - delta).toColor();
    _wrongFlash = -1;
  }

  void _pick(int idx) {
    if (_status != GameStatus.playing) return;
    if (idx == _odd) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _flashBanner(_spottedPool[_rnd.nextInt(_spottedPool.length)]);
      // A child who runs out of lives right after this tap still deserves
      // the companion's loudest celebration if it's a genuine all-time
      // record, not just the routine correct-spot chime.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (crossedBest) {
        _beatBest = true;
        _flashBanner('New personal best! 🏆', duration: const Duration(milliseconds: 1300));
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_score >= _target) {
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrongFlash = idx;
      _lives--;
      // Every wrong tap deserves the companion's gentle encouraging
      // reaction, not just the one that happens to end the game.
      emit(ExperienceEvent.incorrectAnswer);
      if (_lives <= 0) {
        // The life-ending miss is the real end of the run — it must sound
        // distinct from a routine miss, never just the same gentle-retry cue.
        _status = GameStatus.over;
        _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
        _banner = 'Out of lives!';
        TonePlayer.instance.playCue(SoundCue.gameOver);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _flashBanner('Look closely…');
        // Same stuck-wrong-flash bug class fixed catalog-wide (weather_sort,
        // bigger_number, odd_one_out, _ChoiceGoalGame, etc.): `_wrongFlash`
        // was previously only cleared by the NEXT correct tap's `_newRound`,
        // so a child who missed then kept scanning the grid saw the wrong
        // tile stay red-bordered the whole search instead of a brief, honest
        // mistake flash. Auto-clear after a short delay, gated on `mounted
        // && _wrongFlash == idx` so a later miss on a different tile can't
        // be stomped by a stale timer.
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted && _wrongFlash == idx) {
            setState(() => _wrongFlash = -1);
          }
        });
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _beatBest = false;
      _banner = null;
      _bannerTimer?.cancel();
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔍 Spot the Difference',
      introHow:
          'One tile is a slightly different colour from the rest. Tap the odd one out! '
          'A wrong tap costs one of your 3 lives.',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Find the odd tile · ${'💛' * _lives}',
      overEmoji: '💪',
      overText: _overPraise,
      winEmoji: '🔍',
      winText: _winPraise,
      accent: const Color(0xFF66D9E8),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final cw = w / _cols, ch = h / _rows;
          // Every tile is painted only onto the canvas with a colour
          // difference so subtle it's the entire challenge — but that left
          // the whole grid with zero Semantics tree, so a screen-reader
          // user couldn't even discover a tile existed to tap, let alone
          // which one they'd just picked. These invisible per-tile overlays
          // (same pattern as odd_one_out/pattern_weaver) expose position and
          // route to the real `_pick()` hit-test, without naming the shade
          // itself — that would hand away the answer this game is about.
          final tiles = <Widget>[
            for (var r = 0; r < _rows; r++)
              for (var cc = 0; cc < _cols; cc++)
                Positioned(
                  left: cc * cw,
                  top: r * ch,
                  width: cw,
                  height: ch,
                  child: Semantics(
                    label: 'Row ${r + 1} column ${cc + 1}',
                    button: true,
                    onTap: () => _pick(r * _cols + cc),
                    child: const SizedBox.expand(),
                  ),
                ),
          ];
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final col = (d.localPosition.dx / w * _cols).floor();
                  final row = (d.localPosition.dy / h * _rows).floor();
                  if (col < 0 || col >= _cols || row < 0 || row >= _rows) return;
                  _pick(row * _cols + col);
                },
                child: CustomPaint(
                  painter: _SpotPainter(
                    cols: _cols,
                    rows: _rows,
                    odd: _odd,
                    base: _base,
                    oddColor: _oddColor,
                    wrongFlash: _wrongFlash,
                  ),
                  size: Size.infinite,
                ),
              ),
              ...tiles,
            ],
          );
        },
      ),
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter({
    required this.cols,
    required this.rows,
    required this.odd,
    required this.base,
    required this.oddColor,
    required this.wrongFlash,
  });
  final int cols, rows, odd, wrongFlash;
  final Color base, oddColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF12131A));
    final cw = w / cols, ch = h / rows;
    for (var r = 0; r < rows; r++) {
      for (var cc = 0; cc < cols; cc++) {
        final idx = r * cols + cc;
        final rect = Rect.fromLTWH(cc * cw + 6, r * ch + 6, cw - 12, ch - 12);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(14)),
            Paint()..color = idx == odd ? oddColor : base);
        if (idx == wrongFlash) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(14)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4
                ..color = const Color(0xFFE23B3B));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SpotPainter old) => true;
}

