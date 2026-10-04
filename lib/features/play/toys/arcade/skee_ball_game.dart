part of '../arcade_games.dart';

/// Skee Ball — drag up and release to roll the ball up the ramp. The further it
/// reaches, the better the ring it lands in. Build up 100 points to win.
class SkeeBallGame extends StatefulWidget {
  const SkeeBallGame({super.key});
  @override
  State<SkeeBallGame> createState() => _SkeeBallGameState();
}

class _SkeeBallGameState extends State<SkeeBallGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'skee_ball';
  static const int _target = 100;

  double _ballY = 0.86;
  double _targetY = 0.86;
  bool _rolling = false;
  bool _dragging = false;
  double _power = 0;
  double _startY = 0;
  int _score = 0, _best = 0;
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

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_rolling) {
      final dir = _targetY - _ballY;
      _ballY += dir * 6 * dt;
      if ((_targetY - _ballY).abs() < 0.01) {
        _ballY = _targetY;
        _resolve();
      }
    }
    setState(() {});
  }

  void _resolve() {
    _rolling = false;
    int pts;
    String label;
    if (_targetY < 0.2) {
      pts = 50;
      label = 'Bullseye! +50';
    } else if (_targetY < 0.33) {
      pts = 30;
      label = '+30';
    } else if (_targetY < 0.46) {
      pts = 20;
      label = '+20';
    } else if (_targetY < 0.72) {
      pts = 10;
      label = '+10';
    } else {
      pts = 0;
      label = 'Gutter!';
    }
    if (pts > 0) {
      _score += pts;
      TonePlayer.instance.playCue(pts >= 30 ? SoundCue.success : SoundCue.coin);
      emit(ExperienceEvent.bubblePopped);
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
    }
    _banner = label;
    _bannerT = 1.1;
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
    if (_score >= _target) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else {
      _ballY = 0.86;
    }
  }

  void _launch() {
    _targetY = (0.86 - _power * 1.05).clamp(0.08, 0.86);
    _rolling = true;
    TonePlayer.instance.playCue(SoundCue.ball);
  }

  void _reset() {
    setState(() {
      _score = 0;
      _ballY = 0.86;
      _rolling = false;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎳 Skee Ball',
      introHow:
          'Drag up and let go to roll the ball up the ramp. Aim for the top '
          'ring for the most points. Reach 100 to win!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? (_dragging ? 'Power: ${(_power * 100).round()}%' : 'Drag up to roll'),
      overEmoji: '🎳',
      overText: 'Nice rolling!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              if (_rolling) return;
              _dragging = true;
              _startY = d.localPosition.dy;
              _power = 0;
            },
            onPanUpdate: (d) {
              if (_rolling || !_dragging) return;
              _power = ((_startY - d.localPosition.dy) / h).clamp(0.0, 1.0);
              setState(() {});
            },
            onPanEnd: (_) {
              if (_rolling || !_dragging) return;
              _dragging = false;
              if (_power > 0.05) _launch();
            },
            child: CustomPaint(
              painter: _SkeeBallPainter(
                  ballY: _ballY, power: _dragging ? _power : 0),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _SkeeBallPainter extends CustomPainter {
  _SkeeBallPainter({required this.ballY, required this.power});
  final double ballY, power;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2A1E12), Color(0xFF150E08)],
          ).createShader(Offset.zero & size));

    // Ramp.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.32, h * 0.06, w * 0.36, h * 0.86),
            const Radius.circular(20)),
        Paint()..color = const Color(0xFF6B4A2A));

    // Scoring rings.
    final rings = <List<double>>[
      <double>[0.14, 0.09, 50],
      <double>[0.26, 0.12, 30],
      <double>[0.39, 0.14, 20],
      <double>[0.58, 0.16, 10],
    ];
    const cols = <Color>[
      Color(0xFFFF5DA2), Color(0xFFFFD166), Color(0xFF80ED99), Color(0xFF48CAE4),
    ];
    for (var i = 0; i < rings.length; i++) {
      canvas.drawCircle(
          Offset(w * 0.5, h * rings[i][0]),
          w * rings[i][1],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = cols[i]);
    }

    // Power meter at the left.
    if (power > 0) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.08, h * 0.9 - h * 0.8 * power, w * 0.05, h * 0.8 * power),
              const Radius.circular(6)),
          Paint()..color = Color.lerp(const Color(0xFF80ED99), const Color(0xFFE63946), power)!);
    }

    // Ball.
    canvas.drawCircle(Offset(w * 0.5, ballY * h), w * 0.05,
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.5 - w * 0.015, ballY * h - w * 0.015), w * 0.015,
        Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(_SkeeBallPainter oldDelegate) => true;
}
