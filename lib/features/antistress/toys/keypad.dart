import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/audio/tone_player.dart';

/// A full-bleed calculator-style keypad of big clicky buttons.
///
/// Tap digits to watch them scroll across a little display; the clear key
/// wipes it. No math, no goal — just the joy of pressing chunky keys.
class KeypadToy extends StatefulWidget {
  const KeypadToy({super.key});

  @override
  State<KeypadToy> createState() => _KeypadToyState();
}

class _KeypadToyState extends State<KeypadToy> {
  static const int _maxDigits = 12;

  String _display = '';

  void _press(String label) {
    HapticFeedback.selectionClick();
    TonePlayer.instance.playThock();
    setState(() {
      _display = (_display + label);
      if (_display.length > _maxDigits) {
        _display = _display.substring(_display.length - _maxDigits);
      }
    });
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    TonePlayer.instance.playClick();
    setState(() => _display = '');
  }

  @override
  Widget build(BuildContext context) {
    const List<String> keys = <String>[
      '7', '8', '9',
      '4', '5', '6',
      '1', '2', '3',
      'C', '0', '.',
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0E1726), Color(0xFF182338), Color(0xFF0B1220)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Display(text: _display),
                  const SizedBox(height: 22),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: keys.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.05,
                    ),
                    itemBuilder: (BuildContext context, int i) {
                      final String label = keys[i];
                      final bool isClear = label == 'C';
                      return _KeyButton(
                        label: label,
                        isAccent: isClear,
                        onPressed: isClear ? _clear : () => _press(label),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The top readout that shows the pressed digits, newest on the right.
class _Display extends StatelessWidget {
  const _Display({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0A1220), Color(0xFF111B2E)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> anim) {
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.25, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            );
          },
          child: Text(
            text.isEmpty ? '·' : text,
            key: ValueKey<String>(text),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: const Color(0xFF64DFDF),
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              shadows: <Shadow>[
                Shadow(
                  color: const Color(0xFF64DFDF).withOpacity(0.5),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single chunky key that presses in (scale + shadow collapse) on tap.
class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.label,
    required this.isAccent,
    required this.onPressed,
  });

  final String label;
  final bool isAccent;
  final VoidCallback onPressed;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    lowerBound: 0,
    upperBound: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) => _controller.forward();
  void _up() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final Color base =
        widget.isAccent ? const Color(0xFFEF476F) : const Color(0xFF2B3650);
    final Color top =
        widget.isAccent ? const Color(0xFFFF6B8B) : const Color(0xFF3A4866);

    return GestureDetector(
      onTapDown: _down,
      onTapUp: (TapUpDetails _) {
        _up();
        widget.onPressed();
      },
      onTapCancel: _up,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;
          final double scale = 1 - 0.08 * t;
          final double depth = 8 * (1 - t);
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[top, base],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: depth + 4,
                    offset: Offset(0, depth * 0.7),
                  ),
                  if (widget.isAccent)
                    BoxShadow(
                      color: const Color(0xFFEF476F).withOpacity(0.35),
                      blurRadius: 20,
                    ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Center(
          child: widget.isAccent
              ? const Icon(Icons.backspace_outlined,
                  color: Colors.white, size: 30)
              : Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
