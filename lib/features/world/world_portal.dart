import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A tappable, living object inside the magical world.
///
/// Wraps a passive art [child] (one of the world objects) and gives it a
/// uniform tactile feel: an endless idle bob, a press squash, a glow bloom, a
/// burst of celebratory particles, a haptic tap, and a soft floating name
/// label that appears the moment the child touches it. After a short delight
/// beat it calls [onActivate] (which routes into the real feature). Nothing
/// here looks like a button — it is an object you discover by touching.
class WorldPortal extends StatefulWidget {
  const WorldPortal({
    super.key,
    required this.child,
    required this.label,
    required this.glow,
    required this.onActivate,
    this.size = 150,
    this.bobSeconds = 4,
    this.phase = 0,
  });

  /// The art object to host (e.g. a [BubbleMachineObject]).
  final Widget child;

  /// The friendly name that floats up when touched ("Bubbles", "Talk"...).
  final String label;

  /// The signature glow colour for this object.
  final Color glow;

  /// Invoked after the touch-delight beat — usually a navigation push.
  final VoidCallback onActivate;

  /// Logical size of the object box (square).
  final double size;

  /// Idle-bob period; varied per object so the world breathes organically.
  final double bobSeconds;

  /// Starting phase offset (0..1) so objects don't bob in lockstep.
  final double phase;

  @override
  State<WorldPortal> createState() => _WorldPortalState();
}

class _WorldPortalState extends State<WorldPortal>
    with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _press;
  late final AnimationController _burst;
  bool _showLabel = false;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.bobSeconds * 1000).round()),
    )..repeat(reverse: true);
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0,
      upperBound: 1,
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _bob.dispose();
    _press.dispose();
    _burst.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.mediumImpact();
    setState(() => _showLabel = true);
    _burst
      ..reset()
      ..forward();
    await _press.forward();
    await _press.reverse();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    widget.onActivate();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _showLabel = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s + 34,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press.forward(),
        onTapCancel: () => _press.reverse(),
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_bob, _press, _burst]),
          builder: (context, _) {
            final bob = math.sin((_bob.value + widget.phase) * math.pi * 2);
            final dy = bob * s * 0.035;
            final tilt = bob * 0.02;
            final pressT = Curves.easeOut.transform(_press.value);
            final scale = 1 - pressT * 0.10;
            final glowStrength = 0.35 + pressT * 0.55 + _burst.value * 0.2;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: <Widget>[
                // Soft signature glow halo behind the object.
                Positioned(
                  top: s * 0.12,
                  child: IgnorePointer(
                    child: Container(
                      width: s * 0.82,
                      height: s * 0.82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: widget.glow.withOpacity(0.45 * glowStrength),
                            blurRadius: 38 + pressT * 26,
                            spreadRadius: 2 + pressT * 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Particle burst on touch.
                if (_burst.isAnimating)
                  Positioned(
                    top: 0,
                    child: IgnorePointer(
                      child: CustomPaint(
                        size: Size(s, s),
                        painter: _BurstPainter(
                          t: _burst.value,
                          color: widget.glow,
                        ),
                      ),
                    ),
                  ),
                // The living object itself.
                Positioned(
                  top: 0,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.rotate(
                      angle: tilt,
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox(width: s, height: s, child: widget.child),
                      ),
                    ),
                  ),
                ),
                // Floating name label that blooms on touch.
                Positioned(
                  bottom: 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    offset: _showLabel ? Offset.zero : const Offset(0, 0.5),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showLabel ? 1 : 0,
                      child: _NameTag(label: widget.label, color: widget.glow),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NameTag extends StatelessWidget {
  const _NameTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 16),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.5);
    final ease = Curves.easeOut.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    final rnd = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 14; i++) {
      final ang = (i / 14) * math.pi * 2 + rnd.nextDouble() * 0.5;
      final dist = size.shortestSide * (0.15 + ease * 0.5) * (0.7 + rnd.nextDouble() * 0.6);
      final p = center + Offset(math.cos(ang), math.sin(ang)) * dist;
      final r = size.shortestSide * 0.035 * fade * (0.6 + rnd.nextDouble());
      paint.color = Color.lerp(color, Colors.white, rnd.nextDouble() * 0.6)!
          .withOpacity(0.9 * fade);
      canvas.drawCircle(p, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}
