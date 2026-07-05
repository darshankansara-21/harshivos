import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/audio/tone_player.dart';

/// A full-bleed silicone "pop it" fidget board.
///
/// A responsive grid of large rounded-square bubbles arranged in soft pastel
/// rainbow rows. Tapping a bubble toggles it from convex (raised) to concave
/// (pressed-in) with a quick scale dip and haptic feedback. A small floating
/// reset button un-pops everything with a calming ripple.
class PopItToy extends StatefulWidget {
  const PopItToy({super.key});

  @override
  State<PopItToy> createState() => _PopItToyState();
}

class _PopItToyState extends State<PopItToy> {
  static const int _columns = 6;

  // Soft pastel rainbow rows.
  static const List<Color> _rowColors = <Color>[
    Color(0xFFFF9AA2), // rose
    Color(0xFFFFB7A8), // peach
    Color(0xFFFFDAC1), // apricot
    Color(0xFFFFF2B6), // butter
    Color(0xFFB5EAD7), // mint
    Color(0xFFA8D8EA), // sky
    Color(0xFFC7CEEA), // periwinkle
    Color(0xFFE2C2F0), // lilac
  ];

  late List<bool> _popped;
  int _rippleSeed = 0;

  @override
  void initState() {
    super.initState();
    _popped = <bool>[];
  }

  void _ensureSized(int count) {
    if (_popped.length != count) {
      _popped = List<bool>.filled(count, false);
    }
  }

  void _togglePop(int index) {
    HapticFeedback.mediumImpact();
    TonePlayer.instance.playPop(0.35 + (index % _columns) / _columns * 0.4);
    setState(() {
      _popped[index] = !_popped[index];
    });
  }

  void _resetAll() {
    HapticFeedback.heavyImpact();
    setState(() {
      _rippleSeed++;
      _popped = List<bool>.filled(_popped.length, false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFDF6FF), Color(0xFFEAF4FF)],
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double padding = 20.0;
          const double spacing = 12.0;
          final double available = constraints.maxWidth - padding * 2;
          final double cell =
              (available - spacing * (_columns - 1)) / _columns;
          final double usableHeight = constraints.maxHeight - padding * 2;
          final int rows = math.max(
            1,
            ((usableHeight + spacing) / (cell + spacing)).floor(),
          );
          final int count = rows * _columns;
          _ensureSized(count);

          return Stack(
            children: <Widget>[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(padding),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: count,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columns,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final int row = index ~/ _columns;
                      final Color color =
                          _rowColors[row % _rowColors.length];
                      return _PopBubble(
                        key: ValueKey<int>(index * 1000 + _rippleSeed),
                        color: color,
                        popped: _popped[index],
                        onTap: () => _togglePop(index),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 18,
                right: 18,
                child: _ResetButton(onTap: _resetAll),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single silicone bubble that animates between convex and concave.
class _PopBubble extends StatefulWidget {
  const _PopBubble({
    super.key,
    required this.color,
    required this.popped,
    required this.onTap,
  });

  final Color color;
  final bool popped;
  final VoidCallback onTap;

  @override
  State<_PopBubble> createState() => _PopBubbleState();
}

class _PopBubbleState extends State<_PopBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _press;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.popped ? 1.0 : 0.0,
    );
    _press = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _PopBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.popped != oldWidget.popped) {
      if (widget.popped) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _press,
        builder: (BuildContext context, Widget? child) {
          final double t = _press.value.clamp(0.0, 1.0);
          // Quick scale dip while transitioning, settling near 1.
          final double dip = math.sin(t * math.pi) * 0.10;
          final double scale = 1.0 - dip;

          // Convex: light from top-left. Concave: inverted (light from bottom-right).
          final Alignment lightStart = Alignment.lerp(
            Alignment.topLeft,
            Alignment.bottomRight,
            t,
          )!;
          final Alignment lightEnd = Alignment.lerp(
            Alignment.bottomRight,
            Alignment.topLeft,
            t,
          )!;

          final Color base = widget.color;
          final Color highlight = Color.lerp(base, Colors.white, 0.55)!;
          final Color shadow = Color.lerp(base, Colors.black, 0.18)!;

          return Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: lightStart,
                  end: lightEnd,
                  colors: <Color>[highlight, base, shadow],
                  stops: const <double>[0.0, 0.55, 1.0],
                ),
                boxShadow: t < 0.5
                    ? <BoxShadow>[
                        BoxShadow(
                          color: shadow.withOpacity(0.45),
                          blurRadius: 8,
                          offset: const Offset(2, 4),
                        ),
                      ]
                    : <BoxShadow>[
                        BoxShadow(
                          color: Colors.white.withOpacity(0.6),
                          blurRadius: 6,
                          offset: const Offset(-2, -3),
                        ),
                      ],
              ),
              child: Center(
                child: Opacity(
                  opacity: (1.0 - t) * 0.7,
                  child: FractionallySizedBox(
                    widthFactor: 0.32,
                    heightFactor: 0.32,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small floating circular reset button.
class _ResetButton extends StatefulWidget {
  const _ResetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;
          return SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (t > 0 && t < 1)
                  Container(
                    width: 56 + t * 40,
                    height: 56 + t * 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF7C9CBF).withOpacity(1 - t),
                        width: 3,
                      ),
                    ),
                  ),
                Transform.rotate(
                  angle: t * math.pi * 2,
                  child: child,
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.9),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF7C9CBF).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 30,
            color: Color(0xFF5B7BA6),
          ),
        ),
      ),
    );
  }
}
