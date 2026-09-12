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

  // Authored raster hero art (Pixar-style Hari). Emotion busts are preferred
  // when available; the standing hero and procedural SVG remain safe fallbacks
  // so the app never shows an empty character if a PNG is not bundled.
  static const String _heroAsset = 'assets/characters/hari_master.png';
  static const String _vectorAsset = 'assets/characters/hari_master.svg';

  // Maps every emotion to the closest authored expression bust.
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

  // Maps distinct action poses to authored full-body art.
  static const Map<AvatarPose, String> _poseArt = <AvatarPose, String>{
    AvatarPose.wave: 'waving',
    AvatarPose.walk: 'walking',
    AvatarPose.run: 'walking',
    AvatarPose.brush: 'brushing',
  };

  @override
  Widget build(BuildContext context) {
    // Priority: an authored action pose, else the matching emotion bust, else
    // the standing hero. The procedural SVG is the final safety net.
    final poseArt = _poseArt[pose];
    final emotionArt = _emotionArt[emotion];
    final String asset;
    if (poseArt != null) {
      asset = 'assets/characters/actions/$poseArt.png';
    } else if (emotionArt != null) {
      asset = 'assets/characters/emotions/$emotionArt.png';
    } else {
      asset = _heroAsset;
    }
    return RepaintBoundary(
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
    );
  }
}