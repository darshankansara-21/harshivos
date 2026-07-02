import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A slow, hypnotic lava-lamp fidget toy.
///
/// Several soft glowing blobs drift up and sink in a warm gradient column,
/// gently stretching and visually merging (approximate metaballs via
/// overlapping radial-gradient circles). Drag to push blobs around; they
/// ease back to their natural float afterwards.
class LavaBlobsToy extends StatefulWidget {
  const LavaBlobsToy({super.key});

  @override
  State<LavaBlobsToy> createState() => _LavaBlobsToyState();
}

class _LavaBlobsToyState extends State<LavaBlobsToy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Blob> _blobs = <_Blob>[];
  final math.Random _rng = math.Random(7);

  Offset? _pushPoint;
  double _lastHapticPhase = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    for (int i = 0; i < 7; i++) {
      _blobs.add(_Blob(
        baseX: 0.18 + _rng.nextDouble() * 0.64,
        radius: 0.10 + _rng.nextDouble() * 0.10,
        phase: _rng.nextDouble(),
        speed: 0.18 + _rng.nextDouble() * 0.22,
        wobbleAmp: 0.02 + _rng.nextDouble() * 0.05,
        wobbleSpeed: 0.4 + _rng.nextDouble() * 0.8,
        hue: _rng.nextDouble(),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePush(Offset localPosition, Size size) {
    setState(() {
      _pushPoint = Offset(
        localPosition.dx / size.width,
        localPosition.dy / size.height,
      );
    });
    final double phase = _controller.value * 8;
    if ((phase - _lastHapticPhase).abs() > 1) {
      _lastHapticPhase = phase;
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) {
            HapticFeedback.lightImpact();
            _handlePush(d.localPosition, size);
          },
          onPanUpdate: (DragUpdateDetails d) =>
              _handlePush(d.localPosition, size),
          onPanEnd: (DragEndDetails d) {
            HapticFeedback.mediumImpact();
            setState(() => _pushPoint = null);
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _LavaPainter(
                  t: _controller.value,
                  blobs: _blobs,
                  pushPoint: _pushPoint,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Blob {
  _Blob({
    required this.baseX,
    required this.radius,
    required this.phase,
    required this.speed,
    required this.wobbleAmp,
    required this.wobbleSpeed,
    required this.hue,
  });

  final double baseX;
  final double radius;
  final double phase;
  final double speed;
  final double wobbleAmp;
  final double wobbleSpeed;
  final double hue;
}

class _LavaPainter extends CustomPainter {
  _LavaPainter({
    required this.t,
    required this.blobs,
    required this.pushPoint,
  });

  final double t;
  final List<_Blob> blobs;
  final Offset? pushPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Warm gradient column background.
    final Paint bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF2A0A3A),
          Color(0xFF6E1846),
          Color(0xFFB23A2E),
          Color(0xFF3A0B2E),
        ],
        stops: <double>[0.0, 0.4, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Soft inner vignette glow for warmth.
    final Paint vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: <Color>[
          const Color(0xFFFFB347).withOpacity(0.18),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);

    canvas.saveLayer(rect, Paint());
    for (final _Blob blob in blobs) {
      // Vertical float: slow up-and-down using a sine over its phase.
      final double cycle = (t * blob.speed + blob.phase) % 1.0;
      final double floatY = 0.5 - 0.42 * math.cos(cycle * 2 * math.pi);
      final double wobbleX =
          blob.wobbleAmp * math.sin((t * blob.wobbleSpeed + blob.phase) * 2 * math.pi);

      double cx = (blob.baseX + wobbleX) * size.width;
      double cy = floatY * size.height;

      // Vertical stretch near the ends of travel (squash/merge feel).
      final double stretch =
          1.0 + 0.35 * math.sin(cycle * 2 * math.pi).abs();

      // Drag push: blobs near the touch point get nudged away.
      if (pushPoint != null) {
        final Offset push = Offset(
          pushPoint!.dx * size.width,
          pushPoint!.dy * size.height,
        );
        final double dx = cx - push.dx;
        final double dy = cy - push.dy;
        final double dist = math.sqrt(dx * dx + dy * dy);
        final double reach = size.shortestSide * 0.45;
        if (dist < reach && dist > 0.001) {
          final double force = (1 - dist / reach) * size.shortestSide * 0.18;
          cx += dx / dist * force;
          cy += dy / dist * force;
        }
      }

      final double r = blob.radius * size.shortestSide;
      final Color core = HSVColor.fromAHSV(
        1.0,
        (28 + blob.hue * 28) % 360,
        0.85,
        1.0,
      ).toColor();

      final Rect blobRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: r * 2,
        height: r * 2 * stretch,
      );

      final Paint glow = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            core.withOpacity(0.95),
            core.withOpacity(0.45),
            core.withOpacity(0.0),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(blobRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(1.0, stretch);
      canvas.translate(-cx, -cy);
      canvas.drawCircle(Offset(cx, cy), r, glow);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LavaPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.pushPoint != pushPoint;
}
