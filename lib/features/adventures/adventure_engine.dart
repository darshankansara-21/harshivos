import 'package:flutter/material.dart';

import '../lifeskills/avatar/hari_pico_scene.dart';

@immutable
class AdventureChoice {
  const AdventureChoice(this.label, this.reply);
  final String label;
  final String reply;
}

@immutable
class AdventureStep {
  const AdventureStep({
    required this.moment,
    required this.prompt,
    required this.choices,
  });

  final HariPicoMoment moment;
  final String prompt;
  final List<AdventureChoice> choices;
}

@immutable
class AdventureExperience {
  const AdventureExperience({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradient,
    required this.steps,
  });

  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradient;
  final List<AdventureStep> steps;
}

const List<AdventureExperience> kAdventureExperiences = <AdventureExperience>[
  AdventureExperience(
    id: 'adv_rainbow_rescue',
    title: 'Rainbow Rescue',
    subtitle: 'Help Hari and Pico find color stars',
    emoji: '🌈',
    gradient: <Color>[Color(0xFF6A5AE0), Color(0xFF24C6DC)],
    steps: <AdventureStep>[
      AdventureStep(
        moment: HariPicoMoment.greeting,
        prompt: 'Hari found a faded rainbow. Which color should we restore first?',
        choices: <AdventureChoice>[
          AdventureChoice('Red', 'Great choice! Pico jumps to the red star.'),
          AdventureChoice('Blue', 'Nice! Hari paints a blue arc in the sky.'),
          AdventureChoice('Green', 'Awesome! You made the grass sparkle.'),
        ],
      ),
      AdventureStep(
        moment: HariPicoMoment.play,
        prompt: 'A windy cloud appears. What should we do together?',
        choices: <AdventureChoice>[
          AdventureChoice('Hold hands', 'Perfect teamwork. Everyone stays steady.'),
          AdventureChoice('Take deep breaths', 'Calm breaths help the cloud pass.'),
        ],
      ),
      AdventureStep(
        moment: HariPicoMoment.celebrating,
        prompt: 'The rainbow is glowing again! How do we celebrate?',
        choices: <AdventureChoice>[
          AdventureChoice('Cheer', 'Yay! Hari and Pico cheer with you.'),
          AdventureChoice('High five', 'Great teamwork! Pico gives a paw-five.'),
        ],
      ),
    ],
  ),
  AdventureExperience(
    id: 'adv_park_helper',
    title: 'Park Helper',
    subtitle: 'Practice safe play choices together',
    emoji: '🛝',
    gradient: <Color>[Color(0xFF06D6A0), Color(0xFF118AB2)],
    steps: <AdventureStep>[
      AdventureStep(
        moment: HariPicoMoment.reacting,
        prompt: 'Pico sees many friends at the park. What is the first safe choice?',
        choices: <AdventureChoice>[
          AdventureChoice('Say hello', 'Friendly start! Hari waves with you.'),
          AdventureChoice('Run alone', 'Let us stay together with Hari and Pico.'),
        ],
      ),
      AdventureStep(
        moment: HariPicoMoment.encouraging,
        prompt: 'A turn on the slide is coming. What can we practice?',
        choices: <AdventureChoice>[
          AdventureChoice('Wait my turn', 'Strong choice. Pico waits right beside you.'),
          AdventureChoice('Push to go first', 'Let us try gentle waiting together.'),
        ],
      ),
      AdventureStep(
        moment: HariPicoMoment.calm,
        prompt: 'The park feels noisy now. What helps your body?',
        choices: <AdventureChoice>[
          AdventureChoice('Quiet break', 'Smart pause. Hari sits with you calmly.'),
          AdventureChoice('Drink water', 'Great reset. Pico brings a water break.'),
        ],
      ),
    ],
  ),
  AdventureExperience(
    id: 'adv_bedtime_mission',
    title: 'Bedtime Mission',
    subtitle: 'Wind down with Hari and Pico',
    emoji: '🌙',
    gradient: <Color>[Color(0xFF3A0CA3), Color(0xFF7209B7)],
    steps: <AdventureStep>[
      AdventureStep(
        moment: HariPicoMoment.greeting,
        prompt: 'Mission start: what comes before sleep?',
        choices: <AdventureChoice>[
          AdventureChoice('Brush teeth', 'Sparkly choice. Hari shows the brushing steps.'),
          AdventureChoice('Jump on bed', 'Let us do our routine first.'),
        ],
      ),
      AdventureStep(
        moment: HariPicoMoment.play,
        prompt: 'Pico found your cozy blanket. What next?',
        choices: <AdventureChoice>[
          AdventureChoice('Read a story', 'Wonderful. Story time makes bedtime easier.'),
          AdventureChoice('Take 3 breaths', 'Nice reset. Slow breaths calm the body.'),
        ],
      ),
      AdventureStep(
        moment: HariPicoMoment.calm,
        prompt: 'Lights are low. What should our bodies do now?',
        choices: <AdventureChoice>[
          AdventureChoice('Rest quietly', 'You did it. Hari and Pico whisper goodnight.'),
          AdventureChoice('Ask for a hug', 'Beautiful choice. A hug can help us settle.'),
        ],
      ),
    ],
  ),
];