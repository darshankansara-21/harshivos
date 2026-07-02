import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../../models/toy_meta.dart';
import '../../state/providers.dart';
import 'toy_player_screen.dart';

/// Play & Explore — the flagship sensory toybox.
class PlayHubScreen extends ConsumerWidget {
  const PlayHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommended = ref.watch(recommendedToysProvider);
    final name = ref.watch(childNameProvider);

    return HarshivScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _Header(name: name),
          ),
          if (recommended.isNotEmpty) ...<Widget>[
            const SliverToBoxAdapter(child: _SectionTitle('✨ Picked for you')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  itemCount: recommended.length,
                  itemBuilder: (context, i) =>
                      _RecommendedChip(toy: recommended[i]),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: _SectionTitle('🧰 The toybox')),
          SliverPadding(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ToyTile(toy: kToyCatalog[i]),
                childCount: kToyCatalog.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Play & Explore',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Pick a toy. There is no wrong way to play.',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Text(text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _RecommendedChip extends StatelessWidget {
  const _RecommendedChip({required this.toy});
  final ToyMeta toy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openToy(context, toy),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: toy.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(toy.emoji, style: const TextStyle(fontSize: 34)),
            Text(toy.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ToyTile extends StatelessWidget {
  const _ToyTile({required this.toy});
  final ToyMeta toy;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => openToy(context, toy),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: toy.gradient),
            ),
            child: Text(toy.emoji, style: const TextStyle(fontSize: 30)),
          ),
          const Spacer(),
          Text(toy.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(toy.implemented ? 'Tap to play' : 'Coming soon',
              style: TextStyle(
                color: toy.implemented ? Colors.white60 : Colors.amberAccent.withOpacity(0.8),
                fontSize: 12,
              )),
        ],
      ),
    );
  }
}
