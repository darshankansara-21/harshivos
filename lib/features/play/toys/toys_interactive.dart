import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/tone_player.dart';
import 'toys_particles.dart' show rainbow;

// ===========================================================================
// Calm Clouds — drag soft clouds across a gentle sky.
// ===========================================================================
class CalmCloudsToy extends StatefulWidget {
  const CalmCloudsToy({super.key});
  @override
  State<CalmCloudsToy> createState() => _CalmCloudsToyState();
}

class _CalmCloudsToyState extends State<CalmCloudsToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Cloud> _clouds = <_Cloud>[];
  final math.Random _r = math.Random();
  int? _dragging;
  bool _seeded = false;

  void _seed(Size size) {
    for (var i = 0; i < 7; i++) {
      _clouds.add(_Cloud(
        pos: Offset(_r.nextDouble() * size.width, 80 + _r.nextDouble() * (size.height - 200)),
        scale: 0.7 + _r.nextDouble() * 0.9,
        drift: 6 + _r.nextDouble() * 10,
      ));
    }
    _seeded = true;
  }

  @override
  void onTick(double dt) {
    final size = context.size ?? Size.zero;
    if (!_seeded && size != Size.zero) _seed(size);
    for (var i = 0; i < _clouds.length; i++) {
      if (i == _dragging) continue;
      final c = _clouds[i];
      c.pos = Offset((c.pos.dx + c.drift * dt) % (size.width + 200) - 0, c.pos.dy);
      if (c.pos.dx > size.width + 120) c.pos = Offset(-120, c.pos.dy);
    }
  }

  int? _nearest(Offset p) {
    double best = 90;
    int? idx;
    for (var i = 0; i < _clouds.length; i++) {
      final d = (_clouds[i].pos - p).distance;
      if (d < best) { best = d; idx = i; }
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) { _dragging = _nearest(e.localPosition); HapticFeedback.selectionClick(); },
      onPointerMove: (e) {
        if (_dragging != null) _clouds[_dragging!].pos = e.localPosition;
      },
      onPointerUp: (_) => _dragging = null,
      child: CustomPaint(painter: _CloudPainter(_clouds), size: Size.infinite),
    );
  }
}

class _Cloud {
  _Cloud({required this.pos, required this.scale, required this.drift});
  Offset pos;
  double scale, drift;
}

class _CloudPainter extends CustomPainter {
  _CloudPainter(this.clouds);
  final List<_Cloud> clouds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF8EC5FC), Color(0xFFB7E0FF), Color(0xFFE0C3FC)],
        ).createShader(Offset.zero & size),
    );
    final puff = Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (final c in clouds) {
      final s = c.scale;
      void blob(double dx, double dy, double r) =>
          canvas.drawCircle(c.pos + Offset(dx * s, dy * s), r * s, puff);
      blob(-40, 8, 34);
      blob(0, -6, 46);
      blob(42, 8, 36);
      blob(0, 18, 50);
    }
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) => true;
}

// ===========================================================================
// Music Garden — tap flowers to bloom them and play a pentatonic note.
// (Visual + haptic feedback; wire a synth/audio asset for full sound.)
// ===========================================================================
class MusicGardenToy extends StatefulWidget {
  const MusicGardenToy({super.key});
  @override
  State<MusicGardenToy> createState() => _MusicGardenToyState();
}

class _MusicGardenToyState extends State<MusicGardenToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Flower> _flowers = <_Flower>[];
  bool _seeded = false;

  void _seed(Size size) {
    const cols = 5, rows = 6;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        _flowers.add(_Flower(
          pos: Offset(
            size.width * (x + 0.5) / cols,
            size.height * (y + 0.6) / rows,
          ),
          hue: (x + y) / (cols + rows),
          note: (x + y) % 5,
          // Top rows ring an octave higher than the bottom rows.
          octave: y < rows ~/ 2 ? 1 : 0,
        ));
      }
    }
    _seeded = true;
  }

  @override
  void onTick(double dt) {
    final size = context.size ?? Size.zero;
    if (!_seeded && size != Size.zero) _seed(size);
    for (final f in _flowers) {
      if (f.bloom > 0) f.bloom = (f.bloom - dt * 1.4).clamp(0.0, 1.0);
      f.sway += dt;
    }
  }

  void _tap(Offset p) {
    for (final f in _flowers) {
      if ((f.pos - p).distance < 36 && f.bloom < 0.2) {
        f.bloom = 1;
        HapticFeedback.lightImpact();
        // Each flower is tuned to a pentatonic note → always harmonious.
        TonePlayer.instance.playNote(f.note + f.octave * 5);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _tap(e.localPosition),
      onPointerMove: (e) => _tap(e.localPosition),
      child: CustomPaint(painter: _GardenPainter(_flowers), size: Size.infinite),
    );
  }
}

class _Flower {
  _Flower({required this.pos, required this.hue, required this.note, required this.octave})
      : bloom = 0,
        sway = 0;
  final Offset pos;
  final double hue;
  final int note;
  final int octave;
  double bloom, sway;
}

class _GardenPainter extends CustomPainter {
  _GardenPainter(this.flowers);
  final List<_Flower> flowers;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1B4332), Color(0xFF2D6A4F)],
        ).createShader(Offset.zero & size),
    );
    for (final f in flowers) {
      final scale = 1 + f.bloom * 0.6;
      final petalColor = rainbow(f.hue, s: 0.7, v: 1);
      final sway = math.sin(f.sway) * 3;
      final center = f.pos + Offset(sway, 0);
      // Stem.
      canvas.drawLine(center, center + const Offset(0, 40),
          Paint()..color = const Color(0xFF40916C)..strokeWidth = 4);
      // Petals.
      const petals = 6;
      for (var i = 0; i < petals; i++) {
        final a = i * 2 * math.pi / petals + f.sway * 0.2;
        final pc = center + Offset(math.cos(a), math.sin(a)) * 14 * scale;
        canvas.drawCircle(pc, 10 * scale,
            Paint()..color = petalColor.withOpacity(0.85));
      }
      // Center.
      canvas.drawCircle(center, 8 * scale,
          Paint()..color = Color.lerp(Colors.yellow, Colors.orange, f.bloom)!);
      if (f.bloom > 0) {
        canvas.drawCircle(center, 24 * scale,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = petalColor.withOpacity(f.bloom));
      }
    }
  }

  @override
  bool shouldRepaint(_GardenPainter oldDelegate) => true;
}
