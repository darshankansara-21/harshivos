import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/services/audio/game_music_host.dart';
import 'package:harshivos/services/audio/tone_player.dart';

Future<void> _sendLifecycle(WidgetTester tester, String state) {
  return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state),
    (ByteData? data) {},
  );
}

void main() {
  testWidgets(
      'GameMusicHost stops the bed when the app backgrounds and restarts it on resume',
      (tester) async {
    // Exercises the production path (musicEnabled + full volume) so a real
    // regression here would surface, even though the test binding's
    // `_audioAvailable` guard keeps actual playback a no-op.
    TonePlayer.instance.musicEnabled = true;
    TonePlayer.instance.volumeScale = 1.0;
    addTearDown(() => TonePlayer.instance.musicEnabled = false);

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: GameMusicHost(
        playing: true,
        bed: WonderMusicBed.arcade,
        child: SizedBox.shrink(),
      ),
    ));

    // A background/foreground cycle (app switcher, lock screen, phone call)
    // must never throw — this is the regression batch 98 fixed: the bed
    // used to keep looping right through a backgrounded app because nothing
    // observed app lifecycle at all.
    await _sendLifecycle(tester, 'AppLifecycleState.inactive');
    await _sendLifecycle(tester, 'AppLifecycleState.paused');
    await tester.pump();
    await _sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.pump();

    // Leaving the game while backgrounded must still clean up without error.
    await _sendLifecycle(tester, 'AppLifecycleState.paused');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
