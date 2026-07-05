import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../../state/providers.dart';
import 'avatar/avatar.dart';
import 'avatar_studio_screen.dart';
import 'card_deck_screen.dart';
import 'create_routine_screen.dart';
import 'data/routine_library.dart';
import 'models/life_models.dart';
import 'progress_dashboard_screen.dart';
import 'routine_player_screen.dart';
import 'state/lifeskills_providers.dart';
import 'success_binder_screen.dart';

/// "My Daily Life" — the home of the Visual Life Skills world. A warm hub where
/// the child's own avatar greets them, celebrates their streak, and invites them
/// into routines, good-choice lessons, and safety practice.
class DailyLifeScreen extends ConsumerWidget {
  const DailyLifeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(childNameProvider);
    final config = ref.watch(avatarConfigProvider);
    final progress = ref.watch(lifeProgressProvider);
    final custom = ref.watch(customRoutinesProvider);
    final routines = <LifeRoutine>[...RoutineLibrary.routines, ...custom];

    return HarshivScaffold(
      padding: EdgeInsets.zero,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _Header(name: name, config: config, progress: progress),
          ),
          _sectionTitle('Daily Routines', '🌈'),
          _routineGrid(context, routines, progress, ref),
          _sectionTitle('Learn Good Choices', '💡'),
          _deckGrid(context),
          _sectionTitle('Make It Yours', '✨'),
          _toolGrid(context),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  SliverToBoxAdapter _sectionTitle(String title, String emoji) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
        child: Row(
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _routineGrid(BuildContext context, List<LifeRoutine> routines,
      LifeProgress progress, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.9,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final r = routines[i];
            final done = progress.completions[r.id] ?? 0;
            final mastered = progress.mastered.contains(r.id);
            final fav = progress.favorites.contains(r.id);
            return _RoutineTile(
              routine: r,
              done: done,
              mastered: mastered,
              favorite: fav,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RoutinePlayerScreen(routine: r))),
              onFav: () =>
                  ref.read(lifeProgressProvider.notifier).toggleFavorite(r.id),
            );
          },
          childCount: routines.length,
        ),
      ),
    );
  }

  Widget _deckGrid(BuildContext context) {
    final decks = RoutineLibrary.decks;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final d = decks[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _DeckTile(
                deck: d,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CardDeckScreen(deck: d))),
              ),
            );
          },
          childCount: decks.length,
        ),
      ),
    );
  }

  Widget _toolGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.5,
        ),
        delegate: SliverChildListDelegate(<Widget>[
          _ToolTile(
            emoji: '🪄',
            title: 'Create Routine',
            subtitle: 'Make a new one',
            glow: const Color(0xFF9B5DE5),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CreateRoutineScreen())),
          ),
          _ToolTile(
            emoji: '🧑‍🎨',
            title: 'Avatar Studio',
            subtitle: 'Design your guide',
            glow: const Color(0xFF4CC9F0),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AvatarStudioScreen())),
          ),
          _ToolTile(
            emoji: '📈',
            title: 'Progress',
            subtitle: 'See how far we\u2019ve come',
            glow: const Color(0xFF06D6A0),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ProgressDashboardScreen())),
          ),
          _ToolTile(
            emoji: '🏆',
            title: 'My Wins',
            subtitle: 'Our success binder',
            glow: const Color(0xFFFFD166),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SuccessBinderScreen())),
          ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header(
      {required this.name, required this.config, required this.progress});
  final String name;
  final AvatarConfig config;
  final LifeProgress progress;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 8, 20, 20),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _RoundIcon(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop()),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              SizedBox(
                height: 96,
                width: 96,
                child: AvatarWidget(config: config, pose: AvatarPose.wave),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('$_greeting,',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16)),
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    const Text('My Daily Life',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _StatChip(
                  emoji: '🔥',
                  value: '${progress.streak}',
                  label: 'day streak',
                  color: const Color(0xFFFF7A00)),
              const SizedBox(width: 10),
              _StatChip(
                  emoji: '💪',
                  value: '${progress.independenceScore}%',
                  label: 'independent',
                  color: const Color(0xFF06D6A0)),
              const SizedBox(width: 10),
              _StatChip(
                  emoji: '⭐',
                  value: '${progress.mastered.length}',
                  label: 'mastered',
                  color: const Color(0xFFFFD166)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.emoji,
      required this.value,
      required this.label,
      required this.color});
  final String emoji;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.4),
        ),
        child: Column(
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- tiles

class _RoutineTile extends StatelessWidget {
  const _RoutineTile(
      {required this.routine,
      required this.done,
      required this.mastered,
      required this.favorite,
      required this.onTap,
      required this.onFav});
  final LifeRoutine routine;
  final int done;
  final bool mastered;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFav;

  @override
  Widget build(BuildContext context) {
    final glow = routine.gradient.first;
    return GlassCard(
      onTap: onTap,
      glowColor: glow,
      padding: const EdgeInsets.all(14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[glow.withOpacity(0.28), glow.withOpacity(0.06)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(routine.emoji, style: const TextStyle(fontSize: 40)),
              const Spacer(),
              GestureDetector(
                onTap: onFav,
                child: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: favorite ? const Color(0xFFEF476F) : Colors.white54,
                  size: 22,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(routine.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(routine.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (mastered)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD166).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('⭐ Mastered',
                      style: TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                )
              else if (done > 0)
                Text('Done ${done}x',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12))
              else
                const Text('Tap to start',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.deck, required this.onTap});
  final LessonDeck deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glow = deck.gradient.first;
    return GlassCard(
      onTap: onTap,
      glowColor: glow,
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[glow.withOpacity(0.3), glow.withOpacity(0.05)],
      ),
      child: Row(
        children: <Widget>[
          Text(deck.emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(deck.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(deck.subtitle,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white54),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile(
      {required this.emoji,
      required this.title,
      required this.subtitle,
      required this.glow,
      required this.onTap});
  final String emoji;
  final String title;
  final String subtitle;
  final Color glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      glowColor: glow,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[glow.withOpacity(0.28), glow.withOpacity(0.06)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          Text(subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
