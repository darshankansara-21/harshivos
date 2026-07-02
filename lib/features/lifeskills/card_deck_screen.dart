import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'avatar/avatar.dart';
import 'models/life_models.dart';
import 'state/lifeskills_providers.dart';

/// Plays a [LessonDeck] (Do's & Don'ts, Social Skills, Stay Safe) as a stack of
/// big, clearly colour-coded teaching cards with avatar + narration.
class CardDeckScreen extends ConsumerStatefulWidget {
  const CardDeckScreen({super.key, required this.deck});
  final LessonDeck deck;

  @override
  ConsumerState<CardDeckScreen> createState() => _CardDeckScreenState();
}

class _CardDeckScreenState extends ConsumerState<CardDeckScreen> {
  final FlutterTts _tts = FlutterTts();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.44);
      await _tts.setPitch(1.06);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  List<LessonCard> get _cards => widget.deck.cards;

  Future<void> _speakCurrent() async {
    try {
      await _tts.stop();
      await _tts.speak(_cards[_index].narration);
    } catch (_) {}
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index >= _cards.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index++);
    _speakCurrent();
  }

  void _prev() {
    HapticFeedback.selectionClick();
    if (_index <= 0) return;
    setState(() => _index--);
    _speakCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(avatarConfigProvider);
    final card = _cards[_index];
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              _kindColor(card.kind).withOpacity(0.5),
              const Color(0xFF0B1020),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _bar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: _next,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1)
                                .animate(anim),
                            child: child),
                      ),
                      child: _CardView(
                        key: ValueKey<int>(_index),
                        card: card,
                        config: config,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: <Widget>[
                    _round(Icons.arrow_back_rounded, _prev),
                    const SizedBox(width: 12),
                    _round(Icons.volume_up_rounded, _speakCurrent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: _kindColor(card.kind),
                        borderRadius: BorderRadius.circular(22),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _next,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                    _index == _cards.length - 1
                                        ? 'Done'
                                        : 'Next',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 6),
      child: Row(
        children: <Widget>[
          _round(Icons.close_rounded, () => Navigator.of(context).pop()),
          const SizedBox(width: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_index + 1) / _cards.length,
                minHeight: 10,
                backgroundColor: Colors.white.withOpacity(0.18),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${_index + 1}/${_cards.length}',
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) {
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

Color _kindColor(LessonKind k) {
  switch (k) {
    case LessonKind.doThis:
    case LessonKind.good:
      return const Color(0xFF06D6A0);
    case LessonKind.dontThis:
    case LessonKind.bad:
      return const Color(0xFFEF476F);
    case LessonKind.info:
      return const Color(0xFF4CC9F0);
  }
}

String _kindLabel(LessonKind k) {
  switch (k) {
    case LessonKind.doThis:
      return 'DO';
    case LessonKind.good:
      return 'GOOD';
    case LessonKind.dontThis:
      return "DON'T";
    case LessonKind.bad:
      return 'NOT THIS';
    case LessonKind.info:
      return 'LEARN';
  }
}

IconData _kindIcon(LessonKind k) {
  switch (k) {
    case LessonKind.doThis:
    case LessonKind.good:
      return Icons.check_circle_rounded;
    case LessonKind.dontThis:
    case LessonKind.bad:
      return Icons.cancel_rounded;
    case LessonKind.info:
      return Icons.lightbulb_rounded;
  }
}

class _CardView extends StatelessWidget {
  const _CardView({super.key, required this.card, required this.config});
  final LessonCard card;
  final AvatarConfig config;

  @override
  Widget build(BuildContext context) {
    final color = _kindColor(card.kind);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: RadialGradient(
          center: const Alignment(-0.2, -0.4),
          radius: 1.3,
          colors: <Color>[color.withOpacity(0.5), color.withOpacity(0.1)],
        ),
        border: Border.all(color: color.withOpacity(0.7), width: 3),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 40, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(_kindIcon(card.kind), color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(_kindLabel(card.kind),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Align(
                  alignment: const Alignment(-0.5, 0),
                  child: Text(card.emoji, style: const TextStyle(fontSize: 96)),
                ),
                Align(
                  alignment: const Alignment(0.6, 0.1),
                  child: FractionallySizedBox(
                    widthFactor: 0.42,
                    heightFactor: 0.8,
                    child: AvatarWidget(config: config, pose: card.pose),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
            child: Column(
              children: <Widget>[
                Text(card.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(card.narration,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small decorative sparkle helper reused by callers if needed.
class DeckSparkle extends StatelessWidget {
  const DeckSparkle({super.key, this.size = 12});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Icon(Icons.star_rounded, size: size, color: Colors.white70),
    );
  }
}
