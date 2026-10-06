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

  List<int> _tiles = <int>[];
  int _sum = 5;
  int _selected = -1;
  int _wrong = -1;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
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
    if (_status != GameStatus.playing) return;
    _wrong = -1;
    if (_selected == -1) {
      _selected = k;
    } else if (_selected == k) {
      _selected = -1;
    } else {
      if (_tiles[_selected] + _tiles[k] == _sum) {
        _score++;
        _tiles[_selected] = 1 + _rnd.nextInt(_maxVal);
        _tiles[k] = 1 + _rnd.nextInt(_maxVal);
        if (_tiles.length < _tileCount) {
          _tiles.add(1 + _rnd.nextInt(_maxVal));
        }
        _selected = -1;
        TonePlayer.instance.playCue(SoundCue.correct);
        emit(ExperienceEvent.bubblePopped);
        _banner = 'Correct!';
        GameScores.instance.submit(_id, _score).then((v) {
          if (mounted) setState(() => _best = v);
        });
        if (_score >= _target) {
          _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _newTarget();
        }
      } else {
        _wrong = k;
        _selected = -1;
        _lives--;
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
          'Ten correct sums to win!',
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
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const Spacer(flex: 2),
              Text('Make $_sum',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
              const Spacer(),
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
                        onTap: () => _tap(i),
                      ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
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
    required this.onTap,
  });
  final int value;
  final bool selected, wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = wrong
        ? const Color(0xFFE23B3B)
        : selected
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
          child: Text('$value',
              style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
