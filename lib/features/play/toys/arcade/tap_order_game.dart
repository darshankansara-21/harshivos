part of '../arcade_games.dart';

class TapOrderGame extends StatefulWidget {
  const TapOrderGame({super.key});
  @override
  State<TapOrderGame> createState() => _TapOrderGameState();
}

class _TapOrderGameState extends State<TapOrderGame> with _Emit {
  static const String _id = 'tap_order';
  final math.Random _rnd = math.Random();
  late List<int> _cells; // number shown at each of the 25 cells
  int _next = 1;
  int _score = 0;
  int _round = 1;
  int _best = 0;
  String? _banner;
  int _wrongCell = -1;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _shuffle();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _shuffle() {
    _cells = List<int>.generate(25, (i) => i + 1)..shuffle(_rnd);
    _next = 1;
  }

  void _tap(int cell) {
    if (_status != GameStatus.playing) return;
    if (_cells[cell] == _next) {
      _score++;
      _next++;
      TonePlayer.instance.playNote(_next % 10, seconds: 0.16);
      emit(ExperienceEvent.bubblePopped);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) setState(() => _best = b);
      });
      if (_next > 25) {
        _round++;
        _banner = 'Round $_round!';
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
        setState(_shuffle);
      } else {
        setState(() {});
      }
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      setState(() => _wrongCell = cell);
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _wrongCell = -1);
      });
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _round = 1;
      _banner = null;
      _status = GameStatus.playing;
      _shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔢 Tap Order',
      introHow: 'Tap the numbers in order — 1, 2, 3… as fast as you can!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF10233A), Color(0xFF0A1626)],
          ),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 116),
            Text('Tap $_next',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var i = 0; i < 25; i++)
                      GestureDetector(
                        onTapDown: (_) => _tap(i),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('tap-$i-${_cells[i] < _next}'),
                          tween: Tween<double>(
                              begin: _cells[i] < _next ? 1.25 : 1.0, end: 1.0),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          builder: (c, s, child) =>
                              Transform.scale(scale: s, child: child),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _wrongCell == i
                                  ? const Color(0xFFEF476F)
                                  : _cells[i] < _next
                                      ? const Color(0xFF06D6A0).withOpacity(0.3)
                                      : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _cells[i] < _next ? '' : '${_cells[i]}',
                                maxLines: 1,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
// Piano Tiles — tap the falling tiles in their column before they slip past the
// bottom. Each tap plays a note so a melody builds; it speeds up as you go.
// ===========================================================================
