import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';

/// A calm, visual-first countdown timer (in the spirit of a Time Timer).
///
/// A large coloured wedge depletes smoothly as time passes, with the remaining
/// time shown big in the centre. The colour drifts gently green → amber → soft
/// red so the *passage of time is felt visually*, never announced with a
/// jarring alarm. When it finishes the whole screen breathes a few soft glow
/// pulses with a light haptic pattern and a calm "All done" message.
class VisualTimerScreen extends StatefulWidget {
  const VisualTimerScreen({super.key});

  @override
  State<VisualTimerScreen> createState() => _VisualTimerScreenState();
}

class _VisualTimerScreenState extends State<VisualTimerScreen>
    with TickerProviderStateMixin {
  /// Selectable presets (label + total seconds).
  static const List<_Preset> _presets = <_Preset>[
    _Preset('30s', 30),
    _Preset('1 min', 60),
    _Preset('2 min', 120),
    _Preset('5 min', 300),
    _Preset('10 min', 600),
  ];

  // The currently chosen total duration and how much time is left.
  int _totalSeconds = 120;
  double _remaining = 120;

  bool _running = false;
  bool _finished = false;

  // Drives the per-frame wedge depletion while running.
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // Drives the gentle full-screen glow pulse on completion.
  late final AnimationController _finishPulse;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _finishPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _finishPulse.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_running) {
      _lastTick = elapsed;
      return;
    }
    final double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    final double next = _remaining - dt;
    if (next <= 0) {
      setState(() {
        _remaining = 0;
        _running = false;
      });
      _ticker.stop();
      _onFinished();
    } else {
      setState(() => _remaining = next);
    }
  }

  void _selectPreset(int seconds) {
    HapticFeedback.selectionClick();
    setState(() {
      _totalSeconds = seconds;
      _remaining = seconds.toDouble();
      _running = false;
      _finished = false;
    });
    _ticker.stop();
    _finishPulse.stop();
    _finishPulse.value = 0;
  }

  void _toggleRunPause() {
    if (_finished || _remaining <= 0) return;
    HapticFeedback.mediumImpact();
    setState(() => _running = !_running);
    if (_running) {
      _finished = false;
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    }
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _remaining = _totalSeconds.toDouble();
      _running = false;
      _finished = false;
    });
    _ticker.stop();
    _finishPulse.stop();
    _finishPulse.value = 0;
  }

  Future<void> _onFinished() async {
    if (!mounted) return;
    setState(() => _finished = true);
    // Three gentle pulses of light.
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      await _finishPulse.forward(from: 0);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  // 0.0 at the start, 1.0 when time has fully elapsed.
  double get _progress {
    if (_totalSeconds <= 0) return 0;
    return (1 - _remaining / _totalSeconds).clamp(0.0, 1.0);
  }

  /// Calm green → amber → soft red as the timer nears the end.
  Color get _wedgeColor {
    const Color green = Color(0xFF4ADE80);
    const Color amber = Color(0xFFFBBF24);
    const Color softRed = Color(0xFFFB7185);
    final double t = _progress;
    if (t < 0.5) {
      return Color.lerp(green, amber, t / 0.5)!;
    }
    return Color.lerp(amber, softRed, (t - 0.5) / 0.5)!;
  }

  String _formatTime(double seconds) {
    final int total = seconds.ceil();
    final int m = total ~/ 60;
    final int s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 8),
                      _buildDial(),
                      const SizedBox(height: 24),
                      _buildPresets(),
                      const SizedBox(height: 20),
                      _buildControls(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildFinishGlow(),
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
          'Timer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDial() {
    final Color wedge = _wedgeColor;
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: AnimatedBuilder(
          animation: _finishPulse,
          builder: (BuildContext context, Widget? child) {
            final double glow = _finished
                ? (math.sin(_finishPulse.value * math.pi) * 0.6)
                : 0.0;
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: wedge.withOpacity(0.30 + glow * 0.5),
                    blurRadius: 48 + glow * 40,
                    spreadRadius: 2 + glow * 10,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: CustomPaint(
            painter: _TimerDialPainter(
              progress: _progress,
              wedgeColor: wedge,
            ),
            child: Center(child: _buildCenterLabel()),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterLabel() {
    if (_finished) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('🌟', style: TextStyle(fontSize: 40)),
          SizedBox(height: 6),
          Text(
            'All done',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          _formatTime(_remaining),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 58,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _running ? 'remaining' : (_remaining <= 0 ? '' : 'paused'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPresets() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: _presets.map((_Preset p) {
        final bool selected = p.seconds == _totalSeconds;
        return _PresetChip(
          label: p.label,
          selected: selected,
          onTap: () => _selectPreset(p.seconds),
        );
      }).toList(),
    );
  }

  Widget _buildControls() {
    final bool canRun = _remaining > 0 && !_finished;
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: GlassCard(
            onTap: canRun ? _toggleRunPause : null,
            glowColor: _running ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80),
            gradient: LinearGradient(
              colors: <Color>[
                (_running ? const Color(0xFFFBBF24) : const Color(0xFF4ADE80))
                    .withOpacity(0.28),
                (_running ? const Color(0xFFF59E0B) : const Color(0xFF22C55E))
                    .withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Text(
                  _running ? 'Pause' : 'Start',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 1,
          child: GlassCard(
            onTap: _reset,
            glowColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.refresh_rounded, color: Colors.white, size: 26),
                SizedBox(width: 8),
                Text(
                  'Reset',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinishGlow() {
    if (!_finished) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _finishPulse,
        builder: (BuildContext context, Widget? child) {
          final double v = math.sin(_finishPulse.value * math.pi);
          return Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFF4ADE80).withOpacity(0.16 * v),
                    Colors.transparent,
                  ],
                  radius: 1.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Immutable preset descriptor.
class _Preset {
  const _Preset(this.label, this.seconds);
  final String label;
  final int seconds;
}

/// A selectable duration chip with a calm selected/idle visual state.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      glowColor: const Color(0xFF60A5FA),
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      gradient: selected
          ? LinearGradient(
              colors: <Color>[
                const Color(0xFF60A5FA).withOpacity(0.34),
                const Color(0xFF3B82F6).withOpacity(0.16),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(selected ? 1 : 0.8),
          fontSize: 18,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

/// Paints the depleting Time-Timer wedge plus a calm track and a clean rim.
class _TimerDialPainter extends CustomPainter {
  _TimerDialPainter({
    required this.progress,
    required this.wedgeColor,
  });

  /// 0.0 → full wedge remaining, 1.0 → wedge fully depleted.
  final double progress;
  final Color wedgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius - 10);

    // Soft background disc.
    final Paint disc = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 4, disc);

    // Remaining wedge — depletes clockwise from the top (12 o'clock).
    final double sweep = (1 - progress).clamp(0.0, 1.0) * 2 * math.pi;
    if (sweep > 0) {
      final Paint wedge = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + 2 * math.pi,
          colors: <Color>[
            wedgeColor.withOpacity(0.95),
            wedgeColor.withOpacity(0.70),
          ],
          stops: const <double>[0.0, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, -math.pi / 2, sweep, true, wedge);
    }

    // Tick marks around the rim for a clock-like, readable feel.
    final Paint tick = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final double a = -math.pi / 2 + i * (2 * math.pi / 12);
      final double inner = radius - 14;
      final double outer = radius - 6;
      final Offset p1 = center + Offset(math.cos(a) * inner, math.sin(a) * inner);
      final Offset p2 = center + Offset(math.cos(a) * outer, math.sin(a) * outer);
      canvas.drawLine(p1, p2, tick);
    }

    // Clean outer rim.
    final Paint rim = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 4, rim);
  }

  @override
  bool shouldRepaint(_TimerDialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.wedgeColor != wedgeColor;
  }
}
