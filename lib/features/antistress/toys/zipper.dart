import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A calm fidget toy: a big vertical zipper down the center of the screen.
/// Drag the pull-tab up or down; teeth below the tab interlock (closed) while
/// teeth above the tab separate (open). Haptic ticks fire as teeth mesh.
class ZipperToy extends StatefulWidget {
  const ZipperToy({super.key});

  @override
  State<ZipperToy> createState() => _ZipperToyState();
}

class _ZipperToyState extends State<ZipperToy>
    with SingleTickerProviderStateMixin {
  // Normalized position of the slider along the track. 0.0 == top (fully
  // open), 1.0 == bottom (fully closed).
  double _position = 0.85;
  int _lastToothTicked = -1;

  late final AnimationController _settleController;
  Animation<double> _settle = const AlwaysStoppedAnimation<double>(0.85);

  static const int _toothCount = 26;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _settleController.addListener(() {
      if (_settleController.isAnimating) {
        setState(() => _position = _settle.value);
      }
    });
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  void _handleDrag(double localY, double trackTop, double trackHeight) {
    final double next =
        ((localY - trackTop) / trackHeight).clamp(0.0, 1.0);
    final int tooth = (next * _toothCount).floor();
    if (tooth != _lastToothTicked) {
      _lastToothTicked = tooth;
      HapticFeedback.selectionClick();
    }
    setState(() => _position = next);
  }

  void _settleToEdge() {
    final double target = _position >= 0.5 ? 1.0 : 0.0;
    _settle = Tween<double>(begin: _position, end: target).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOut),
    );
    _settleController
      ..value = 0.0
      ..forward();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1E3F), Color(0xFF14101F)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double trackTop = constraints.maxHeight * 0.08;
          final double trackHeight = constraints.maxHeight * 0.84;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (DragStartDetails d) {
              _settleController.stop();
              _handleDrag(d.localPosition.dy, trackTop, trackHeight);
            },
            onVerticalDragUpdate: (DragUpdateDetails d) {
              _handleDrag(d.localPosition.dy, trackTop, trackHeight);
            },
            onVerticalDragEnd: (_) => _settleToEdge(),
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _ZipperPainter(
                position: _position,
                trackTop: trackTop,
                trackHeight: trackHeight,
                toothCount: _toothCount,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ZipperPainter extends CustomPainter {
  _ZipperPainter({
    required this.position,
    required this.trackTop,
    required this.trackHeight,
    required this.toothCount,
  });

  final double position;
  final double trackTop;
  final double trackHeight;
  final int toothCount;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double sliderY = trackTop + trackHeight * position;
    final double toothSpacing = trackHeight / toothCount;
    final double toothLen = size.width * 0.16;
    final double toothH = toothSpacing * 0.62;

    // Closed (below slider) fabric halves are pulled together; open (above
    // slider) halves spread apart.
    final double maxSpread = size.width * 0.22;

    // Fabric halves.
    final Paint fabricLeft = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF6D5BA6).withOpacity(0.95),
          const Color(0xFF4A3D78).withOpacity(0.95),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final Paint fabricRight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          const Color(0xFF6D5BA6).withOpacity(0.95),
          const Color(0xFF4A3D78).withOpacity(0.95),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path leftFabric = Path();
    final Path rightFabric = Path();

    final double tapeHalf = toothLen + 10;

    // Build the inner edges of each fabric tape, spreading above the slider.
    leftFabric.moveTo(0, trackTop);
    rightFabric.moveTo(size.width, trackTop);

    const int steps = 40;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double y = trackTop + trackHeight * t;
      double spread;
      if (y < sliderY) {
        // Above slider -> open. Spread grows the farther above.
        final double openAmt =
            ((sliderY - y) / trackHeight).clamp(0.0, 1.0);
        spread = maxSpread * Curves.easeOut.transform(openAmt);
      } else {
        spread = 0.0;
      }
      final double leftEdge = cx - tapeHalf - spread;
      final double rightEdge = cx + tapeHalf + spread;
      leftFabric.lineTo(leftEdge, y);
      rightFabric.lineTo(rightEdge, y);
    }
    leftFabric.lineTo(0, trackTop + trackHeight);
    leftFabric.close();
    rightFabric.lineTo(size.width, trackTop + trackHeight);
    rightFabric.close();

    canvas.drawPath(leftFabric, fabricLeft);
    canvas.drawPath(rightFabric, fabricRight);

    // Stitch lines along the tapes.
    final Paint stitch = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(cx - tapeHalf - 4, trackTop),
      Offset(cx - tapeHalf - 4, trackTop + trackHeight),
      stitch,
    );
    canvas.drawLine(
      Offset(cx + tapeHalf + 4, trackTop),
      Offset(cx + tapeHalf + 4, trackTop + trackHeight),
      stitch,
    );

    // Teeth.
    final Paint toothPaint = Paint()
      ..color = const Color(0xFFD9DEE8);
    final Paint toothShade = Paint()
      ..color = const Color(0xFF9AA3B5);

    for (int i = 0; i < toothCount; i++) {
      final double y = trackTop + toothSpacing * (i + 0.5);
      final bool closed = y >= sliderY;
      final bool leftTooth = i.isEven;

      double spread;
      if (closed) {
        spread = 0.0;
      } else {
        final double openAmt =
            ((sliderY - y) / trackHeight).clamp(0.0, 1.0);
        spread = maxSpread * Curves.easeOut.transform(openAmt);
      }

      if (closed) {
        // Interlocked: teeth meet at the center line, alternating.
        final double dir = leftTooth ? 1.0 : -1.0;
        final double baseX = cx - dir * (toothLen * 0.5);
        final double tipX = cx + dir * (toothLen * 0.5);
        _drawTooth(canvas, baseX, tipX, y, toothH, toothPaint, toothShade);
      } else {
        // Separated: each tooth retreats to its own tape.
        if (leftTooth) {
          final double baseX = cx - tapeHalf - spread + toothLen;
          final double tipX = cx - tapeHalf - spread + 2;
          _drawTooth(canvas, baseX, tipX, y, toothH, toothPaint, toothShade);
        } else {
          final double baseX = cx + tapeHalf + spread - toothLen;
          final double tipX = cx + tapeHalf + spread - 2;
          _drawTooth(canvas, baseX, tipX, y, toothH, toothPaint, toothShade);
        }
      }
    }

    _drawSlider(canvas, cx, sliderY, size.width, toothLen);
  }

  void _drawTooth(
    Canvas canvas,
    double baseX,
    double tipX,
    double y,
    double toothH,
    Paint fill,
    Paint shade,
  ) {
    final double half = toothH / 2;
    final Path p = Path()
      ..moveTo(baseX, y - half)
      ..lineTo(baseX, y + half)
      ..lineTo(tipX, y + half * 0.45)
      ..lineTo(tipX, y - half * 0.45)
      ..close();
    canvas.drawPath(p, fill);
    canvas.drawPath(
      Path()
        ..moveTo(baseX, y + half)
        ..lineTo(tipX, y + half * 0.45)
        ..lineTo(tipX, y - half * 0.45)
        ..close(),
      shade,
    );
  }

  void _drawSlider(
    Canvas canvas,
    double cx,
    double y,
    double width,
    double toothLen,
  ) {
    final double bodyW = toothLen * 2.6;
    final double bodyH = math.max(34.0, toothLen * 1.9);
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, y), width: bodyW, height: bodyH),
      const Radius.circular(10),
    );
    final Paint metal = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF2F4F8),
          Color(0xFFB9C2D0),
          Color(0xFF7C8798),
        ],
      ).createShader(body.outerRect);
    canvas.drawRRect(body, metal);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF5B6678).withOpacity(0.7),
    );

    // Pull-tab.
    final double tabTop = y + bodyH * 0.45;
    final Paint tabPaint = Paint()
      ..color = const Color(0xFFE7ECF3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(5.0, toothLen * 0.22)
      ..strokeCap = StrokeCap.round;
    final Path tab = Path()
      ..moveTo(cx, y + bodyH * 0.2)
      ..lineTo(cx, tabTop);
    canvas.drawPath(tab, tabPaint);
    final RRect tabRing = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, tabTop + bodyH * 0.5),
        width: bodyW * 0.62,
        height: bodyH * 0.9,
      ),
      const Radius.circular(40),
    );
    canvas.drawRRect(
      tabRing,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(6.0, toothLen * 0.26)
        ..color = const Color(0xFFCED6E1),
    );

    // Highlight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, y - bodyH * 0.22),
          width: bodyW * 0.7,
          height: bodyH * 0.3,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withOpacity(0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _ZipperPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.trackTop != trackTop ||
        oldDelegate.trackHeight != trackHeight;
  }
}
