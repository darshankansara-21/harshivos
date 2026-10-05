part of '../arcade_games.dart';

/// Penalty Dash — a striker marker and the keeper both slide along the goal.
/// Tap to shoot the instant the marker is clear of the keeper and inside the
/// posts. It all speeds up as you score. Ten goals to win, five misses is over.
class PenaltyDashGame extends StatefulWidget {
  const PenaltyDashGame({super.key});
  @override
  State<PenaltyDashGame> createState() => _PenaltyDashGameState();
}

class _PenaltyDashGameState extends State<PenaltyDashGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'penalty_dash';
  static const int _target = 10;

  double _t = 0;
  double _marker = 0.5;
  double _keeper = 0.5;
  int _score = 0, _misses = 0, _best = 0;
  double _flashX = -1, _flashT = 0;
  bool _flashGoal = false;
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

  double get _speed => 1.6 + _score * 0.12;

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_flashT > 0) _flashT -= dt;
    _marker = 0.5 + 0.38 * math.sin(_t * _speed);
    _keeper = 0.5 + 0.30 * math.sin(_t * _speed * 0.8 + 1.7);
    setState(() {});
  }

  void _shoot() {
    if (_status != GameStatus.playing) return;
    _flashX = _marker;
    _flashT = 0.5;
    final inPosts = _marker > 0.17 && _marker < 0.83;
    final beatsKeeper = (_marker - _keeper).abs() > 0.14;
    if (inPosts && beatsKeeper) {
      _flashGoal = true;
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'GOAL!  ⚽';
      _bannerT = 1.1;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      }
    } else {
      _flashGoal = false;
      _misses++;
      if (_misses >= 5) {
        // The game-ending miss must sound distinct from a routine miss,
        // never just the same gentle-retry cue as every other shot.
        _status = GameStatus.over;
        _banner = 'Out of shots!';
        _bannerT = 1.1;
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = inPosts ? 'Saved!' : 'Wide!';
        _bannerT = 1.1;
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _misses = 0;
      _t = 0;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🥅 Penalty Dash',
      introHow:
          'Tap to shoot when the striker marker is clear of the keeper and '
          'between the posts. Ten goals to win!',
      onStart: () => setState(() {
        _t = 0;
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Goals $_score/$_target  ·  ${'🧤' * (5 - _misses)}',
      overEmoji: '💪',
      overText: 'Out of shots — nice try!',
      winEmoji: '🥅',
      winText: 'Ten goals! You won the shootout!',
      accent: const Color(0xFF80ED99),
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _shoot(),
        child: CustomPaint(
          painter: _PenaltyDashPainter(
            marker: _marker,
            keeper: _keeper,
            flashX: _flashT > 0 ? _flashX : -1,
            flashGoal: _flashGoal,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PenaltyDashPainter extends CustomPainter {
  _PenaltyDashPainter({
    required this.marker,
    required this.keeper,
    required this.flashX,
    required this.flashGoal,
  });
  final double marker, keeper, flashX;
  final bool flashGoal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2E7D32), Color(0xFF1B5E20)],
          ).createShader(Offset.zero & size));

    final gy = h * 0.3;
    final goalL = w * 0.17, goalR = w * 0.83;
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(goalL, gy), Offset(goalL, gy - h * 0.14), post);
    canvas.drawLine(Offset(goalR, gy), Offset(goalR, gy - h * 0.14), post);
    canvas.drawLine(Offset(goalL, gy - h * 0.14), Offset(goalR, gy - h * 0.14), post);

    // Keeper.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(keeper * w, gy - h * 0.05),
                width: w * 0.12,
                height: h * 0.09),
            const Radius.circular(10)),
        Paint()..color = const Color(0xFFFFD166));

    // Striker meter at the bottom.
    final my = h * 0.82;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.1, my - 8, w * 0.8, 16),
            const Radius.circular(8)),
        Paint()..color = Colors.black26);
    canvas.drawCircle(Offset(marker * w, my), 14,
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(marker * w, my), 7,
        Paint()..color = const Color(0xFF222222));

    // Shot flash.
    if (flashX >= 0) {
      canvas.drawLine(
          Offset(flashX * w, my),
          Offset(flashX * w, gy),
          Paint()
            ..color = (flashGoal ? const Color(0xFF80ED99) : const Color(0xFFE23B3B))
                .withOpacity(0.8)
            ..strokeWidth = 4);
    }
  }

  @override
  bool shouldRepaint(_PenaltyDashPainter oldDelegate) => true;
}
