import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/tone_player.dart';
import 'toys_particles.dart' show rainbow;

// ===========================================================================
// Paint With Light — finger leaves a glowing, slowly-fading trail.
// ===========================================================================
class PaintWithLightToy extends StatefulWidget {
  const PaintWithLightToy({super.key});
  @override
  State<PaintWithLightToy> createState() => _PaintWithLightToyState();
}

class _PaintWithLightToyState extends State<PaintWithLightToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_LightDot> _dots = <_LightDot>[];
  double _hue = 0;

  void _add(Offset p) {
    _dots.add(_LightDot(pos: p, hue: _hue, life: 1));
    _hue = (_hue + 0.01) % 1.0;
  }

  @override
  void onTick(double dt) {
    for (final d in _dots) {
      d.life -= dt * 0.25;
    }
    _dots.removeWhere((d) => d.life <= 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Listener(
          onPointerDown: (e) {
            TonePlayer.instance.haptic(HapticFeedback.selectionClick);
            _add(e.localPosition);
          },
          onPointerMove: (e) => _add(e.localPosition),
          child: CustomPaint(painter: _LightPainter(_dots), size: Size.infinite),
        ),
        // The onboarding hint is drawn only onto the canvas (invisible to
        // screen readers); IgnorePointer keeps it from stealing touches.
        Positioned.fill(
          child: IgnorePointer(
            child: Semantics(label: 'Draw with your finger'),
          ),
        ),
      ],
    );
  }
}

class _LightDot {
  _LightDot({required this.pos, required this.hue, required this.life});
  Offset pos;
  double hue, life;
}

class _LightPainter extends CustomPainter {
  _LightPainter(this.dots);
  final List<_LightDot> dots;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF02010A));
    // A pure black canvas with zero ambient motion gives a child no clue this
    // is a finger-drawing toy — show a fading hint until the first stroke,
    // the same pattern already used by CarTrackBuilderToy's empty state.
    if (dots.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Draw with your finger ✨',
          style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    for (final d in dots) {
      final o = d.life.clamp(0.0, 1.0);
      glow.color = rainbow(d.hue, v: 1).withOpacity(o * 0.9);
      canvas.drawCircle(d.pos, 10 + o * 6, glow);
    }
    // Bright cores.
    final core = Paint();
    for (final d in dots) {
      core.color = Colors.white.withOpacity(d.life.clamp(0.0, 1.0) * 0.8);
      canvas.drawCircle(d.pos, 3, core);
    }
  }

  @override
  bool shouldRepaint(_LightPainter oldDelegate) => true;
}

// ===========================================================================
// Magnetic Balls — physics balls attracted to (or repelled from) your finger.
// ===========================================================================
class MagneticBallsToy extends StatefulWidget {
  const MagneticBallsToy({super.key});
  @override
  State<MagneticBallsToy> createState() => _MagneticBallsToyState();
}

class _MagneticBallsToyState extends State<MagneticBallsToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Ball> _balls = <_Ball>[];
  final math.Random _r = math.Random();
  Offset? _finger;
  bool _seeded = false;

  void _seed(Size size) {
    for (var i = 0; i < 26; i++) {
      _balls.add(_Ball(
        pos: Offset(_r.nextDouble() * size.width, _r.nextDouble() * size.height),
        vel: Offset.zero,
        radius: 14 + _r.nextDouble() * 18,
        hue: _r.nextDouble(),
      ));
    }
    _seeded = true;
  }

  @override
  void onTick(double dt) {
    final size = context.size ?? Size.zero;
    if (!_seeded && size != Size.zero) _seed(size);

    for (final b in _balls) {
      if (_finger != null) {
        final toF = _finger! - b.pos;
        final dist = toF.distance.clamp(30.0, 5000.0);
        b.vel += toF / dist * 1400 * dt;
      }
      b.vel *= 0.92; // damping
      b.pos += b.vel * dt;
      // Walls. Like InfiniteMarbleRunToy's peg field, this toy has real
      // physics collisions that were entirely silent — a ball bouncing hard
      // off the edge should be heard, not just seen. SoundCue.marble's own
      // 60ms cooldown keeps a cluster of simultaneous bounces from spamming.
      if (b.pos.dx < b.radius) {
        b.pos = Offset(b.radius, b.pos.dy);
        if (b.vel.dx.abs() > 60) TonePlayer.instance.playCue(SoundCue.marble);
        b.vel = Offset(-b.vel.dx * 0.6, b.vel.dy);
      }
      if (b.pos.dx > size.width - b.radius) {
        b.pos = Offset(size.width - b.radius, b.pos.dy);
        if (b.vel.dx.abs() > 60) TonePlayer.instance.playCue(SoundCue.marble);
        b.vel = Offset(-b.vel.dx * 0.6, b.vel.dy);
      }
      if (b.pos.dy < b.radius) {
        b.pos = Offset(b.pos.dx, b.radius);
        if (b.vel.dy.abs() > 60) TonePlayer.instance.playCue(SoundCue.marble);
        b.vel = Offset(b.vel.dx, -b.vel.dy * 0.6);
      }
      if (b.pos.dy > size.height - b.radius) {
        b.pos = Offset(b.pos.dx, size.height - b.radius);
        if (b.vel.dy.abs() > 60) TonePlayer.instance.playCue(SoundCue.marble);
        b.vel = Offset(b.vel.dx, -b.vel.dy * 0.6);
      }
    }
    // Simple pairwise separation so they don't overlap; a real impact (fast
    // closing speed, not just gentle magnetic clustering) also gets the same
    // tactile click the walls just earned above.
    for (var i = 0; i < _balls.length; i++) {
      for (var j = i + 1; j < _balls.length; j++) {
        final a = _balls[i], c = _balls[j];
        final delta = c.pos - a.pos;
        final d = delta.distance;
        final min = a.radius + c.radius;
        if (d > 0 && d < min) {
          final n = delta / d;
          final closing = (a.vel.dx - c.vel.dx) * n.dx +
              (a.vel.dy - c.vel.dy) * n.dy;
          if (closing > 70) {
            TonePlayer.instance.playCue(SoundCue.marble);
          }
          final push = n * (min - d) / 2;
          a.pos -= push;
          c.pos += push;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) { _finger = e.localPosition; TonePlayer.instance.haptic(HapticFeedback.selectionClick); },
      onPointerMove: (e) => _finger = e.localPosition,
      onPointerUp: (_) => _finger = null,
      onPointerCancel: (_) => _finger = null,
      child: CustomPaint(painter: _BallsPainter(_balls, _finger), size: Size.infinite),
    );
  }
}

class _Ball {
  _Ball({required this.pos, required this.vel, required this.radius, required this.hue});
  Offset pos, vel;
  double radius, hue;
}

class _BallsPainter extends CustomPainter {
  _BallsPainter(this.balls, this.finger);
  final List<_Ball> balls;
  final Offset? finger;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0B1020));
    if (finger != null) {
      canvas.drawCircle(finger!, 26,
          Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)..color = Colors.white24);
    }
    for (final b in balls) {
      final c = rainbow(b.hue, s: 0.75, v: 1);
      canvas.drawCircle(
        b.pos,
        b.radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[Color.lerp(c, Colors.white, 0.5)!, c],
            stops: const <double>[0.0, 1.0],
          ).createShader(Rect.fromCircle(center: b.pos, radius: b.radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_BallsPainter oldDelegate) => true;
}
