import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/audio/tone_player.dart';
import '../../companion/companion.dart';

class SnackStudioToy extends StatefulWidget {
  const SnackStudioToy({super.key});

  @override
  State<SnackStudioToy> createState() => _SnackStudioToyState();
}

class _SnackStudioToyState extends State<SnackStudioToy> {
  static const List<(String, String)> _bases = <(String, String)>[
    ('Bread', '🍞'), ('Taco', '🌮'), ('Bowl', '🥣'),
  ];
  static const List<(String, String)> _toppings = <(String, String)>[
    ('Berry', '🍓'), ('Banana', '🍌'), ('Cheese', '🧀'), ('Leaf', '🥬'),
  ];

  (String, String)? _base;
  final List<(String, String)> _chosen = <(String, String)>[];
  bool _served = false;
  int _snacksMade = 0;

  void _chooseBase((String, String) base) {
    HapticFeedback.selectionClick();
    TonePlayer.instance.playCue(SoundCue.selection);
    setState(() {
      _base = base;
      _chosen.clear();
      _served = false;
    });
  }

  void _addTopping((String, String) topping) {
    if (_base == null || _served || _chosen.length >= 4) return;
    HapticFeedback.lightImpact();
    TonePlayer.instance.playPop(_chosen.length / 4);
    setState(() => _chosen.add(topping));
  }

  void _serve() {
    if (_base == null || _chosen.isEmpty) return;
    HapticFeedback.mediumImpact();
    TonePlayer.instance.playCue(SoundCue.milestone);
    const CompanionEventNotification(ExperienceEvent.correctAnswer).dispatch(context);
    setState(() => _served = true);
  }

  void _feed() {
    HapticFeedback.heavyImpact();
    TonePlayer.instance.playCue(SoundCue.completion);
    const CompanionEventNotification(ExperienceEvent.gameCompleted).dispatch(context);
    setState(() {
      _snacksMade++;
      _base = null;
      _chosen.clear();
      _served = false;
    });
  }

  void _reset() {
    HapticFeedback.selectionClick();
    setState(() {
      _base = null;
      _chosen.clear();
      _served = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: const Color(0xFF102C2A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 76, 20, 150),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text('Pocket Picnic', style: TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                  Text('Served $_snacksMade', style: const TextStyle(
                      color: Color(0xFFFFD166), fontWeight: FontWeight.w700)),
                  IconButton(
                    tooltip: 'Start over',
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      AnimatedScale(
                        scale: _served ? 1.12 : 1,
                        duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 260),
                        child: Text(
                          _base == null
                              ? '🧺'
                              : '${_base!.$2}${_chosen.map((item) => item.$2).join()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 54),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _base == null
                            ? 'Pick a snack base'
                            : _served
                                ? 'Ready for Hari and Pico!'
                                : _chosen.isEmpty ? 'Add a topping' : 'Add more or serve it',
                        style: const TextStyle(color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_base == null)
                _ChoiceRow(items: _bases, onChoose: _chooseBase)
              else if (!_served)
                _ChoiceRow(items: _toppings, onChoose: _addTopping),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _served
                      ? _feed
                      : (_base != null && _chosen.isNotEmpty ? _serve : null),
                  icon: Icon(_served ? Icons.restaurant_rounded : Icons.room_service_rounded),
                  label: Text(_served ? 'Feed Hari and Pico' : 'Serve snack'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.items, required this.onChoose});

  final List<(String, String)> items;
  final ValueChanged<(String, String)> onChoose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final item in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                button: true,
                label: item.$1,
                child: InkWell(
                  onTap: () => onChoose(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 82,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(item.$2, style: const TextStyle(fontSize: 28)),
                        Text(item.$1, style: const TextStyle(
                            color: Color(0xFF153B38), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}