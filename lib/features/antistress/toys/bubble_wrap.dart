import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A full-bleed classic plastic bubble wrap fidget surface.
///
/// A dense grid of glossy translucent bubbles. Tapping a bubble pops it: it
/// deflates to a flat dimple with a tiny burst animation and stays popped,
/// accompanied by a sharp haptic. A floating "refill" button re-inflates all.
class BubbleWrapToy extends StatefulWidget {
  const BubbleWrapToy({super.key});

  @override
  State<BubbleWrapToy> createState() => _BubbleWrapToyState();
}

class _BubbleWrapToyState extends State<BubbleWrapToy> {
  static const double _targetCell = 64.0;

  late List<bool> _popped;
  int _refillSeed = 0;

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

  void _pop(int index) {
    if (_popped[index]) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _popped[index] = true;
    });
  }

  void _refill() {
    HapticFeedback.mediumImpact();
    setState(() {
      _refillSeed++;
      _popped = List<bool>.filled(_popped.length, false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFDDEFF6), Color(0xFFBFD9E8)],
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double padding = 14.0;
          final double availW = constraints.maxWidth - padding * 2;
          final double availH = constraints.maxHeight - padding * 2;
          final int columns = math.max(3, (availW / _targetCell).round());
          final double cell = availW / columns;
          final int rows = math.max(3, (availH / cell).floor());
          final int count = columns * rows;
          _ensureSized(count);

          return Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(padding),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: count,
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 0,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return _WrapBubble(
                      key: ValueKey<int>(index * 7919 + _refillSeed),
                      popped: _popped[index],
                      onPop: () => _pop(index),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 22,
                right: 22,
                child: _RefillButton(onTap: _refill),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single glossy translucent bubble that deflates with a burst when popped.
class _WrapBubble extends StatefulWidget {
  const _WrapBubble({
    super.key,
    required this.popped,
    required this.onPop,
  });

  final bool popped;
  final VoidCallback onPop;

  @override
  State<_WrapBubble> createState() => _WrapBubbleState();
}

class _WrapBubbleState extends State<_WrapBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.popped ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _WrapBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.popped != oldWidget.popped) {
      if (widget.popped) {
        _controller.forward(from: 0.0);
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
      onTapDown: (_) => widget.onPop(),
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = _controller.value.clamp(0.0, 1.0);
            // Burst: bubble inflates briefly then collapses to a dimple.
            final double burst = math.sin(t * math.pi);
            final double scale = (1.0 - t) + burst * 0.12;

            if (t >= 0.999) {
              return const _Dimple();
            }

            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Burst ring.
                if (burst > 0.02)
                  FractionallySizedBox(
                    widthFactor: 0.6 + burst * 0.5,
                    heightFactor: 0.6 + burst * 0.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(burst * 0.7),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                Transform.scale(
                  scale: scale.clamp(0.0, 1.2),
                  child: const _GlossyBubble(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The inflated, glossy bubble visual.
class _GlossyBubble extends StatelessWidget {
  const _GlossyBubble();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: <Color>[
            Color(0xCCFFFFFF),
            Color(0x99B6E0F0),
            Color(0x88A0C8DC),
          ],
          stops: <double>[0.0, 0.45, 1.0],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF6E94A8).withOpacity(0.35),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: const Align(
        alignment: Alignment(-0.4, -0.45),
        child: FractionallySizedBox(
          widthFactor: 0.28,
          heightFactor: 0.28,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xCCFFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

/// The flat, popped dimple visual.
class _Dimple extends StatelessWidget {
  const _Dimple();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.78,
        heightFactor: 0.78,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(0.3, 0.35),
              radius: 0.9,
              colors: <Color>[
                Color(0x33597486),
                Color(0x110F2A36),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// A floating circular "refill" button.
class _RefillButton extends StatefulWidget {
  const _RefillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RefillButton> createState() => _RefillButtonState();
}

class _RefillButtonState extends State<_RefillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
          final double scale = 1.0 + math.sin(t * math.pi) * 0.18;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.92),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF466276).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.bubble_chart_rounded,
            size: 32,
            color: Color(0xFF3E6577),
          ),
        ),
      ),
    );
  }
}
