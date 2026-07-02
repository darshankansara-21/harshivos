import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';

/// A single pickable thing shown on the board.
class _Choice {
  const _Choice(this.emoji, this.word);
  final String emoji;
  final String word;
}

/// A top-row category with its own set of choices.
class _Category {
  const _Category(this.emoji, this.label, this.glow, this.choices);
  final String emoji;
  final String label;
  final Color glow;
  final List<_Choice> choices;
}

/// Choice Board — visual requesting ("I want ___").
///
/// A non/limited-verbal child taps a big picture card; the screen blooms it
/// huge with the sentence "I want [word]" so they can SHOW an adult exactly
/// what they want. Calm, high-contrast, large targets, no fail states.
class ChoiceBoardScreen extends StatefulWidget {
  const ChoiceBoardScreen({super.key});

  @override
  State<ChoiceBoardScreen> createState() => _ChoiceBoardScreenState();
}

class _ChoiceBoardScreenState extends State<ChoiceBoardScreen> {
  static const List<_Category> _categories = <_Category>[
    _Category('🍎', 'Food', Color(0xFFFF7A8A), <_Choice>[
      _Choice('🍎', 'Apple'),
      _Choice('🍌', 'Banana'),
      _Choice('🥨', 'Snack'),
      _Choice('💧', 'Water'),
      _Choice('🥛', 'Milk'),
      _Choice('🍪', 'Cookie'),
      _Choice('🍇', 'Grapes'),
      _Choice('🥪', 'Sandwich'),
    ]),
    _Category('🎲', 'Play', Color(0xFF7AD1FF), <_Choice>[
      _Choice('🎨', 'Draw'),
      _Choice('🧩', 'Puzzle'),
      _Choice('📺', 'Show'),
      _Choice('🚗', 'Cars'),
      _Choice('🎵', 'Music'),
      _Choice('🫧', 'Bubbles'),
      _Choice('🧸', 'Toy'),
      _Choice('⚽', 'Ball'),
    ]),
    _Category('📍', 'Places', Color(0xFF8CF5C4), <_Choice>[
      _Choice('🏞️', 'Park'),
      _Choice('🛝', 'Playground'),
      _Choice('🏠', 'Home'),
      _Choice('🚗', 'Car ride'),
      _Choice('🏊', 'Pool'),
      _Choice('🛒', 'Store'),
      _Choice('🛏️', 'Bed'),
    ]),
    _Category('👪', 'People', Color(0xFFFFD27A), <_Choice>[
      _Choice('👩', 'Mom'),
      _Choice('👨', 'Dad'),
      _Choice('👵', 'Grandma'),
      _Choice('👴', 'Grandpa'),
      _Choice('🧑‍🏫', 'Teacher'),
      _Choice('👫', 'Friend'),
    ]),
  ];

  int _categoryIndex = 0;
  _Choice? _revealed;

  void _selectCategory(int index) {
    if (_categoryIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _categoryIndex = index);
  }

  void _reveal(_Choice choice) {
    HapticFeedback.heavyImpact();
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
    setState(() => _revealed = choice);
  }

  void _dismiss() {
    if (_revealed == null) return;
    HapticFeedback.selectionClick();
    setState(() => _revealed = null);
  }

  @override
  Widget build(BuildContext context) {
    final _Category category = _categories[_categoryIndex];

    return HarshivScaffold(
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildHeader(),
              const SizedBox(height: 16),
              _buildCategoryRow(),
              const SizedBox(height: 18),
              Expanded(child: _buildGrid(category)),
            ],
          ),
          if (_revealed != null)
            _RevealOverlay(
              key: ValueKey<String>(_revealed!.word),
              choice: _revealed!,
              glow: category.glow,
              onDismiss: _dismiss,
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
          'I Choose',
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

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final _Category cat = _categories[index];
          final bool selected = index == _categoryIndex;
          return _CategoryChip(
            category: cat,
            selected: selected,
            onTap: () => _selectCategory(index),
          );
        },
      ),
    );
  }

  Widget _buildGrid(_Category category) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 720
            ? 4
            : width >= 480
                ? 3
                : 2;
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.92,
          ),
          itemCount: category.choices.length,
          itemBuilder: (BuildContext context, int index) {
            return _ChoiceTile(
              choice: category.choices[index],
              glow: category.glow,
              index: index,
              onTap: () => _reveal(category.choices[index]),
            );
          },
        );
      },
    );
  }
}

/// A single top-row category chip.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.0 : 0.96,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: GlassCard(
        onTap: onTap,
        glowColor: category.glow,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        gradient: selected
            ? LinearGradient(
                colors: <Color>[
                  category.glow.withOpacity(0.55),
                  category.glow.withOpacity(0.22),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(category.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              category.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A big picture card on the board.
class _ChoiceTile extends StatefulWidget {
  const _ChoiceTile({
    required this.choice,
    required this.glow,
    required this.index,
    required this.onTap,
  });

  final _Choice choice;
  final Color glow;
  final int index;
  final VoidCallback onTap;

  @override
  State<_ChoiceTile> createState() => _ChoiceTileState();
}

class _ChoiceTileState extends State<_ChoiceTile> {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('${widget.choice.word}_${widget.index}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + widget.index * 45),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double t, Widget? child) {
        final double clamped = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.scale(scale: 0.7 + 0.3 * clamped, child: child),
        );
      },
      child: GlassCard(
        onTap: widget.onTap,
        glowColor: widget.glow,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Center(
                child: FittedBox(
                  child: Text(
                    widget.choice.emoji,
                    style: const TextStyle(fontSize: 72),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.choice.word,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen "I want ___" bloom that lets the child SHOW an adult.
class _RevealOverlay extends StatefulWidget {
  const _RevealOverlay({
    super.key,
    required this.choice,
    required this.glow,
    required this.onDismiss,
  });

  final _Choice choice;
  final Color glow;
  final VoidCallback onDismiss;

  @override
  State<_RevealOverlay> createState() => _RevealOverlayState();
}

class _RevealOverlayState extends State<_RevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _haloController;

  @override
  void initState() {
    super.initState();
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _haloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismiss,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutBack,
          builder: (BuildContext context, double t, Widget? child) {
            final double clamped = t.clamp(0.0, 1.0);
            return Opacity(opacity: clamped, child: child);
          },
          child: Container(
            color: Colors.black.withOpacity(0.72),
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: _buildHalo()),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'I want',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBloomEmoji(),
                      const SizedBox(height: 4),
                      Text(
                        widget.choice.word,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          shadows: <Shadow>[
                            Shadow(
                              color: widget.glow.withOpacity(0.8),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const <Widget>[
                          Icon(Icons.touch_app_rounded,
                              color: Colors.white54, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Tap to go back',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHalo() {
    return AnimatedBuilder(
      animation: _haloController,
      builder: (BuildContext context, Widget? child) {
        final double pulse =
            0.85 + 0.15 * math.sin(_haloController.value * 2 * math.pi);
        return Center(
          child: Container(
            width: 320 * pulse,
            height: 320 * pulse,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  widget.glow.withOpacity(0.45),
                  widget.glow.withOpacity(0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBloomEmoji() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double t, Widget? child) {
        final double clamped = t.clamp(0.0, 1.0);
        return Transform.scale(
          scale: 0.4 + 0.6 * clamped,
          child: Opacity(opacity: clamped, child: child),
        );
      },
      child: Text(
        widget.choice.emoji,
        style: const TextStyle(fontSize: 150),
      ),
    );
  }
}
