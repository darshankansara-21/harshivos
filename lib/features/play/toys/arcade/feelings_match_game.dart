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
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Feelings friend!" line on win screen.
  static const List<String> _winPraisePool = <String>[
    'Feelings friend!',
    'Emotion expert!',
    'Feelings genius!',
    'Ten right in a row!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  final List<int> _bag = <int>[];

  _Feeling _prompt = _feelings.first;
  List<_Feeling> _options = <_Feeling>[];
  int _score = 0;
  int _lives = 3;
  int _wrong = -1;
  // Unlike the wrong tap (which flashes red), a correct tap gave zero
  // tile-level feedback — the faces just silently swapped out for the next
  // round. Flash the tapped face green for a beat first, same convention.
  int _correct = -1;
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

  int _drawPrompt() {
    // Shuffled bag with no immediate repeat: every round across the whole
    // catalog of prompt-and-pick games draws from a bag (kindness_match,
    // weather_sort) rather than a raw random pick, which can otherwise hand
    // a child the exact same feeling two or three rounds in a row.
    if (_bag.isEmpty) {
      _bag.addAll(List<int>.generate(_feelings.length, (i) => i)..shuffle(_rnd));
    }
    return _bag.removeLast();
  }

  // Unlike every other sort/match game in the catalog (odd_one_out's grid,
  // shadow_match's option count), this one was a flat 3-face choice every
  // single round for all ten rounds with zero escalation. Widen the choice
  // set as the child progresses — up to all 8 faces by the final rounds —
  // so round 10 is a genuinely harder scan than round 1, not identical to it.
  int get _optionCount => (3 + _score ~/ 3).clamp(3, _feelings.length);

  void _newRound() {
    _wrong = -1;
    _correct = -1;
    _prompt = _feelings[_drawPrompt()];
    final count = _optionCount;
    final set = <_Feeling>{_prompt};
    while (set.length < count) {
      set.add(_feelings[_rnd.nextInt(_feelings.length)]);
    }
    _options = set.toList()..shuffle(_rnd);
  }

  void _pick(_Feeling f, int idx) {
    if (_status != GameStatus.playing) return;
    if (f.name == _prompt.name) {
      _score++;
      _correct = idx;
      TonePlayer.instance.playCue(SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      _banner = '${_prompt.face} ${_prompt.name}!';
      GameScores.instance.submit(_id, _score).then((v) {
        if (mounted) setState(() => _best = v);
      });
      if (_score >= _target) {
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        // The final correct tap used to jump straight to the win overlay in
        // the same frame, so the green face flash above was set but never
        // actually rendered before the whole game view was replaced. Give
        // it the same 220ms beat as every other correct tap before
        // declaring the win, so the last answer is visibly confirmed too.
        Future.delayed(const Duration(milliseconds: 220), () {
          if (!mounted) return;
          setState(() => _status = GameStatus.won);
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        });
      } else {
        // Let the green flash above actually be seen before the faces swap
        // out for the next round.
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted && _status == GameStatus.playing) {
            setState(_newRound);
          }
        });
      }
    } else {
      _wrong = idx;
      _lives--;
      // Every wrong tap deserves the companion's gentle encouraging
      // reaction, not just the one that happens to end the game.
      emit(ExperienceEvent.incorrectAnswer);
      if (_lives <= 0) {
        // The life-ending miss must sound distinct from a routine miss,
        // never just the same gentle-retry cue as every other wrong tap.
        _status = GameStatus.over;
        _banner = 'Out of lives!';
        TonePlayer.instance.playCue(SoundCue.gameOver);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'That one is ${f.name}. Try again!';
        // Momentary mistake cue, not a sticky state: auto-clear the red
        // highlight so a face doesn't stay flagged wrong indefinitely while
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
      title: '😊 Feelings Match',
      introHow:
          'Read the feeling word, then tap the face that shows it. Learn your '
          'feelings — ten right to win, with 3 💛 hearts so a few misses are okay!',
      onStart: () => setState(() {
        _bag.clear();
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
      winText: _winPraise,
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
                // A Wrap (not a fixed-width Row) so the growing option count
                // (up to 6 by the later rounds) never overflows a narrow
                // phone screen — it simply wraps to a second line instead.
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 14,
                  children: <Widget>[
                    for (var i = 0; i < _options.length; i++)
                      _FaceOption(
                        face: _options[i].face,
                        name: _options[i].name,
                        wrong: _wrong == i,
                        correct: _correct == i,
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
  const _FaceOption(
      {required this.face,
      required this.name,
      required this.wrong,
      required this.correct,
      required this.onTap});
  final String face;
  final String name;
  final bool wrong;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // This whole option was only a raw GestureDetector around a Text(face)
    // glyph — a blind child gets no indication these faces are tappable
    // buttons at all, and raw emoji alone (e.g. 😲 vs 😨) read inconsistently
    // across screen readers. Expose a named button; excludeSemantics stops
    // the inner emoji glyph from being separately (and redundantly) read.
    return Semantics(
      button: true,
      label: '$name face',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: wrong
                ? const Color(0xFFE23B3B)
                : correct
                    ? const Color(0xFF80ED99)
                    : Colors.white10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: wrong
                    ? const Color(0xFFE23B3B)
                    : correct
                        ? const Color(0xFF80ED99)
                        : Colors.white24,
                width: 2),
          ),
          alignment: Alignment.center,
          child: Text(face, style: const TextStyle(fontSize: 48)),
        ),
      ),
    );
  }
}
