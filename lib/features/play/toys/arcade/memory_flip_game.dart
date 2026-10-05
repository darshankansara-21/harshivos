part of '../arcade_games.dart';

class MemoryFlipGame extends StatefulWidget {
  const MemoryFlipGame({super.key});
  @override
  State<MemoryFlipGame> createState() => _MemoryFlipGameState();
}

class _MemoryFlipGameState extends State<MemoryFlipGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'memory_flip';
  static const List<String> _facePool = <String>[
    '🍎',
    '⭐',
    '🐢',
    '🎈',
    '🌸',
    '🚗',
    '🐬',
    '🎵',
    '🦋',
    '🍩'
  ];
  static const int _maxLevel = 5;
  late List<String> _cards;
  late List<bool> _matched;
  int _first = -1;
  int _second = -1;
  bool _locked = false;
  int _pairs = 0;
  int _level = 1;
  int _streak = 0;
  int _score = 0;
  int _best = 0;
  int _lives = 3;
  bool _previewing = false;
  double _previewLeft = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  // Per-level think-fast timer: running out costs a life (same as a wrong
  // match) but banking leftover time pays out a bonus, so players choose
  // between careful memorising and a faster, riskier pace.
  double _timeLimit = 0;
  double _timeLeft = 0;

  int get _pairsThisLevel => (5 + _level).clamp(4, _facePool.length);
  double get _levelTimeLimit => 16 + _pairsThisLevel * 2.2;

  @override
  void initState() {
    super.initState();
    _deal();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_previewing) {
      _previewLeft -= dt;
      if (_previewLeft <= 0) _previewing = false;
      return;
    }
    if (_locked) return;
    _timeLeft -= dt;
    if (_timeLeft <= 0) {
      _timeLeft = _timeLimit;
      _loseLife('Too slow! $_lives left');
    }
  }

  void _deal() {
    final faces = _facePool.take(_pairsThisLevel).toList();
    _cards = <String>[...faces, ...faces];
    _cards.shuffle();
    _matched = List<bool>.filled(_cards.length, false);
    _first = -1;
    _second = -1;
    _locked = false;
    _pairs = 0;
    _timeLimit = _levelTimeLimit;
    _timeLeft = _timeLimit;
  }

  void _startPreview() {
    setState(() {
      _previewing = true;
      _previewLeft = 1.4;
    });
  }

  /// Shared penalty path for a wrong match or a timeout: drops a life, ends
  /// the game if that was the last one, otherwise flashes [missMessage].
  void _loseLife(String missMessage) {
    _streak = 0;
    _lives--;
    if (_lives <= 0) {
      _status = GameStatus.over;
      TonePlayer.instance.playCue(SoundCue.gameOver);
      final prev = GameScores.instance.best(_id);
      emit(_score > prev
          ? ExperienceEvent.gameCompleted
          : ExperienceEvent.incorrectAnswer);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      _flash('Game over!');
      return;
    }
    TonePlayer.instance.playCue(SoundCue.gentleRetry);
    _flash(missMessage);
  }

  bool get _gameOver => _status == GameStatus.over;

  /// Rewards leftover level time as score, shown appended to [base].
  String _bankTimeBonus(String base) {
    final bonus = (_timeLeft * 2).round();
    if (bonus <= 0) return base;
    _score += bonus;
    return '$base (+$bonus time bonus)';
  }

  void _flash(String s) {
    _banner = s;
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  void _tap(int i) {
    if (_previewing ||
        _locked ||
        _matched[i] ||
        i == _first ||
        _status != GameStatus.playing) {
      return;
    }
    // A card flip is a flat paper/cardboard tile, not a wooden block — use
    // the dedicated `paper` grain cue (previously orphaned) instead of the
    // percussive `wood` click so the sound actually matches what's drawn.
    TonePlayer.instance.playCue(SoundCue.paper);
    setState(() {
      if (_first == -1) {
        _first = i;
      } else {
        _second = i;
        if (_cards[_first] == _cards[_second]) {
          _matched[_first] = true;
          _matched[_second] = true;
          _pairs++;
          _streak++;
          _score += 10 + (_streak >= 3 ? 5 : 0);
          TonePlayer.instance.playCue(SoundCue.learnGood);
          if (_streak >= 3) _flash('Streak x$_streak!');
          _first = -1;
          _second = -1;
          if (_pairs >= _pairsThisLevel) {
            if (_level >= _maxLevel) {
              _flash(_bankTimeBonus('Galaxy cleared!'));
              _status = GameStatus.won;
              TonePlayer.instance.playCue(SoundCue.success);
              emit(ExperienceEvent.gameCompleted);
              GameScores.instance.submit(_id, _score).then((b) {
                if (mounted) setState(() => _best = b);
              });
            } else {
              _flash(_bankTimeBonus('Level $_level!'));
              _level++;
              _score += 20;
              TonePlayer.instance.playCue(SoundCue.milestone);
              // Clearing a level is a real in-run milestone, not the end of
              // the galaxy — only the _level >= _maxLevel branch above is
              // the true completion that earns the full celebration.
              emit(ExperienceEvent.bubblePopped);
              _locked = true;
              Future<void>.delayed(const Duration(milliseconds: 650), () {
                if (!mounted) return;
                setState(_deal);
                _startPreview();
              });
            }
          } else {
            emit(ExperienceEvent.bubblePopped);
          }
        } else {
          _loseLife('Miss! $_lives left');
          if (_gameOver) return;
          _locked = true;
          Future<void>.delayed(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            setState(() {
              _first = -1;
              _second = -1;
              _locked = false;
            });
          });
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _level = 1;
      _streak = 0;
      _score = 0;
      _lives = 3;
      _banner = null;
      _previewing = false;
      _previewLeft = 0;
      _deal();
      _status = GameStatus.playing;
    });
    _startPreview();
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final cols = _cards.length <= 12 ? 3 : 4;
    return _Shell(
      title: '🧠 Memory Flip',
      introHow:
          'Flip two cards to find matching pairs before the timer runs out. Clear every level, bank leftover time as bonus points!',
      onStart: () {
        setState(() {
          _status = GameStatus.playing;
          _previewing = false;
          _previewLeft = 0;
        });
        _startPreview();
      },
      score: _score,
      best: _best,
      status: _status,
      banner: _banner ??
          (_previewing
              ? 'Memorize the pairs!'
              : 'Level $_level · ⏱ ${_timeLeft.ceil()}s · $_lives❤'),
      overEmoji: '💔',
      overText: 'Out of lives — nice try!',
      winEmoji: '🧠',
      winText: 'Great memory!',
      accent: const Color(0xFF06D6A0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF10233A), Color(0xFF0A1626)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 70),
            child: GridView.count(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (var i = 0; i < _cards.length; i++)
                  Builder(builder: (context) {
                    final faceUp = _previewing ||
                        _matched[i] ||
                        i == _first ||
                        i == _second;
                    return GestureDetector(
                      onTapDown: (_) => _tap(i),
                      child: TweenAnimationBuilder<double>(
                        // Re-keys when a card becomes matched, firing a pop.
                        key: ValueKey('mem-$i-${_matched[i]}'),
                        tween: Tween<double>(
                            begin: _matched[i] ? 1.35 : 1.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _matched[i]
                                ? const Color(0xFF06D6A0).withOpacity(0.35)
                                : faceUp
                                    ? Colors.white
                                    : const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(14),
                            border: _matched[i]
                                ? Border.all(
                                    color: const Color(0xFFFFD166), width: 2)
                                : null,
                            boxShadow: _matched[i]
                                ? <BoxShadow>[
                                    BoxShadow(
                                        color: const Color(0xFF06D6A0)
                                            .withOpacity(0.5),
                                        blurRadius: 14)
                                  ]
                                : const <BoxShadow>[],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              faceUp ? _cards[i] : '',
                              maxLines: 1,
                              style: TextStyle(fontSize: cols == 3 ? 40 : 30),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Ball Sort — pour coloured balls between tubes until each tube holds a single
// colour. A calm, deeply satisfying sorting puzzle that quietly trains planning
// and colour sorting. Levels add more colours as you go.
// ===========================================================================
