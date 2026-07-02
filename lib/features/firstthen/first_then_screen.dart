import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';

/// A First–Then board: the classic ABA transition & motivation tool.
///
/// "First we do X, Then you get Y." Two huge cards sit side by side (or stacked
/// on narrow screens). The child taps a slot to select it, then taps a picture
/// chip to fill it. Once both are set, a big calm button celebrates "First
/// done!" and visually promotes the reward.
///
/// Everything here is visual-first, high-contrast, calm, and confirms every
/// touch with motion + haptics. There are no fail states.
class FirstThenScreen extends StatefulWidget {
  const FirstThenScreen({super.key});

  @override
  State<FirstThenScreen> createState() => _FirstThenScreenState();
}

/// Which big slot is currently being edited.
enum _Slot { first, then }

/// A single picture activity the child can pick.
class _Activity {
  const _Activity(this.emoji, this.label);
  final String emoji;
  final String label;
}

const List<_Activity> _palette = <_Activity>[
  _Activity('🪥', 'Brush'),
  _Activity('🍽️', 'Eat'),
  _Activity('🧹', 'Clean up'),
  _Activity('📚', 'Read'),
  _Activity('🚻', 'Potty'),
  _Activity('👕', 'Dress'),
  _Activity('🧩', 'Puzzle'),
  _Activity('🎨', 'Draw'),
  _Activity('📺', 'Show'),
  _Activity('🍪', 'Snack'),
  _Activity('🎮', 'Game'),
  _Activity('🛝', 'Park'),
  _Activity('🫧', 'Bubbles'),
  _Activity('🎵', 'Music'),
];

// Calm, high-contrast slot colours.
const Color _firstBlue = Color(0xFF3B82F6);
const Color _firstBlueDeep = Color(0xFF1D4ED8);
const Color _thenAmber = Color(0xFFFB923C);
const Color _thenAmberDeep = Color(0xFFEA580C);
const Color _doneGreen = Color(0xFF34D399);
const Color _doneGreenDeep = Color(0xFF059669);

class _FirstThenScreenState extends State<FirstThenScreen>
    with TickerProviderStateMixin {
  _Activity? _first;
  _Activity? _then;
  _Slot _selected = _Slot.first;
  bool _firstDone = false;

  // Celebration pulse that promotes the reward card.
  late final AnimationController _celebrate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Gentle perpetual breathing for the active/empty slot to invite a tap.
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  bool get _ready => _first != null && _then != null;

  @override
  void dispose() {
    _celebrate.dispose();
    _breathe.dispose();
    super.dispose();
  }

  void _selectSlot(_Slot slot) {
    if (_firstDone) return;
    if (_selected == slot) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = slot);
  }

  void _pickActivity(_Activity activity) {
    if (_firstDone) return;
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selected == _Slot.first) {
        _first = activity;
        // Auto-advance to the reward slot once "First" is filled.
        if (_then == null) _selected = _Slot.then;
      } else {
        _then = activity;
        if (_first == null) _selected = _Slot.first;
      }
    });
  }

  Future<void> _markDone() async {
    if (!_ready || _firstDone) return;
    setState(() {
      _firstDone = true;
      _selected = _Slot.then;
    });
    unawaited(_celebrationHaptics());
    _celebrate.forward(from: 0);
  }

  Future<void> _celebrationHaptics() async {
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 130));
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 130));
    HapticFeedback.lightImpact();
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    _celebrate.stop();
    setState(() {
      _first = null;
      _then = null;
      _firstDone = false;
      _selected = _Slot.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildBoard(),
                  const SizedBox(height: 20),
                  _buildPalette(),
                  const SizedBox(height: 20),
                  _buildActions(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
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
        const Expanded(
          child: Text(
            'First — Then',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  // ---- The two big slots + the arrow between them ----

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 560;
        final Widget firstCard = _buildSlotCard(_Slot.first);
        final Widget thenCard = _buildSlotCard(_Slot.then);

        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: firstCard),
                _buildArrow(vertical: false),
                Expanded(child: thenCard),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            firstCard,
            _buildArrow(vertical: true),
            thenCard,
          ],
        );
      },
    );
  }

  Widget _buildArrow({required bool vertical}) {
    final IconData icon =
        vertical ? Icons.arrow_downward_rounded : Icons.arrow_forward_rounded;
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: AnimatedBuilder(
          animation: _celebrate,
          builder: (BuildContext context, Widget? child) {
            final double t = Curves.easeInOut.transform(_celebrate.value);
            return Transform.translate(
              offset: vertical
                  ? Offset(0, 6 * math.sin(t * math.pi))
                  : Offset(10 * math.sin(t * math.pi), 0),
              child: child,
            );
          },
          child: Icon(
            icon,
            size: 40,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(_Slot slot) {
    final bool isFirst = slot == _Slot.first;
    final _Activity? activity = isFirst ? _first : _then;
    final bool isSelected = _selected == slot && !_firstDone;

    // First flips to a celebrated green "done" state; Then is promoted as the
    // reward once we mark done.
    final bool firstCelebrated = isFirst && _firstDone;
    final bool thenPromoted = !isFirst && _firstDone;

    final Color top = firstCelebrated
        ? _doneGreen
        : isFirst
            ? _firstBlue
            : _thenAmber;
    final Color bottom = firstCelebrated
        ? _doneGreenDeep
        : isFirst
            ? _firstBlueDeep
            : _thenAmberDeep;
    final Color glow = firstCelebrated
        ? _doneGreen
        : isFirst
            ? _firstBlue
            : _thenAmber;

    final String caption = firstCelebrated
        ? 'DONE'
        : isFirst
            ? 'FIRST'
            : 'THEN';

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_celebrate, _breathe]),
      builder: (BuildContext context, Widget? child) {
        // Breathing invite only on the active empty slot.
        final bool invite = isSelected && activity == null;
        final double breath =
            invite ? 1 + 0.018 * math.sin(_breathe.value * math.pi * 2) : 1;
        final double promote =
            thenPromoted ? 1 + 0.06 * Curves.easeOut.transform(_celebrate.value) : 1;
        return Transform.scale(scale: breath * promote, child: child);
      },
      child: GlassCard(
        glowColor: glow,
        onTap: _firstDone ? null : () => _selectSlot(slot),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            top.withOpacity(thenPromoted ? 0.55 : 0.42),
            bottom.withOpacity(thenPromoted ? 0.62 : 0.50),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.9)
                  : Colors.white.withOpacity(0.16),
              width: isSelected ? 3 : 1.4,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildSlotCaption(caption, firstCelebrated, thenPromoted),
              const SizedBox(height: 14),
              SizedBox(
                height: 168,
                child: Center(
                  child: activity == null
                      ? _buildEmptySlot(isSelected)
                      : _buildFilledSlot(activity, firstCelebrated),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCaption(String caption, bool celebrated, bool promoted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (celebrated) ...<Widget>[
          const Icon(Icons.check_circle_rounded,
              color: Colors.white, size: 26),
          const SizedBox(width: 8),
        ],
        if (promoted) ...<Widget>[
          const Icon(Icons.celebration_rounded,
              color: Colors.white, size: 26),
          const SizedBox(width: 8),
        ],
        Text(
          caption,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            shadows: <Shadow>[
              Shadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySlot(bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          isSelected ? Icons.touch_app_rounded : Icons.add_rounded,
          color: Colors.white.withOpacity(0.92),
          size: 64,
        ),
        const SizedBox(height: 10),
        Text(
          isSelected ? 'Pick below' : 'Tap to choose',
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilledSlot(_Activity activity, bool celebrated) {
    return AnimatedBuilder(
      animation: _celebrate,
      builder: (BuildContext context, Widget? child) {
        // Tiny celebratory pop on the First emoji when marked done.
        final double pop = celebrated
            ? 1 + 0.12 * math.sin(Curves.easeOut.transform(_celebrate.value) * math.pi)
            : 1;
        return Transform.scale(scale: pop, child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(activity.emoji, style: const TextStyle(fontSize: 96)),
          const SizedBox(height: 10),
          Text(
            activity.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Palette of picture chips ----

  Widget _buildPalette() {
    final bool isFirstSlot = _selected == _Slot.first;
    final Color hint = isFirstSlot ? _firstBlue : _thenAmber;
    final _Activity? activeValue = isFirstSlot ? _first : _then;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.grid_view_rounded,
                  color: Colors.white.withOpacity(0.9), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _firstDone
                      ? 'All set — great job!'
                      : isFirstSlot
                          ? 'Choose FIRST'
                          : 'Choose THEN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (final _Activity activity in _palette)
                _buildChip(
                  activity,
                  selected: !_firstDone && activeValue == activity,
                  hint: hint,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    _Activity activity, {
    required bool selected,
    required Color hint,
  }) {
    return GlassCard(
      onTap: _firstDone ? null : () => _pickActivity(activity),
      glowColor: hint,
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gradient: selected
          ? LinearGradient(
              colors: <Color>[
                hint.withOpacity(0.55),
                hint.withOpacity(0.35),
              ],
            )
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _firstDone ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(activity.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text(
              activity.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Bottom action row: big done button + small reset ----

  Widget _buildActions() {
    return Row(
      children: <Widget>[
        Expanded(child: _buildDoneButton()),
        const SizedBox(width: 14),
        _buildResetButton(),
      ],
    );
  }

  Widget _buildDoneButton() {
    final bool enabled = _ready && !_firstDone;
    final bool celebrating = _firstDone;

    final Color top = celebrating ? _doneGreen : _firstBlue;
    final Color bottom = celebrating ? _doneGreenDeep : _firstBlueDeep;

    return AnimatedBuilder(
      animation: _celebrate,
      builder: (BuildContext context, Widget? child) {
        final double bounce = celebrating
            ? 1 + 0.05 * math.sin(_celebrate.value * math.pi)
            : 1;
        return Transform.scale(scale: bounce, child: child);
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: enabled || celebrating ? 1 : 0.4,
        child: GlassCard(
          onTap: enabled ? _markDone : null,
          glowColor: celebrating ? _doneGreen : _firstBlue,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              top.withOpacity(0.7),
              bottom.withOpacity(0.7),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                celebrating
                    ? Icons.emoji_events_rounded
                    : Icons.check_circle_rounded,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  celebrating ? 'Yay! Now your reward' : 'First done!',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
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

  Widget _buildResetButton() {
    return GlassCard(
      onTap: _reset,
      borderRadius: 22,
      padding: const EdgeInsets.all(18),
      child: const Icon(
        Icons.refresh_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}
