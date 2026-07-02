import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../../models/regulation_entry.dart';
import '../../models/sensory_profile.dart';
import '../../models/toy_meta.dart';
import '../../services/regulation/regulation_engine.dart';
import '../../state/providers.dart';

/// Analytics — the "Regulation Genome". Plain-language parent insights derived
/// entirely from on-device play & calm sessions.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(regulationLogProvider);
    final profile = ref.watch(sensoryProfileProvider);
    final ranking = ref.watch(toyRankingProvider);
    final insight = ref.watch(headlineInsightProvider);
    final engine = ref.watch(regulationEngineProvider);
    final triggers = engine.triggerFrequency(log);
    final hours = engine.bestRegulationHours(log);

    return HarshivScaffold(
      child: ListView(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Text('Regulation Genome',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          GlassCard(
            gradient: const LinearGradient(
              colors: <Color>[Color(0x3343E97B), Color(0x3338F9D7)],
            ),
            child: Row(
              children: <Widget>[
                const Text('🧬', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(insight,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          if (log.isEmpty) ...<Widget>[
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                children: <Widget>[
                  const Text('No sessions yet',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Play in the toybox or use Calm Me, and HARSHIVOS will '
                      'start learning what helps. Want a quick preview?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _seedDemo(ref),
                    icon: const Icon(Icons.auto_graph_rounded),
                    label: const Text('Generate sample insights'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          _CardTitle('Sensory profile', '👁️'),
          GlassCard(child: _SensoryRadar(profile: profile)),
          const SizedBox(height: 18),
          if (ranking.isNotEmpty) ...<Widget>[
            _CardTitle('What calms fastest', '🌈'),
            GlassCard(child: _ToyBars(ranking: ranking)),
            const SizedBox(height: 18),
          ],
          if (triggers.isNotEmpty) ...<Widget>[
            _CardTitle('Triggers to watch', '⚠️'),
            GlassCard(child: _TriggerList(triggers: triggers)),
            const SizedBox(height: 18),
          ],
          if (hours.isNotEmpty) ...<Widget>[
            _CardTitle('Best regulation times', '⏰'),
            GlassCard(child: _BestHours(hours: hours)),
            const SizedBox(height: 18),
          ],
          GlassCard(
            child: Row(
              children: <Widget>[
                const Icon(Icons.shield_moon_rounded, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${log.length} sessions recorded, all stored privately '
                      'on this device.',
                      style: const TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _seedDemo(WidgetRef ref) {
    final notifier = ref.read(regulationLogProvider.notifier);
    final samples = <(String, CalmMood, double, double)>[
      ('particle_galaxy', CalmMood.overwhelmed, 0.1, 0.85),
      ('water_ripples', CalmMood.anxious, 0.2, 0.8),
      ('particle_galaxy', CalmMood.frustrated, 0.2, 0.9),
      ('bubble_pop', CalmMood.frustrated, 0.25, 0.6),
      ('fluid_sim', CalmMood.sad, 0.3, 0.7),
      ('water_ripples', CalmMood.tired, 0.35, 0.75),
      ('fireworks', CalmMood.overwhelmed, 0.15, 0.5),
    ];
    for (final s in samples) {
      notifier.logSession(
        toyIds: <String>[s.$1],
        mood: s.$2,
        calmBefore: s.$3,
        calmAfter: s.$4,
      );
    }
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text, this.emoji);
  final String text;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text('$emoji  $text',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
    );
  }
}

class _SensoryRadar extends StatelessWidget {
  const _SensoryRadar({required this.profile});
  final SensoryProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 220,
          child: CustomPaint(
            painter: _RadarPainter(profile),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final c in SensoryChannel.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(c.label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.profile);
  final SensoryProfile profile;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 16;
    final channels = SensoryChannel.values;
    final n = channels.length;

    // Grid rings.
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white24;
    for (var r = 1; r <= 4; r++) {
      final path = Path();
      for (var i = 0; i <= n; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / n;
        final p = center + Offset(math.cos(a), math.sin(a)) * (radius * r / 4);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, grid);
    }

    // Data polygon.
    final fill = Paint()..color = const Color(0x6643E97B);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF43E97B);
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      final v = profile.scoreOf(channels[i]).clamp(0.05, 1.0);
      final p = center + Offset(math.cos(a), math.sin(a)) * radius * v;
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();
    canvas.drawPath(dataPath, fill);
    canvas.drawPath(dataPath, stroke);

    // Vertex dots.
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      final v = profile.scoreOf(channels[i]).clamp(0.05, 1.0);
      final p = center + Offset(math.cos(a), math.sin(a)) * radius * v;
      canvas.drawCircle(p, 4, Paint()..color = channels[i].color);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => true;
}

class _ToyBars extends StatelessWidget {
  const _ToyBars({required this.ranking});
  final List<ToyEffectiveness> ranking;

  @override
  Widget build(BuildContext context) {
    final top = ranking.take(5).toList();
    return Column(
      children: <Widget>[
        for (final t in top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                SizedBox(width: 28, child: Text(toyMetaById(t.toyId).emoji, style: const TextStyle(fontSize: 22))),
                Expanded(
                  flex: 3,
                  child: Text(toyMetaById(t.toyId).title,
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ((t.averageCalmDelta + 1) / 2).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.lerp(Colors.orangeAccent, const Color(0xFF43E97B),
                            ((t.averageCalmDelta + 1) / 2).clamp(0.0, 1.0))!,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TriggerList extends StatelessWidget {
  const _TriggerList({required this.triggers});
  final Map<CalmMood, int> triggers;

  @override
  Widget build(BuildContext context) {
    final entries = triggers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final e in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Text('${e.key.emoji}  ${e.key.label} ×${e.value}',
                style: const TextStyle(color: Colors.white)),
          ),
      ],
    );
  }
}

class _BestHours extends StatelessWidget {
  const _BestHours({required this.hours});
  final List<int> hours;

  String _fmt(int h) {
    final period = h < 12 ? 'am' : 'pm';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12$period';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.wb_sunny_rounded, color: Colors.amberAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Calming works best around ${hours.map(_fmt).join(', ')}.',
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
