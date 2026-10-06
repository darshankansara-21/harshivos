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
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Counting star!" line on win screen.
  static const List<String> _winPraisePool = <String>[
    'Counting star!',
    'Number whiz!',
    'Sharp counting!',
    'Ten for ten!',
  ];
  String _winPraise = _winPraisePool[0];
  String _overPraise = _gentleTryAgainPool[0];
  // Every routine wrong tap flashed the exact same "Count again…" banner
  // (up to several times in one round); vary it like the win-screen praise.
  static const List<String> _missPool = <String>[
    'Count again…', 'Recount…', 'Try counting again…', 'One more count…',
  ];
  final math.Random _rnd = math.Random();
  final List<_Fly> _flies = <_Fly>[];
  List<int> _options = <int>[2, 3, 4];
  int _count = 3;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  bool _beatBest = false;
  int _wrongFlash = -1;
  double _wrongT = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Unlike every other sibling tap-the-right-answer game (tone_match,
  // odd_one_out, jigsaw_four), a correct count tap here had zero screen-space
  // celebration — just a banner line and a chime, identical in weight to
  // every other quiz-style game's genuine "I got it!" moment before this
  // class of gap was closed catalog-wide. Add the same colour-shard burst
  // from the tapped answer pad.
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;

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
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    for (final f in _flies) {
      f.phase += dt * 3;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      if (f.x < 0.08 || f.x > 0.92) f.vx = -f.vx;
      if (f.y < 0.1 || f.y > 0.62) f.vy = -f.vy;
    }
  }

  void _burst(int idx) {
    final cx = (idx + 0.5) / 3;
    const cy = 0.83; // center of the answer-pad band drawn at h*0.7..h*0.96
    final n = _reduceMotion ? 4 : 12;
    for (var k = 0; k < n; k++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.3;
      _bits.add(_Shard(cx, cy, math.cos(a) * sp, math.sin(a) * sp,
          const Color(0xFFFFE066)));
    }
  }

  void _pick(int value, int idx) {
    if (_status != GameStatus.playing) return;
    if (value == _count) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _burst(idx);
      _banner = 'Yes! $_count fireflies ✨';
      _bannerT = 1.2;
      // A child who runs out of lives right after this tap still deserves
      // the companion's loudest celebration if it's a genuine all-time
      // record, not just the routine correct-tap chime.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
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
        _newRound();
      }
    } else {
      _wrongFlash = idx;
      _wrongT = 0.5;
      _lives--;
      // Every wrong tap deserves the companion's gentle encouraging
      // reaction, not just the one that happens to end the game.
      emit(ExperienceEvent.incorrectAnswer);
      if (_lives <= 0) {
        // The life-ending miss is the real end of the run — it must sound
        // distinct from a routine miss, never just the same gentle-retry cue.
        _status = GameStatus.over;
        _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
        _banner = 'Out of lives!';
        _bannerT = 1.2;
        TonePlayer.instance.playCue(SoundCue.gameOver);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = _missPool[_rnd.nextInt(_missPool.length)];
        _bannerT = 1.0;
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _beatBest = false;
      _banner = null;
      _bannerT = 0;
      _bits.clear();
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '✨ Firefly Count',
      introHow:
          'Count the glowing fireflies, then tap the number that matches. Get ten right! '
          'A wrong answer costs one of your 3 lives.',
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
      overText: _overPraise,
      winEmoji: '✨',
      winText: _winPraise,
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
              if (_bits.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _FireflyShardPainter(_bits)),
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

class _FireflyShardPainter extends CustomPainter {
  _FireflyShardPainter(this.bits);
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_FireflyShardPainter oldDelegate) => true;
}

