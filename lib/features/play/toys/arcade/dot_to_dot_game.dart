part of '../arcade_games.dart';

/// Dot-to-Dot — tap the numbered dots in order to draw the hidden shape. Each
/// finished picture has more dots. Complete five to win.
class DotToDotGame extends StatefulWidget {
  const DotToDotGame({super.key});
  @override
  State<DotToDotGame> createState() => _DotToDotGameState();
}

class _DotToDotGameState extends State<DotToDotGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'dot_to_dot';
  static const int _target = 5;
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  List<Offset> _dots = <Offset>[];
  int _next = 0;
  int _fig = 0;
  int _score = 0;
  int _best = 0;
  double _pulse = 0;
  int _wrongDot = -1;
  double _wrongFlashT = 0;
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

  void _buildFigure() {
    // Points around a circle; star alternates radius. More points each figure.
    // The point count/star-or-not progression stays a deterministic function
    // of _fig (that's the intended difficulty curve), but every other visual
    // parameter is randomized per figure so repeat sessions — and even the
    // five pictures within one session — never trace the exact same shape
    // twice: a fresh rotation, outer/inner radius, and center jitter each time.
    final count = 3 + _fig; // 3,4,5,6,7
    final star = _fig >= 2;
    _dots = <Offset>[];
    final pts = star ? count * 2 : count;
    final rotation = _rnd.nextDouble() * math.pi * 2;
    final outerR = 0.29 + _rnd.nextDouble() * 0.06;
    final innerR = 0.13 + _rnd.nextDouble() * 0.05;
    final cx = 0.5 + (_rnd.nextDouble() - 0.5) * 0.06;
    final cy = 0.42 + (_rnd.nextDouble() - 0.5) * 0.06;
    for (var i = 0; i < pts; i++) {
      final a = rotation + i * math.pi * 2 / pts;
      final rr = star && i.isOdd ? innerR : outerR;
      _dots.add(Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr * 1.1));
    }
    _next = 0;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _pulse += dt * 4;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_wrongFlashT > 0) {
      _wrongFlashT -= dt;
      if (_wrongFlashT <= 0) _wrongDot = -1;
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
    if (_status != GameStatus.playing || _next >= _dots.length) return;
    final nx = p.dx / w, ny = p.dy / h;
    final target = _dots[_next];
    if ((target.dx - nx).abs() < 0.08 && (target.dy - ny).abs() < 0.08) {
      _next++;
      TonePlayer.instance.playNote(2 + _next, seconds: 0.14);
      if (_next >= _dots.length) {
        _score++;
        for (var i = 0; i < 18; i++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.15 + _rnd.nextDouble() * 0.4;
          _bits.add(_Shard(0.5, 0.42, math.cos(a) * sp, math.sin(a) * sp,
              const Color(0xFFFFD166)));
        }
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.bubblePopped);
        _banner = 'Picture done! 🎉';
        _bannerT = 1.2;
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        if (_score >= _target) {
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _fig++;
          _buildFigure();
        }
      }
      setState(() {});
      return;
    }
    // Tapped a dot that isn't next in sequence — give clear feedback instead
    // of silently doing nothing, so the child knows the tap registered but
    // picked the wrong number.
    for (var i = 0; i < _dots.length; i++) {
      if (i == _next) continue;
      final d = _dots[i];
      if ((d.dx - nx).abs() < 0.08 && (d.dy - ny).abs() < 0.08) {
        _wrongDot = i;
        _wrongFlashT = 0.3;
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        setState(() {});
        break;
      }
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _fig = 0;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _wrongDot = -1;
      _wrongFlashT = 0;
      _buildFigure();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    if (_dots.isEmpty) _buildFigure();
    return _Shell(
      title: '🔢 Dot-to-Dot',
      introHow:
          'Tap the numbered dots in order — 1, 2, 3… — to draw the hidden picture!',
      onStart: () => setState(() {
        _buildFigure();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Tap dot ${_next + 1}',
      winEmoji: '🔢',
      winText: 'Artist!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d.localPosition, w, h),
            child: CustomPaint(
              painter: _DotPainter(
                dots: _dots,
                next: _next,
                pulse: _pulse,
                bits: _bits,
                wrongDot: _wrongDot,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.dots,
    required this.next,
    required this.pulse,
    required this.bits,
    required this.wrongDot,
  });
  final List<Offset> dots;
  final int next;
  final double pulse;
  final List<_Shard> bits;
  final int wrongDot;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF20283A), Color(0xFF141A28)],
          ).createShader(Offset.zero & size));
    Offset sp(Offset o) => Offset(o.dx * w, o.dy * h);
    // Connected lines.
    final line = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < next; i++) {
      canvas.drawLine(sp(dots[i - 1]), sp(dots[i]), line);
    }
    if (next == dots.length && dots.isNotEmpty) {
      canvas.drawLine(sp(dots.last), sp(dots.first), line);
    }
    // Dots.
    for (var i = 0; i < dots.length; i++) {
      final c = sp(dots[i]);
      final done = i < next;
      final isNext = i == next;
      final r = isNext ? 16 + math.sin(pulse) * 3 : 13.0;
      canvas.drawCircle(c, r,
          Paint()..color = done
              ? const Color(0xFFFFD166)
              : (isNext ? Colors.white : Colors.white54));
      if (i == wrongDot) {
        // A tap landed here but it isn't next — a clear ring says "I saw
        // that tap, it's just not the right dot yet".
        canvas.drawCircle(
            c,
            r + 6,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFFE23B3B));
      }
      if (!done) {
        final tp = TextPainter(
          text: TextSpan(
              text: '${i + 1}',
              style: TextStyle(
                  color: isNext ? Colors.black : const Color(0xFF20283A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 4 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => true;
}

