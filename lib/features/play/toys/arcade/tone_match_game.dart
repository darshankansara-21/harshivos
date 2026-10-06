part of '../arcade_games.dart';

/// Tone Match — the bells all look the same. Tap one to hear its note, then find
/// the bell that plays the same note. Match all four pairs by ear to win.
class ToneMatchGame extends StatefulWidget {
  const ToneMatchGame({super.key});
  @override
  State<ToneMatchGame> createState() => _ToneMatchGameState();
}

class _ToneMatchGameState extends State<ToneMatchGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'tone_match';
  static const List<int> _toneNotes = <int>[0, 4, 7, 12];
  static const List<Color> _toneColors = <Color>[
    Color(0xFFE63946), Color(0xFF48CAE4), Color(0xFFFFD166), Color(0xFF9B5DE5),
  ];
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Good ears!', 'Perfect pitch!', 'Sound master!', 'Great listening!',
  ];
  String _winPraise = _winPraisePool[0];
  // Every matched pair routinely flashed the exact same "Matched!" banner
  // (up to four times in one round); vary it like the win-screen praise.
  static const List<String> _matchPool = <String>[
    'Matched!', 'Nice ears!', 'Good listening!', 'Found it!',
  ];

  List<int> _tones = <int>[]; // tone index per bell
  final Set<int> _matched = <int>{};
  final List<int> _revealed = <int>[];
  double _hideT = 0;
  int _score = 0; // pairs found
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // A found pair only ever recoloured the two bells — every other grid
  // matching game in the catalog (memory_flip, odd_one_out, shadow_match)
  // bursts a few shards of colour on a correct match; this one, built
  // entirely around the "found it!" feeling, stayed flat. Mirror the
  // established convention using the same fractional-grid-cell centre
  // approach memory_flip_game uses for its own widget-grid bells.
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _deal() {
    _tones = <int>[0, 0, 1, 1, 2, 2, 3, 3]..shuffle(_rnd);
    _matched.clear();
    _revealed.clear();
    _hideT = 0;
    _score = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_hideT > 0) {
      _hideT -= dt;
      if (_hideT <= 0) {
        _revealed.clear();
        setState(() {});
      }
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_bits.isNotEmpty) setState(() {});
  }

  // Mirrors memory_flip_game.dart's `_cellCenter`: resolves a bell index to
  // its real on-screen fractional centre from the same crossAxisCount: 4,
  // mainAxisSpacing/crossAxisSpacing: 14, padding: fromLTRB(26, 150, 26, 40)
  // the GridView itself is built with below.
  Offset _cellCenter(int i, double w, double h) {
    const cols = 4, spacing = 14.0;
    const padLeft = 26.0, padRight = 26.0, padTop = 150.0, padBottom = 40.0;
    final rows = (_tones.length / cols).ceil();
    final availW = w - padLeft - padRight;
    final availH = h - padTop - padBottom;
    final cellW = (availW - spacing * (cols - 1)) / cols;
    final cellH = (availH - spacing * (rows - 1)) / rows;
    final col = i % cols, row = i ~/ cols;
    final cx = padLeft + col * (cellW + spacing) + cellW / 2;
    final cy = padTop + row * (cellH + spacing) + cellH / 2;
    return Offset(cx / w, cy / h);
  }

  void _burst(Offset fracPos, Color color) {
    final n = _reduceMotion ? 4 : 12;
    for (var k = 0; k < n; k++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.3;
      _bits.add(_Shard(fracPos.dx, fracPos.dy, math.cos(a) * sp,
          math.sin(a) * sp, color));
    }
  }

  void _tap(int i) {
    if (_status != GameStatus.playing) return;
    if (_matched.contains(i) || _revealed.contains(i) || _hideT > 0) return;
    if (_revealed.length >= 2) return;
    TonePlayer.instance.playNote(_toneNotes[_tones[i]], seconds: 0.35);
    _revealed.add(i);
    if (_revealed.length == 2) {
      final a = _revealed[0], b = _revealed[1];
      if (_tones[a] == _tones[b]) {
        _matched.addAll(<int>[a, b]);
        _revealed.clear();
        _score++;
        emit(ExperienceEvent.bubblePopped);
        TonePlayer.instance.playCue(SoundCue.success);
        if (_lastSize != null) {
          final color = _toneColors[_tones[a]];
          _burst(_cellCenter(a, _lastSize!.width, _lastSize!.height), color);
          _burst(_cellCenter(b, _lastSize!.width, _lastSize!.height), color);
        }
        _banner = _matchPool[_rnd.nextInt(_matchPool.length)];
        GameScores.instance.submit(_id, _score).then((v) {
          if (mounted) setState(() => _best = v);
        });
        if (_matched.length >= _tones.length) {
          _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        }
      } else {
        _hideT = 0.9;
        // Every other mismatch/no-op interaction across the catalog gives a
        // distinct sound cue (see memory_flip_game.dart's _loseLife); this
        // auditory-memory game played each bell's own note on reveal but
        // stayed completely silent on the mismatch itself, leaving a child
        // to infer failure from the banner text alone.
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        emit(ExperienceEvent.incorrectAnswer);
        _banner = 'Different notes — listen again';
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _banner = null;
      _deal();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔔 Tone Match',
      introHow:
          'The bells look the same. Tap one to hear its note, then find the '
          'bell that sounds the same. Match all four pairs to win!',
      onStart: () => setState(() {
        _deal();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: 4,
      status: _status,
      banner: _banner ?? 'Find the matching sounds',
      winEmoji: '🔔',
      winText: _winPraise,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1E1A2E), Color(0xFF0F0C18)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
              _reduceMotion = MediaQuery.disableAnimationsOf(context);
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 150, 26, 40),
                    child: GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      physics: const NeverScrollableScrollPhysics(),
                      children: <Widget>[
                        for (var i = 0; i < _tones.length; i++)
                          _buildBell(i),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _ToneMatchShardPainter(_bits)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBell(int i) {
    final shown = _matched.contains(i) || _revealed.contains(i);
    // The game is auditory-memory by design — every bell looks (and sounds,
    // until tapped) identical, so the Semantics label must never reveal a
    // bell's tone ahead of a tap; it only states the same visible state a
    // sighted child sees (hidden / matched), matching information parity.
    final label = _matched.contains(i)
        ? 'Bell ${i + 1}, matched'
        : 'Bell ${i + 1}, hidden, tap to hear its note';
    return Semantics(
      button: true,
      label: label,
      onTap: () => _tap(i),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _tap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: shown ? _toneColors[_tones[i]] : Colors.white12,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _matched.contains(i) ? Colors.white : Colors.white24, width: 2),
          ),
          child: const Center(child: Text('🔔', style: TextStyle(fontSize: 30))),
        ),
      ),
    );
  }
}

class _ToneMatchShardPainter extends CustomPainter {
  _ToneMatchShardPainter(this.bits);
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_ToneMatchShardPainter oldDelegate) => true;
}
