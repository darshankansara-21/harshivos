part of '../arcade_games.dart';

/// Hoop Toss — the peg slides back and forth; tap to toss the ring and time it
/// so the peg is under the ring when it lands. The peg speeds up as you score.
/// Ring it ten times to win; five misses ends the game.
class HoopTossGame extends StatefulWidget {
  const HoopTossGame({super.key});
  @override
  State<HoopTossGame> createState() => _HoopTossGameState();
}

class _HoopTossGameState extends State<HoopTossGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'hoop_toss';
  static const int _target = 10;
  static const double _pegY = 0.3;

  double _t = 0;
  double _pegX = 0.5;
  double _ringY = 0.86;
  bool _flying = false;
  int _score = 0, _misses = 0, _best = 0;
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

  double get _speed => 1.7 + _score * 0.13;
  double get _catch => (0.1 - _score * 0.004).clamp(0.05, 0.1);

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _pegX = 0.5 + 0.36 * math.sin(_t * _speed);
    if (_flying) {
      _ringY -= 1.15 * dt;
      if (_ringY <= _pegY) _resolve();
    }
    setState(() {});
  }

  void _resolve() {
    _flying = false;
    _ringY = 0.86;
    if ((_pegX - 0.5).abs() < _catch) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Ringer!  🎯';
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
      _misses++;
      if (_misses >= 5) {
        // The game-ending miss must sound distinct from a routine miss,
        // never just the same gentle-retry cue as every other near-miss.
        _status = GameStatus.over;
        _banner = 'Out of rings!';
        _bannerT = 1.2;
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'Just missed!';
        _bannerT = 1.1;
      }
    }
  }

  void _toss() {
    if (_status != GameStatus.playing || _flying) return;
    _flying = true;
    _ringY = 0.86;
    TonePlayer.instance.playCue(SoundCue.wood);
  }

  void _reset() {
    setState(() {
      _score = 0;
      _misses = 0;
      _t = 0;
      _flying = false;
      _ringY = 0.86;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎪 Hoop Toss',
      introHow:
          'Tap to toss the ring and time it so the sliding peg is right under '
          'it. Ring it ten times to win!',
      onStart: () => setState(() {
        _t = 0;
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Ringers $_score/$_target  ·  ${'⭕' * (5 - _misses)}',
      overEmoji: '💪',
      overText: 'Out of rings — nice try!',
      winEmoji: '🎪',
      winText: 'Good tosses!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _toss(),
        child: CustomPaint(
          painter: _HoopTossPainter(pegX: _pegX, pegY: _pegY, ringY: _ringY, flying: _flying),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _HoopTossPainter extends CustomPainter {
  _HoopTossPainter({
    required this.pegX,
    required this.pegY,
    required this.ringY,
    required this.flying,
  });
  final double pegX, pegY, ringY;
  final bool flying;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF3A2A5E), Color(0xFF1C1430)],
          ).createShader(Offset.zero & size));

    // Peg + base.
    final px = pegX * w, py = pegY * h;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(px, py + h * 0.03), width: w * 0.05, height: h * 0.12),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFBC6C25));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py + h * 0.1), width: w * 0.16, height: h * 0.03),
        Paint()..color = const Color(0xFF8A4F18));

    // Ring.
    final ry = (flying ? ringY : 0.86) * h;
    canvas.drawCircle(
        Offset(w * 0.5, ry),
        w * 0.075,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0xFF48CAE4));
    canvas.drawCircle(
        Offset(w * 0.5, ry),
        w * 0.075,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white70);
  }

  @override
  bool shouldRepaint(_HoopTossPainter oldDelegate) => true;
}
