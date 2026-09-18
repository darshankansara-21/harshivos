import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Zen Stones — a gentle, no-fail *stacking* calm experience.
///
/// Tap to rest one more smooth stone on a slow-growing cairn. Each stone eases
/// softly into place, leaning a little where it lands but never toppling, so a
/// child can build a tall balanced tower without any pressure. A long press
/// lets the stones sink away and begin again.
class ZenStonesToy extends StatefulWidget {
  const ZenStonesToy({super.key});

  @override
  State<ZenStonesToy> createState() => _ZenStonesToyState();
}

class _ZenStonesToyState extends State<ZenStonesToy>
    with SingleTickerProviderStateMixin {
  final math.Random _rng = math.Random();
  late final AnimationController _controller;
  final List<_Stone> _stones = <_Stone>[];
  double _seconds = 0;

  static const List<Color> _palette = <Color>[
    Color(0xFFB8A99A),
    Color(0xFF9FB0A6),
    Color(0xFFC9B7A0),
    Color(0xFFA6A2B8),
    Color(0xFFBFA6A0),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(_tick);
    _controller.repeat();
  }

  void _tick() {
    _seconds = _controller.lastElapsedDuration == null
        ? _seconds
        : _controller.lastElapsedDuration!.inMicroseconds / 1e6;
    bool moving = false;
    for (final _Stone s in _stones) {
      if ((s.y - s.targetY).abs() > 0.5) {
        s.y += (s.targetY - s.y) * 0.14;
        moving = true;
      } else {
        s.y = s.targetY;
      }
    }
    if (moving && mounted) setState(() {});
  }

  void _addStone(double x, Size size) {
    // Each stone leans a little toward the tap, clamped so the cairn can't fail.
    final double baseX = size.width / 2;
    final double lean = ((x - baseX) / size.width).clamp(-0.18, 0.18);
    final double w = size.width * (0.32 - _stones.length.clamp(0, 8) * 0.012);
    final double h = 26 + _rng.nextDouble() * 10;
    final double slot = size.height - 40 - _stones.length * 30.0;
    _stones.add(_Stone(
      x: baseX + lean * size.width * 0.5,
      y: -60,
      targetY: slot,
      w: math.max(60, w),
      h: h,
      color: _palette[_stones.length % _palette.length],
    ));
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(_stones.clear);
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
          onTapDown: (TapDownDetails d) => _addStone(d.localPosition.dx, size),
          onLongPress: _reset,
          child: CustomPaint(
            size: size,
            painter: _ZenPainter(stones: _stones, seconds: _seconds),
          ),
        );
      },
    );
  }
}

class _Stone {
  _Stone({
    required this.x,
    required this.y,
    required this.targetY,
    required this.w,
    required this.h,
    required this.color,
  });
  final double x;
  double y;
  final double targetY;
  final double w;
  final double h;
  final Color color;
}

class _ZenPainter extends CustomPainter {
  _ZenPainter({required this.stones, required this.seconds});
  final List<_Stone> stones;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF243244), Color(0xFF3A3350)],
        ).createShader(rect),
    );

    // Soft moon.
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.2),
      40,
      Paint()
        ..color = const Color(0xFFF5EAD0).withOpacity(0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    for (final _Stone s in stones) {
      final RRect rr = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(s.x, s.y), width: s.w, height: s.h),
        Radius.circular(s.h * 0.5),
      );
      canvas.drawRRect(
        rr.shift(const Offset(0, 4)),
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRRect(rr, Paint()..color = s.color);
      // Soft top highlight.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(s.x, s.y - s.h * 0.22),
              width: s.w * 0.7,
              height: s.h * 0.3),
          Radius.circular(s.h * 0.3),
        ),
        Paint()..color = Colors.white.withOpacity(0.10),
      );
    }

    if (stones.isEmpty) {
      final TextPainter tp = TextPainter(
        text: const TextSpan(
          text: 'Tap to stack a stone',
          style: TextStyle(color: Colors.white38, fontSize: 18),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, size.height * 0.44));
    }
  }

  @override
  bool shouldRepaint(covariant _ZenPainter old) => true;
}
