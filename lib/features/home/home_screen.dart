import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../../state/providers.dart';
import '../analytics/analytics_screen.dart';
import '../antistress/antistress_hub_screen.dart';
import '../calm/calm_me_screen.dart';
import '../choices/choice_board_screen.dart';
import '../feelings/feelings_screen.dart';
import '../firstthen/first_then_screen.dart';
import '../learn/learn_screen.dart';
import '../parent/parent_copilot_screen.dart';
import '../play/play_hub_screen.dart';
import '../schedule/visual_schedule_screen.dart';
import '../stories/social_stories_screen.dart';
import '../talk/talk_screen.dart';
import '../timer/visual_timer_screen.dart';

/// A destination on the home toybox.
class _Destination {
  const _Destination(this.title, this.subtitle, this.emoji, this.gradient, this.builder);
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradient;
  final WidgetBuilder builder;
}

/// The magical home screen: large floating glass cards over a living backdrop.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static final List<_Destination> _destinations = <_Destination>[
    _Destination('Calm Me', 'One tap to feel better', '🌈', AppColors.calmGradient,
        (_) => const CalmMeScreen()),
    _Destination('Help Me Talk', 'Tap to speak', '🗣️', AppColors.talkGradient,
        (_) => const TalkScreen()),
    _Destination('Antistress', '21 fidget toys', '🫧',
        const <Color>[Color(0xFFEF476F), Color(0xFFF7B801)],
        (_) => const AntistressHubScreen()),
    _Destination('Play & Explore', '14 sensory toys', '🎮', AppColors.playGradient,
        (_) => const PlayHubScreen()),
    _Destination('My Day', 'Picture routine', '📅',
        const <Color>[Color(0xFF06D6A0), Color(0xFF118AB2)],
        (_) => const VisualScheduleScreen()),
    _Destination('First — Then', 'First this, then that', '➡️',
        const <Color>[Color(0xFF4361EE), Color(0xFFF7B801)],
        (_) => const FirstThenScreen()),
    _Destination('How I Feel', 'Name big feelings', '😊',
        const <Color>[Color(0xFF9B5DE5), Color(0xFFF15BB5)],
        (_) => const FeelingsScreen()),
    _Destination('Timer', 'See time left', '⏲️',
        const <Color>[Color(0xFF43E97B), Color(0xFFFB7185)],
        (_) => const VisualTimerScreen()),
    _Destination('I Choose', 'Show what I want', '👉',
        const <Color>[Color(0xFFFF9E00), Color(0xFF06D6A0)],
        (_) => const ChoiceBoardScreen()),
    _Destination('Social Stories', 'Practice new places', '📖', AppColors.storyGradient,
        (_) => const SocialStoriesScreen()),
    _Destination('Learn', 'Playful micro-games', '🧠', AppColors.learnGradient,
        (_) => const LearnScreen()),
    _Destination('Parent Copilot', 'AI for caregivers', '👨‍👩‍👦', AppColors.parentGradient,
        (_) => const ParentCopilotScreen()),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(childNameProvider);
    return HarshivScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _Greeting(name: name)),
          SliverPadding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _FloatingCard(
                  destination: _destinations[i],
                  index: i,
                ),
                childCount: _destinations.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'morning' : hour < 18 ? 'afternoon' : 'evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Good $part,',
                    style: const TextStyle(color: Colors.white70, fontSize: 18)),
                Text('$name 🌟',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Insights',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AnalyticsScreen()),
            ),
            icon: const Icon(Icons.insights_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

/// A floating glass card that gently bobs on its own rhythm.
class _FloatingCard extends StatefulWidget {
  const _FloatingCard({required this.destination, required this.index});
  final _Destination destination;
  final int index;

  @override
  State<_FloatingCard> createState() => _FloatingCardState();
}

class _FloatingCardState extends State<_FloatingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3200 + widget.index * 260),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.destination;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = math.sin(_controller.value * math.pi * 2) * 6;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: GlassCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: d.builder),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: d.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: d.gradient.last.withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(d.emoji, style: const TextStyle(fontSize: 34)),
            ),
            const Spacer(),
            Text(d.title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(d.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
