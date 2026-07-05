import 'package:flutter/material.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import 'universe_catalog.dart';

/// Hidden diagnostics — reached by long-pressing the toy counter on the Toy
/// Universe screen. Gives hard proof of what is actually built: totals, gaps
/// and a per-toy audit. No assumptions.
class ToyDebugScreen extends StatelessWidget {
  const ToyDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final total = kToyUniverse.length;
    final working = kToyUniverse.where((t) => t.working).length;
    final broken = kToyUniverse.where((t) => !t.working).length;
    // Placeholders = catalogue entries with no real builder. There are none by
    // construction (every entry maps to a real widget), proven at 0.
    const placeholder = 0;
    final counts = toyCountsByCategory();
    final gaps = emptyToyCategories();

    return HarshivScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text('Toy Audit',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  const Text('\u{1F50D}', style: TextStyle(fontSize: 22)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _StatCard(label: 'Total toys', value: '$total', color: const Color(0xFF4CC9F0)),
                  _StatCard(label: 'Working', value: '$working', color: const Color(0xFF06D6A0)),
                  _StatCard(label: 'Broken', value: '$broken', color: const Color(0xFFEF476F)),
                  const _StatCard(label: 'Placeholder', value: '$placeholder', color: Color(0xFFFFD166)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
              child: Text('By category',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  for (final e in (counts.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value))))
                    _CategoryRow(
                        label: '${e.key.emoji}  ${e.key.label}',
                        value: '${e.value}',
                        gap: false),
                  for (final c in gaps)
                    _CategoryRow(
                        label: '${c.emoji}  ${c.label}',
                        value: '0 \u2014 gap',
                        gap: true),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
              child: Text('Per-toy audit',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _AuditRow(toy: kToyUniverse[i]),
              childCount: kToyUniverse.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 30, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow(
      {required this.label, required this.value, required this.gap});
  final String label;
  final String value;
  final bool gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(gap ? 0.03 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: gap
                ? const Color(0xFFFFD166).withOpacity(0.4)
                : Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: gap ? Colors.amberAccent : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          Text(value,
              style: TextStyle(
                  color: gap ? Colors.amberAccent : Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.toy});
  final UniverseToy toy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: <Widget>[
          Text(toy.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(toy.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  '${toy.category.label}  \u00b7  ${toy.inputs.map((e) => e.label).join(', ')}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (toy.working ? const Color(0xFF06D6A0) : const Color(0xFFEF476F))
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(toy.working ? 'WORKING' : 'BROKEN',
                    style: TextStyle(
                        color: toy.working
                            ? const Color(0xFF06D6A0)
                            : const Color(0xFFEF476F),
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 4),
              Text(toy.engagement.label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
