part of '../arcade_games.dart';

/// Calm Choices — read how you feel, then pick a healthy way to handle it. A
/// gentle self-regulation game that practises calm-down strategies. Three lives,
/// ten calm choices to win.
class CalmChoicesGame extends StatefulWidget {
  const CalmChoicesGame({super.key});
  @override
  State<CalmChoicesGame> createState() => _CalmChoicesGameState();
}

class _CalmScene {
  const _CalmScene(this.feeling, this.healthy, this.other1, this.other2, this.other3);
  final String feeling;
  final String healthy;
  final String other1;
  final String other2;
  // Third distractor, only shown once the active option count grows past 3
  // (see _optionCount) — keeps later rounds genuinely harder than early
  // ones, the same pattern KindnessMatchGame already uses.
  final String other3;
}

class _CalmChoicesGameState extends State<CalmChoicesGame> with _Emit {
  static const String _id = 'calm_choices';
  static const int _target = 10;
  static const List<_CalmScene> _scenes = <_CalmScene>[
    _CalmScene('When you feel angry…', 'Take slow deep breaths', 'Hit something', 'Yell at a friend', 'Slam the door'),
    _CalmScene('When you feel sad…', 'Talk to someone you trust', 'Keep it all inside', 'Stay alone all day', 'Pretend you feel fine'),
    _CalmScene('When you feel worried…', 'Think of a calm place', 'Worry even more', 'Panic', 'Imagine the worst'),
    _CalmScene('When you feel overwhelmed…', 'Take a little break', 'Do everything at once', 'Give up', 'Rush through it all'),
    _CalmScene('When you feel scared…', 'Ask for a hug', 'Hide forever', "Pretend you're fine", 'Freeze up'),
    _CalmScene('When you feel frustrated…', 'Try again slowly', 'Break your things', 'Scream', 'Storm off'),
    _CalmScene('When you feel very excited…', 'Take turns and share', 'Push to the front', 'Grab everything', 'Interrupt everyone'),
    _CalmScene('When you feel tired…', 'Rest quietly', 'Keep pushing hard', 'Get grumpy at everyone', 'Skip resting'),
    _CalmScene('When your heart races…', 'Count to ten', 'Hold your breath', 'Run around wildly', 'Clench your fists'),
    _CalmScene('When you need space…', 'Go to a quiet corner', 'Shout at people', 'Throw things', 'Push past everyone'),
  ];
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Calm champion!" line on win screen.
  static const List<String> _winPraisePool = <String>[
    'Calm champion!',
    'Healthy-choices hero!',
    'Calm and in control!',
    'Ten calm choices!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  // Every healthy choice routinely flashed the exact same "That helps 💙"
  // banner (up to ten times in one round); vary it like the win praise.
  static const List<String> _helpsPool = <String>[
    'That helps 💙', 'Good choice!', 'Calm choice!', 'Nice pick!',
  ];
  final List<int> _bag = <int>[];

  _CalmScene _scene = _scenes.first;
  List<String> _options = <String>[];
  int _score = 0, _lives = 3, _best = 0;
  int _wrong = -1;
  // Unlike the wrong tap (which flashes red), a calm tap gave zero
  // tile-level feedback — the options just silently swapped for the next
  // scene. Flash the tapped option green for a beat first, same convention.
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

  int _drawScene() {
    // Shuffled bag with no immediate repeat: every scenario is shown once
    // before any repeats, so a full win covers all ten calm-down strategies.
    if (_bag.isEmpty) {
      _bag.addAll(List<int>.generate(_scenes.length, (i) => i)..shuffle(_rnd));
    }
    return _bag.removeLast();
  }

  // Real difficulty curve: the first few rounds offer only 3 choices (1
  // healthy + 2 unhealthy), then from the halfway point on a 3rd unhealthy
  // distractor joins the mix, so late rounds are genuinely harder to tell
  // apart than round 1 instead of every round being identically easy —
  // the same pattern KindnessMatchGame already uses.
  int get _optionCount => (3 + _score ~/ 5).clamp(3, 4);

  void _newRound() {
    _wrong = -1;
    _correct = -1;
    _scene = _scenes[_drawScene()];
    final List<String> distractors = <String>[_scene.other1, _scene.other2, _scene.other3]
      ..shuffle(_rnd);
    _options = <String>[_scene.healthy, ...distractors.take(_optionCount - 1)]..shuffle(_rnd);
  }

  void _pick(String choice, int idx) {
    if (_status != GameStatus.playing) return;
    if (choice == _scene.healthy) {
      _score++;
      _correct = idx;
      TonePlayer.instance.playCue(SoundCue.calm);
      emit(ExperienceEvent.bubblePopped);
      _banner = _helpsPool[_rnd.nextInt(_helpsPool.length)];
      GameScores.instance.submit(_id, _score).then((v) {
        if (mounted) setState(() => _best = v);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        // Let the green flash above actually be seen before the options
        // swap out for the next scene.
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted && _status == GameStatus.playing) {
            setState(_newRound);
          }
        });
      }
    } else {
      _wrong = idx;
      _lives--;
      if (_lives <= 0) {
        // The life-ending wrong choice must sound distinct from a routine
        // miss, never just the same gentle-retry cue as every other one.
        _status = GameStatus.over;
        _banner = 'Out of lives!';
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'That might make it harder. Try a calm one.';
        // Momentary mistake cue, not a sticky state: auto-clear the red
        // highlight so a tile doesn't stay flagged wrong indefinitely while
        // the child keeps trying this same round.
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && _wrong == idx) setState(() => _wrong = -1);
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
      _bag.clear();
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🌈 Calm Choices',
      introHow:
          'Read how you feel, then tap a healthy way to handle it. Ten calm '
          'choices to win!',
      onStart: () => setState(() {
        _bag.clear();
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Choose what helps  ·  ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '🌈',
      winText: _winPraise,
      accent: const Color(0xFF89F7FE),
      onPlayAgain: _reset,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF123038), Color(0xFF081418)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 150, 22, 24),
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _status == GameStatus.playing ? _scene.feeling : 'Choose what helps',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                for (var i = 0; i < _options.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: _CalmOption(
                      text: _options[i],
                      wrong: _wrong == i,
                      correct: _correct == i,
                      onTap: () => _pick(_options[i], i),
                    ),
                  ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalmOption extends StatelessWidget {
  const _CalmOption({required this.text, required this.wrong, required this.correct, required this.onTap});
  final String text;
  final bool wrong;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: wrong
                ? const Color(0xFFE23B3B)
                : correct
                    ? const Color(0xFF80ED99)
                    : Colors.white12,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
