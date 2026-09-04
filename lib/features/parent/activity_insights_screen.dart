import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import '../../state/providers.dart';

/// Activity Insights — a private, on-device summary of what the child actually
/// did. Deterministic aggregation of the local event log (NOT AI, no cloud).
/// Framed as gentle observations, never clinical conclusions.
class ActivityInsightsScreen extends ConsumerWidget {
  const ActivityInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(childNameProvider);
    final i = ref.watch(activityInsightsProvider);
    return HarshivScaffold(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const Expanded(
                  child: Text('Activity Insights',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                ),
                const Icon(Icons.lock_rounded, color: Colors.white54, size: 20),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 2, 8, 12),
              child: Text('Private, on this device. Gentle observations — not advice.',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
            ),
            if (!i.hasData)
              _EmptyState(name: name)
            else ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _StatTile(
                        big: '${i.eventsToday}',
                        label: 'activities today',
                        color: const Color(0xFF43E97B)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                        big: '${i.minutes7d}',
                        label: 'minutes this week',
                        color: const Color(0xFF4CC9F0)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _StatTile(
                        big: '${i.routinesCompleted7d}',
                        label: 'routines finished',
                        color: const Color(0xFFFF9E6D)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                        big: '${i.calmCompleted7d}',
                        label: 'calm sessions',
                        color: const Color(0xFF9B8CFF)),
                  ),
                ],
              ),
              _ChipsSection(
                  title: '$name recently enjoyed',
                  emoji: '🧸',
                  entries: i.topActivities),
              _ChipsSection(
                  title: 'Words used most',
                  emoji: '💬',
                  entries: i.topWords),
              _ChipsSection(
                  title: 'Feelings shared',
                  emoji: '❤️',
                  entries: i.feelings),
              if (i.activeHours.isNotEmpty)
                _ChipsSection(
                    title: 'Most active times',
                    emoji: '🕒',
                    entries: i.activeHours
                        .map((h) => MapEntry(_hourLabel(h), 0))
                        .toList()),
            ],
            const SizedBox(height: 20),
            Text(
              'These notes come only from play on this device. HarshivOS does not '
              'diagnose or provide medical advice.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  static String _hourLabel(int h) {
    final am = h < 12;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 ${am ? 'am' : 'pm'}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: <Widget>[
          const Text('🌱', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text('Insights will grow as $name plays',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Play a few toys, try a calm activity, or use Talk — then come back '
            'to see gentle patterns.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.big, required this.label, required this.color});
  final String big;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: <Color>[color.withOpacity(0.30), color.withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(big,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 13)),
        ],
      ),
    );
  }
}

class _ChipsSection extends StatelessWidget {
  const _ChipsSection(
      {required this.title, required this.emoji, required this.entries});
  final String title;
  final String emoji;
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text('$emoji  $title',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries.map((e) {
            final showCount = e.value > 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(showCount ? '${e.key} · ${e.value}' : e.key,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            );
          }).toList(),
        ),
      ],
    );
  }
}
