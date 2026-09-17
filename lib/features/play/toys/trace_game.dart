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
  int _score = 0;
  int _best = 0;
  GameStatus _status = GameStatus.playing;
  late List<Offset> _pts;
  late List<bool> _lit;

  @override
  void initState() {
    super.initState();
    _load(0);
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _load(int level) {
    _pts = _shape(level % _shapeCount);
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
      default: // star
        for (var k = 0; k < 10; k++) {
          final r = k.isEven ? 0.36 : 0.15;
          final a = -math.pi / 2 + k / 10 * math.pi * 2;
          pts.add(Offset(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r));
        }
    }
    return pts;
  }

  void _drag(Offset local, Size size) {
    if (_status != GameStatus.playing) return;
    final p = Offset(local.dx / size.width, local.dy / size.height);
    var changed = false;
    for (var k = 0; k < _pts.length; k++) {
      if (!_lit[k] && (_pts[k] - p).distance < 0.06) {
        _lit[k] = true;
        changed = true;
      }
    }
    if (!changed) return;
    final done = _lit.where((e) => e).length;
    TonePlayer.instance.playPop(0.4 + done / _pts.length * 0.5);
    if (_lit.every((e) => e)) {
      _score++;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _shapeCount) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.success);
      } else {
        _load(_score);
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _status = GameStatus.playing;
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
                child: CustomPaint(
                  painter: _TracePainter(_pts, _lit),
                  size: Size.infinite,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '✏️ Trace   $_score / $_shapeCount${_best > 0 ? '   ★ $_best' : ''}',
                      style: const TextStyle(
                          color: Color(0xFF7DD3FC),
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
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
                    const Text('All shapes traced!',
                        style: TextStyle(
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
  _TracePainter(this.pts, this.lit);
  final List<Offset> pts;
  final List<bool> lit;

  @override
  void paint(Canvas canvas, Size size) {
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
