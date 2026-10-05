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
  const _CalmScene(this.feeling, this.healthy, this.other1, this.other2);
  final String feeling;
  final String healthy;
  final String other1;
  final String other2;
}

class _CalmChoicesGameState extends State<CalmChoicesGame> with _Emit {
  static const String _id = 'calm_choices';
  static const int _target = 10;
  static const List<_CalmScene> _scenes = <_CalmScene>[
    _CalmScene('When you feel angry…', 'Take slow deep breaths', 'Hit something', 'Yell at a friend'),
    _CalmScene('When you feel sad…', 'Talk to someone you trust', 'Keep it all inside', 'Stay alone all day'),
    _CalmScene('When you feel worried…', 'Think of a calm place', 'Worry even more', 'Panic'),
    _CalmScene('When you feel overwhelmed…', 'Take a little break', 'Do everything at once', 'Give up'),
    _CalmScene('When you feel scared…', 'Ask for a hug', 'Hide forever', "Pretend you're fine"),
    _CalmScene('When you feel frustrated…', 'Try again slowly', 'Break your things', 'Scream'),
    _CalmScene('When you feel very excited…', 'Take turns and share', 'Push to the front', 'Grab everything'),
    _CalmScene('When you feel tired…', 'Rest quietly', 'Keep pushing hard', 'Get grumpy at everyone'),
    _CalmScene('When your heart races…', 'Count to ten', 'Hold your breath', 'Run around wildly'),
    _CalmScene('When you need space…', 'Go to a quiet corner', 'Shout at people', 'Throw things'),
  ];
  final math.Random _rnd = math.Random();
  final List<int> _bag = <int>[];

  _CalmScene _scene = _scenes.first;
  List<String> _options = <String>[];
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

  int _drawScene() {
    // Shuffled bag with no immediate repeat: every scenario is shown once
    // before any repeats, so a full win covers all ten calm-down strategies.
    if (_bag.isEmpty) {
      _bag.addAll(List<int>.generate(_scenes.length, (i) => i)..shuffle(_rnd));
    }
    return _bag.removeLast();
  }

  void _newRound() {
    _wrong = -1;
    _scene = _scenes[_drawScene()];
    _options = <String>[_scene.healthy, _scene.other1, _scene.other2]..shuffle(_rnd);
  }

  void _pick(String choice, int idx) {
    if (_status != GameStatus.playing) return;
    if (choice == _scene.healthy) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.calm);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'That helps 💙';
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
      winText: 'Calm champion!',
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
  const _CalmOption({required this.text, required this.wrong, required this.onTap});
  final String text;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: wrong ? const Color(0xFFE23B3B) : Colors.white12,
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
    );
  }
}
