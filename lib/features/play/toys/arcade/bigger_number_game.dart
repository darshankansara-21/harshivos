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
  final math.Random _rnd = math.Random();

  List<int> _nums = <int>[2, 5, 8];
  bool _biggest = true;
  int _score = 0, _lives = 3, _best = 0;
  int _wrong = -1;
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
      TonePlayer.instance.playCue(SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Correct!';
      GameScores.instance.submit(_id, _score).then((v) {
        if (mounted) setState(() => _best = v);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrong = i;
      _lives--;
      if (_lives <= 0) {
        _status = GameStatus.over;
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
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
      winText: 'Number star!',
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
                    GestureDetector(
                      onTap: () => _tap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 92,
                        height: 110,
                        decoration: BoxDecoration(
                          color: _wrong == i ? const Color(0xFFE23B3B) : Colors.white12,
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
