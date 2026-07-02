import 'dart:async';

import '../../models/social_story.dart';
import 'ai_provider.dart';

/// Fully-offline AI provider.
///
/// Generates warm, on-brand content from templates so the entire app is
/// usable with zero API keys — the default in [ai_config.json]. Swapping in a
/// live provider later changes nothing for call-sites.
class MockAiProvider implements AiProvider {
  @override
  String get name => 'mock';

  Future<void> get _thinking =>
      Future<void>.delayed(const Duration(milliseconds: 450));

  @override
  Future<String> complete(String prompt, {String? system}) async {
    await _thinking;
    return 'Here is a gentle, supportive response based on: "$prompt".';
  }

  @override
  Future<String> expandPhrase(String basePhrase) async {
    await _thinking;
    final trimmed = basePhrase.trim().replaceAll(RegExp(r'[.!]$'), '');
    return 'I would like to ${_lowerFirst(_stripLead(trimmed))}, please.';
  }

  @override
  Future<SocialStory> generateStory(StoryRequest request) async {
    await _thinking;
    final s = request.situation.trim();
    final lower = s.toLowerCase();
    final emojis = _emojiSequence(lower, request.pageCount);

    final beats = <String>[
      'Today I am going to the $s. That is okay. I am safe.',
      'When I arrive, I will see new things and meet calm, friendly people.',
      'If I feel big feelings, I can take a slow breath, like blowing a bubble.',
      'I can ask for a break or hold something soft if I need to.',
      'When we are finished, I did it. I am proud of myself.',
    ];

    final pages = <SocialStoryPage>[
      for (var i = 0; i < request.pageCount; i++)
        SocialStoryPage(
          text: beats[i % beats.length],
          emoji: emojis[i % emojis.length],
          imagePrompt:
              'Soft, friendly Pixar-style illustration of a calm child at the $s, '
              'gentle pastel colours, reassuring mood, page ${i + 1}',
        ),
    ];

    return SocialStory(
      title: _titleCase(s),
      situation: s,
      pages: pages,
    );
  }

  @override
  Future<CopilotReply> assistCaregiver(CopilotRequest request) async {
    await _thinking;
    final m = request.message.toLowerCase();
    final isMeltdown = m.contains('scream') ||
        m.contains('melt') ||
        m.contains('cry') ||
        m.contains('hit');
    final isSchool = m.contains('school') || m.contains('class');

    return CopilotReply(
      summary: isMeltdown
          ? 'This sounds like sensory or transition overload — very common and '
              'not your fault. The goal now is co-regulation, not correction.'
          : 'Here are some supportive, low-pressure ideas you can try.',
      likelyCauses: <String>[
        if (isSchool) 'Accumulated sensory load across the school day',
        if (isSchool) 'Hard transition from a structured to an open environment',
        'Hunger, thirst, or tiredness',
        'A change in routine or an unmet expectation',
        'Difficulty putting a big feeling into words',
      ],
      regulationActivities: <String>[
        'Open Calm Me → Particle Galaxy for 90 seconds',
        'Slow breathing with Bubble Pop World',
        'Deep-pressure / proprioceptive input (a firm hug or weighted toy)',
        'Dim lights and lower noise for 10 minutes',
      ],
      communicationPrompts: <String>[
        'Offer two choices instead of open questions: "water or snack?"',
        'Use the Help Me Talk board to let them point to the feeling',
        'Name the feeling for them: "You look frustrated. That is okay."',
      ],
      environmentChanges: <String>[
        'Create a predictable after-school wind-down routine',
        'Prepare a calm, low-stimulation corner',
        'Offer a snack and water before any demands',
      ],
    );
  }

  // ---- helpers -------------------------------------------------------------

  List<String> _emojiSequence(String s, int n) {
    final base = <String>['🌟', '🫧', '🌬️', '🧸', '🎉'];
    if (s.contains('dentist') || s.contains('doctor')) {
      return <String>['🦷', '🪥', '🩺', '😌', '🌟'];
    }
    if (s.contains('haircut')) return <String>['💇', '✂️', '🪞', '😌', '🌟'];
    if (s.contains('school')) return <String>['🎒', '🏫', '✏️', '🤝', '🌟'];
    if (s.contains('temple')) return <String>['🛕', '🪔', '🙏', '😌', '🌟'];
    if (s.contains('birthday') || s.contains('party')) {
      return <String>['🎂', '🎈', '🎁', '🎉', '🌟'];
    }
    if (s.contains('travel') || s.contains('flight') || s.contains('plane')) {
      return <String>['🧳', '✈️', '🪟', '😌', '🌟'];
    }
    return base;
  }

  String _stripLead(String s) =>
      s.replaceFirst(RegExp(r'^(i want|i need|my)\s*', caseSensitive: false), '');

  String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
