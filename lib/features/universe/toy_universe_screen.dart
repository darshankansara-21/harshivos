import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import '../../models/activity_event.dart';
import '../../services/audio/tone_player.dart';
import '../../state/player_progress.dart';
import '../../state/providers.dart';
import '../play/toys/mini_games.dart' show GameScores;
import '../adventures/adventure_hub_screen.dart';
import '../antistress/antistress_player_screen.dart';
import '../calm/calm_me_screen.dart';
import '../companion/companion.dart';
import '../experiences/experience_catalog.dart';
import '../learn/learn_screen.dart';
import '../lifeskills/daily_life_screen.dart';
import '../parent/activity_insights_screen.dart';
import '../world/world_screen.dart';
import '../lifeskills/profile_wizard_screen.dart';
import '../settings/sensory_settings_screen.dart';
import '../talk/talk_screen.dart';
import '../play/toys/mini_games.dart' show GameScores;
import 'game_thumb.dart';
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
    await GameScores.instance.ensureLoaded();
    final beforeBest = GameScores.instance.best(toy.id);
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
    // Award progression for a real session (>3s) and surface any new unlocks.
    if (played.inSeconds >= 3) {
      final newBest = GameScores.instance.best(toy.id) > beforeBest;
      final unlocked = ref
          .read(playerProgressProvider.notifier)
          .recordSession(newBest: newBest);
      if (context.mounted && unlocked.isNotEmpty) {
        final a = achievementById(unlocked.first);
        if (a != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF2A2036),
              content: Text('${a.emoji}  Unlocked: ${a.title}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          );
        }
      }
    }
  }

  @override
  ConsumerState<ToyUniverseScreen> createState() => _ToyUniverseScreenState();
}

class _ToyUniverseScreenState extends ConsumerState<ToyUniverseScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _allToysKey = GlobalKey();
  bool _meetShown = false;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowMeetSheet());
  }

  Future<void> _maybeShowMeetSheet() async {
    if (!mounted || _meetShown) return;
    final storage = ref.read(localStorageProvider);
    final complete = ref.read(profileCompleteProvider);
    if (!complete) return;
    final shouldShow = storage.readBool('show_meet_hari_pico');
    if (!shouldShow) return;
    final seen = storage.readBool('met_hari_pico_v1');
    if (seen || !mounted) return;
    _meetShown = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: const Color(0xFF151C46),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _MeetHariPicoSheet(
        onEnterPlay: () {
          Navigator.of(context).pop();
          _scrollToToys();
        },
      ),
    );
    await storage.writeBool('show_meet_hari_pico', false);
    await storage.writeBool('met_hari_pico_v1', true);
  }

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
    final featured = featuredToys();
    final arcade = arcadeToys();
    final racing = racingSkillToys();
    final puzzles = puzzleBrainToys();
    final stress = stressBusterToys();
    final sensory = sensoryPlayToys();
    final smart = smartPlayToys();
    final allToys = curatedAllToys();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'WONDERPLAY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Hidden debug entry: long-press the counter chip.
                        IconButton(
                          tooltip: ref.watch(sensoryPreferencesProvider
                                  .select((p) => p.muted))
                              ? 'Turn sound on'
                              : 'Turn sound off',
                          icon: Icon(
                            ref.watch(sensoryPreferencesProvider
                                    .select((p) => p.muted))
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            final wasMuted = ref.read(sensoryPreferencesProvider
                                .select((p) => p.muted));
                            ref
                                .read(sensoryPreferencesProvider.notifier)
                                .toggleMuted();
                            if (wasMuted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                TonePlayer.instance
                                    .playCue(SoundCue.navigation);
                              });
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Activity insights',
                          icon: const Icon(Icons.insights_rounded,
                              color: Colors.white, size: 26),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ActivityInsightsScreen(),
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
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const ProfileWizardScreen(fullEditor: true),
                              ),
                            );
                            if (mounted) {
                              await _maybeShowMeetSheet();
                            }
                          },
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
                    const SizedBox(height: 3),
                    const Text('Play. Learn. Calm. Connect.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'A playful world where every child can explore, learn, and feel good.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.64),
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _HariGreeting(name: name),
          ),
          if (recents.isNotEmpty)
            SliverToBoxAdapter(
              child: _ContinueCard(toy: recents.first),
            ),
          const SliverToBoxAdapter(
            child: _ProgressCard(),
          ),
          SliverToBoxAdapter(
            child: _CoreDestinations(onPlay: _scrollToToys),
          ),
          if (featured.isNotEmpty)
            _RailSliver(title: 'Featured', emoji: '⭐', toys: featured),
          if (arcade.isNotEmpty)
            _RailSliver(title: 'Arcade', emoji: '🕹️', toys: arcade),
          if (racing.isNotEmpty)
            _RailSliver(title: 'Racing & Skill', emoji: '🏎️', toys: racing),
          if (stress.isNotEmpty)
            _RailSliver(title: 'Stress Buster', emoji: '🧘', toys: stress),
          if (puzzles.isNotEmpty)
            _RailSliver(title: 'Puzzles & Brain', emoji: '🧩', toys: puzzles),
          if (favorites.isNotEmpty)
            _RailSliver(title: 'Favorites', emoji: '\u2764\uFE0F', toys: favorites),
          if (recents.isNotEmpty)
            _RailSliver(title: 'Recently Played', emoji: '\u23F1\uFE0F', toys: recents),
          if (sensory.isNotEmpty)
            _RailSliver(title: 'Sensory Play', emoji: '🫧', toys: sensory),
          if (smart.isNotEmpty)
            _RailSliver(title: 'Smart Play', emoji: '🧠', toys: smart),
          const SliverToBoxAdapter(
            child: _AdventureRoadmapCard(),
          ),
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
                (context, i) => _ToyCard(toy: allToys[i]),
                childCount: allToys.length,
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

class _MeetHariPicoSheet extends StatefulWidget {
  const _MeetHariPicoSheet({required this.onEnterPlay});

  final VoidCallback onEnterPlay;

  @override
  State<_MeetHariPicoSheet> createState() => _MeetHariPicoSheetState();
}

class _MeetHariPicoSheetState extends State<_MeetHariPicoSheet> {
  final CompanionController _companion = CompanionController();

  @override
  void initState() {
    super.initState();
    _companion.setReaction(CompanionReaction.pair);
  }

  @override
  void dispose() {
    _companion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 180,
                height: 132,
                child: CompanionView(controller: _companion),
              ),
              const SizedBox(height: 8),
              const Text(
                'Meet Hari and Pico',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'They play with you, celebrate with you, and help you feel calm.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 14.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onEnterPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Enter Play World'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF06D6A0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A warm welcome from Hari and Pico — the first thing the child sees, so the
/// app feels like meeting a friend, not opening a menu.
class _HariGreeting extends StatefulWidget {
  const _HariGreeting({required this.name});
  final String name;

  @override
  State<_HariGreeting> createState() => _HariGreetingState();
}

class _HariGreetingState extends State<_HariGreeting> {
  final CompanionController _companion = CompanionController();

  @override
  void initState() {
    super.initState();
    _companion.setReaction(CompanionReaction.happy);
  }

  @override
  void dispose() {
    _companion.dispose();
    super.dispose();
  }

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
            SizedBox(
              width: 112,
              height: 94,
              child: CompanionView(
                controller: _companion,
                animate: true,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Hi, ${widget.name}!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                    Text('Hari and Pico are ready to explore with you.',
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

/// The core worlds of WonderPlay, always one tap from the front door. Large,
/// distinct cards so the home feels like a place to explore — and so a
/// non-reading child can navigate the whole app by colour and picture.
class _CoreDestinations extends StatelessWidget {
  const _CoreDestinations({required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    void go(Widget screen) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => screen),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text('Where to today?',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _DestinationCard(
                  emoji: '\u2B50',
                  label: 'Play',
                  subtitle: 'Games & toys',
                  colors: const <Color>[Color(0xFF9B5DE5), Color(0xFFF15BB5)],
                  onTap: onPlay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DestinationCard(
                  emoji: '\uD83C\uDF93',
                  label: 'Learn',
                  subtitle: 'Playful smarts',
                  colors: const <Color>[Color(0xFF06D6A0), Color(0xFF43E97B)],
                  onTap: () => go(const LearnScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DestinationCard(
                  emoji: '\uD83C\uDF0A',
                  label: 'Calm',
                  subtitle: 'Relax & breathe',
                  colors: const <Color>[Color(0xFF0891B2), Color(0xFF06D6A0)],
                  onTap: () => go(const CalmMeScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _DestinationCard(
                  emoji: '\uD83D\uDCAC',
                  label: 'Talk',
                  subtitle: 'Say it your way',
                  colors: const <Color>[Color(0xFF4361EE), Color(0xFF38B2F9)],
                  onTap: () => go(const TalkScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DestinationCard(
                  emoji: '\uD83C\uDF08',
                  label: 'Routines',
                  subtitle: 'Daily flow',
                  colors: const <Color>[Color(0xFFFF9E6D), Color(0xFFF7B801)],
                  onTap: () => go(const DailyLifeScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DestinationCard(
                  emoji: '\uD83D\uDDFA\uFE0F',
                  label: 'Adventure',
                  subtitle: 'Explore',
                  colors: const <Color>[Color(0xFF5E60CE), Color(0xFF4EA8DE)],
                  onTap: () => go(const AdventureHubScreen()),
                ),
              ),
            ],
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
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final String subtitle;
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
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.last.withOpacity(0.32),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                right: -6,
                bottom: -10,
                child: Text(emoji,
                    style: TextStyle(
                        fontSize: 56,
                        color: Colors.white.withOpacity(0.16))),
              ),
              Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900)),
                        ),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.82),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600)),
                      ],
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
    final best = GameScores.instance.best(toy.id);
    return GestureDetector(
      onTap: () => ToyUniverseScreen.open(context, ref, toy),
      onLongPress: () => _showPreview(context, ref),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161335),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    GameThumb(id: toy.id, color: toy.color, emoji: toy.emoji),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _HeartButton(
                        active: isFav,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(favoritesProvider.notifier).toggle(toy.id);
                        },
                      ),
                    ),
                    if (best > 0)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('\u2605 $best',
                              style: const TextStyle(
                                  color: Color(0xFFFFD166),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                      )
                    else if (toy.isNew)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: toy.color.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('New \u2728',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(toy.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(toy.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
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

/// A one-tap "Continue" hero for the most recently played toy, so the child
/// (or parent) can jump straight back into what they were enjoying.
class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.toy});
  final UniverseToy toy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => ToyUniverseScreen.open(context, ref, toy),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: <Color>[
                  toy.color.withOpacity(0.55),
                  toy.color.withOpacity(0.22),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black.withOpacity(0.25),
                  ),
                  child: Text(toy.emoji, style: const TextStyle(fontSize: 30)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Continue playing',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(toy.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The home progression banner — the child's level, an XP bar toward the next
/// level, and their record count. Tapping opens the achievements sheet.
class _ProgressCard extends ConsumerWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(playerProgressProvider);
    final unlocked = p.achievements.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showProgressSheet(context, p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: <Color>[Color(0x334CC9F0), Color(0x339B5DE5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: <Color>[Color(0xFF4CC9F0), Color(0xFF9B5DE5)],
                    ),
                  ),
                  child: Text('${p.level}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text('Level ${p.level}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Text('⭐ ${p.records}   🏅 $unlocked',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: p.levelProgress,
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFFD166)),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('${p.xpIntoLevel} / ${p.xpForLevel} XP to level ${p.level + 1}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showProgressSheet(BuildContext context, PlayerProgress p) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF16121F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('Level ${p.level}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('⭐ ${p.records} records   ·   🎮 ${p.plays} plays',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Achievements',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Flexible(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                childAspectRatio: 2.9,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: <Widget>[
                  for (final a in kAchievements)
                    _AchievementTile(
                        achievement: a,
                        unlocked: p.achievements.contains(a.id)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});
  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: unlocked
            ? const Color(0xFF06D6A0).withOpacity(0.18)
            : Colors.white.withOpacity(0.05),
        border: Border.all(
            color: unlocked ? const Color(0xFF06D6A0) : Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          Opacity(
            opacity: unlocked ? 1 : 0.35,
            child: Text(achievement.emoji,
                style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(achievement.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: unlocked ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                Text(unlocked ? 'Unlocked' : achievement.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: unlocked
                            ? const Color(0xFF06D6A0)
                            : Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
