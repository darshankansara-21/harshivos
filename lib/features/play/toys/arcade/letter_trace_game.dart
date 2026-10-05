part of '../arcade_games.dart';

/// Letter Trace — follow the dotted path to trace a letter or number. Drag over
/// each dot to light it; fill them all and the glyph is complete. Trace five to
/// win. A calm fine-motor game built from simple straight strokes.
class LetterTraceGame extends StatefulWidget {
  const LetterTraceGame({super.key});
  @override
  State<LetterTraceGame> createState() => _LetterTraceGameState();
}

class _TraceDot {
  _TraceDot(this.x, this.y, this.strokeIdx);
  final double x, y; // screen-normalized [0,1]
  final int strokeIdx; // which stroke this dot belongs to, in glyph order
  bool lit = false;
}

class _LetterTraceGameState extends State<LetterTraceGame> with _Emit {
  static const String _id = 'letter_trace';
  static const int _target = 5;
  final math.Random _rnd = math.Random();

  // Each glyph is a set of straight strokes in a [0,1] box (x right, y down).
  static const Map<String, List<List<List<double>>>> _glyphs =
      <String, List<List<List<double>>>>{
    'A': <List<List<double>>>[
      <List<double>>[[0, 1], [0.5, 0]],
      <List<double>>[[0.5, 0], [1, 1]],
      <List<double>>[[0.22, 0.56], [0.78, 0.56]],
    ],
    'H': <List<List<double>>>[
      <List<double>>[[0, 0], [0, 1]],
      <List<double>>[[1, 0], [1, 1]],
      <List<double>>[[0, 0.5], [1, 0.5]],
    ],
    'L': <List<List<double>>>[
      <List<double>>[[0, 0], [0, 1]],
      <List<double>>[[0, 1], [1, 1]],
    ],
    'T': <List<List<double>>>[
      <List<double>>[[0, 0], [1, 0]],
      <List<double>>[[0.5, 0], [0.5, 1]],
    ],
    'E': <List<List<double>>>[
      <List<double>>[[1, 0], [0, 0]],
      <List<double>>[[0, 0], [0, 1]],
      <List<double>>[[0, 0.5], [0.7, 0.5]],
      <List<double>>[[0, 1], [1, 1]],
    ],
    'N': <List<List<double>>>[
      <List<double>>[[0, 1], [0, 0]],
      <List<double>>[[0, 0], [1, 1]],
      <List<double>>[[1, 1], [1, 0]],
    ],
    'V': <List<List<double>>>[
      <List<double>>[[0, 0], [0.5, 1]],
      <List<double>>[[0.5, 1], [1, 0]],
    ],
    'Z': <List<List<double>>>[
      <List<double>>[[0, 0], [1, 0]],
      <List<double>>[[1, 0], [0, 1]],
      <List<double>>[[0, 1], [1, 1]],
    ],
    '1': <List<List<double>>>[
      <List<double>>[[0.25, 0.22], [0.5, 0]],
      <List<double>>[[0.5, 0], [0.5, 1]],
    ],
    '7': <List<List<double>>>[
      <List<double>>[[0, 0], [1, 0]],
      <List<double>>[[1, 0], [0.4, 1]],
    ],
    '4': <List<List<double>>>[
      <List<double>>[[0.7, 0], [0.1, 0.62]],
      <List<double>>[[0.1, 0.62], [1, 0.62]],
      <List<double>>[[0.7, 0], [0.7, 1]],
    ],
  };
  late final List<String> _pool = _glyphs.keys.toList();

  final List<_TraceDot> _dots = <_TraceDot>[];
  String _glyph = 'A';
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newGlyph() {
    _glyph = _pool[_rnd.nextInt(_pool.length)];
    _dots.clear();
    // Map glyph box into a centred region of the screen.
    const ox = 0.3, oy = 0.28, sw = 0.4, sh = 0.5;
    final strokes = _glyphs[_glyph]!;
    for (var si = 0; si < strokes.length; si++) {
      final stroke = strokes[si];
      final a = stroke.first, b = stroke.last;
      final len = math.sqrt(
          math.pow(b[0] - a[0], 2) + math.pow(b[1] - a[1], 2)).toDouble();
      final n = math.max(2, (len / 0.2).ceil());
      for (var i = 0; i <= n; i++) {
        final t = i / n;
        final gx = a[0] + (b[0] - a[0]) * t;
        final gy = a[1] + (b[1] - a[1]) * t;
        final sx = ox + gx * sw, sy = oy + gy * sh;
        // Avoid duplicate dots at shared stroke endpoints.
        if (_dots.any((d) =>
            (d.x - sx).abs() < 0.015 && (d.y - sy).abs() < 0.015)) {
          continue;
        }
        _dots.add(_TraceDot(sx, sy, si));
      }
    }
  }

  void _touch(double nx, double ny) {
    if (_status != GameStatus.playing) return;
    _TraceDot? best;
    double bestD = 0.065;
    for (final d in _dots) {
      if (d.lit) continue;
      final dist = math.sqrt(math.pow(d.x - nx, 2) + math.pow(d.y - ny, 2));
      if (dist < bestD) {
        bestD = dist;
        best = d;
      }
    }
    if (best == null) return;
    best.lit = true;
    TonePlayer.instance.playCue(SoundCue.correct);
    if (_dots.every((d) => d.lit)) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _banner = 'Nice tracing! Next letter';
        _newGlyph();
      }
    } else {
      _banner = null;
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _banner = null;
      _newGlyph();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final lit = _dots.where((d) => d.lit).length;
    return _Shell(
      title: '✍️ Letter Trace',
      introHow:
          'Drag along the dotted path to trace the letter. Light up every dot, '
          'then trace the next one. Five to win!',
      onStart: () => setState(() {
        _newGlyph();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Trace the "$_glyph"  ·  $lit/${_dots.length}'
              : 'Trace the dotted letters'),
      winEmoji: '✍️',
      winText: 'Great writing!',
      accent: const Color(0xFF80ED99),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          void handle(Offset p) =>
              _touch((p.dx / w).clamp(0.0, 1.0), (p.dy / h).clamp(0.0, 1.0));
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => handle(d.localPosition),
            onPanUpdate: (d) => handle(d.localPosition),
            onTapDown: (d) => handle(d.localPosition),
            child: CustomPaint(
              painter: _LetterTracePainter(dots: _dots, glyph: _glyph),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _LetterTracePainter extends CustomPainter {
  _LetterTracePainter({required this.dots, required this.glyph});
  final List<_TraceDot> dots;
  final String glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF13241B), Color(0xFF0A1510)],
          ).createShader(Offset.zero & size));

    // Faint ghost glyph letter behind the dots.
    final ghost = TextPainter(
      text: TextSpan(
          text: glyph,
          style: TextStyle(
              fontSize: h * 0.52,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.05))),
      textDirection: TextDirection.ltr,
    )..layout();
    ghost.paint(canvas, Offset(w / 2 - ghost.width / 2, h * 0.24));

    // Ink trail: connect consecutive lit dots within the same stroke so the
    // letter visibly gets "written" rather than just lighting up disjoint dots.
    final inkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF57CC99).withOpacity(0.85);
    for (var i = 1; i < dots.length; i++) {
      final prev = dots[i - 1], cur = dots[i];
      if (prev.strokeIdx == cur.strokeIdx && prev.lit && cur.lit) {
        canvas.drawLine(Offset(prev.x * w, prev.y * h),
            Offset(cur.x * w, cur.y * h), inkPaint);
      }
    }

    for (final d in dots) {
      final c = Offset(d.x * w, d.y * h);
      if (d.lit) {
        canvas.drawCircle(
            c, 13, Paint()..color = const Color(0xFF80ED99).withOpacity(0.3));
        canvas.drawCircle(c, 8, Paint()..color = const Color(0xFF57CC99));
      } else {
        canvas.drawCircle(
            c,
            9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.white54);
      }
    }
  }

  @override
  bool shouldRepaint(_LetterTracePainter oldDelegate) => true;
}
