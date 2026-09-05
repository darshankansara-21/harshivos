import 'package:flutter/material.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';

/// Caregiver Guide — a curated library of common, evidence-informed strategies
/// for hard moments. Fully offline and static: NOT AI, not a personalized
/// analysis of your child, and not medical advice. Pick a situation to see
/// gentle ideas you can try.
class CaregiverGuideScreen extends StatelessWidget {
  const CaregiverGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Text('Caregiver Guide',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 2, 8, 12),
            child: Text(
                'Common, evidence-informed strategies for hard moments. These are '
                'general curated ideas — not AI, and not medical advice.',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: <Widget>[
                for (final g in _guides)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GuideCard(guide: g),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Every child is different. If you are worried about safety, '
                  'development, or health, talk to a doctor or therapist.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One curated situation and the strategies that commonly help.
class _Guide {
  const _Guide(
    this.title,
    this.emoji,
    this.summary, {
    required this.causes,
    required this.calming,
    required this.saying,
    required this.environment,
  });
  final String title;
  final String emoji;
  final String summary;
  final List<String> causes;
  final List<String> calming;
  final List<String> saying;
  final List<String> environment;
}

const List<_Guide> _guides = <_Guide>[
  _Guide(
    'Meltdown after school',
    '🏫',
    'Often sensory or transition overload — very common and not a discipline '
        'problem. The goal is co-regulation, not correction.',
    causes: <String>[
      'Accumulated sensory load across the school day',
      'Hard transition from a structured to an open environment',
      'Hunger, thirst, or tiredness',
      'A big feeling that is hard to put into words',
    ],
    calming: <String>[
      'Open Calm Me and pick a slow, low-stimulation toy for a minute or two',
      'Offer deep-pressure input — a firm hug or a weighted toy',
      'Dim the lights and lower noise for ten minutes',
      'Keep demands to zero until the body settles',
    ],
    saying: <String>[
      'Offer two choices instead of open questions: "water or snack?"',
      'Use the Talk board so they can point to the feeling',
      'Name it for them: "You look frustrated. That is okay."',
    ],
    environment: <String>[
      'Build a predictable after-school wind-down routine',
      'Prepare a calm, low-stimulation corner',
      'Offer a snack and water before any demands',
    ],
  ),
  _Guide(
    'Won\'t eat dinner',
    '🍽️',
    'Food refusal is often about sensory sensitivity or control, not '
        'stubbornness. Pressure usually makes it harder.',
    causes: <String>[
      'Texture, smell, temperature, or colour sensitivity',
      'Feeling full, tired, or overstimulated',
      'A need for predictability or control at mealtimes',
    ],
    calming: <String>[
      'Keep mealtimes calm and low-pressure — no forcing or bargaining',
      'Offer one familiar "safe food" alongside anything new',
      'Let them explore new food by touch or smell with no demand to eat',
    ],
    saying: <String>[
      'Offer a clear choice: "carrots or cucumber?"',
      'Use First-Then: "First two bites, then music."',
      'Praise trying, not finishing',
    ],
    environment: <String>[
      'Reduce noise and screens at the table',
      'Serve small portions so the plate is not overwhelming',
      'Keep a steady mealtime rhythm day to day',
    ],
  ),
  _Guide(
    'Hard bedtime',
    '🌙',
    'Sleep is easier with a predictable, calming wind-down and fewer '
        'surprises near bedtime.',
    causes: <String>[
      'Too much stimulation or screen time before bed',
      'An unpredictable or rushed bedtime routine',
      'Worry, or difficulty switching the body "off"',
    ],
    calming: <String>[
      'Use a Visual Timer so the wind-down is predictable',
      'Try slow breathing together with a calm toy',
      'Offer deep pressure — a weighted blanket or firm hug',
    ],
    saying: <String>[
      'Walk through the steps: "bath, teeth, story, sleep."',
      'Use First-Then: "First story, then lights out."',
      'Keep words few, warm, and the same each night',
    ],
    environment: <String>[
      'Dim lights an hour before bed and lower noise',
      'Keep the same order of steps every night',
      'Remove bright screens from the wind-down',
    ],
  ),
  _Guide(
    'Overwhelmed in public',
    '🛒',
    'Shops and busy places pile on noise, light, and crowds. A quick exit '
        'plan and sensory tools help.',
    causes: <String>[
      'Bright lights, echo, crowds, and unpredictable noise',
      'Too long without a break',
      'No clear plan for what happens next',
    ],
    calming: <String>[
      'Step outside or to a quiet corner for a reset',
      'Offer headphones, a fidget, or a favourite comfort item',
      'Keep the trip short and end before overload builds',
    ],
    saying: <String>[
      'Preview the plan: "three things, then we go."',
      'Offer a choice to give a sense of control',
      'Name the feeling calmly and stay close',
    ],
    environment: <String>[
      'Go at quieter times of day',
      'Bring noise-reducing headphones and a comfort item',
      'Agree a quiet-signal you both understand',
    ],
  ),
  _Guide(
    'Big feelings, hard to calm',
    '🌊',
    'When feelings are big, connection comes before any teaching. Stay calm '
        'and let the wave pass.',
    causes: <String>[
      'An overwhelmed nervous system that cannot yet self-regulate',
      'A feeling that is too big for words',
      'Sensory overload or an unmet need',
    ],
    calming: <String>[
      'Lower your own voice and slow your movements',
      'Offer calm choices, not questions or demands',
      'Try a slow, rhythmic activity together',
    ],
    saying: <String>[
      'Validate first: "That was really hard. I am here."',
      'Keep language short and gentle',
      'Wait for calm before talking it through',
    ],
    environment: <String>[
      'Reduce noise, light, and the number of people nearby',
      'Give space but stay available',
      'Return to a predictable routine afterwards',
    ],
  ),
  _Guide(
    'Change in routine',
    '🔄',
    'Unexpected change is genuinely hard. Predictability and preview reduce '
        'the stress.',
    causes: <String>[
      'A surprise or last-minute change to the plan',
      'Not knowing what happens next',
      'Losing a comforting, expected step',
    ],
    calming: <String>[
      'Preview the change with a Social Story or Visual Schedule',
      'Keep one familiar anchor in the day the same',
      'Allow extra time and lower other demands',
    ],
    saying: <String>[
      'Explain simply and early: "Today is different because…"',
      'Use First-Then to show the new order',
      'Acknowledge it is hard, then show what stays the same',
    ],
    environment: <String>[
      'Show the change visually rather than only in words',
      'Reintroduce the normal routine as soon as you can',
      'Give warnings before each transition',
    ],
  ),
];

/// A curated situation card that expands to show the strategies.
class _GuideCard extends StatefulWidget {
  const _GuideCard({required this.guide});
  final _Guide guide;

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    return GlassCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(g.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(g.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: Colors.white70),
            ],
          ),
          if (_open) ...<Widget>[
            const SizedBox(height: 10),
            Text(g.summary,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            _Section('Likely causes', '🔎', g.causes),
            _Section('Calming ideas', '🌈', g.calming),
            _Section('What to say', '💬', g.saying),
            _Section('Try changing', '🛋️', g.environment),
          ],
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
