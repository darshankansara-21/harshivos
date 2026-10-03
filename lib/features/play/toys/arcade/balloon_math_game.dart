part of '../arcade_games.dart';

/// Balloon Math — solve the sum by tapping the balloon with the right answer.
/// Balloons drift up; addition then subtraction. Ten right to win.
class BalloonMathGame extends StatefulWidget {
  const BalloonMathGame({super.key});
  @override
  State<BalloonMathGame> createState() => _BalloonMathGameState();
}

class _Balloon {
  _Balloon(this.x, this.y, this.value, this.color, this.sway);
  double x, y;
  final int value;
  final Color color;
  final double sway;
}

class _BalloonMathGameState extends State<BalloonMathGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'balloon_math';
  static const int _target = 10;
  static const List<Color> _colors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
    Color(0xFFB197FC),
  ];
  final math.Random _rnd = math.Random();
  final List<_Balloon> _balloons = <_Balloon>[];
  final List<_Shard> _bits = <_Shard>[];
  int _a = 1, _b = 1;
  bool _sub = false;
  int _answer = 2;
  double _t = 0;
  int _score = 0;
  int _lives = 3;
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

  void _newProblem() {
    _sub = _score >= 5 && _rnd.nextBool();
    if (_sub) {
      _a = 2 + _rnd.nextInt(8);
      _b = 1 + _rnd.nextInt(_a);
      _answer = _a - _b;
    } else {
      _a = 1 + _rnd.nextInt(6);
      _b = 1 + _rnd.nextInt(6);
      _answer = _a + _b;
    }
    _balloons.clear();
    final values = <int>{_answer};
    while (values.length < 4) {
      final d = _answer + _rnd.nextInt(7) - 3;
      if (d >= 0 && d != _answer) values.add(d);
    }
    final vlist = values.toList()..shuffle(_rnd);
    for (var i = 0; i < vlist.length; i++) {
      _balloons.add(_Balloon(0.18 + i * 0.22, 0.6 + _rnd.nextDouble() * 0.5,
          vlist[i], _colors[i % _colors.length], _rnd.nextDouble() * math.pi * 2));
    }
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (final b in _balloons) {
      b.y -= dt * 0.12;
      b.x += math.sin(_t * 1.5 + b.sway) * dt * 0.02;
      if (b.y < -0.1) b.y = 1.1; // wrap, keep the answer in play
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
    }
  }

  void _tap(Offset p, double w, double h) {
    if (_status != GameStatus.playing) return;
    for (final b in _balloons) {
      if ((b.x - p.dx / w).abs() < 0.1 && (b.y - p.dy / h).abs() < 0.1) {
        if (b.value == _answer) {
          _score++;
          for (var i = 0; i < 14; i++) {
            final a = _rnd.nextDouble() * math.pi * 2;
            final sp = 0.15 + _rnd.nextDouble() * 0.35;
            _bits.add(_Shard(b.x, b.y, math.cos(a) * sp, math.sin(a) * sp, b.color));
          }
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.bubblePopped);
          _banner = 'Pop! $_a ${_sub ? '−' : '+'} $_b = $_answer';
          _bannerT = 1.2;
          GameScores.instance.submit(_id, _score).then((v) {
            if (mounted) setState(() => _best = v);
          });
          if (_score >= _target) {
            _status = GameStatus.won;
            TonePlayer.instance.playCue(SoundCue.gameStart);
            emit(ExperienceEvent.gameCompleted);
          } else {
            _newProblem();
          }
        } else {
          _lives--;
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
          _banner = 'Try again…';
          _bannerT = 1.0;
          if (_lives <= 0) _status = GameStatus.over;
        }
        setState(() {});
        return;
      }
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _newProblem();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎈 Balloon Math',
      introHow:
          'Work out the sum, then pop the balloon with the right answer before it floats away!',
      onStart: () => setState(() {
        _newProblem();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? '$_a ${_sub ? '−' : '+'} $_b = ?  · ${'💛' * _lives}',
      overEmoji: '🎈',
      overText: 'Math whiz!',
      accent: const Color(0xFFFF6B6B),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d.localPosition, w, h),
            child: CustomPaint(
              painter: _BalloonMathPainter(
                a: _a,
                b: _b,
                sub: _sub,
                balloons: _balloons,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BalloonMathPainter extends CustomPainter {
  _BalloonMathPainter({
    required this.a,
    required this.b,
    required this.sub,
    required this.balloons,
    required this.bits,
  });
  final int a, b;
  final bool sub;
  final List<_Balloon> balloons;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF9BD7F0), Color(0xFFD9F0FA)],
          ).createShader(Offset.zero & size));
    for (final b in balloons) {
      final c = Offset(b.x * w, b.y * h);
      canvas.drawLine(c, c + Offset(0, h * 0.06),
          Paint()..color = Colors.white70..strokeWidth = 1.5);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: w * 0.15, height: w * 0.18),
          Paint()..color = b.color);
      canvas.drawOval(
          Rect.fromCenter(
              center: c.translate(-w * 0.03, -w * 0.04),
              width: w * 0.04,
              height: w * 0.05),
          Paint()..color = Colors.white.withOpacity(0.5));
      final tp = TextPainter(
        text: TextSpan(
            text: '${b.value}',
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
    // Problem card.
    final card = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.12), width: w * 0.5, height: h * 0.1);
    canvas.drawRRect(RRect.fromRectAndRadius(card, const Radius.circular(14)),
        Paint()..color = Colors.white.withOpacity(0.9));
    final tp = TextPainter(
      text: TextSpan(
          text: '$a ${sub ? '−' : '+'} $b = ?',
          style: const TextStyle(
              color: Color(0xFF123050), fontSize: 30, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, card.center - Offset(tp.width / 2, tp.height / 2));
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 4 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_BalloonMathPainter old) => true;
}

