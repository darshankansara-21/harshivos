import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/tone_player.dart';
import 'toys_particles.dart' show rainbow;

// ===========================================================================
// Bubble Pop World — endless rising bubbles, satisfying haptic pops.
// ===========================================================================
class BubblePopToy extends StatefulWidget {
  const BubblePopToy({super.key});
  @override
  State<BubblePopToy> createState() => _BubblePopToyState();
}

class _BubblePopToyState extends State<BubblePopToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Bubble> _bubbles = <_Bubble>[];
  final List<_Pop> _pops = <_Pop>[];
  final math.Random _r = math.Random();
  double _spawnAcc = 0;
  // Unlike every other continuous-particle sensory toy (ParticleGalaxyToy /
  // FireworksToy already gate their burst sizes on this), BubblePopToy kept
  // spawning a dense, unbroken stream of up to 90 bubbles regardless of the
  // OS Reduce Motion setting — exactly the kind of constant ambient motion
  // that setting exists to calm down. Thin the spawn rate and the on-screen
  // cap under Reduce Motion instead of leaving this toy as the one gap.
  bool _reduceMotion = false;

  @override
  void onTick(double dt) {
    final size = context.size ?? Size.zero;
    final cap = _reduceMotion ? 28 : 90;
    _spawnAcc += dt * (_reduceMotion ? 2 : 6);
    while (_spawnAcc >= 1 && _bubbles.length < cap) {
      _spawnAcc -= 1;
      final radius = 16 + _r.nextDouble() * 38;
      _bubbles.add(_Bubble(
        pos: Offset(_r.nextDouble() * size.width, size.height + radius),
        radius: radius,
        vy: 40 + _r.nextDouble() * 70,
        wobble: _r.nextDouble() * math.pi * 2,
        hue: _r.nextDouble(),
      ));
    }
    for (final b in _bubbles) {
      b.wobble += dt * 2;
      b.pos = Offset(b.pos.dx + math.sin(b.wobble) * 16 * dt, b.pos.dy - b.vy * dt);
    }
    _bubbles.removeWhere((b) => b.pos.dy < -b.radius);
    _pops.removeWhere((p) => p.life <= 0);
    for (final p in _pops) {
      p.life -= dt * 3;
    }
  }

  void _popAt(Offset p) {
    for (final b in [..._bubbles]) {
      if ((b.pos - p).distance <= b.radius + 6) {
        _bubbles.remove(b);
        _pops.add(_Pop(pos: b.pos, radius: b.radius, hue: b.hue, life: 1));
        TonePlayer.instance.haptic(HapticFeedback.lightImpact);
        // Smaller bubbles pop higher-pitched than big ones.
        TonePlayer.instance.playPop(1 - (b.radius - 16) / 38);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: <Widget>[
        Listener(
          onPointerDown: (e) => _popAt(e.localPosition),
          onPointerMove: (e) => _popAt(e.localPosition),
          child: CustomPaint(
            painter: _BubblePainter(_bubbles, _pops),
            size: Size.infinite,
          ),
        ),
        // This free-form gesture canvas had zero Semantics tree — a blind
        // child had no way to even discover rising bubbles exist here, let
        // alone that touching pops them. Same convention as `toys_light`'s
        // onboarding hint: an invisible, IgnorePointer-wrapped label so it
        // never steals touches from the real pop gesture above.
        Positioned.fill(
          child: IgnorePointer(
            child: Semantics(label: 'Tap or drag to pop the rising bubbles'),
          ),
        ),
      ],
    );
  }
}

class _Bubble {
  _Bubble({required this.pos, required this.radius, required this.vy, required this.wobble, required this.hue});
  Offset pos;
  double radius, vy, wobble, hue;
}

class _Pop {
  _Pop({required this.pos, required this.radius, required this.hue, required this.life});
  Offset pos;
  double radius, hue, life;
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.bubbles, this.pops);
  final List<_Bubble> bubbles;
  final List<_Pop> pops;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0A2540), Color(0xFF0D3B66)],
        ).createShader(Offset.zero & size),
    );
    for (final b in bubbles) {
      final base = rainbow(b.hue, s: 0.5, v: 1);
      canvas.drawCircle(
        b.pos,
        b.radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[base.withOpacity(0.10), base.withOpacity(0.35)],
          ).createShader(Rect.fromCircle(center: b.pos, radius: b.radius)),
      );
      canvas.drawCircle(b.pos, b.radius,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.white.withOpacity(0.5));
      // Highlight.
      canvas.drawCircle(b.pos + Offset(-b.radius * 0.3, -b.radius * 0.3), b.radius * 0.18,
          Paint()..color = Colors.white.withOpacity(0.7));
    }
    for (final p in pops) {
      canvas.drawCircle(
        p.pos,
        p.radius * (1.4 - p.life * 0.4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = rainbow(p.hue, s: 0.5).withOpacity(p.life.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => true;
}

// ===========================================================================
// Water Ripples — realistic expanding, fading ripple rings.
// ===========================================================================
class WaterRipplesToy extends StatefulWidget {
  const WaterRipplesToy({super.key});
  @override
  State<WaterRipplesToy> createState() => _WaterRipplesToyState();
}

class _WaterRipplesToyState extends State<WaterRipplesToy>
    with TickerProviderStateMixin, ToyTicker {
  final List<_Ripple> _ripples = <_Ripple>[];
  double _hue = 0.55;
  // Unlike BubblePopToy (its sibling sensory toy in this same file), which
  // already thins its spawn rate and caps the on-screen particle count under
  // the OS Reduce Motion setting, a drag here could keep dropping a new
  // expanding ripple ring every ~28px of finger movement with no ceiling at
  // all — an unbroken stream of continuous ambient motion (plus a sound cue
  // per drop), exactly what Reduce Motion exists to calm down. Widen the
  // minimum drag distance between drops and cap concurrent ripples the same
  // way, instead of leaving this toy as the one remaining gap.
  bool _reduceMotion = false;

  void _drop(Offset p) {
    final cap = _reduceMotion ? 3 : 14;
    if (_ripples.length >= cap) _ripples.removeAt(0);
    _ripples.add(_Ripple(center: p, hue: _hue));
    _hue = (_hue + 0.03) % 1.0;
    TonePlayer.instance.haptic(HapticFeedback.selectionClick);
    // Each tap drops a droplet into the pool — give it the tuned water sound,
    // not silence (BubblePopToy, its sibling sensory toy, already pops audibly).
    TonePlayer.instance.playCue(SoundCue.water);
  }

  @override
  void onTick(double dt) {
    for (final r in _ripples) {
      r.radius += 160 * dt;
      r.life -= dt * 0.5;
    }
    _ripples.removeWhere((r) => r.life <= 0);
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final minDragDistance = _reduceMotion ? 70.0 : 28.0;
    return Stack(
      children: <Widget>[
        Listener(
          onPointerDown: (e) => _drop(e.localPosition),
          onPointerMove: (e) {
            if (_ripples.isEmpty ||
                (_ripples.last.center - e.localPosition).distance >
                    minDragDistance) {
              _drop(e.localPosition);
            }
          },
          child: CustomPaint(painter: _RipplePainter(_ripples), size: Size.infinite),
        ),
        // Same zero-Semantics gap as BubblePopToy above — an invisible,
        // IgnorePointer-wrapped onboarding label so a screen-reader user can
        // discover this toy exists and how to use it.
        Positioned.fill(
          child: IgnorePointer(
            child: Semantics(label: 'Tap or drag to drop ripples into the water'),
          ),
        ),
      ],
    );
  }
}

class _Ripple {
  _Ripple({required this.center, required this.hue}) : radius = 0, life = 1;
  final Offset center;
  final double hue;
  double radius, life;
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.ripples);
  final List<_Ripple> ripples;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF013A63), Color(0xFF01497C), Color(0xFF014F86)],
        ).createShader(Offset.zero & size),
    );
    // Unlike this file's sibling BubblePopToy (an ever-present stream of
    // rising bubbles gives automatic first-3-seconds visual feedback) and
    // the other blank-canvas toys that already show a fading hint until the
    // first touch (PaintWithLightToy, FireworksToy, CarTrackBuilderToy),
    // this toy is purely reactive with no fallback: a child who hasn't
    // tapped yet sees only an unchanging blue gradient with no clue it
    // responds to touch at all. Show the same onboarding hint pattern until
    // the first ripple is dropped.
    if (ripples.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Tap or drag to make ripples 💧',
          style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width - 40);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }
    for (final r in ripples) {
      final color = rainbow(r.hue, s: 0.4, v: 1).withOpacity(r.life.clamp(0.0, 1.0) * 0.8);
      for (var i = 0; i < 3; i++) {
        final rad = r.radius - i * 14;
        if (rad <= 0) continue;
        canvas.drawCircle(
          r.center,
          rad,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 - i
            ..color = color.withOpacity(color.opacity * (1 - i * 0.3)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) => true;
}
