import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'avatar.dart' show AvatarEmotion, AvatarPose, HearingDevice, HearingSide;

/// Canonical Hari renderer. The face artwork is immutable; animation is added
/// only as transform motion around that approved art.
class HariMasterWidget extends StatefulWidget {
  const HariMasterWidget({
    super.key,
    required this.emotion,
    required this.pose,
    required this.device,
    required this.hearingSide,
    required this.glasses,
    required this.animate,
  });

  final AvatarEmotion emotion;
  final AvatarPose pose;
  final HearingDevice device;
  final HearingSide hearingSide;
  final bool glasses;
  final bool animate;

  @override
  State<HariMasterWidget> createState() => _HariMasterWidgetState();
}

class _HariMasterWidgetState extends State<HariMasterWidget>
    with SingleTickerProviderStateMixin {
  static const String _heroAsset = 'assets/characters/emotions/happy.png';
  static const String _vectorAsset = 'assets/characters/hari_master.svg';

  static const Map<AvatarEmotion, String> _emotionArt = <AvatarEmotion, String>{
    AvatarEmotion.happy: 'happy',
    AvatarEmotion.calm: 'calm',
    AvatarEmotion.excited: 'excited',
    AvatarEmotion.proud: 'proud',
    AvatarEmotion.sad: 'sad',
    AvatarEmotion.frustrated: 'frustrated',
    AvatarEmotion.tired: 'sleepy',
    AvatarEmotion.nervous: 'worried',
    AvatarEmotion.silly: 'silly',
    AvatarEmotion.loving: 'love',
    AvatarEmotion.relaxed: 'calm',
    AvatarEmotion.sleepy: 'sleepy',
    AvatarEmotion.curious: 'curious',
    AvatarEmotion.thinking: 'thinking',
    AvatarEmotion.confused: 'thinking',
    AvatarEmotion.surprised: 'excited',
    AvatarEmotion.worried: 'worried',
    AvatarEmotion.angry: 'frustrated',
    AvatarEmotion.scared: 'worried',
    AvatarEmotion.overwhelmed: 'worried',
    AvatarEmotion.shy: 'sad',
    AvatarEmotion.kind: 'love',
    AvatarEmotion.listening: 'calm',
    AvatarEmotion.encouraging: 'proud',
  };

  static const Map<AvatarPose, String> _poseArt = <AvatarPose, String>{
    AvatarPose.wave: 'waving',
    AvatarPose.walk: 'walking',
    AvatarPose.run: 'walking',
    AvatarPose.brush: 'brushing',
  };

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _motion(widget.pose, widget.emotion).period,
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant HariMasterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = _motion(widget.pose, widget.emotion);
    if (_controller.duration != current.period) {
      _controller.duration = current.period;
      if (widget.animate) {
        _controller.repeat();
      }
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
    final asset = _assetFor(widget.pose, widget.emotion, widget.device, widget.glasses);
    final motion = _motion(widget.pose, widget.emotion);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = _controller.value * math.pi * 2;
          final y = math.sin(phase) * motion.bobPx;
          final tilt = math.sin(phase + motion.tiltLead) * motion.tiltRad;
          final breathe = 1 + (math.sin(phase + math.pi / 3) * motion.breatheScale);
          return Transform.translate(
            offset: Offset(0, y),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: breathe,
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  semanticLabel: 'Hari',
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stack) => SvgPicture.asset(
                    _vectorAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    semanticsLabel: 'Hari',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _assetFor(
    AvatarPose pose,
    AvatarEmotion emotion,
    HearingDevice device,
    bool glasses,
  ) {
    if (glasses) {
      return 'assets/characters/looks/glasses.png';
    }
    if (device == HearingDevice.cochlear) {
      return 'assets/characters/looks/cochlear.png';
    }
    final poseArt = _poseArt[pose];
    if (poseArt != null) {
      return 'assets/characters/actions/$poseArt.png';
    }
    final emotionArt = _emotionArt[emotion];
    if (emotionArt != null) {
      return 'assets/characters/emotions/$emotionArt.png';
    }
    return _heroAsset;
  }

  static _HariMotion _motion(AvatarPose pose, AvatarEmotion emotion) {
    if (emotion == AvatarEmotion.calm ||
        pose == AvatarPose.breathe ||
        pose == AvatarPose.takeBreak) {
      return const _HariMotion(
        period: Duration(milliseconds: 3600),
        bobPx: 1.8,
        tiltRad: 0.010,
        breatheScale: 0.012,
        tiltLead: 0.2,
      );
    }
    if (pose == AvatarPose.cheer || emotion == AvatarEmotion.excited) {
      return const _HariMotion(
        period: Duration(milliseconds: 1300),
        bobPx: 5.5,
        tiltRad: 0.030,
        breatheScale: 0.020,
        tiltLead: 1.4,
      );
    }
    if (pose == AvatarPose.walk || pose == AvatarPose.run) {
      return const _HariMotion(
        period: Duration(milliseconds: 900),
        bobPx: 4.6,
        tiltRad: 0.018,
        breatheScale: 0.015,
        tiltLead: 0.8,
      );
    }
    if (pose == AvatarPose.sleep || emotion == AvatarEmotion.sleepy) {
      return const _HariMotion(
        period: Duration(milliseconds: 4200),
        bobPx: 1.1,
        tiltRad: 0.008,
        breatheScale: 0.010,
        tiltLead: 0.0,
      );
    }
    return const _HariMotion(
      period: Duration(milliseconds: 2100),
      bobPx: 2.7,
      tiltRad: 0.014,
      breatheScale: 0.014,
      tiltLead: 0.5,
    );
  }
}

class _HariMotion {
  const _HariMotion({
    required this.period,
    required this.bobPx,
    required this.tiltRad,
    required this.breatheScale,
    required this.tiltLead,
  });

  final Duration period;
  final double bobPx;
  final double tiltRad;
  final double breatheScale;
  final double tiltLead;
}
