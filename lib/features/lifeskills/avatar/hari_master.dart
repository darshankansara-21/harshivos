import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'avatar.dart' show AvatarEmotion, AvatarPose, HearingDevice, HearingSide;

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
    final smile = emotion == AvatarEmotion.excited ? 1.035 : 1.0;
    return RepaintBoundary(
      child: Transform.scale(
        scale: smile,
        child: SvgPicture.asset(
          'assets/characters/hari_master.svg',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          semanticsLabel: 'Hari',
        ),
      ),
    );
  }
}