import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lifeskills/avatar/avatar.dart';
import '../lifeskills/avatar/hari_master.dart';
import '../lifeskills/avatar/pico.dart';

/// The emotional beats Hari + Pico can express as companions. Deterministic,
/// state-driven — no ML, but the experience should *feel* alive.
enum CompanionReaction {
  idle,
  curious,
  happy,
  excited,
  encouraging,
  proud,
  surprised,
  calm,
  soothing,
  thinking,
  sleepy,
  celebrating,
}

/// Drives a [CompanionView]. Activities call [tap]/[react]/[celebrate]/[calm]
/// as the child interacts; the companions respond and settle back to idle.
class CompanionController extends ChangeNotifier {
  CompanionReaction _reaction = CompanionReaction.idle;
  int _pulse = 0;
  int _energy = 0;
  Timer? _revert;
  Timer? _decay;

  CompanionReaction get reaction => _reaction;

  /// Increments on every reaction so views can trigger a one-shot bounce.
  int get pulse => _pulse;

  /// 0..6 — rises with rapid interaction, drives escalating excitement.
  int get energy => _energy;

  void react(
    CompanionReaction r, {
    Duration hold = const Duration(milliseconds: 1500),
    bool bounce = true,
  }) {
    _reaction = r;
    if (bounce) _pulse++;
    notifyListeners();
    _revert?.cancel();
    _revert = Timer(hold, () {
      _reaction =
          _energy > 0 ? CompanionReaction.happy : CompanionReaction.idle;
      notifyListeners();
    });
  }

  /// Generic "the child did something" — escalates energy into excitement.
  void tap() {
    _energy = math.min(_energy + 1, 6);
    final r = _energy >= 4
        ? CompanionReaction.excited
        : _energy >= 2
            ? CompanionReaction.happy
            : CompanionReaction.curious;
    react(r, hold: const Duration(milliseconds: 1200));
    _decay?.cancel();
    _decay = Timer(const Duration(milliseconds: 2600), () {
      _energy = 0;
      _reaction = CompanionReaction.idle;
      notifyListeners();
    });
  }

  void celebrate() =>
      react(CompanionReaction.celebrating, hold: const Duration(seconds: 2));

  void calm() {
    _energy = 0;
    react(CompanionReaction.calm, hold: const Duration(seconds: 4));
  }

  void setReaction(CompanionReaction r) {
    _revert?.cancel();
    _decay?.cancel();
    _reaction = r;
    notifyListeners();
  }

  @override
  void dispose() {
    _revert?.cancel();
    _decay?.cancel();
    super.dispose();
  }
}

/// Maps a reaction to Hari's expression + Pico's mood.
({AvatarEmotion hari, PicoMood pico}) _mapReaction(CompanionReaction r) {
  switch (r) {
    case CompanionReaction.idle:
      return (hari: AvatarEmotion.happy, pico: PicoMood.happy);
    case CompanionReaction.curious:
      return (hari: AvatarEmotion.curious, pico: PicoMood.curious);
    case CompanionReaction.happy:
      return (hari: AvatarEmotion.happy, pico: PicoMood.happy);
    case CompanionReaction.excited:
      return (hari: AvatarEmotion.excited, pico: PicoMood.excited);
    case CompanionReaction.encouraging:
      return (hari: AvatarEmotion.encouraging, pico: PicoMood.happy);
    case CompanionReaction.proud:
      return (hari: AvatarEmotion.proud, pico: PicoMood.celebrating);
    case CompanionReaction.surprised:
      return (hari: AvatarEmotion.surprised, pico: PicoMood.curious);
    case CompanionReaction.calm:
      return (hari: AvatarEmotion.calm, pico: PicoMood.calm);
    case CompanionReaction.soothing:
      return (hari: AvatarEmotion.calm, pico: PicoMood.comforting);
    case CompanionReaction.thinking:
      return (hari: AvatarEmotion.thinking, pico: PicoMood.curious);
    case CompanionReaction.sleepy:
      return (hari: AvatarEmotion.sleepy, pico: PicoMood.sleepy);
    case CompanionReaction.celebrating:
      return (hari: AvatarEmotion.excited, pico: PicoMood.celebrating);
  }
}

/// A living Hari + Pico pair that breathes at idle and bounces on reactions.
/// Reusable across toys, calm, learning and routines.
class CompanionView extends StatefulWidget {
  const CompanionView({
    super.key,
    required this.controller,
    this.showPico = true,
    this.animate = true,
  });

  final CompanionController controller;
  final bool showPico;
  final bool animate;

  @override
  State<CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<CompanionView>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _bounce;
  int _lastPulse = 0;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 560));
    if (widget.animate) _idle.repeat();
    widget.controller.addListener(_onReaction);
  }

  void _onReaction() {
    if (widget.controller.pulse != _lastPulse) {
      _lastPulse = widget.controller.pulse;
      if (widget.animate) _bounce.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onReaction);
    _idle.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = _mapReaction(widget.controller.reaction);
    final celebrating =
        widget.controller.reaction == CompanionReaction.celebrating;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_idle, _bounce]),
      builder: (context, _) {
        final bob = math.sin(_idle.value * math.pi * 2) * 4.0;
        final b = Curves.elasticOut.transform(_bounce.value.clamp(0.0, 1.0));
        final scale = 1.0 + (b * 0.16) * (1 - _bounce.value * 0.3);
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 140.0;
            final h = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 120.0;
            return Transform.translate(
              offset: Offset(0, bob),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (celebrating)
                      Positioned.fill(child: _Sparkles(t: _idle.value)),
                    // Hari — authored emotion art.
                    Align(
                      alignment: Alignment.bottomRight,
                      child: SizedBox(
                        width: w * 0.66,
                        height: h * 0.92,
                        child: HariMasterWidget(
                          emotion: map.hari,
                          pose: AvatarPose.idle,
                          device: HearingDevice.none,
                          hearingSide: HearingSide.left,
                          animate: widget.animate,
                        ),
                      ),
                    ),
                    if (widget.showPico)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: SizedBox(
                          width: w * 0.5,
                          height: h * 0.6,
                          child: PicoWidget(
                            mood: map.pico,
                            animate: widget.animate,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Sparkles extends StatelessWidget {
  const _Sparkles({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SparklePainter(t));
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    for (int i = 0; i < 10; i++) {
      final phase = (t + i / 10) % 1.0;
      final x = rnd.nextDouble() * size.width;
      final y = size.height * (1 - phase) * 0.9;
      final a = (math.sin(phase * math.pi)).clamp(0.0, 1.0);
      final r = 2.0 + rnd.nextDouble() * 2.5;
      final paint = Paint()
        ..color = <Color>[
          const Color(0xFFFFD166),
          const Color(0xFF06D6A0),
          const Color(0xFF4CC9F0),
          const Color(0xFFF15BB5),
        ][i % 4]
            .withOpacity(0.85 * a);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}
