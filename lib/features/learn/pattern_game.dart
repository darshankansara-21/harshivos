import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/audio/tone_player.dart';
import '../companion/companion.dart';

/// An adaptive pattern game: a repeating sequence is shown with the last item
/// hidden, and the child taps what comes next. The pattern length and unit
/// grow after a streak and ease after a miss.
class PatternGameScreen extends StatefulWidget {
  const PatternGameScreen({super.key});

  @override
  State<PatternGameScreen> createState() => _PatternGameScreenState();
}

class _PatternGameScreenState extends State<PatternGameScreen> {
  static const List<String> _tokens = <String>[
    '🔴', '🔵', '🟡', '🟢', '🟣', '🟠',
  ];

  final math.Random _rnd = math.Random();
  final CompanionController _companion = CompanionController();

  int _difficulty = 1; // 1..4 → longer unit + more choices
  int _streak = 0;
  int _score = 0;
  late List<String> _sequence; // visible items (last is the "?")
  late String _answer;
  late List<String> _choices;
  bool _justWrong = false;

  @override
  void initState() {
    super.initState();
    _companion.setReaction(CompanionReaction.curious);
    _newRound();
  }

  @override
  void dispose() {
    _companion.dispose();
    super.dispose();
  }

  // Repeating-unit length: 2 for easy (ABAB), growing to 3 (ABCABC).
  int get _unit => _difficulty < 3 ? 2 : 3;
  int get _optionCount => <int>[2, 3, 3, 4][_difficulty.clamp(1, 4) - 1];
  int get _reveal => <int>[3, 4, 5, 6][_difficulty.clamp(1, 4) - 1];

  void _newRound() {
    final palette = [..._tokens]..shuffle(_rnd);
    final unit = palette.take(_unit).toList();
    final full = <String>[
      for (var i = 0; i < _reveal + 1; i++) unit[i % unit.length],
    ];
    _answer = full[_reveal];
    _sequence = full.sublist(0, _reveal);
    final options = <String>{_answer};
    while (options.length < _optionCount) {
      options.add(_tokens[_rnd.nextInt(_tokens.length)]);
    }
    _choices = options.toList()..shuffle(_rnd);
    _justWrong = false;
  }

  void _pick(String choice) {
    if (choice == _answer) {
      _companion.reactToEvent(ExperienceEvent.correctAnswer);
      HapticFeedback.mediumImpact();
      TonePlayer.instance.playCue(SoundCue.learnGood);
      setState(() {
        _score++;
        _streak++;
        if (_streak % 3 == 0 && _difficulty < 4) _difficulty++;
        if (_score > 0 && _score % 8 == 0) {
          _companion.reactToEvent(ExperienceEvent.gameCompleted);
          TonePlayer.instance.playCue(SoundCue.completion);
        }
        _newRound();
      });
    } else {
      _companion.reactToEvent(ExperienceEvent.incorrectAnswer);
      HapticFeedback.selectionClick();
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      setState(() {
        _streak = 0;
        if (_difficulty > 1) _difficulty--;
        _justWrong = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1140),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('What comes next?'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Level $_difficulty',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
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
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  const Spacer(),
                  Text('Finish the pattern',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      for (final t in _sequence)
                        Text(t, style: const TextStyle(fontSize: 46)),
                      Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white54, width: 2),
                        ),
                        child: const Text('?',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 26,
                    child: _justWrong
                        ? const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('Look at the colors again! 💪',
                                style: TextStyle(color: Colors.amberAccent)),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      for (final c in _choices)
                        GestureDetector(
                          onTap: () => _pick(c),
                          child: Container(
                            width: 92,
                            height: 92,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white.withOpacity(0.10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child:
                                Text(c, style: const TextStyle(fontSize: 52)),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 8,
              width: 140,
              height: 120,
              child: IgnorePointer(
                child: CompanionView(controller: _companion),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
