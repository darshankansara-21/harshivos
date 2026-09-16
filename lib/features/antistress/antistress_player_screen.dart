import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../companion/companion.dart';
import '../../services/audio/tone_player.dart';
import '../settings/audio_toggle_button.dart';

/// Full-screen host for an Antistress fidget toy, now with a living Hari + Pico
/// companion that watches and reacts as the child plays.
///
/// The toy fills the whole canvas; a translucent back button floats on top and
/// the companions sit in the bottom-left, reacting to every touch.
class AntistressPlayerScreen extends StatefulWidget {
  const AntistressPlayerScreen({
    super.key,
    required this.toy,
    required this.title,
    required this.emoji,
  });

  final Widget toy;
  final String title;
  final String emoji;

  @override
  State<AntistressPlayerScreen> createState() => _AntistressPlayerScreenState();
}

class _AntistressPlayerScreenState extends State<AntistressPlayerScreen> {
  final CompanionController _companion = CompanionController();
  Timer? _hello;

  @override
  void initState() {
    super.initState();
    _companion.setReaction(CompanionReaction.curious);
    _hello = Timer(const Duration(milliseconds: 700),
        () => _companion.react(CompanionReaction.happy));
  }

  @override
  void dispose() {
    _hello?.cancel();
    _companion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Toy fills the canvas; a passive listener lets the companions react
          // to every touch without intercepting the toy's own gestures.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.deferToChild,
              onPointerDown: (_) =>
                  _companion.reactToEvent(ExperienceEvent.bubblePopped),
              child: widget.toy,
            ),
          ),
          // Living companions — never block the toy.
          Positioned(
            left: 10,
            bottom: 10,
            width: 150,
            height: 132,
            child: IgnorePointer(
              child: CompanionView(controller: _companion),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    _RoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        TonePlayer.instance.playCue(SoundCue.navigation);
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.emoji}  ${widget.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const MuteButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
