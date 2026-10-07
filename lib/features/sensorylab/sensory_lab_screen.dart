import 'package:flutter/material.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../antistress/antistress_player_screen.dart';
import 'experiences/aurora_paint.dart';
import 'experiences/fluid_flow.dart';
import 'experiences/magnet_play.dart';
import 'experiences/particle_galaxy.dart';
import 'experiences/sand_zen.dart';
import 'experiences/slime.dart';

/// One world-class sensory experience in the lab.
class _Lab {
  const _Lab(this.title, this.subtitle, this.emoji, this.glow, this.builder);
  final String title;
  final String subtitle;
  final String emoji;
  final Color glow;
  final Widget Function() builder;
}

/// Sensory Lab 2.0 — a gallery of premium, physics-driven sensory experiences
/// you can lose yourself in. Each one is fully interactive and full-screen.
class SensoryLabScreen extends StatelessWidget {
  const SensoryLabScreen({super.key});

  static final List<_Lab> _labs = <_Lab>[
    _Lab('Liquid Light', 'Swirl glowing fluid', '💧',
        const Color(0xFF4CC9F0), FluidFlowExperience.new),
    _Lab('Galaxy', 'Bend the stars', '🌌',
        const Color(0xFF9B5DE5), ParticleGalaxyExperience.new),
    _Lab('Slime', 'Stretch & squish', '🫠',
        const Color(0xFF06D6A0), SlimeExperience.new),
    _Lab('Aurora', 'Paint the night sky', '🌈',
        const Color(0xFF36E0C0), AuroraPaintExperience.new),
    _Lab('Zen Sand', 'Rake calm patterns', '🏝️',
        const Color(0xFFFFB703), SandZenExperience.new),
    _Lab('Magnets', 'Pull the iron dust', '🧲',
        const Color(0xFFEF476F), MagnetPlayExperience.new),
  ];

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text('Sensory Lab',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(width: 10),
                          Text('🔭', style: TextStyle(fontSize: 26)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.95,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _LabTile(lab: _labs[i]),
                childCount: _labs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabTile extends StatelessWidget {
  const _LabTile({required this.lab});
  final _Lab lab;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: lab.glow,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AntistressPlayerScreen(
            toy: lab.builder(),
            title: lab.title,
            emoji: lab.emoji,
          ),
        ),
      ),
      padding: const EdgeInsets.all(18),
      // This grid tile's height is fixed by the parent SliverGrid's
      // childAspectRatio (0.95) — it never grows to fit its content. At a
      // large accessibility TextScaler the icon circle (and its emoji Text)
      // and the title/subtitle text block both scale up with it and
      // genuinely overflowed that fixed height (334px at 2.5x), the same
      // bug class already fixed in play_hub's _ToyTile. FittedBox(fit:
      // scaleDown) around both scales each down just enough to keep fitting
      // the fixed tile height, while still growing (up to that limit) for a
      // child who needs bigger text.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      lab.glow.withOpacity(0.9),
                      lab.glow.withOpacity(0.4),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                        color: lab.glow.withOpacity(0.5),
                        blurRadius: 22,
                        spreadRadius: 1),
                  ],
                ),
                child: Text(lab.emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  // A bare FittedBox gives its child unbounded width; fixing
                  // the inner Column's width to the tile's real available
                  // width before scaling keeps the normal layout intact.
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(lab.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(lab.subtitle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
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
