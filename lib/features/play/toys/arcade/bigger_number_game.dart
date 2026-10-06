part of '../arcade_games.dart';

/// Bigger Number — read whether to find the biggest or the smallest, then tap
/// the right number. The range grows as you go. Twelve right to win.
class BiggerNumberGame extends StatefulWidget {
  const BiggerNumberGame({super.key});
  @override
  State<BiggerNumberGame> createState() => _BiggerNumberGameState();
}

class _BiggerNumberGameState extends State<BiggerNumberGame> with _Emit {
  static const String _id = 'bigger_number';
  static const int _target = 12;
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Number star!" line on win screen.
  static const List<String> _winPraisePool = <String>[
    'Number star!',
    'Number genius!',
    'Sharp number eyes!',
    'Twelve for twelve!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  // Every correct tap routinely flashed the exact same "Correct!" banner
  // (up to twelve times in one round); vary it like the win-screen praise.
  static const List<String> _correctPool = <String>[
    'Correct!', 'Sharp eyes!', 'Nice pick!', 'Got it!',
  ];

  List<int> _nums = <int>[2, 5, 8];
  bool _biggest = true;
  int _score = 0, _lives = 3, _best = 0;
  bool _beatBest = false;
  int _wrong = -1;
  // Unlike the wrong tap (which flashes the tile red), a correct tap gave
  // zero tile-level visual feedback at all — the numbers just silently
  // swapped out for the next round under the banner text. Flash the tapped
  // tile green for a beat, same convention as the red wrong-flash, so a
  // correct answer is visibly confirmed, not just announced in text a
  // child might not be looking at.
  int _correct = -1;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newRound() {
    _wrong = -1;
    _correct = -1;
    _biggest = _rnd.nextBool();
    final max = _maxForScore(_score);
    final set = <int>{};
    while (set.length < 3) {
      set.add(1 + _rnd.nextInt(max));
    }
    _nums = set.toList()..shuffle(_rnd);
  }

  // Gentle ramp: early correct answers widen the number range only a little
  // (so the very first win doesn't suddenly throw a much bigger range at the
  // child), then the step grows round by round up to a steady pace.
  int _maxForScore(int score) {
    var max = 9;
    for (var i = 0; i < score; i++) {
      max += math.min(2 + i, 7);
    }
    return max.clamp(9, 99);
  }

  int get _answer {
    var best = _nums[0];
    for (final n in _nums) {
      if (_biggest ? n > best : n < best) best = n;
    }
    return best;
  }

  void _tap(int i) {
    if (_status != GameStatus.playing) return;
    if (_nums[i] == _answer) {
      _score++;
      _correct = i;
      TonePlayer.instance.playCue(SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      _banner = _correctPool[_rnd.nextInt(_correctPool.length)];
      // A child who runs out of lives right after this tap still deserves
      // the companion's loudest celebration if it's a genuine all-time
      // record, not just the routine correct-tap chime.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((v) {
        if (mounted) setState(() => _best = v);
      });
      if (crossedBest) {
        _beatBest = true;
        _banner = 'New personal best! 🏆';
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_score >= _target) {
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        // The final correct tap used to jump straight to the win overlay in
        // the same frame, so the green tile flash above was set but never
        // actually rendered before the whole game view was replaced. Give it
        // the same 220ms beat as every other correct tap before declaring
        // the win, so the last answer is visibly confirmed too.
        Future.delayed(const Duration(milliseconds: 220), () {
          if (!mounted) return;
          setState(() => _status = GameStatus.won);
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        });
      } else {
        // Let the green flash above actually be seen before the tiles swap
        // out for the next round.
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted && _status == GameStatus.playing) {
            setState(_newRound);
          }
        });
      }
    } else {
      _wrong = i;
      _lives--;
      // Every wrong tap deserves the companion's gentle encouraging
      // reaction, not just the one that happens to end the game.
      emit(ExperienceEvent.incorrectAnswer);
      if (_lives <= 0) {
        _status = GameStatus.over;
        TonePlayer.instance.playCue(SoundCue.gameOver);
        _banner = 'Out of lives!';
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'Look again…';
        // Unlike every other miss-flash in the catalog (a brief ~350-500ms
        // highlight), this one was only ever cleared by the next correct
        // answer's _newRound() call — so a child who missed then paused (or
        // missed again without yet solving the round) saw the tile stuck red
        // indefinitely. Auto-clear it the same way weather_sort/shape_builder
        // do, gated so a later miss on a different tile can't be stomped by
        // a stale timer.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _wrong == i) setState(() => _wrong = -1);
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
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🥇 Bigger Number',
      introHow:
          'Read whether to find the biggest or the smallest number, then tap '
          'it. Twelve right to win!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Which one?  ·  ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '🥇',
      winText: _winPraise,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2A2412), Color(0xFF141006)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const Spacer(flex: 2),
              Text(
                _status == GameStatus.playing
                    ? (_biggest ? 'Tap the BIGGEST' : 'Tap the SMALLEST')
                    : 'Biggest or smallest?',
                style: const TextStyle(
                    color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  for (var i = 0; i < _nums.length; i++)
                    Semantics(
                      button: true,
                      label: 'Number ${_nums[i]}',
                      onTap: () => _tap(i),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => _tap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 92,
                          height: 110,
                          decoration: BoxDecoration(
                            color: _wrong == i
                                ? const Color(0xFFE23B3B)
                                : _correct == i
                                    ? const Color(0xFF80ED99)
                                    : Colors.white12,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text('${_nums[i]}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
