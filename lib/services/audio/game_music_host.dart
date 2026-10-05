import 'package:flutter/widgets.dart';

import 'tone_player.dart';

/// Drives the optional background music for a game: starts the family's bed
/// while the game is actively playing and stops it on the start card, the
/// result screen, and when the game is left. All calls are no-ops unless the
/// parent has opted into music (and it always obeys the global mute).
class GameMusicHost extends StatefulWidget {
  const GameMusicHost({
    super.key,
    required this.playing,
    required this.bed,
    required this.child,
  });

  final bool playing;
  final WonderMusicBed bed;
  final Widget child;

  @override
  State<GameMusicHost> createState() => _GameMusicHostState();
}

class _GameMusicHostState extends State<GameMusicHost> with WidgetsBindingObserver {
  // Tracks whether the app itself is in the foreground, independent of
  // `widget.playing`. Without this, backgrounding the app (phone call, app
  // switcher, lock screen) left the music bed looping right through it —
  // the one place in the app that kept making noise with nobody looking at
  // the screen, unlike every tap/companion sound which naturally stops the
  // moment a finger lifts.
  bool _appVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void didUpdateWidget(GameMusicHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (visible == _appVisible) return;
    _appVisible = visible;
    _sync();
  }

  void _sync() {
    if (widget.playing && _appVisible) {
      TonePlayer.instance.startMusic(widget.bed);
    } else {
      TonePlayer.instance.stopMusic();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TonePlayer.instance.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
