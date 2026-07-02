import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A living, gently-breathing gradient backdrop with drifting colour blobs.
///
/// Used behind every screen. Motion is slow and continuous — designed to be
/// soothing rather than attention-grabbing.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, this.child});

  final Widget? child;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.bgTop,
            AppColors.bgMid,
            AppColors.bgBottom,
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _BlobPainter(_controller.value),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.t);

  final double t;

  static const List<Color> _colors = <Color>[
    AppColors.blobViolet,
    AppColors.blobTeal,
    AppColors.blobPink,
    AppColors.blobBlue,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final twoPi = math.pi * 2;
    for (var i = 0; i < _colors.length; i++) {
      final phase = t * twoPi + i * (twoPi / _colors.length);
      final cx = size.width * (0.5 + 0.42 * math.cos(phase + i));
      final cy = size.height * (0.5 + 0.42 * math.sin(phase * 0.8 + i));
      final radius = size.shortestSide * (0.45 + 0.08 * math.sin(phase));

      final paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _colors[i].withOpacity(0.40),
            _colors[i].withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) => oldDelegate.t != t;
}
