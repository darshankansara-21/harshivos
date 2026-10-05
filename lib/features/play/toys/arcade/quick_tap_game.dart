part of '../arcade_games.dart';

class QuickTapGame extends StatefulWidget {
  const QuickTapGame({super.key});
  @override
  State<QuickTapGame> createState() => _QuickTapGameState();
}

class _QuickTapGameState extends State<QuickTapGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'quick_tap';
  static const int _rounds = 5;
  final math.Random _rnd = math.Random();
  int _phase = 0; // 0 waiting(red) 1 go(green) 2 too-soon 3 result
  double _waitT = 0;
  double _reactT = 0;
  double _resultT = 0;
  double _flashT = 0;
  String _rating = '';
  int _round = 0;
  int _score = 0;
  int _best = 0;
  int _lastMs = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _startRound();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _startRound() {
    _phase = 0;
    _waitT = 0.9 + _rnd.nextDouble() * 2.2;
    _reactT = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_flashT > 0) _flashT -= dt;
    if (_phase == 0) {
      _waitT -= dt;
      if (_waitT <= 0) _phase = 1;
    } else if (_phase == 1) {
      _reactT += dt;
    } else if (_phase == 3) {
      _resultT -= dt;
      if (_resultT <= 0) _startRound();
    }
  }

  String _ratingFor(int ms) => ms < 250
      ? '⚡ Lightning!'
      : ms < 400
          ? 'Fast!'
          : ms < 600
              ? 'Nice'
              : 'Got it';

  void _tap() {
    if (_status != GameStatus.playing) return;
    if (_phase == 3) return; // result showing
    if (_phase == 2) {
      setState(_startRound);
      return;
    }
    if (_phase == 0) {
      _phase = 2; // tapped before green
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      setState(() {});
      return;
    }
    // Green — score by reaction speed.
    _lastMs = (_reactT * 1000).round();
    _rating = _ratingFor(_lastMs);
    _flashT = 0.3;
    final pts = math.max(5, 120 - _lastMs ~/ 10);
    _score += pts;
    _round++;
    TonePlayer.instance.playCue(SoundCue.correct);
    emit(ExperienceEvent.bubblePopped);
    if (_round >= _rounds) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
    } else {
      GameScores.instance.submit(_id, _score).then((b) {
        // Resolves after this frame's setState has already run, so updating
        // `_best` without triggering a rebuild left a new best silently
        // stale on screen until some unrelated later interaction repainted.
        if (mounted && b != _best) setState(() => _best = b);
      });
      _phase = 3;
      _resultT = 0.9;
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _round = 0;
      _score = 0;
      _lastMs = 0;
      _rating = '';
      _flashT = 0;
      _status = GameStatus.playing;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final Color bg = _phase == 1
        ? const Color(0xFF06D6A0)
        : _phase == 2
            ? const Color(0xFFF4A259)
            : _phase == 3
                ? const Color(0xFF118AB2)
                : const Color(0xFFC0392B);
    final String big = _phase == 1
        ? 'TAP!'
        : _phase == 2
            ? 'Too soon!'
            : _phase == 3
                ? '${_lastMs}ms'
                : 'Wait…';
    final String sub = _phase == 2
        ? 'Tap to try this round again'
        : _phase == 3
            ? _rating
            : _phase == 1
                ? 'Go go go!'
                : (_lastMs > 0
                    ? 'Last: ${_lastMs}ms · $_rating'
                    : 'Tap the moment it turns green');
    return _Shell(
      title: '⚡ Quick Tap',
      introHow: 'Wait for green, then tap fast! Never tap on red.',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _rounds,
      status: _status,
      banner: _lastMs > 0 ? 'Round $_round · ${_lastMs}ms' : 'Round ${_round + 1}',
      winEmoji: '⚡',
      winText: 'Fast fingers!',
      accent: Colors.white,
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          color: Color.lerp(
              bg, Colors.white, _flashT > 0 ? (_flashT / 0.3) * 0.5 : 0),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(big,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(sub,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Pinball — a gentle child's table: the ball falls under soft gravity, tap the
// left or right half to flip, bounce off the glowing bumpers to score, and use
// the flippers to keep the ball out of the centre drain. Three balls per game.
// ===========================================================================
