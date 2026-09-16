import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/audio/tone_player.dart';
import '../lifeskills/avatar/avatar.dart';
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
  pair,
  dance,
}

/// Cross-feature action events so screens can emit what the child did and let
/// one engine decide how Hari + Pico respond.
enum ExperienceEvent {
  bubblePopped,
  sandDrawn,
  musicStarted,
  correctAnswer,
  incorrectAnswer,
  gameCompleted,
  calmStarted,
  aacSelected,
  routineCompleted,
}

class CompanionEventNotification extends Notification {
  const CompanionEventNotification(this.event);

  final ExperienceEvent event;
}

class _CompanionBeat {
  const _CompanionBeat(this.reaction, this.durationMs, {this.bounce = true});

  final CompanionReaction reaction;
  final int durationMs;
  final bool bounce;
}

CompanionReaction reactionForToyIdle(String toyId) {
  final id = toyId.toLowerCase();
  if (id.contains('music')) return CompanionReaction.dance;
  if (id.contains('calm') || id.contains('sand') || id.contains('water')) {
    return CompanionReaction.calm;
  }
  if (id.contains('draw') || id.contains('paint') || id.contains('color')) {
    return CompanionReaction.curious;
  }
  if (id.contains('bubble') || id.contains('particle')) {
    return CompanionReaction.excited;
  }
  return CompanionReaction.curious;
}

CompanionReaction reactionForToyTap(String toyId) {
  final id = toyId.toLowerCase();
  if (id.contains('music')) return CompanionReaction.dance;
  if (id.contains('bubble') || id.contains('particle') || id.contains('fireworks')) {
    return CompanionReaction.celebrating;
  }
  if (id.contains('sand') || id.contains('water') || id.contains('calm')) {
    return CompanionReaction.soothing;
  }
  if (id.contains('draw') || id.contains('paint') || id.contains('color')) {
    return CompanionReaction.proud;
  }
  return CompanionReaction.happy;
}

ExperienceEvent eventForToyTap(String toyId) {
  final id = toyId.toLowerCase();
  if (id.contains('music')) return ExperienceEvent.musicStarted;
  if (id.contains('bubble') || id.contains('particle') || id.contains('fireworks')) {
    return ExperienceEvent.bubblePopped;
  }
  if (id.contains('sand') || id.contains('draw') || id.contains('paint') || id.contains('color')) {
    return ExperienceEvent.sandDrawn;
  }
  return ExperienceEvent.bubblePopped;
}

/// Drives a [CompanionView]. Activities call [tap]/[react]/[celebrate]/[calm]
/// as the child interacts; the companions respond and settle back to idle.
class CompanionController extends ChangeNotifier {
  CompanionReaction _reaction = CompanionReaction.idle;
  int _pulse = 0;
  int _energy = 0;
  final Map<ExperienceEvent, int> _eventCounts = <ExperienceEvent, int>{};
  DateTime? _lastSmallReactionAt;
  int _activePriority = 0;
  Timer? _revert;
  Timer? _decay;
  Timer? _priorityReset;
  final List<Timer> _scriptTimers = <Timer>[];

  CompanionReaction get reaction => _reaction;

  /// Increments on every reaction so views can trigger a one-shot bounce.
  int get pulse => _pulse;

  /// 0..6 — rises with rapid interaction, drives escalating excitement.
  int get energy => _energy;

  int eventCount(ExperienceEvent event) => _eventCounts[event] ?? 0;

  // --- Milestone celebration signal ---------------------------------------
  // When a meaningful moment happens (a milestone or a win) the companions
  // flash a short, unmistakable celebration: a floating gesture emoji + label
  // and a celebration sound. This is what makes milestones *noticeable*.
  String? _celebration;
  String? _celebrationEmoji;
  int _celebrationPulse = 0;

  String? get celebration => _celebration;
  String? get celebrationEmoji => _celebrationEmoji;
  int get celebrationPulse => _celebrationPulse;

  void _flashCelebration(String label, String emoji, SoundCue? cue) {
    _celebration = label;
    _celebrationEmoji = emoji;
    _celebrationPulse++;
    // A null cue means "show the visual reaction only" — used for the frequent
    // small milestones so the companion feels alive without chirping over the
    // toy's own sound on every few taps.
    if (cue != null) TonePlayer.instance.playCue(cue);
    notifyListeners();
  }

  void _setNow(CompanionReaction r, {bool bounce = true}) {
    _reaction = r;
    if (bounce) _pulse++;
    notifyListeners();
  }

  void _clearScriptTimers() {
    for (final t in _scriptTimers) {
      t.cancel();
    }
    _scriptTimers.clear();
  }

  void _startSequence(
    List<_CompanionBeat> beats, {
    CompanionReaction settle = CompanionReaction.idle,
    int priority = 2,
  }) {
    if (priority < _activePriority) return;
    _activePriority = priority;
    _priorityReset?.cancel();
    _clearScriptTimers();
    _revert?.cancel();
    if (beats.isEmpty) return;
    _setNow(beats.first.reaction, bounce: beats.first.bounce);
    var elapsedMs = beats.first.durationMs;
    for (final beat in beats.skip(1)) {
      final at = elapsedMs;
      _scriptTimers.add(Timer(Duration(milliseconds: at), () {
        _setNow(beat.reaction, bounce: beat.bounce);
      }));
      elapsedMs += beat.durationMs;
    }
    _scriptTimers.add(Timer(Duration(milliseconds: elapsedMs), () {
      _reaction = _energy > 0 ? CompanionReaction.happy : settle;
      _activePriority = 0;
      notifyListeners();
    }));
    _priorityReset = Timer(Duration(milliseconds: elapsedMs + 50), () {
      _activePriority = 0;
    });
  }

  void react(
    CompanionReaction r, {
    Duration hold = const Duration(milliseconds: 1500),
    bool bounce = true,
    int priority = 1,
  }) {
    if (priority < _activePriority) return;
    _activePriority = priority;
    _clearScriptTimers();
    _setNow(r, bounce: bounce);
    _revert?.cancel();
    _revert = Timer(hold, () {
      _reaction =
          _energy > 0 ? CompanionReaction.happy : CompanionReaction.idle;
      _activePriority = 0;
      notifyListeners();
    });
  }

  /// Generic "the child did something" — escalates energy into excitement.
  void tap() {
    _energy = math.min(_energy + 1, 6);
    final now = DateTime.now();
    final canReact = _lastSmallReactionAt == null ||
        now.difference(_lastSmallReactionAt!) >=
            const Duration(milliseconds: 450);
    if (canReact && _activePriority == 0) {
      _lastSmallReactionAt = now;
      react(
        _energy >= 3 ? CompanionReaction.happy : CompanionReaction.curious,
        hold: const Duration(milliseconds: 520),
        bounce: false,
      );
    }
    _decay?.cancel();
    _decay = Timer(const Duration(milliseconds: 2600), () {
      _energy = 0;
      _reaction = CompanionReaction.idle;
      notifyListeners();
    });
  }

  void celebrate() {
    _startSequence(<_CompanionBeat>[
      const _CompanionBeat(CompanionReaction.excited, 260),
      const _CompanionBeat(CompanionReaction.celebrating, 760),
      const _CompanionBeat(CompanionReaction.happy, 520, bounce: false),
    ], settle: CompanionReaction.happy, priority: 3);
  }

  void pair() {
    _startSequence(<_CompanionBeat>[
      const _CompanionBeat(CompanionReaction.curious, 180, bounce: false),
      const _CompanionBeat(CompanionReaction.pair, 600),
      const _CompanionBeat(CompanionReaction.happy, 500, bounce: false),
    ], settle: CompanionReaction.happy, priority: 3);
  }

  void dance() {
    _startSequence(<_CompanionBeat>[
      const _CompanionBeat(CompanionReaction.curious, 180, bounce: false),
      const _CompanionBeat(CompanionReaction.dance, 900),
      const _CompanionBeat(CompanionReaction.celebrating, 560),
      const _CompanionBeat(CompanionReaction.happy, 540, bounce: false),
    ], settle: CompanionReaction.happy, priority: 3);
  }

  void encourage() {
    _startSequence(<_CompanionBeat>[
      const _CompanionBeat(CompanionReaction.curious, 120, bounce: false),
      const _CompanionBeat(CompanionReaction.encouraging, 520),
      const _CompanionBeat(CompanionReaction.happy, 420, bounce: false),
    ], settle: CompanionReaction.happy);
  }

  void reactToToyTap(String toyId) {
    reactToEvent(eventForToyTap(toyId), toyId: toyId);
  }

  void reactToEvent(ExperienceEvent event, {String? toyId}) {
    final count = (_eventCounts[event] ?? 0) + 1;
    _eventCounts[event] = count;
    switch (event) {
      case ExperienceEvent.bubblePopped:
        if (count % 50 == 0) {
          celebrate();
          _flashCelebration('WOW!', '🎉', SoundCue.completion);
        } else if (count % 25 == 0) {
          dance();
          _flashCelebration("Let's dance!", '💃', SoundCue.milestone);
        } else if (count % 10 == 0) {
          pair();
          // Visual-only: a high five every 10 taps shouldn't add a chirp on
          // top of the toy's own sound.
          _flashCelebration('High five!', '🙌', null);
        } else if (count % 5 == 0) {
          _startSequence(<_CompanionBeat>[
            const _CompanionBeat(CompanionReaction.proud, 720),
            const _CompanionBeat(
                CompanionReaction.happy, 420, bounce: false),
          ], settle: CompanionReaction.happy, priority: 3);
          // Visual-only reaction — no sound on the frequent small milestone.
          _flashCelebration('Nice!', '👍', null);
        } else {
          tap();
        }
        return;
      case ExperienceEvent.sandDrawn:
        if (count % 12 == 0) {
          _startSequence(<_CompanionBeat>[
            const _CompanionBeat(CompanionReaction.thinking, 180, bounce: false),
            const _CompanionBeat(CompanionReaction.proud, 560),
            const _CompanionBeat(CompanionReaction.happy, 420, bounce: false),
          ], settle: CompanionReaction.happy, priority: 3);
        } else {
          tap();
        }
        return;
      case ExperienceEvent.musicStarted:
        if (toyId?.toLowerCase().contains('music') ?? false) {
          if (count % 8 == 0) {
            dance();
          } else {
            tap();
          }
        } else {
          dance();
        }
        return;
      case ExperienceEvent.correctAnswer:
        react(CompanionReaction.happy,
            hold: const Duration(milliseconds: 900), bounce: false);
        return;
      case ExperienceEvent.incorrectAnswer:
        encourage();
        return;
      case ExperienceEvent.gameCompleted:
        celebrate();
        _flashCelebration('You did it!', '🎉', SoundCue.completion);
        return;
      case ExperienceEvent.calmStarted:
        calm();
        return;
      case ExperienceEvent.aacSelected:
        tap();
        return;
      case ExperienceEvent.routineCompleted:
        _startSequence(<_CompanionBeat>[
          const _CompanionBeat(CompanionReaction.proud, 460),
          const _CompanionBeat(CompanionReaction.celebrating, 700),
          const _CompanionBeat(CompanionReaction.happy, 420, bounce: false),
        ], settle: CompanionReaction.happy);
        _flashCelebration('Amazing!', '⭐', SoundCue.completion);
        return;
    }
  }

  void calm() {
    _energy = 0;
    _startSequence(<_CompanionBeat>[
      const _CompanionBeat(CompanionReaction.soothing, 480, bounce: false),
      const _CompanionBeat(CompanionReaction.calm, 920, bounce: false),
    ], settle: CompanionReaction.calm);
  }

  void setReaction(CompanionReaction r) {
    _clearScriptTimers();
    _revert?.cancel();
    _decay?.cancel();
    _reaction = r;
    notifyListeners();
  }

  @override
  void dispose() {
    _clearScriptTimers();
    _revert?.cancel();
    _decay?.cancel();
    _priorityReset?.cancel();
    _activePriority = 0;
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
    case CompanionReaction.pair:
      return (hari: AvatarEmotion.kind, pico: PicoMood.comforting);
    case CompanionReaction.dance:
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
  late final AnimationController _banner;
  int _lastPulse = 0;
  int _lastCelebration = 0;
  String? _bannerLabel;
  String? _bannerEmoji;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 560));
    _banner = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    if (widget.animate) _idle.repeat();
    widget.controller.addListener(_onReaction);
  }

  void _onReaction() {
    if (widget.controller.pulse != _lastPulse) {
      _lastPulse = widget.controller.pulse;
      if (widget.animate) _bounce.forward(from: 0);
    }
    if (widget.controller.celebrationPulse != _lastCelebration) {
      _lastCelebration = widget.controller.celebrationPulse;
      _bannerLabel = widget.controller.celebration;
      _bannerEmoji = widget.controller.celebrationEmoji;
      if (widget.animate) _banner.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onReaction);
    _idle.dispose();
    _bounce.dispose();
    _banner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = _mapReaction(widget.controller.reaction);
    final celebrating =
      widget.controller.reaction == CompanionReaction.celebrating ||
        widget.controller.reaction == CompanionReaction.dance;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_idle, _bounce, _banner]),
      builder: (context, _) {
        final t = _idle.value;
        final bob = math.sin(t * math.pi * 2) * 4.0;
        final hariBob = math.sin((t + 0.12) * math.pi * 2) * 2.8;
        final picoBob = math.sin((t + 0.53) * math.pi * 2) * 3.6;
        final hariSide = math.sin((t + 0.08) * math.pi * 2) * 1.4;
        final picoSide = math.sin((t + 0.71) * math.pi * 2) * 1.9;
        final dance = widget.controller.reaction == CompanionReaction.dance;
        final pair = widget.controller.reaction == CompanionReaction.pair;
        final reaction = widget.controller.reaction;
        final phase = (t * 4).floor() % 4;
        final hariPose = dance
          ? (<AvatarPose>[
              AvatarPose.clap,
              AvatarPose.wave,
              AvatarPose.cheer,
              AvatarPose.point,
            ][phase])
          : pair
            ? AvatarPose.point
            : reaction == CompanionReaction.encouraging
              ? AvatarPose.point
              : reaction == CompanionReaction.proud
                ? AvatarPose.clap
                : reaction == CompanionReaction.surprised
                  ? AvatarPose.wave
                  : reaction == CompanionReaction.thinking ||
                      reaction == CompanionReaction.curious
                    ? AvatarPose.think
                    : reaction == CompanionReaction.calm ||
                        reaction == CompanionReaction.soothing
                      ? AvatarPose.breathe
                      : reaction == CompanionReaction.sleepy
                        ? AvatarPose.sleep
                        : reaction == CompanionReaction.excited
                          ? AvatarPose.wave
                          : reaction ==
                              CompanionReaction.celebrating
                            ? AvatarPose.cheer
                            : AvatarPose.idle;
        final danceScaleHari = dance ? 1.07 + math.sin(t * math.pi * 8) * 0.05 : 1.0;
        final danceScalePico = dance ? 1.06 + math.sin((t + 0.35) * math.pi * 7) * 0.06 : 1.0;
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
                    if (celebrating) Positioned.fill(child: _Sparkles(t: t)),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Transform.translate(
                        offset: Offset(hariSide, hariBob),
                        child: SizedBox(
                          width: w * 0.62,
                          height: h * 0.9,
                          child: Transform.scale(
                            scale: danceScaleHari,
                            alignment: Alignment.bottomCenter,
                            child: Hari(
                              config: AvatarConfig.hari,
                              emotion: map.hari,
                              pose: hariPose,
                              animate: widget.animate,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.showPico)
                      Align(
                        alignment:
                            pair ? const Alignment(-0.86, 1.0) : const Alignment(-0.88, 1.0),
                        child: Transform.translate(
                          offset: Offset(picoSide, picoBob),
                          child: SizedBox(
                            width: w * 0.42,
                            height: h * 0.56,
                            child: Transform.scale(
                              scale: danceScalePico,
                              alignment: Alignment.bottomCenter,
                              child: PicoWidget(
                                mood: map.pico,
                                animate: widget.animate,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_banner.value > 0 && _bannerEmoji != null)
                      Positioned(
                        top: -8,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: _CelebrationBanner(
                            progress: _banner.value,
                            emoji: _bannerEmoji!,
                            label: _bannerLabel ?? '',
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

/// A short-lived floating gesture badge (e.g. 👏 "High five!") shown when a
/// milestone or win happens, so the celebration is impossible to miss.
class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner({
    required this.progress,
    required this.emoji,
    required this.label,
  });

  final double progress;
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Fade in over the first 18%, hold, then fade out over the last 30%.
    final opacity = progress < 0.18
        ? progress / 0.18
        : progress > 0.7
            ? (1 - (progress - 0.7) / 0.3).clamp(0.0, 1.0)
            : 1.0;
    final rise = -18.0 * Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final pop = 0.7 + 0.3 * Curves.elasticOut.transform(progress.clamp(0.0, 1.0));
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, rise),
        child: Transform.scale(
          scale: pop,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 30)),
              if (label.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
