import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';

/// A single emotion the child can choose, with its own calm colour,
/// a gentle validating message, and a set of coping strategies that suit it.
class _Feeling {
  const _Feeling({
    required this.emoji,
    required this.label,
    required this.color,
    required this.message,
    required this.strategies,
  });

  final String emoji;
  final String label;
  final Color color;
  final String message;
  final List<_Strategy> strategies;
}

/// A coping strategy offered after a feeling is chosen.
class _Strategy {
  const _Strategy({required this.emoji, required this.label});

  final String emoji;
  final String label;
}

// Shared strategy definitions so they can be reused across feelings.
const _Strategy _breathe = _Strategy(emoji: '🌬️', label: 'Breathe');
const _Strategy _squeeze = _Strategy(emoji: '✊', label: 'Squeeze');
const _Strategy _quiet = _Strategy(emoji: '🤫', label: 'Quiet space');
const _Strategy _askHelp = _Strategy(emoji: '🙋', label: 'Ask for help');
const _Strategy _drink = _Strategy(emoji: '💧', label: 'Drink water');
const _Strategy _hug = _Strategy(emoji: '🤗', label: 'Hug');
const _Strategy _walk = _Strategy(emoji: '🚶', label: 'Walk');
const _Strategy _music = _Strategy(emoji: '🎵', label: 'Music');
const _Strategy _toy = _Strategy(emoji: '🧸', label: 'Hold toy');

const List<_Feeling> _feelings = <_Feeling>[
  _Feeling(
    emoji: '😀',
    label: 'Happy',
    color: Color(0xFFFFC93C),
    message: 'Yay! It feels good to be happy.',
    strategies: <_Strategy>[_music, _hug, _walk],
  ),
  _Feeling(
    emoji: '😢',
    label: 'Sad',
    color: Color(0xFF5AA9E6),
    message: "It's okay to feel sad. I'm here with you.",
    strategies: <_Strategy>[_hug, _askHelp, _toy],
  ),
  _Feeling(
    emoji: '😡',
    label: 'Angry',
    color: Color(0xFFFF6B6B),
    message: "It's okay to feel angry. Let's let it out gently.",
    strategies: <_Strategy>[_breathe, _squeeze, _walk],
  ),
  _Feeling(
    emoji: '😨',
    label: 'Scared',
    color: Color(0xFF9B7EDE),
    message: "You are safe. I'm right here with you.",
    strategies: <_Strategy>[_breathe, _hug, _askHelp],
  ),
  _Feeling(
    emoji: '😴',
    label: 'Tired',
    color: Color(0xFF7C8DB5),
    message: "Resting is okay. Your body needs a break.",
    strategies: <_Strategy>[_quiet, _drink, _toy],
  ),
  _Feeling(
    emoji: '😌',
    label: 'Calm',
    color: Color(0xFF6FD08C),
    message: 'Lovely. You feel calm and safe.',
    strategies: <_Strategy>[_breathe, _music, _quiet],
  ),
  _Feeling(
    emoji: '🤩',
    label: 'Excited',
    color: Color(0xFFFF9F45),
    message: 'How exciting! Big feelings can be fun.',
    strategies: <_Strategy>[_walk, _music, _breathe],
  ),
  _Feeling(
    emoji: '😟',
    label: 'Worried',
    color: Color(0xFF5FB0B7),
    message: "It's okay to feel worried. We can take it slow.",
    strategies: <_Strategy>[_breathe, _askHelp, _hug],
  ),
  _Feeling(
    emoji: '🤢',
    label: 'Yucky',
    color: Color(0xFF8FBF6F),
    message: "Feeling yucky is okay. Let's feel a little better.",
    strategies: <_Strategy>[_drink, _quiet, _askHelp],
  ),
  _Feeling(
    emoji: '😕',
    label: 'Confused',
    color: Color(0xFFC58BE0),
    message: "It's okay to feel confused. We can figure it out.",
    strategies: <_Strategy>[_askHelp, _breathe, _quiet],
  ),
];

/// Feelings check-in: a calm, visual-first screen where the child picks an
/// emotion and is offered gentle, suitable coping strategies. There are no
/// wrong choices — every feeling is welcomed and validated.
class FeelingsScreen extends StatefulWidget {
  const FeelingsScreen({super.key});

  @override
  State<FeelingsScreen> createState() => _FeelingsScreenState();
}

class _FeelingsScreenState extends State<FeelingsScreen> {
  _Feeling? _selected;

  void _selectFeeling(_Feeling feeling) {
    HapticFeedback.mediumImpact();
    setState(() => _selected = feeling);
  }

  void _backToGrid() {
    HapticFeedback.selectionClick();
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TopBar(
            onBack: _selected == null ? null : _backToGrid,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> anim) {
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                );
              },
              child: _selected == null
                  ? _FeelingsGrid(
                      key: const ValueKey<String>('grid'),
                      onSelect: _selectFeeling,
                    )
                  : _FeelingDetail(
                      key: ValueKey<String>('detail-${_selected!.label}'),
                      feeling: _selected!,
                      onChooseAnother: _backToGrid,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back button + screen title row.
class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack});

  /// When null, the back button pops the route (grid view). Otherwise it
  /// returns to the grid (detail view).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 28),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Text(
            'How do you feel?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// The scrollable grid of large emotion cards.
class _FeelingsGrid extends StatelessWidget {
  const _FeelingsGrid({super.key, required this.onSelect});

  final ValueChanged<_Feeling> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.92,
      ),
      itemCount: _feelings.length,
      itemBuilder: (BuildContext context, int index) {
        final feeling = _feelings[index];
        return _FeelingCard(
          feeling: feeling,
          onTap: () => onSelect(feeling),
        );
      },
    );
  }
}

/// A single big emotion face card in the grid.
class _FeelingCard extends StatelessWidget {
  const _FeelingCard({required this.feeling, required this.onTap});

  final _Feeling feeling;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      glowColor: feeling.color,
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          feeling.color.withOpacity(0.42),
          feeling.color.withOpacity(0.16),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            feeling.emoji,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 12),
          Text(
            feeling.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The detail view shown after a feeling is chosen: the big face floats up,
/// a validating message appears, and suitable coping strategies are offered.
class _FeelingDetail extends StatefulWidget {
  const _FeelingDetail({
    super.key,
    required this.feeling,
    required this.onChooseAnother,
  });

  final _Feeling feeling;
  final VoidCallback onChooseAnother;

  @override
  State<_FeelingDetail> createState() => _FeelingDetailState();
}

class _FeelingDetailState extends State<_FeelingDetail> {
  _Strategy? _chosen;
  bool _breathing = false;

  void _chooseStrategy(_Strategy strategy) {
    HapticFeedback.mediumImpact();
    setState(() {
      _chosen = strategy;
      _breathing = strategy.label == _breathe.label;
    });
  }

  void _onBreathingDone() {
    if (!mounted) return;
    setState(() => _breathing = false);
  }

  @override
  Widget build(BuildContext context) {
    final feeling = widget.feeling;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 4),
          _FloatingFace(
            key: ValueKey<String>('face-${feeling.label}'),
            feeling: feeling,
          ),
          const SizedBox(height: 18),
          GlassCard(
            glowColor: feeling.color,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                feeling.color.withOpacity(0.30),
                feeling.color.withOpacity(0.10),
              ],
            ),
            child: Column(
              children: <Widget>[
                Text(
                  feeling.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_breathing) ...<Widget>[
                  const SizedBox(height: 20),
                  _BreathingCircle(
                    color: feeling.color,
                    onDone: _onBreathingDone,
                  ),
                ] else if (_chosen != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _GoodChoiceBanner(
                    key: ValueKey<String>('banner-${_chosen!.label}'),
                    strategy: _chosen!,
                    color: feeling.color,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _StrategyTitle(color: feeling.color),
          const SizedBox(height: 12),
          ...feeling.strategies.map(
            (_Strategy s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StrategyButton(
                strategy: s,
                color: feeling.color,
                selected: _chosen?.label == s.label,
                onTap: () => _chooseStrategy(s),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ChooseAnotherButton(onTap: widget.onChooseAnother),
        ],
      ),
    );
  }
}

/// The chosen emotion's face gently floating with a soft halo.
class _FloatingFace extends StatefulWidget {
  const _FloatingFace({super.key, required this.feeling});

  final _Feeling feeling;

  @override
  State<_FloatingFace> createState() => _FloatingFaceState();
}

class _FloatingFaceState extends State<_FloatingFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.feeling.color;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final offset = -6.0 + (t * 12.0);
        final glow = 0.30 + (t * 0.25);
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  color.withOpacity(0.55),
                  color.withOpacity(0.12),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withOpacity(glow),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Text(
        widget.feeling.emoji,
        style: const TextStyle(fontSize: 76),
      ),
    );
  }
}

/// Heading above the coping strategies.
class _StrategyTitle extends StatelessWidget {
  const _StrategyTitle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.favorite_rounded, color: color.withOpacity(0.9), size: 20),
        const SizedBox(width: 8),
        const Text(
          'What could help?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// A large coping-strategy button. When chosen it blooms (scales up briefly).
class _StrategyButton extends StatefulWidget {
  const _StrategyButton({
    required this.strategy,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final _Strategy strategy;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_StrategyButton> createState() => _StrategyButtonState();
}

class _StrategyButtonState extends State<_StrategyButton> {
  bool _bloom = false;
  Timer? _bloomTimer;

  void _handleTap() {
    _bloomTimer?.cancel();
    setState(() => _bloom = true);
    _bloomTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() => _bloom = false);
    });
    widget.onTap();
  }

  @override
  void dispose() {
    _bloomTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return AnimatedScale(
      scale: _bloom ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: GlassCard(
        onTap: _handleTap,
        glowColor: widget.color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            widget.color.withOpacity(selected ? 0.46 : 0.26),
            widget.color.withOpacity(selected ? 0.22 : 0.10),
          ],
        ),
        child: Row(
          children: <Widget>[
            Text(
              widget.strategy.emoji,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                widget.strategy.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: selected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft "Good choice 💙" confirmation shown after picking a strategy.
class _GoodChoiceBanner extends StatelessWidget {
  const _GoodChoiceBanner({
    super.key,
    required this.strategy,
    required this.color,
  });

  final _Strategy strategy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double value, Widget? child) {
        final clamped = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.scale(scale: 0.85 + (clamped * 0.15), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              strategy.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Good choice 💙',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline calming breathing exercise: a circle that expands and contracts for
/// a few cycles, with gentle "Breathe in / Breathe out" guidance.
class _BreathingCircle extends StatefulWidget {
  const _BreathingCircle({required this.color, required this.onDone});

  final Color color;
  final VoidCallback onDone;

  @override
  State<_BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<_BreathingCircle>
    with SingleTickerProviderStateMixin {
  static const int _totalCycles = 4;

  late final AnimationController _controller;
  int _cycles = 0;
  bool _inhaling = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _controller.addStatusListener(_onStatus);
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.lightImpact();
      setState(() => _inhaling = false);
      _controller.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _cycles += 1;
      if (_cycles >= _totalCycles) {
        widget.onDone();
        return;
      }
      HapticFeedback.lightImpact();
      setState(() => _inhaling = true);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 180,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                final t = Curves.easeInOut.transform(_controller.value);
                final size = 90.0 + (t * 80.0);
                return Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        widget.color.withOpacity(0.55),
                        widget.color.withOpacity(0.15),
                      ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: widget.color.withOpacity(0.30 + (t * 0.25)),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.air_rounded,
                    color: Colors.white.withOpacity(0.85),
                    size: 28 + (t * 10),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _inhaling ? 'Breathe in…' : 'Breathe out…',
            key: ValueKey<bool>(_inhaling),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft pill button to return to the feelings grid.
class _ChooseAnotherButton extends StatelessWidget {
  const _ChooseAnotherButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.grid_view_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Choose another feeling',
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
}
