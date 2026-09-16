import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/audio/tone_player.dart';
import '../../state/providers.dart';

/// The single, reusable sound on/off control for WonderPlay.
///
/// It reads and writes the one global [SensoryPreferences.muted] flag, so every
/// placement (home, any game, any toy) shares the exact same state — there is
/// no second audio switch and no way for one screen to disagree with another.
class MuteButton extends ConsumerWidget {
  const MuteButton({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted =
        ref.watch(sensoryPreferencesProvider.select((p) => p.muted));
    return AudioToggleButton(
      muted: muted,
      size: size,
      onPressed: () {
        final notifier = ref.read(sensoryPreferencesProvider.notifier);
        final wasMuted = muted;
        notifier.toggleMuted();
        // A soft confirmation only when turning sound back ON, so the child
        // hears that it worked. volumeScale is updated by the root rebuild, so
        // play on the next frame.
        if (wasMuted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            TonePlayer.instance.playCue(SoundCue.navigation);
          });
        }
      },
    );
  }
}

/// The presentation of the mute control — a round, translucent button that
/// matches the floating chrome used across game and toy screens.
class AudioToggleButton extends StatelessWidget {
  const AudioToggleButton({
    super.key,
    required this.muted,
    required this.onPressed,
    this.size = 44,
  });

  final bool muted;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: !muted,
      label: muted ? 'Sound off' : 'Sound on',
      child: Tooltip(
        message: muted ? 'Turn sound on' : 'Turn sound off',
        child: Material(
          color: Colors.black.withOpacity(0.35),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: muted ? Colors.white70 : Colors.white,
                size: size * 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
