part of '../arcade_games.dart';

/// Balloon Bounce — tap the balloon to bop it back up before it touches the
/// floor. It drifts and speeds up a little with every bounce. Keep it up for
/// twenty bounces to win.
class BalloonBounceGame extends StatefulWidget {
  const BalloonBounceGame({super.key});
  @override
  State<BalloonBounceGame> createState() => _BalloonBounceGameState();
}

class _BalloonBounceGameState extends State<BalloonBounceGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'balloon_bounce';
  static const int _target = 20;
  static const double _r = 0.1;
  final math.Random _rnd = math.Random();

  double _x = 0.5, _y = 0.4, _vx = 0.1, _vy = 0;
  int _score = 0, _best = 0;
  double _squash = 0;
  Color _color = const Color(0xFFFF5DA2);
  String? _banner;
  GameStatus _status = GameStatus.ready;

  static const List<Color> _colors = <Color>[
    Color(0xFFFF5DA2), Color(0xFF48CAE4), Color(0xFF80ED99),
    Color(0xFFFFD166), Color(0xFF9B5DE5),
  ];

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _launch() {
    _x = 0.5;
    _y = 0.4;
    _vx = (_rnd.nextDouble() - 0.5) * 0.3;
    _vy = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_squash > 0) _squash -= dt * 3;
    // Gravity ramps up gently as the streak grows, so bounce 20 genuinely
    // demands quicker reflexes than bounce 1 instead of feeling identical.
    final gravity = 0.5 + (_score / _target).clamp(0.0, 1.0) * 0.45;
    _vy += gravity * dt;
    _x += _vx * dt;
    _y += _vy * dt;
    if (_x < _r || _x > 1 - _r) {
      _vx = -_vx;
      _x = _x.clamp(_r, 1 - _r);
    }
    if (_y < _r) {
      _y = _r;
      _vy = _vy.abs() * 0.5;
    }
    if (_y > 1 - _r * 0.4) {
      // The balloon touching the floor ends the round — it must not be
      // silent; play a distinct game-over cue, same as every other game's
      // terminal loss branch.
      _status = GameStatus.over;
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
    }
    setState(() {});
  }

  void _tapAt(double nx, double ny) {
    if (_status != GameStatus.playing) return;
    if ((nx - _x).abs() < _r * 1.4 && (ny - _y).abs() < _r * 1.4) {
      _vy = -0.78;
      _vx += (_x - nx) * 1.6; // bop away from the finger
      _vx = _vx.clamp(-0.6, 0.6);
      _squash = 0.3;
      _score++;
      TonePlayer.instance.playCue(SoundCue.balloon);
      emit(ExperienceEvent.bubblePopped);
      _color = _colors[_score % _colors.length];
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      }
      setState(() {});
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _banner = null;
      _launch();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎈 Balloon Bounce',
      introHow:
          'Tap the balloon to bop it up before it reaches the floor. Keep it '
          'up for twenty bounces to win!',
      onStart: () => setState(() {
        _launch();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Keep it up!  ·  $_score/$_target',
      overEmoji: '🎈',
      overText: 'It floated down!',
      winEmoji: '🏆',
      winText: 'Bounce champion!',
      accent: const Color(0xFFFF5DA2),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) =>
                    _tapAt(d.localPosition.dx / w, d.localPosition.dy / h),
                child: CustomPaint(
                  painter: _BalloonBouncePainter(
                      x: _x, y: _y, r: _r, squash: _squash.clamp(0.0, 1.0), color: _color),
                  size: Size.infinite,
                ),
              ),
              // Screen-reader overlay tracking the balloon's live position
              // (it drifts/bounces continuously), like bug_catch/count_pop.
              Positioned(
                left: (_x - _r * 1.4) * w,
                top: (_y - _r * 1.4) * h,
                width: _r * 2.8 * w,
                height: _r * 2.8 * h,
                child: Semantics(
                  label: 'Balloon',
                  button: true,
                  onTap: () => _tapAt(_x, _y),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BalloonBouncePainter extends CustomPainter {
  _BalloonBouncePainter({
    required this.x,
    required this.y,
    required this.r,
    required this.squash,
    required this.color,
  });
  final double x, y, r, squash;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF8ECAE6), Color(0xFFBDE0FE)],
          ).createShader(Offset.zero & size));

    // Floor line.
    canvas.drawRect(Rect.fromLTWH(0, h * 0.97, w, h * 0.03),
        Paint()..color = const Color(0xFF52B788));

    final c = Offset(x * w, y * h);
    final rw = r * w * (1 + squash * 0.25);
    final rh = r * h * (1 - squash * 0.25);
    // String.
    canvas.drawLine(Offset(c.dx, c.dy + rh), Offset(c.dx, c.dy + rh + 24),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5);
    // Balloon body.
    canvas.drawOval(
        Rect.fromCenter(center: c, width: rw * 2, height: rh * 2),
        Paint()..color = color);
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(-rw * 0.3, -rh * 0.35),
            width: rw * 0.7,
            height: rh * 0.5),
        Paint()..color = Colors.white.withOpacity(0.4));
    // Knot.
    final knot = Path()
      ..moveTo(c.dx - 5, c.dy + rh)
      ..lineTo(c.dx + 5, c.dy + rh)
      ..lineTo(c.dx, c.dy + rh + 7)
      ..close();
    canvas.drawPath(knot, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BalloonBouncePainter oldDelegate) => true;
}
