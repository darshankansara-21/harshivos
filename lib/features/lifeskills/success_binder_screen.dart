import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import '../../state/providers.dart';
import 'avatar/avatar.dart';
import 'models/life_models.dart';
import 'state/lifeskills_providers.dart';

/// The **Success Binder / My Wins** — a warm, growing keepsake of proud
/// moments. Routines finished are captured automatically; parents can add
/// their own ("Tried a new food!", "Stayed calm at the dentist"). Fully
/// offline: everything lives in local storage.
class SuccessBinderScreen extends ConsumerWidget {
  const SuccessBinderScreen({super.key});

  static const _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _prettyDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    final name = (m >= 1 && m <= 12) ? _months[m - 1] : '';
    return '$name $d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wins = ref.watch(winsProvider);
    final config = ref.watch(avatarConfigProvider);
    final name = ref.watch(childNameProvider);

    return HarshivScaffold(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _header(context, config, name, wins.length),
          Expanded(
            child: wins.isEmpty
                ? _empty(name)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: wins.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _WinCard(
                      win: wins[i],
                      dateLabel: _prettyDate(wins[i].dateIso),
                      onDelete: () {
                        HapticFeedback.selectionClick();
                        ref.read(winsProvider.notifier).remove(wins[i].id);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(
      BuildContext context, AvatarConfig config, String name, int count) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 4),
        child: Row(
          children: <Widget>[
            _round(context, Icons.arrow_back_rounded,
                () => Navigator.of(context).maybePop()),
            const SizedBox(width: 6),
            SizedBox(
              width: 56,
              height: 56,
              child: AvatarWidget(
                config: config,
                pose: AvatarPose.cheer,
                emotion: AvatarEmotion.proud,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('My Wins',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  Text(
                    count == 0
                        ? 'Every win goes here'
                        : '$count proud ${count == 1 ? 'moment' : 'moments'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            _addButton(context),
          ],
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      return GestureDetector(
        onTap: () => _addWin(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFFD166), Color(0xFFFFB703)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, color: Color(0xFF1B1836), size: 20),
              SizedBox(width: 4),
              Text('Add',
                  style: TextStyle(
                      color: Color(0xFF1B1836), fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    });
  }

  Widget _round(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _empty(String name) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('🏆', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(
              "$name's wins will appear here",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Finish a routine, or tap Add to save a proud moment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addWin(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController();
    String emoji = '⭐';
    const choices = <String>[
      '⭐', '🎉', '🏆', '💪', '🍎', '🦷', '🚽', '👕', '🛁', '🤝', '😊', '🌟'
    ];
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1836),
          title: const Text('Add a win',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'What did they do? (e.g. Tried a new food)',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final e in choices)
                    GestureDetector(
                      onTap: () => setState(() => emoji = e),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: emoji == e
                              ? const Color(0xFFFFD166).withOpacity(0.3)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: emoji == e
                                ? const Color(0xFFFFD166)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      await ref
          .read(winsProvider.notifier)
          .addMoment(controller.text.trim(), emoji: emoji);
    }
  }
}

class _WinCard extends StatelessWidget {
  const _WinCard(
      {required this.win, required this.dateLabel, required this.onDelete});

  final Win win;
  final String dateLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        win.photoPath != null && File(win.photoPath!).existsSync();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: win.accent.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: win.accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: hasPhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(File(win.photoPath!),
                        width: 52, height: 52, fit: BoxFit.cover),
                  )
                : Text(win.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(win.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                if (win.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(win.note,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(dateLabel,
                      style: TextStyle(
                          color: win.accent, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded,
                color: Colors.white38, size: 20),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
