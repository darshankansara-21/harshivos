part of '../arcade_games.dart';

/// Memory Pairs Deluxe — flip cards to find matching pairs. A streak multiplier
/// rewards quick matches; the board grows each level. Clear four levels to win.
class MemoryPairsDeluxeGame extends StatefulWidget {
  const MemoryPairsDeluxeGame({super.key});
  @override
  State<MemoryPairsDeluxeGame> createState() => _MemoryPairsDeluxeGameState();
}

class _MCard {
  _MCard(this.emoji);
  final String emoji;
  bool up = false;
  bool matched = false;
}

class _MemoryPairsDeluxeGameState extends State<MemoryPairsDeluxeGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'memory_deluxe';
  static const int _target = 4; // levels to win
  static const List<String> _pool = <String>[
    '🐶', '🐱', '🦊', '🐻', '🐼', '🐸', '🐵', '🦁', '🐯', '🦄', '🐙', '🦉'
  ];
  // Spoken names for the pool above — a screen reader can't rely on the raw
  // emoji glyph alone (it reads inconsistently/ambiguously across
  // TalkBack/VoiceOver), same pattern established in `memory_flip_game.dart`.
  static const Map<String, String> _faceNames = <String, String>{
    '🐶': 'dog',
    '🐱': 'cat',
    '🦊': 'fox',
    '🐻': 'bear',
    '🐼': 'panda',
    '🐸': 'frog',
    '🐵': 'monkey',
    '🦁': 'lion',
    '🐯': 'tiger',
    '🦄': 'unicorn',
    '🐙': 'octopus',
    '🦉': 'owl',
  };
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Memory master!',
    'Perfect recall!',
    'Pair champion!',
    'Sharp memory!',
  ];
  String _winPraise = _winPraisePool.first;
  List<_MCard> _cards = <_MCard>[];
  int _first = -1;
  int _second = -1;
  double _hideT = 0;
  int _level = 1;
  int _streak = 0;
  int _score = 0;
  int _best = 0;
  bool _beatBest = false;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _deal() {
    final pairs = (2 + _level).clamp(3, 8);
    final picks = (_pool.toList()..shuffle(_rnd)).take(pairs).toList();
    _cards = <_MCard>[];
    for (final e in picks) {
      _cards.add(_MCard(e));
      _cards.add(_MCard(e));
    }
    _cards.shuffle(_rnd);
    _first = -1;
    _second = -1;
    _hideT = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_hideT > 0) {
      _hideT -= dt;
      if (_hideT <= 0) {
        if (_first >= 0) _cards[_first].up = false;
        if (_second >= 0) _cards[_second].up = false;
        _first = -1;
        _second = -1;
        _streak = 0;
      }
    }
  }

  void _flip(int i) {
    if (_status != GameStatus.playing || _hideT > 0) return;
    final card = _cards[i];
    if (card.up || card.matched) return;
    // A card flip is a flat paper/cardboard tile, not a mechanical fidget
    // switch — use the dedicated `paper` grain cue (same fix already applied
    // to `memory_flip_game.dart`) instead of the generic `playClick` thock so
    // the sound actually matches what's drawn, and so this deluxe sibling
    // doesn't sound unrelated to the base memory game.
    TonePlayer.instance.playCue(SoundCue.paper);
    setState(() {
      card.up = true;
      if (_first == -1) {
        _first = i;
      } else {
        _second = i;
        if (_cards[_first].emoji == card.emoji) {
          _cards[_first].matched = true;
          card.matched = true;
          _streak++;
          _score += 10 * _streak;
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.bubblePopped);
          _banner = _streak >= 2 ? 'Match! Streak x$_streak 🔥' : 'Match!';
          _bannerT = 1.0;
          _first = -1;
          _second = -1;
          // The streak multiplier makes every playthrough's final score
          // genuinely open-ended, exactly the shape the catalog already
          // celebrates mid-run with a "New personal best!" banner elsewhere
          // (piano_tiles/ball_sort/bubble_wrap/stack/etc.) — this was the
          // one remaining streak-scored game that tracked `_best` only to
          // display it, never to celebrate actually beating it.
          final crossedBest = _score > _best && !_beatBest && _best > 0;
          GameScores.instance.submit(_id, _score).then((b) {
            if (mounted) setState(() => _best = b);
          });
          if (crossedBest) {
            _beatBest = true;
            _banner = 'New personal best! 🏆';
            _bannerT = 1.2;
            TonePlayer.instance.playCue(SoundCue.milestone);
            emit(ExperienceEvent.personalBest);
          }
          if (_cards.every((c) => c.matched)) {
            if (_level >= _target) {
              _status = GameStatus.won;
              _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
              // `gameStart` is the cue for beginning a run, not winning one —
              // it was firing at the exact moment of victory, the opposite of
              // what a child hears. `success` is the catalog's established
              // win-moment cue (same one `memory_flip_game.dart` uses).
              TonePlayer.instance.playCue(SoundCue.success);
              emit(ExperienceEvent.gameCompleted);
            } else {
              _level++;
              _banner = 'Level $_level!';
              _bannerT = 1.2;
              _deal();
            }
          }
        } else {
          _hideT = 0.8;
          // Matches the rest of the catalog's gentle wrong-answer cue
          // (`gentleRetry`) instead of the generic fidget-toy `thock`, which
          // read as a harsh mechanical buzz rather than an encouraging retry.
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
          emit(ExperienceEvent.incorrectAnswer);
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _level = 1;
      _streak = 0;
      _score = 0;
      _beatBest = false;
      _banner = null;
      _bannerT = 0;
      _deal();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    if (_cards.isEmpty) _deal();
    // Pick a column count that evenly divides the card count so every level
    // renders a clean rectangle instead of a dangling, uneven last row (the
    // old fixed `<=8 ? 4 : ...` thresholds left level 1's 6 cards and level
    // 3's 10 cards as a half-empty final row of 2 in a 4-column grid).
    final cols = _cards.length <= 6
        ? 3
        : (_cards.length <= 8
            ? 4
            : (_cards.length <= 10 ? 5 : 4));
    return _Shell(
      title: '🧠 Memory Pairs Deluxe',
      introHow:
          'Flip two cards to find a matching pair. Match quickly to build a streak for bonus points!',
      onStart: () => setState(() {
        _deal();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      // No fake target fraction here: the real win condition is clearing
      // `_target` levels, not reaching any particular point total, so a
      // `score / target` header (previously `score / (_target * 1000)`)
      // showed a fabricated denominator that never matched real progress.
      // The "Level $_level" banner below already carries the true signal.
      status: _status,
      banner: _banner ?? 'Level $_level/$_target · find the pairs',
      winEmoji: '🧠',
      winText: _winPraise,
      accent: const Color(0xFFB197FC),
      onPlayAgain: _reset,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            for (var i = 0; i < _cards.length; i++)
              Builder(builder: (context) {
                final c = _cards[i];
                // Only describe what is CURRENTLY visible on this exact
                // card — never the hidden identity of a face-down card —
                // so a screen-reader user faces the same memory challenge
                // (remember what you've already seen flipped) as a
                // sighted child, not an easier one.
                final name = _faceNames[c.emoji] ?? 'card';
                final label = c.matched
                    ? 'Matched $name card'
                    : c.up
                        ? '$name card'
                        : 'Hidden card';
                return Semantics(
                  button: true,
                  label: label,
                  onTap: () => _flip(i),
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => _flip(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.matched
                            ? const Color(0xFF3A5A4A)
                            : (c.up ? Colors.white : const Color(0xFF4A3A6E)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          c.up || c.matched ? c.emoji : '',
                          maxLines: 1,
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

