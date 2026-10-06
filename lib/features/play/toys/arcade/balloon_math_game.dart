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
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Math whiz!" line on win screen.
  static const List<String> _winPraisePool = <String>[
    'Math whiz!',
    'Number ninja!',
    'Sum solver supreme!',
    'Perfect ten!',
  ];
  String _winPraise = _winPraisePool[0];
  String _overPraise = _gentleTryAgainPool[0];
  final math.Random _rnd = math.Random();
  final List<_Balloon> _balloons = <_Balloon>[];
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  int _a = 1, _b = 1;
  bool _sub = false;
  int _answer = 2;
  double _t = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  bool _beatBest = false;
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
    // Challenge curve: unlike target_toss's ring speed or count_pop's rising
    // count floor, this drift speed was a flat 0.12 for all 10 rounds — round
    // 9 never felt any more urgent than round 1. Ramp it gently with score so
    // reading the sum/difference genuinely gets harder to keep up with as the
    // child approaches the win target, same escalation convention the rest
    // of the catalog already uses.
    final driftSpeed = 0.12 + (_score / _target) * 0.09;
    for (final b in _balloons) {
      b.y -= dt * driftSpeed;
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
    // Hit-test in pixel space: the balloon's drawn size is scaled entirely
    // by width (painter uses `w * 0.15` / `w * 0.18` for both axes), so the
    // tap-forgiveness box must also be width-calibrated on both axes —
    // comparing against a height-normalized y-threshold would silently
    // stretch the vertical hit zone on any non-square (portrait) screen.
    for (final b in _balloons) {
      final dx = p.dx - b.x * w;
      final dy = p.dy - b.y * h;
      if (dx.abs() < w * 0.1 && dy.abs() < w * 0.12) {
        if (b.value == _answer) {
          _score++;
          final bitCount = _reduceMotion ? 4 : 14;
          for (var i = 0; i < bitCount; i++) {
            final a = _rnd.nextDouble() * math.pi * 2;
            final sp = 0.15 + _rnd.nextDouble() * 0.35;
            _bits.add(_Shard(b.x, b.y, math.cos(a) * sp, math.sin(a) * sp, b.color));
          }
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.bubblePopped);
          _banner = 'Pop! $_a ${_sub ? '−' : '+'} $_b = $_answer';
          _bannerT = 1.2;
          // A child who runs out of lives right after this pop still
          // deserves the companion's loudest celebration if it's a genuine
          // all-time record, not just the routine correct-pop chime.
          final crossedBest = _score > _best && !_beatBest && _best > 0;
          GameScores.instance.submit(_id, _score).then((v) {
            if (mounted) setState(() => _best = v);
          });
          if (crossedBest) {
            _beatBest = true;
            _banner = 'New personal best! 🏆';
            _bannerT = 1.2;
            TonePlayer.instance.playCue(SoundCue.milestone);
            emit(ExperienceEvent.personalBest);
          }
          if (_score >= _target) {
            _status = GameStatus.won;
            _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
            TonePlayer.instance.playCue(SoundCue.gameStart);
            emit(ExperienceEvent.gameCompleted);
          } else {
            _newProblem();
          }
        } else {
          _lives--;
          // Every wrong pop deserves the companion's gentle encouraging
          // reaction, not just the one that happens to end the game.
          emit(ExperienceEvent.incorrectAnswer);
          if (_lives <= 0) {
            // The life-ending miss must sound distinct from a routine miss,
            // never just the same gentle-retry cue as every other pop.
            _status = GameStatus.over;
            _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
            _banner = 'Out of lives!';
            _bannerT = 1.2;
            TonePlayer.instance.playCue(SoundCue.gameOver);
            emit(ExperienceEvent.incorrectAnswer);
          } else {
            TonePlayer.instance.playCue(SoundCue.gentleRetry);
            _banner = 'Try again…';
            _bannerT = 1.0;
          }
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
      _beatBest = false;
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
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '🎈 Balloon Math',
      introHow:
          'Work out the sum, then pop the balloon with the right answer before it floats away! '
          'A wrong pop costs one of your 3 lives.',
      onStart: () => setState(() {
        _newProblem();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? '$_a ${_sub ? '−' : '+'} $_b = ?  · ${'💛' * _lives}',
      overEmoji: '💪',
      overText: _overPraise,
      winEmoji: '🎈',
      winText: _winPraise,
      accent: const Color(0xFFFF6B6B),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return Stack(
            children: <Widget>[
              GestureDetector(
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
              ),
              // Each balloon's number is painted only onto the canvas and
              // keeps drifting upward, so a screen-reader user had no way to
              // discover the answer choices at all. These invisible
              // Semantics overlays track the balloons' live positions every
              // tick (the widget already rebuilds each frame via ToyTicker)
              // so TalkBack/VoiceOver can find and activate the correct
              // floating number, mirroring the fix already applied to
              // dot_to_dot/firefly_count's fixed-position choices.
              for (final bln in _balloons)
                Positioned(
                  left: bln.x * w - w * 0.1,
                  top: bln.y * h - w * 0.12,
                  width: w * 0.2,
                  height: w * 0.24,
                  child: Semantics(
                    label: 'Balloon ${bln.value}',
                    button: true,
                    onTap: () => _tap(Offset(bln.x * w, bln.y * h), w, h),
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

