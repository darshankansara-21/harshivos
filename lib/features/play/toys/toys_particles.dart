import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/toy/toy_ticker.dart';

/// Shared HSV rainbow helper.
Color rainbow(double t, {double s = 0.8, double v = 1.0, double opacity = 1}) =>
    HSVColor.fromAHSV(opacity, (t * 360) % 360, s, v).toColor();

// ===========================================================================
// Particle Galaxy — tap explodes stars that swirl; drag attracts them.
// ===========================================================================
class ParticleGalaxyToy extends StatefulWidget {
  const ParticleGalaxyToy({super.key});
  @override
  State<ParticleGalaxyToy> createState() => _ParticleGalaxyToyState();
}

class _ParticleGalaxyToyState extends State<ParticleGalaxyToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Star> _stars = <_Star>[];
  final math.Random _r = math.Random();
  Offset? _attractor;
  double _hue = 0;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 140; i++) {
      _stars.add(_Star.ambient(_r));
    }
  }

  void _burst(Offset p) {
    HapticFeedback.lightImpact();
    for (var i = 0; i < 40; i++) {
      final a = _r.nextDouble() * math.pi * 2;
      final speed = 60 + _r.nextDouble() * 220;
      _stars.add(_Star(
        pos: p,
        vel: Offset(math.cos(a), math.sin(a)) * speed,
        color: rainbow(_hue + _r.nextDouble() * 0.1),
        size: 1.5 + _r.nextDouble() * 3,
        life: 1.0,
        ambient: false,
      ));
    }
    _hue = (_hue + 0.08) % 1.0;
  }

  @override
  void onTick(double dt) {
    final size = context.size ?? Size.zero;
    final center = size.center(Offset.zero);
    _stars.removeWhere((s) => !s.ambient && s.life <= 0);
    for (final s in _stars) {
      // Gentle galactic swirl around the centre.
      final toCenter = center - s.pos;
      final dist = toCenter.distance.clamp(20.0, 4000.0);
      final tangent = Offset(-toCenter.dy, toCenter.dx) / dist;
      s.vel += tangent * (s.ambient ? 18 : 30) * dt;
      if (_attractor != null) {
        final toA = _attractor! - s.pos;
        s.vel += toA / toA.distance.clamp(40.0, 4000.0) * 600 * dt;
      }
      s.vel *= s.ambient ? 0.999 : 0.985;
      s.pos += s.vel * dt;
      if (!s.ambient) s.life -= dt * 0.4;
      // Wrap ambient stars to keep the galaxy full.
      if (s.ambient) {
        if (s.pos.dx < 0) s.pos = Offset(size.width, s.pos.dy);
        if (s.pos.dx > size.width) s.pos = Offset(0, s.pos.dy);
        if (s.pos.dy < 0) s.pos = Offset(s.pos.dx, size.height);
        if (s.pos.dy > size.height) s.pos = Offset(s.pos.dx, 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _attractor = e.localPosition;
        _burst(e.localPosition);
      },
      onPointerMove: (e) => _attractor = e.localPosition,
      onPointerUp: (_) => _attractor = null,
      child: CustomPaint(
        painter: _GalaxyPainter(_stars),
        size: Size.infinite,
      ),
    );
  }
}

class _Star {
  _Star({
    required this.pos,
    required this.vel,
    required this.color,
    required this.size,
    required this.life,
    required this.ambient,
  });
  Offset pos;
  Offset vel;
  Color color;
  double size;
  double life;
  bool ambient;

  factory _Star.ambient(math.Random r) => _Star(
        pos: Offset(r.nextDouble() * 1200, r.nextDouble() * 1800),
        vel: Offset.zero,
        color: rainbow(r.nextDouble(), s: 0.3, v: 1),
        size: 0.6 + r.nextDouble() * 1.6,
        life: 1,
        ambient: true,
      );
}

class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter(this.stars);
  final List<_Star> stars;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF05030F));
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (final s in stars) {
      final o = s.ambient ? 0.9 : s.life.clamp(0.0, 1.0);
      glow.color = s.color.withOpacity(o);
      canvas.drawCircle(s.pos, s.size + (s.ambient ? 0 : s.life * 2), glow);
    }
  }

  @override
  bool shouldRepaint(_GalaxyPainter oldDelegate) => true;
}

// ===========================================================================
// Fireworks Touch — tap launches a shell that bursts into colour.
// ===========================================================================
class FireworksToy extends StatefulWidget {
  const FireworksToy({super.key});
  @override
  State<FireworksToy> createState() => _FireworksToyState();
}

class _FireworksToyState extends State<FireworksToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Spark> _sparks = <_Spark>[];
  final List<_Shell> _shells = <_Shell>[];
  final math.Random _r = math.Random();
  double _hue = 0;

  void _launch(Offset target) {
    final size = context.size ?? Size.zero;
    _shells.add(_Shell(
      pos: Offset(target.dx, size.height),
      target: target,
      hue: _hue,
    ));
    _hue = (_hue + 0.12) % 1.0;
  }

  void _explode(Offset p, double hue) {
    HapticFeedback.mediumImpact();
    for (var i = 0; i < 60; i++) {
      final a = _r.nextDouble() * math.pi * 2;
      final speed = 40 + _r.nextDouble() * 200;
      _sparks.add(_Spark(
        pos: p,
        vel: Offset(math.cos(a), math.sin(a)) * speed,
        color: rainbow(hue + _r.nextDouble() * 0.1),
        life: 1,
      ));
    }
  }

  @override
  void onTick(double dt) {
    for (final shell in [..._shells]) {
      shell.pos += (shell.target - shell.pos) * (dt * 2.2);
      if ((shell.pos - shell.target).distance < 12) {
        _explode(shell.pos, shell.hue);
        _shells.remove(shell);
      }
    }
    _sparks.removeWhere((s) => s.life <= 0);
    for (final s in _sparks) {
      s.vel += const Offset(0, 90) * dt; // gravity
      s.vel *= 0.99;
      s.pos += s.vel * dt;
      s.life -= dt * 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (e) => _launch(e.localPosition),
      child: CustomPaint(
        painter: _FireworksPainter(_sparks, _shells),
        size: Size.infinite,
      ),
    );
  }
}

class _Shell {
  _Shell({required this.pos, required this.target, required this.hue});
  Offset pos;
  final Offset target;
  final double hue;
}

class _Spark {
  _Spark({required this.pos, required this.vel, required this.color, required this.life});
  Offset pos;
  Offset vel;
  Color color;
  double life;
}

class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.sparks, this.shells);
  final List<_Spark> sparks;
  final List<_Shell> shells;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF050813));
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (final shell in shells) {
      glow.color = rainbow(shell.hue);
      canvas.drawCircle(shell.pos, 3, glow);
    }
    for (final s in sparks) {
      glow.color = s.color.withOpacity(s.life.clamp(0.0, 1.0));
      canvas.drawCircle(s.pos, 2 + s.life * 1.5, glow);
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter oldDelegate) => true;
}
