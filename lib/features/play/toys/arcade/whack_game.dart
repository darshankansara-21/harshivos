part of '../arcade_games.dart';

class WhackGame extends StatefulWidget {
  const WhackGame({super.key});
  @override
  State<WhackGame> createState() => _WhackGameState();
}

class _WhackGameState extends State<WhackGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'whack';
  static const int _holes = 9;
  final math.Random _rnd = math.Random();
  final List<double> _mole = List<double>.filled(_holes, 0); // seconds left
  final List<bool> _isBomb = List<bool>.filled(_holes, false);
  final List<double> _splat = List<double>.filled(_holes, 0); // hit burst timer
  double _spawnIn = 0.7;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

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
    for (var i = 0; i < _holes; i++) {
      if (_splat[i] > 0) _splat[i] -= dt;
      if (_mole[i] > 0) {
        _mole[i] -= dt;
        if (_mole[i] <= 0) {
          // A hamster that ducks away unhit breaks the combo; an avoided bomb
          // is fine.
          if (!_isBomb[i]) _combo = 0;
          _isBomb[i] = false;
        }
      }
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.35, 0.8 - _score * 0.01) *
          (0.6 + _rnd.nextDouble() * 0.7);
      final free = <int>[
        for (var i = 0; i < _holes; i++)
          if (_mole[i] <= 0) i
      ];
      if (free.isNotEmpty) {
        final h = free[_rnd.nextInt(free.length)];
        // Roughly one in five pop-ups is a bomb to avoid.
        _isBomb[h] = _rnd.nextInt(5) == 0;
        _mole[h] = math.max(0.6, 1.4 - _score * 0.02);
      }
    }
  }

  void _hit(int i) {
    if (_status != GameStatus.playing) return;
    if (_mole[i] > 0) {
      final wasBomb = _isBomb[i];
      _mole[i] = 0;
      _isBomb[i] = false;
      if (wasBomb) {
        _combo = 0;
        _score = math.max(0, _score - 1);
        _banner = 'Ouch! Avoid 💣';
        _bannerT = 1.0;
        TonePlayer.instance.playCue(SoundCue.crash);
        emit(ExperienceEvent.incorrectAnswer);
        return;
      }
      _combo++;
      _score += 1 + (_combo >= 5 ? 1 : 0);
      _splat[i] = 0.35;
      TonePlayer.instance.playCue(SoundCue.wood);
      emit(ExperienceEvent.bubblePopped);
      // Milestone cheers give the endless whack a sense of achievement.
      if (_score == 10 || _score == 25 || (_score >= 50 && _score % 25 == 0)) {
        _banner = '$_score moles! 🎉';
        _bannerT = 1.3;
        TonePlayer.instance.playCue(SoundCue.milestone);
      } else if (_combo >= 5) {
        _banner = 'Combo x$_combo!';
        _bannerT = 1.0;
      }
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) setState(() => _best = b);
      });
    }
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < _holes; i++) {
        _mole[i] = 0;
        _isBomb[i] = false;
        _splat[i] = 0;
      }
      _score = 0;
      _combo = 0;
      _banner = null;
      _bannerT = 0;
      _spawnIn = 0.7;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔨 Whack',
      introHow: 'Tap the moles as they pop up — but never the bombs!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF8D5A3B),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF3B2A1A), Color(0xFF241810)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 60),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (var i = 0; i < _holes; i++)
                GestureDetector(
                  onTapDown: (_) => _hit(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A120A),
                      borderRadius: BorderRadius.circular(80),
                      border: Border.all(color: const Color(0xFF4A3420), width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        AnimatedScale(
                          scale: _mole[i] > 0 ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          child: Text(_isBomb[i] ? '💣' : '🐹',
                              style: const TextStyle(fontSize: 46)),
                        ),
                        if (_splat[i] > 0)
                          Opacity(
                            opacity: (_splat[i] / 0.35).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 1 + (1 - _splat[i] / 0.35) * 1.5,
                              child: const Text('💥',
                                  style: TextStyle(fontSize: 44)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Sky Hop — one-tap flappy. Tap to flap the bird up through the gaps. Each gap
// cleared scores a point; touching a pipe or the ground ends the run.
// ===========================================================================
