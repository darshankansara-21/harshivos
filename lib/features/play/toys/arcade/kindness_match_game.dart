part of '../arcade_games.dart';

/// Kindness Match — read what happens, then tap the kind thing to say or do.
/// A gentle social game that builds caring responses. Three lives, ten kind
/// choices to win.
class KindnessMatchGame extends StatefulWidget {
  const KindnessMatchGame({super.key});
  @override
  State<KindnessMatchGame> createState() => _KindnessMatchGameState();
}

class _KindScene {
  const _KindScene(this.situation, this.kind, this.other1, this.other2);
  final String situation;
  final String kind;
  final String other1;
  final String other2;
}

class _KindnessMatchGameState extends State<KindnessMatchGame> with _Emit {
  static const String _id = 'kindness_match';
  static const int _target = 10;
  static const List<_KindScene> _scenes = <_KindScene>[
    _KindScene('Your friend falls down.', 'Are you okay?', "You're silly", 'Go away'),
    _KindScene('Someone is new at school.', 'Want to play with us?', "That's my spot", "You can't sit here"),
    _KindScene('Your friend looks sad.', "I'm here for you", 'Stop crying', "That's boring"),
    _KindScene('Someone drops their books.', 'Let me help you', 'Watch out!', 'So clumsy!'),
    _KindScene('A friend shares their toy.', 'Thank you so much!', 'I want more', "It's mine now"),
    _KindScene('Someone makes a mistake.', "It's okay, try again", "You're bad at this", 'Ha ha ha'),
    _KindScene('Your friend wins a game.', 'Well done!', 'No fair', 'You cheated'),
    _KindScene('Someone feels left out.', 'Come join us!', 'Not you', 'Go away'),
    _KindScene('A friend is scared.', "I'll stay with you", "Don't be a baby", 'Scaredy cat'),
    _KindScene('Someone is tired.', 'Have a rest', 'Keep going', 'Too slow'),
  ];
  final math.Random _rnd = math.Random();

  _KindScene _scene = _scenes.first;
  List<String> _options = <String>[];
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
    _scene = _scenes[_rnd.nextInt(_scenes.length)];
    _options = <String>[_scene.kind, _scene.other1, _scene.other2]..shuffle(_rnd);
  }

  void _pick(String choice, int idx) {
    if (_status != GameStatus.playing) return;
    if (choice == _scene.kind) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'That was kind 💛';
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
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = 'That might hurt feelings. Try a kind one.';
      if (_lives <= 0) _status = GameStatus.over;
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
      title: '💛 Kindness Match',
      introHow:
          'Read what happens, then tap the kind thing to say or do. Ten kind '
          'choices to win!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Choose kindness  ·  ${'💛' * _lives}',
      overEmoji: '💛',
      overText: 'Kind friend!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF3A2E12), Color(0xFF1C1608)],
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
                    _status == GameStatus.playing ? _scene.situation : 'Choose kindness',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                for (var i = 0; i < _options.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: _KindOption(
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

class _KindOption extends StatelessWidget {
  const _KindOption({required this.text, required this.wrong, required this.onTap});
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
