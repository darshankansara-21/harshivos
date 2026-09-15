import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small painted scene that communicates a game's actual gameplay on its
/// tile — a snake board, a bowling lane, a racing road, and so on — instead of
/// a generic emoji. Falls back to the toy's emoji for non-game experiences.
class GameThumb extends StatelessWidget {
  const GameThumb({super.key, required this.id, required this.color, required this.emoji});

  final String id;
  final Color color;
  final String emoji;

  static const Set<String> painted = <String>{
    'snake',
    'racing',
    'bowling',
    'balloon_pop',
    'fruit_catch',
    'star_tap',
    'bubble_pop',
    'marble_run',
    'snack_studio',
    'car_track',
  };

  @override
  Widget build(BuildContext context) {
    if (painted.contains(id)) {
      return CustomPaint(painter: _ThumbPainter(id, color), size: Size.infinite);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[color.withOpacity(0.55), color.withOpacity(0.2)],
        ),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 40))),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.id, this.color);
  final String id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (id) {
      case 'snake':
        _snake(canvas, w, h);
      case 'racing':
        _racing(canvas, w, h);
      case 'bowling':
        _bowling(canvas, w, h);
      case 'balloon_pop':
        _balloons(canvas, w, h);
      case 'fruit_catch':
        _fruitCatch(canvas, w, h);
      case 'star_tap':
        _starTap(canvas, w, h);
      case 'bubble_pop':
        _bubbles(canvas, w, h);
      case 'marble_run':
        _marble(canvas, w, h);
      case 'snack_studio':
        _snack(canvas, w, h);
      case 'car_track':
        _carTrack(canvas, w, h);
    }
  }

  void _bg(Canvas canvas, double w, double h, List<Color> colors) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  void _snake(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF0B2436), const Color(0xFF0E3020)]);
    final cell = w / 7;
    final body = Paint()..color = const Color(0xFF06D6A0);
    final pts = <Offset>[
      Offset(cell * 1.5, h * 0.62),
      Offset(cell * 2.5, h * 0.62),
      Offset(cell * 3.5, h * 0.62),
      Offset(cell * 3.5, h * 0.4),
    ];
    for (final p in pts) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: cell * 0.8, height: cell * 0.8),
              Radius.circular(cell * 0.28)),
          body);
    }
    canvas.drawCircle(Offset(cell * 5, h * 0.3), cell * 0.34,
        Paint()..color = const Color(0xFFEF476F));
  }

  void _racing(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF2A2E38), const Color(0xFF16181F)]);
    final line = Paint()
      ..color = Colors.white54
      ..strokeWidth = 3;
    for (final fx in <double>[1 / 3, 2 / 3]) {
      for (double y = 6; y < h; y += 22) {
        canvas.drawLine(Offset(w * fx, y), Offset(w * fx, y + 12), line);
      }
    }
    final carRect = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.72), width: w * 0.22, height: h * 0.3);
    canvas.drawRRect(
        RRect.fromRectAndRadius(carRect, const Radius.circular(6)),
        Paint()..color = const Color(0xFFFF512F));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(w * 0.5, h * 0.66),
                width: w * 0.14,
                height: h * 0.08),
            const Radius.circular(3)),
        Paint()..color = Colors.white70);
  }

  void _bowling(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF1A1030), const Color(0xFF241A3A)]);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.28, 0, w * 0.44, h), const Radius.circular(10)),
        Paint()..color = const Color(0xFFC9A26B));
    final pin = Paint()..color = Colors.white;
    final positions = <Offset>[
      Offset(w * 0.5, h * 0.2),
      Offset(w * 0.43, h * 0.32),
      Offset(w * 0.57, h * 0.32),
    ];
    for (final p in positions) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: w * 0.07, height: h * 0.16),
              const Radius.circular(4)),
          pin);
    }
    canvas.drawCircle(Offset(w * 0.5, h * 0.8), w * 0.1,
        Paint()..color = const Color(0xFF22223B));
    canvas.drawCircle(
        Offset(w * 0.5, h * 0.8),
        w * 0.1,
        Paint()
          ..color = const Color(0xFF4CC9F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  void _balloons(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF241A5E), const Color(0xFF1A1246)]);
    final cols = <Color>[
      const Color(0xFFEF476F),
      const Color(0xFFFFD166),
      const Color(0xFF06D6A0),
    ];
    final xs = <double>[0.3, 0.5, 0.72];
    final ys = <double>[0.5, 0.36, 0.56];
    for (var i = 0; i < 3; i++) {
      final c = Offset(w * xs[i], h * ys[i]);
      canvas.drawLine(c, Offset(c.dx, c.dy + h * 0.22),
          Paint()..color = Colors.white24..strokeWidth = 1.5);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: w * 0.2, height: h * 0.3),
          Paint()..color = cols[i]);
    }
  }

  void _fruitCatch(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF15324A), const Color(0xFF0B2436)]);
    canvas.drawCircle(Offset(w * 0.36, h * 0.3), w * 0.09,
        Paint()..color = const Color(0xFFEF476F));
    canvas.drawCircle(Offset(w * 0.62, h * 0.44), w * 0.08,
        Paint()..color = const Color(0xFFFFD166));
    final basket = Path()
      ..moveTo(w * 0.32, h * 0.7)
      ..lineTo(w * 0.68, h * 0.7)
      ..lineTo(w * 0.6, h * 0.9)
      ..lineTo(w * 0.4, h * 0.9)
      ..close();
    canvas.drawPath(basket, Paint()..color = const Color(0xFFB07A3A));
  }

  void _starTap(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF13294B), const Color(0xFF0E1F3A)]);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final center =
            Offset(w * (0.28 + c * 0.22), h * (0.28 + r * 0.22));
        final active = r == 1 && c == 1;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: center, width: w * 0.16, height: w * 0.16),
                const Radius.circular(5)),
            Paint()
              ..color = active
                  ? const Color(0xFFFFD166)
                  : Colors.white.withOpacity(0.08));
      }
    }
  }

  void _bubbles(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF0E3B34), const Color(0xFF0B2A28)]);
    final rnd = math.Random(7);
    for (var i = 0; i < 6; i++) {
      final c = Offset(w * (0.15 + rnd.nextDouble() * 0.7),
          h * (0.15 + rnd.nextDouble() * 0.7));
      final r = w * (0.06 + rnd.nextDouble() * 0.08);
      canvas.drawCircle(c, r, Paint()..color = const Color(0x5543E97B));
      canvas.drawCircle(c, r,
          Paint()..color = const Color(0x8843E97B)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  void _marble(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF12314A), const Color(0xFF0C2233)]);
    final track = Paint()
      ..color = Colors.white38
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(w * 0.15, h * 0.2)
      ..lineTo(w * 0.7, h * 0.35)
      ..moveTo(w * 0.3, h * 0.55)
      ..lineTo(w * 0.85, h * 0.7);
    canvas.drawPath(path, track);
    canvas.drawCircle(Offset(w * 0.7, h * 0.35), w * 0.08,
        Paint()..color = const Color(0xFF4CC9F0));
  }

  void _snack(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF102C2A), const Color(0xFF0C201F)]);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.6), width: w * 0.6, height: h * 0.42),
        Paint()..color = const Color(0xFFFFF3D6));
    final tops = <Color>[
      const Color(0xFFEF476F),
      const Color(0xFF06D6A0),
      const Color(0xFFFFD166),
    ];
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(w * (0.38 + i * 0.12), h * 0.56), w * 0.05,
          Paint()..color = tops[i]);
    }
  }

  void _carTrack(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF2A1230), const Color(0xFF1A0E22)]);
    final road = Paint()
      ..color = const Color(0xFF6B7280)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(w * 0.2, h * 0.85)
      ..cubicTo(w * 0.1, h * 0.4, w * 0.9, h * 0.6, w * 0.8, h * 0.2);
    canvas.drawPath(path, road);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(w * 0.2, h * 0.8),
                width: w * 0.14,
                height: h * 0.1),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFFFF512F));
  }

  @override
  bool shouldRepaint(_ThumbPainter oldDelegate) => oldDelegate.id != id;
}
