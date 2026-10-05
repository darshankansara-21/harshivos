part of '../arcade_games.dart';

/// Balance Ball — drag left or right to tilt the beam and keep the ball from
/// rolling off either end. The beam wobbles more as time passes. Stay balanced
/// for twenty seconds to win.
class BalanceBallGame extends StatefulWidget {
  const BalanceBallGame({super.key});
  @override
  State<BalanceBallGame> createState() => _BalanceBallGameState();
}

class _BalanceBallGameState extends State<BalanceBallGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'balance_ball';
  static const int _target = 20; // seconds to survive

  double _t = 0;
  double _tilt = 0; // player target tilt
  double _beam = 0; // actual beam angle
  double _s = 0; // ball position along beam (-1..1)
  double _v = 0;
  bool _dragging = false;
  int _score = 0, _best = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (!_dragging) _tilt *= (1 - 2.5 * dt).clamp(0.0, 1.0);
    // Wobble grows slowly with time.
    final wobble = (0.04 + _t * 0.004) * math.sin(_t * 2.3) +
        (0.02 + _t * 0.002) * math.sin(_t * 5.1 + 1);
    _beam += ((_tilt + wobble) - _beam) * 8 * dt;
    _v += -math.sin(_beam) * 2.4 * dt;
    _v *= (1 - 0.6 * dt);
    _s += _v * dt;
    if (_s.abs() > 1.0) {
      _status = GameStatus.over;
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
      setState(() {});
      return;
    }
    final sec = _t.floor();
    if (sec > _score) {
      _score = sec.clamp(0, _target);
      if (_score % 5 == 0) TonePlayer.instance.playCue(SoundCue.coin);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _t = 0;
      _tilt = 0;
      _beam = 0;
      _s = 0;
      _v = 0;
      _score = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '⚖️ Balance Ball',
      introHow:
          'Drag left or right to tilt the beam and keep the ball from rolling '
          'off. Stay balanced for twenty seconds to win!',
      onStart: () => setState(() {
        _t = 0;
        _s = 0;
        _v = 0;
        _beam = 0;
        _tilt = 0;
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: 'Keep it centred  ·  ${_score}s',
      overEmoji: '⚖️',
      overText: 'It rolled off!',
      accent: const Color(0xFF48CAE4),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              _dragging = true;
              _tilt = ((d.localPosition.dx / w) - 0.5) * 1.1;
            },
            onPanUpdate: (d) {
              _dragging = true;
              _tilt = (((d.localPosition.dx / w) - 0.5) * 1.1).clamp(-0.5, 0.5);
            },
            onPanEnd: (_) => _dragging = false,
            child: CustomPaint(
              painter: _BalanceBallPainter(beam: _beam, s: _s),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BalanceBallPainter extends CustomPainter {
  _BalanceBallPainter({required this.beam, required this.s});
  final double beam, s;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF12222E), Color(0xFF0A141C)],
          ).createShader(Offset.zero & size));

    final cx = w / 2, cy = h * 0.55;
    final half = w * 0.4;
    final dx = math.cos(beam) * half, dy = math.sin(beam) * half;
    final left = Offset(cx - dx, cy - dy), right = Offset(cx + dx, cy + dy);

    // Pivot.
    final pivot = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx - w * 0.06, cy + h * 0.14)
      ..lineTo(cx + w * 0.06, cy + h * 0.14)
      ..close();
    canvas.drawPath(pivot, Paint()..color = const Color(0xFF5C7C9E));

    // Beam.
    canvas.drawLine(
        left,
        right,
        Paint()
          ..color = const Color(0xFF9AB4CC)
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);

    // Ball on the beam at position s.
    final bx = cx + math.cos(beam) * half * s;
    final by = cy + math.sin(beam) * half * s;
    final nx = -math.sin(beam), ny = math.cos(beam); // normal (up from beam)
    final ballC = Offset(bx + nx * 20, by - ny.abs() * 20);
    canvas.drawCircle(ballC, 18,
        Paint()..color = s.abs() > 0.7 ? const Color(0xFFE23B3B) : const Color(0xFF48CAE4));
    canvas.drawCircle(ballC + const Offset(-5, -5), 5,
        Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(_BalanceBallPainter oldDelegate) => true;
}
