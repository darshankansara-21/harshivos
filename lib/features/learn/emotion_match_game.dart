import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An adaptive emotion-recognition game. Difficulty (number of choices) rises
/// after a streak of correct answers and eases after mistakes — so it stays in
/// the "just right" zone without ever feeling like a test.
class EmotionMatchGame extends StatefulWidget {
  const EmotionMatchGame({super.key});

  @override
  State<EmotionMatchGame> createState() => _EmotionMatchGameState();
}

class _EmotionMatchGameState extends State<EmotionMatchGame>
    with SingleTickerProviderStateMixin {
  static const List<(String emoji, String name)> _emotions = <(String, String)>[
    ('😊', 'happy'),
    ('😢', 'sad'),
    ('😡', 'angry'),
    ('😨', 'scared'),
    ('😴', 'tired'),
    ('😮', 'surprised'),
    ('😍', 'excited'),
    ('😌', 'calm'),
  ];

  final math.Random _rnd = math.Random();
  int _difficulty = 2; // number of choices (2..5)
  int _streak = 0;
  int _score = 0;
  late (String, String) _target;
  late List<(String, String)> _choices;
  bool _justWrong = false;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final pool = [..._emotions]..shuffle(_rnd);
    _choices = pool.take(_difficulty).toList();
    _target = _choices[_rnd.nextInt(_choices.length)];
    _choices.shuffle(_rnd);
    _justWrong = false;
  }

  void _pick((String, String) choice) {
    if (choice == _target) {
      HapticFeedback.mediumImpact();
      setState(() {
        _score++;
        _streak++;
        if (_streak % 3 == 0 && _difficulty < 5) _difficulty++;
        _newRound();
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _streak = 0;
        if (_difficulty > 2) _difficulty--;
        _justWrong = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1140),
      appBar: AppBar(
        title: const Text('Find the feeling'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('⭐ $_score',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Text('Tap the face that is',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 20)),
              const SizedBox(height: 8),
              Text(_target.$2,
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
              if (_justWrong)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('Try again — you can do it! 💪',
                      style: TextStyle(color: Colors.amberAccent)),
                ),
              const Spacer(),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (final c in _choices)
                    GestureDetector(
                      onTap: () => _pick(c),
                      child: Container(
                        width: 110,
                        height: 110,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.white.withOpacity(0.10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(c.$1, style: const TextStyle(fontSize: 64)),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text('Level $_difficulty',
                  style: const TextStyle(color: Colors.white38)),
            ],
          ),
        ),
      ),
    );
  }
}
