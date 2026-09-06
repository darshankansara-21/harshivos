import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../experiences/experience_catalog.dart';
import '../../models/activity_event.dart';
import '../../state/providers.dart';
import '../lifeskills/avatar/avatar.dart';
import '../lifeskills/avatar/hari_pico_scene.dart';
import '../lifeskills/state/lifeskills_providers.dart';
import '../stories/social_stories_screen.dart';
import 'adventure_engine.dart';

class AdventureHubScreen extends ConsumerWidget {
  const AdventureHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(childAvatarProfileProvider);
    final played = ref.watch(activityLogProvider).where((e) =>
        e.type == ActivityType.adventurePlayed ||
        e.target.startsWith('adv_')).length;
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
                const Expanded(
                  child: Text('Adventures',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('Played $played',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 14),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: AvatarWidget(
                        config: profile.avatar,
                        pose: AvatarPose.wave,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('${profile.name} joins Hari and Pico',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Play, practice daily life, and rehearse stories.',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: _StoryPracticeCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SocialStoriesScreen(),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: _ExperienceTruthCard(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final exp = kAdventureExperiences[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AdventureTile(experience: exp),
                  );
                },
                childCount: kAdventureExperiences.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryPracticeCard extends StatelessWidget {
  const _StoryPracticeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0x4024C6DC), Color(0x406A5AE0)],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.16),
            ),
            child: const Text('📖', style: TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Story Practice',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text('Create a personalized social story with your child name.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Colors.white70),
        ],
      ),
    );
  }
}

class _AdventureTile extends StatelessWidget {
  const _AdventureTile({required this.experience});
  final AdventureExperience experience;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdventurePlayScreen(experience: experience),
        ),
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          experience.gradient.first.withOpacity(0.42),
          experience.gradient.last.withOpacity(0.18),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.16),
            ),
            child: Text(experience.emoji, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(experience.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(experience.subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill_rounded,
              color: Colors.white, size: 34),
        ],
      ),
    );
  }
}

class AdventurePlayScreen extends ConsumerStatefulWidget {
  const AdventurePlayScreen({super.key, required this.experience});

  final AdventureExperience experience;

  @override
  ConsumerState<AdventurePlayScreen> createState() => _AdventurePlayScreenState();
}

class _AdventurePlayScreenState extends ConsumerState<AdventurePlayScreen> {
  int _step = 0;
  String _reply = '';
  late final DateTime _started;

  @override
  void initState() {
    super.initState();
    _started = DateTime.now();
  }

  Future<void> _finish() async {
    final sec = DateTime.now().difference(_started).inSeconds;
    await ref.read(activityLogProvider.notifier).log(
          ActivityType.adventurePlayed,
          widget.experience.id,
          seconds: sec,
          label: widget.experience.title,
        );
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1240),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('🎉', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            const Text('Adventure complete!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Great teamwork with Hari and Pico.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.8))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Back to Adventures'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(childAvatarProfileProvider);
    final steps = widget.experience.steps;
    final current = steps[_step];
    final done = _step >= steps.length - 1;
    return HarshivScaffold(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(widget.experience.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
              ),
              Text('${_step + 1}/${steps.length}',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    widget.experience.gradient.first.withOpacity(0.34),
                    widget.experience.gradient.last.withOpacity(0.16),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 170,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: HariPicoScene(moment: current.moment),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: <Widget>[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: 90,
                                height: 90,
                                child: AvatarWidget(
                                  config: profile.avatar,
                                  pose: AvatarPose.wave,
                                  emotion: AvatarEmotion.happy,
                                ),
                              ),
                              Text(profile.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(current.prompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      for (final c in current.choices)
                        ActionChip(
                          label: Text(c.label),
                          onPressed: () => setState(() => _reply = c.reply),
                          labelStyle: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                          backgroundColor: Colors.white.withOpacity(0.14),
                          shape: StadiumBorder(
                            side: BorderSide(color: Colors.white.withOpacity(0.24)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_reply.isNotEmpty)
                    Text(_reply,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.86),
                            fontWeight: FontWeight.w600)),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() => _reply = '');
                        if (done) {
                          _finish();
                          return;
                        }
                        setState(() => _step++);
                      },
                      icon: Icon(done
                          ? Icons.celebration_rounded
                          : Icons.arrow_forward_rounded),
                      label: Text(done ? 'Finish adventure' : 'Next moment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperienceTruthCard extends StatelessWidget {
  const _ExperienceTruthCard();

  @override
  Widget build(BuildContext context) {
    final rows = ExperienceCatalog.build();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Experience roadmap truth',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final row in rows)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Text(
                    '${row.category.name}: ${row.current}/${row.capacity}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}