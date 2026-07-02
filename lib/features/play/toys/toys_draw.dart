import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/toy/toy_ticker.dart';
import 'toys_particles.dart' show rainbow;

// ===========================================================================
// Sand Garden — zen raked-sand drawing.
// ===========================================================================
class SandGardenToy extends StatefulWidget {
  const SandGardenToy({super.key});
  @override
  State<SandGardenToy> createState() => _SandGardenToyState();
}

class _SandGardenToyState extends State<SandGardenToy> {
  final List<List<Offset>> _strokes = <List<Offset>>[];

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        HapticFeedback.selectionClick();
        setState(() => _strokes.add(<Offset>[e.localPosition]));
      },
      onPointerMove: (e) => setState(() {
        if (_strokes.isNotEmpty) _strokes.last.add(e.localPosition);
        if (_strokes.length > 60) _strokes.removeAt(0);
      }),
      child: CustomPaint(painter: _SandPainter(_strokes), size: Size.infinite),
    );
  }
}

class _SandPainter extends CustomPainter {
  _SandPainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE7CBA9), Color(0xFFD9B38C)],
        ).createShader(Offset.zero & size),
    );
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      // Groove shadow + highlight to fake raked depth.
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round..color = const Color(0x33000000));
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round..color = const Color(0x55FFFFFF));
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = const Color(0x33000000));
    }
  }

  @override
  bool shouldRepaint(_SandPainter oldDelegate) => true;
}

// ===========================================================================
// Kaleidoscope Mirror — symmetrical drawing with live mirroring.
// ===========================================================================
class KaleidoscopeToy extends StatefulWidget {
  const KaleidoscopeToy({super.key});
  @override
  State<KaleidoscopeToy> createState() => _KaleidoscopeToyState();
}

class _KaleidoscopeToyState extends State<KaleidoscopeToy> {
  final List<_KSeg> _segs = <_KSeg>[];
  Offset? _last;
  double _hue = 0;
  static const int _slices = 8;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) { _last = e.localPosition; HapticFeedback.selectionClick(); },
      onPointerMove: (e) => setState(() {
        if (_last != null) {
          _segs.add(_KSeg(_last!, e.localPosition, _hue));
          _hue = (_hue + 0.01) % 1.0;
          if (_segs.length > 800) _segs.removeRange(0, 100);
        }
        _last = e.localPosition;
      }),
      onPointerUp: (_) => _last = null,
      child: CustomPaint(painter: _KaleidoPainter(_segs, _slices), size: Size.infinite),
    );
  }
}

class _KSeg {
  _KSeg(this.a, this.b, this.hue);
  final Offset a, b;
  final double hue;
}

class _KaleidoPainter extends CustomPainter {
  _KaleidoPainter(this.segs, this.slices);
  final List<_KSeg> segs;
  final int slices;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF080014));
    final center = size.center(Offset.zero);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final paint = Paint()..strokeCap = StrokeCap.round..strokeWidth = 3;
    for (var s = 0; s < slices; s++) {
      canvas.save();
      canvas.rotate(s * 2 * math.pi / slices);
      for (final seg in segs) {
        paint.color = rainbow(seg.hue, v: 1).withOpacity(0.9);
        final a = seg.a - center;
        final b = seg.b - center;
        canvas.drawLine(a, b, paint);
        // Mirror across the slice axis for the classic kaleidoscope look.
        canvas.drawLine(Offset(a.dx, -a.dy), Offset(b.dx, -b.dy), paint);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KaleidoPainter oldDelegate) => true;
}

// ===========================================================================
// Fluid Simulator — glowing colour fluid that advects with your finger.
// ===========================================================================
class FluidSimulatorToy extends StatefulWidget {
  const FluidSimulatorToy({super.key});
  @override
  State<FluidSimulatorToy> createState() => _FluidSimulatorToyState();
}

class _FluidSimulatorToyState extends State<FluidSimulatorToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_FluidParticle> _p = <_FluidParticle>[];
  final math.Random _r = math.Random();
  Offset? _last;
  double _hue = 0.0;

  void _emit(Offset p, Offset vel) {
    for (var i = 0; i < 6; i++) {
      _p.add(_FluidParticle(
        pos: p + Offset((_r.nextDouble() - 0.5) * 10, (_r.nextDouble() - 0.5) * 10),
        vel: vel * 0.4 + Offset((_r.nextDouble() - 0.5) * 30, (_r.nextDouble() - 0.5) * 30),
        hue: _hue,
        life: 1,
      ));
    }
    _hue = (_hue + 0.006) % 1.0;
    if (_p.length > 1400) _p.removeRange(0, 200);
  }

  @override
  void onTick(double dt) {
    for (final f in _p) {
      f.vel *= 0.94;
      f.pos += f.vel * dt;
      f.life -= dt * 0.35;
    }
    _p.removeWhere((f) => f.life <= 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) { _last = e.localPosition; _emit(e.localPosition, Offset.zero); },
      onPointerMove: (e) {
        final v = _last == null ? Offset.zero : (e.localPosition - _last!) * 12;
        _emit(e.localPosition, v);
        _last = e.localPosition;
      },
      onPointerUp: (_) => _last = null,
      child: CustomPaint(painter: _FluidPainter(_p), size: Size.infinite),
    );
  }
}

class _FluidParticle {
  _FluidParticle({required this.pos, required this.vel, required this.hue, required this.life});
  Offset pos, vel;
  double hue, life;
}

class _FluidPainter extends CustomPainter {
  _FluidPainter(this.particles);
  final List<_FluidParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF03010A));
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    for (final f in particles) {
      paint.color = rainbow(f.hue, s: 0.9, v: 1).withOpacity(f.life.clamp(0.0, 1.0) * 0.5);
      canvas.drawCircle(f.pos, 22 * f.life + 6, paint);
    }
  }

  @override
  bool shouldRepaint(_FluidPainter oldDelegate) => true;
}
