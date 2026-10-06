part of '../arcade_games.dart';

/// Add It Up — tap two number tiles that add up to the target. Get it right and
/// fresh numbers appear; a wrong pair costs a life. Ten correct sums to win.
class AddItUpGame extends StatefulWidget {
  const AddItUpGame({super.key});
  @override
  State<AddItUpGame> createState() => _AddItUpGameState();
}

class _AddItUpGameState extends State<AddItUpGame> with _Emit {
  static const String _id = 'add_it_up';
  static const int _target = 10;
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Great maths!', 'Number whiz!', 'Sum master!', 'Math star!',
  ];
  String _winPraise = _winPraisePool[0];
  // Every correct tap routinely flashed the exact same "Correct!" banner
  // (up to ten times in one round); vary it like the win-screen praise.
  static const List<String> _correctPool = <String>[
    'Correct!', 'Nice sum!', 'That adds up!', 'Spot on!',
  ];

  List<int> _tiles = <int>[];
  int _sum = 5;
  int _selected = -1;
  int _wrong = -1;
  // Same gap as bigger_number: a wrong pair flashes red, but a correct pair
  // gave zero tile-level feedback — the two tiles just silently swapped out
  // for fresh numbers. Flash both tapped tiles green for a beat first.
  int _correctA = -1;
  int _correctB = -1;
  // A correct tap left the board fully tappable for the 220ms confirm beat
  // below (win or round-advance), so a fast extra tap during that window
  // could lose the last life and flip the status to GameStatus.over —
  // only for the already-queued delayed callback to then force it back to
  // GameStatus.won (or silently deal fresh tiles into an ended game) a
  // beat later. Lock input for that one beat, same convention as
  // weather_sort_game's `_locked`.
  bool _locked = false;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  bool _beatBest = false;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  // Difficulty escalates with score across the WHOLE 10-round game: tiles
  // start small (1-5) and six wide, climbing to bigger numbers (up to 1-23)
  // and up to nine tiles only by the final round. The old formula capped
  // both at round 5, leaving the back half of the game completely flat —
  // round 10 must feel harder than round 5, not identical to it.
  int get _maxVal => (5 + _score * 2).clamp(5, 23);
  int get _tileCount => (6 + _score ~/ 3).clamp(6, 9);

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _deal() {
    _tiles = List<int>.generate(_tileCount, (_) => 1 + _rnd.nextInt(_maxVal));
    _selected = -1;
    _wrong = -1;
    _correctA = -1;
    _correctB = -1;
    _locked = false;
    _newTarget();
  }

  void _newTarget() {
    // Pick two distinct tiles so a solution always exists.
    final i = _rnd.nextInt(_tiles.length);
    var j = _rnd.nextInt(_tiles.length);
    while (j == i) {
      j = _rnd.nextInt(_tiles.length);
    }
    _sum = _tiles[i] + _tiles[j];
  }

  void _tap(int k) {
    if (_status != GameStatus.playing || _locked) return;
    _wrong = -1;
    if (_selected == -1) {
      _selected = k;
    } else if (_selected == k) {
      _selected = -1;
    } else {
      if (_tiles[_selected] + _tiles[k] == _sum) {
        _score++;
        final a = _selected, b = k;
        _correctA = a;
        _correctB = b;
        _locked = true;
        _selected = -1;
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
          // The final correct tap used to jump straight to the win overlay
          // in the same frame, so the green tile flash above was set but
          // never actually rendered before the whole game view was
          // replaced. Give it the same 220ms beat as every other correct
          // tap before declaring the win, so the last pair is visibly
          // confirmed too.
          Future.delayed(const Duration(milliseconds: 220), () {
            if (!mounted) return;
            setState(() => _status = GameStatus.won);
            TonePlayer.instance.playCue(SoundCue.gameStart);
            emit(ExperienceEvent.gameCompleted);
          });
        } else {
          // Let the green flash above actually be seen before the two
          // tiles silently swap out for fresh numbers.
          Future.delayed(const Duration(milliseconds: 220), () {
            if (!mounted || _status != GameStatus.playing) return;
            setState(() {
              _tiles[a] = 1 + _rnd.nextInt(_maxVal);
              _tiles[b] = 1 + _rnd.nextInt(_maxVal);
              if (_tiles.length < _tileCount) {
                _tiles.add(1 + _rnd.nextInt(_maxVal));
              }
              _correctA = -1;
              _correctB = -1;
              _locked = false;
              _newTarget();
            });
          });
        }
      } else {
        _wrong = k;
        _selected = -1;
        _lives--;
        // Every wrong pair deserves the companion's gentle encouraging
        // reaction, not just the one that happens to end the game.
        emit(ExperienceEvent.incorrectAnswer);
        if (_lives <= 0) {
          // The life-ending miss must sound distinct from a routine miss,
          // never just the same gentle-retry cue as every other wrong pair.
          _status = GameStatus.over;
          _banner = 'Out of lives!';
          TonePlayer.instance.playCue(SoundCue.gameOver);
          emit(ExperienceEvent.incorrectAnswer);
        } else {
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
          _banner = 'Not quite — try again';
        }
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
      _deal();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '➕ Add It Up',
      introHow:
          'Tap two number tiles that add up to the target number at the top. '
          'Ten correct sums to win — you have 3 💛 hearts, so a few wrong '
          'guesses are okay!',
      onStart: () => setState(() {
        _deal();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Find two that make it  ·  ${'💛' * _lives}',
      overEmoji: '💔',
      overText: 'Out of lives — nice try!',
      winEmoji: '➕',
      winText: _winPraise,
      accent: const Color(0xFF80ED99),
      onPlayAgain: _reset,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF123524), Color(0xFF0A1A12)],
          ),
        ),
        // Same bug class `_overlayScroll` fixed for `BiggerNumberGame`: the
        // original `Spacer`-based Column assumed the title Text would always
        // fit, which overflowed by 193px at `TextScaler.linear(2.5)` since
        // `Spacer`s squeeze to zero while the scaled Text keeps growing.
        // Reuse `_overlayScroll` with a fixed gap instead.
        child: SafeArea(
          child: _overlayScroll(Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Make $_sum',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
              const SizedBox(height: 56),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    for (var i = 0; i < _tiles.length; i++)
                      _NumberTile(
                        value: _tiles[i],
                        selected: _selected == i,
                        wrong: _wrong == i,
                        correct: _correctA == i || _correctB == i,
                        onTap: () => _tap(i),
                      ),
                  ],
                ),
              ),
            ],
          )),
        ),
      ),
    );
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({
    required this.value,
    required this.selected,
    required this.wrong,
    required this.correct,
    required this.onTap,
  });
  final int value;
  final bool selected, wrong, correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = wrong
        ? const Color(0xFFE23B3B)
        : (selected || correct)
            ? const Color(0xFF80ED99)
            : Colors.white10;
    return Semantics(
      button: true,
      label: selected ? 'Number $value. Selected.' : 'Number $value',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          alignment: Alignment.center,
          // Fixed 86px tile but a scaled Text — FittedBox keeps a 2-digit
          // sum from silently clipping at large accessibility text scale,
          // same convention as `BiggerNumberGame`'s number tiles.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$value',
                style: TextStyle(
                    color: (selected || correct) ? Colors.black : Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}
