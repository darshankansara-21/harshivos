import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Frosted-glass surface used throughout the app (glassmorphism).
///
/// When [onTap] is set the card gives a satisfying *visual* press response —
/// it scales down and a soft glow blooms underneath. This matters deeply for
/// Harshiv: with a hearing aid he cannot rely on click sounds, so every tap
/// must confirm itself with motion and light.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
    this.blur = 18,
    this.onTap,
    this.gradient,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final VoidCallback? onTap;
  final Gradient? gradient;

  /// Colour of the press glow. Defaults to a soft white bloom.
  final Color? glowColor;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final glow = widget.glowColor ?? Colors.white;
    final interactive = widget.onTap != null;

    final card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    widget.onTap!.call();
                  },
            onHighlightChanged: _setPressed,
            borderRadius: radius,
            splashColor: glow.withOpacity(0.18),
            highlightColor: glow.withOpacity(0.06),
            child: Ink(
              decoration: BoxDecoration(
                gradient: widget.gradient,
                color: widget.gradient == null ? AppColors.glassFill : null,
                borderRadius: radius,
                border: Border.all(
                  color: _pressed ? glow.withOpacity(0.65) : AppColors.glassStroke,
                  width: _pressed ? 1.6 : 1.2,
                ),
              ),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );

    if (!interactive) return card;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: _pressed
              ? <BoxShadow>[
                  BoxShadow(
                    color: glow.withOpacity(0.35),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: card,
      ),
    );
  }
}
