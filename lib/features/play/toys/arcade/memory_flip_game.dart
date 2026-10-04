part of '../arcade_games.dart';

class MemoryFlipGame extends StatefulWidget {
  const MemoryFlipGame({super.key});
  @override
  State<MemoryFlipGame> createState() => _MemoryFlipGameState();
}

class _MemoryFlipGameState extends State<MemoryFlipGame> with _Emit {
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
  String? _banner;
  GameStatus _status = GameStatus.ready;

  int get _pairsThisLevel => (5 + _level).clamp(4, _facePool.length);

  @override
  void initState() {
    super.initState();
    _deal();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
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
  }

  void _flash(String s) {
    _banner = s;
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  void _tap(int i) {
    if (_locked ||
        _matched[i] ||
        i == _first ||
        _status != GameStatus.playing) {
      return;
    }
    TonePlayer.instance.playCue(SoundCue.wood);
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
              _status = GameStatus.won;
              TonePlayer.instance.playCue(SoundCue.success);
              emit(ExperienceEvent.gameCompleted);
              GameScores.instance.submit(_id, _score).then((b) {
                if (mounted) setState(() => _best = b);
              });
            } else {
              _level++;
              _score += 20;
              _flash('Level $_level!');
              TonePlayer.instance.playCue(SoundCue.milestone);
              emit(ExperienceEvent.gameCompleted);
              _locked = true;
              Future<void>.delayed(const Duration(milliseconds: 650), () {
                if (!mounted) return;
                setState(_deal);
              });
            }
          } else {
            emit(ExperienceEvent.bubblePopped);
          }
        } else {
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
          _locked = true;
          _flash('Miss! $_lives left');
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

  void _reset() => setState(() {
        _level = 1;
        _streak = 0;
        _score = 0;
        _lives = 3;
        _banner = null;
        _deal();
        _status = GameStatus.playing;
      });

  @override
  Widget build(BuildContext context) {
    drain(context);
    final cols = _cards.length <= 12 ? 3 : 4;
    return _Shell(
      title: '🧠 Memory Flip',
      introHow: 'Flip two cards to find matching pairs. Clear them all!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner ?? 'Level $_level / $_lives left',
      overEmoji: '🧠',
      overText: 'Great memory!',
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
                  GestureDetector(
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
                              : (i == _first || i == _second)
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
                        child: Text(
                          (_matched[i] || i == _first || i == _second)
                              ? _cards[i]
                              : '',
                          style: TextStyle(fontSize: cols == 3 ? 40 : 30),
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

// ===========================================================================
// Ball Sort — pour coloured balls between tubes until each tube holds a single
// colour. A calm, deeply satisfying sorting puzzle that quietly trains planning
// and colour sorting. Levels add more colours as you go.
// ===========================================================================
