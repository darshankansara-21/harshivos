import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/activity_event.dart';
import '../../services/audio/tone_player.dart';
import '../../services/voice/hari_voice.dart';
import '../../state/providers.dart';

/// One learnable thing — an emoji (or glyph) and the word for it.
class LearnItem {
  const LearnItem(this.emoji, this.label);
  final String emoji;
  final String label;
}

/// A content pack that the shared [LearningGameScreen] turns into a real,
/// adaptive, no-fail identification game. Many packs → many genuine games from
/// one engine (content + mechanics + difficulty + reinforcement).
class LearnPack {
  const LearnPack({
    required this.id,
    required this.title,
    required this.emoji,
    required this.gradient,
    required this.prompt,
    required this.items,
  });

  final String id;
  final String title;
  final String emoji;
  final List<Color> gradient;

  /// How the round is phrased, e.g. 'Find the'. The item label is appended and
  /// spoken by Hari, so a child who cannot read can still play by listening.
  final String prompt;
  final List<LearnItem> items;
}

/// The reusable learning engine: "listen/look, then tap the one that matches".
///
/// Difficulty (number of choices) rises after a streak and eases after a miss,
/// so it stays in the "just right" zone. There is no fail state — a wrong tap
/// simply offers a gentle "try again" and the round continues. Completing a
/// session logs a single [ActivityType.gamePlayed] event (real tracking).
class LearningGameScreen extends ConsumerStatefulWidget {
  const LearningGameScreen({super.key, required this.pack});
  final LearnPack pack;

  @override
  ConsumerState<LearningGameScreen> createState() => _LearningGameScreenState();
}

class _LearningGameScreenState extends ConsumerState<LearningGameScreen> {
  static const int _roundsTarget = 8;

  final math.Random _rnd = math.Random();
  int _difficulty = 2; // number of choices (2..6)
  int _streak = 0;
  int _score = 0;
  int _round = 0;
  bool _justWrong = false;
  bool _done = false;
  late LearnItem _target;
  late List<LearnItem> _choices;
  late final DateTime _startedAt;

  int get _maxChoices => math.min(6, widget.pack.items.length);

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _newRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakPrompt());
  }

  double get _volume => ref.read(sensoryPreferencesProvider).volumeScale;

  void _speakPrompt() {
    HariVoice.instance.speak('${widget.pack.prompt} ${_target.label}',
        volume: _volume);
  }

  void _newRound() {
    final pool = <LearnItem>[...widget.pack.items]..shuffle(_rnd);
    _choices = pool.take(_difficulty.clamp(2, _maxChoices)).toList();
    _target = _choices[_rnd.nextInt(_choices.length)];
    _choices.shuffle(_rnd);
    _justWrong = false;
  }

  void _pick(LearnItem choice) {
    if (_done) return;
    if (choice.label == _target.label) {
      HapticFeedback.mediumImpact();
      TonePlayer.instance.playNote(3 + _streak); // gentle rising reward
      setState(() {
        _score++;
        _streak++;
        _round++;
        if (_streak % 3 == 0 && _difficulty < _maxChoices) _difficulty++;
        if (_round >= _roundsTarget) {
          _finish();
        } else {
          _newRound();
        }
      });
      if (!_done) _speakPrompt();
    } else {
      HapticFeedback.selectionClick();
      setState(() {
        _streak = 0;
        if (_difficulty > 2) _difficulty--;
        _justWrong = true;
      });
    }
  }

  void _finish() {
    _done = true;
    final seconds = DateTime.now().difference(_startedAt).inSeconds;
    ref.read(activityLogProvider.notifier).log(
          ActivityType.gamePlayed,
          widget.pack.id,
          seconds: seconds,
          label: widget.pack.title,
        );
  }

  void _playAgain() {
    setState(() {
      _difficulty = 2;
      _streak = 0;
      _score = 0;
      _round = 0;
      _done = false;
      _newRound();
    });
    _speakPrompt();
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    return Scaffold(
      backgroundColor: const Color(0xFF1B1140),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(pack.title),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('⭐ $_score',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _done ? _buildDone(pack) : _buildRound(pack),
      ),
    );
  }

  Widget _buildRound(LearnPack pack) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          _ProgressDots(total: _roundsTarget, done: _round),
          const Spacer(),
          Text(pack.prompt,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 20)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _speakPrompt,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(_target.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.volume_up_rounded, color: Colors.white54),
              ],
            ),
          ),
          SizedBox(
            height: 26,
            child: _justWrong
                ? const Text('Try again — you can do it! 💪',
                    style: TextStyle(color: Colors.amberAccent))
                : const SizedBox.shrink(),
          ),
          const Spacer(),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final c in _choices)
                _ChoiceTile(item: c, gradient: pack.gradient, onTap: () => _pick(c)),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDone(LearnPack pack) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: pack.gradient),
            ),
            child: const Text('🌟', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 20),
          const Text('You did it!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('$_score out of $_roundsTarget',
              style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _playAgain,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Play again'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
              ),
              child: const Text('All done',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.total, required this.done});
  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < total; i++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done
                  ? const Color(0xFF43E97B)
                  : Colors.white.withOpacity(0.18),
            ),
          ),
      ],
    );
  }
}

class _ChoiceTile extends StatefulWidget {
  const _ChoiceTile(
      {required this.item, required this.gradient, required this.onTap});
  final LearnItem item;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  State<_ChoiceTile> createState() => _ChoiceTileState();
}

class _ChoiceTileState extends State<_ChoiceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 112,
          height: 112,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withOpacity(0.10),
            border: Border.all(
              color: widget.gradient.first.withOpacity(0.7),
              width: 1.6,
            ),
          ),
          child: Text(widget.item.emoji, style: const TextStyle(fontSize: 60)),
        ),
      ),
    );
  }
}

/// The curated content packs. Each becomes a real game via [LearningGameScreen].
const List<LearnPack> kLearnPacks = <LearnPack>[
  LearnPack(
    id: 'learn_colors',
    title: 'Colors',
    emoji: '🎨',
    gradient: <Color>[Color(0xFFFF6B6B), Color(0xFFFFD93D)],
    prompt: 'Find',
    items: <LearnItem>[
      LearnItem('🔴', 'red'),
      LearnItem('🟠', 'orange'),
      LearnItem('🟡', 'yellow'),
      LearnItem('🟢', 'green'),
      LearnItem('🔵', 'blue'),
      LearnItem('🟣', 'purple'),
      LearnItem('🟤', 'brown'),
      LearnItem('⚫', 'black'),
      LearnItem('⚪', 'white'),
      LearnItem('🩷', 'pink'),
    ],
  ),
  LearnPack(
    id: 'learn_animals',
    title: 'Animals',
    emoji: '🐶',
    gradient: <Color>[Color(0xFF43E97B), Color(0xFF38F9D7)],
    prompt: 'Find the',
    items: <LearnItem>[
      LearnItem('🐶', 'dog'),
      LearnItem('🐱', 'cat'),
      LearnItem('🐮', 'cow'),
      LearnItem('🐷', 'pig'),
      LearnItem('🐔', 'chicken'),
      LearnItem('🐸', 'frog'),
      LearnItem('🐴', 'horse'),
      LearnItem('🐑', 'sheep'),
      LearnItem('🐰', 'rabbit'),
      LearnItem('🦆', 'duck'),
      LearnItem('🐟', 'fish'),
      LearnItem('🐘', 'elephant'),
    ],
  ),
  LearnPack(
    id: 'learn_shapes',
    title: 'Shapes',
    emoji: '🔷',
    gradient: <Color>[Color(0xFF4FACFE), Color(0xFF00F2FE)],
    prompt: 'Find the',
    items: <LearnItem>[
      LearnItem('⭕', 'circle'),
      LearnItem('🟥', 'square'),
      LearnItem('🔺', 'triangle'),
      LearnItem('⭐', 'star'),
      LearnItem('❤️', 'heart'),
      LearnItem('🔷', 'diamond'),
    ],
  ),
  LearnPack(
    id: 'learn_numbers',
    title: 'Numbers',
    emoji: '🔢',
    gradient: <Color>[Color(0xFFA18CD1), Color(0xFFFBC2EB)],
    prompt: 'Find the number',
    items: <LearnItem>[
      LearnItem('1️⃣', 'one'),
      LearnItem('2️⃣', 'two'),
      LearnItem('3️⃣', 'three'),
      LearnItem('4️⃣', 'four'),
      LearnItem('5️⃣', 'five'),
      LearnItem('6️⃣', 'six'),
      LearnItem('7️⃣', 'seven'),
      LearnItem('8️⃣', 'eight'),
      LearnItem('9️⃣', 'nine'),
      LearnItem('🔟', 'ten'),
    ],
  ),
  LearnPack(
    id: 'learn_letters',
    title: 'Letters',
    emoji: '🔤',
    gradient: <Color>[Color(0xFFFF9E6D), Color(0xFFFFC371)],
    prompt: 'Find the letter',
    items: <LearnItem>[
      LearnItem('A', 'A'),
      LearnItem('B', 'B'),
      LearnItem('C', 'C'),
      LearnItem('D', 'D'),
      LearnItem('E', 'E'),
      LearnItem('F', 'F'),
      LearnItem('G', 'G'),
      LearnItem('H', 'H'),
      LearnItem('O', 'O'),
      LearnItem('S', 'S'),
    ],
  ),
  LearnPack(
    id: 'learn_food',
    title: 'Food',
    emoji: '🍎',
    gradient: <Color>[Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    prompt: 'Find the',
    items: <LearnItem>[
      LearnItem('🍎', 'apple'),
      LearnItem('🍌', 'banana'),
      LearnItem('🍇', 'grapes'),
      LearnItem('🥕', 'carrot'),
      LearnItem('🍞', 'bread'),
      LearnItem('🥛', 'milk'),
      LearnItem('🍪', 'cookie'),
      LearnItem('🧀', 'cheese'),
      LearnItem('🍓', 'strawberry'),
      LearnItem('🍚', 'rice'),
    ],
  ),
  LearnPack(
    id: 'learn_objects',
    title: 'Things',
    emoji: '🚗',
    gradient: <Color>[Color(0xFF9B8CFF), Color(0xFF6D8BFF)],
    prompt: 'Find the',
    items: <LearnItem>[
      LearnItem('🚗', 'car'),
      LearnItem('⚽', 'ball'),
      LearnItem('📚', 'book'),
      LearnItem('🪑', 'chair'),
      LearnItem('🛏️', 'bed'),
      LearnItem('🚪', 'door'),
      LearnItem('👟', 'shoe'),
      LearnItem('🧦', 'sock'),
      LearnItem('🪥', 'toothbrush'),
      LearnItem('🥄', 'spoon'),
    ],
  ),
];
