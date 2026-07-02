import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A calm fidget toy: several sliding barrel bolts (door slide-locks) stacked
/// in rows. Drag each bolt knob horizontally to slide it open or closed; it
/// snaps to the end positions with a satisfying haptic thunk.
class LatchBoltToy extends StatefulWidget {
  const LatchBoltToy({super.key});

  @override
  State<LatchBoltToy> createState() => _LatchBoltToyState();
}

class _LatchBoltToyState extends State<LatchBoltToy> {
  static const int _boltCount = 5;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2A41), Color(0xFF0E1726)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double gap = constraints.maxHeight /
                  (_boltCount * 1.6 + 0.6);
              final double boltHeight = gap;
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List<Widget>.generate(_boltCount, (int i) {
                  return _BoltRow(
                    seed: i,
                    height: boltHeight.clamp(64.0, 132.0),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BoltRow extends StatefulWidget {
  const _BoltRow({required this.seed, required this.height});

  final int seed;
  final double height;

  @override
  State<_BoltRow> createState() => _BoltRowState();
}

class _BoltRowState extends State<_BoltRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  // 0.0 == closed (latched), 1.0 == open (unlatched).
  double _value = 0.0;
  double _dragStartValue = 0.0;

  @override
  void initState() {
    super.initState();
    _value = widget.seed.isEven ? 0.0 : 1.0;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _animation = AlwaysStoppedAnimation<double>(_value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapTo(double target) {
    _animation = Tween<double>(begin: _value, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller
      ..value = 0.0
      ..forward();
    _value = target;
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        final double knobWidth = widget.height * 0.92;
        final double travel = trackWidth - knobWidth - 16;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _controller.stop();
            _dragStartValue = _value;
          },
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            setState(() {
              final double delta = details.primaryDelta ?? 0.0;
              _value = (_value + delta / travel).clamp(0.0, 1.0);
              _animation = AlwaysStoppedAnimation<double>(_value);
            });
          },
          onHorizontalDragEnd: (_) {
            final double target = _value >= 0.5 ? 1.0 : 0.0;
            if (target != _dragStartValue || _value != target) {
              _snapTo(target);
            } else {
              setState(() {
                _value = target;
                _animation = AlwaysStoppedAnimation<double>(_value);
              });
            }
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final double v = _controller.isAnimating
                  ? _animation.value.clamp(0.0, 1.0)
                  : _value;
              return CustomPaint(
                size: Size(trackWidth, widget.height),
                painter: _BoltPainter(
                  value: v,
                  knobWidth: knobWidth,
                  travel: travel,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BoltPainter extends CustomPainter {
  _BoltPainter({
    required this.value,
    required this.knobWidth,
    required this.travel,
  });

  final double value;
  final double knobWidth;
  final double travel;

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final double cy = h / 2;
    final double radius = h * 0.28;

    // Panel plate background.
    final RRect plate = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.12, size.width, h * 0.76),
      Radius.circular(h * 0.22),
    );
    final Paint platePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2E4364).withOpacity(0.95),
          const Color(0xFF1A2740).withOpacity(0.95),
        ],
      ).createShader(plate.outerRect);
    canvas.drawRRect(plate, platePaint);
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withOpacity(0.08),
    );

    // Strike staples (where the bolt seats), left and right.
    final Paint staple = Paint()
      ..color = const Color(0xFF0C1320).withOpacity(0.9)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * 0.10
      ..style = PaintingStyle.stroke;
    final double leftX = 8 + knobWidth * 0.5;
    final double rightX = 8 + travel + knobWidth * 0.5;
    canvas.drawLine(
      Offset(leftX - knobWidth * 0.18, cy - radius * 1.25),
      Offset(leftX - knobWidth * 0.18, cy + radius * 1.25),
      staple,
    );
    canvas.drawLine(
      Offset(rightX + knobWidth * 0.18, cy - radius * 1.25),
      Offset(rightX + knobWidth * 0.18, cy + radius * 1.25),
      staple,
    );

    // Closed indicator glow on the left seat.
    final double closedGlow = (1.0 - value).clamp(0.0, 1.0);
    if (closedGlow > 0.02) {
      canvas.drawCircle(
        Offset(leftX - knobWidth * 0.18, cy),
        radius * 0.55,
        Paint()
          ..color = const Color(0xFF36D399).withOpacity(0.55 * closedGlow),
      );
    }

    // Bolt body: the sliding barrel.
    final double knobLeft = 8 + travel * value;
    final Rect barrel = Rect.fromLTWH(
      knobLeft,
      cy - radius,
      knobWidth,
      radius * 2,
    );
    final RRect barrelR = RRect.fromRectAndRadius(
      barrel,
      Radius.circular(radius),
    );

    final Paint metal = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFE9EEF5),
          Color(0xFFB7C2D0),
          Color(0xFF8A97A8),
          Color(0xFFC6D0DC),
        ],
        stops: [0.0, 0.45, 0.7, 1.0],
      ).createShader(barrel);
    canvas.drawRRect(barrelR, metal);

    // Highlight sheen.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(knobLeft + 4, cy - radius + 3, knobWidth - 8,
            radius * 0.5),
        Radius.circular(radius),
      ),
      Paint()..color = Colors.white.withOpacity(0.35),
    );

    // Knurled grip ridges on the knob.
    final Paint ridge = Paint()
      ..color = const Color(0xFF5C6B7E).withOpacity(0.6)
      ..strokeWidth = 2;
    final double gripStart = knobLeft + knobWidth * 0.34;
    for (int i = 0; i < 6; i++) {
      final double rx = gripStart + i * 4.0;
      canvas.drawLine(
        Offset(rx, cy - radius * 0.55),
        Offset(rx, cy + radius * 0.55),
        ridge,
      );
    }

    // Outline.
    canvas.drawRRect(
      barrelR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF6A7689).withOpacity(0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _BoltPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.knobWidth != knobWidth ||
        oldDelegate.travel != travel;
  }
}
