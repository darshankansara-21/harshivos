import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/audio/tone_player.dart';
import '../companion/companion.dart';

/// An adaptive counting game: a playful cluster of objects appears and the
/// child taps how many there are. The count range and number of choices grow
/// after a streak and ease after a miss, so it stays in the "just right" zone.
class CountingGameScreen extends StatefulWidget {
  const CountingGameScreen({super.key});

  @override
  State<CountingGameScreen> createState() => _CountingGameScreenState();
}

class _CountingGameScreenState extends State<CountingGameScreen> {
  static const List<String> _objects = <String>[
    '🍎', '⭐', '🐟', '🎈', '🌸', '🚗', '🐢', '🍪', '🦋', '🍓',
  ];

  final math.Random _rnd = math.Random();
  final CompanionController _companion = CompanionController();

  int _difficulty = 1; // 1..4 → wider count range + more choices
  int _streak = 0;
  int _score = 0;
  late int _count;
  late String _object;
  late List<int> _choices;
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

  int get _maxCount => <int>[3, 5, 7, 10][_difficulty.clamp(1, 4) - 1];
  int get _optionCount => <int>[3, 3, 4, 4][_difficulty.clamp(1, 4) - 1];

  void _newRound() {
    _object = _objects[_rnd.nextInt(_objects.length)];
    _count = 1 + _rnd.nextInt(_maxCount);
    final options = <int>{_count};
    while (options.length < _optionCount) {
      final delta = _rnd.nextInt(3) + 1;
      final candidate = _rnd.nextBool() ? _count + delta : _count - delta;
      if (candidate >= 1 && candidate <= _maxCount) options.add(candidate);
    }
    _choices = options.toList()..shuffle(_rnd);
    _justWrong = false;
  }

  void _pick(int choice) {
    if (choice == _count) {
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
      backgroundColor: const Color(0xFF10233A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('How many?'),
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
                  Text('Count the ${_object}s, then tap the number',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Center(
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          alignment: WrapAlignment.center,
                          runAlignment: WrapAlignment.center,
                          children: <Widget>[
                            for (var i = 0; i < _count; i++)
                              Text(_object,
                                  style: const TextStyle(fontSize: 52)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 26,
                    child: _justWrong
                        ? const Text('Count again — take your time! 💪',
                            style: TextStyle(color: Colors.amberAccent))
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      for (final n in _choices)
                        GestureDetector(
                          onTap: () => _pick(n),
                          child: Container(
                            width: 76,
                            height: 76,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF43E97B),
                                  Color(0xFF38B2F9),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Text('$n',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
