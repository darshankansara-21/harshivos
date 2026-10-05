part of '../arcade_games.dart';

/// Pattern Weaver — a repeating bead pattern with one bead missing. Tap the
/// colour that comes next. Patterns get longer. Ten right to win.
class PatternWeaverGame extends StatefulWidget {
  const PatternWeaverGame({super.key});
  @override
  State<PatternWeaverGame> createState() => _PatternWeaverGameState();
}

class _PatternWeaverGameState extends State<PatternWeaverGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'pattern_weaver';
  static const int _target = 10;
  static const List<Color> _palette = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
  ];
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  List<int> _pattern = <int>[0, 1];
  int _visible = 4;
  int _answer = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  int _wrongFlash = -1;
  double _wrongT = 0;
  double _pop = 0;
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

  int get _colorCount => _score >= 6 ? 4 : 3;

  void _newRound() {
    final period = 2 + _rnd.nextInt(_score >= 4 ? 3 : 2); // 2..4
    _pattern = <int>[];
    for (var i = 0; i < period; i++) {
      int c;
      do {
        c = _rnd.nextInt(_colorCount);
      } while (i > 0 && c == _pattern[i - 1] && period > 2);
      _pattern.add(c);
    }
    _visible = period * 2;
    _answer = _pattern[_visible % period];
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
    if (_pop > 0) _pop -= dt;
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
  }

  void _pick(int color, int idx) {
    if (_status != GameStatus.playing) return;
    if (color == _answer) {
      _score++;
      _pop = 0.4;
      for (var i = 0; i < 12; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard(0.5, 0.32, math.cos(a) * sp, math.sin(a) * sp,
            _palette[color]));
      }
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'You wove it! 🧶';
      _bannerT = 1.0;
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
        _banner = 'Look at the pattern…';
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
      title: '🧶 Pattern Weaver',
      introHow:
          'Look at the repeating colours, then tap the one that comes next in the pattern!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'What comes next? · ${'💛' * _lives}',
      overEmoji: '🧶',
      overText: 'Pattern pro!',
      accent: const Color(0xFF63E6BE),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (d.localPosition.dy < h * 0.6) return;
              final i =
                  (d.localPosition.dx / w * _colorCount).floor().clamp(0, _colorCount - 1);
              _pick(i, i);
            },
            child: CustomPaint(
              painter: _PatternPainter(
                palette: _palette,
                pattern: _pattern,
                visible: _visible,
                colorCount: _colorCount,
                wrongFlash: _wrongFlash,
                pop: _pop,
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

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.palette,
    required this.pattern,
    required this.visible,
    required this.colorCount,
    required this.wrongFlash,
    required this.pop,
    required this.bits,
  });
  final List<Color> palette;
  final List<int> pattern;
  final int visible, colorCount, wrongFlash;
  final double pop;
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
            colors: <Color>[Color(0xFF1E2A3A), Color(0xFF131C28)],
          ).createShader(Offset.zero & size));
    final period = pattern.length;
    final n = visible + 1;
    final slot = w / (n + 1);
    final r = math.min(slot * 0.38, h * 0.08);
    final y = h * 0.32;
    // String line.
    canvas.drawLine(Offset(slot * 0.5, y), Offset(w - slot * 0.5, y),
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 2);
    for (var i = 0; i < n; i++) {
      final cx = slot * (i + 1);
      if (i < visible) {
        canvas.drawCircle(Offset(cx, y), r,
            Paint()..color = palette[pattern[i % period]]);
        canvas.drawCircle(Offset(cx, y), r * 0.4,
            Paint()..color = Colors.white.withOpacity(0.25));
      } else {
        // The missing bead.
        final pr = r * (1 + pop * 0.6);
        canvas.drawCircle(Offset(cx, y), pr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white70);
        final tp = TextPainter(
          text: const TextSpan(
              text: '?',
              style: TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, y - tp.height / 2));
      }
    }
    // Option pads.
    final padTop = h * 0.62;
    final pw = w / colorCount;
    for (var i = 0; i < colorCount; i++) {
      final rect = Rect.fromLTWH(i * pw + 10, padTop, pw - 20, h * 0.3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(16)),
          Paint()
            ..color = wrongFlash == i
                ? const Color(0xFFE23B3B)
                : palette[i]);
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => true;
}

