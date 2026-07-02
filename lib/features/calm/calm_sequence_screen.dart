import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/regulation_entry.dart';
import '../../state/providers.dart';
import '../play/toys/toys_particles.dart';
import '../play/toys/toys_water.dart';
import 'breathing_exercise.dart';

/// One timed step in a calm-down sequence.
class _Step {
  const _Step(this.label, this.seconds, this.builder);
  final String label;
  final int seconds;
  final WidgetBuilder builder;
}

/// An AI-personalised calm-down sequence: breathing → ripples → galaxy →
/// outcome check-in. The session is logged for the Regulation Genome.
class CalmSequenceScreen extends ConsumerStatefulWidget {
  const CalmSequenceScreen({super.key, required this.mood});

  final CalmMood mood;

  @override
  ConsumerState<CalmSequenceScreen> createState() => _CalmSequenceScreenState();
}

class _CalmSequenceScreenState extends ConsumerState<CalmSequenceScreen> {
  late final List<_Step> _steps;
  int _index = 0;
  int _remaining = 0;
  Timer? _timer;
  bool _finished = false;

  static const Map<CalmMood, double> _calmBefore = <CalmMood, double>{
    CalmMood.overwhelmed: 0.10,
    CalmMood.frustrated: 0.20,
    CalmMood.sad: 0.25,
    CalmMood.anxious: 0.18,
    CalmMood.tired: 0.35,
  };

  @override
  void initState() {
    super.initState();
    _steps = <_Step>[
      _Step('Breathe with the bubble', 30, (_) => const BreathingExercise()),
      _Step('Soft water ripples', 60, (_) => const WaterRipplesToy()),
      _Step('Drift through the galaxy', 90, (_) => const ParticleGalaxyToy()),
    ];
    _startStep();
  }

  void _startStep() {
    _remaining = _steps[_index].seconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) _next();
      });
    });
  }

  void _next() {
    _timer?.cancel();
    if (_index < _steps.length - 1) {
      setState(() {
        _index++;
        _startStep();
      });
    } else {
      setState(() => _finished = true);
    }
  }

  void _complete(double calmAfter) {
    ref.read(regulationLogProvider.notifier).logSession(
      toyIds: <String>['water_ripples', 'particle_galaxy'],
      mood: widget.mood,
      calmBefore: _calmBefore[widget.mood] ?? 0.2,
      calmAfter: calmAfter,
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return _OutcomeCheckIn(onDone: _complete);
    }
    final step = _steps[_index];
    final progress = 1 - (_remaining / step.seconds);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: step.builder(context)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _glassPill(Text('${widget.mood.emoji}  ${step.label}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                      const Spacer(),
                      _glassPill(Text('0:${_remaining.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _next,
                    child: Text(
                      _index < _steps.length - 1 ? 'Next →' : 'I feel calmer',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassPill(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

/// A gentle face-based outcome check after a calm sequence.
class _OutcomeCheckIn extends StatelessWidget {
  const _OutcomeCheckIn({required this.onDone});
  final void Function(double calmAfter) onDone;

  @override
  Widget build(BuildContext context) {
    const faces = <(String, double)>[
      ('😣', 0.2),
      ('😐', 0.45),
      ('🙂', 0.7),
      ('😊', 0.9),
      ('🤩', 1.0),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF101830),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('How do you feel now?',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('There is no wrong answer.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 40),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (final f in faces)
                    GestureDetector(
                      onTap: () => onDone(f.$2),
                      child: Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(f.$1, style: const TextStyle(fontSize: 40)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
