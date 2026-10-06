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
  const _KindScene(this.situation, this.kind, this.other1, this.other2, this.other3);
  final String situation;
  final String kind;
  final String other1;
  final String other2;
  // Third distractor, only shown once the active option count grows past 3
  // (see _optionCount) — keeps later rounds genuinely harder than early ones.
  final String other3;
}

class _KindnessMatchGameState extends State<KindnessMatchGame> with _Emit {
  static const String _id = 'kindness_match';
  static const int _target = 10;
  static const List<_KindScene> _scenes = <_KindScene>[
    _KindScene('Your friend falls down.', 'Are you okay?', "You're silly", 'Go away', 'Clumsy!'),
    _KindScene('Someone is new at school.', 'Want to play with us?', "That's my spot", "You can't sit here", 'Not my friend'),
    _KindScene('Your friend looks sad.', "I'm here for you", 'Stop crying', "That's boring", 'So dramatic'),
    _KindScene('Someone drops their books.', 'Let me help you', 'Watch out!', 'So clumsy!', 'Not my problem'),
    _KindScene('A friend shares their toy.', 'Thank you so much!', 'I want more', "It's mine now", 'Give me that'),
    _KindScene('Someone makes a mistake.', "It's okay, try again", "You're bad at this", 'Ha ha ha', 'You always mess up'),
    _KindScene('Your friend wins a game.', 'Well done!', 'No fair', 'You cheated', "I'm still better"),
    _KindScene('Someone feels left out.', 'Come join us!', 'Not you', 'Go away', 'Find your own group'),
    _KindScene('A friend is scared.', "I'll stay with you", "Don't be a baby", 'Scaredy cat', 'Just get over it'),
    _KindScene('Someone is tired.', 'Have a rest', 'Keep going', 'Too slow', "Don't be lazy"),
  ];
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Kind friend!',
    'Kindness champion!',
    'So thoughtful!',
    'Big heart!',
  ];
  String _winPraise = _winPraisePool.first;
  String _overPraise = _gentleTryAgainPool[0];
  // Every kind choice routinely flashed the exact same "That was kind 💛"
  // banner (up to ten times in one round); vary it like the win praise.
  static const List<String> _kindPool = <String>[
    'That was kind 💛', 'Kind choice!', 'So thoughtful!', 'Good heart!',
  ];
  final List<int> _bag = <int>[];

  _KindScene _scene = _scenes.first;
  List<String> _options = <String>[];
  int _score = 0;
  int _lives = 3;
  int _wrong = -1;
  // Unlike the wrong tap (which flashes red), a kind tap gave zero
  // tile-level feedback — the options just silently swapped for the next
  // scene. Flash the tapped option green for a beat first, same convention.
  int _correct = -1;
  int _best = 0;
  bool _beatBest = false;
  // A correct pick left the options fully tappable for the 220ms confirm
  // beat below (win or round-advance), so a fast extra tap during that
  // window could lose the last life and flip the status to
  // GameStatus.over — only for the already-queued delayed callback to then
  // force it back to GameStatus.won a beat later. Lock input for that one
  // beat, same convention as weather_sort_game's `_locked`.
  bool _locked = false;
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
    // before any repeats, so a full win sees all ten kindness lessons.
    if (_bag.isEmpty) {
      _bag.addAll(List<int>.generate(_scenes.length, (i) => i)..shuffle(_rnd));
    }
    return _bag.removeLast();
  }

  // Real difficulty curve: the first few rounds offer only 3 choices (1 kind
  // + 2 unkind), then from the halfway point on a 3rd unkind distractor
  // joins the mix, so late rounds are genuinely harder to tell apart than
  // round 1 instead of every round being identically easy.
  int get _optionCount => (3 + _score ~/ 5).clamp(3, 4);

  void _newRound() {
    _wrong = -1;
    _correct = -1;
    _locked = false;
    _scene = _scenes[_drawScene()];
    final List<String> distractors = <String>[_scene.other1, _scene.other2, _scene.other3]
      ..shuffle(_rnd);
    _options = <String>[_scene.kind, ...distractors.take(_optionCount - 1)]..shuffle(_rnd);
  }

  void _pick(String choice, int idx) {
    if (_status != GameStatus.playing || _locked) return;
    if (choice == _scene.kind) {
      _score++;
      _correct = idx;
      _locked = true;
      TonePlayer.instance.playCue(SoundCue.correct);
      emit(ExperienceEvent.bubblePopped);
      _banner = _kindPool[_rnd.nextInt(_kindPool.length)];
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
        // the same frame, so the green option flash above was set but
        // never actually rendered before the whole game view was replaced.
        // Give it the same 220ms beat as every other correct tap before
        // declaring the win, so the last choice is visibly confirmed too.
        Future.delayed(const Duration(milliseconds: 220), () {
          if (!mounted) return;
          setState(() => _status = GameStatus.won);
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        });
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
      // Every wrong choice deserves the companion's gentle encouraging
      // reaction, not just the one that happens to end the game.
      emit(ExperienceEvent.incorrectAnswer);
      if (_lives <= 0) {
        // The life-ending wrong choice must sound distinct from a routine
        // miss, never just the same gentle-retry cue as every other one.
        _status = GameStatus.over;
        _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
        _banner = 'Out of lives!';
        TonePlayer.instance.playCue(SoundCue.gameOver);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'That might hurt feelings. Try a kind one.';
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
      _beatBest = false;
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
      title: '💛 Kindness Match',
      introHow:
          'Read what happens, then tap the kind thing to say or do. Ten kind '
          'choices to win — you have 3 💛 hearts, so a few wrong guesses are okay!',
      onStart: () => setState(() {
        _bag.clear();
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Choose kindness  ·  ${'💛' * _lives}',
      overEmoji: '💪',
      overText: _overPraise,
      winEmoji: '💛',
      winText: _winPraise,
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
            // Same bug class `_overlayScroll` fixed for `BiggerNumberGame`:
            // the `Spacer`-based Column overflowed by 72px at
            // `TextScaler.linear(2.5)` since `Spacer`s squeeze to zero while
            // the scaled prompt Text and option list kept growing.
            child: _overlayScroll(Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 28),
                for (var i = 0; i < _options.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: _KindOption(
                      text: _options[i],
                      wrong: _wrong == i,
                      correct: _correct == i,
                      onTap: () => _pick(_options[i], i),
                    ),
                  ),
              ],
            )),
          ),
        ),
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({required this.text, required this.wrong, required this.correct, required this.onTap});
  final String text;
  final bool wrong;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A bare GestureDetector exposes no tap action to screen readers, so
    // without this overlay the option reads as inert static text. The label
    // is simply the option's own words — it never reveals which option is
    // the kind one, preserving the real choice for screen-reader users.
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
