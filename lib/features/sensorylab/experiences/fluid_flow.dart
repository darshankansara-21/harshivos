import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A premium, hypnotic fluid-flow sensory experience.
///
/// Hundreds of glowing fluid particles ride a swirling velocity field, leaving
/// soft blurred ribbons of slowly shifting rainbow colour. Dragging a finger
/// pushes the fluid, carving vortices and currents — like luminous ink in water.
class FluidFlowExperience extends StatefulWidget {
  const FluidFlowExperience({super.key});

  @override
  State<FluidFlowExperience> createState() => _FluidFlowExperienceState();
}

class _FluidFlowExperienceState extends State<FluidFlowExperience>
    with SingleTickerProviderStateMixin {
  static const double _dt = 1 / 60;
  static const int _count = 200;
  static const int _trailLen = 7;

  late final AnimationController _controller;
  final math.Random _rng = math.Random(7);
  final List<_FluidParticle> _particles = <_FluidParticle>[];

  Size _size = Size.zero;
  bool _seeded = false;
  double _time = 0;

  Offset? _touch;
  Offset _touchVel = Offset.zero;
  Offset _lastTouch = Offset.zero;
  Duration _lastHaptic = Duration.zero;
  Duration _elapsed = Duration.zero;

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
    _particles.clear();
    for (int i = 0; i < _count; i++) {
      final Offset p = Offset(
        _rng.nextDouble() * size.width,
        _rng.nextDouble() * size.height,
      );
      _particles.add(
        _FluidParticle(
          position: p,
          hue: _rng.nextDouble() * 360,
          history: List<Offset>.filled(_trailLen, p, growable: true),
        ),
      );
    }
    _seeded = true;
  }

  void _tick() {
    _elapsed += Duration(microseconds: (_dt * 1e6).round());
    if (!_seeded || _size.isEmpty) {
      return;
    }
    _time += _dt;

    final double w = _size.width;
    final double h = _size.height;
    final Offset? touch = _touch;

    // Velocity field swirl parameters.
    final double t = _time;
    for (final _FluidParticle p in _particles) {
      final double x = p.position.dx;
      final double y = p.position.dy;

      // Two-octave curl-like flow field for organic swirls.
      final double a1 = t * 0.20 +
          math.sin(x * 0.0090 + t * 0.30) * 1.7 +
          math.cos(y * 0.0090 - t * 0.22) * 1.7;
      final double a2 = math.sin(y * 0.0180 - t * 0.45) * 1.4 +
          math.cos(x * 0.0180 + t * 0.18) * 1.4;
      final double angle = a1 + a2 * 0.5;

      Offset flow = Offset(math.cos(angle), math.sin(angle)) * 46.0;

      // Touch interaction: push + swirl around the finger.
      if (touch != null) {
        final Offset rel = p.position - touch;
        final double dist = rel.distance;
        const double radius = 190.0;
        if (dist < radius) {
          final double fall = 1.0 - (dist / radius);
          final double f = fall * fall;
          // Push along finger movement.
          flow += _touchVel * (3.4 * f);
          // Tangential swirl for vortices.
          final Offset n = dist > 0.001 ? rel / dist : const Offset(1, 0);
          final Offset tangent = Offset(-n.dy, n.dx);
          flow += tangent * (260.0 * f);
        }
      }

      // Ease velocity toward field for smooth, liquid motion.
      p.velocity = Offset.lerp(p.velocity, flow, 0.14)!;

      Offset next = p.position + p.velocity * _dt * 3.2;

      // Continuous wrap; reset history on wrap to avoid streaks.
      bool wrapped = false;
      double nx = next.dx;
      double ny = next.dy;
      if (nx < -8) {
        nx += w + 16;
        wrapped = true;
      } else if (nx > w + 8) {
        nx -= w + 16;
        wrapped = true;
      }
      if (ny < -8) {
        ny += h + 16;
        wrapped = true;
      } else if (ny > h + 8) {
        ny -= h + 16;
        wrapped = true;
      }
      next = Offset(nx, ny);
      p.position = next;

      // Slowly drift hue with speed for living colour.
      p.hue += (0.10 + p.velocity.distance * 0.012);
      if (p.hue >= 360) {
        p.hue -= 360;
      }

      if (wrapped) {
        for (int i = 0; i < p.history.length; i++) {
          p.history[i] = next;
        }
      } else {
        p.history.removeAt(0);
        p.history.add(next);
      }
    }

    // Decay touch velocity so currents settle gracefully.
    _touchVel = _touchVel * 0.86;
  }

  void _maybeHaptic() {
    if (_elapsed - _lastHaptic > const Duration(milliseconds: 120)) {
      _lastHaptic = _elapsed;
      HapticFeedback.selectionClick();
    }
  }

  void _onPanStart(DragStartDetails d) {
    _touch = d.localPosition;
    _lastTouch = d.localPosition;
    _touchVel = Offset.zero;
    _maybeHaptic();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final Offset p = d.localPosition;
    _touchVel = (p - _lastTouch) / _dt;
    _lastTouch = p;
    _touch = p;
  }

  void _onPanEnd(DragEndDetails d) {
    _touch = null;
  }

  void _onTapDown(TapDownDetails d) {
    _touch = d.localPosition;
    _lastTouch = d.localPosition;
    _touchVel = const Offset(0, -1200);
    _maybeHaptic();
  }

  void _onTapUp(TapUpDetails d) {
    _touch = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        if (!_seeded || _size != size) {
          _size = size;
          _seed(size);
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _FluidPainter(
                  particles: _particles,
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

class _FluidParticle {
  _FluidParticle({
    required this.position,
    required this.hue,
    required this.history,
  });

  Offset position;
  Offset velocity = Offset.zero;
  double hue;
  final List<Offset> history;
}

class _FluidPainter extends CustomPainter {
  _FluidPainter({required this.particles, required this.time});

  final List<_FluidParticle> particles;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    // Deep, near-black background with a faint cool glow.
    final Rect rect = Offset.zero & size;
    final Paint bg = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: <Color>[
          Color(0xFF0A0E1A),
          Color(0xFF05060C),
          Color(0xFF010103),
        ],
        stops: <double>[0.0, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Layered additive ribbons.
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.plus;

    for (final _FluidParticle p in particles) {
      final List<Offset> h = p.history;
      if (h.length < 2) {
        continue;
      }
      final Path path = Path()..moveTo(h.first.dx, h.first.dy);
      for (int i = 1; i < h.length; i++) {
        path.lineTo(h[i].dx, h[i].dy);
      }

      final Color core = HSVColor.fromAHSV(1.0, p.hue % 360, 0.85, 1.0).toColor();

      // Wide soft halo.
      glow
        ..color = core.withOpacity(0.06)
        ..strokeWidth = 16
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawPath(path, glow);

      // Mid ribbon.
      glow
        ..color = core.withOpacity(0.16)
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glow);

      // Bright core.
      glow
        ..color = core.withOpacity(0.55)
        ..strokeWidth = 2.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
      canvas.drawPath(path, glow);

      // Glowing head.
      final Paint head = Paint()
        ..color = Color.lerp(core, Colors.white, 0.35)!.withOpacity(0.85)
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(p.position, 2.6, head);
    }
  }

  @override
  bool shouldRepaint(covariant _FluidPainter oldDelegate) => true;
}
