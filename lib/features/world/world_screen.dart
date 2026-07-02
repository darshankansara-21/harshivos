import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../analytics/analytics_screen.dart';
import '../antistress/antistress_hub_screen.dart';
import '../calm/calm_me_screen.dart';
import '../choices/choice_board_screen.dart';
import '../feelings/feelings_screen.dart';
import '../firstthen/first_then_screen.dart';
import '../learn/learn_screen.dart';
import '../lifeskills/daily_life_screen.dart';
import '../parent/parent_copilot_screen.dart';
import '../play/play_hub_screen.dart';
import '../schedule/visual_schedule_screen.dart';
import '../sensorylab/sensory_lab_screen.dart';
import '../stories/social_stories_screen.dart';
import '../talk/talk_screen.dart';
import '../timer/visual_timer_screen.dart';
import 'objects/bubble_machine.dart';
import 'objects/calendar_board.dart';
import 'objects/cloud_mobile.dart';
import 'objects/cozy_house.dart';
import 'objects/music_flower.dart';
import 'objects/owl_lamp.dart';
import 'objects/signpost.dart';
import 'objects/story_book.dart';
import 'objects/telescope.dart';
import 'objects/toy_phone.dart';
import 'objects/toy_shelf.dart';
import 'objects/toy_train.dart';
import 'objects/treasure_chest.dart';
import 'objects/wall_clock.dart';
import 'world_ambient.dart';
import 'world_portal.dart';

/// One discoverable object placed in the world.
class _Spot {
  const _Spot({
    required this.fx,
    required this.fy,
    required this.sizeFactor,
    required this.label,
    required this.glow,
    required this.builder,
    required this.child,
    this.bob = 4.2,
    this.phase = 0,
  });

  /// Fractional centre position (0..1) within the scene.
  final double fx;
  final double fy;

  /// Object box size as a fraction of the scene's shorter side.
  final double sizeFactor;
  final String label;
  final Color glow;

  /// The feature screen this object opens.
  final WidgetBuilder builder;

  /// The living art object.
  final Widget child;
  final double bob;
  final double phase;
}

/// HARSHIVOS' home is not a menu — it is a place. The child enters a magical
/// treehouse at dusk and *discovers* every feature by touching a living object:
/// a bubble machine to breathe, a toy phone to talk, a storybook to read, a
/// train to learn, a cloud to feel, an owl who fetches a grown-up. The therapy
/// is invisible; the play is everything.
class WorldScreen extends ConsumerWidget {
  const WorldScreen({super.key});

  static const List<_Spot> _spots = <_Spot>[
    // ---- Row 1 (upper) ----
    _Spot(
      fx: 0.11, fy: 0.25, sizeFactor: 0.21, bob: 4.8, phase: 0.0,
      label: 'Feelings', glow: Color(0xFF9B5DE5),
      child: CloudMobileObject(), builder: _b0,
    ),
    _Spot(
      fx: 0.30, fy: 0.24, sizeFactor: 0.22, bob: 5.2, phase: 0.2,
      label: 'Stories', glow: Color(0xFFF7B801),
      child: StoryBookObject(), builder: _b1,
    ),
    _Spot(
      fx: 0.50, fy: 0.24, sizeFactor: 0.28, bob: 5.6, phase: 0.45,
      label: 'My Daily Life', glow: Color(0xFFFF9E6D),
      child: CozyHouseObject(), builder: _b13,
    ),
    _Spot(
      fx: 0.70, fy: 0.24, sizeFactor: 0.21, bob: 4.4, phase: 0.5,
      label: 'For Grown-ups', glow: Color(0xFFFFB37B),
      child: OwlLampObject(), builder: _b2,
    ),
    _Spot(
      fx: 0.89, fy: 0.27, sizeFactor: 0.20, bob: 4.0, phase: 0.7,
      label: 'Sensory Lab', glow: Color(0xFF36E0C0),
      child: TelescopeObject(), builder: _b3,
    ),
    // ---- Row 2 (middle) ----
    _Spot(
      fx: 0.16, fy: 0.53, sizeFactor: 0.22, bob: 3.8, phase: 0.3,
      label: 'Talk', glow: Color(0xFFFF6B6B),
      child: ToyPhoneObject(), builder: _b4,
    ),
    _Spot(
      fx: 0.38, fy: 0.52, sizeFactor: 0.22, bob: 4.6, phase: 0.9,
      label: 'Music', glow: Color(0xFFF15BB5),
      child: MusicFlowerObject(), builder: _b5,
    ),
    _Spot(
      fx: 0.60, fy: 0.53, sizeFactor: 0.23, bob: 5.0, phase: 0.1,
      label: 'Bubbles', glow: Color(0xFF4CC9F0),
      child: BubbleMachineObject(), builder: _b6,
    ),
    _Spot(
      fx: 0.83, fy: 0.55, sizeFactor: 0.21, bob: 4.2, phase: 0.6,
      label: 'Timer', glow: Color(0xFF43E97B),
      child: WallClockObject(), builder: _b7,
    ),
    // ---- Row 3 (lower) ----
    _Spot(
      fx: 0.11, fy: 0.79, sizeFactor: 0.21, bob: 4.4, phase: 0.4,
      label: 'First — Then', glow: Color(0xFF4361EE),
      child: SignpostObject(), builder: _b8,
    ),
    _Spot(
      fx: 0.30, fy: 0.80, sizeFactor: 0.23, bob: 3.9, phase: 0.8,
      label: 'Learn', glow: Color(0xFF06D6A0),
      child: ToyTrainObject(), builder: _b9,
    ),
    _Spot(
      fx: 0.50, fy: 0.80, sizeFactor: 0.22, bob: 4.7, phase: 0.2,
      label: 'Fidgets', glow: Color(0xFFEF476F),
      child: FidgetShelfObject(), builder: _b10,
    ),
    _Spot(
      fx: 0.70, fy: 0.79, sizeFactor: 0.21, bob: 4.1, phase: 0.55,
      label: 'My Day', glow: Color(0xFF118AB2),
      child: CalendarBoardObject(), builder: _b11,
    ),
    _Spot(
      fx: 0.89, fy: 0.80, sizeFactor: 0.22, bob: 4.9, phase: 0.35,
      label: 'I Choose', glow: Color(0xFFFFD166),
      child: TreasureChestObject(), builder: _b12,
    ),
  ];

  // Route builders (kept as const top-level tear-off targets).
  static Widget _b0(BuildContext c) => const FeelingsScreen();
  static Widget _b1(BuildContext c) => const SocialStoriesScreen();
  static Widget _b2(BuildContext c) => const ParentCopilotScreen();
  static Widget _b3(BuildContext c) => const SensoryLabScreen();
  static Widget _b4(BuildContext c) => const TalkScreen();
  static Widget _b5(BuildContext c) => const PlayHubScreen();
  static Widget _b6(BuildContext c) => const CalmMeScreen();
  static Widget _b7(BuildContext c) => const VisualTimerScreen();
  static Widget _b8(BuildContext c) => const FirstThenScreen();
  static Widget _b9(BuildContext c) => const LearnScreen();
  static Widget _b10(BuildContext c) => const AntistressHubScreen();
  static Widget _b11(BuildContext c) => const VisualScheduleScreen();
  static Widget _b12(BuildContext c) => const ChoiceBoardScreen();
  static Widget _b13(BuildContext c) => const DailyLifeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(childNameProvider);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(child: WorldAmbient()),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final shortest = w < h ? w : h;
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    for (final spot in _spots)
                      _placed(context, spot, w, h, shortest),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: _Greeting(name: name),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _CornerButton(
                            icon: Icons.insights_rounded,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const AnalyticsScreen()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _placed(
    BuildContext context,
    _Spot spot,
    double w,
    double h,
    double shortest,
  ) {
    final size = (shortest * spot.sizeFactor).clamp(96.0, 230.0);
    final left = spot.fx * w - size / 2;
    final top = spot.fy * h - size / 2;
    return Positioned(
      left: left,
      top: top,
      child: WorldPortal(
        size: size,
        label: spot.label,
        glow: spot.glow,
        bobSeconds: spot.bob,
        phase: spot.phase,
        onActivate: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: spot.builder),
        ),
        child: spot.child,
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
    final part = hour < 12
        ? 'morning'
        : hour < 18
            ? 'afternoon'
            : 'evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Good $part, $name',
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 26,
              fontWeight: FontWeight.w800,
              shadows: const <Shadow>[
                Shadow(color: Colors.black54, blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Touch anything you like  ✨',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              shadows: const <Shadow>[
                Shadow(color: Colors.black54, blurRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerButton extends StatelessWidget {
  const _CornerButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.10),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 22),
        ),
      ),
    );
  }
}

