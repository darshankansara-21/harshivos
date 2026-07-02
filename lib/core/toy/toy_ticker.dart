import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Drop-in game loop for sensory toys.
///
/// Mix onto a [State] that also uses [TickerProviderStateMixin]. Provides a
/// real per-frame delta-time ([onTick]) and triggers a repaint each frame, so
/// every toy gets smooth ~60fps physics with almost no boilerplate.
mixin ToyTicker<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  Ticker? _ticker;
  Duration _last = Duration.zero;

  /// Called once per frame with the elapsed seconds since the previous frame.
  void onTick(double dt);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      // Guard against the first frame and pauses (e.g. backgrounding).
      if (dt > 0 && dt < 0.1) onTick(dt);
      if (mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}
