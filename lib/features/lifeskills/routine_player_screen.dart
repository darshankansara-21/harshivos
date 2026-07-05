import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../state/providers.dart';
import 'avatar/avatar.dart';
import 'models/life_models.dart';
import 'state/lifeskills_providers.dart';

/// Plays a [LifeRoutine] as a warm, avatar-guided, narrated sequence:
/// a cover → one big visual step at a time → a completion celebration.
class RoutinePlayerScreen extends ConsumerStatefulWidget {
  const RoutinePlayerScreen({super.key, required this.routine});
  final LifeRoutine routine;

  @override
  ConsumerState<RoutinePlayerScreen> createState() =>
      _RoutinePlayerScreenState();
}

class _RoutinePlayerScreenState extends ConsumerState<RoutinePlayerScreen>
    with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  late final AnimationController _timer;
  int _index = -1; // -1 cover, 0..n steps, n done
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(vsync: this);
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.44);
      await _tts.setPitch(1.06);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer.dispose();
    _tts.stop();
    super.dispose();
  }

  List<RoutineStep> get _steps => widget.routine.steps;

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void _start() {
    setState(() => _index = 0);
    _onEnterStep();
  }

  void _onEnterStep() {
    final step = _steps[_index];
    _speak(step.instruction);
    _timer.stop();
    _timer.reset();
    if (step.kind == StepKind.timer && step.timerSeconds != null) {
      _timer.duration = Duration(seconds: step.timerSeconds!);
      _timer.forward();
    }
  }

  void _next() {
    HapticFeedback.mediumImpact();
    if (_index >= _steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _index++);
    _onEnterStep();
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_index <= 0) {
      setState(() => _index = -1);
      _tts.stop();
      return;
    }
    setState(() => _index--);
    _onEnterStep();
  }

  void _finish() {
    setState(() => _index = _steps.length);
    if (!_completed) {
      _completed = true;
      ref.read(lifeProgressProvider.notifier).markComplete(widget.routine.id);
      // Capture a proud moment in the Success Binder / My Wins.
      ref.read(winsProvider.notifier).recordRoutineWin(
            routineId: widget.routine.id,
            title: widget.routine.title,
            emoji: widget.routine.emoji,
            accent: widget.routine.gradient.isNotEmpty
                ? widget.routine.gradient.first
                : const Color(0xFFFFD166),
          );
    }
    final name = ref.read(childNameProvider);
    _speak('You did it, $name! Amazing job!');
  }

  void _restart() {
    HapticFeedback.mediumImpact();
    setState(() {
      _index = 0;
      _completed = false;
    });
    _onEnterStep();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(avatarConfigProvider);
    final name = ref.watch(childNameProvider);
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _bgColors(),
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _buildPhase(config, name),
          ),
        ),
      ),
    );
  }

  List<Color> _bgColors() {
    if (_index < 0 || _index >= _steps.length) {
      return <Color>[
        widget.routine.gradient.first.withOpacity(0.55),
        const Color(0xFF0B1020),
      ];
    }
    final accent = _steps[_index].accent;
    return <Color>[accent.withOpacity(0.5), const Color(0xFF0B1020)];
  }

  Widget _buildPhase(AvatarConfig config, String name) {
    if (_index < 0) return _cover(config, key: const ValueKey('cover'));
    if (_index >= _steps.length) {
      return _done(config, name, key: const ValueKey('done'));
    }
    return _stepView(config, key: ValueKey('step$_index'));
  }

  // ---- Cover ----
  Widget _cover(AvatarConfig config, {required Key key}) {
    final r = widget.routine;
    return Column(
      key: key,
      children: <Widget>[
        _TopBar(onBack: () => Navigator.of(context).pop()),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(r.emoji, style: const TextStyle(fontSize: 96)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  width: 150,
                  child: AvatarWidget(config: config, pose: AvatarPose.wave),
                ),
                const SizedBox(height: 12),
                Text(r.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('${r.steps.length} easy steps',
                    style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: _BigButton(
            label: "Let's Go!",
            icon: Icons.play_arrow_rounded,
            color: widget.routine.gradient.first,
            onTap: _start,
          ),
        ),
      ],
    );
  }

  // ---- Step ----
  Widget _stepView(AvatarConfig config, {required Key key}) {
    final step = _steps[_index];
    final progress = (_index + 1) / _steps.length;
    return Column(
      key: key,
      children: <Widget>[
        _TopBar(
          onBack: _back,
          progress: progress,
          label: 'Step ${_index + 1} of ${_steps.length}',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _StepScene(step: step, config: config, timer: _timer),
                const SizedBox(height: 22),
                Text(step.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(step.instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 17)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
          child: Row(
            children: <Widget>[
              _RoundIcon(
                icon: Icons.volume_up_rounded,
                onTap: () => _speak(step.instruction),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _BigButton(
                  label: _index == _steps.length - 1 ? 'Finish' : 'Next',
                  icon: Icons.arrow_forward_rounded,
                  color: step.accent,
                  onTap: _next,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Done ----
  Widget _done(AvatarConfig config, String name, {required Key key}) {
    return Stack(
      key: key,
      children: <Widget>[
        const Positioned.fill(child: _Celebration()),
        Column(
          children: <Widget>[
            _TopBar(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('🎉', style: TextStyle(fontSize: 88)),
                    SizedBox(
                      height: 160,
                      width: 160,
                      child:
                          AvatarWidget(config: config, pose: AvatarPose.cheer),
                    ),
                    const SizedBox(height: 10),
                    Text('You did it, $name!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('${widget.routine.title} complete ⭐',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _BigButton(
                      label: 'Again',
                      icon: Icons.replay_rounded,
                      color: const Color(0xFF06D6A0),
                      onTap: _restart,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _BigButton(
                      label: 'Done',
                      icon: Icons.check_rounded,
                      color: widget.routine.gradient.first,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- scene

class _StepScene extends StatefulWidget {
  const _StepScene({required this.step, required this.config, required this.timer});
  final RoutineStep step;
  final AvatarConfig config;
  final AnimationController timer;

  @override
  State<_StepScene> createState() => _StepSceneState();
}

class _StepSceneState extends State<_StepScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            radius: 1.2,
            colors: <Color>[
              step.accent.withOpacity(0.55),
              step.accent.withOpacity(0.12),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: step.accent.withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 2),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Family photo for this step (if the parent added one), otherwise
            // a big emoji — both gently bobbing.
            AnimatedBuilder(
              animation: _bob,
              builder: (context, child) {
                final dy = math.sin(_bob.value * math.pi * 2) * 8;
                return Align(
                  alignment: const Alignment(-0.55, -0.15),
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: _StepVisual(step: step),
                  ),
                );
              },
            ),
            // Avatar demonstrating.
            Align(
              alignment: const Alignment(0.55, 0.2),
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 0.95,
                child:
                    AvatarWidget(config: widget.config, pose: step.pose),
              ),
            ),
            // Countdown ring for timer steps.
            if (step.kind == StepKind.timer && step.timerSeconds != null)
              Positioned(
                top: 14,
                right: 16,
                child: AnimatedBuilder(
                  animation: widget.timer,
                  builder: (context, _) {
                    final remaining =
                        ((1 - widget.timer.value) * step.timerSeconds!).ceil();
                    return _TimerRing(
                        progress: widget.timer.value,
                        seconds: remaining,
                        color: step.accent);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepVisual extends StatelessWidget {
  const _StepVisual({required this.step});
  final RoutineStep step;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = step.photoPath != null &&
        !kIsWeb &&
        File(step.photoPath!).existsSync();
    if (hasPhoto) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: step.accent.withOpacity(0.5),
                blurRadius: 24,
                spreadRadius: 1),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(step.photoPath!),
          width: 132,
          height: 132,
          fit: BoxFit.cover,
        ),
      );
    }
    return Text(step.emoji, style: const TextStyle(fontSize: 92));
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing(
      {required this.progress, required this.seconds, required this.color});
  final double progress;
  final int seconds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color),
        child: Center(
          child: Text('$seconds',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final bg = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(c, r, bg);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        (1 - progress) * math.pi * 2, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------- celebration

class _Celebration extends StatefulWidget {
  const _Celebration();

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(t: _c.value),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t});
  final double t;
  static const _colors = <Color>[
    Color(0xFFFFD166),
    Color(0xFFEF476F),
    Color(0xFF06D6A0),
    Color(0xFF4CC9F0),
    Color(0xFF9B5DE5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    final paint = Paint();
    for (int i = 0; i < 70; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 0.5 + rnd.nextDouble();
      final y = ((t * speed + rnd.nextDouble()) % 1.0) * size.height;
      final rot = (t * 6 + i) * (rnd.nextBool() ? 1 : -1);
      paint.color = _colors[i % _colors.length].withOpacity(0.9);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 9, height: 5),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

// ---------------------------------------------------------------- chrome

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, this.progress, this.label});
  final VoidCallback onBack;
  final double? progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 6),
      child: Row(
        children: <Widget>[
          _RoundIcon(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 14),
          if (progress != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (label != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 2),
                      child: Text(label!,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      shadowColor: color.withOpacity(0.6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Icon(icon, color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
