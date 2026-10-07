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
    // Unlike the main toybox grid below (`_ToyTile`, which already uses the
    // shared `GlassCard` — InkWell-backed haptic + tone + press-glow
    // feedback and full screen-reader semantics), this "Picked for you"
    // carousel — the very first row of tiles a child sees — used a bare
    // `GestureDetector`. A raw `GestureDetector`'s `onTap` never gets a
    // semantics node on its own, so a screen-reader user had no way to even
    // discover these chips exist, let alone activate one, and every child
    // lost the same press haptic/chime/scale-down confirmation every other
    // tappable card in the app gives (the exact gap `GlassCard`'s own doc
    // comment calls out as essential for Harshiv, who can't rely on sound
    // alone). Reusing `GlassCard` here closes that gap and keeps every
    // tappable surface in the hub behaving identically.
    return SizedBox(
      width: 150,
      child: Semantics(
        button: true,
        label: '${toy.title}, recommended. Tap to play.',
        child: GlassCard(
          onTap: () => openToy(context, toy),
          padding: const EdgeInsets.all(14),
          borderRadius: 22,
          gradient: LinearGradient(
            colors: toy.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          // This chip sits in a fixed `height: 120` row (see the
          // `SliverToBoxAdapter` above) that never grows to fit its
          // content. At a large accessibility `TextScaler`, the 34px emoji
          // glyph and the 2-line title both scale up with it and genuinely
          // overflowed that fixed height — the same bug class just fixed in
          // `_ToyTile` below. A single `FittedBox(fit: scaleDown)` around
          // the whole (naturally-sized, `mainAxisSize: min`) content Column
          // scales the entire chip body down only as far as needed to keep
          // fitting, while still growing (up to that limit) for a child who
          // needs bigger text. The inner `SizedBox(width: ...)` fixes the
          // title's wrap width *before* scaling — a bare `FittedBox` gives
          // its child unbounded width, which would stop the 2-line title
          // from ever wrapping at all.
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(toy.emoji, style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 10),
                    Text(toy.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
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
      // This grid tile's height is fixed by the parent `SliverGrid`'s
      // `childAspectRatio` (0.92) — it never grows to fit its content. The
      // old `Spacer()` + fixed-size icon/text below only ever worked at
      // normal text scale; at a large accessibility `TextScaler` (every
      // title/subtitle Text here scales with it by default, and even the
      // emoji glyph's own `Text` widget does too, outgrowing its fixed
      // 56x56 box) the Column genuinely overflowed its bounded height —
      // every single tile in the main toybox grid, the very first screen a
      // child picks a game from. `FittedBox(fit: scaleDown)` around both
      // the icon and the text block scales each down just enough to keep
      // fitting the fixed tile height instead of clipping/overflowing,
      // while still growing (up to that limit) for a child who needs
      // bigger text.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 56,
            height: 56,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: toy.gradient),
                ),
                child: Text(toy.emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  // A bare `FittedBox` gives its child unbounded width, so
                  // `Text(maxLines: 2)` below would never actually wrap —
                  // it would lay out as one long line, then get scaled down
                  // as a whole, defeating the 2-line title entirely. Fixing
                  // the inner Column's width to this tile's real available
                  // width lets the title still wrap normally; only the
                  // resulting block's height is then scaled to fit.
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(toy.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(toy.implemented ? 'Tap to play' : 'Coming soon',
                            style: TextStyle(
                              color: toy.implemented ? Colors.white60 : Colors.amberAccent.withOpacity(0.8),
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
