import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A calm water-surface fidget toy.
///
/// Tap or drag anywhere to drop water: each touch spawns an expanding
/// concentric ripple ring that fades out, plus a tiny splash droplet.
/// Multiple ripples animate concurrently and expire on their own. A soft
/// blue gradient with a gentle caustic shimmer fills the surface.
class WaterDropToy extends StatefulWidget {
  const WaterDropToy({super.key});

  @override
  State<WaterDropToy> createState() => _WaterDropToyState();
}

class _WaterDropToyState extends State<WaterDropToy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Ripple> _ripples = <_Ripple>[];

  // Elapsed seconds derived from the looping controller for ripple lifetimes.
  double _seconds = 0;
  double _lastDropAt = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..addListener(_tick);
    _controller.repeat();
  }

  void _tick() {
    // Map the looping 0..1 value onto a continuously growing second counter.
    final double now = _controller.lastElapsedDuration == null
        ? _seconds
        : _controller.lastElapsedDuration!.inMicroseconds / 1e6;
    _seconds = now;
    _ripples.removeWhere((_Ripple r) => now - r.startSeconds > r.life);
    if (_ripples.isNotEmpty) {
      setState(() {});
    }
  }

  void _drop(Offset position) {
    final double now = _seconds;
    // Throttle so dragging spawns a pleasant, spaced trail of ripples.
    if (now - _lastDropAt < 0.05) {
      // Still allow the visual but skip extra haptics on very dense drags.
    }
    _lastDropAt = now;
    _ripples.add(_Ripple(
      center: position,
      startSeconds: now,
      life: 2.6,
      maxRadius: 160 + math.Random().nextDouble() * 60,
    ));
    HapticFeedback.lightImpact();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails d) => _drop(d.localPosition),
      onPanStart: (DragStartDetails d) => _drop(d.localPosition),
      onPanUpdate: (DragUpdateDetails d) => _drop(d.localPosition),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _WaterPainter(
              ripples: _ripples,
              seconds: _seconds,
            ),
          );
        },
      ),
    );
  }
}

class _Ripple {
  _Ripple({
    required this.center,
    required this.startSeconds,
    required this.life,
    required this.maxRadius,
  });

  final Offset center;
  final double startSeconds;
  final double life;
  final double maxRadius;
}

class _WaterPainter extends CustomPainter {
  _WaterPainter({
    required this.ripples,
    required this.seconds,
  });

  final List<_Ripple> ripples;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Soft blue water gradient.
    final Paint bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF0A2A4A),
          Color(0xFF0E4D7A),
          Color(0xFF1C7FB8),
          Color(0xFF0B3A5C),
        ],
        stops: <double>[0.0, 0.4, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Subtle caustic shimmer: slow drifting light bands.
    final Paint caustic = Paint()
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    for (int i = 0; i < 4; i++) {
      final double phase = seconds * 0.25 + i * 1.7;
      final double cx =
          (0.5 + 0.4 * math.sin(phase)) * size.width;
      final double cy =
          (0.5 + 0.35 * math.cos(phase * 0.8 + i)) * size.height;
      caustic.shader = RadialGradient(
        colors: <Color>[
          Colors.white.withOpacity(0.06),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: size.shortestSide * 0.4),
      );
      canvas.drawCircle(
          Offset(cx, cy), size.shortestSide * 0.4, caustic);
    }

    // Concentric ripple rings + splash droplet per touch.
    for (final _Ripple ripple in ripples) {
      final double age = seconds - ripple.startSeconds;
      final double tNorm = (age / ripple.life).clamp(0.0, 1.0);
      final double eased = Curves.easeOut.transform(tNorm);
      final double radius = eased * ripple.maxRadius;
      final double fade = (1.0 - tNorm);

      // Two concentric rings, the inner trailing the outer slightly.
      for (int ring = 0; ring < 2; ring++) {
        final double rr = radius - ring * 16;
        if (rr <= 0) continue;
        final Paint ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3.0 - ring) * fade + 0.5
          ..color = Colors.white.withOpacity(0.35 * fade * (ring == 0 ? 1.0 : 0.6));
        canvas.drawCircle(ripple.center, rr, ringPaint);
      }

      // Inner bright core fades fast.
      if (tNorm < 0.3) {
        final double coreFade = 1 - (tNorm / 0.3);
        final Paint core = Paint()
          ..color = Colors.white.withOpacity(0.22 * coreFade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(ripple.center, 10 * coreFade + 2, core);
      }

      // Splash droplet rises then falls in the first part of the life.
      if (tNorm < 0.5) {
        final double dropT = tNorm / 0.5;
        final double lift = math.sin(dropT * math.pi) * 26;
        final Paint drop = Paint()
          ..color = Colors.white.withOpacity(0.7 * (1 - dropT))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(
          ripple.center.translate(0, -lift),
          4.5 * (1 - dropT * 0.5),
          drop,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WaterPainter oldDelegate) => true;
}
