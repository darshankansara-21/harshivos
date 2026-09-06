import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import '../../models/activity_event.dart';
import '../../state/providers.dart';
import '../adventures/adventure_hub_screen.dart';
import '../antistress/antistress_player_screen.dart';
import '../calm/calm_me_screen.dart';
import '../experiences/experience_catalog.dart';
import '../learn/learn_screen.dart';
import '../lifeskills/avatar/hari_pico_scene.dart';
import '../lifeskills/daily_life_screen.dart';
import '../parent/activity_insights_screen.dart';
import '../world/world_screen.dart';
import '../lifeskills/profile_wizard_screen.dart';
import '../settings/sensory_settings_screen.dart';
import '../talk/talk_screen.dart';
import 'toy_debug_screen.dart';
import 'universe_catalog.dart';
import 'universe_state.dart';

/// THE front door — a flat toy box. Open the app, see a wall of toys, tap one
/// in a single step. No categories to decode, no portals to navigate. This is
/// "Netflix for toys": rails of Favorites / Recently Played / Most Loved / New,
/// then every toy below.
class ToyUniverseScreen extends ConsumerStatefulWidget {
  const ToyUniverseScreen({super.key});

  /// Opens a toy immersively and records the play for the rails.
  static Future<void> open(
      BuildContext context, WidgetRef ref, UniverseToy toy) async {
    HapticFeedback.selectionClick();
    ref.read(toyUsageProvider.notifier).record(toy.id);
    final started = DateTime.now();
    if (toy.launch == ToyLaunch.screen) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => toy.build()),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AntistressPlayerScreen(
            toy: toy.build(),
            title: toy.name,
            emoji: toy.emoji,
          ),
        ),
      );
    }
    // Back from the toy — record duration for rails + the unified activity log.
    final played = DateTime.now().difference(started);
    ref.read(toyUsageProvider.notifier).recordDuration(toy.id, played);
    ref.read(activityLogProvider.notifier).log(
          ActivityType.toyPlayed,
          toy.id,
          seconds: played.inSeconds,
          label: toy.name,
        );
  }

  @override
  ConsumerState<ToyUniverseScreen> createState() => _ToyUniverseScreenState();
}

class _ToyUniverseScreenState extends ConsumerState<ToyUniverseScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _allToysKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Play is the home itself — bring the wall of toys into view.
  void _scrollToToys() {
    final ctx = _allToysKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(childNameProvider);
    final favorites = ref.watch(favoriteToysProvider);
    final recents = ref.watch(recentToysProvider);
    final loved = ref.watch(mostLovedToysProvider);
    final fresh = ref.watch(newToysProvider);
    final recommended = ref.watch(recommendedUniverseToysProvider);
    final counts = toyCountsByCategory();
    final total = kToyUniverse.where((t) => t.working).length;

    final sortedCounts = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return HarshivScaffold(
      padding: EdgeInsets.zero,
      child: CustomScrollView(
        controller: _scroll,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('$name\u2019s Toy Box',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('$total toys to play  \u2728',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    // Hidden debug entry: long-press the counter chip.
                                        IconButton(
                                          tooltip: 'Activity insights',
                                          icon: const Icon(Icons.insights_rounded,
                                              color: Colors.white, size: 26),
                                          onPressed: () => Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const ActivityInsightsScreen(),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Sensory settings',
                                          icon: const Icon(Icons.tune_rounded,
                                              color: Colors.white, size: 28),
                                          onPressed: () => Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => const SensorySettingsScreen(),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'My avatar',
                                          icon: const Icon(Icons.face_rounded,
                                              color: Colors.white, size: 30),
                                          onPressed: () => Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const ProfileWizardScreen(fullEditor: true),
                                            ),
                                          ),
                                        ),
                    GestureDetector(
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => const ToyDebugScreen()));
                      },
                      child: _CountBadge(total: total),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _HariGreeting(name: name),
          ),
          if (recommended.isNotEmpty)
            _RailSliver(
                title: 'Start Playing', emoji: '\u25B6\uFE0F', toys: recommended),
          SliverToBoxAdapter(
            child: _CoreDestinations(onPlay: _scrollToToys),
          ),
          const SliverToBoxAdapter(
            child: _AdventureRoadmapCard(),
          ),
          if (favorites.isNotEmpty)
            _RailSliver(title: 'Favorites', emoji: '\u2764\uFE0F', toys: favorites),
          if (recents.isNotEmpty)
            _RailSliver(title: 'Recently Played', emoji: '\u23F1\uFE0F', toys: recents),
          if (loved.isNotEmpty)
            _RailSliver(title: 'Most Loved', emoji: '\u2B50', toys: loved),
          if (fresh.isNotEmpty)
            _RailSliver(title: 'New', emoji: '\u2728', toys: fresh),
          SliverToBoxAdapter(
            child: _CategoryChips(counts: sortedCounts),
          ),
          SliverToBoxAdapter(
            child: _ExploreWorldsButton(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const WorldScreen()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              key: _allToysKey,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: const Text('All Toys',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.86,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ToyCard(toy: kToyUniverse[i]),
                childCount: kToyUniverse.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A prominent doorway back to the immersive World home. Toys are the front
/// door now; this keeps every existing world one tap away.
class _ExploreWorldsButton extends StatelessWidget {
  const _ExploreWorldsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF1E3A8A), Color(0xFF36E0C0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              child: Row(
                children: <Widget>[
                  const Text('🗺️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Explore Worlds',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withOpacity(0.9)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A warm welcome from Hari and Pico — the first thing the child sees, so the
/// app feels like meeting a friend, not opening a menu.
class _HariGreeting extends StatelessWidget {
  const _HariGreeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: <Color>[Color(0x263AA0FF), Color(0x2606D6A0)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 92,
              height: 92,
              child: HariPicoScene(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Hi, $name!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Hari and Pico are ready to play.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// The six core destinations, always one tap from the front door. Emoji-led
/// and one word each so a non-reading child can navigate the whole app.
class _CoreDestinations extends StatelessWidget {
  const _CoreDestinations({required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    void go(Widget screen) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => screen),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _DestinationCard(
              emoji: '\uD83E\uDDF8',
              label: 'Play',
              colors: const <Color>[Color(0xFF9B5DE5), Color(0xFFF15BB5)],
              onTap: onPlay,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _DestinationCard(
              emoji: '\uD83D\uDDFA\uFE0F',
              label: 'Adventure',
              colors: const <Color>[Color(0xFF5E60CE), Color(0xFF4EA8DE)],
              onTap: () => go(const AdventureHubScreen()),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _DestinationCard(
              emoji: '\uD83C\uDF0A',
              label: 'Calm',
              colors: const <Color>[Color(0xFF0891B2), Color(0xFF06D6A0)],
              onTap: () => go(const CalmMeScreen()),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _DestinationCard(
              emoji: '\uD83D\uDCAC',
              label: 'Talk',
              colors: const <Color>[Color(0xFF4361EE), Color(0xFF38B2F9)],
              onTap: () => go(const TalkScreen()),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _DestinationCard(
              emoji: '\uD83C\uDF08',
              label: 'Routines',
              colors: const <Color>[Color(0xFFFF9E6D), Color(0xFFF7B801)],
              onTap: () => go(const DailyLifeScreen()),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _DestinationCard(
              emoji: '\uD83C\uDF93',
              label: 'Learn',
              colors: const <Color>[Color(0xFF06D6A0), Color(0xFF43E97B)],
              onTap: () => go(const LearnScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.emoji,
    required this.label,
    required this.colors,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.last.withOpacity(0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdventureRoadmapCard extends StatelessWidget {
  const _AdventureRoadmapCard();

  @override
  Widget build(BuildContext context) {
    final live = ExperienceCatalog.currentTotal;
    final capacity = ExperienceCatalog.projectedCapacity;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdventureHubScreen(),
            ),
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: <Color>[Color(0x346A5AE0), Color(0x3424C6DC)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: <Widget>[
                const Text('🧭', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Adventures with Hari & Pico',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text('Live: $live  •  Capacity: $capacity',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: <Widget>[
          Text('$total',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          Text('toys',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.counts});
  final List<MapEntry<ToyCategory, int>> counts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        itemCount: counts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final e = counts[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Text('${e.key.emoji}  ${e.key.label} (${e.value})',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          );
        },
      ),
    );
  }
}

class _RailSliver extends StatelessWidget {
  const _RailSliver(
      {required this.title, required this.emoji, required this.toys});
  final String title;
  final String emoji;
  final List<UniverseToy> toys;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text('$emoji  $title',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: toys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  SizedBox(width: 128, child: _ToyCard(toy: toys[i])),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToyCard extends ConsumerWidget {
  const _ToyCard({required this.toy});
  final UniverseToy toy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).contains(toy.id);
    return GestureDetector(
      onTap: () => ToyUniverseScreen.open(context, ref, toy),
      onLongPress: () => _showPreview(context, ref),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              toy.color.withOpacity(0.36),
              toy.color.withOpacity(0.12),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: <Color>[
                        toy.color,
                        Color.lerp(toy.color, Colors.black, 0.35)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: toy.color.withOpacity(0.5),
                          blurRadius: 14,
                          spreadRadius: 1),
                    ],
                  ),
                  child: Text(toy.emoji, style: const TextStyle(fontSize: 24)),
                ),
                const Spacer(),
                _HeartButton(
                  active: isFav,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(favoritesProvider.notifier).toggle(toy.id);
                  },
                ),
              ],
            ),
            const Spacer(),
            Text(toy.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(toy.isNew ? 'New \u2728' : toy.category.label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showPreview(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _PreviewDialog(toy: toy),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: active ? const Color(0xFFFF375F) : Colors.white54,
        size: 22,
      ),
    );
  }
}

/// Long-press live preview — instantiates the real toy in a small window so a
/// parent (or child) can peek at what it does before opening it full-screen.
class _PreviewDialog extends ConsumerWidget {
  const _PreviewDialog({required this.toy});
  final UniverseToy toy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = toy.launch == ToyLaunch.widget;
    return Dialog(
      backgroundColor: const Color(0xFF14122A),
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(toy.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(toy.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 260,
                width: double.infinity,
                child: live
                    ? AbsorbPointer(child: toy.build())
                    : _StaticPreview(toy: toy),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${toy.inputs.map((e) => e.label).join(' \u00b7 ')}  \u2022  ${toy.engagement.label}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: toy.color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  ToyUniverseScreen.open(context, ref, toy);
                },
                child: const Text('Play',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticPreview extends StatelessWidget {
  const _StaticPreview({required this.toy});
  final UniverseToy toy;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            toy.color.withOpacity(0.5),
            toy.color.withOpacity(0.15),
          ],
        ),
      ),
      child: Text(toy.emoji, style: const TextStyle(fontSize: 72)),
    );
  }
}
