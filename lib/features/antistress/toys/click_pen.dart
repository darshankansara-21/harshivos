import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/audio/tone_player.dart';

/// A full-bleed retractable click-pen drawn with shapes.
///
/// Tap the plunger to click the tip out, tap again to retract. A springy
/// animation drives both the plunger and the tip, with a sharp haptic click
/// and a gentle running counter.
class ClickPenToy extends StatefulWidget {
  const ClickPenToy({super.key});

  @override
  State<ClickPenToy> createState() => _ClickPenToyState();
}

class _ClickPenToyState extends State<ClickPenToy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 0,
  );

  late final Animation<double> _spring = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
    reverseCurve: Curves.easeOutBack,
  );

  bool _extended = false;
  int _clicks = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _click() {
    HapticFeedback.heavyImpact();
    setState(() {
      _extended = !_extended;
      _clicks++;
    });
    TonePlayer.instance.playClick(pitch: _extended ? 1.15 : 0.85);
    if (_extended) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse(from: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF12100B), Color(0xFF241F12), Color(0xFF0D0B07)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16),
            _Counter(clicks: _clicks),
            Expanded(
              child: GestureDetector(
                onTap: _click,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _spring,
                    builder: (BuildContext context, Widget? child) {
                      final double t = _spring.value.clamp(0.0, 1.4);
                      return CustomPaint(
                        size: const Size(180, 520),
                        painter: _PenPainter(extend: t),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Text(
                _extended ? 'Tap to retract' : 'Tap to click',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small running tally of how many times the pen has been clicked.
class _Counter extends StatelessWidget {
  const _Counter({required this.clicks});

  final int clicks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.touch_app_outlined,
              size: 18, color: Colors.amber.withOpacity(0.9)),
          const SizedBox(width: 8),
          Text(
            '$clicks',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the whole pen: tip, glossy barrel, grip, clip and the plunger.
/// [extend] runs 0..~1.4 (elastic overshoot) where 0 = retracted.
class _PenPainter extends CustomPainter {
  _PenPainter({required this.extend});

  final double extend;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double barrelW = size.width * 0.46;
    final double left = cx - barrelW / 2;
    final double right = cx + barrelW / 2;

    final double t = extend.clamp(0.0, 1.4);
    final double tipReveal = t.clamp(0.0, 1.0);
    final double overshoot = (t - 1.0).clamp(0.0, 0.4);

    // Vertical layout (top -> bottom).
    const double topPad = 8;
    final double plungerTravel = 26 * (1 - (overshoot / 0.4) * 0.4);
    final double plungerY = topPad + 4 - plungerTravel * t.clamp(0.0, 1.0);
    final double plungerH = 34;
    final double clipTop = topPad + plungerH;
    final double bodyTop = clipTop + 6;
    final double bodyBottom = size.height - 96;
    final double coneBottom = size.height - 28;
    final double tipBottom = coneBottom + 26 * tipReveal;

    // --- Plunger button (top) ---
    final Rect plungerRect = Rect.fromLTWH(
      cx - barrelW * 0.28,
      plungerY,
      barrelW * 0.56,
      plungerH,
    );
    final Paint plungerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFFFE08A), Color(0xFFFFB703)],
      ).createShader(plungerRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plungerRect, const Radius.circular(8)),
      plungerPaint,
    );
    // plunger highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(plungerRect.left + 6, plungerRect.top + 4,
            barrelW * 0.16, plungerH - 10),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white.withOpacity(0.45),
    );

    // --- Clip ---
    final Path clip = Path()
      ..moveTo(right - 6, clipTop)
      ..lineTo(right - 6, bodyTop + 120)
      ..lineTo(right + 6, bodyTop + 132)
      ..lineTo(right + 6, clipTop - 2)
      ..close();
    canvas.drawPath(
      clip,
      Paint()
        ..color = const Color(0xFFFFC93C)
        ..style = PaintingStyle.fill,
    );

    // --- Barrel (glossy) ---
    final Rect barrelRect = Rect.fromLTRB(left, bodyTop, right, bodyBottom);
    final RRect barrelR =
        RRect.fromRectAndRadius(barrelRect, Radius.circular(barrelW / 2));
    final Paint barrelPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Color(0xFF1B3A6B),
          Color(0xFF3E7CC4),
          Color(0xFF7FB6F0),
          Color(0xFF2C5A99),
          Color(0xFF13294B),
        ],
        stops: <double>[0.0, 0.28, 0.5, 0.72, 1.0],
      ).createShader(barrelRect);
    canvas.drawRRect(barrelR, barrelPaint);

    // glossy vertical highlight streak
    final Rect streak = Rect.fromLTWH(
      left + barrelW * 0.26,
      bodyTop + 8,
      barrelW * 0.12,
      bodyBottom - bodyTop - 16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(streak, const Radius.circular(20)),
      Paint()..color = Colors.white.withOpacity(0.35),
    );

    // grip rings near the bottom of the barrel
    final Paint ring = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (int i = 0; i < 5; i++) {
      final double y = bodyBottom - 14 - i * 12.0;
      canvas.drawLine(Offset(left + 6, y), Offset(right - 6, y), ring);
    }

    // --- Cone (front taper) ---
    final Path cone = Path()
      ..moveTo(left + 6, bodyBottom - 2)
      ..lineTo(right - 6, bodyBottom - 2)
      ..lineTo(cx + barrelW * 0.16, coneBottom)
      ..lineTo(cx - barrelW * 0.16, coneBottom)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF2C5A99),
            const Color(0xFF13294B).withOpacity(0.95),
          ],
        ).createShader(
            Rect.fromLTRB(left, bodyBottom - 2, right, coneBottom)),
    );

    // --- Metal tip (retractable) ---
    if (tipReveal > 0.01) {
      final Path tip = Path()
        ..moveTo(cx - barrelW * 0.16, coneBottom)
        ..lineTo(cx + barrelW * 0.16, coneBottom)
        ..lineTo(cx + 2.5, tipBottom)
        ..lineTo(cx - 2.5, tipBottom)
        ..close();
      canvas.drawPath(
        tip,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[Color(0xFF9AA4B2), Color(0xFFE6ECF3), Color(0xFF6B7686)],
          ).createShader(Rect.fromLTRB(
              cx - barrelW * 0.16, coneBottom, cx + barrelW * 0.16, tipBottom)),
      );
    }

    // --- soft shadow under the pen ---
    final double shadowOpacity = 0.18 + 0.12 * math.sin(t * math.pi).abs();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 8),
        width: barrelW * 1.6,
        height: 14,
      ),
      Paint()..color = Colors.black.withOpacity(shadowOpacity),
    );
  }

  @override
  bool shouldRepaint(_PenPainter oldDelegate) => oldDelegate.extend != extend;
}
