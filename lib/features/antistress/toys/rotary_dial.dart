import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/audio/tone_player.dart';

/// An old telephone rotary dial fidget toy.
///
/// A centered disc with ten finger holes (0-9). Drag a hole clockwise to the
/// finger-stop and release; the dial spins back to rest with a decelerating
/// animation, ticking with haptics past each number. Purely satisfying — no
/// fail states, just the mechanical return.
class RotaryDialToy extends StatefulWidget {
  const RotaryDialToy({super.key});

  @override
  State<RotaryDialToy> createState() => _RotaryDialToyState();
}

class _RotaryDialToyState extends State<RotaryDialToy>
    with SingleTickerProviderStateMixin {
  /// Angular span between adjacent finger holes (radians).
  static const double _holeStep = math.pi * 2 / 12;

  /// The finger-stop sits just past hole 0's travel.
  static const double _maxRotation = _holeStep * 10;

  late final AnimationController _controller;

  Size _size = Size.zero;
  Offset _center = Offset.zero;
  double _radius = 0;

  /// Current rotation of the dial in radians (0 = rest).
  double _rotation = 0.0;

  // Drag state.
  bool _dragging = false;
  double _dragStartAngle = 0.0;
  double _rotationAtDragStart = 0.0;

  // Return-spring state.
  bool _returning = false;
  double _returnVelocity = 0.0;
  int _lastTickIndex = 0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_onTick);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _ensureMetrics(Size size) {
    if (size == _size && _radius > 0) return;
    _size = size;
    _center = Offset(size.width / 2, size.height / 2);
    _radius = math.min(size.width, size.height) * 0.40;
  }

  double _angleFromCenter(Offset p) {
    final Offset d = p - _center;
    return math.atan2(d.dy, d.dx);
  }

  void _onTick() {
    final Duration elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    dt = math.min(dt, 1 / 30);

    if (!_returning) return;

    // Decelerating return: accelerate toward rest, then settle.
    const double accel = 26.0;
    if (_rotation > 0) {
      _returnVelocity -= accel * dt;
    }
    _rotation += _returnVelocity * dt;

    if (_rotation <= 0) {
      _rotation = 0;
      _returnVelocity = 0;
      _returning = false;
      HapticFeedback.mediumImpact();
      TonePlayer.instance.playThock(pitch: 0.8);
    } else {
      _emitTicks();
    }

    if (mounted) setState(() {});
  }

  /// Fire a haptic tick each time the dial passes a hole boundary.
  void _emitTicks() {
    final int idx = (_rotation / _holeStep).floor();
    if (idx != _lastTickIndex) {
      _lastTickIndex = idx;
      HapticFeedback.selectionClick();
      TonePlayer.instance.playTick();
    }
  }

  void _onPanStart(DragStartDetails d) {
    if (_returning) return;
    _dragging = true;
    _dragStartAngle = _angleFromCenter(d.localPosition);
    _rotationAtDragStart = _rotation;
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final double angleNow = _angleFromCenter(d.localPosition);
    double delta = angleNow - _dragStartAngle;
    // Normalize into a sensible range so wrap-around is smooth.
    while (delta > math.pi) {
      delta -= math.pi * 2;
    }
    while (delta < -math.pi) {
      delta += math.pi * 2;
    }
    double target = _rotationAtDragStart + delta;
    target = target.clamp(0.0, _maxRotation);

    final int prevIdx = (_rotation / _holeStep).floor();
    final int newIdx = (target / _holeStep).floor();
    if (newIdx != prevIdx) {
      HapticFeedback.selectionClick();
      TonePlayer.instance.playTick();
    }
    setState(() => _rotation = target);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    if (_rotation <= 0.001) {
      _rotation = 0;
      return;
    }
    // Begin the decelerating spin-back.
    _returning = true;
    _returnVelocity = -3.2;
    _lastTickIndex = (_rotation / _holeStep).floor();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureMetrics(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: () => _dragging = false,
          child: CustomPaint(
            painter: _DialPainter(
              rotation: _rotation,
              holeStep: _holeStep,
            ),
            size: size,
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.rotation, required this.holeStep});

  final double rotation;
  final double holeStep;

  static const List<int> _digits = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 0];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Paint bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF233044), Color(0xFF121A2A)],
      ).createShader(bounds);
    canvas.drawRect(bounds, bg);

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) * 0.40;

    // Fixed number ring (does not rotate) — drawn behind the dial.
    _paintNumberRing(canvas, center, radius);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Dial face.
    final Paint face = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFFEFE7D6),
          const Color(0xFFCBBEA3),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, face);

    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF8A7C5E).withOpacity(0.9);
    canvas.drawCircle(Offset.zero, radius, rim);

    // Finger holes positioned around the upper arc.
    final double holeRadius = radius * 0.13;
    final double ringRadius = radius * 0.72;
    final Paint holePaint = Paint()..color = const Color(0xFF1B2230);
    final Paint holeRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF6B5E45).withOpacity(0.8);

    for (int i = 0; i < _digits.length; i++) {
      final double a = _holeAngle(i);
      final Offset hc =
          Offset(math.cos(a) * ringRadius, math.sin(a) * ringRadius);
      canvas.drawCircle(hc, holeRadius, holePaint);
      canvas.drawCircle(hc, holeRadius, holeRing);

      _paintHoleLabel(canvas, hc, _digits[i], holeRadius, rotation);
    }

    // Center hub.
    final Paint hub = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0xFFD8CCB2), Color(0xFFA8997A)],
      ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: radius * 0.28));
    canvas.drawCircle(Offset.zero, radius * 0.28, hub);

    canvas.restore();

    // Finger-stop (fixed, lower-right), drawn on top.
    _paintFingerStop(canvas, center, radius);
  }

  double _holeAngle(int i) {
    // Holes arranged clockwise starting from the lower-left, sweeping up
    // and over toward the finger-stop at the lower-right.
    const double start = math.pi * 0.78;
    return start + i * holeStep;
  }

  void _paintHoleLabel(
    Canvas canvas,
    Offset holeCenter,
    int digit,
    double holeRadius,
    double rotation,
  ) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '$digit',
        style: TextStyle(
          color: const Color(0xFFEDE6D6),
          fontSize: holeRadius * 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(holeCenter.dx, holeCenter.dy);
    // Counter-rotate so digits stay upright as the dial turns.
    canvas.rotate(-rotation);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _paintNumberRing(Canvas canvas, Offset center, double radius) {
    final double labelRadius = radius * 1.08;
    for (int i = 0; i < _digits.length; i++) {
      final double a = _holeAngle(i);
      final Offset lc = center +
          Offset(math.cos(a) * labelRadius, math.sin(a) * labelRadius);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${_digits[i]}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: radius * 0.085,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, lc - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintFingerStop(Canvas canvas, Offset center, double radius) {
    final double a = _holeAngle(_digits.length);
    final Offset base = center +
        Offset(math.cos(a) * radius * 0.86, math.sin(a) * radius * 0.86);
    final Paint stop = Paint()
      ..color = const Color(0xFF8A7C5E)
      ..style = PaintingStyle.fill;
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: base, width: radius * 0.16, height: radius * 0.34),
        const Radius.circular(6),
      ));
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, stop);
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}
