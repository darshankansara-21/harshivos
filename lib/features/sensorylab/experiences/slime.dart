import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A big, squishy, jiggly slime blob you can pull, stretch and squash.
///
/// The blob is a soft body: a ring of mass points held around a centre by
/// radial springs and to their neighbours by structural springs, rendered as
/// one smooth closed gooey shape with a glossy highlight, rim light, inner
/// bubbles and a soft outer glow. Dragging stretches the slime toward your
/// finger into a gooey tendril; releasing lets it spring back with a
/// satisfying wobble. Tapping squashes it and sends a ripple through the goo.
/// The colour slowly drifts through translucent greens and teals.
class SlimeExperience extends StatefulWidget {
  const SlimeExperience({super.key});

  @override
  State<SlimeExperience> createState() => _SlimeExperienceState();
}

class _Node {
  _Node(this.pos, this.angle);
  Offset pos;
  Offset vel = Offset.zero;
  final double angle;
}

class _Bubble {
  _Bubble(this.rel, this.vel, this.radius);
  Offset rel; // position relative to blob centre
  Offset vel;
  double radius;
}

class _SlimeExperienceState extends State<SlimeExperience>
    with SingleTickerProviderStateMixin {
  static const double _dt = 1 / 60;
  static const int _count = 36;

  late final AnimationController _controller;
  final math.Random _rng = math.Random(11);
  final List<_Node> _nodes = <_Node>[];
  final List<_Bubble> _bubbles = <_Bubble>[];

  Size _size = Size.zero;
  Offset _center = Offset.zero;
  double _radius = 120;
  bool _seeded = false;
  double _time = 0;

  Offset? _touch;
  bool _dragging = false;
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

  void _layout(Size size) {
    _center = Offset(size.width / 2, size.height * 0.5);
    _radius = math.min(size.width, size.height) * 0.27;
    if (_seeded && size == _size) {
      return;
    }
    _size = size;
    _nodes.clear();
    for (int i = 0; i < _count; i++) {
      final double a = (i / _count) * math.pi * 2;
      final Offset p =
          _center + Offset(math.cos(a), math.sin(a)) * _radius;
      _nodes.add(_Node(p, a));
    }
    _bubbles.clear();
    for (int i = 0; i < 6; i++) {
      final double a = _rng.nextDouble() * math.pi * 2;
      final double rr = _rng.nextDouble() * _radius * 0.5;
      _bubbles.add(
        _Bubble(
          Offset(math.cos(a), math.sin(a)) * rr,
          Offset(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5) * 10,
          7 + _rng.nextDouble() * 13,
        ),
      );
    }
    _seeded = true;
  }

  void _maybeHaptic() {
    if (_elapsed - _lastHaptic > const Duration(milliseconds: 90)) {
      _lastHaptic = _elapsed;
      HapticFeedback.selectionClick();
    }
  }

  void _tick() {
    _elapsed += Duration(microseconds: (_dt * 1e6).round());
    if (!_seeded || _size.isEmpty) {
      return;
    }
    _time += _dt;

    final double restChord = 2 * _radius * math.sin(math.pi / _count);
    final double sigma = _radius * 0.85;

    for (int i = 0; i < _count; i++) {
      final _Node n = _nodes[i];
      // Gentle breathing so the goo always feels alive.
      final double breathe =
          1 + math.sin(_time * 1.5 + n.angle * 2) * 0.02;
      final Offset rest = _center +
          Offset(math.cos(n.angle), math.sin(n.angle)) * _radius * breathe;

      Offset force = (rest - n.pos) * 70.0;

      // Neighbour structural springs keep the surface smooth and gooey.
      for (final int j in <int>[
        (i - 1 + _count) % _count,
        (i + 1) % _count,
      ]) {
        final Offset d = _nodes[j].pos - n.pos;
        final double dist = d.distance;
        if (dist > 1e-3) {
          force += (d / dist) * (dist - restChord) * 150.0;
        }
      }

      // Dragging pulls nearby surface toward the finger -> a gooey tendril.
      final Offset? touch = _touch;
      if (_dragging && touch != null) {
        final Offset d = touch - n.pos;
        final double dist = d.distance;
        final double w = math.exp(-(dist * dist) / (2 * sigma * sigma));
        force += d * 30.0 * w;
      }

      n.vel += force * _dt;
      n.vel *= 0.90;
      final double sp = n.vel.distance;
      const double maxV = 2800.0;
      if (sp > maxV) {
        n.vel = n.vel / sp * maxV;
      }
      n.pos += n.vel * _dt;
    }

    // Bubbles drift and bounce inside the blob.
    final double limit = _radius * 0.6;
    for (final _Bubble b in _bubbles) {
      Offset next = b.rel +
          b.vel * _dt +
          Offset(
                math.sin(_time * 0.8 + b.radius),
                math.cos(_time * 0.7 + b.radius),
              ) *
              0.4;
      final double d = next.distance;
      if (d > limit - b.radius && d > 1e-3) {
        final Offset nrm = next / d;
        final double vn = b.vel.dx * nrm.dx + b.vel.dy * nrm.dy;
        b.vel = b.vel - nrm * (2 * vn);
        next = nrm * (limit - b.radius);
      }
      b.rel = next;
    }
  }

  void _onTap(Offset local) {
    if (!_seeded) {
      return;
    }
    _maybeHaptic();
    final double s2 = _radius * 0.8 * _radius * 0.8;
    for (final _Node n in _nodes) {
      final Offset inward = _center - n.pos;
      final double dist = inward.distance;
      final Offset dir = dist > 1e-3 ? inward / dist : Offset.zero;
      final Offset toTap = local - n.pos;
      final double near = math.exp(-(toTap.distanceSquared) / (2 * s2));
      final double ripple = 0.6 + 0.4 * math.sin(n.angle * 3 + _time);
      n.vel += dir * (300 + 460 * near) * ripple;
    }
    for (final _Bubble b in _bubbles) {
      b.vel += Offset(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5) * 80;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        _layout(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => _onTap(d.localPosition),
          onPanStart: (DragStartDetails d) {
            _dragging = true;
            _touch = d.localPosition;
            _maybeHaptic();
          },
          onPanUpdate: (DragUpdateDetails d) => _touch = d.localPosition,
          onPanEnd: (DragEndDetails d) {
            _dragging = false;
            _touch = null;
          },
          onPanCancel: () {
            _dragging = false;
            _touch = null;
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _SlimePainter(
                  nodes: _nodes,
                  bubbles: _bubbles,
                  center: _center,
                  radius: _radius,
                  time: _time,
                  seeded: _seeded,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SlimePainter extends CustomPainter {
  _SlimePainter({
    required this.nodes,
    required this.bubbles,
    required this.center,
    required this.radius,
    required this.time,
    required this.seeded,
  });

  final List<_Node> nodes;
  final List<_Bubble> bubbles;
  final Offset center;
  final double radius;
  final double time;
  final bool seeded;

  Path _blobPath() {
    final Path path = Path();
    final int n = nodes.length;
    if (n < 3) {
      return path;
    }
    Offset mid(Offset a, Offset b) => (a + b) / 2;
    final Offset start = mid(nodes[n - 1].pos, nodes[0].pos);
    path.moveTo(start.dx, start.dy);
    for (int i = 0; i < n; i++) {
      final Offset cur = nodes[i].pos;
      final Offset m = mid(cur, nodes[(i + 1) % n].pos);
      path.quadraticBezierTo(cur.dx, cur.dy, m.dx, m.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint bg = Paint()
      ..shader = const RadialGradient(
        radius: 1.15,
        colors: <Color>[
          Color(0xFF0A2B2B),
          Color(0xFF051620),
          Color(0xFF02060B),
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    if (!seeded || nodes.length < 3) {
      return;
    }

    final double hue = (time * 16) % 360;
    final Color base = HSVColor.fromAHSV(1, hue, 0.62, 0.95).toColor();
    final Color deep =
        HSVColor.fromAHSV(1, (hue + 22) % 360, 0.82, 0.6).toColor();
    final Path path = _blobPath();

    // Soft outer glow.
    canvas.drawPath(
      path,
      Paint()
        ..color = base.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
    );

    // Glossy translucent body.
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.05,
          colors: <Color>[
            Color.lerp(base, Colors.white, 0.4)!.withOpacity(0.96),
            base.withOpacity(0.92),
            deep.withOpacity(0.94),
          ],
          stops: const <double>[0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: radius * 1.5),
        ),
    );

    // Bubbles and gloss are clipped to the goo body.
    canvas.save();
    canvas.clipPath(path);

    for (final _Bubble b in bubbles) {
      final Offset bp = center + b.rel;
      canvas.drawCircle(
        bp,
        b.radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.white.withOpacity(0.45),
              base.withOpacity(0.04),
            ],
          ).createShader(Rect.fromCircle(center: bp, radius: b.radius)),
      );
      canvas.drawCircle(
        bp - Offset(b.radius * 0.3, b.radius * 0.3),
        b.radius * 0.26,
        Paint()..color = Colors.white.withOpacity(0.6),
      );
    }

    final Rect glossRect = Rect.fromCenter(
      center: center + Offset(-radius * 0.28, -radius * 0.44),
      width: radius * 1.2,
      height: radius * 0.72,
    );
    canvas.drawOval(
      glossRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withOpacity(0.75),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(glossRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.restore();

    // Bright rim light.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(covariant _SlimePainter oldDelegate) => true;
}
