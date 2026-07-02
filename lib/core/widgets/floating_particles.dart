import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft, slow floating particles layered over the background for depth.
class FloatingParticles extends StatefulWidget {
  const FloatingParticles({super.key, this.count = 36});

  final int count;

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final math.Random _rnd = math.Random(7);

  @override
  void initState() {
    super.initState();
    _particles = List<_Particle>.generate(
      widget.count,
      (_) => _Particle.random(_rnd),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ParticlePainter(_particles, _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  _Particle(this.x, this.y, this.radius, this.speed, this.opacity, this.drift);

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double opacity;
  final double drift;

  factory _Particle.random(math.Random r) => _Particle(
        r.nextDouble(),
        r.nextDouble(),
        1.0 + r.nextDouble() * 3.0,
        0.4 + r.nextDouble() * 0.8,
        0.15 + r.nextDouble() * 0.45,
        (r.nextDouble() - 0.5) * 0.08,
      );
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (final p in particles) {
      // Particles drift upward and wrap around.
      var y = (p.y - t * p.speed) % 1.0;
      if (y < 0) y += 1.0;
      final x = (p.x + math.sin((t + p.x) * math.pi * 2) * p.drift) % 1.0;
      paint.color = Colors.white.withOpacity(p.opacity * 0.7);
      canvas.drawCircle(Offset(x * size.width, y * size.height), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => oldDelegate.t != t;
}
