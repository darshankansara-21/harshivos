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

  List<int> _tones = <int>[]; // tone index per bell
  final Set<int> _matched = <int>{};
  final List<int> _revealed = <int>[];
  double _hideT = 0;
  int _score = 0; // pairs found
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
        _banner = 'Matched!';
        GameScores.instance.submit(_id, _score).then((v) {
          if (mounted) setState(() => _best = v);
        });
        if (_matched.length >= _tones.length) {
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
      winText: 'Good ears!',
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
          child: Padding(
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
        ),
      ),
    );
  }

  Widget _buildBell(int i) {
    final shown = _matched.contains(i) || _revealed.contains(i);
    return GestureDetector(
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
    );
  }
}
