import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A calm fidget toy: a combination padlock face with four vertical number
/// dials (0-9). Drag each dial up or down to scroll the numbers like an
/// odometer wheel, with a detent haptic per number snap. There is no correct
/// or incorrect combination, only satisfying scrolling.
class ComboLockToy extends StatefulWidget {
  const ComboLockToy({super.key});

  @override
  State<ComboLockToy> createState() => _ComboLockToyState();
}

class _ComboLockToyState extends State<ComboLockToy> {
  static const int _dialCount = 4;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13322E), Color(0xFF0A1A18)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxW = math.min(constraints.maxWidth * 0.9, 520.0);
              final double dialW = maxW / (_dialCount + 0.6);
              final double dialH =
                  math.min(constraints.maxHeight * 0.6, dialW * 2.6);
              return _LockBody(
                width: maxW,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(_dialCount, (int i) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: dialW * 0.08,
                      ),
                      child: _NumberDial(
                        width: dialW,
                        height: dialH,
                        seed: i * 3,
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LockBody extends StatelessWidget {
  const _LockBody({required this.child, required this.width});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shackle.
          CustomPaint(
            size: Size(width * 0.5, width * 0.32),
            painter: _ShacklePainter(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF1C453),
                  Color(0xFFD9A323),
                  Color(0xFFB6831A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ShacklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint metal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.16
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFE9EDF2), Color(0xFF9AA4B2)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    final double inset = size.width * 0.16;
    final Path p = Path()
      ..moveTo(inset, size.height)
      ..lineTo(inset, size.height * 0.55)
      ..arcToPoint(
        Offset(size.width - inset, size.height * 0.55),
        radius: Radius.circular(size.width * 0.42),
        clockwise: true,
      )
      ..lineTo(size.width - inset, size.height);
    canvas.drawPath(p, metal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NumberDial extends StatefulWidget {
  const _NumberDial({
    required this.width,
    required this.height,
    required this.seed,
  });

  final double width;
  final double height;
  final int seed;

  @override
  State<_NumberDial> createState() => _NumberDialState();
}

class _NumberDialState extends State<_NumberDial>
    with SingleTickerProviderStateMixin {
  // Continuous offset measured in "digits". Increases as the wheel rolls.
  double _offset = 0.0;
  int _lastDetent = 0;

  late final AnimationController _settleController;
  Animation<double> _settle = const AlwaysStoppedAnimation<double>(0.0);

  @override
  void initState() {
    super.initState();
    _offset = widget.seed.toDouble();
    _lastDetent = _offset.round();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _settleController.addListener(() {
      if (_settleController.isAnimating) {
        setState(() {
          _offset = _settle.value;
          _checkDetent();
        });
      }
    });
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  void _checkDetent() {
    final int nearest = _offset.round();
    if (nearest != _lastDetent) {
      _lastDetent = nearest;
      HapticFeedback.selectionClick();
    }
  }

  double get _digitHeight => widget.height / 3.0;

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _offset -= (d.primaryDelta ?? 0.0) / _digitHeight;
      _checkDetent();
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final double target = _offset.roundToDouble();
    _settle = Tween<double>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutCubic),
    );
    _settleController
      ..value = 0.0
      ..forward();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _settleController.stop(),
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _DialPainter(offset: _offset),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.offset});

  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final double digitHeight = size.height / 3.0;
    final double cy = size.height / 2;

    // Drum background.
    final Rect rect = Offset.zero & size;
    final Paint drum = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF1A1F26),
          Color(0xFF333B46),
          Color(0xFF1A1F26),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, drum);

    // Visible digits: render a window of 5 around the current offset.
    final int center = offset.round();
    final double frac = offset - center; // -0.5 .. 0.5

    for (int k = -2; k <= 2; k++) {
      final int value = ((center + k) % 10 + 10) % 10;
      final double y = cy + (k - frac) * digitHeight;
      final double dist = (y - cy).abs() / (size.height / 2);
      final double opacity = (1.0 - dist).clamp(0.0, 1.0);
      if (opacity <= 0.01) {
        continue;
      }
      // Curved-wheel scaling: digits shrink toward the edges.
      final double scale = (1.0 - dist * 0.45).clamp(0.3, 1.0);
      _drawDigit(canvas, size, value, y, opacity, scale);
    }

    // Center selection band.
    final Paint band = Paint()
      ..color = Colors.white.withOpacity(0.10);
    canvas.drawRect(
      Rect.fromLTWH(0, cy - digitHeight * 0.5, size.width, digitHeight),
      band,
    );
    final Paint line = Paint()
      ..color = const Color(0xFFF1C453).withOpacity(0.7)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, cy - digitHeight * 0.5),
      Offset(size.width, cy - digitHeight * 0.5),
      line,
    );
    canvas.drawLine(
      Offset(0, cy + digitHeight * 0.5),
      Offset(size.width, cy + digitHeight * 0.5),
      line,
    );

    // Top/bottom shading for the rolling-drum illusion.
    final Paint topShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withOpacity(0.65),
          Colors.black.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.4),
      topShade,
    );
    final Paint bottomShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black.withOpacity(0.65),
          Colors.black.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4),
      bottomShade,
    );
  }

  void _drawDigit(
    Canvas canvas,
    Size size,
    int value,
    double y,
    double opacity,
    double scale,
  ) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '$value',
        style: TextStyle(
          color: Colors.white.withOpacity(opacity),
          fontSize: size.height * 0.3 * scale,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(minWidth: size.width, maxWidth: size.width);
    tp.paint(canvas, Offset(0, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}
