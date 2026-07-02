import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Matching Pairs — a calm, no-fail memory game.
///
/// Designed for Harshiv: large high-contrast picture cards (good for the left
/// eye), a satisfying flip + glow on every tap (visible, never sound-dependent),
/// and absolutely no way to lose. Mismatches simply turn back over; matches
/// celebrate. Finishing rains gentle confetti, then offers another round.
class MatchingPairsGame extends StatefulWidget {
  const MatchingPairsGame({super.key});

  @override
  State<MatchingPairsGame> createState() => _MatchingPairsGameState();
}

class _Card {
  _Card(this.emoji, this.color);
  final String emoji;
  final Color color;
  bool flipped = false;
  bool matched = false;
}

class _MatchingPairsGameState extends State<MatchingPairsGame> {
  static const List<(String, Color)> _deck = <(String, Color)>[
    ('🐶', Color(0xFFFFA552)),
    ('🐱', Color(0xFFFF6B9D)),
    ('🦊', Color(0xFFFF6B6B)),
    ('🐢', Color(0xFF43E97B)),
    ('🐠', Color(0xFF54A0FF)),
    ('🦋', Color(0xFFA55EEA)),
    ('🌟', Color(0xFFFEC84D)),
    ('🌈', Color(0xFF18C8C8)),
  ];

  final math.Random _rnd = math.Random();
  int _pairs = 4; // 4 pairs = 8 cards (grows a little each win)
  late List<_Card> _cards;
  _Card? _first;
  bool _busy = false;
  int _wins = 0;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final chosen = (<(String, Color)>[..._deck]..shuffle(_rnd)).take(_pairs).toList();
    _cards = <_Card>[
      for (final c in chosen) ...<_Card>[_Card(c.$1, c.$2), _Card(c.$1, c.$2)],
    ]..shuffle(_rnd);
    _first = null;
    _busy = false;
  }

  bool get _solved => _cards.every((c) => c.matched);

  Future<void> _tap(_Card card) async {
    if (_busy || card.flipped || card.matched) return;
    HapticFeedback.selectionClick();
    setState(() => card.flipped = true);

    if (_first == null) {
      _first = card;
      return;
    }

    if (_first!.emoji == card.emoji) {
      // Match!
      HapticFeedback.mediumImpact();
      setState(() {
        _first!.matched = true;
        card.matched = true;
        _first = null;
      });
      if (_solved) {
        _wins++;
        if (_pairs < 8) _pairs++; // gently grow next round
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) _celebrate();
      }
    } else {
      // No match — turn both back after a beat. Never a fail state.
      _busy = true;
      final firstCard = _first!;
      _first = null;
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      setState(() {
        firstCard.flipped = false;
        card.flipped = false;
        _busy = false;
      });
    }
  }

  void _celebrate() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1140),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white24, width: 1.6),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x6643E97B), blurRadius: 40, spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('🎉', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 8),
              const Text('You found them all!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF43E97B),
                  foregroundColor: const Color(0xFF0B1026),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(_deal);
                },
                child: const Text('Play again',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cols = _cards.length <= 8 ? 4 : (_cards.length <= 12 ? 4 : 5);
    return Scaffold(
      backgroundColor: const Color(0xFF1B1140),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Matching Pairs'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('🏆 $_wins',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: _cards.length,
              itemBuilder: (context, i) => _CardView(card: _cards[i], onTap: () => _tap(_cards[i])),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.onTap});
  final _Card card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showFace = card.flipped || card.matched;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: card.matched ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: showFace ? card.color.withOpacity(0.22) : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: showFace ? card.color : Colors.white24,
              width: showFace ? 2.4 : 1.4,
            ),
            boxShadow: card.matched
                ? <BoxShadow>[BoxShadow(color: card.color.withOpacity(0.6), blurRadius: 26, spreadRadius: 1)]
                : const <BoxShadow>[],
          ),
          child: Center(
            child: showFace
                ? Text(card.emoji, style: const TextStyle(fontSize: 52))
                : Icon(Icons.question_mark_rounded,
                    color: Colors.white.withOpacity(0.5), size: 40),
          ),
        ),
      ),
    );
  }
}
