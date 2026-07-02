import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/toy/toy_ticker.dart';

/// Fidget Cube Digital — a panel of tactile gadgets: clicky buttons, a flickable
/// spinner, toggle switches, and a glide pad. Every interaction gives haptic
/// feedback.
class FidgetCubeToy extends StatelessWidget {
  const FidgetCubeToy({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF141E30), Color(0xFF243B55)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 48),
              Expanded(
                child: Row(
                  children: const <Widget>[
                    Expanded(child: _ClickyButtons()),
                    SizedBox(width: 16),
                    Expanded(child: _Spinner()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: const <Widget>[
                    Expanded(child: _ToggleSwitches()),
                    SizedBox(width: 16),
                    Expanded(child: _GlideRoller()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, required this.label});
  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }
}

// --- Clicky buttons --------------------------------------------------------
class _ClickyButtons extends StatefulWidget {
  const _ClickyButtons();
  @override
  State<_ClickyButtons> createState() => _ClickyButtonsState();
}

class _ClickyButtonsState extends State<_ClickyButtons> {
  final List<bool> _pressed = List<bool>.filled(6, false);

  @override
  Widget build(BuildContext context) {
    return _Panel(
      label: 'CLICK',
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        physics: const NeverScrollableScrollPhysics(),
        children: List<Widget>.generate(6, (i) {
          return GestureDetector(
            onTapDown: (_) { setState(() => _pressed[i] = true); HapticFeedback.lightImpact(); },
            onTapUp: (_) => setState(() => _pressed[i] = false),
            onTapCancel: () => setState(() => _pressed[i] = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              transform: Matrix4.identity()..scale(_pressed[i] ? 0.88 : 1.0),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: _pressed[i]
                      ? <Color>[const Color(0xFF1B98E0), const Color(0xFF0B5394)]
                      : <Color>[const Color(0xFF6DD5FA), const Color(0xFF2980B9)],
                ),
                boxShadow: _pressed[i]
                    ? const <BoxShadow>[]
                    : const <BoxShadow>[BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// --- Flickable spinner -----------------------------------------------------
class _Spinner extends StatefulWidget {
  const _Spinner();
  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with TickerProviderStateMixin, ToyTicker {
  double _angle = 0;
  double _vel = 0;
  int _lastClick = 0;

  @override
  void onTick(double dt) {
    _angle += _vel * dt;
    _vel *= 0.985; // slow friction — spins for a long time
    // Detent clicks every 60°.
    final detent = (_angle / (math.pi / 3)).floor();
    if (detent != _lastClick && _vel.abs() > 0.6) {
      HapticFeedback.selectionClick();
      _lastClick = detent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      label: 'SPIN',
      child: GestureDetector(
        onPanUpdate: (e) => _vel += e.delta.dx * 0.08 + e.delta.dy * 0.08,
        onTap: () => _vel += 6,
        child: Transform.rotate(
          angle: _angle,
          child: CustomPaint(size: const Size(140, 140), painter: _SpinnerPainter()),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF22313F));
    for (var i = 0; i < 3; i++) {
      final a = i * 2 * math.pi / 3;
      final arm = c + Offset(math.cos(a), math.sin(a)) * r * 0.78;
      canvas.drawCircle(arm, r * 0.22,
          Paint()..shader = const RadialGradient(colors: <Color>[Color(0xFF00F2FE), Color(0xFF4FACFE)]).createShader(Rect.fromCircle(center: arm, radius: r * 0.22)));
    }
    canvas.drawCircle(c, r * 0.18, Paint()..color = const Color(0xFFB0BEC5));
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => true;
}

// --- Toggle switches -------------------------------------------------------
class _ToggleSwitches extends StatefulWidget {
  const _ToggleSwitches();
  @override
  State<_ToggleSwitches> createState() => _ToggleSwitchesState();
}

class _ToggleSwitchesState extends State<_ToggleSwitches> {
  final List<bool> _on = <bool>[true, false, true];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      label: 'FLIP',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(_on.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: GestureDetector(
              onTap: () { setState(() => _on[i] = !_on[i]); HapticFeedback.mediumImpact(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 84,
                height: 40,
                padding: const EdgeInsets.all(4),
                alignment: _on[i] ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _on[i] ? const Color(0xFF26DE81) : const Color(0xFF555E6E),
                ),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// --- Glide roller ----------------------------------------------------------
class _GlideRoller extends StatefulWidget {
  const _GlideRoller();
  @override
  State<_GlideRoller> createState() => _GlideRollerState();
}

class _GlideRollerState extends State<_GlideRoller> {
  double _value = 0.5;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      label: 'GLIDE',
      child: LayoutBuilder(builder: (context, c) {
        return GestureDetector(
          onPanUpdate: (e) {
            setState(() => _value = (_value + e.delta.dy / c.maxHeight).clamp(0.0, 1.0));
            if ((_value * 12).round() != ((_value - e.delta.dy / c.maxHeight) * 12).round()) {
              HapticFeedback.selectionClick();
            }
          },
          child: Container(
            width: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.black26,
            ),
            child: Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                Align(
                  alignment: Alignment(0, _value * 2 - 1),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: <Color>[Color(0xFFFFD194), Color(0xFFF79D00)]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
