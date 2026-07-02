import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/toy/toy_ticker.dart';
import 'toys_particles.dart' show rainbow;

// ===========================================================================
// Rainbow Rain — touch summons falling rainbow drops; drag changes weather.
// ===========================================================================
class RainbowRainToy extends StatefulWidget {
  const RainbowRainToy({super.key});
  @override
  State<RainbowRainToy> createState() => _RainbowRainToyState();
}

class _RainbowRainToyState extends State<RainbowRainToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Drop> _drops = <_Drop>[];
  final List<_Splash> _splashes = <_Splash>[];
  final math.Random _r = math.Random();
  double _intensity = 0.4; // 0..1, controlled by vertical drag
  double _spawnAcc = 0;

  @override
  void onTick(double dt) {
    final size = context.size ?? Size.zero;
    // Spawn drops proportional to intensity.
    _spawnAcc += dt * (8 + _intensity * 90);
    while (_spawnAcc >= 1) {
      _spawnAcc -= 1;
      _drops.add(_Drop(
        x: _r.nextDouble() * size.width,
        y: -10,
        vy: 240 + _r.nextDouble() * 200,
        hue: _r.nextDouble(),
      ));
    }
    for (final d in _drops) {
      d.y += d.vy * dt;
    }
    _drops.removeWhere((d) {
      if (d.y >= size.height - 4) {
        _splashes.add(_Splash(x: d.x, y: size.height - 4, hue: d.hue, life: 1));
        return true;
      }
      return false;
    });
    _splashes.removeWhere((s) => s.life <= 0);
    for (final s in _splashes) {
      s.life -= dt * 2.2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (e) {
        setState(() => _intensity = (_intensity - e.delta.dy / 300).clamp(0.0, 1.0));
      },
      onTapDown: (_) => HapticFeedback.selectionClick(),
      child: CustomPaint(
        painter: _RainPainter(_drops, _splashes, _intensity),
        size: Size.infinite,
      ),
    );
  }
}

class _Drop {
  _Drop({required this.x, required this.y, required this.vy, required this.hue});
  double x, y, vy, hue;
}

class _Splash {
  _Splash({required this.x, required this.y, required this.hue, required this.life});
  double x, y, hue, life;
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.drops, this.splashes, this.intensity);
  final List<_Drop> drops;
  final List<_Splash> splashes;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.lerp(const Color(0xFF1B2845), const Color(0xFF274060), intensity)!,
          const Color(0xFF0B1320),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final p = Paint()..strokeCap = StrokeCap.round..strokeWidth = 2.4;
    for (final d in drops) {
      p.color = rainbow(d.hue, s: 0.7).withOpacity(0.85);
      canvas.drawLine(Offset(d.x, d.y), Offset(d.x, d.y + 12), p);
    }
    final sp = Paint()..style = PaintingStyle.stroke..strokeWidth = 2;
    for (final s in splashes) {
      sp.color = rainbow(s.hue, s: 0.7).withOpacity(s.life.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(s.x, s.y), (1 - s.life) * 16, sp);
    }
  }

  @override
  bool shouldRepaint(_RainPainter oldDelegate) => true;
}

// ===========================================================================
// Sensory Lava Lamp — slow rising/falling metaball blobs.
// ===========================================================================
class LavaLampToy extends StatefulWidget {
  const LavaLampToy({super.key});
  @override
  State<LavaLampToy> createState() => _LavaLampToyState();
}

class _LavaLampToyState extends State<LavaLampToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Blob> _blobs = <_Blob>[];
  final math.Random _r = math.Random();
  double _t = 0;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 7; i++) {
      _blobs.add(_Blob(
        x: 0.2 + _r.nextDouble() * 0.6,
        phase: _r.nextDouble() * math.pi * 2,
        speed: 0.15 + _r.nextDouble() * 0.2,
        radius: 40 + _r.nextDouble() * 50,
        hue: _r.nextDouble(),
      ));
    }
  }

  @override
  void onTick(double dt) => _t += dt;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (e) {
        final size = context.size ?? Size.zero;
        setState(() {
          _blobs.add(_Blob(
            x: e.localPosition.dx / size.width,
            phase: _t,
            speed: 0.2 + _r.nextDouble() * 0.25,
            radius: 30 + _r.nextDouble() * 40,
            hue: _r.nextDouble(),
          ));
          if (_blobs.length > 14) _blobs.removeAt(0);
        });
      },
      child: CustomPaint(
        painter: _LavaPainter(_blobs, _t),
        size: Size.infinite,
      ),
    );
  }
}

class _Blob {
  _Blob({required this.x, required this.phase, required this.speed, required this.radius, required this.hue});
  double x, phase, speed, radius, hue;
}

class _LavaPainter extends CustomPainter {
  _LavaPainter(this.blobs, this.t);
  final List<_Blob> blobs;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF1A0033), Color(0xFF330033)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    canvas.saveLayer(Offset.zero & size, Paint());
    for (final b in blobs) {
      final y = size.height * (0.5 + 0.42 * math.sin(b.phase + t * b.speed));
      final x = size.width * b.x + math.sin(t * 0.3 + b.phase) * 20;
      final paint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
        ..color = rainbow(b.hue, s: 0.9, v: 1).withOpacity(0.9);
      canvas.drawCircle(Offset(x, y), b.radius, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LavaPainter oldDelegate) => true;
}
