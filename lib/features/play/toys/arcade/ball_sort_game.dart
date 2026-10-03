part of '../arcade_games.dart';

class BallSortGame extends StatefulWidget {
  const BallSortGame({super.key});
  @override
  State<BallSortGame> createState() => _BallSortGameState();
}

class _BallSortGameState extends State<BallSortGame> with _Emit {
  static const String _id = 'ball_sort';
  static const int _cap = 4;
  static const List<Color> _colorsPal = <Color>[
    Color(0xFFEF476F), Color(0xFFFFD166), Color(0xFF06D6A0),
    Color(0xFF4CC9F0), Color(0xFF9B5DE5), Color(0xFFFF9E00),
  ];
  final math.Random _rnd = math.Random();
  late List<List<int>> _tubes;
  int _selected = -1;
  int _level = 0;
  int _colorsN = 3;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _deal();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _deal() {
    _colorsN = math.min(6, 3 + _level ~/ 2);
    _tubes = List<List<int>>.generate(_colorsN + 2, (_) => <int>[]);
    final balls = <int>[];
    for (var c = 0; c < _colorsN; c++) {
      for (var k = 0; k < _cap; k++) {
        balls.add(c);
      }
    }
    balls.shuffle(_rnd);
    var idx = 0;
    for (var t = 0; t < _colorsN; t++) {
      for (var k = 0; k < _cap; k++) {
        _tubes[t].add(balls[idx++]);
      }
    }
    _selected = -1;
  }

  bool _solved() {
    for (final t in _tubes) {
      if (t.isEmpty) continue;
      if (t.length != _cap || t.any((c) => c != t.first)) return false;
    }
    return true;
  }

  void _tapTube(int i) {
    if (_status != GameStatus.playing) return;
    if (_selected == -1) {
      if (_tubes[i].isNotEmpty) setState(() => _selected = i);
      return;
    }
    if (_selected == i) {
      setState(() => _selected = -1);
      return;
    }
    final from = _tubes[_selected];
    final to = _tubes[i];
    final ball = from.isNotEmpty ? from.last : -1;
    if (ball != -1 && to.length < _cap && (to.isEmpty || to.last == ball)) {
      setState(() {
        from.removeLast();
        to.add(ball);
        _selected = -1;
      });
      TonePlayer.instance.playCue(SoundCue.water);
      if (_solved()) {
        _score++;
        _level++;
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        _banner = 'Level $_level!';
        setState(_deal);
      }
    } else {
      setState(() => _selected = _tubes[i].isNotEmpty ? i : -1);
    }
  }

  void _reset() {
    setState(() {
      _level = 0;
      _score = 0;
      _banner = null;
      _status = GameStatus.playing;
      _deal();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🧪 Ball Sort',
      introHow: 'Tap a tube, then another, to pour. Sort each colour together!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF06D6A0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1A2036), Color(0xFF0E1424)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 40),
            child: FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (var i = 0; i < _tubes.length; i++) _tube(i),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tube(int i) {
    const ball = 34.0;
    final t = _tubes[i];
    final selected = _selected == i;
    return GestureDetector(
      onTap: () => _tapTube(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, selected ? -16 : 0, 0),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10), bottom: Radius.circular(28)),
          border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2.5 : 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var s = _cap - 1; s >= 0; s--)
              TweenAnimationBuilder<double>(
                key: ValueKey('bs-$i-$s-${s < t.length ? t[s] : -1}'),
                tween: Tween<double>(
                    begin: s < t.length ? 1.3 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (ctx, sc, child) =>
                    Transform.scale(scale: sc, child: child),
                child: Container(
                  width: ball,
                  height: ball,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s < t.length
                        ? _colorsPal[t[s]]
                        : Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Tap Order — a Schulte grid. Numbers 1–25 are scattered; tap them in order as
// fast as you can. A classic attention / visual-search trainer that's calm and
// forgiving: a wrong tap just gives a gentle nudge, never ends the game.
// ===========================================================================
