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

  late List<int> _order; // shuffled tune order for this playthrough
  int _orderPos = 0;
  int _pos = 0;
  int _score = 0; // tunes completed
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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
        GameScores.instance.submit(_id, _score).then((v) {
          if (mounted) setState(() => _best = v);
        });
        if (_score >= _target) {
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _orderPos++;
          _pos = 0;
          _banner = 'Lovely! Next: ${_tune.name}';
        }
      } else {
        _banner = null;
      }
    } else {
      _banner = 'Follow the glowing bar';
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
      winText: 'Keep playing!',
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
                            color: _colors[b],
                            lit: _status == GameStatus.playing && _nextBar == b,
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
  const _XyloBar({required this.color, required this.lit, required this.onTap});
  final Color color;
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.lerp(color, Colors.white, lit ? 0.5 : 0.18)!,
              color,
            ],
          ),
          border: lit ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: lit
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
                ],
        ),
        child: const Center(
          child: SizedBox(width: 10, height: 10),
        ),
      ),
    );
  }
}
