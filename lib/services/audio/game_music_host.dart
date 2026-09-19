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

class _GameMusicHostState extends State<GameMusicHost> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(GameMusicHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.playing) {
      TonePlayer.instance.startMusic(widget.bed);
    } else {
      TonePlayer.instance.stopMusic();
    }
  }

  @override
  void dispose() {
    TonePlayer.instance.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
