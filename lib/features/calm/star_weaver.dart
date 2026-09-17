import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Star Weaver — a slow, no-fail *tracing* calm experience.
///
/// A handful of soft stars drift across a night sky. Dragging a finger near a
/// star threads a gentle glowing line to it; when every star is connected the
/// constellation blooms, fades, and a fresh sky drifts in. There is no timer,
/// no score and nothing to lose — only a quiet line to draw.
class StarWeaverToy extends StatefulWidget {
  const StarWeaverToy({super.key});

  @override
  State<StarWeaverToy> createState() => _StarWeaverToyState();
}

class _StarWeaverToyState extends State<StarWeaverToy>
    with SingleTickerProviderStateMixin {
  final math.Random _rng = math.Random();
  late final AnimationController _controller;
  final List<_Star> _stars = <_Star>[];
  final List<int> _order = <int>[]; // indices of connected stars, in order
  double _seconds = 0;
  double _bloomAt = -1; // when the current constellation completed

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(_tick);
    _controller.repeat();
    _spawnSky();
  }

  void _spawnSky() {
    _stars
      ..clear()
      ..addAll(List<_Star>.generate(7, (int i) {
        return _Star(
          base: Offset(0.14 + _rng.nextDouble() * 0.72,
              0.16 + _rng.nextDouble() * 0.66),
          phase: _rng.nextDouble() * math.pi * 2,
          drift: 0.012 + _rng.nextDouble() * 0.02,
          twinkle: _rng.nextDouble() * math.pi * 2,
        );
      }));
    _order.clear();
    _bloomAt = -1;
  }

  void _tick() {
    final double now = _controller.lastElapsedDuration == null
        ? _seconds
        : _controller.lastElapsedDuration!.inMicroseconds / 1e6;
    _seconds = now;
    // After a completed constellation lingers for a moment, drift in a new sky.
    if (_bloomAt > 0 && now - _bloomAt > 2.4) {
      _spawnSky();
    }
    if (mounted) setState(() {});
  }

  Offset _posOf(_Star s, Size size) {
    final double dx = s.base.dx + math.sin(_seconds * 0.25 + s.phase) * s.drift;
    final double dy = s.base.dy + math.cos(_seconds * 0.2 + s.phase) * s.drift;
    return Offset(dx * size.width, dy * size.height);
  }

  void _tryConnect(Offset local, Size size) {
    if (_bloomAt > 0) return;
    for (int i = 0; i < _stars.length; i++) {
      if (_order.contains(i)) continue;
      if ((_posOf(_stars[i], size) - local).distance < 46) {
        setState(() => _order.add(i));
        HapticFeedback.selectionClick();
        if (_order.length == _stars.length) {
          _bloomAt = _seconds;
          HapticFeedback.lightImpact();
        }
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final Size size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => _tryConnect(d.localPosition, size),
          onPanStart: (DragStartDetails d) => _tryConnect(d.localPosition, size),
          onPanUpdate: (DragUpdateDetails d) =>
              _tryConnect(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _StarWeaverPainter(
              stars: _stars,
              order: _order,
              posOf: (s) => _posOf(s, size),
              seconds: _seconds,
              bloom: _bloomAt > 0
                  ? ((_seconds - _bloomAt) / 2.4).clamp(0.0, 1.0)
                  : 0.0,
            ),
          ),
        );
      },
    );
  }
}

class _Star {
  _Star({
    required this.base,
    required this.phase,
    required this.drift,
    required this.twinkle,
  });
  final Offset base;
  final double phase;
  final double drift;
  final double twinkle;
}

class _StarWeaverPainter extends CustomPainter {
  _StarWeaverPainter({
    required this.stars,
    required this.order,
    required this.posOf,
    required this.seconds,
    required this.bloom,
  });

  final List<_Star> stars;
  final List<int> order;
  final Offset Function(_Star) posOf;
  final double seconds;
  final double bloom;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF141B3C), Color(0xFF221A46)],
        ).createShader(rect),
    );

    // Threads between connected stars.
    if (order.length >= 2) {
      final Path path = Path();
      for (int i = 0; i < order.length; i++) {
        final Offset p = posOf(stars[order[i]]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      final double glow = 0.5 + 0.5 * bloom;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF9BE7FF).withOpacity(0.18 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withOpacity(0.75 * glow),
      );
    }

    // Stars.
    for (int i = 0; i < stars.length; i++) {
      final Offset p = posOf(stars[i]);
      final bool on = order.contains(i);
      final double tw = 0.6 + 0.4 * math.sin(seconds * 1.6 + stars[i].twinkle);
      final double r = on ? 7.5 + 3.0 * bloom : 4.5;
      final Color core = on ? const Color(0xFFFFF3C4) : const Color(0xFFDCE6FF);
      canvas.drawCircle(
        p,
        r * 3.2,
        Paint()
          ..color = core.withOpacity((on ? 0.35 : 0.16) * tw)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(p, r, Paint()..color = core.withOpacity(0.95));
    }
  }

  @override
  bool shouldRepaint(covariant _StarWeaverPainter old) => true;
}
