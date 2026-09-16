import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../companion/companion.dart';
import '../../models/toy_meta.dart';
import '../../services/audio/tone_player.dart';
import '../../state/providers.dart';
import '../settings/audio_toggle_button.dart';
import 'toy_registry.dart';

/// Immersive, full-screen sensory toy player.
///
/// The toy fills the whole canvas; a translucent back button floats on top. On
/// exit the session is silently logged so the regulation engine can learn.
class ToyPlayerScreen extends ConsumerStatefulWidget {
  const ToyPlayerScreen({super.key, required this.toy});

  final ToyMeta toy;

  @override
  ConsumerState<ToyPlayerScreen> createState() => _ToyPlayerScreenState();
}

class _ToyPlayerScreenState extends ConsumerState<ToyPlayerScreen> {
  final DateTime _start = DateTime.now();
  final CompanionController _companion = CompanionController();
  bool _chromeVisible = true;
  RegulationLogNotifier? _logger;

  @override
  void initState() {
    super.initState();
    _companion.setReaction(reactionForToyIdle(widget.toy.id));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture the notifier while `ref` is still valid; `ref` cannot be used
    // inside dispose() in Riverpod 2.x.
    _logger = ref.read(regulationLogProvider.notifier);
  }

  @override
  void dispose() {
    // Only log meaningful play sessions (> 3s).
    if (DateTime.now().difference(_start).inSeconds >= 3) {
      _logger?.logSession(toyIds: <String>[widget.toy.id]);
    }
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
          Positioned.fill(
            child: NotificationListener<CompanionEventNotification>(
              onNotification: (notification) {
                _companion.reactToEvent(notification.event, toyId: widget.toy.id);
                return true;
              },
              child: GestureDetector(
                onTapDown: (_) => _companion.reactToEvent(
                  eventForToyTap(widget.toy.id),
                  toyId: widget.toy.id,
                ),
                onLongPress: () {
                  _companion.pair();
                  setState(() => _chromeVisible = !_chromeVisible);
                },
                child: buildToy(widget.toy.id),
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            width: 160,
            height: 136,
            child: IgnorePointer(
              child: CompanionView(controller: _companion),
            ),
          ),
          AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      _RoundButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.toy.emoji}  ${widget.toy.title}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      const MuteButton(),
                      const SizedBox(width: 12),
                      _RoundButton(
                        icon: Icons.visibility_off_rounded,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _chromeVisible = false);
                        },
                      ),
                    ],
                  ),
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
        onTap: () {
          HapticFeedback.selectionClick();
          TonePlayer.instance.playCue(SoundCue.navigation);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

/// Opens a toy, or a gentle "coming soon" sheet for scaffolded entries.
void openToy(BuildContext context, ToyMeta toy) {
  if (toyIsPlayable(toy.id)) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ToyPlayerScreen(toy: toy)),
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1240),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(toy.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(toy.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('This toy is coming soon to the toybox. ✨',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
