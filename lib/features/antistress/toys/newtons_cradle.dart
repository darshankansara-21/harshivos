import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A calming Newton's cradle fidget toy.
///
/// Five polished metal balls hang from strings. Drag an end ball up and let go;
/// it swings down and transfers its momentum so the opposite end ball kicks out,
/// clicking softly at every collision. Endless, soothing, no fail state.
class NewtonsCradleToy extends StatefulWidget {
  const NewtonsCradleToy({super.key});

  @override
  State<NewtonsCradleToy> createState() => _NewtonsCradleToyState();
}

class _NewtonsCradleToyState extends State<NewtonsCradleToy>
    with SingleTickerProviderStateMixin {
  static const int _ballCount = 5;

  late final AnimationController _ticker;
  Duration _lastTick = Duration.zero;

  // Pendulum angles (radians, 0 = straight down) and angular velocities.
  final List<double> _angle = List<double>.filled(_ballCount, 0);
  final List<double> _vel = List<double>.filled(_ballCount, 0);

  // Drag state.
  int _draggingIndex = -1;
  Size _size = Size.zero;

  // Geometry, recomputed on layout.
  double _stringLength = 1;
  double _ballRadius = 1;
  double _pivotY = 0;
  final List<double> _pivotX = List<double>.filled(_ballCount, 0);

  // Physics constants.
  static const double _gravity = 22.0; // tuned for screen-space pendulum
  static const double _damping = 0.06; // gentle energy loss per second

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1), // continuous ticker
    )..addListener(_onTick);
    _ticker.forward();
    // A gentle initial nudge on the first ball so it's alive on open.
    _angle[0] = -0.7;
  }

  @override
  void dispose() {
    _ticker
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _layout(Size size) {
    if (size == _size) return;
    _size = size;
    final double w = size.width;
    final double h = size.height;
    _ballRadius = (w / (_ballCount * 2.6)).clamp(14.0, 46.0);
    final double gap = _ballRadius * 2.04; // near-touching at rest
    final double totalWidth = gap * (_ballCount - 1);
    final double startX = (w - totalWidth) / 2;
    for (int i = 0; i < _ballCount; i++) {
      _pivotX[i] = startX + gap * i;
    }
    _pivotY = h * 0.16;
    _stringLength = h * 0.52;
  }

  void _onTick() {
    final Duration now = _ticker.lastElapsedDuration ?? Duration.zero;
    double dt = (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    if (dt <= 0) return;
    dt = dt.clamp(0.0, 1 / 30); // stability clamp

    // Integrate each pendulum (except the one being dragged).
    for (int i = 0; i < _ballCount; i++) {
      if (i == _draggingIndex) continue;
      final double accel = -_gravity / (_stringLength / 100) * math.sin(_angle[i]);
      _vel[i] += accel * dt;
      _vel[i] *= (1 - _damping * dt);
      _angle[i] += _vel[i] * dt;
    }

    _resolveCollisions();

    if (mounted) setState(() {});
  }

  /// Energy-conserving collision: adjacent balls swap angular velocity when
  /// they meet at the bottom (the classic cradle behaviour).
  void _resolveCollisions() {
    for (int i = 0; i < _ballCount - 1; i++) {
      final int j = i + 1;
      // The balls touch near the centre; collision happens when the left ball
      // swings right (vel>0) into the right ball or vice versa, and both are
      // close to vertical.
      final bool closing = _angle[i] >= _angle[j] - 1e-3;
      final bool approaching = _vel[i] - _vel[j] > 0.02;
      if (closing && approaching) {
        // Swap velocities (equal masses, elastic).
        final double tmp = _vel[i];
        _vel[i] = _vel[j];
        _vel[j] = tmp;
        // Separate them to avoid sticking.
        final double mid = (_angle[i] + _angle[j]) / 2;
        _angle[i] = mid - 1e-3;
        _angle[j] = mid + 1e-3;
        if (i == _draggingIndex || j == _draggingIndex) continue;
        final double impact = tmp.abs();
        if (impact > 0.25) {
          HapticFeedback.selectionClick();
        }
      }
    }
  }

  Offset _ballCenter(int i) {
    final double x = _pivotX[i] + math.sin(_angle[i]) * _stringLength;
    final double y = _pivotY + math.cos(_angle[i]) * _stringLength;
    return Offset(x, y);
  }

  int _hitTest(Offset p) {
    for (int i = 0; i < _ballCount; i++) {
      if ((p - _ballCenter(i)).distance <= _ballRadius * 1.4) return i;
    }
    return -1;
  }

  void _onPanStart(DragStartDetails d) {
    final int i = _hitTest(d.localPosition);
    if (i != -1) {
      _draggingIndex = i;
      _vel[i] = 0;
      HapticFeedback.lightImpact();
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_draggingIndex == -1) return;
    final int i = _draggingIndex;
    final Offset rel = d.localPosition - Offset(_pivotX[i], _pivotY);
    double a = math.atan2(rel.dx, rel.dy.abs().clamp(1.0, double.infinity));
    a = a.clamp(-1.35, 1.35);
    _angle[i] = a;
    _vel[i] = 0;
  }

  void _onPanEnd(DragEndDetails d) {
    if (_draggingIndex == -1) return;
    _vel[_draggingIndex] = 0;
    _draggingIndex = -1;
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _layout(Size(constraints.maxWidth, constraints.maxHeight));
        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF1B2440), Color(0xFF0B1020)],
              ),
            ),
            child: CustomPaint(
              painter: _CradlePainter(
                angles: _angle,
                pivotX: _pivotX,
                pivotY: _pivotY,
                stringLength: _stringLength,
                ballRadius: _ballRadius,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _CradlePainter extends CustomPainter {
  _CradlePainter({
    required this.angles,
    required this.pivotX,
    required this.pivotY,
    required this.stringLength,
    required this.ballRadius,
  });

  final List<double> angles;
  final List<double> pivotX;
  final double pivotY;
  final double stringLength;
  final double ballRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // Top support bar.
    final double barY = pivotY - ballRadius * 0.5;
    final Rect bar = Rect.fromLTWH(
      pivotX.first - ballRadius,
      barY - 8,
      (pivotX.last - pivotX.first) + ballRadius * 2,
      14,
    );
    final Paint barPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF5A6480), Color(0xFF2C3350)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bar);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(6)), barPaint);

    final Paint string = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.4;

    for (int i = 0; i < angles.length; i++) {
      final double a = angles[i];
      final Offset pivot = Offset(pivotX[i], pivotY);
      final Offset center = Offset(
        pivotX[i] + math.sin(a) * stringLength,
        pivotY + math.cos(a) * stringLength,
      );
      canvas.drawLine(pivot, center, string);
      _drawBall(canvas, center);
    }
  }

  void _drawBall(Canvas canvas, Offset c) {
    // Soft glow.
    canvas.drawCircle(
      c,
      ballRadius * 1.25,
      Paint()
        ..color = const Color(0xFF8FB4FF).withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Metallic body.
    final Rect r = Rect.fromCircle(center: c, radius: ballRadius);
    final Paint body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        colors: <Color>[
          const Color(0xFFEFF4FF),
          const Color(0xFFAFC0E0),
          const Color(0xFF5B6B8C),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(r);
    canvas.drawCircle(c, ballRadius, body);
    // Specular highlight.
    canvas.drawCircle(
      c + Offset(-ballRadius * 0.32, -ballRadius * 0.36),
      ballRadius * 0.26,
      Paint()..color = Colors.white.withOpacity(0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _CradlePainter oldDelegate) => true;
}
