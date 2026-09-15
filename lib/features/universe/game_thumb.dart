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
    'whack',
    'sky_hop',
    'stack',
    'merge',
    'echo',
    'tictactoe',
    'brick_break',
    'space_dodge',
    'memory_flip',
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
      case 'whack':
        _whack(canvas, w, h);
      case 'sky_hop':
        _skyHop(canvas, w, h);
      case 'stack':
        _stack(canvas, w, h);
      case 'merge':
        _merge(canvas, w, h);
      case 'echo':
        _echo(canvas, w, h);
      case 'tictactoe':
        _tictactoe(canvas, w, h);
      case 'brick_break':
        _brickBreak(canvas, w, h);
      case 'space_dodge':
        _spaceDodge(canvas, w, h);
      case 'memory_flip':
        _memoryFlip(canvas, w, h);
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

  void _whack(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF3B2A1A), const Color(0xFF241810)]);
    final hole = Paint()..color = const Color(0xFF1A120A);
    final xs = <double>[0.3, 0.5, 0.7];
    final ys = <double>[0.35, 0.6];
    for (final y in ys) {
      for (final x in xs) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(w * x, h * y), width: w * 0.18, height: h * 0.1),
            hole);
      }
    }
    canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.08,
        Paint()..color = const Color(0xFFB07A3A));
  }

  void _skyHop(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF4EC5F1), const Color(0xFFA8E6CF)]);
    final pipe = Paint()..color = const Color(0xFF2E9E5B);
    canvas.drawRect(Rect.fromLTWH(w * 0.62, 0, w * 0.16, h * 0.35), pipe);
    canvas.drawRect(Rect.fromLTWH(w * 0.62, h * 0.62, w * 0.16, h * 0.4), pipe);
    canvas.drawCircle(Offset(w * 0.34, h * 0.5), w * 0.09,
        Paint()..color = const Color(0xFFFFD166));
    canvas.drawCircle(Offset(w * 0.37, h * 0.47), 3, Paint()..color = Colors.black);
  }

  void _stack(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF11294B), const Color(0xFF0B1B33)]);
    final widths = <double>[0.6, 0.5, 0.42, 0.3];
    for (var i = 0; i < widths.length; i++) {
      final bw = widths[i] * w;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH((w - bw) / 2, h * (0.7 - i * 0.15), bw, h * 0.12),
              const Radius.circular(4)),
          Paint()
            ..color = HSVColor.fromAHSV(1, (i * 40).toDouble(), 0.55, 0.95)
                .toColor());
    }
  }

  void _merge(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF2A2036), const Color(0xFF1A1226)]);
    final vals = <String>['2', '4', '8', '16'];
    final colors = <Color>[
      const Color(0xFFEF476F),
      const Color(0xFFF7B801),
      const Color(0xFF06D6A0),
      const Color(0xFF4CC9F0),
    ];
    var k = 0;
    for (var r = 0; r < 2; r++) {
      for (var c = 0; c < 2; c++) {
        final rect = Rect.fromLTWH(
            w * (0.28 + c * 0.24), h * (0.3 + r * 0.24), w * 0.2, w * 0.2);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            Paint()..color = colors[k]);
        final tp = TextPainter(
          text: TextSpan(
              text: vals[k],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
        k++;
      }
    }
  }

  void _echo(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF1B1140), const Color(0xFF120C2E)]);
    final colors = <Color>[
      const Color(0xFFEF476F),
      const Color(0xFF06D6A0),
      const Color(0xFF118AB2),
      const Color(0xFFFFD166),
    ];
    var k = 0;
    for (var r = 0; r < 2; r++) {
      for (var c = 0; c < 2; c++) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * (0.3 + c * 0.22), h * (0.3 + r * 0.22),
                    w * 0.18, w * 0.18),
                const Radius.circular(8)),
            Paint()..color = colors[k].withOpacity(k == 0 ? 1 : 0.4));
        k++;
      }
    }
  }

  void _tictactoe(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF12314A), const Color(0xFF0C2233)]);
    final line = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(w * (0.3 + i * 0.13), h * 0.28),
          Offset(w * (0.3 + i * 0.13), h * 0.72), line);
      canvas.drawLine(Offset(w * 0.3, h * (0.28 + i * 0.147)),
          Offset(w * 0.69, h * (0.28 + i * 0.147)), line);
    }
    final tp = TextPainter(
      text: const TextSpan(text: '⭐', style: TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w * 0.33, h * 0.3));
    final tp2 = TextPainter(
      text: const TextSpan(text: '🐾', style: TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(w * 0.55, h * 0.5));
  }

  void _brickBreak(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF20123A), const Color(0xFF0E0820)]);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 5; c++) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * (0.14 + c * 0.15), h * (0.2 + r * 0.12),
                    w * 0.12, h * 0.08),
                const Radius.circular(3)),
            Paint()
              ..color = HSVColor.fromAHSV(1, (r * 55).toDouble(), 0.6, 0.95)
                  .toColor());
      }
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(w * 0.5, h * 0.86),
                width: w * 0.26,
                height: h * 0.05),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFF4CC9F0));
    canvas.drawCircle(Offset(w * 0.5, h * 0.72), w * 0.035,
        Paint()..color = Colors.white);
  }

  void _spaceDodge(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF0B1030), const Color(0xFF05030F)]);
    final star = Paint()..color = Colors.white70;
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(
          Offset(w * ((i * 0.19) % 1), h * ((i * 0.13) % 1)), 1.3, star);
    }
    final rock = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawCircle(Offset(w * 0.35, h * 0.35), w * 0.06, rock);
    canvas.drawCircle(Offset(w * 0.62, h * 0.55), w * 0.05, rock);
    final ship = Path()
      ..moveTo(w * 0.5, h * 0.72)
      ..lineTo(w * 0.44, h * 0.86)
      ..lineTo(w * 0.56, h * 0.86)
      ..close();
    canvas.drawPath(ship, Paint()..color = const Color(0xFF4CC9F0));
  }

  void _memoryFlip(Canvas canvas, double w, double h) {
    _bg(canvas, w, h, <Color>[const Color(0xFF10233A), const Color(0xFF0A1626)]);
    final faces = <String>['🍎', '?', '?', '🍎', '?', '⭐'];
    var k = 0;
    for (var r = 0; r < 2; r++) {
      for (var c = 0; c < 3; c++) {
        final rect = Rect.fromLTWH(
            w * (0.16 + c * 0.24), h * (0.3 + r * 0.26), w * 0.17, w * 0.17);
        final up = faces[k] != '?';
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            Paint()
              ..color = up
                  ? const Color(0xFF06D6A0).withOpacity(0.35)
                  : const Color(0xFF1E3A5F));
        if (up) {
          final tp = TextPainter(
            text: TextSpan(
                text: faces[k], style: const TextStyle(fontSize: 13)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
        }
        k++;
      }
    }
  }

  @override
  bool shouldRepaint(_ThumbPainter oldDelegate) => oldDelegate.id != id;
}
