import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A mesmerizing rainbow slinky fidget toy.
///
/// A chain of points connected by springs. The head follows your finger and
/// the rest of the coils trail behind, bouncing with soft springy physics.
/// Drawn as overlapping rainbow rings for that classic slinky shimmer.
class SlinkyToy extends StatefulWidget {
  const SlinkyToy({super.key});

  @override
  State<SlinkyToy> createState() => _SlinkyToyState();
}

class _SlinkyToyState extends State<SlinkyToy>
    with SingleTickerProviderStateMixin {
  static const int _pointCount = 30;
  static const double _segmentLength = 16.0;
  static const double _stiffness = 180.0; // spring constant
  static const double _damping = 4.2; // velocity damping
  static const double _gravity = 140.0;

  late final AnimationController _ticker;
  Duration _lastTick = Duration.zero;

  final List<Offset> _pos = <Offset>[];
  final List<Offset> _vel = <Offset>[];

  Offset _target = Offset.zero;
  bool _dragging = false;
  bool _seeded = false;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onTick);
    _ticker.forward();
  }

  @override
  void dispose() {
    _ticker
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _seed(Size size) {
    if (_seeded && size == _size) return;
    _size = size;
    _seeded = true;
    _pos
      ..clear()
      ..addAll(List<Offset>.generate(
        _pointCount,
        (int i) => Offset(size.width / 2, size.height * 0.25 + i * _segmentLength),
      ));
    _vel
      ..clear()
      ..addAll(List<Offset>.filled(_pointCount, Offset.zero));
    _target = Offset(size.width / 2, size.height * 0.25);
  }

  void _onTick() {
    final Duration now = _ticker.lastElapsedDuration ?? Duration.zero;
    double dt = (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    if (dt <= 0 || _pos.isEmpty) return;
    dt = dt.clamp(0.0, 1 / 60);

    // Head: critically-damped pull toward the finger / rest target.
    final Offset toTarget = _target - _pos[0];
    _vel[0] += toTarget * (_stiffness * 0.12) * dt;
    _vel[0] *= (1 - (_damping * 1.6) * dt).clamp(0.0, 1.0);
    _pos[0] += _vel[0] * dt;

    // Body: each point spring-follows the previous point at fixed spacing,
    // plus a little gravity for a lively drape.
    for (int i = 1; i < _pointCount; i++) {
      final Offset delta = _pos[i] - _pos[i - 1];
      final double dist = delta.distance;
      final double diff = dist - _segmentLength;
      final Offset dir = dist > 1e-4 ? delta / dist : const Offset(0, 1);
      // Spring force pulling toward correct spacing.
      _vel[i] -= dir * (diff * _stiffness) * dt;
      // Gravity.
      _vel[i] += const Offset(0, _gravity) * dt;
      // Damping.
      _vel[i] *= (1 - _damping * dt).clamp(0.0, 1.0);
      _pos[i] += _vel[i] * dt;

      // Hard distance constraint keeps the coil from over-stretching.
      final Offset d2 = _pos[i] - _pos[i - 1];
      final double dd = d2.distance;
      if (dd > _segmentLength * 1.6) {
        final Offset dir2 = d2 / dd;
        _pos[i] = _pos[i - 1] + dir2 * _segmentLength * 1.6;
      }
      _bound(i);
    }

    if (mounted) setState(() {});
  }

  void _bound(int i) {
    double x = _pos[i].dx;
    double y = _pos[i].dy;
    final double r = 6;
    if (x < r) {
      x = r;
      _vel[i] = Offset(-_vel[i].dx * 0.4, _vel[i].dy);
    } else if (x > _size.width - r) {
      x = _size.width - r;
      _vel[i] = Offset(-_vel[i].dx * 0.4, _vel[i].dy);
    }
    if (y > _size.height - r) {
      y = _size.height - r;
      _vel[i] = Offset(_vel[i].dx, -_vel[i].dy * 0.4);
    }
    _pos[i] = Offset(x, y);
  }

  void _onPanStart(DragStartDetails d) {
    _dragging = true;
    _target = d.localPosition;
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _target = d.localPosition;
    HapticFeedback.selectionClick();
  }

  void _onPanEnd(DragEndDetails d) {
    _dragging = false;
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _seed(Size(constraints.maxWidth, constraints.maxHeight));
        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF101326), Color(0xFF1C1430)],
              ),
            ),
            child: CustomPaint(
              painter: _SlinkyPainter(points: _pos, dragging: _dragging),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _SlinkyPainter extends CustomPainter {
  _SlinkyPainter({required this.points, required this.dragging});

  final List<Offset> points;
  final bool dragging;

  Color _rainbow(double t) {
    return HSVColor.fromAHSV(1.0, (t * 320) % 360, 0.85, 1.0).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final int n = points.length;

    // Draw from tail to head so the head sits on top.
    for (int i = n - 1; i >= 0; i--) {
      final double t = i / (n - 1);
      final Color c = _rainbow(t);
      final double radius = 26 - t * 10; // fatter near head
      final Offset p = points[i];

      // Outer glow ring.
      canvas.drawCircle(
        p,
        radius + 4,
        Paint()
          ..color = c.withOpacity(0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Coil ring (stroke).
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = c.withOpacity(0.95),
      );
      // Inner soft fill.
      canvas.drawCircle(
        p,
        radius * 0.55,
        Paint()..color = c.withOpacity(0.30),
      );
    }

    // Bright head dot.
    canvas.drawCircle(
      points.first,
      10,
      Paint()..color = Colors.white.withOpacity(dragging ? 0.95 : 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _SlinkyPainter oldDelegate) => true;
}
