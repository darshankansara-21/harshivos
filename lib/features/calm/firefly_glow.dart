import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Firefly Glow — a warm, no-fail *hold* calm experience.
///
/// Dozens of soft fireflies drift through a dusk meadow. Pressing and holding
/// gently draws the nearest ones toward the fingertip, where they gather and
/// glow brighter; lifting the finger lets them wander free again. Nothing is
/// scored or timed — it is a slow, gathering kind of quiet.
class FireflyGlowToy extends StatefulWidget {
  const FireflyGlowToy({super.key});

  @override
  State<FireflyGlowToy> createState() => _FireflyGlowToyState();
}

class _FireflyGlowToyState extends State<FireflyGlowToy>
    with SingleTickerProviderStateMixin {
  final math.Random _rng = math.Random();
  late final AnimationController _controller;
  final List<_Firefly> _flies = <_Firefly>[];
  Offset? _touch; // normalized 0..1
  double _seconds = 0;
  double _last = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..addListener(_tick);
    _controller.repeat();
    _flies.addAll(List<_Firefly>.generate(38, (int i) {
      return _Firefly(
        pos: Offset(_rng.nextDouble(), _rng.nextDouble()),
        vel: Offset((_rng.nextDouble() - 0.5) * 0.02,
            (_rng.nextDouble() - 0.5) * 0.02),
        phase: _rng.nextDouble() * math.pi * 2,
        hue: _rng.nextDouble(),
      );
    }));
  }

  void _tick() {
    final double now = _controller.lastElapsedDuration == null
        ? _seconds
        : _controller.lastElapsedDuration!.inMicroseconds / 1e6;
    final double dt = (now - _last).clamp(0.0, 0.05);
    _last = now;
    _seconds = now;
    for (final _Firefly f in _flies) {
      // Gentle random wander.
      f.vel += Offset((_rng.nextDouble() - 0.5) * 0.006,
          (_rng.nextDouble() - 0.5) * 0.006);
      if (_touch != null) {
        final Offset to = _touch! - f.pos;
        final double d = to.distance;
        if (d < 0.42 && d > 0.001) {
          // Ease toward the finger, stronger when nearer.
          final double pull = (0.42 - d) * 0.9;
          f.vel += Offset(to.dx / d, to.dy / d) * pull * dt * 2.4;
        }
      }
      // Damping keeps motion soft and slow.
      f.vel = f.vel * 0.94;
      final double sp = f.vel.distance;
      if (sp > 0.06) f.vel = f.vel * (0.06 / sp);
      f.pos += f.vel * dt * 8;
      // Soft-wrap at the edges.
      f.pos = Offset(f.pos.dx % 1.0, f.pos.dy % 1.0);
      if (f.pos.dx < 0) f.pos = Offset(f.pos.dx + 1, f.pos.dy);
      if (f.pos.dy < 0) f.pos = Offset(f.pos.dx, f.pos.dy + 1);
    }
    if (mounted) setState(() {});
  }

  void _setTouch(Offset local, Size size) {
    setState(() => _touch = Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final Size size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (DragDownDetails d) {
            HapticFeedback.selectionClick();
            _setTouch(d.localPosition, size);
          },
          onPanUpdate: (DragUpdateDetails d) => _setTouch(d.localPosition, size),
          onPanEnd: (_) => setState(() => _touch = null),
          onPanCancel: () => setState(() => _touch = null),
          child: CustomPaint(
            size: size,
            painter: _FireflyPainter(
              flies: _flies,
              seconds: _seconds,
              touch: _touch,
            ),
          ),
        );
      },
    );
  }
}

class _Firefly {
  _Firefly({
    required this.pos,
    required this.vel,
    required this.phase,
    required this.hue,
  });
  Offset pos;
  Offset vel;
  final double phase;
  final double hue;
}

class _FireflyPainter extends CustomPainter {
  _FireflyPainter({
    required this.flies,
    required this.seconds,
    required this.touch,
  });

  final List<_Firefly> flies;
  final double seconds;
  final Offset? touch;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF10241E), Color(0xFF1B1636)],
        ).createShader(rect),
    );

    for (final _Firefly f in flies) {
      final Offset p = Offset(f.pos.dx * size.width, f.pos.dy * size.height);
      final double pulse = 0.55 + 0.45 * math.sin(seconds * 2.2 + f.phase);
      double bright = pulse;
      if (touch != null) {
        final double d = (touch! - f.pos).distance;
        if (d < 0.3) bright = (bright + (0.3 - d) * 3).clamp(0.0, 1.4);
      }
      final Color glow = Color.lerp(
        const Color(0xFFB6FF9E),
        const Color(0xFFFFF1A6),
        f.hue,
      )!;
      canvas.drawCircle(
        p,
        9 + 6 * bright,
        Paint()
          ..color = glow.withOpacity(0.18 * bright)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        p,
        2.2 + 1.6 * bright,
        Paint()..color = glow.withOpacity(0.95),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FireflyPainter old) => true;
}
