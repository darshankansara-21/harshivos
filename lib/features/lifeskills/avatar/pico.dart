import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pico's emotional and behavioural states.
enum PicoMood {
  happy,
  excited,
  curious,
  sleepy,
  calm,
  celebrating,
  worried,
  comforting,
}

/// Canonical Pico renderer: immutable approved artwork plus motion transforms.
class PicoWidget extends StatefulWidget {
  const PicoWidget({
    super.key,
    this.mood = PicoMood.happy,
    this.animate = true,
  });

  final PicoMood mood;
  final bool animate;

  @override
  State<PicoWidget> createState() => _PicoWidgetState();
}

class _PicoWidgetState extends State<PicoWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Map<PicoMood, String> _moodAsset = <PicoMood, String>{
    PicoMood.happy: 'happy',
    PicoMood.excited: 'playful',
    PicoMood.curious: 'curious',
    PicoMood.sleepy: 'sleepy',
    PicoMood.calm: 'calm',
    PicoMood.celebrating: 'playful',
    PicoMood.worried: 'calm',
    PicoMood.comforting: 'loving',
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _motion(widget.mood).period,
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PicoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = _motion(widget.mood);
    if (_controller.duration != current.period) {
      _controller.duration = current.period;
      if (widget.animate) _controller.repeat();
    }
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _motion(widget.mood);
    final asset = 'assets/characters/pico/${_moodAsset[widget.mood]}.png';
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = _controller.value * math.pi * 2;
          final y = math.sin(phase) * motion.bobPx;
          final x = math.sin(phase * 0.5 + 0.9) * motion.xDriftPx;
          final tilt = math.sin(phase + motion.tiltLead) * motion.tiltRad;
          final scale = 1 + (math.sin(phase + 1.1) * motion.breatheScale);
          return Transform.translate(
            offset: Offset(x, y),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  filterQuality: FilterQuality.high,
                  semanticLabel: 'Pico',
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static _PicoMotion _motion(PicoMood mood) {
    switch (mood) {
      case PicoMood.calm:
      case PicoMood.comforting:
        return const _PicoMotion(
          period: Duration(milliseconds: 3200),
          bobPx: 1.4,
          xDriftPx: 0.8,
          tiltRad: 0.010,
          breatheScale: 0.012,
          tiltLead: 0.4,
        );
      case PicoMood.sleepy:
        return const _PicoMotion(
          period: Duration(milliseconds: 4200),
          bobPx: 0.9,
          xDriftPx: 0.5,
          tiltRad: 0.006,
          breatheScale: 0.010,
          tiltLead: 0.0,
        );
      case PicoMood.excited:
      case PicoMood.celebrating:
        return const _PicoMotion(
          period: Duration(milliseconds: 1100),
          bobPx: 4.8,
          xDriftPx: 1.2,
          tiltRad: 0.045,
          breatheScale: 0.020,
          tiltLead: 1.2,
        );
      case PicoMood.curious:
        return const _PicoMotion(
          period: Duration(milliseconds: 1700),
          bobPx: 2.8,
          xDriftPx: 1.5,
          tiltRad: 0.030,
          breatheScale: 0.016,
          tiltLead: 0.7,
        );
      case PicoMood.worried:
        return const _PicoMotion(
          period: Duration(milliseconds: 2400),
          bobPx: 1.8,
          xDriftPx: 0.7,
          tiltRad: 0.020,
          breatheScale: 0.013,
          tiltLead: 0.2,
        );
      case PicoMood.happy:
        return const _PicoMotion(
          period: Duration(milliseconds: 1500),
          bobPx: 3.3,
          xDriftPx: 1.0,
          tiltRad: 0.026,
          breatheScale: 0.017,
          tiltLead: 0.9,
        );
    }
  }
}

class _PicoMotion {
  const _PicoMotion({
    required this.period,
    required this.bobPx,
    required this.xDriftPx,
    required this.tiltRad,
    required this.breatheScale,
    required this.tiltLead,
  });

  final Duration period;
  final double bobPx;
  final double xDriftPx;
  final double tiltRad;
  final double breatheScale;
  final double tiltLead;
}
