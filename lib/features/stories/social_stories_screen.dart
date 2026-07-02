import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../../services/ai/ai_provider.dart';
import '../../state/providers.dart';
import 'story_reader_screen.dart';

/// Social Stories — caregiver enters a situation; the AI layer writes a gentle,
/// first-person story with illustrations + narration to rehearse it.
class SocialStoriesScreen extends ConsumerStatefulWidget {
  const SocialStoriesScreen({super.key});

  @override
  ConsumerState<SocialStoriesScreen> createState() => _SocialStoriesScreenState();
}

class _SocialStoriesScreenState extends ConsumerState<SocialStoriesScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;

  static const List<String> _suggestions = <String>[
    'Dentist', 'School', 'Haircut', 'Travel', 'Doctor', 'Temple', 'Birthday Party',
  ];

  Future<void> _generate(String situation) async {
    if (situation.trim().isEmpty) return;
    setState(() => _loading = true);
    final name = ref.read(childNameProvider);
    final ai = await ref.read(aiProvider.future);
    final story = await ai.generateStory(
      StoryRequest(situation: situation.trim(), childName: name),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StoryReaderScreen(story: story)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: ListView(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Text('Social Stories',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 16),
            child: Text('Tell us about a new place or event. We will make a calm '
                'story to practice together.',
                style: TextStyle(color: Colors.white70)),
          ),
          GlassCard(
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Going to the dentist',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    icon: Icon(Icons.auto_stories_rounded, color: Colors.white70),
                  ),
                  onSubmitted: _generate,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : () => _generate(_controller.text),
                    icon: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_loading ? 'Writing your story…' : 'Create story'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Popular situations',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: _loading ? null : () => _generate(s),
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  backgroundColor: Colors.white.withOpacity(0.12),
                  shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.2))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
