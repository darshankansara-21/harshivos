import 'package:flutter/material.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import 'emotion_match_game.dart';
import 'matching_pairs_game.dart';

class _LearnActivity {
  const _LearnActivity(this.title, this.emoji, this.gradient, {this.builder});
  final String title;
  final String emoji;
  final List<Color> gradient;
  final WidgetBuilder? builder;
  bool get ready => builder != null;
}

/// Learn — adaptive, playful micro-learning. Difficulty self-adjusts so games
/// stay in the "just right" zone and never feel like school.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  // Every activity here is a real, finished, no-fail game. We ship fewer real
  // games rather than a wall of "coming soon" dead-ends.
  static const List<_LearnActivity> _activities = <_LearnActivity>[
    _LearnActivity('Emotion Match', '🎭', <Color>[Color(0xFFA18CD1), Color(0xFFFBC2EB)],
        builder: _emotionBuilder),
    _LearnActivity('Matching Pairs', '🃏', <Color>[Color(0xFF43E97B), Color(0xFF38F9D7)],
        builder: _pairsBuilder),
  ];

  static Widget _emotionBuilder(BuildContext context) => const EmotionMatchGame();
  static Widget _pairsBuilder(BuildContext context) => const MatchingPairsGame();

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text('Learn',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text('Tiny, playful games that grow with you.',
                  style: TextStyle(color: Colors.white70)),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ActivityTile(activity: _activities[i]),
              childCount: _activities.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});
  final _LearnActivity activity;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: activity.ready
          ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: activity.builder!),
              )
          : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon to the toybox ✨')),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: activity.gradient),
            ),
            child: Text(activity.emoji, style: const TextStyle(fontSize: 32)),
          ),
          const Spacer(),
          Text(activity.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(activity.ready ? 'Tap to play' : 'Coming soon',
              style: TextStyle(
                color: activity.ready ? Colors.white60 : Colors.amberAccent.withOpacity(0.8),
                fontSize: 12,
              )),
        ],
      ),
    );
  }
}
