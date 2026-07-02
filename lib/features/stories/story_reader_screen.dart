import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/social_story.dart';

/// Reads a generated social story page-by-page with narration and a gentle
/// "Practice Mode" prompt on the final page.
class StoryReaderScreen extends StatefulWidget {
  const StoryReaderScreen({super.key, required this.story});

  final SocialStory story;

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  final PageController _pages = PageController();
  final FlutterTts _tts = FlutterTts();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _tts
      ..setSpeechRate(0.42)
      ..setPitch(1.05);
    WidgetsBinding.instance.addPostFrameCallback((_) => _narrate(0));
  }

  Future<void> _narrate(int i) async {
    await _tts.stop();
    await _tts.speak(widget.story.pages[i].text);
  }

  @override
  void dispose() {
    _tts.stop();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.story.pages;
    final isLast = _index == pages.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF120B2E),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(widget.story.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.replay_rounded, color: Colors.white),
                  onPressed: () => _narrate(_index),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: pages.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _narrate(i);
                },
                itemBuilder: (context, i) => _StoryPageView(page: pages[i], index: i, total: pages.length),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  _Dots(count: pages.length, index: _index),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      if (isLast) {
                        _showPracticeMode(context);
                      } else {
                        _pages.nextPage(
                            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                      }
                    },
                    icon: Icon(isLast ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded),
                    label: Text(isLast ? 'Practice' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPracticeMode(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1240),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('🎭', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            const Text('Practice Mode',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Let\'s act out "${widget.story.situation}" together. '
                'You can pause anytime. You are doing great. 🌟',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pages.jumpToPage(0);
              },
              child: const Text('Read it again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryPageView extends StatelessWidget {
  const _StoryPageView({required this.page, required this.index, required this.total});
  final SocialStoryPage page;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: double.infinity,
            height: 240,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFFA709A), Color(0xFFFEE140)],
              ),
            ),
            child: Text(page.emoji, style: const TextStyle(fontSize: 96)),
          ),
          const SizedBox(height: 28),
          Text(page.text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.4, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
