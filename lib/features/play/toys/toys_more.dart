import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/toy/toy_ticker.dart';
import 'toys_particles.dart' show rainbow;

// ===========================================================================
// Slime Stretch — a gooey soft-body blob that follows and stretches with the
// finger, then jiggles back to rest. Pure tactile satisfaction.
// ===========================================================================
class SlimeStretchToy extends StatefulWidget {
  const SlimeStretchToy({super.key});
  @override
  State<SlimeStretchToy> createState() => _SlimeStretchToyState();
}

class _SlimeStretchToyState extends State<SlimeStretchToy>
    with TickerProviderStateMixin, ToyTicker {
  static const int _verts = 26;
  final List<double> _radii = List<double>.filled(_verts, 90);
  final List<double> _vel = List<double>.filled(_verts, 0);
  Offset _center = Offset.zero;
  Offset _centerVel = Offset.zero;
  Offset? _finger;
  double _hue = 0.33;
  bool _seeded = false;

  @override
  void onTick(double dt) {
    final size = context.size ?? Size.zero;
    if (size == Size.zero) return;
    if (!_seeded) {
      _center = size.center(Offset.zero);
      _seeded = true;
    }
    // Spring the blob centre toward the finger (or back to the middle).
    final target = _finger ?? size.center(Offset.zero);
    final accel = (target - _center) * 26 - _centerVel * 7;
    _centerVel += accel * dt;
    _center += _centerVel * dt;

    // Each rim vertex springs back to the base radius, jiggling like jelly.
    const base = 90.0;
    for (var i = 0; i < _verts; i++) {
      final force = (base - _radii[i]) * 60 - _vel[i] * 6;
      _vel[i] += force * dt;
      _radii[i] += _vel[i] * dt;
    }
  }

  void _poke(Offset p) {
    _finger = p;
    final dir = p - _center;
    final ang = math.atan2(dir.dy, dir.dx);
    // Bulge the rim toward the finger to create the stretch.
    for (var i = 0; i < _verts; i++) {
      final a = i / _verts * 2 * math.pi;
      final align = math.cos(a - ang).clamp(-1.0, 1.0);
      _vel[i] += align * dir.distance.clamp(0, 220) * 0.06;
    }
    _hue = (_hue + 0.002) % 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) { _poke(e.localPosition); HapticFeedback.selectionClick(); },
      onPointerMove: (e) => _poke(e.localPosition),
      onPointerUp: (_) { _finger = null; HapticFeedback.lightImpact(); },
      child: CustomPaint(
        painter: _SlimePainter(_center, _radii, _hue),
        size: Size.infinite,
      ),
    );
  }
}

class _SlimePainter extends CustomPainter {
  _SlimePainter(this.center, this.radii, this.hue);
  final Offset center;
  final List<double> radii;
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0E1F12), Color(0xFF12331C)],
        ).createShader(Offset.zero & size),
    );
    final n = radii.length;
    final path = Path();
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi;
      pts.add(center + Offset(math.cos(a), math.sin(a)) * radii[i]);
    }
    // Smooth closed Catmull-Rom-ish curve through the rim points.
    path.moveTo((pts[0].dx + pts[n - 1].dx) / 2, (pts[0].dy + pts[n - 1].dy) / 2);
    for (var i = 0; i < n; i++) {
      final cur = pts[i];
      final next = pts[(i + 1) % n];
      path.quadraticBezierTo(cur.dx, cur.dy, (cur.dx + next.dx) / 2, (cur.dy + next.dy) / 2);
    }
    path.close();

    final body = rainbow(hue, s: 0.65, v: 0.95);
    canvas.drawPath(
      path,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = body.withOpacity(0.55),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[Color.lerp(body, Colors.white, 0.4)!, body],
        ).createShader(Rect.fromCircle(center: center, radius: 120)),
    );
    // Glossy highlight.
    canvas.drawCircle(center + const Offset(-26, -30), 22,
        Paint()..color = Colors.white.withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  }

  @override
  bool shouldRepaint(_SlimePainter oldDelegate) => true;
}

// ===========================================================================
// Color Mixing Lab — drop paint that spreads and blends like real pigment.
// ===========================================================================
class ColorMixingLabToy extends StatefulWidget {
  const ColorMixingLabToy({super.key});
  @override
  State<ColorMixingLabToy> createState() => _ColorMixingLabToyState();
}

class _ColorMixingLabToyState extends State<ColorMixingLabToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Paint> _blobs = <_Paint>[];
  double _hue = 0.0;

  @override
  void onTick(double dt) {
    for (final b in _blobs) {
      if (b.radius < b.maxRadius) b.radius += dt * 70;
    }
    if (_blobs.length > 120) _blobs.removeRange(0, _blobs.length - 120);
  }

  void _drop(Offset p) {
    _blobs.add(_Paint(pos: p, hue: _hue, maxRadius: 60 + math.Random().nextDouble() * 40));
    _hue = (_hue + 0.04) % 1.0;
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _drop(e.localPosition),
      onPointerMove: (e) {
        if (_blobs.isEmpty || (_blobs.last.pos - e.localPosition).distance > 24) {
          _drop(e.localPosition);
        }
      },
      child: CustomPaint(painter: _MixPainter(_blobs), size: Size.infinite),
    );
  }
}

class _Paint {
  _Paint({required this.pos, required this.hue, required this.maxRadius}) : radius = 6;
  final Offset pos;
  final double hue, maxRadius;
  double radius;
}

class _MixPainter extends CustomPainter {
  _MixPainter(this.blobs);
  final List<_Paint> blobs;

  @override
  void paint(Canvas canvas, Size size) {
    // White paper.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF6F1E7));
    // Multiply blending makes overlapping colours mix like real pigment.
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final b in blobs) {
      final c = rainbow(b.hue, s: 0.85, v: 0.95);
      canvas.drawCircle(
        b.pos,
        b.radius,
        Paint()
          ..blendMode = BlendMode.multiply
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..color = c.withOpacity(0.55),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MixPainter oldDelegate) => true;
}

// ===========================================================================
// Car Track Builder — draw a road with your finger, a little car drives it.
// ===========================================================================
class CarTrackBuilderToy extends StatefulWidget {
  const CarTrackBuilderToy({super.key});
  @override
  State<CarTrackBuilderToy> createState() => _CarTrackBuilderToyState();
}

class _CarTrackBuilderToyState extends State<CarTrackBuilderToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<Offset> _track = <Offset>[];
  double _dist = 0; // arc-length position of the car along the track
  bool _drawing = false;

  @override
  void onTick(double dt) {
    if (_drawing || _track.length < 2) return;
    _dist += 180 * dt;
    final total = _trackLength();
    if (total > 0) _dist %= total;
  }

  double _trackLength() {
    var len = 0.0;
    for (var i = 1; i < _track.length; i++) {
      len += (_track[i] - _track[i - 1]).distance;
    }
    return len;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        setState(() {
          _track
            ..clear()
            ..add(e.localPosition);
          _drawing = true;
          _dist = 0;
        });
        HapticFeedback.selectionClick();
      },
      onPointerMove: (e) {
        if (_track.isEmpty || (_track.last - e.localPosition).distance > 10) {
          _track.add(e.localPosition);
        }
      },
      onPointerUp: (_) {
        _drawing = false;
        HapticFeedback.lightImpact();
      },
      child: CustomPaint(painter: _TrackPainter(_track, _dist), size: Size.infinite),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.track, this.dist);
  final List<Offset> track;
  final double dist;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1D3B2A), Color(0xFF14532D)],
        ).createShader(Offset.zero & size),
    );
    if (track.length < 2) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Draw a road with your finger 🏎️',
          style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2));
      return;
    }
    final road = Path()..moveTo(track.first.dx, track.first.dy);
    for (var i = 1; i < track.length; i++) {
      road.lineTo(track[i].dx, track[i].dy);
    }
    canvas.drawPath(road, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF2B2B2B));
    canvas.drawPath(road, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.amber.withOpacity(0.8));

    // Locate the car along the polyline at arc length `dist`.
    var remaining = dist;
    var carPos = track.first;
    var angle = 0.0;
    for (var i = 1; i < track.length; i++) {
      final seg = track[i] - track[i - 1];
      final segLen = seg.distance;
      if (remaining <= segLen) {
        final t = segLen == 0 ? 0 : remaining / segLen;
        carPos = track[i - 1] + seg * t.toDouble();
        angle = math.atan2(seg.dy, seg.dx);
        break;
      }
      remaining -= segLen;
    }
    canvas.save();
    canvas.translate(carPos.dx, carPos.dy);
    canvas.rotate(angle);
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -11, 36, 22), const Radius.circular(6));
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFF5252));
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -8, 14, 16), const Radius.circular(4)),
        Paint()..color = Colors.lightBlueAccent.withOpacity(0.9));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) => true;
}

// ===========================================================================
// Spin Universe — fling to spin a galaxy; angular momentum carries it on.
// ===========================================================================
class SpinUniverseToy extends StatefulWidget {
  const SpinUniverseToy({super.key});
  @override
  State<SpinUniverseToy> createState() => _SpinUniverseToyState();
}

class _SpinUniverseToyState extends State<SpinUniverseToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Star> _stars = <_Star>[];
  final math.Random _r = math.Random();
  double _rot = 0;
  double _spin = 0.4; // angular velocity (rad/s)
  bool _seeded = false;

  void _seed(Size size) {
    final maxR = size.shortestSide * 0.48;
    for (var i = 0; i < 220; i++) {
      // Two-arm logarithmic spiral.
      final arm = i.isEven ? 0.0 : math.pi;
      final t = _r.nextDouble();
      final radius = t * maxR;
      final spread = (1 - t) * 0.6;
      final ang = arm + t * 5 + (_r.nextDouble() - 0.5) * spread * 2;
      _stars.add(_Star(
        baseAngle: ang,
        radius: radius,
        size: 1.2 + _r.nextDouble() * 2.6,
        hue: 0.55 + t * 0.25 + _r.nextDouble() * 0.05,
      ));
    }
    _seeded = true;
  }

  @override
  void onTick(double dt) {
    final size = context.size ?? Size.zero;
    if (size == Size.zero) return;
    if (!_seeded) _seed(size);
    _rot += _spin * dt;
    // Gentle friction so a fling slowly coasts to a calm idle spin.
    _spin += (0.25 - _spin) * 0.4 * dt;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (e) {
        final size = context.size ?? Size.zero;
        final c = size.center(Offset.zero);
        final p = e.localPosition;
        // Torque from the tangential component of the drag.
        final tangent = Offset(-(p - c).dy, (p - c).dx);
        final tl = tangent.distance;
        if (tl > 0) {
          final proj = (e.delta.dx * tangent.dx + e.delta.dy * tangent.dy) / (tl * tl);
          _spin = (_spin + proj * 26).clamp(-9.0, 9.0);
        }
      },
      onTapDown: (_) => HapticFeedback.selectionClick(),
      child: CustomPaint(painter: _GalaxyPainter(_stars, _rot), size: Size.infinite),
    );
  }
}

class _Star {
  _Star({required this.baseAngle, required this.radius, required this.size, required this.hue});
  final double baseAngle, radius, size, hue;
}

class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter(this.stars, this.rot);
  final List<_Star> stars;
  final double rot;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0xFF1A1140), Color(0xFF05010F)],
        ).createShader(Offset.zero & size),
    );
    final c = size.center(Offset.zero);
    // Glowing core.
    canvas.drawCircle(c, 46,
        Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)..color = const Color(0xFFFFE9B0).withOpacity(0.8));
    for (final s in stars) {
      final a = s.baseAngle + rot;
      final p = c + Offset(math.cos(a), math.sin(a)) * s.radius;
      canvas.drawCircle(p, s.size,
          Paint()..color = rainbow(s.hue % 1.0, s: 0.55, v: 1).withOpacity(0.9));
    }
  }

  @override
  bool shouldRepaint(_GalaxyPainter oldDelegate) => true;
}

// ===========================================================================
// Infinite Marble Run — tap to drop marbles that tumble through a peg field.
// ===========================================================================
class InfiniteMarbleRunToy extends StatefulWidget {
  const InfiniteMarbleRunToy({super.key});
  @override
  State<InfiniteMarbleRunToy> createState() => _InfiniteMarbleRunToyState();
}

class _InfiniteMarbleRunToyState extends State<InfiniteMarbleRunToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Marble> _marbles = <_Marble>[];
  final List<Offset> _pegs = <Offset>[];
  final math.Random _r = math.Random();
  double _spawnAcc = 0;
  bool _seeded = false;

  void _seed(Size size) {
    const rows = 9;
    final cols = (size.width / 70).floor().clamp(4, 9);
    final gapY = size.height * 0.78 / rows;
    for (var row = 0; row < rows; row++) {
      final offset = row.isEven ? 0.0 : 0.5;
      for (var col = 0; col <= cols; col++) {
        _pegs.add(Offset(
          size.width * (col + offset) / cols,
          size.height * 0.16 + row * gapY,
        ));
      }
    }
    _seeded = true;
  }

  @override
  void onTick(double dt) {
    final size = context.size ?? Size.zero;
    if (size == Size.zero) return;
    if (!_seeded) _seed(size);

    // A steady gentle rain of marbles keeps it "infinite".
    _spawnAcc += dt * 1.6;
    while (_spawnAcc >= 1 && _marbles.length < 70) {
      _spawnAcc -= 1;
      _spawn(size.width * (0.2 + _r.nextDouble() * 0.6));
    }

    const g = 900.0;
    for (final m in _marbles) {
      m.vel = Offset(m.vel.dx * 0.999, m.vel.dy + g * dt);
      m.pos += m.vel * dt;
      // Walls.
      if (m.pos.dx < m.radius) { m.pos = Offset(m.radius, m.pos.dy); m.vel = Offset(m.vel.dx.abs() * 0.6, m.vel.dy); }
      if (m.pos.dx > size.width - m.radius) { m.pos = Offset(size.width - m.radius, m.pos.dy); m.vel = Offset(-m.vel.dx.abs() * 0.6, m.vel.dy); }
      // Peg collisions.
      for (final peg in _pegs) {
        final d = m.pos - peg;
        final dist = d.distance;
        final minDist = m.radius + 6;
        if (dist < minDist && dist > 0) {
          final n = d / dist;
          m.pos = peg + n * minDist;
          final vn = m.vel.dx * n.dx + m.vel.dy * n.dy;
          m.vel = (m.vel - n * (2 * vn)) * 0.55;
        }
      }
    }
    _marbles.removeWhere((m) => m.pos.dy > size.height + 40);
  }

  void _spawn(double x) {
    _marbles.add(_Marble(
      pos: Offset(x, -20),
      vel: Offset((_r.nextDouble() - 0.5) * 40, 0),
      radius: 9 + _r.nextDouble() * 6,
      hue: _r.nextDouble(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) { _spawn(e.localPosition.dx); HapticFeedback.lightImpact(); },
      child: CustomPaint(painter: _MarblePainter(_marbles, _pegs), size: Size.infinite),
    );
  }
}

class _Marble {
  _Marble({required this.pos, required this.vel, required this.radius, required this.hue});
  Offset pos, vel;
  final double radius, hue;
}

class _MarblePainter extends CustomPainter {
  _MarblePainter(this.marbles, this.pegs);
  final List<_Marble> marbles;
  final List<Offset> pegs;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0B1E3B), Color(0xFF09122B)],
        ).createShader(Offset.zero & size),
    );
    final pegPaint = Paint()..color = Colors.white.withOpacity(0.22);
    for (final p in pegs) {
      canvas.drawCircle(p, 4, pegPaint);
    }
    for (final m in marbles) {
      final base = rainbow(m.hue, s: 0.7, v: 1);
      canvas.drawCircle(
        m.pos,
        m.radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[Color.lerp(base, Colors.white, 0.6)!, base],
            center: const Alignment(-0.4, -0.4),
          ).createShader(Rect.fromCircle(center: m.pos, radius: m.radius)),
      );
      canvas.drawCircle(m.pos + Offset(-m.radius * 0.3, -m.radius * 0.3), m.radius * 0.22,
          Paint()..color = Colors.white.withOpacity(0.8));
    }
  }

  @override
  bool shouldRepaint(_MarblePainter oldDelegate) => true;
}
