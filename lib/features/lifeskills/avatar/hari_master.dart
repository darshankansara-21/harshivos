import 'package:flutter/material.dart';

import 'avatar.dart'
  show
    AvatarConfig,
    AvatarEmotion,
    AvatarPose,
    AvatarWidget,
    HearingDevice,
    HearingSide;

/// Authored vector master for Hari's most common welcoming states. Other
/// expressions and instructional poses retain the established API fallback in
/// [Hari] until equivalent authored pose assets are available.
class HariMasterWidget extends StatelessWidget {
  const HariMasterWidget({
    super.key,
    required this.emotion,
    required this.pose,
    required this.device,
    required this.hearingSide,
    required this.animate,
  });

  final AvatarEmotion emotion;
  final AvatarPose pose;
  final HearingDevice device;
  final HearingSide hearingSide;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    // Single production-safe path with complete pose/emotion/device coverage.
    return AvatarWidget(
      config:
          AvatarConfig.hari.copyWith(device: device, hearingSide: hearingSide),
      pose: pose,
      emotion: emotion,
      animate: animate,
    );
  }
}