import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import '../../state/providers.dart';
import 'models/life_models.dart';
import 'photo_store.dart';
import 'state/lifeskills_providers.dart';

/// Parents create their own family routines here — either by describing a goal
/// and letting the AI draft the steps, or by building steps by hand with emoji.
class CreateRoutineScreen extends ConsumerStatefulWidget {
  const CreateRoutineScreen({super.key});

  @override
  ConsumerState<CreateRoutineScreen> createState() =>
      _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends ConsumerState<CreateRoutineScreen> {
  final TextEditingController _goal = TextEditingController();
  final List<RoutineStep> _steps = <RoutineStep>[];
  String _emoji = '🌟';
  Color _accent = const Color(0xFF9B5DE5);
  bool _busy = false;

  static const _palette = <String>[
    '🌟', '🛒', '🚗', '🏫', '🍎', '🧴', '👕', '🦷', '🛁', '🍽️',
    '🎒', '🧸', '📚', '🎨', '⚽', '🌳', '🐶', '☀️', '🌙', '🧼',
  ];
  static const _accents = <Color>[
    Color(0xFF9B5DE5),
    Color(0xFF4CC9F0),
    Color(0xFF06D6A0),
    Color(0xFFFFD166),
    Color(0xFFEF476F),
    Color(0xFFFF7A00),
  ];

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final goal = _goal.text.trim();
    if (goal.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    List<RoutineStep> steps;
    try {
      final ai = await ref.read(aiProvider.future);
      final raw = await ai.complete(
        'Create a simple visual routine for an autistic child to "$goal". '
        'Reply as a short numbered list of 5 to 7 tiny concrete steps. '
        'Each step must be a short kind instruction of 3 to 8 words.',
        system: 'You design calm, literal, step-by-step routines for children.',
      );
      steps = _parse(raw, goal);
    } catch (_) {
      steps = _fallback(goal);
    }
    if (steps.length < 2) steps = _fallback(goal);
    setState(() {
      _steps
        ..clear()
        ..addAll(steps);
      _busy = false;
    });
  }

  List<RoutineStep> _parse(String raw, String goal) {
    final lines = raw
        .split(RegExp(r'[\n\r]+'))
        .map((l) => l.replaceAll(RegExp(r'^\s*\d+[\.\)]\s*'), '').trim())
        .where((l) => l.length > 2 && l.length < 90)
        .take(8)
        .toList();
    return <RoutineStep>[
      for (final l in lines)
        RoutineStep(
          title: _shortTitle(l),
          instruction: l,
          emoji: _guessEmoji(l),
          accent: _accent,
        ),
    ];
  }

  List<RoutineStep> _fallback(String goal) {
    return <RoutineStep>[
      RoutineStep(
          title: 'Get ready',
          instruction: 'We are going to $goal. Let\'s get ready.',
          emoji: '🌟',
          accent: _accent),
      RoutineStep(
          title: 'Stay close',
          instruction: 'Hold hands and stay together.',
          emoji: '🤝',
          accent: _accent),
      RoutineStep(
          title: 'Take a breath',
          instruction: 'If it feels loud, take a slow breath.',
          emoji: '🌬️',
          accent: _accent),
      RoutineStep(
          title: 'Do the thing',
          instruction: 'Now we do $goal, one step at a time.',
          emoji: _emoji,
          accent: _accent),
      RoutineStep(
          title: 'All done',
          instruction: 'Great job! We finished $goal.',
          emoji: '🎉',
          accent: _accent),
    ];
  }

  String _shortTitle(String s) {
    final words = s.split(' ');
    return words.take(3).join(' ');
  }

  String _guessEmoji(String s) {
    final t = s.toLowerCase();
    const map = <String, String>{
      'wash': '🧼', 'hand': '🧼', 'brush': '🦷', 'teeth': '🦷',
      'shoe': '👟', 'coat': '🧥', 'shirt': '👕', 'eat': '🍽️',
      'food': '🍎', 'car': '🚗', 'seat': '🚗', 'belt': '🚗',
      'shop': '🛒', 'cart': '🛒', 'pay': '💳', 'bag': '🛍️',
      'water': '💧', 'toilet': '🚽', 'potty': '🚽', 'sleep': '🌙',
      'bed': '🛏️', 'book': '📚', 'wait': '⏳', 'breath': '🌬️',
      'hand hold': '🤝', 'done': '🎉', 'finish': '🎉',
    };
    for (final e in map.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return _emoji;
  }

  void _addManual() {
    HapticFeedback.selectionClick();
    setState(() {
      _steps.add(RoutineStep(
        title: 'Step ${_steps.length + 1}',
        instruction: 'Tap to describe this step',
        emoji: _emoji,
        accent: _accent,
      ));
    });
  }

  void _editStep(int i) async {
    final controller = TextEditingController(text: _steps[i].instruction);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1836),
        title: const Text('Edit step', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'What happens in this step?',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _steps[i] = _steps[i].copyWith(
            instruction: result,
            title: _shortTitle(result),
            emoji: _guessEmoji(result),
          ));
    }
  }

  Future<void> _addPhoto(int i) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1B1836),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Add a photo for this step',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: Color(0xFF4CC9F0)),
              title: const Text('Take a photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF06D6A0)),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_steps[i].photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF476F)),
                title: const Text('Remove photo',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      _removePhoto(i);
      return;
    }
    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final path = await RoutinePhotoStore.pick(source);
    if (!mounted || path == null) return;
    setState(() => _steps[i] = _steps[i].copyWith(photoPath: path));
  }

  void _removePhoto(int i) {
    HapticFeedback.selectionClick();
    setState(() => _steps[i] = _steps[i].copyWith(clearPhoto: true));
  }

  void _save() {
    if (_goal.text.trim().isEmpty || _steps.isEmpty) return;
    HapticFeedback.mediumImpact();
    final routine = LifeRoutine(
      id: 'custom_${const Uuid().v4()}',
      title: _goal.text.trim(),
      subtitle: 'Our family routine',
      emoji: _emoji,
      gradient: <Color>[_accent, _accent.withOpacity(0.4)],
      steps: List<RoutineStep>.from(_steps),
      custom: true,
    );
    ref.read(customRoutinesProvider.notifier).add(routine);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: <Widget>[
                  _round(Icons.arrow_back_rounded,
                      () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  const Text('Create Routine',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: <Widget>[
                _field(),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Text('Icon:',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(_emoji, style: const TextStyle(fontSize: 26)),
                    const Spacer(),
                    Text('Colour:',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    ..._accents.map((c) => GestureDetector(
                          onTap: () => setState(() => _accent = c),
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: c.value == _accent.value
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2.5),
                            ),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 10),
                _emojiPalette(),
                const SizedBox(height: 16),
                _generateButton(),
                const SizedBox(height: 20),
                if (_steps.isNotEmpty) ...<Widget>[
                  Row(
                    children: <Widget>[
                      const Text('Steps',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addManual,
                        icon: const Icon(Icons.add_rounded,
                            color: Color(0xFF4CC9F0)),
                        label: const Text('Add',
                            style: TextStyle(color: Color(0xFF4CC9F0))),
                      ),
                    ],
                  ),
                  ..._steps.asMap().entries.map((e) => _stepTile(e.key)),
                ],
              ],
            ),
          ),
          if (_steps.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Material(
                  color: _accent,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _save,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.check_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Save Routine',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900)),
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

  Widget _field() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _goal,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'e.g. Going to the grocery store',
          hintStyle: TextStyle(color: Colors.white38),
          icon: Icon(Icons.edit_rounded, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _emojiPalette() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _palette.map((e) {
        final on = e == _emoji;
        return GestureDetector(
          onTap: () => setState(() => _emoji = e),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on
                  ? _accent.withOpacity(0.3)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: on ? Colors.white : Colors.white12, width: 1.5),
            ),
            child: Text(e, style: const TextStyle(fontSize: 22)),
          ),
        );
      }).toList(),
    );
  }

  Widget _generateButton() {
    return Material(
      color: const Color(0xFF9B5DE5),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : _generate,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_busy)
                const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
              else
                const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(_busy ? 'Thinking…' : 'Generate with AI',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepTile(int i) {
    final s = _steps[i];
    final hasPhoto = s.photoPath != null &&
        !kIsWeb &&
        File(s.photoPath!).existsSync();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(s.photoPath!),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          else
            Text(s.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${i + 1}. ${s.title}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                Text(s.instruction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              s.photoPath != null
                  ? Icons.image_rounded
                  : Icons.add_a_photo_rounded,
              color: s.photoPath != null
                  ? const Color(0xFF06D6A0)
                  : Colors.white54,
              size: 20,
            ),
            onPressed: () => _addPhoto(i),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded,
                color: Colors.white54, size: 20),
            onPressed: () => _editStep(i),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white38, size: 20),
            onPressed: () => setState(() => _steps.removeAt(i)),
          ),
        ],
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) {
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
