part of '../arcade_games.dart';

/// Count & Pop — read the number, then pop exactly that many drifting bubbles.
/// The count shows as you go and the round finishes at the target. Gentle
/// counting with no way to fail; ten rounds to win.
class CountPopGame extends StatefulWidget {
  const CountPopGame({super.key});
  @override
  State<CountPopGame> createState() => _CountPopGameState();
}

class _CountBubble {
  _CountBubble(this.x, this.y, this.vx, this.vy, this.r, this.hue);
  double x, y, vx, vy;
  final double r;
  final double hue;
}

class _CountPopGameState extends State<CountPopGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'count_pop';
  static const int _target = 10;
  final math.Random _rnd = math.Random();

  final List<_CountBubble> _bubbles = <_CountBubble>[];
  int _need = 3;
  int _popped = 0;
  int _score = 0;
  int _best = 0;
  double _pop = 0;
  double _popX = 0, _popY = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newRound() {
    _need = 2 + _rnd.nextInt(5);
    _popped = 0;
    _bubbles.clear();
    for (var i = 0; i < _need + 4; i++) {
      _bubbles.add(_spawn());
    }
  }

  _CountBubble _spawn() => _CountBubble(
        0.12 + _rnd.nextDouble() * 0.76,
        0.18 + _rnd.nextDouble() * 0.6,
        (_rnd.nextDouble() - 0.5) * 0.08,
        (_rnd.nextDouble() - 0.5) * 0.08,
        0.06 + _rnd.nextDouble() * 0.03,
        _rnd.nextDouble() * 360,
      );

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_pop > 0) _pop -= dt * 3;
    for (final b in _bubbles) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.x < 0.08 || b.x > 0.92) b.vx = -b.vx;
      if (b.y < 0.14 || b.y > 0.86) b.vy = -b.vy;
    }
    setState(() {});
  }

  void _tap(Offset p, double w, double h) {
    if (_status != GameStatus.playing) return;
    for (var i = _bubbles.length - 1; i >= 0; i--) {
      final b = _bubbles[i];
      // The painter draws each bubble as a true pixel circle with radius
      // scaled only by width (`b.r * w`), so the hit-test must compare real
      // pixel deltas rather than mixing a width-normalized radius with a
      // height-normalized y-delta — otherwise the tap region stretches
      // vertically on any device where height != width.
      final dx = b.x * w - p.dx;
      final dy = b.y * h - p.dy;
      final r = b.r * w;
      if (dx * dx + dy * dy < r * r) {
        _bubbles.removeAt(i);
        _popped++;
        _pop = 1;
        _popX = b.x;
        _popY = b.y;
        TonePlayer.instance.playCue(SoundCue.bubble);
        if (_popped >= _need) {
          _score++;
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.bubblePopped);
          GameScores.instance.submit(_id, _score).then((v) {
            if (mounted) setState(() => _best = v);
          });
          if (_score >= _target) {
            _status = GameStatus.won;
            TonePlayer.instance.playCue(SoundCue.gameStart);
            emit(ExperienceEvent.gameCompleted);
          } else {
            _banner = 'Yes! You popped $_need 🫧';
            _newRound();
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
      _banner = null;
      _newRound();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔢 Count & Pop',
      introHow:
          'Read the number, then pop exactly that many bubbles. The round '
          'finishes when you reach it. Ten rounds to win!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Pop $_need bubbles  ·  $_popped/$_need'
              : 'Pop the right number of bubbles'),
      winEmoji: '🔢',
      winText: 'Great counting!',
      accent: const Color(0xFF48CAE4),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d.localPosition, w, h),
            child: CustomPaint(
              painter: _CountPopPainter(
                bubbles: _bubbles,
                need: _need,
                popped: _popped,
                pop: _pop.clamp(0.0, 1.0),
                popX: _popX,
                popY: _popY,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _CountPopPainter extends CustomPainter {
  _CountPopPainter({
    required this.bubbles,
    required this.need,
    required this.popped,
    required this.pop,
    required this.popX,
    required this.popY,
  });
  final List<_CountBubble> bubbles;
  final int need, popped;
  final double pop, popX, popY;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF123047), Color(0xFF0A1824)],
          ).createShader(Offset.zero & size));

    for (final b in bubbles) {
      final c = Offset(b.x * w, b.y * h);
      final col = HSVColor.fromAHSV(1, b.hue, 0.5, 1).toColor();
      canvas.drawCircle(c, b.r * w, Paint()..color = col.withOpacity(0.5));
      canvas.drawCircle(
          c,
          b.r * w,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white70);
      canvas.drawCircle(c + Offset(-b.r * w * 0.3, -b.r * w * 0.3),
          b.r * w * 0.25, Paint()..color = Colors.white54);
    }
    if (pop > 0) {
      canvas.drawCircle(
          Offset(popX * w, popY * h),
          (1 - pop) * 40 + 10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withOpacity(pop));
    }
    // Big target number — a counting-literacy aid, not pure decoration, so it
    // must stay legible against the dark gradient instead of the previous
    // near-invisible white24 (a child learning to count needs to actually
    // read it, not squint for a watermark).
    final tp = TextPainter(
      text: TextSpan(
          text: '$popped / $need',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 60,
              fontWeight: FontWeight.w900,
              shadows: <Shadow>[
                Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
              ])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h * 0.86));
  }

  @override
  bool shouldRepaint(_CountPopPainter oldDelegate) => true;
}
