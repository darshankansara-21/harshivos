import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';

/// Visual Schedule / Daily Routine — the #1 evidence-based autism support.
///
/// A calm, visual-first list of routine steps. Predictability lowers anxiety,
/// so every step is a big emoji + one short word. Tapping a step marks it
/// done; the first not-done step is the live "NOW" step. There are no fail
/// states — only gentle forward motion and a warm celebration at the end.
class VisualScheduleScreen extends StatefulWidget {
  const VisualScheduleScreen({super.key});

  @override
  State<VisualScheduleScreen> createState() => _VisualScheduleScreenState();
}

class _VisualScheduleScreenState extends State<VisualScheduleScreen>
    with TickerProviderStateMixin {
  // ----- Data -----------------------------------------------------------
  static const List<_Step> _steps = <_Step>[
    _Step('🌅', 'Wake up', Color(0xFFFFB74D)),
    _Step('🪥', 'Brush teeth', Color(0xFF4DD0E1)),
    _Step('👕', 'Get dressed', Color(0xFF9575CD)),
    _Step('🍳', 'Breakfast', Color(0xFFFF8A65)),
    _Step('🎒', 'School', Color(0xFF4FC3F7)),
    _Step('🥪', 'Lunch', Color(0xFFAED581)),
    _Step('🎨', 'Play', Color(0xFFF06292)),
    _Step('🛁', 'Bath', Color(0xFF4DB6AC)),
    _Step('📚', 'Story', Color(0xFFBA68C8)),
    _Step('😴', 'Sleep', Color(0xFF7986CB)),
  ];

  late final List<bool> _done =
      List<bool>.filled(_steps.length, false, growable: false);

  // ----- Animations -----------------------------------------------------
  // Drives the progress bar smoothly toward the real completion ratio.
  late final AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  double _progressFrom = 0;

  // Continuous pulse for the live "NOW" glow ring.
  late final AnimationController _pulseCtrl;

  // One-shot bloom when the whole day is finished.
  late final AnimationController _celebrateCtrl;

  // Per-step tap pop (scale punch on the check circle).
  final Map<int, AnimationController> _popCtrls = <int, AnimationController>{};

  int get _doneCount => _done.where((bool d) => d).length;

  bool get _allDone => _doneCount == _steps.length;

  /// Index of the first not-done step, or -1 when everything is complete.
  int get _nowIndex => _done.indexWhere((bool d) => !d);

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnim = const AlwaysStoppedAnimation<double>(0);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _celebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    _celebrateCtrl.dispose();
    for (final AnimationController c in _popCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ----- Behaviour ------------------------------------------------------
  void _animateProgressTo(double target) {
    _progressFrom = _progressAnim.value;
    _progressAnim = Tween<double>(begin: _progressFrom, end: target).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic),
    );
    _progressCtrl
      ..stop()
      ..value = 0
      ..forward();
  }

  AnimationController _popControllerFor(int index) {
    return _popCtrls.putIfAbsent(
      index,
      () => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 360),
      ),
    );
  }

  void _toggle(int index) {
    final bool willBeDone = !_done[index];
    setState(() => _done[index] = willBeDone);

    if (willBeDone) {
      HapticFeedback.mediumImpact();
      final AnimationController pop = _popControllerFor(index);
      pop
        ..stop()
        ..forward(from: 0);
      // A soft second tap a beat later = the "satisfying again" haptic.
      Future<void>.delayed(const Duration(milliseconds: 90), () {
        if (mounted) HapticFeedback.lightImpact();
      });
    } else {
      HapticFeedback.selectionClick();
    }

    _animateProgressTo(_doneCount / _steps.length);

    if (_allDone) {
      HapticFeedback.heavyImpact();
      _celebrateCtrl.forward(from: 0);
    } else if (_celebrateCtrl.value != 0) {
      _celebrateCtrl.reverse();
    }
  }

  void _resetDay() {
    if (_doneCount == 0) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      for (int i = 0; i < _done.length; i++) {
        _done[i] = false;
      }
    });
    _celebrateCtrl.reverse();
    _animateProgressTo(0);
  }

  // ----- UI -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final int nowIndex = _nowIndex;

    return HarshivScaffold(
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(),
              const SizedBox(height: 16),
              _buildProgress(),
              const SizedBox(height: 16),
              Expanded(
                child: _allDone
                    ? _buildCelebration()
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _steps.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 14),
                        itemBuilder: (BuildContext context, int i) {
                          return _buildStepCard(
                            i,
                            isNow: i == nowIndex,
                            isNext: i == nowIndex + 1,
                          );
                        },
                      ),
              ),
            ],
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: _buildResetButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 4),
        const Text(
          'My Day',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (BuildContext context, _) {
          final double value = _progressAnim.value.clamp(0.0, 1.0);
          final int shown = (value * _steps.length).round();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'My progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$shown of ${_steps.length} done',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  return Stack(
                    children: <Widget>[
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Container(
                        height: 16,
                        width: c.maxWidth * value,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFF4FC3F7),
                              Color(0xFF66E0A3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF66E0A3)
                                  .withOpacity(0.45),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepCard(int index, {required bool isNow, required bool isNext}) {
    final _Step step = _steps[index];
    final bool done = _done[index];
    final AnimationController pop = _popControllerFor(index);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_pulseCtrl, pop]),
      builder: (BuildContext context, Widget? child) {
        final double pulse = isNow
            ? 0.5 + 0.5 * math.sin(_pulseCtrl.value * math.pi)
            : 0.0;
        final Color glow = isNow
            ? Color.lerp(step.color, Colors.white, 0.2)!
            : step.color;

        return GlassCard(
          onTap: () => _toggle(index),
          glowColor: glow,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          gradient: isNow
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    step.color.withOpacity(0.22),
                    step.color.withOpacity(0.06),
                  ],
                )
              : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: isNow
                  ? <BoxShadow>[
                      BoxShadow(
                        color: glow.withOpacity(0.18 + 0.22 * pulse),
                        blurRadius: 18 + 12 * pulse,
                        spreadRadius: 1,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Row(
              children: <Widget>[
                _buildEmojiCircle(step, done: done, isNow: isNow, pulse: pulse),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isNow) _buildNowBadge(step),
                      if (isNow) const SizedBox(height: 6),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          color: Colors.white.withOpacity(done ? 0.45 : 1.0),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: Colors.white.withOpacity(0.6),
                          decorationThickness: 2.5,
                        ),
                        child: Text(step.label),
                      ),
                      if (isNext && !done)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'next',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildCheck(step, done: done, pop: pop.value),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmojiCircle(
    _Step step, {
    required bool done,
    required bool isNow,
    required double pulse,
  }) {
    final double ring = isNow ? 2.0 + 2.0 * pulse : 0.0;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: done ? 0.5 : 1.0,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              step.color.withOpacity(0.55),
              step.color.withOpacity(0.28),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(isNow ? 0.9 : 0.35),
            width: isNow ? ring : 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: Text(step.emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  Widget _buildNowBadge(_Step step) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'NOW',
        style: TextStyle(
          color: Color.lerp(step.color, Colors.black, 0.35)!,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCheck(_Step step, {required bool done, required double pop}) {
    // pop animates 0->1; turn it into a gentle overshoot punch.
    final double punch =
        done ? 1.0 + 0.28 * math.sin(pop * math.pi) : 1.0;
    return Transform.scale(
      scale: punch,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? step.color.withOpacity(0.95) : Colors.transparent,
          border: Border.all(
            color: done ? step.color : Colors.white.withOpacity(0.5),
            width: 2.4,
          ),
          boxShadow: done
              ? <BoxShadow>[
                  BoxShadow(
                    color: step.color.withOpacity(0.5),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: done ? 1.0 : 0.0,
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildCelebration() {
    final Animation<double> scale = CurvedAnimation(
      parent: _celebrateCtrl,
      curve: Curves.easeOutBack,
    );
    final Animation<double> fade = CurvedAnimation(
      parent: _celebrateCtrl,
      curve: Curves.easeOut,
    );
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(scale),
            child: GlassCard(
              glowColor: const Color(0xFF66E0A3),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF4FC3F7).withOpacity(0.22),
                  const Color(0xFF66E0A3).withOpacity(0.10),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (BuildContext context, Widget? child) {
                      final double s =
                          1.0 + 0.06 * math.sin(_pulseCtrl.value * math.pi);
                      return Transform.scale(scale: s, child: child);
                    },
                    child: const Text('🎉', style: TextStyle(fontSize: 84)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'All done!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Great job!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildCelebrateReset(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrateReset() {
    return GlassCard(
      onTap: _resetDay,
      glowColor: const Color(0xFF4FC3F7),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
          SizedBox(width: 10),
          Text(
            'New day',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    if (_allDone) return const SizedBox.shrink();
    return GlassCard(
      onTap: _resetDay,
      glowColor: const Color(0xFFFF8A65),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.restart_alt_rounded, color: Colors.white, size: 24),
          SizedBox(width: 8),
          Text(
            'Reset',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single immutable routine step: big emoji + one short word + a colour.
class _Step {
  const _Step(this.emoji, this.label, this.color);

  final String emoji;
  final String label;
  final Color color;
}
