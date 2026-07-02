import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../../services/ai/ai_provider.dart';
import '../../state/providers.dart';

/// Parent Copilot — a calm AI assistant for caregivers. Ask anything; get
/// likely causes, regulation ideas, communication prompts, and environment
/// tweaks. Backed by the same AI abstraction (mock offline by default).
class ParentCopilotScreen extends ConsumerStatefulWidget {
  const ParentCopilotScreen({super.key});

  @override
  ConsumerState<ParentCopilotScreen> createState() => _ParentCopilotScreenState();
}

class _ParentCopilotScreenState extends ConsumerState<ParentCopilotScreen> {
  final TextEditingController _controller = TextEditingController();
  CopilotReply? _reply;
  String? _question;
  bool _loading = false;

  static const List<String> _examples = <String>[
    'Harshiv screamed after school.',
    'He won\'t eat dinner tonight.',
    'Bedtime has been really hard.',
    'She covered her ears at the shop.',
  ];

  Future<void> _ask(String message) async {
    if (message.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _question = message.trim();
      _reply = null;
    });
    final name = ref.read(childNameProvider);
    final ai = await ref.read(aiProvider.future);
    final reply = await ai.assistCaregiver(
      CopilotRequest(message: message.trim(), context: 'Child name: $name'),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _reply = reply;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Text('Parent Copilot',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: <Widget>[
                if (_question != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14, left: 40),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4FACFE).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(_question!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (_loading) const _Thinking(),
                if (_reply != null) _ReplyCard(reply: _reply!),
                if (_question == null && !_loading) ...<Widget>[
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Tell me what happened. I am here to help, not to judge. 💙',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ),
                  const SizedBox(height: 8),
                  for (final e in _examples)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        onTap: () => _ask(e),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(e, style: const TextStyle(color: Colors.white))),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ask the copilot…',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (v) {
                _ask(v);
                _controller.clear();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            onPressed: () {
              _ask(_controller.text);
              _controller.clear();
            },
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Thinking it through…', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});
  final CopilotReply reply;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(reply.summary,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          _Section('Likely causes', '🔎', reply.likelyCauses),
          _Section('Calming ideas', '🌈', reply.regulationActivities),
          _Section('What to say', '💬', reply.communicationPrompts),
          _Section('Try changing', '🛋️', reply.environmentChanges),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.emoji, this.items);
  final String title;
  final String emoji;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$emoji  $title',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('•  ', style: TextStyle(color: Colors.white54)),
                  Expanded(child: Text(item, style: const TextStyle(color: Colors.white70))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
