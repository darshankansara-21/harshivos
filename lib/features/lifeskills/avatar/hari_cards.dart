import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/voice/hari_voice.dart';
import '../../../state/providers.dart';
import 'avatar.dart';

// ---------------------------------------------------------------------------
// Reusable Hari cards — emotions and calming strategies.
// ---------------------------------------------------------------------------
// One shared system so Feelings, Calm, Communication, Social Stories and more
// all speak with the same warm character. Every card shows Hari, uses minimal
// child-friendly language, and can gently speak (respecting sensory volume).
// ---------------------------------------------------------------------------

/// A feeling Hari can model: its expression, a child-first name, a first-person
/// phrase, and one gentle coping idea. No diagnosis, no pressure.
@immutable
class HariFeeling {
  const HariFeeling(this.emotion, this.name, this.phrase, this.coping, this.color);
  final AvatarEmotion emotion;
  final String name;
  final String phrase;
  final String coping;
  final Color color;
}

const List<HariFeeling> kHariFeelings = <HariFeeling>[
  HariFeeling(AvatarEmotion.happy, 'Happy', 'I feel happy.', "Let's keep the fun going.", Color(0xFFFFC24B)),
  HariFeeling(AvatarEmotion.excited, 'Excited', 'I feel excited!', "Take a big breath and enjoy.", Color(0xFFFF8A5B)),
  HariFeeling(AvatarEmotion.calm, 'Calm', 'I feel calm.', "This feels nice and safe.", Color(0xFF57C7C7)),
  HariFeeling(AvatarEmotion.proud, 'Proud', 'I feel proud.', "You did something great.", Color(0xFFFFD166)),
  HariFeeling(AvatarEmotion.silly, 'Silly', 'I feel silly!', "Giggles are okay.", Color(0xFFF15BB5)),
  HariFeeling(AvatarEmotion.loving, 'Loving', 'I feel love.', "Share a gentle hug.", Color(0xFFFF6B9D)),
  HariFeeling(AvatarEmotion.sleepy, 'Sleepy', 'I feel sleepy.', "It might be time to rest.", Color(0xFF8C7AE6)),
  HariFeeling(AvatarEmotion.curious, 'Curious', 'I feel curious.', "Let's find out together.", Color(0xFF4CC9F0)),
  HariFeeling(AvatarEmotion.confused, 'Confused', 'I feel confused.', "It's okay to ask for help.", Color(0xFF9B8CFF)),
  HariFeeling(AvatarEmotion.surprised, 'Surprised', 'I feel surprised!', "Take a slow breath.", Color(0xFF6BCB77)),
  HariFeeling(AvatarEmotion.sad, 'Sad', 'I feel sad.', "It's okay. Let's find comfort.", Color(0xFF5AA9E6)),
  HariFeeling(AvatarEmotion.worried, 'Worried', 'I feel worried.', "Let's breathe together.", Color(0xFF7AA5D2)),
  HariFeeling(AvatarEmotion.frustrated, 'Frustrated', 'I feel frustrated.', "Let's take a little break.", Color(0xFFEF6F6C)),
  HariFeeling(AvatarEmotion.angry, 'Angry', 'I feel angry.', "Squeeze tight, then let go.", Color(0xFFE5575A)),
  HariFeeling(AvatarEmotion.scared, 'Scared', 'I feel scared.', "You are safe. Hari is here.", Color(0xFF6C7A9C)),
  HariFeeling(AvatarEmotion.overwhelmed, 'Overwhelmed', "It's a lot right now.", "Let's find a calm, quiet spot.", Color(0xFF8E7CC3)),
  HariFeeling(AvatarEmotion.shy, 'Shy', 'I feel shy.', "That's okay. Take your time.", Color(0xFFB58CD6)),
];

/// A self-regulation strategy Hari demonstrates. Not medical treatment — a
/// child-friendly idea to try together.
@immutable
class CalmingStrategy {
  const CalmingStrategy(this.title, this.pose, this.emotion, this.phrase, this.color);
  final String title;
  final AvatarPose pose;
  final AvatarEmotion emotion;
  final String phrase;
  final Color color;
}

const List<CalmingStrategy> kCalmingStrategies = <CalmingStrategy>[
  CalmingStrategy('Take slow breaths', AvatarPose.breathe, AvatarEmotion.calm, 'Breathe in… and slowly out.', Color(0xFF57C7C7)),
  CalmingStrategy('Squeeze something soft', AvatarPose.hold, AvatarEmotion.calm, 'Squeeze tight… then let go.', Color(0xFF6BCB77)),
  CalmingStrategy('Ask for a break', AvatarPose.takeBreak, AvatarEmotion.calm, "It's okay to take a break.", Color(0xFF4CC9F0)),
  CalmingStrategy('Go somewhere quiet', AvatarPose.sit, AvatarEmotion.relaxed, 'Find a cozy, quiet spot.', Color(0xFF8C7AE6)),
  CalmingStrategy('Listen to calm sounds', AvatarPose.listen, AvatarEmotion.relaxed, 'Soft sounds help me settle.', Color(0xFF9B8CFF)),
  CalmingStrategy('Hug something you love', AvatarPose.hold, AvatarEmotion.loving, 'Hold your comfort thing close.', Color(0xFFFF6B9D)),
  CalmingStrategy('Drink some water', AvatarPose.drink, AvatarEmotion.calm, 'Take a slow, cool sip.', Color(0xFF54A0FF)),
  CalmingStrategy('Count slowly', AvatarPose.think, AvatarEmotion.calm, 'One… two… three…', Color(0xFFFFC24B)),
  CalmingStrategy('Push on the wall', AvatarPose.stretch, AvatarEmotion.calm, 'Push and feel strong.', Color(0xFFEF8354)),
  CalmingStrategy('Stretch up high', AvatarPose.stretch, AvatarEmotion.relaxed, 'Reach up as tall as you can.', Color(0xFF6BCB77)),
  CalmingStrategy('Use headphones', AvatarPose.listen, AvatarEmotion.calm, 'Quiet the busy noise.', Color(0xFF57C7C7)),
  CalmingStrategy('Ask for help', AvatarPose.help, AvatarEmotion.worried, 'You can always ask for help.', Color(0xFF7AA5D2)),
  CalmingStrategy('Sit somewhere cozy', AvatarPose.sit, AvatarEmotion.relaxed, 'Get comfy and soft.', Color(0xFF8E7CC3)),
  CalmingStrategy('Look at something calm', AvatarPose.idle, AvatarEmotion.calm, 'Watch something gentle.', Color(0xFF4CC9F0)),
  CalmingStrategy('Choose another activity', AvatarPose.point, AvatarEmotion.happy, "Let's try something new.", Color(0xFFFFD166)),
];

double _voiceVolume(WidgetRef ref) =>
    ref.read(sensoryPreferencesProvider).volumeScale;

/// A card that shows Hari expressing a feeling, names it, and offers a gentle
/// coping idea. Tapping the speaker lets Hari say it out loud.
class HariEmotionCard extends ConsumerWidget {
  const HariEmotionCard({
    super.key,
    required this.feeling,
    this.showCoping = true,
    this.onTap,
  });

  final HariFeeling feeling;
  final bool showCoping;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap ??
          () => HariVoice.instance.speak(
                showCoping ? '${feeling.phrase} ${feeling.coping}' : feeling.phrase,
                volume: _voiceVolume(ref),
              ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              feeling.color.withOpacity(0.32),
              feeling.color.withOpacity(0.12),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(feeling.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                ),
                _SpeakDot(
                  color: feeling.color,
                  onTap: () => HariVoice.instance.speak(
                    showCoping
                        ? '${feeling.phrase} ${feeling.coping}'
                        : feeling.phrase,
                    volume: _voiceVolume(ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AspectRatio(
              aspectRatio: 1,
              child: Hari(emotion: feeling.emotion, pose: HariPose.idle),
            ),
            const SizedBox(height: 6),
            Text(feeling.phrase,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            if (showCoping) ...<Widget>[
              const SizedBox(height: 4),
              Text(feeling.coping,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A calming strategy Hari demonstrates. "Try it with me" plays the gentle
/// voice cue and gives warm, no-pressure feedback.
class CalmingStrategyCard extends ConsumerStatefulWidget {
  const CalmingStrategyCard({super.key, required this.strategy});
  final CalmingStrategy strategy;

  @override
  ConsumerState<CalmingStrategyCard> createState() =>
      _CalmingStrategyCardState();
}

class _CalmingStrategyCardState extends ConsumerState<CalmingStrategyCard> {
  bool _tried = false;

  void _try() {
    final s = widget.strategy;
    HariVoice.instance.speak(s.phrase, volume: _voiceVolume(ref));
    setState(() => _tried = true);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _tried = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strategy;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            s.color.withOpacity(0.30),
            s.color.withOpacity(0.10),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 104,
            child: Hari(emotion: s.emotion, pose: s.pose),
          ),
          const SizedBox(height: 8),
          Text(s.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(_tried ? "You've got this. 💙" : s.phrase,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 13)),
          const SizedBox(height: 10),
          Material(
            color: s.color,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _try,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Text('Try it with me',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakDot extends StatelessWidget {
  const _SpeakDot({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.9),
        ),
        child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}
