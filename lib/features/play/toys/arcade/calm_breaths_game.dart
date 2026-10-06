part of '../arcade_games.dart';

/// Calm Breaths — follow the circle as it grows and shrinks to breathe along.
/// Breathe in as it expands, hold, then out as it settles. No tapping, nothing
/// to lose — just five slow breaths together.
class CalmBreathsGame extends StatefulWidget {
  const CalmBreathsGame({super.key});
  @override
  State<CalmBreathsGame> createState() => _CalmBreathsGameState();
}

class _CalmBreathsGameState extends State<CalmBreathsGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'calm_breaths';
  static const int _target = 5;
  // One breath: inhale 4s, hold 2s, exhale 4s.
  static const double _inhale = 4, _hold = 2, _exhale = 4;
  static const double _cycle = _inhale + _hold + _exhale;
  // Pool of calm, low-key completion phrases — intentionally gentle (no
  // exclamation-mark hype) to match this exercise's quiet "calmCompleted"
  // tone instead of an excited "You did it!" celebration.
  static const List<String> _winPraisePool = <String>[
    'So calm 💙',
    'Beautifully calm',
    'Peaceful and still',
    'Nice and steady 💙',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();

  double _t = 0;
  int _score = 0;
  int _best = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  // 0..1 breath size + a phase label.
  double get _size {
    final p = _t % _cycle;
    if (p < _inhale) return _ease(p / _inhale);
    if (p < _inhale + _hold) return 1;
    return _ease(1 - (p - _inhale - _hold) / _exhale);
  }

  String get _phase {
    final p = _t % _cycle;
    if (p < _inhale) return 'Breathe in…';
    if (p < _inhale + _hold) return 'Hold…';
    return 'Breathe out…';
  }

  double _ease(double x) => 0.5 - 0.5 * math.cos(x * math.pi);

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    final before = (_t / _cycle).floor();
    _t += dt;
    final after = (_t / _cycle).floor();
    if (after > before) {
      _score = after;
      TonePlayer.instance.playCue(SoundCue.calm);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        // No loud win fanfare here — five slow breaths ending in an excited
        // "You did it!" celebration burst would undercut the whole point of
        // a calming exercise. `calmCompleted` settles the companion instead
        // of celebrating it.
        emit(ExperienceEvent.calmCompleted);
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _t = 0;
      _score = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🫧 Calm Breaths',
      introHow:
          'Follow the circle — breathe in as it grows, hold, then breathe out '
          'as it shrinks. Five calm breaths together.',
      onStart: () => setState(() {
        _t = 0;
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      rankByScore: false,
      banner: _status == GameStatus.playing ? _phase : 'Breathe along with the circle',
      winEmoji: '🫧',
      winText: _winPraise,
      accent: const Color(0xFF89F7FE),
      onPlayAgain: _reset,
      child: CustomPaint(
        painter: _CalmBreathsPainter(
          size01: _status == GameStatus.playing ? _size : 0.3,
          phase: _status == GameStatus.playing ? _phase : '',
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CalmBreathsPainter extends CustomPainter {
  _CalmBreathsPainter({required this.size01, required this.phase});
  final double size01;
  final String phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0E3A4A), Color(0xFF07202A)],
          ).createShader(Offset.zero & size));

    final c = Offset(w / 2, h / 2);
    final maxR = math.min(w, h) * 0.38;
    final r = maxR * (0.4 + 0.6 * size01);
    // Soft outer glow rings.
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
          c,
          r + i * 16.0,
          Paint()..color = const Color(0xFF89F7FE).withOpacity(0.06 * i));
    }
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFF89F7FE).withOpacity(0.9),
              const Color(0xFF66A6FF).withOpacity(0.6),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)));

    if (phase.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
            text: phase,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CalmBreathsPainter oldDelegate) => true;
}
