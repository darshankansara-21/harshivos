import 'package:flutter/material.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import 'emotion_match_game.dart';
import 'learning_engine.dart';
import 'matching_pairs_game.dart';

class _LearnActivity {
  const _LearnActivity(this.title, this.emoji, this.gradient, this.builder);
  final String title;
  final String emoji;
  final List<Color> gradient;
  final WidgetBuilder builder;
}

/// Learn — adaptive, playful micro-learning. Difficulty self-adjusts so games
/// stay in the "just right" zone and never feel like school.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  // Every activity here is a real, finished, no-fail game. The first two are
  // bespoke; the rest are powered by the shared learning engine (one adaptive
  // mechanic + curated content packs) — real depth, no "coming soon" tiles.
  static Widget _emotionBuilder(BuildContext context) => const EmotionMatchGame();
  static Widget _pairsBuilder(BuildContext context) => const MatchingPairsGame();

  static List<_LearnActivity> _buildActivities() => <_LearnActivity>[
        const _LearnActivity('Emotion Match', '🎭',
            <Color>[Color(0xFFA18CD1), Color(0xFFFBC2EB)], _emotionBuilder),
        const _LearnActivity('Matching Pairs', '🃏',
            <Color>[Color(0xFF43E97B), Color(0xFF38F9D7)], _pairsBuilder),
        for (final pack in kLearnPacks)
          _LearnActivity(pack.title, pack.emoji, pack.gradient,
              (context) => LearningGameScreen(pack: pack)),
        for (final pack in kSortPacks)
          _LearnActivity(pack.title, pack.emoji, pack.gradient,
              (context) => SortingGameScreen(pack: pack)),
      ];

  @override
  Widget build(BuildContext context) {
    final activities = _buildActivities();
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
              (context, i) => _ActivityTile(activity: activities[i]),
              childCount: activities.length,
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: activity.builder),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Tap to play',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}
