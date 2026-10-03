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
  final math.Random _rnd = math.Random();
  List<_MCard> _cards = <_MCard>[];
  int _first = -1;
  int _second = -1;
  double _hideT = 0;
  int _level = 1;
  int _streak = 0;
  int _score = 0;
  int _best = 0;
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
    setState(() {
      card.up = true;
      if (_first == -1) {
        _first = i;
        TonePlayer.instance.playClick();
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
          GameScores.instance.submit(_id, _score).then((b) {
            if (mounted) setState(() => _best = b);
          });
          if (_cards.every((c) => c.matched)) {
            if (_level >= _target) {
              _status = GameStatus.won;
              TonePlayer.instance.playCue(SoundCue.gameStart);
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
          TonePlayer.instance.playThock();
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _level = 1;
      _streak = 0;
      _score = 0;
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
    final cols = _cards.length <= 8 ? 4 : (_cards.length <= 12 ? 4 : 5);
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
      target: _target * 1000,
      status: _status,
      banner: _banner ?? 'Level $_level · find the pairs',
      overEmoji: '🧠',
      overText: 'Memory master!',
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
              GestureDetector(
                onTap: () => _flip(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cards[i].matched
                        ? const Color(0xFF3A5A4A)
                        : (_cards[i].up
                            ? Colors.white
                            : const Color(0xFF4A3A6E)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _cards[i].up || _cards[i].matched ? _cards[i].emoji : '',
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

