part of '../arcade_games.dart';

/// Xylophone Tap — a rainbow xylophone you can free-play, with a guided tune
/// mode: the next bar glows, tap it to play the song. Every bar always sounds,
/// so tapping around is encouraged. Finish three tunes to win.
class XylophoneTapGame extends StatefulWidget {
  const XylophoneTapGame({super.key});
  @override
  State<XylophoneTapGame> createState() => _XylophoneTapGameState();
}

class _XyloTune {
  const _XyloTune(this.name, this.bars);
  final String name;
  final List<int> bars; // indices into the 8 bars
}

class _XylophoneTapGameState extends State<XylophoneTapGame> with _Emit {
  static const String _id = 'xylophone_tap';
  // 8 bars: C D E F G A B C' — a full diatonic octave.
  static const List<int> _degrees = <int>[0, 2, 4, 5, 7, 9, 11, 12];
  static const List<Color> _colors = <Color>[
    Color(0xFFE63946), // C red
    Color(0xFFF4A261), // D orange
    Color(0xFFFFD166), // E yellow
    Color(0xFF80ED99), // F green
    Color(0xFF48CAE4), // G sky
    Color(0xFF4361EE), // A blue
    Color(0xFF9B5DE5), // B violet
    Color(0xFFFF5DA2), // C' pink
  ];
  static const List<_XyloTune> _tunes = <_XyloTune>[
    _XyloTune('Twinkle Twinkle', <int>[0, 0, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0]),
    _XyloTune('Hot Cross Buns', <int>[2, 1, 0, 2, 1, 0, 0, 0, 0, 1, 1, 1, 1, 2, 1, 0]),
    _XyloTune('Up and Down', <int>[0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1, 0]),
  ];
  static const int _target = 3;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'All 3 tunes played!', 'Melody master!', 'Perfect performance!', 'Musical star!',
  ];
  String _winPraise = _winPraisePool[0];
  // Pool of per-tune completion prefixes so finishing a tune doesn't always
  // flash the identical "Lovely!" prefix (the tune name itself already varies).
  static const List<String> _nextTunePrefixPool = <String>[
    'Lovely!', 'Beautiful!', 'Well played!', 'Nice music!',
  ];
  late List<int> _order; // shuffled tune order for this playthrough
  int _orderPos = 0;
  int _pos = 0;
  int _score = 0; // tunes completed
  int _best = 0;
  bool _beatBest = false;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  int _wrongBar = -1; // brief red flash on a mis-tapped bar

  @override
  void initState() {
    super.initState();
    _order = List<int>.generate(_tunes.length, (i) => i)..shuffle(_rnd);
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  _XyloTune get _tune => _tunes[_order[_orderPos]];
  int get _nextBar => _tune.bars[_pos];

  void _start() {
    setState(() {
      _order = List<int>.generate(_tunes.length, (i) => i)..shuffle(_rnd);
      _orderPos = 0;
      _pos = 0;
      _score = 0;
      _beatBest = false;
      _banner = null;
      _status = GameStatus.playing;
    });
  }

  void _hit(int b) {
    if (_status != GameStatus.playing) return;
    TonePlayer.instance.playNote(_degrees[b], seconds: 0.3);
    if (b == _nextBar) {
      _pos++;
      if (_pos >= _tune.bars.length) {
        _score++;
        emit(ExperienceEvent.bubblePopped);
        TonePlayer.instance.playCue(SoundCue.success);
        // A run abandoned before all 3 tunes (e.g. quitting after tune 1 of
        // 3) still silently persisted a new best — the exact "stat that can
        // never move" bug class already fixed catalog-wide (shape_builder,
        // air_hockey, etc.). Celebrate the moment it's actually crossed.
        final crossedBest = _score > _best && !_beatBest && _best > 0;
        GameScores.instance.submit(_id, _score).then((v) {
          if (mounted) setState(() => _best = v);
        });
        if (crossedBest) _beatBest = true;
        if (_score >= _target) {
          _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _orderPos++;
          _pos = 0;
          _banner = crossedBest
              ? 'New personal best! 🏆'
              : '${_nextTunePrefixPool[_rnd.nextInt(_nextTunePrefixPool.length)]} Next: ${_tune.name}';
          if (crossedBest) {
            TonePlayer.instance.playCue(SoundCue.milestone);
            emit(ExperienceEvent.personalBest);
          }
        }
      } else {
        _banner = null;
      }
    } else {
      // Same gap as piano_song: a wrong tap only changed the banner text,
      // never the bar the child actually touched. Add the catalog-wide
      // brief red-flash-then-clear feedback so the tap itself answers them.
      _banner = 'Follow the glowing bar';
      _wrongBar = b;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      emit(ExperienceEvent.incorrectAnswer);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _wrongBar == b) setState(() => _wrongBar = -1);
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final progress = _status == GameStatus.playing
        ? '${_tune.name} · ${_pos + 1}/${_tune.bars.length}'
        : 'Tap the glowing bars to play a tune';
    return _Shell(
      title: '🎵 Xylophone Tap',
      introHow:
          'Tap the bars to make music. The next bar in the tune glows — follow '
          'it to play the song. Three tunes to win!',
      onStart: _start,
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? progress,
      winEmoji: '🎵',
      winText: _winPraise,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _start,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF241A12), Color(0xFF130D08)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 150, 16, 26),
            child: Column(
              children: <Widget>[
                for (var b = 0; b < 8; b++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Align(
                        alignment: Alignment.center,
                        child: FractionallySizedBox(
                          // Bars shorten as the pitch rises, like a real toy.
                          widthFactor: 1.0 - b * 0.055,
                          child: _XyloBar(
                            index: b,
                            color: _colors[b],
                            lit: _status == GameStatus.playing && _nextBar == b,
                            wrong: _wrongBar == b,
                            onTap: () => _hit(b),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _XyloBar extends StatelessWidget {
  const _XyloBar({
    required this.color,
    required this.lit,
    required this.onTap,
    required this.index,
    this.wrong = false,
  });
  final Color color;
  final bool lit;
  final bool wrong;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Bars are tappable only via a bare GestureDetector with zero Semantics
    // tree, making this "free-play + follow the glowing bar" premise
    // silently unplayable by a blind child. The label now includes whether
    // THIS bar is the one currently lit (matching shape_builder_game's
    // "current piece" convention) so a screen-reader user can follow the
    // guided tune the same way a sighted child follows the glow, instead of
    // having to separately track the progress banner text.
    return Semantics(
      button: true,
      label: 'Bar ${index + 1}${lit ? ', glowing, tap now' : ''}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: wrong
                ? <Color>[
                    Color.lerp(const Color(0xFFE23B3B), Colors.white, 0.35)!,
                    const Color(0xFFE23B3B),
                  ]
                : <Color>[
                    Color.lerp(color, Colors.white, lit ? 0.5 : 0.18)!,
                    color,
                  ],
          ),
          border: wrong
              ? Border.all(color: const Color(0xFFFFD9D9), width: 3)
              : (lit ? Border.all(color: Colors.white, width: 3) : null),
          boxShadow: wrong
              ? <BoxShadow>[
                  BoxShadow(
                      color: const Color(0xFFE23B3B).withOpacity(0.8),
                      blurRadius: 20,
                      spreadRadius: 1),
                ]
              : (lit
                  ? <BoxShadow>[
                      BoxShadow(
                          color: color.withOpacity(0.8),
                          blurRadius: 20,
                          spreadRadius: 1),
                    ]
                  : <BoxShadow>[
                      BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ]),
        ),
        child: const Center(
          child: SizedBox(width: 10, height: 10),
        ),
      ),
      ),
    );
  }
}
