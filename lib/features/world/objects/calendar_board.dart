import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A cute daily routine board — a "visual schedule" world object.
///
/// A rounded warm board with a little sun arcing gently across the top (the day
/// passing), a tear-off calendar page whose top corner lifts/flips in a loop,
/// a tiny clip at the top, and a row of small pinned picture cards (a plate &
/// fork, a book, a moon). Organized and friendly, alive while idle.
class CalendarBoardObject extends StatefulWidget {
  const CalendarBoardObject({super.key});

  @override
  State<CalendarBoardObject> createState() => _CalendarBoardObjectState();
}

class _CalendarBoardObjectState extends State<CalendarBoardObject>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _CalendarBoardPainter(t: _controller.value),
        );
      },
    );
  }
}

class _CalendarBoardPainter extends CustomPainter {
  _CalendarBoardPainter({required this.t});

  /// Animation phase in [0, 1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final double box = s.clamp(90.0, 220.0);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double tau = math.pi * 2;

    // Gentle breathing wobble keeps it alive.
    final double wobble = math.sin(t * tau) * 0.010;

    final double w = box * 0.86;
    final double h = box * 0.96;
    final Rect boardRect = Rect.fromCenter(
      center: center,
      width: w,
      height: h,
    );

    // ---- Soft grounding shadow near the bottom ----
    final Paint shadowPaint = Paint()
      ..color = const Color(0x33101828)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.save();
    canvas.translate(center.dx, center.dy + h * 0.56);
    canvas.scale(1.0, 0.28);
    canvas.drawCircle(Offset.zero, w * 0.46, shadowPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(wobble);
    canvas.translate(-center.dx, -center.dy);

    // ---- Board back panel (warm frame) ----
    final RRect frame = RRect.fromRectAndRadius(
      boardRect.inflate(box * 0.03),
      Radius.circular(box * 0.10),
    );
    final Paint frameGlow = Paint()
      ..color = const Color(0x33F2A65A)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, box * 0.05);
    canvas.drawRRect(frame, frameGlow);
    final Paint framePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFF7B872),
          Color(0xFFE79A4F),
          Color(0xFFC97B38),
        ],
      ).createShader(frame.outerRect);
    canvas.drawRRect(frame, framePaint);

    // ---- Paper page ----
    final RRect page = RRect.fromRectAndRadius(
      boardRect,
      Radius.circular(box * 0.07),
    );
    final Paint pagePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFFFDF7),
          Color(0xFFFBF2E2),
        ],
      ).createShader(boardRect);
    canvas.drawRRect(page, pagePaint);

    // Header band.
    final Rect headerRect = Rect.fromLTWH(
      boardRect.left,
      boardRect.top,
      w,
      h * 0.30,
    );
    final RRect header = RRect.fromRectAndCorners(
      headerRect,
      topLeft: Radius.circular(box * 0.07),
      topRight: Radius.circular(box * 0.07),
    );
    final Paint headerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF7FC8E8),
          Color(0xFF5AA9D6),
        ],
      ).createShader(headerRect);
    canvas.drawRRect(header, headerPaint);

    // ---- Sun arcing across the top ----
    _paintSun(canvas, headerRect, box, tau);

    // ---- Pinned picture cards row ----
    _paintCards(canvas, boardRect, box);

    // ---- Tear-off top corner lifting/flipping ----
    _paintTearCorner(canvas, boardRect, box, tau);

    // ---- Clip / pin at the very top ----
    _paintClip(canvas, boardRect, box);

    canvas.restore();
  }

  void _paintSun(Canvas canvas, Rect header, double box, double tau) {
    // Arc gently left->right across the header band.
    final double phase = (math.sin(t * tau - math.pi / 2) + 1) / 2; // 0..1
    final double x = header.left + header.width * (0.18 + 0.64 * phase);
    final double arc = math.sin(phase * math.pi); // up in the middle
    final double y = header.bottom - header.height * (0.18 + 0.55 * arc);
    final Offset sun = Offset(x, y);
    final double rad = box * 0.06;

    final Paint glow = Paint()
      ..color = const Color(0x66FFE9A8)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, box * 0.05);
    canvas.drawCircle(sun, rad * 1.9, glow);

    // Rays.
    final Paint rayPaint = Paint()
      ..color = const Color(0xCCFFE08A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = box * 0.012;
    for (int i = 0; i < 8; i++) {
      final double a = (i / 8.0) * tau + t * tau * 0.5;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(sun + dir * rad * 1.3, sun + dir * rad * 1.8, rayPaint);
    }

    final Paint sunPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: <Color>[Color(0xFFFFF3C4), Color(0xFFFFC74A)],
      ).createShader(Rect.fromCircle(center: sun, radius: rad));
    canvas.drawCircle(sun, rad, sunPaint);
    canvas.drawCircle(
      sun.translate(-rad * 0.3, -rad * 0.3),
      rad * 0.28,
      Paint()..color = const Color(0x99FFFFFF),
    );
  }

  void _paintCards(Canvas canvas, Rect board, double box) {
    final double cardW = board.width * 0.24;
    final double cardH = board.height * 0.30;
    final double cy = board.top + board.height * 0.62;
    final List<double> xs = <double>[
      board.left + board.width * 0.23,
      board.left + board.width * 0.50,
      board.left + board.width * 0.77,
    ];
    final List<Color> tints = <Color>[
      const Color(0xFFFFE2D0),
      const Color(0xFFD9ECFB),
      const Color(0xFFE6DCF7),
    ];

    for (int i = 0; i < 3; i++) {
      final Rect c = Rect.fromCenter(
        center: Offset(xs[i], cy),
        width: cardW,
        height: cardH,
      );
      final RRect rc = RRect.fromRectAndRadius(c, Radius.circular(box * 0.03));

      final Paint cShadow = Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, box * 0.02);
      canvas.drawRRect(rc.shift(const Offset(0, 2)), cShadow);

      final Paint cardPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Colors.white, tints[i]],
        ).createShader(c);
      canvas.drawRRect(rc, cardPaint);

      // Pin dot at the top of each card.
      final Offset pin = Offset(c.center.dx, c.top + cardH * 0.12);
      canvas.drawCircle(
        pin,
        box * 0.018,
        Paint()..color = const Color(0xFFE7704F),
      );
      canvas.drawCircle(
        pin.translate(-box * 0.006, -box * 0.006),
        box * 0.007,
        Paint()..color = const Color(0x99FFFFFF),
      );

      // Icon inside.
      if (i == 0) {
        _paintPlateFork(canvas, c, box);
      } else if (i == 1) {
        _paintBook(canvas, c, box);
      } else {
        _paintMoon(canvas, c, box);
      }
    }
  }

  void _paintPlateFork(Canvas canvas, Rect c, double box) {
    final Offset ctr = c.center.translate(0, c.height * 0.06);
    final double r = c.width * 0.26;
    canvas.drawCircle(
      ctr,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = box * 0.012
        ..color = const Color(0xFFE08A5A),
    );
    canvas.drawCircle(
      ctr,
      r * 0.55,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = box * 0.008
        ..color = const Color(0x66E08A5A),
    );
    // Fork to the left.
    final Paint fork = Paint()
      ..color = const Color(0xFFB06A3A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = box * 0.010;
    final double fx = c.left + c.width * 0.16;
    canvas.drawLine(
      Offset(fx, ctr.dy - r * 1.0),
      Offset(fx, ctr.dy + r * 0.9),
      fork,
    );
  }

  void _paintBook(Canvas canvas, Rect c, double box) {
    final Offset ctr = c.center.translate(0, c.height * 0.06);
    final double bw = c.width * 0.52;
    final double bh = c.height * 0.42;
    final Rect left = Rect.fromLTWH(ctr.dx - bw / 2, ctr.dy - bh / 2, bw / 2, bh);
    final Rect right = Rect.fromLTWH(ctr.dx, ctr.dy - bh / 2, bw / 2, bh);
    final Paint pageP = Paint()..color = const Color(0xFFFDFBF4);
    final Paint edgeP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = box * 0.009
      ..color = const Color(0xFF5A8FC0);
    canvas.drawRect(left, pageP);
    canvas.drawRect(right, pageP);
    canvas.drawRect(left, edgeP);
    canvas.drawRect(right, edgeP);
    canvas.drawLine(
      Offset(ctr.dx, ctr.dy - bh / 2),
      Offset(ctr.dx, ctr.dy + bh / 2),
      edgeP,
    );
    // Text lines.
    final Paint lineP = Paint()
      ..color = const Color(0x885A8FC0)
      ..strokeWidth = box * 0.006
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 2; i++) {
      final double ly = ctr.dy - bh * 0.18 + i * bh * 0.28;
      canvas.drawLine(
        Offset(left.left + bw * 0.06, ly),
        Offset(left.right - bw * 0.04, ly),
        lineP,
      );
      canvas.drawLine(
        Offset(right.left + bw * 0.04, ly),
        Offset(right.right - bw * 0.06, ly),
        lineP,
      );
    }
  }

  void _paintMoon(Canvas canvas, Rect c, double box) {
    final Offset ctr = c.center.translate(0, c.height * 0.06);
    final double r = c.width * 0.26;
    final Path crescent = Path()
      ..addOval(Rect.fromCircle(center: ctr, radius: r));
    final Path cut = Path()
      ..addOval(
        Rect.fromCircle(center: ctr.translate(r * 0.5, -r * 0.15), radius: r),
      );
    final Path moon = Path.combine(PathOperation.difference, crescent, cut);
    final Paint moonGlow = Paint()
      ..color = const Color(0x55C9B6F2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, box * 0.03);
    canvas.drawPath(moon, moonGlow);
    final Paint moonP = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFFEDE3FF), Color(0xFFB89BE8)],
      ).createShader(Rect.fromCircle(center: ctr, radius: r));
    canvas.drawPath(moon, moonP);
  }

  void _paintTearCorner(Canvas canvas, Rect board, double box, double tau) {
    // Lift amount eases up and back down across the loop.
    final double lift = (math.sin(t * tau) * 0.5 + 0.5);
    final double size = box * 0.20 * (0.45 + 0.55 * lift);

    final Offset corner = Offset(board.right, board.top);
    final Path flap = Path()
      ..moveTo(corner.dx - size, corner.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(corner.dx, corner.dy + size)
      ..close();

    // Shadow under the lifted flap.
    final Paint flapShadow = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, box * 0.02);
    canvas.drawPath(
      flap.shift(Offset(-size * 0.25 * lift, size * 0.25 * lift)),
      flapShadow,
    );

    // The curled page underside.
    final Paint flapPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: <Color>[Color(0xFFE9DCC2), Color(0xFFF7EFDF)],
      ).createShader(flap.getBounds());
    canvas.drawPath(flap, flapPaint);
    canvas.drawPath(
      flap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = box * 0.006
        ..color = const Color(0x44A07A3A),
    );
  }

  void _paintClip(Canvas canvas, Rect board, double box) {
    final Offset top = Offset(board.center.dx, board.top - box * 0.02);
    final RRect clip = RRect.fromRectAndRadius(
      Rect.fromCenter(center: top, width: box * 0.22, height: box * 0.09),
      Radius.circular(box * 0.04),
    );
    final Paint clipGlow = Paint()
      ..color = const Color(0x44B0BAC9)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, box * 0.02);
    canvas.drawRRect(clip, clipGlow);
    final Paint clipPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFE7ECF3), Color(0xFFAEB8C7)],
      ).createShader(clip.outerRect);
    canvas.drawRRect(clip, clipPaint);
    // Highlight bar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: top.translate(0, -box * 0.018),
          width: box * 0.16,
          height: box * 0.018,
        ),
        Radius.circular(box * 0.01),
      ),
      Paint()..color = const Color(0x88FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_CalendarBoardPainter oldDelegate) => oldDelegate.t != t;
}
