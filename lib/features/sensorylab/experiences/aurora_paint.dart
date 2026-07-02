import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An interactive night sky where dragging paints glowing aurora ribbons.
///
/// Every stroke becomes a luminous flowing curtain of green/teal/violet/pink
/// light that undulates like a real aurora borealis, slowly drifts upward and
/// fades. The backdrop is a deep starry night with softly twinkling stars and
/// a faint mountain silhouette. Strokes are soft and additive — meditative.
class AuroraPaintExperience extends StatefulWidget {
  const AuroraPaintExperience({super.key});

  @override
  State<AuroraPaintExperience> createState() => _AuroraPaintExperienceState();
}

class _Stroke {
  _Stroke(this.hue, this.phase, this.width);
  final List<Offset> points = <Offset>[];
  final double hue;
  final double phase;
  final double width;
  bool released = false;
  double life = 1.0;
}

class _Star {
  _Star(this.frac, this.size, this.phase, this.speed, this.baseAlpha);
  final Offset frac;
  final double size;
  final double phase;
  final double speed;
  final double baseAlpha;
}

class _AuroraPaintExperienceState extends State<AuroraPaintExperience>
    with SingleTickerProviderStateMixin {
  static const double _dt = 1 / 60;
  static const int _maxStrokes = 12;
  static const int _maxPoints = 64;
  static const double _spacing = 14;
  static const List<double> _palette = <double>[148, 172, 280, 320];

  late final AnimationController _controller;
  final math.Random _rng = math.Random(23);
  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_Star> _stars = <_Star>[];
  _Stroke? _current;
  int _paletteIndex = 0;

  Size _size = Size.zero;
  bool _seeded = false;
  double _time = 0;
  Duration _elapsed = Duration.zero;
  Duration _lastHaptic = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_tick);
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  void _seed(Size size) {
    if (_seeded && size == _size) {
      return;
    }
    _size = size;
    _stars.clear();
    for (int i = 0; i < 90; i++) {
      _stars.add(
        _Star(
          Offset(_rng.nextDouble(), _rng.nextDouble() * 0.72),
          0.6 + _rng.nextDouble() * 1.8,
          _rng.nextDouble() * math.pi * 2,
          0.6 + _rng.nextDouble() * 1.6,
          0.35 + _rng.nextDouble() * 0.55,
        ),
      );
    }
    _seeded = true;
  }

  void _maybeHaptic() {
    if (_elapsed - _lastHaptic > const Duration(milliseconds: 110)) {
      _lastHaptic = _elapsed;
      HapticFeedback.selectionClick();
    }
  }

  double _nextHue() {
    final double h = _palette[_paletteIndex % _palette.length] +
        (_rng.nextDouble() - 0.5) * 16;
    _paletteIndex++;
    return h % 360;
  }

  void _tick() {
    _elapsed += Duration(microseconds: (_dt * 1e6).round());
    if (!_seeded || _size.isEmpty) {
      return;
    }
    _time += _dt;

    for (final _Stroke s in _strokes) {
      // Slow upward drift of the whole curtain.
      for (int i = 0; i < s.points.length; i++) {
        s.points[i] = s.points[i] - const Offset(0, 6) * _dt;
      }
      if (s.released) {
        s.life -= _dt / 6.5;
      }
    }
    _strokes.removeWhere((_Stroke s) => s.life <= 0 || s.points.isEmpty);
  }

  void _startStroke(Offset p) {
    final _Stroke s = _Stroke(_nextHue(), _rng.nextDouble() * math.pi * 2,
        26 + _rng.nextDouble() * 14)
      ..points.add(p);
    _current = s;
    _strokes.add(s);
    while (_strokes.length > _maxStrokes) {
      _strokes.removeAt(0);
    }
    _maybeHaptic();
  }

  void _extendStroke(Offset p) {
    final _Stroke? s = _current;
    if (s == null) {
      return;
    }
    final Offset last = s.points.last;
    if ((p - last).distance >= _spacing) {
      s.points.add(p);
      if (s.points.length > _maxPoints) {
        s.points.removeAt(0);
      }
      _maybeHaptic();
    }
  }

  void _endStroke() {
    _current?.released = true;
    _current = null;
  }

  void _tap(Offset p) {
    final _Stroke s = _Stroke(_nextHue(), _rng.nextDouble() * math.pi * 2, 30)
      ..points.add(p)
      ..points.add(p + const Offset(0.5, 0))
      ..released = true;
    _strokes.add(s);
    while (_strokes.length > _maxStrokes) {
      _strokes.removeAt(0);
    }
    _maybeHaptic();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        _seed(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => _tap(d.localPosition),
          onPanStart: (DragStartDetails d) => _startStroke(d.localPosition),
          onPanUpdate: (DragUpdateDetails d) => _extendStroke(d.localPosition),
          onPanEnd: (DragEndDetails d) => _endStroke(),
          onPanCancel: _endStroke,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _AuroraPainter(
                  strokes: _strokes,
                  stars: _stars,
                  time: _time,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.strokes,
    required this.stars,
    required this.time,
  });

  final List<_Stroke> strokes;
  final List<_Star> stars;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Deep night sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF050A1E),
            Color(0xFF071427),
            Color(0xFF020308),
          ],
          stops: <double>[0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    _paintStars(canvas, size);
    _paintAurora(canvas);
    _paintMountains(canvas, size);
  }

  void _paintStars(Canvas canvas, Size size) {
    final Paint glow = Paint()..blendMode = BlendMode.plus;
    for (final _Star s in stars) {
      final double tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(time * s.speed + s.phase));
      final Offset p = Offset(s.frac.dx * size.width, s.frac.dy * size.height);
      glow.color = Colors.white.withOpacity(s.baseAlpha * tw);
      canvas.drawCircle(p, s.size, glow);
      if (s.size > 1.4) {
        glow.color = Colors.white.withOpacity(0.12 * tw);
        canvas.drawCircle(p, s.size * 3.2, glow);
      }
    }
  }

  void _paintAurora(Canvas canvas) {
    for (final _Stroke s in strokes) {
      final int n = s.points.length;
      if (n == 0) {
        continue;
      }
      final Color base = HSVColor.fromAHSV(1, s.hue, 0.7, 1).toColor();
      final Color bright =
          Color.lerp(base, Colors.white, 0.55)!;
      final double curtainH = 150 + s.width * 2.2;

      // Wavy, undulating sample points.
      final List<Offset> wp = List<Offset>.generate(n, (int i) {
        final Offset p = s.points[i];
        final double sway =
            math.sin(p.dy * 0.011 + time * 1.6 + s.phase + i * 0.18) * 16;
        return Offset(p.dx + sway, p.dy);
      });

      // Vertical light curtain rising from each sample point.
      final Paint bar = Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.5)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width;
      for (int i = 0; i < n; i += 2) {
        final Offset b = wp[i];
        final double topSway =
            math.sin(time * 1.2 + i * 0.3 + s.phase) * 22;
        final Offset top = b + Offset(topSway, -curtainH);
        final Rect r = Rect.fromPoints(b, top).inflate(s.width);
        bar.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            base.withOpacity(0.0),
            base.withOpacity(0.42 * s.life),
            bright.withOpacity(0.0),
          ],
          stops: const <double>[0.0, 0.35, 1.0],
        ).createShader(r);
        canvas.drawLine(b, top, bar);
      }

      // Cohesive flowing baseline ribbon.
      if (n >= 2) {
        final Path path = Path()..moveTo(wp[0].dx, wp[0].dy);
        for (int i = 1; i < n; i++) {
          final Offset m = (wp[i - 1] + wp[i]) / 2;
          path.quadraticBezierTo(wp[i - 1].dx, wp[i - 1].dy, m.dx, m.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.plus
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = s.width * 0.9
            ..color = base.withOpacity(0.32 * s.life)
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, s.width * 0.7),
        );
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.plus
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2.0
            ..color = bright.withOpacity(0.5 * s.life)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
      } else {
        // Single-tap soft bloom.
        canvas.drawCircle(
          wp[0],
          s.width,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = base.withOpacity(0.4 * s.life)
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, s.width * 0.8),
        );
      }
    }
  }

  void _paintMountains(Canvas canvas, Size size) {
    final double h = size.height;
    final double w = size.width;
    final double baseY = h * 0.86;
    final Path m = Path()..moveTo(0, h);
    m.lineTo(0, baseY);
    final List<double> peaks = <double>[0.0, 0.16, 0.34, 0.52, 0.7, 0.85, 1.0];
    final List<double> heights = <double>[
      0.0,
      0.07,
      0.02,
      0.10,
      0.03,
      0.06,
      0.0,
    ];
    for (int i = 0; i < peaks.length; i++) {
      m.lineTo(peaks[i] * w, baseY - heights[i] * h);
    }
    m.lineTo(w, h);
    m.close();
    canvas.drawPath(
      m,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFF0A1424).withOpacity(0.96),
            const Color(0xFF02040A),
          ],
        ).createShader(Rect.fromLTRB(0, baseY - h * 0.12, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => true;
}
