part of '../arcade_games.dart';

/// Firefly Count — count the glowing fireflies and tap the matching number.
/// Gentle number practice; the count grows as you go. Ten right to win.
class FireflyCountGame extends StatefulWidget {
  const FireflyCountGame({super.key});
  @override
  State<FireflyCountGame> createState() => _FireflyCountGameState();
}

class _Fly {
  _Fly(this.x, this.y, this.phase, this.vx, this.vy);
  double x, y, phase, vx, vy;
}

class _FireflyCountGameState extends State<FireflyCountGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'firefly_count';
  static const int _target = 10;
  final math.Random _rnd = math.Random();
  final List<_Fly> _flies = <_Fly>[];
  List<int> _options = <int>[2, 3, 4];
  int _count = 3;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  int _wrongFlash = -1;
  double _wrongT = 0;
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

  void _newRound() {
    final maxN = (4 + _score ~/ 2).clamp(4, 9);
    _count = 2 + _rnd.nextInt(maxN - 1);
    _flies.clear();
    for (var i = 0; i < _count; i++) {
      _flies.add(_Fly(0.15 + _rnd.nextDouble() * 0.7, 0.12 + _rnd.nextDouble() * 0.5,
          _rnd.nextDouble() * math.pi * 2, (_rnd.nextDouble() - 0.5) * 0.06,
          (_rnd.nextDouble() - 0.5) * 0.06));
    }
    final opts = <int>{_count};
    while (opts.length < 3) {
      final d = _count + _rnd.nextInt(5) - 2;
      if (d >= 1 && d != _count) opts.add(d);
    }
    _options = opts.toList()..shuffle(_rnd);
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_wrongT > 0) {
      _wrongT -= dt;
      if (_wrongT <= 0) _wrongFlash = -1;
    }
    for (final f in _flies) {
      f.phase += dt * 3;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      if (f.x < 0.08 || f.x > 0.92) f.vx = -f.vx;
      if (f.y < 0.1 || f.y > 0.62) f.vy = -f.vy;
    }
  }

  void _pick(int value, int idx) {
    if (_status != GameStatus.playing) return;
    if (value == _count) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Yes! $_count fireflies ✨';
      _bannerT = 1.2;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newRound();
      }
    } else {
      _wrongFlash = idx;
      _wrongT = 0.5;
      _lives--;
      if (_lives <= 0) {
        // The life-ending miss is the real end of the run — it must sound
        // distinct from a routine miss, never just the same gentle-retry cue.
        _status = GameStatus.over;
        _banner = 'Out of lives!';
        _bannerT = 1.2;
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'Count again…';
        _bannerT = 1.0;
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _banner = null;
      _bannerT = 0;
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '✨ Firefly Count',
      introHow:
          'Count the glowing fireflies, then tap the number that matches. Get ten right!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'How many fireflies? · ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '✨',
      winText: 'Counting star!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final padTop = h * 0.7;
          return Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (d.localPosition.dy < h * 0.68) return;
                  final i = (d.localPosition.dx / w * 3).floor().clamp(0, 2);
                  _pick(_options[i], i);
                },
                child: CustomPaint(
                  painter: _FireflyPainter(
                    flies: _flies,
                    options: _options,
                    wrongFlash: _wrongFlash,
                  ),
                  size: Size.infinite,
                ),
              ),
              // The tappable answer numbers are drawn only onto the canvas,
              // so a screen-reader user couldn't even discover what the
              // choices were. These invisible Semantics overlays mirror the
              // painter's pad rects so TalkBack/VoiceOver can announce and
              // activate each number choice.
              for (var i = 0; i < _options.length; i++)
                Positioned(
                  left: w * (i / 3) + 10,
                  top: padTop,
                  width: w / 3 - 20,
                  height: h * 0.26,
                  child: Semantics(
                    label: 'Answer ${_options[i]}',
                    button: true,
                    onTap: () => _pick(_options[i], i),
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

class _FireflyPainter extends CustomPainter {
  _FireflyPainter({
    required this.flies,
    required this.options,
    required this.wrongFlash,
  });
  final List<_Fly> flies;
  final List<int> options;
  final int wrongFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1B2450), Color(0xFF0C1030)],
          ).createShader(Offset.zero & size));
    for (final f in flies) {
      final glow = 0.6 + 0.4 * math.sin(f.phase);
      final c = Offset(f.x * w, f.y * h);
      canvas.drawCircle(c, 14 * glow,
          Paint()..color = const Color(0xFFFFF3B0).withOpacity(0.25 * glow));
      canvas.drawCircle(c, 6, Paint()..color = const Color(0xFFFFE066));
    }
    // Number pads.
    final padTop = h * 0.7;
    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(w * (i / 3) + 10, padTop, w / 3 - 20, h * 0.26);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(16)),
          Paint()
            ..color = wrongFlash == i
                ? const Color(0xFFE23B3B)
                : Colors.white.withOpacity(0.12));
      final tp = TextPainter(
        text: TextSpan(
            text: '${options[i]}',
            style: const TextStyle(
                color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_FireflyPainter old) => true;
}

