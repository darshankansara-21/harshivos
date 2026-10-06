import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/audio/tone_player.dart';
import 'mini_games.dart' show GameScores, GameStatus;

/// Trace It — a calm fine-motor game. A shape is drawn as a trail of dots and
/// the child drags a finger over them to light each one up. Complete a shape to
/// move to the next; trace five to win. Distinct from every other game: it
/// rewards steady tracing, not speed or reflex.
class TraceGame extends StatefulWidget {
  const TraceGame({super.key});

  @override
  State<TraceGame> createState() => _TraceGameState();
}

class _TraceGameState extends State<TraceGame> {
  static const String _id = 'trace_it';
  static const int _shapeCount = 5;
  // Total distinct shapes the game can draw from. Only _shapeCount of these
  // are traced per playthrough, picked randomly — so a child who plays
  // several rounds in a row sees a different subset each time instead of
  // the exact same circle->square->triangle->wave->star sequence forever.
  static const int _shapePoolSize = 9;
  final math.Random _rnd = math.Random();
  int _score = 0;
  int _best = 0;
  GameStatus _status = GameStatus.playing;
  late List<Offset> _pts;
  late List<bool> _lit;
  late List<int> _order;

  static const List<String> _winPraisePool = <String>[
    'All shapes traced!',
    'Steady hands! All done!',
    'Beautifully traced!',
    'Every shape complete!',
  ];
  late String _winPraise = _winPraisePool[0];

  @override
  void initState() {
    super.initState();
    _order = _pickOrder();
    _load(0);
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  List<int> _pickOrder() {
    final pool = List<int>.generate(_shapePoolSize, (i) => i)..shuffle(_rnd);
    return pool.take(_shapeCount).toList();
  }

  void _load(int level) {
    _pts = _shape(_order[level % _shapeCount]);
    _lit = List<bool>.filled(_pts.length, false);
  }

  void _line(List<Offset> out, Offset a, Offset b) {
    const n = 7;
    for (var k = 0; k <= n; k++) {
      out.add(Offset.lerp(a, b, k / n)!);
    }
  }

  List<Offset> _shape(int i) {
    final pts = <Offset>[];
    switch (i) {
      case 0: // circle
        for (var k = 0; k < 28; k++) {
          final a = k / 28 * math.pi * 2;
          pts.add(Offset(0.5 + math.cos(a) * 0.34, 0.5 + math.sin(a) * 0.34));
        }
      case 1: // square
        _line(pts, const Offset(0.2, 0.24), const Offset(0.8, 0.24));
        _line(pts, const Offset(0.8, 0.24), const Offset(0.8, 0.76));
        _line(pts, const Offset(0.8, 0.76), const Offset(0.2, 0.76));
        _line(pts, const Offset(0.2, 0.76), const Offset(0.2, 0.24));
      case 2: // triangle
        _line(pts, const Offset(0.5, 0.18), const Offset(0.84, 0.78));
        _line(pts, const Offset(0.84, 0.78), const Offset(0.16, 0.78));
        _line(pts, const Offset(0.16, 0.78), const Offset(0.5, 0.18));
      case 3: // wave
        for (var k = 0; k <= 28; k++) {
          final x = 0.12 + k / 28 * 0.76;
          pts.add(Offset(x, 0.5 + math.sin(k / 28 * math.pi * 3) * 0.22));
        }
      case 4: // star
        for (var k = 0; k < 10; k++) {
          final r = k.isEven ? 0.36 : 0.15;
          final a = -math.pi / 2 + k / 10 * math.pi * 2;
          pts.add(Offset(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r));
        }
      case 5: // heart
        for (var k = 0; k <= 32; k++) {
          final t = k / 32 * math.pi * 2;
          final x = 16 * math.pow(math.sin(t), 3);
          final y = 13 * math.cos(t) -
              5 * math.cos(2 * t) -
              2 * math.cos(3 * t) -
              math.cos(4 * t);
          pts.add(Offset(0.5 + x / 34, 0.5 - y / 34));
        }
      case 6: // diamond
        _line(pts, const Offset(0.5, 0.16), const Offset(0.82, 0.5));
        _line(pts, const Offset(0.82, 0.5), const Offset(0.5, 0.84));
        _line(pts, const Offset(0.5, 0.84), const Offset(0.18, 0.5));
        _line(pts, const Offset(0.18, 0.5), const Offset(0.5, 0.16));
      case 7: // arrow
        _line(pts, const Offset(0.16, 0.5), const Offset(0.72, 0.5));
        _line(pts, const Offset(0.72, 0.5), const Offset(0.5, 0.28));
        _line(pts, const Offset(0.72, 0.5), const Offset(0.5, 0.72));
      default: // zigzag
        for (var k = 0; k <= 24; k++) {
          final x = 0.14 + k / 24 * 0.72;
          final y = k.isEven ? 0.32 : 0.68;
          pts.add(Offset(x, y));
        }
    }
    return pts;
  }

  // Index of the one dot the child must trace to next, in path order. `_pts`
  // is generated point-by-point along the shape's outline, so "first unlit
  // point in list order" is exactly "next point on the path".
  int get _nextDotIdx => _lit.indexWhere((e) => !e);

  void _drag(Offset local, Size size) {
    if (_status != GameStatus.playing) return;
    // Only the next dot on the path can be lit — matching every unlit dot in
    // reach (the prior behaviour) let a quick scribble or a straight-line
    // drag across the shape light far-apart dots out of sequence, skipping
    // the actual outline entirely and defeating the fine-motor tracing this
    // game explicitly promises ("rewards steady tracing, not speed or
    // reflex"). Same sequential-order fix already applied to the sibling
    // `letter_trace_game.dart`.
    final idx = _nextDotIdx;
    if (idx < 0) return;
    // Compare in real pixel space (not normalized x/y) so the hit radius is a
    // true circle matching the dots the painter actually draws — normalized
    // (dx/width, dy/height) distance distorts into an ellipse whenever
    // width != height, the same aspect-ratio hit-test bug fixed repeatedly
    // elsewhere in the catalog (space_dodge, letter_trace, steady_hand, etc.).
    final dot = Offset(_pts[idx].dx * size.width, _pts[idx].dy * size.height);
    if ((dot - local).distance >= 32) return;
    _lit[idx] = true;
    final done = _lit.where((e) => e).length;
    TonePlayer.instance.playPop(0.4 + done / _pts.length * 0.5);
    if (_lit.every((e) => e)) {
      _score++;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _shapeCount) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        TonePlayer.instance.playCue(SoundCue.success);
      } else {
        TonePlayer.instance.playCue(SoundCue.correct);
        _load(_score);
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _status = GameStatus.playing;
      _order = _pickOrder();
      _load(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF1B2A4A), Color(0xFF0C1526)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _drag(d.localPosition, size),
                onPanUpdate: (d) => _drag(d.localPosition, size),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('trace-$_score'),
                  tween: Tween<double>(begin: 1.12, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (ctx, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: CustomPaint(
                    painter: _TracePainter(_pts, _lit, _nextDotIdx),
                    size: Size.infinite,
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 70),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Catalog-wide pattern (see _Shell/_GameShell/_GoalShell):
                  // wrap a live-changing score/progress readout in a
                  // liveRegion so a screen-reader user hears each dot lit and
                  // shape completed instead of total silence — this standalone
                  // widget (it doesn't use any of those shared shells) had
                  // never been given the same accessibility treatment.
                  Semantics(
                    container: true,
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '✏️ Trace   $_score / $_shapeCount   '
                        '${_lit.where((e) => e).length}/${_pts.length}'
                        '${_best > 0 ? '   ★ $_best' : ''}',
                        style: const TextStyle(
                            color: Color(0xFF7DD3FC),
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Trace the dots with your finger',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
        if (_status == GameStatus.won)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('🎉', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 8),
                    Text(_winPraise,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Play again'),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) => TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.grid_view_rounded,
                            color: Colors.white70, size: 20),
                        label: const Text('Back to games',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.pts, this.lit, this.nextIdx);
  final List<Offset> pts;
  final List<bool> lit;
  final int nextIdx;

  @override
  void paint(Canvas canvas, Size size) {
    // Ink trail: connect consecutive lit dots so the shape visibly gets
    // "drawn" in order, matching `letter_trace_game.dart`'s ink-trail
    // convention now that tracing is enforced path-order here too.
    final inkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF06D6A0).withOpacity(0.7);
    for (var i = 1; i < pts.length; i++) {
      if (lit[i - 1] && lit[i]) {
        canvas.drawLine(
            Offset(pts[i - 1].dx * size.width, pts[i - 1].dy * size.height),
            Offset(pts[i].dx * size.width, pts[i].dy * size.height),
            inkPaint);
      }
    }
    for (var i = 0; i < pts.length; i++) {
      final c = Offset(pts[i].dx * size.width, pts[i].dy * size.height);
      if (lit[i]) {
        canvas.drawCircle(
            c,
            16,
            Paint()
              ..color = const Color(0x3306D6A0)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawCircle(c, 11, Paint()..color = const Color(0xFF06D6A0));
      } else if (i == nextIdx) {
        // Tracing is now enforced in path order, so the one dot a touch will
        // actually light needs to read as visibly "next" — a plain identical
        // ring for every remaining dot gave no clue which one the enforced
        // order wants, undercutting the whole fix (same reasoning already
        // applied to `letter_trace_game.dart`'s next-dot highlight).
        canvas.drawCircle(
            c, 14, Paint()..color = Colors.white.withOpacity(0.3));
        canvas.drawCircle(
            c,
            9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white);
      } else {
        canvas.drawCircle(c, 9, Paint()..color = Colors.white24);
        canvas.drawCircle(
            c,
            9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white70);
      }
    }
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) => true;
}
