part of '../arcade_games.dart';

/// Beat Builder — a 4x8 step sequencer. Tap cells to switch on drums; a
/// playhead loops and plays your beat. Fill the grid for a full groove.
class BeatBuilderGame extends StatefulWidget {
  const BeatBuilderGame({super.key});
  @override
  State<BeatBuilderGame> createState() => _BeatBuilderGameState();
}

class _BeatBuilderGameState extends State<BeatBuilderGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'beat_builder';
  static const int _rowsN = 4;
  static const int _steps = 8;
  static const double _tempo = 0.26;
  static const List<int> _rowNotes = <int>[0, 3, 7, 11];
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Nice groove!" line on win screen.
  static const List<String> _winPraisePool = <String>[
    'Nice groove!',
    'Full groove master!',
    'Beat machine!',
    'That really slaps!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  static const List<Color> _rowColors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF8CE99A),
    Color(0xFF66D9E8),
  ];
  final List<bool> _grid = List<bool>.filled(_rowsN * _steps, false);
  int _step = 0;
  double _stepT = 0;
  int _active = 0;
  int _best = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Filling the last cell used to flip `_status` to `GameStatus.won`
  // instantly, and `onTick` below early-returns the moment status isn't
  // `playing` — so the playhead froze mid-bar and the full 8-step groove the
  // child just spent a whole round building was silenced before it could
  // ever actually play, the one payoff this whole game is built around.
  // Keep `_status` at `playing` for one more full loop around the grid so
  // the completed beat plays through at least once, then reveal the win
  // overlay.
  bool _winPending = false;
  double _winDelayT = 0;
  // Every other scoring arcade game (bubble_wrap/hoop_toss/echo...) already
  // celebrates the moment a run's score passes the child's all-time best
  // with a banner + milestone chime + ExperienceEvent.personalBest —
  // `_active` (drums switched on) only ever submitted the new best silently
  // here. Guard it the same way (reset in `_reset()`) so building a bigger
  // groove than ever before gets the same celebration every sibling game
  // gives.
  bool _beatBest = false;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_winPending) {
      _winDelayT -= dt;
      if (_winDelayT <= 0) {
        _winPending = false;
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
      }
    }
    _stepT += dt;
    if (_stepT >= _tempo) {
      _stepT -= _tempo;
      _step = (_step + 1) % _steps;
      for (var r = 0; r < _rowsN; r++) {
        if (_grid[r * _steps + _step]) {
          TonePlayer.instance.playNote(_rowNotes[r], seconds: 0.18);
        }
      }
    }
  }

  void _toggle(Offset p, double w, double h) {
    if (_status != GameStatus.playing) return;
    final col = (p.dx / w * _steps).floor();
    final row = (p.dy / h * _rowsN).floor();
    if (col < 0 || col >= _steps || row < 0 || row >= _rowsN) return;
    _toggleCell(row, col);
  }

  void _toggleCell(int row, int col) {
    // Blocks further edits during the post-fill victory lap below — the
    // grid is already complete and about to be celebrated, so letting a
    // stray tap toggle a cell back off mid-loop would both silently break
    // the "full groove" that's about to play and undo the win it already
    // earned.
    if (_status != GameStatus.playing || _winPending) return;
    final idx = row * _steps + col;
    setState(() {
      _grid[idx] = !_grid[idx];
      _active = _grid.where((b) => b).length;
      if (_grid[idx]) {
        TonePlayer.instance.playNote(_rowNotes[row], seconds: 0.2);
      }
      final crossedBest = _active > _best && !_beatBest && _best > 0;
      if (_active > _best) {
        _best = _active;
        GameScores.instance.submit(_id, _active);
      }
      if (crossedBest) {
        _beatBest = true;
        _banner = 'New personal best! 🏆';
        _bannerT = 1.4;
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_active == _rowsN * _steps) {
        // Filling every step is the whole point of the sequencer, and the
        // instant it happens is the one time all eight steps are lit at
        // once — let the full groove actually loop around and play once
        // (one full bar, `_steps * _tempo`) before the win overlay appears,
        // instead of freezing the playhead the moment the last cell lands.
        // Flashed last so it wins over the personal-best banner above when
        // both land on the same tap — filling the whole grid is the bigger
        // moment.
        _banner = 'Full groove! 🔥';
        _bannerT = 1.6;
        _winPending = true;
        _winDelayT = _steps * _tempo;
      }
    });
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < _grid.length; i++) {
        _grid[i] = false;
      }
      _active = 0;
      _step = 0;
      _stepT = 0;
      _banner = null;
      _bannerT = 0;
      _winPending = false;
      _winDelayT = 0;
      _beatBest = false;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎛️ Beat Builder',
      introHow:
          'Tap the squares to switch drums on and off. The line sweeps across and plays your beat on a loop!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _active,
      best: _best,
      target: _rowsN * _steps,
      status: _status,
      banner: _banner ?? 'Beat: $_active drums on',
      winEmoji: '🎛️',
      winText: _winPraise,
      accent: const Color(0xFF66D9E8),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final cw = w / _steps, ch = h / _rowsN;
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _toggle(d.localPosition, w, h),
                child: CustomPaint(
                  painter: _BeatPainter(
                    grid: _grid,
                    rows: _rowsN,
                    steps: _steps,
                    step: _step,
                    colors: _rowColors,
                  ),
                  size: Size.infinite,
                ),
              ),
              // Each grid cell is painted only onto the canvas with no
              // widget-tree counterpart, so a screen-reader user had no way
              // to discover or toggle any drum step. These invisible
              // Semantics overlays sit at each cell's fixed position and
              // announce its drum row, step number and on/off state,
              // mirroring the fix already applied to
              // dot_to_dot/firefly_count/balloon_math's tap targets.
              for (var r = 0; r < _rowsN; r++)
                for (var s = 0; s < _steps; s++)
                  Positioned(
                    left: s * cw,
                    top: r * ch,
                    width: cw,
                    height: ch,
                    child: Semantics(
                      label: 'Drum ${r + 1}, step ${s + 1}, '
                          '${_grid[r * _steps + s] ? 'on' : 'off'}',
                      button: true,
                      onTap: () => _toggleCell(r, s),
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

class _BeatPainter extends CustomPainter {
  _BeatPainter({
    required this.grid,
    required this.rows,
    required this.steps,
    required this.step,
    required this.colors,
  });
  final List<bool> grid;
  final int rows, steps, step;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF1A1030));
    final cw = w / steps, ch = h / rows;
    // Playhead column.
    canvas.drawRect(Rect.fromLTWH(step * cw, 0, cw, h),
        Paint()..color = Colors.white.withOpacity(0.10));
    for (var r = 0; r < rows; r++) {
      for (var s = 0; s < steps; s++) {
        final rect = Rect.fromLTWH(s * cw + 3, r * ch + 3, cw - 6, ch - 6);
        final on = grid[r * steps + s];
        final playing = on && s == step;
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            Paint()
              ..color = on
                  ? colors[r].withOpacity(playing ? 1.0 : 0.85)
                  : Colors.white.withOpacity(0.06));
        if (playing) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(9)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BeatPainter old) => true;
}

