part of '../arcade_games.dart';

/// Feelings Match — read the feeling word and tap the face that shows it. A
/// gentle emotional-vocabulary game: eight feelings, three faces to choose from,
/// three lives. Ten right to win.
class FeelingsMatchGame extends StatefulWidget {
  const FeelingsMatchGame({super.key});
  @override
  State<FeelingsMatchGame> createState() => _FeelingsMatchGameState();
}

class _Feeling {
  const _Feeling(this.name, this.face);
  final String name;
  final String face;
}

class _FeelingsMatchGameState extends State<FeelingsMatchGame> with _Emit {
  static const String _id = 'feelings_match';
  static const int _target = 10;
  static const List<_Feeling> _feelings = <_Feeling>[
    _Feeling('Happy', '😄'),
    _Feeling('Sad', '😢'),
    _Feeling('Angry', '😠'),
    _Feeling('Scared', '😨'),
    _Feeling('Surprised', '😲'),
    _Feeling('Sleepy', '😴'),
    _Feeling('Silly', '😜'),
    _Feeling('Loving', '🥰'),
  ];
  final math.Random _rnd = math.Random();

  _Feeling _prompt = _feelings.first;
  List<_Feeling> _options = <_Feeling>[];
  int _score = 0;
  int _lives = 3;
  int _wrong = -1;
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

  void _newRound() {
    _wrong = -1;
    _prompt = _feelings[_rnd.nextInt(_feelings.length)];
    final set = <_Feeling>{_prompt};
    while (set.length < 3) {
      set.add(_feelings[_rnd.nextInt(_feelings.length)]);
    }
    _options = set.toList()..shuffle(_rnd);
  }

  void _pick(_Feeling f, int idx) {
    if (_status != GameStatus.playing) return;
    if (f.name == _prompt.name) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      _banner = '${_prompt.face} ${_prompt.name}!';
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
        // The life-ending miss must sound distinct from a routine miss,
        // never just the same gentle-retry cue as every other wrong tap.
        _status = GameStatus.over;
        _banner = 'Out of lives!';
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'That one is ${f.name}. Try again!';
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
      title: '😊 Feelings Match',
      introHow:
          'Read the feeling word, then tap the face that shows it. Learn your '
          'feelings — ten right to win!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Find the feeling  ·  ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '😊',
      winText: 'Feelings friend!',
      accent: const Color(0xFFFFB5E8),
      onPlayAgain: _reset,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2A2140), Color(0xFF15111F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Spacer(flex: 2),
              Text(
                _status == GameStatus.playing ? _prompt.name : 'Feelings',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text('Which face feels like this?',
                  style: TextStyle(color: Colors.white60, fontSize: 16)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    for (var i = 0; i < _options.length; i++)
                      _FaceOption(
                        face: _options[i].face,
                        wrong: _wrong == i,
                        onTap: () => _pick(_options[i], i),
                      ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceOption extends StatelessWidget {
  const _FaceOption({required this.face, required this.wrong, required this.onTap});
  final String face;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: wrong ? const Color(0xFFE23B3B) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: wrong ? const Color(0xFFE23B3B) : Colors.white24, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(face, style: const TextStyle(fontSize: 48)),
      ),
    );
  }
}
