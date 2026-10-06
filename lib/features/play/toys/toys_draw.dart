import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/tone_player.dart';
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
        TonePlayer.instance.haptic(HapticFeedback.selectionClick);
        TonePlayer.instance.playCue(SoundCue.sand);
        setState(() => _strokes.add(<Offset>[e.localPosition]));
      },
      onPointerMove: (e) => setState(() {
        if (_strokes.isNotEmpty) _strokes.last.add(e.localPosition);
        if (_strokes.length > 60) _strokes.removeAt(0);
        // Grainy rake texture while the finger drags, matching what's drawn.
        TonePlayer.instance.playCue(SoundCue.sand);
      }),
      child: Stack(
        children: <Widget>[
          CustomPaint(painter: _SandPainter(_strokes), size: Size.infinite),
          // The onboarding hint is drawn only onto the canvas (invisible to
          // screen readers); IgnorePointer keeps it from stealing touches.
          Positioned.fill(
            child: IgnorePointer(
              child: Semantics(label: 'Drag your finger to rake the sand'),
            ),
          ),
        ],
      ),
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
    return Stack(
      children: <Widget>[
        Listener(
          onPointerDown: (e) { _last = e.localPosition; TonePlayer.instance.haptic(HapticFeedback.selectionClick); },
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
        ),
        // The onboarding hint is drawn only onto the canvas (invisible to
        // screen readers); IgnorePointer keeps it from stealing touches
        // from the Listener above.
        Positioned.fill(
          child: IgnorePointer(
            child: Semantics(label: 'Draw — it mirrors into a kaleidoscope'),
          ),
        ),
      ],
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
    // A blank dark canvas gives no hint this is a mirrored-drawing toy — show
    // a fading hint until the first stroke, matching the PaintWithLightToy
    // and CarTrackBuilderToy empty-state pattern.
    if (segs.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Draw — it mirrors into a kaleidoscope ✨',
          style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width - 40);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }
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
  // Every other sensory toy that emits particles on touch (ParticleGalaxy's
  // `_burst`, Fireworks' `_explode`) already halves or thirds its spawn
  // count under OS Reduce Motion, same as the arcade catalog's `_Shard`
  // bursts — this was the one still spawning a flat 6 particles per pointer
  // move regardless, so a sensitive child with Reduce Motion on got the
  // exact same dense swirling fluid as everyone else.
  bool _reduceMotion = false;

  void _emit(Offset p, Offset vel) {
    final n = _reduceMotion ? 2 : 6;
    for (var i = 0; i < n; i++) {
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
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Same "describable but not actionable" gap already fixed in
    // ParticleGalaxyToy/FireworksToy — the onboarding hint was a plain label
    // with no `onTap`, so a screen reader could discover the fluid toy but
    // never actually stir it. Bridges the one discrete action (emit a swirl
    // at the canvas centre); the continuous drag-to-stir half correctly
    // stays out of reach, same as every other continuous-drag sensory toy.
    return Semantics(
      button: true,
      label: 'Tap or drag to swirl the colors',
      onTap: () {
        final size = context.size ?? Size.zero;
        _emit(size.center(Offset.zero), Offset.zero);
      },
      excludeSemantics: true,
      child: Stack(
        children: <Widget>[
          Listener(
            onPointerDown: (e) {
              // Every other continuous-draw toy (SandGarden, Kaleidoscope,
              // PaintWithLight, CarTrackBuilder, ColorMixingLab) gives a haptic
              // pulse on first touch — this was the one silent outlier.
              TonePlayer.instance.haptic(HapticFeedback.selectionClick);
              _last = e.localPosition;
              _emit(e.localPosition, Offset.zero);
            },
            onPointerMove: (e) {
              final v = _last == null ? Offset.zero : (e.localPosition - _last!) * 12;
              _emit(e.localPosition, v);
              _last = e.localPosition;
            },
            onPointerUp: (_) => _last = null,
            child: CustomPaint(painter: _FluidPainter(_p), size: Size.infinite),
          ),
        ],
      ),
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
    // Same blank-dark-canvas gap as Kaleidoscope/PaintWithLight — nothing
    // moves or glows until the finger touches down, so show a fading hint.
    if (particles.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Swirl your finger to stir the colors 🌊',
          style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width - 40);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }
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
