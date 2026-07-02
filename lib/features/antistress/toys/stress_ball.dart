import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A full-bleed squishy stress ball fidget toy.
///
/// One big squishy gradient ball centered on screen. Press-and-drag deforms it
/// (jelly wobble — squashing toward the press point and bulging elsewhere). On
/// release it springs back with a damped wobble. Haptic on press. Soft warm
/// gradient background.
class StressBallToy extends StatefulWidget {
  const StressBallToy({super.key});

  @override
  State<StressBallToy> createState() => _StressBallToyState();
}

class _StressBallToyState extends State<StressBallToy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring;

  // Normalized press offset from the ball center (-1..1 range, roughly).
  Offset _press = Offset.zero;
  // Smoothed/active deformation vector that the painter reads.
  Offset _deform = Offset.zero;
  bool _isPressing = false;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addListener(_onSpringTick);
  }

  void _onSpringTick() {
    if (_isPressing) {
      return;
    }
    // Damped spring wobble back toward zero.
    final double t = _spring.value;
    final double envelope = math.exp(-5.0 * t);
    final double wobble = math.cos(t * math.pi * 6.0);
    final double factor = envelope * wobble;
    setState(() {
      _deform = _press * factor;
    });
  }

  void _start(Offset local, Size size) {
    HapticFeedback.mediumImpact();
    _spring.stop();
    setState(() {
      _isPressing = true;
      _press = _toNormalized(local, size);
      _deform = _press;
    });
  }

  void _update(Offset local, Size size) {
    setState(() {
      _press = _toNormalized(local, size);
      _deform = _press;
    });
  }

  void _end() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPressing = false;
    });
    _spring.forward(from: 0.0);
  }

  Offset _toNormalized(Offset local, Size size) {
    final double r = _ballRadius(size);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Offset delta = local - center;
    // Clamp magnitude so deformation stays controlled.
    final double maxR = r;
    final double dx = (delta.dx / maxR).clamp(-1.0, 1.0);
    final double dy = (delta.dy / maxR).clamp(-1.0, 1.0);
    return Offset(dx, dy);
  }

  double _ballRadius(Size size) {
    return math.min(size.width, size.height) * 0.34;
  }

  @override
  void dispose() {
    _spring.removeListener(_onSpringTick);
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFF1E6), Color(0xFFFFE0D6)],
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (DragDownDetails d) => _start(d.localPosition, size),
            onPanStart: (DragStartDetails d) => _update(d.localPosition, size),
            onPanUpdate: (DragUpdateDetails d) =>
                _update(d.localPosition, size),
            onPanEnd: (DragEndDetails d) => _end(),
            onPanCancel: _end,
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _StressBallPainter(
                  deform: _deform,
                  radius: _ballRadius(size),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paints the squishy gradient ball with jelly deformation.
class _StressBallPainter extends CustomPainter {
  _StressBallPainter({required this.deform, required this.radius});

  final Offset deform;
  final double radius;

  static const int _segments = 96;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Soft contact shadow under the ball.
    final Paint shadowPaint = Paint()
      ..color = const Color(0xFFB07A6A).withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(
      center.translate(0, radius * 0.35),
      radius * 0.95,
      shadowPaint,
    );

    final Path path = _buildJellyPath(center);

    // Body gradient.
    final Rect bounds = Rect.fromCircle(center: center, radius: radius * 1.2);
    final Paint bodyPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.4, -0.5),
        radius: 1.0,
        colors: <Color>[
          Color(0xFFFFC1A6),
          Color(0xFFFF8C6B),
          Color(0xFFE85D75),
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(bounds);
    canvas.drawPath(path, bodyPaint);

    // Glossy highlight that shifts opposite the press for a wet, squishy feel.
    final Offset highlightCenter = center +
        Offset(-radius * 0.32, -radius * 0.36) -
        deform * (radius * 0.18);
    final Paint glossPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withOpacity(0.75),
          Colors.white.withOpacity(0.0),
        ],
        stops: const <double>[0.0, 1.0],
      ).createShader(
        Rect.fromCircle(center: highlightCenter, radius: radius * 0.55),
      );
    canvas.save();
    canvas.clipPath(path);
    canvas.drawCircle(highlightCenter, radius * 0.55, glossPaint);

    // Subtle inner shadow toward the press point for depth.
    final Offset pressPoint = center + deform * radius;
    final Paint innerShade = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF8A2E45).withOpacity(0.28),
          const Color(0xFF8A2E45).withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: pressPoint, radius: radius * 0.8),
      );
    canvas.drawCircle(pressPoint, radius * 0.8, innerShade);
    canvas.restore();
  }

  /// Builds a closed blob path that squashes toward the press direction and
  /// bulges on the opposite side — a jelly/squish effect.
  Path _buildJellyPath(Offset center) {
    final Path path = Path();
    final double mag = deform.distance.clamp(0.0, 1.0);
    final double pressAngle = math.atan2(deform.dy, deform.dx);
    final double amount = mag * 0.30; // max 30% deformation

    for (int i = 0; i <= _segments; i++) {
      final double a = (i / _segments) * math.pi * 2;
      // Angular alignment with press direction: 1 at press, -1 opposite.
      final double align = math.cos(a - pressAngle);
      // Flatten toward press, bulge away from it.
      final double r = radius * (1.0 - amount * align);
      final Offset p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _StressBallPainter oldDelegate) {
    return oldDelegate.deform != deform || oldDelegate.radius != radius;
  }
}
