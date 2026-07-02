import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A magnetic playground. Hundreds of tiny iron filings rest on a dark surface.
/// Touching or dragging becomes a magnet: nearby filings are drawn in, align
/// along the magnetic field lines pointing at the finger, and clump into
/// flowing whisker chains that trail the magnet. Releasing lets them settle
/// where they lie. A glossy magnet glow marks the touch point.
class MagnetPlayExperience extends StatefulWidget {
  const MagnetPlayExperience({super.key});

  @override
  State<MagnetPlayExperience> createState() => _MagnetPlayExperienceState();
}

class _Filing {
  _Filing(this.x, this.y, this.angle);

  double x;
  double y;
  double vx = 0.0;
  double vy = 0.0;
  double angle;
}

class _MagnetPlayExperienceState extends State<MagnetPlayExperience>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final List<_Filing> _filings = <_Filing>[];
  final Random _rnd = Random(42);

  Size _size = Size.zero;
  Offset? _touch;
  bool _panActive = false;
  double _tapHold = 0.0;
  double _time = 0.0;
  double _lastHaptic = -1.0;

  static const double dt = 1 / 60;
  static const int _count = 440;
  static const double _influence = 190.0;
  static const double _core = 26.0;
  static const double _reach = 4400.0;
  static const double _repel = 5200.0;
  static const double _alignRate = 0.26;

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

  void _seed(Size size) {
    _filings.clear();
    for (var i = 0; i < _count; i++) {
      _filings.add(
        _Filing(
          _rnd.nextDouble() * size.width,
          _rnd.nextDouble() * size.height,
          _rnd.nextDouble() * pi * 2,
        ),
      );
    }
  }

  void _ensure(Size size) {
    if (size.isEmpty) {
      return;
    }
    if (_filings.isEmpty ||
        (size.width - _size.width).abs() > 1.0 ||
        (size.height - _size.height).abs() > 1.0) {
      _size = size;
      _seed(size);
    }
  }

  bool get _magnetOn => _panActive || _tapHold > 0.0;

  void _step() {
    _time += dt;
    if (_tapHold > 0.0) {
      _tapHold = max(0.0, _tapHold - dt);
    }
    if (_filings.isEmpty || _size.isEmpty) {
      return;
    }

    final m = _touch;
    final active = _magnetOn && m != null;
    final friction = active ? 0.85 : 0.80;

    for (final f in _filings) {
      if (active) {
        final dx = m.dx - f.x;
        final dy = m.dy - f.y;
        final d = sqrt(dx * dx + dy * dy) + 1e-3;
        if (d < _influence) {
          final n = 1.0 - d / _influence;
          final pull = n * n * _reach;
          var ax = dx / d * pull;
          var ay = dy / d * pull;
          if (d < _core) {
            final push = (_core - d) / _core * _repel;
            ax -= dx / d * push;
            ay -= dy / d * push;
          }
          f.vx += ax * dt;
          f.vy += ay * dt;
          f.angle = _approach(f.angle, atan2(dy, dx), _alignRate);
        }
      }

      f.vx *= friction;
      f.vy *= friction;
      f.x += f.vx * dt;
      f.y += f.vy * dt;

      // Soft containment so filings stay on the surface.
      if (f.x < 0) {
        f.x = 0;
        f.vx = -f.vx * 0.4;
      } else if (f.x > _size.width) {
        f.x = _size.width;
        f.vx = -f.vx * 0.4;
      }
      if (f.y < 0) {
        f.y = 0;
        f.vy = -f.vy * 0.4;
      } else if (f.y > _size.height) {
        f.y = _size.height;
        f.vy = -f.vy * 0.4;
      }
    }
  }

  double _approach(double a, double target, double rate) {
    var diff = target - a;
    while (diff > pi) {
      diff -= pi * 2;
    }
    while (diff < -pi) {
      diff += pi * 2;
    }
    return a + diff * rate;
  }

  void _maybeHaptic() {
    if (_time - _lastHaptic > 0.12) {
      _lastHaptic = _time;
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _ensure(constraints.biggest);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            _touch = d.localPosition;
            _tapHold = 0.35;
            _maybeHaptic();
          },
          onPanStart: (d) {
            _panActive = true;
            _touch = d.localPosition;
            _maybeHaptic();
          },
          onPanUpdate: (d) => _touch = d.localPosition,
          onPanEnd: (_) => _panActive = false,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _MagnetPainter(
                  filings: _filings,
                  magnet: _magnetOn ? _touch : null,
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

class _MagnetPainter extends CustomPainter {
  _MagnetPainter({
    required this.filings,
    required this.magnet,
    required this.time,
  });

  final List<_Filing> filings;
  final Offset? magnet;
  final double time;

  static const double _influence = 190.0;

  static Color _a(Color c, double o) =>
      c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);

    // Dark brushed-metal surface.
    final bg = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: <Color>[Color(0xFF161B22), Color(0xFF0B0E13)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final m = magnet;

    // Faint magnetic field rings to telegraph the magnet's pull.
    if (m != null) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (var i = 1; i <= 4; i++) {
        final r = _influence * (i / 4.0);
        ring.color = _a(const Color(0xFF5FB7FF), 0.10 * (1 - i / 5.0));
        canvas.drawCircle(m, r, ring);
      }
    }

    // Filings. Brightness and a soft glow ramp up near the magnet.
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    final sheen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (final f in filings) {
      const len = 7.0;
      final dx = cos(f.angle) * len * 0.5;
      final dy = sin(f.angle) * len * 0.5;
      final p1 = Offset(f.x - dx, f.y - dy);
      final p2 = Offset(f.x + dx, f.y + dy);

      var proximity = 0.0;
      if (m != null) {
        final d = (m - Offset(f.x, f.y)).distance;
        if (d < _influence) {
          proximity = 1.0 - d / _influence;
        }
      }

      if (proximity > 0.25) {
        glow.color = _a(const Color(0xFF8FD0FF), 0.30 * proximity);
        canvas.drawLine(p1, p2, glow);
      }

      base.color = Color.lerp(
        const Color(0xFF7C848E),
        const Color(0xFFE9F3FF),
        proximity,
      )!;
      canvas.drawLine(p1, p2, base);

      sheen.color = _a(const Color(0xFFFFFFFF), 0.18 + 0.5 * proximity);
      canvas.drawLine(
        Offset(f.x - dx * 0.5, f.y - dy * 0.5),
        Offset(f.x + dx * 0.5, f.y + dy * 0.5),
        sheen,
      );
    }

    // Glossy magnet head with a pulsing glow.
    if (m != null) {
      final pulse = 1.0 + 0.06 * sin(time * 6.0);
      final halo = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _a(const Color(0xFF8FD0FF), 0.55),
            _a(const Color(0xFF2B6CFF), 0.18),
            const Color(0x00000000),
          ],
          stops: const <double>[0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: m, radius: 78 * pulse));
      canvas.drawCircle(m, 78 * pulse, halo);

      final orb = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFBFE3FF),
            Color(0xFF3E8BFF),
          ],
          stops: <double>[0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: m, radius: 16));
      canvas.drawCircle(m, 16, orb);

      canvas.drawCircle(
        m.translate(-5, -6),
        4.5,
        Paint()..color = _a(const Color(0xFFFFFFFF), 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MagnetPainter oldDelegate) => true;
}
