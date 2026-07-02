import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import '../../models/communication_item.dart';
import 'communication_data.dart';

/// A high-frequency "core word" — always available, the way real AAC systems
/// keep a fixed fringe of the words children use most.
class _CoreWord {
  const _CoreWord(this.label, this.emoji);
  final String label;
  final String emoji;
}

const List<_CoreWord> _coreWords = <_CoreWord>[
  _CoreWord('I', '🙋'),
  _CoreWord('want', '👉'),
  _CoreWord('more', '➕'),
  _CoreWord('stop', '✋'),
  _CoreWord('help', '🆘'),
  _CoreWord('please', '🙏'),
  _CoreWord('yes', '👍'),
  _CoreWord('no', '👎'),
  _CoreWord('like', '⭐'),
  _CoreWord('finished', '🏁'),
];

/// A colour per category so the board is easy to scan — and friendly for a
/// child who reads pictures and colour before words.
const Map<String, Color> _categoryColor = <String, Color>{
  'Food': Color(0xFFFFA552),
  'Drink': Color(0xFF54A0FF),
  'Emotions': Color(0xFFFF6B9D),
  'Activities': Color(0xFF43E97B),
  'Places': Color(0xFF18C8C8),
  'Needs': Color(0xFFFF6B6B),
  'Family': Color(0xFFA55EEA),
  'Favorites': Color(0xFFFEC84D),
};

Color _colorFor(String category) => _categoryColor[category] ?? Colors.white;

/// One spoken token on the sentence strip.
class _Word {
  const _Word(this.label, this.emoji, this.color);
  final String label;
  final String emoji;
  final Color color;
}

/// Help Me Talk — a tap-to-speak AAC board designed for Harshiv.
///
/// Built around three realities: a hearing aid (so speech is mirrored *visually*
/// in a big bloom every time), a communication delay (so a single tap is an
/// instant voice — never a wait), and coloboma in the left eye (so targets are
/// large, central and high-contrast).
class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({super.key});

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> {
  final FlutterTts _tts = FlutterTts();
  String _category = kTalkCategories.first;
  final List<_Word> _strip = <_Word>[];

  String? _bloomText;
  String? _bloomEmoji;
  Color _bloomColor = Colors.white;
  Timer? _bloomTimer;

  @override
  void initState() {
    super.initState();
    _tts
      ..setSpeechRate(0.42)
      ..setPitch(1.05)
      ..setVolume(1.0);
  }

  Future<void> _speak(String text, {String? emoji, Color color = Colors.white}) async {
    HapticFeedback.mediumImpact();
    // Mirror the speech visually — this is how Harshiv "hears" it.
    _bloomTimer?.cancel();
    setState(() {
      _bloomText = text;
      _bloomEmoji = emoji;
      _bloomColor = color;
    });
    _bloomTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _bloomText = null);
    });
    await _tts.stop();
    await _tts.speak(text);
  }

  void _addWord(_Word word) {
    setState(() => _strip.add(word));
    // Instant voice — never await anything on the tap path.
    _speak(word.label, emoji: word.emoji, color: word.color);
  }

  void _speakSentence() {
    if (_strip.isEmpty) return;
    _speak(_strip.map((w) => w.label).join(' '), color: Colors.white);
  }

  void _backspace() {
    if (_strip.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _strip.removeLast());
  }

  void _clear() {
    if (_strip.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(_strip.clear);
  }

  @override
  void dispose() {
    _bloomTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = itemsForCategory(_category);
    final accent = _colorFor(_category);
    return HarshivScaffold(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              _topBar(),
              const SizedBox(height: 6),
              _sentenceStrip(),
              const SizedBox(height: 10),
              _coreWordRow(),
              const SizedBox(height: 12),
              _categoryBar(),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 168,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return _ItemTile(
                      item: item,
                      color: accent,
                      onTap: () => _addWord(_Word(item.label, item.emoji, accent)),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_bloomText != null) _SpeakBloom(text: _bloomText!, emoji: _bloomEmoji, color: _bloomColor),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const Text('Help Me Talk',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
      ],
    );
  }

  Widget _sentenceStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1.4),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SizedBox(
              height: 64,
              child: _strip.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tap a word to talk…',
                          style: TextStyle(color: Colors.white54, fontSize: 18)),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _strip.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _StripChip(word: _strip[i]),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          _StripAction(
            icon: Icons.backspace_rounded,
            tip: 'Undo last',
            enabled: _strip.isNotEmpty,
            onTap: _backspace,
          ),
          const SizedBox(width: 6),
          // The big "say it" button — the most important control on the screen.
          GestureDetector(
            onTap: _speakSentence,
            onLongPress: _clear,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF43E97B), Color(0xFF38B2F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF38B2F9).withOpacity(_strip.isEmpty ? 0 : 0.5),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Opacity(
                opacity: _strip.isEmpty ? 0.4 : 1,
                child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coreWordRow() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _coreWords.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final w = _coreWords[i];
          return _CoreChip(
            word: w,
            onTap: () => _addWord(_Word(w.label, w.emoji, const Color(0xFFB9C4FF))),
          );
        },
      ),
    );
  }

  Widget _categoryBar() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kTalkCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = kTalkCategories[i];
          final selected = cat == _category;
          final color = _colorFor(cat);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _category = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? color : Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: selected ? color : Colors.white24,
                  width: 1.4,
                ),
                boxShadow: selected
                    ? <BoxShadow>[BoxShadow(color: color.withOpacity(0.5), blurRadius: 16)]
                    : const <BoxShadow>[],
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: selected ? const Color(0xFF0B1026) : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A word chip on the sentence strip — picture *and* word together.
class _StripChip extends StatelessWidget {
  const _StripChip({required this.word});
  final _Word word;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: word.color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: word.color.withOpacity(0.7), width: 1.4),
      ),
      child: Row(
        children: <Widget>[
          Text(word.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 6),
          Text(word.label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }
}

class _StripAction extends StatelessWidget {
  const _StripAction({
    required this.icon,
    required this.tip,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String tip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: enabled ? Colors.white : Colors.white30, size: 24),
        ),
      ),
    );
  }
}

class _CoreChip extends StatelessWidget {
  const _CoreChip({required this.word, required this.onTap});
  final _CoreWord word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.4),
        ),
        child: Row(
          children: <Widget>[
            Text(word.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(word.label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

/// A communication tile — big picture, always-visible word, coloured ring,
/// and a clear press response (no sound required to know it worked).
class _ItemTile extends StatefulWidget {
  const _ItemTile({required this.item, required this.color, required this.onTap});
  final CommunicationItem item;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_pressed ? 0.26 : 0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.color.withOpacity(_pressed ? 0.95 : 0.55),
              width: _pressed ? 2.2 : 1.6,
            ),
            boxShadow: _pressed
                ? <BoxShadow>[BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 22)]
                : const <BoxShadow>[],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(widget.item.emoji, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(
                widget.item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-screen bloom that mirrors every spoken phrase in giant, high-contrast
/// type — so Harshiv *sees* his voice, hearing aid or not.
class _SpeakBloom extends StatelessWidget {
  const _SpeakBloom({required this.text, required this.emoji, required this.color});
  final String text;
  final String? emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey<String>(text),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          builder: (context, t, child) {
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
            );
          },
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1026).withOpacity(0.82),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: color.withOpacity(0.8), width: 2.4),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: color.withOpacity(0.45), blurRadius: 48, spreadRadius: 4),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (emoji != null) ...<Widget>[
                    Text(emoji!, style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: 10),
                  ] else ...<Widget>[
                    Icon(Icons.graphic_eq_rounded, color: color, size: 56),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
