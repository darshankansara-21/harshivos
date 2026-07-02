import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A meditative top-down zen sand garden. Dragging a finger carves a smooth
/// glowing groove into warm raked sand — the trough sits in soft shadow while
/// the displaced sand forms highlighted ridges along the sides. Smooth pebbles
/// rest on the surface casting soft shadows, ringed by concentric raked lines.
/// The garden is always drawable, building a calming, permanent path.
class SandZenExperience extends StatefulWidget {
  const SandZenExperience({super.key});

  @override
  State<SandZenExperience> createState() => _SandZenExperienceState();
}

class _SandStroke {
  _SandStroke();

  final List<Offset> points = <Offset>[];
  double grow = 0.0;
}

class _SandZenExperienceState extends State<SandZenExperience>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final List<_SandStroke> _strokes = <_SandStroke>[];
  _SandStroke? _current;

  double _time = 0.0;
  double _lastHaptic = -1.0;
  int _pointCount = 0;

  static const double dt = 1 / 60;
  static const int _maxPoints = 4200;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(_step)
      ..repeat();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_step)
      ..dispose();
    super.dispose();
  }

  void _step() {
    _time += dt;
    for (final s in _strokes) {
      if (s.grow < 1.0) {
        s.grow = min(1.0, s.grow + dt * 4.5);
      }
    }
  }

  void _maybeHaptic() {
    if (_time - _lastHaptic > 0.12) {
      _lastHaptic = _time;
      HapticFeedback.selectionClick();
    }
  }

  void _begin(Offset p) {
    final s = _SandStroke()..points.add(p);
    _current = s;
    _strokes.add(s);
    _pointCount++;
    _maybeHaptic();
    _trim();
  }

  void _extend(Offset p) {
    final s = _current;
    if (s == null) {
      return;
    }
    final last = s.points.isNotEmpty ? s.points.last : null;
    if (last == null || (p - last).distance > 3.0) {
      s.points.add(p);
      _pointCount++;
      _trim();
    }
  }

  void _end() {
    _current = null;
  }

  void _trim() {
    while (_pointCount > _maxPoints && _strokes.length > 1) {
      final removed = _strokes.removeAt(0);
      _pointCount -= removed.points.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            _begin(d.localPosition);
            _end();
          },
          onPanStart: (d) => _begin(d.localPosition),
          onPanUpdate: (d) => _extend(d.localPosition),
          onPanEnd: (_) => _end(),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _SandPainter(strokes: _strokes, time: _time),
              );
            },
          ),
        );
      },
    );
  }
}

class _SandPainter extends CustomPainter {
  _SandPainter({required this.strokes, required this.time});

  final List<_SandStroke> strokes;
  final double time;

  static Color _a(Color c, double o) =>
      c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);

    // Warm sand base gradient.
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFEEDDB6),
          Color(0xFFE3CF9F),
          Color(0xFFD6BC8A),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    _drawGrain(canvas, size);

    // Pebble anchors and their raked concentric rings (drawn beneath grooves).
    final pebbles = <Offset>[
      Offset(size.width * 0.24, size.height * 0.30),
      Offset(size.width * 0.76, size.height * 0.64),
      Offset(size.width * 0.58, size.height * 0.16),
    ];
    final unit = min(size.width, size.height);
    final radii = <double>[unit * 0.052, unit * 0.040, unit * 0.030];
    for (var i = 0; i < pebbles.length; i++) {
      _drawRakedRings(canvas, pebbles[i], radii[i]);
    }

    // Carved grooves.
    for (final s in strokes) {
      _drawGroove(canvas, s);
    }

    // Pebbles rest on top of everything.
    for (var i = 0; i < pebbles.length; i++) {
      _drawPebble(canvas, pebbles[i], radii[i]);
    }

    // Soft vignette to focus the garden.
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: <Color>[
          const Color(0x00000000),
          _a(const Color(0xFF5A4322), 0.16),
        ],
        stops: const <double>[0.7, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  void _drawGrain(Canvas canvas, Size size) {
    final rnd = Random(91);
    final shimmer = 0.04 + 0.02 * sin(time * 1.7);
    final dark = Paint()..color = _a(const Color(0xFF8A6E40), 0.05);
    final light = Paint()..color = _a(const Color(0xFFFFF4D6), shimmer);
    for (var i = 0; i < 240; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.5 + rnd.nextDouble() * 1.1;
      canvas.drawCircle(Offset(x, y), r, rnd.nextBool() ? dark : light);
    }
  }

  void _drawRakedRings(Canvas canvas, Offset c, double r0) {
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = _a(const Color(0xFF9A7E4F), 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    final crest = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _a(const Color(0xFFFCEFC9), 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
    for (var i = 0; i < 6; i++) {
      final r = r0 + 14.0 + i * 13.0;
      canvas.drawCircle(c, r, shadow);
      canvas.drawCircle(c.translate(0, -1.4), r, crest);
    }
  }

  void _drawPebble(Canvas canvas, Offset c, double r) {
    // Soft cast shadow.
    final shadow = Paint()
      ..color = _a(const Color(0xFF4A3718), 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(r * 0.30, r * 0.42),
        width: r * 2.25,
        height: r * 1.5,
      ),
      shadow,
    );

    // Stone body with a directional sheen.
    final body = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.4, -0.5),
        radius: 1.1,
        colors: <Color>[
          Color(0xFFBFC4C9),
          Color(0xFF8B9197),
          Color(0xFF5E646B),
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, body);

    // Pulsing specular glint.
    final glintA = 0.35 + 0.18 * sin(time * 1.3 + c.dx);
    final glint = Paint()
      ..color = _a(const Color(0xFFFFFFFF), glintA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(c.translate(-r * 0.34, -r * 0.40), r * 0.30, glint);
  }

  void _drawGroove(Canvas canvas, _SandStroke s) {
    final pts = s.points;
    if (pts.isEmpty) {
      return;
    }
    final g = s.grow.clamp(0.0, 1.0);

    if (pts.length == 1) {
      _drawDimple(canvas, pts.first, g);
      return;
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) {
      path.lineTo(pts[1].dx, pts[1].dy);
    } else {
      for (var i = 1; i < pts.length - 1; i++) {
        final midX = (pts[i].dx + pts[i + 1].dx) / 2;
        final midY = (pts[i].dy + pts[i + 1].dy) / 2;
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, midX, midY);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
    }

    // Highlighted raised ridges flanking the groove.
    final ridge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 30.0 * (0.7 + 0.3 * g)
      ..color = _a(const Color(0xFFFBEFCB), 0.85 * g)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, ridge);

    // Soft groove shadow.
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 20.0 * (0.7 + 0.3 * g)
      ..color = _a(const Color(0xFF9A7C4A), 0.70 * g)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, shadow);

    // Deep trough core.
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 11.0 * (0.7 + 0.3 * g)
      ..color = _a(const Color(0xFF7C6132), 0.88 * g);
    canvas.drawPath(path, core);

    // Faint center sheen catching the light.
    final sheen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0 * g
      ..color = _a(const Color(0xFFFFF7DD), 0.22 * g)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawPath(path, sheen);
  }

  void _drawDimple(Canvas canvas, Offset c, double g) {
    canvas.drawCircle(
      c,
      15.0 * (0.7 + 0.3 * g),
      Paint()
        ..color = _a(const Color(0xFFFBEFCB), 0.7 * g)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      c,
      9.0 * (0.7 + 0.3 * g),
      Paint()
        ..color = _a(const Color(0xFF9A7C4A), 0.6 * g)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      c,
      5.0 * (0.7 + 0.3 * g),
      Paint()..color = _a(const Color(0xFF7C6132), 0.85 * g),
    );
  }

  @override
  bool shouldRepaint(covariant _SandPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.strokes != strokes;
}
