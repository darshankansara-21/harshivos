import 'package:flutter/material.dart';

import '../avatar/avatar.dart';
import '../models/life_models.dart';

/// The built-in Visual Life Skills content. Everything here is real, narrated,
/// avatar-guided content — no placeholders.
class RoutineLibrary {
  const RoutineLibrary._();

  // Palette helpers.
  static const _sun = <Color>[Color(0xFFFFB703), Color(0xFFFB8500)];
  static const _school = <Color>[Color(0xFF4361EE), Color(0xFF4CC9F0)];
  static const _meal = <Color>[Color(0xFFEF476F), Color(0xFFFF9E00)];
  static const _potty = <Color>[Color(0xFF06D6A0), Color(0xFF118AB2)];
  static const _brush = <Color>[Color(0xFF00BBF9), Color(0xFF4CC9F0)];
  static const _wash = <Color>[Color(0xFF48CAE4), Color(0xFF0096C7)];
  static const _bath = <Color>[Color(0xFF9B5DE5), Color(0xFF4CC9F0)];
  static const _temple = <Color>[Color(0xFFFFD166), Color(0xFFF77F00)];
  static const _night = <Color>[Color(0xFF3A0CA3), Color(0xFF7209B7)];

  static final List<LifeRoutine> routines = <LifeRoutine>[
    LifeRoutine(
      id: 'morning',
      title: 'Morning Routine',
      subtitle: 'Start the day happy',
      emoji: '☀️',
      gradient: _sun,
      steps: const <RoutineStep>[
        RoutineStep(title: 'Wake Up', instruction: 'Good morning! Open your eyes and stretch big.', emoji: '🌅', pose: AvatarPose.cheer, accent: Color(0xFFFFB703)),
        RoutineStep(title: 'Use the Toilet', instruction: 'First, go to the bathroom.', emoji: '🚽', pose: AvatarPose.walk, accent: Color(0xFF06D6A0)),
        RoutineStep(title: 'Brush Teeth', instruction: 'Brush your teeth nice and clean.', emoji: '🪥', pose: AvatarPose.brush, accent: Color(0xFF00BBF9)),
        RoutineStep(title: 'Wash Face', instruction: 'Splash water and wash your face.', emoji: '💦', pose: AvatarPose.wash, accent: Color(0xFF48CAE4)),
        RoutineStep(title: 'Get Dressed', instruction: 'Put on your clothes, all by yourself.', emoji: '👕', pose: AvatarPose.idle, accent: Color(0xFF9B5DE5)),
        RoutineStep(title: 'Eat Breakfast', instruction: 'Sit down and eat your yummy breakfast.', emoji: '🥣', pose: AvatarPose.eat, accent: Color(0xFFEF476F)),
        RoutineStep(title: 'Ready to Go!', instruction: 'You did it! You are ready for the day.', emoji: '🎒', pose: AvatarPose.cheer, accent: Color(0xFFFFB703)),
      ],
    ),
    LifeRoutine(
      id: 'school',
      title: 'School Routine',
      subtitle: 'A great day at school',
      emoji: '🏫',
      gradient: _school,
      steps: const <RoutineStep>[
        RoutineStep(title: 'Pack Your Bag', instruction: 'Put your books in your backpack.', emoji: '🎒', pose: AvatarPose.idle, accent: Color(0xFF4361EE)),
        RoutineStep(title: 'Say Goodbye', instruction: 'Wave and say bye to family.', emoji: '👋', pose: AvatarPose.wave, accent: Color(0xFF4CC9F0)),
        RoutineStep(title: 'Sit at Your Desk', instruction: 'Find your seat and sit calmly.', emoji: '🪑', pose: AvatarPose.sit, accent: Color(0xFF06D6A0)),
        RoutineStep(title: 'Listen to Teacher', instruction: 'Look and listen to your teacher.', emoji: '👂', pose: AvatarPose.idle, accent: Color(0xFFFFD166)),
        RoutineStep(title: 'Raise Your Hand', instruction: 'Want to talk? Raise your hand and wait.', emoji: '🙋', pose: AvatarPose.wave, accent: Color(0xFFEF476F)),
        RoutineStep(title: 'Play at Recess', instruction: 'Have fun and take turns with friends.', emoji: '⚽', pose: AvatarPose.cheer, accent: Color(0xFF06D6A0)),
        RoutineStep(title: 'Go Home', instruction: 'School is done. Great job today!', emoji: '🚌', pose: AvatarPose.cheer, accent: Color(0xFF4361EE)),
      ],
    ),
    LifeRoutine(
      id: 'meal',
      title: 'Meal Time',
      subtitle: 'Eat calm and happy',
      emoji: '🍽️',
      gradient: _meal,
      steps: const <RoutineStep>[
        RoutineStep(title: 'Wash Hands', instruction: 'Clean hands before we eat.', emoji: '🧼', pose: AvatarPose.wash, accent: Color(0xFF48CAE4)),
        RoutineStep(title: 'Sit at the Table', instruction: 'Sit down nicely in your chair.', emoji: '🪑', pose: AvatarPose.sit, accent: Color(0xFF06D6A0)),
        RoutineStep(title: 'Use Your Spoon', instruction: 'Take small bites with your spoon.', emoji: '🥄', pose: AvatarPose.eat, accent: Color(0xFFEF476F)),
        RoutineStep(title: 'Chew Slowly', instruction: 'Chew your food slow and gentle.', emoji: '😋', pose: AvatarPose.eat, accent: Color(0xFFFF9E00)),
        RoutineStep(title: 'Drink Water', instruction: 'Take a sip of water.', emoji: '🥤', pose: AvatarPose.idle, accent: Color(0xFF4CC9F0)),
        RoutineStep(title: 'All Done', instruction: 'Say thank you. Yummy meal!', emoji: '🙏', pose: AvatarPose.cheer, accent: Color(0xFFEF476F)),
      ],
    ),
    LifeRoutine(
      id: 'potty',
      title: 'Potty Training',
      subtitle: 'Step by step',
      emoji: '🚽',
      gradient: _potty,
      steps: const <RoutineStep>[
        RoutineStep(title: 'Walk to Bathroom', instruction: 'Feel the potty? Walk to the bathroom.', emoji: '🚶', pose: AvatarPose.walk, accent: Color(0xFF06D6A0)),
        RoutineStep(title: 'Pull Pants Down', instruction: 'Pull your pants down.', emoji: '👖', pose: AvatarPose.idle, accent: Color(0xFF118AB2)),
        RoutineStep(title: 'Sit on Toilet', instruction: 'Sit down on the toilet.', emoji: '🚽', pose: AvatarPose.sit, accent: Color(0xFF06D6A0)),
        RoutineStep(title: 'Go Potty', instruction: 'Stay calm and go potty.', emoji: '💧', pose: AvatarPose.sit, accent: Color(0xFF4CC9F0)),
        RoutineStep(title: 'Wipe', instruction: 'Use toilet paper to wipe clean.', emoji: '🧻', pose: AvatarPose.idle, accent: Color(0xFFFFD166)),
        RoutineStep(title: 'Flush', instruction: 'Press the button to flush. Bye-bye!', emoji: '🌀', pose: AvatarPose.point, accent: Color(0xFF118AB2)),
        RoutineStep(title: 'Wash Hands', instruction: 'Wash your hands with soap.', emoji: '🧼', pose: AvatarPose.wash, accent: Color(0xFF48CAE4)),
      ],
    ),
    LifeRoutine(
      id: 'brushing',
      title: 'Brushing Teeth',
      subtitle: 'Sparkly clean teeth',
      emoji: '🪥',
      gradient: _brush,
      steps: const <RoutineStep>[
        RoutineStep(title: 'Apply Toothpaste', instruction: 'Put a little toothpaste on your brush.', emoji: '🪥', pose: AvatarPose.idle, accent: Color(0xFF00BBF9)),
        RoutineStep(title: 'Brush Top Teeth', instruction: 'Brush the top teeth, round and round.', emoji: '🦷', pose: AvatarPose.brush, kind: StepKind.timer, timerSeconds: 10, accent: Color(0xFF4CC9F0)),
        RoutineStep(title: 'Brush Bottom Teeth', instruction: 'Now brush the bottom teeth.', emoji: '🦷', pose: AvatarPose.brush, kind: StepKind.timer, timerSeconds: 10, accent: Color(0xFF4CC9F0)),
        RoutineStep(title: 'Brush Front Teeth', instruction: 'Brush the front teeth, big smile!', emoji: '😁', pose: AvatarPose.brush, kind: StepKind.timer, timerSeconds: 10, accent: Color(0xFF00BBF9)),
        RoutineStep(title: 'Rinse', instruction: 'Sip water, swish, and spit it out.', emoji: '💦', pose: AvatarPose.idle, accent: Color(0xFF48CAE4)),
        RoutineStep(title: 'Clean Your Brush', instruction: 'Rinse your brush and put it away.', emoji: '✨', pose: AvatarPose.cheer, accent: Color(0xFF00BBF9)),
      ],
    ),
    LifeRoutine(
      id: 'handwash',
      title: 'Washing Hands',
      subtitle: '20 seconds clean',
      emoji: '🧼',
      gradient: _wash,
      steps: const <RoutineStep>[
        RoutineStep(title: 'Wet Hands', instruction: 'Turn on the water and wet your hands.', emoji: '💧', pose: AvatarPose.wash, accent: Color(0xFF48CAE4)),
        RoutineStep(title: 'Add Soap', instruction: 'Pump some soap into your hands.', emoji: '🧴', pose: AvatarPose.wash, accent: Color(0xFF0096C7)),
        RoutineStep(title: 'Scrub!', instruction: 'Rub your hands together. Keep scrubbing!', emoji: '🫧', pose: AvatarPose.wash, kind: StepKind.timer, timerSeconds: 20, accent: Color(0xFF00BBF9)),
        RoutineStep(title: 'Between Fingers', instruction: 'Wash between all your fingers.', emoji: '🖐️', pose: AvatarPose.wash, accent: Color(0xFF48CAE4)),
        RoutineStep(title: 'Rinse', instruction: 'Rinse the soap away with water.', emoji: '💦', pose: AvatarPose.wash, accent: Color(0xFF0096C7)),
        RoutineStep(title: 'Dry', instruction: 'Dry your hands on a towel. All clean!', emoji: '🧻', pose: AvatarPose.cheer, accent: Color(0xFF48CAE4)),
      ],
    ),
    LifeRoutine(
      id: 'bath',
      title: 'Bath Time',
      subtitle: 'Splish splash clean',
      emoji: '🛁',
      gradient: _bath,
      steps: const <RoutineStep>[
        RoutineStep(title: 'Turn Water On', instruction: 'Turn on the water for your bath.', emoji: '🚿', pose: AvatarPose.point, accent: Color(0xFF4CC9F0)),
        RoutineStep(title: 'Check Temperature', instruction: 'Feel the water. Not too hot, not too cold.', emoji: '🌡️', pose: AvatarPose.idle, accent: Color(0xFFEF476F)),
        RoutineStep(title: 'Wash Your Body', instruction: 'Use soap to wash your body.', emoji: '🧼', pose: AvatarPose.wash, accent: Color(0xFF9B5DE5)),
        RoutineStep(title: 'Wash Your Hair', instruction: 'Gently wash your hair with shampoo.', emoji: '🧴', pose: AvatarPose.wash, accent: Color(0xFF4CC9F0)),
        RoutineStep(title: 'Rinse Off', instruction: 'Rinse all the bubbles away.', emoji: '💦', pose: AvatarPose.idle, accent: Color(0xFF48CAE4)),
        RoutineStep(title: 'Dry with Towel', instruction: 'Wrap up in a soft, warm towel.', emoji: '🧖', pose: AvatarPose.idle, accent: Color(0xFF9B5DE5)),
        RoutineStep(title: 'Get Dressed', instruction: 'Put on clean, comfy clothes.', emoji: '👕', pose: AvatarPose.cheer, accent: Color(0xFF4CC9F0)),
      ],
    ),
    LifeRoutine(
      id: 'temple',
      title: 'Temple Routine',
      subtitle: 'Calm and respectful',
      emoji: '🛕',
      gradient: _temple,
      steps: const <RoutineStep>[
        RoutineStep(title: 'Take Off Shoes', instruction: 'Leave your shoes neatly at the door.', emoji: '👟', pose: AvatarPose.idle, accent: Color(0xFFFFD166)),
        RoutineStep(title: 'Walk Quietly', instruction: 'Walk slowly and quietly inside.', emoji: '🤫', pose: AvatarPose.walk, accent: Color(0xFFF77F00)),
        RoutineStep(title: 'Fold Your Hands', instruction: 'Put your hands together gently.', emoji: '🙏', pose: AvatarPose.idle, accent: Color(0xFFFFD166)),
        RoutineStep(title: 'Sit Calmly', instruction: 'Sit down calm and still.', emoji: '🧘', pose: AvatarPose.sit, accent: Color(0xFF06D6A0)),
        RoutineStep(title: 'Say Thank You', instruction: 'Say a quiet thank you in your heart.', emoji: '💛', pose: AvatarPose.idle, accent: Color(0xFFF77F00)),
        RoutineStep(title: 'All Done', instruction: 'Well done. Put your shoes back on.', emoji: '✨', pose: AvatarPose.cheer, accent: Color(0xFFFFD166)),
      ],
    ),
    LifeRoutine(
      id: 'bedtime',
      title: 'Bedtime Routine',
      subtitle: 'Wind down to sleep',
      emoji: '🛏️',
      gradient: _night,
      steps: const <RoutineStep>[
        RoutineStep(title: 'Put on Pajamas', instruction: 'Time for cozy pajamas.', emoji: '👚', pose: AvatarPose.idle, accent: Color(0xFF7209B7)),
        RoutineStep(title: 'Brush Teeth', instruction: 'Brush your teeth before bed.', emoji: '🪥', pose: AvatarPose.brush, accent: Color(0xFF00BBF9)),
        RoutineStep(title: 'Use the Toilet', instruction: 'Go potty one last time.', emoji: '🚽', pose: AvatarPose.walk, accent: Color(0xFF06D6A0)),
        RoutineStep(title: 'Read a Story', instruction: 'Snuggle up with a bedtime story.', emoji: '📖', pose: AvatarPose.sit, accent: Color(0xFFFFD166)),
        RoutineStep(title: 'Lights Off', instruction: 'Turn the lights down low.', emoji: '🌙', pose: AvatarPose.point, accent: Color(0xFF3A0CA3)),
        RoutineStep(title: 'Sleep Tight', instruction: 'Close your eyes. Sweet dreams!', emoji: '😴', pose: AvatarPose.sleep, accent: Color(0xFF7209B7)),
      ],
    ),
  ];

  static LifeRoutine? routineById(String id) {
    for (final r in routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ------------------------------------------------------------------ decks

  static const LessonDeck dosDonts = LessonDeck(
    id: 'dosdonts',
    title: "Do's & Don'ts",
    subtitle: 'Kind and safe choices',
    emoji: '✅',
    gradient: <Color>[Color(0xFF06D6A0), Color(0xFF118AB2)],
    cards: <LessonCard>[
      LessonCard(title: 'Use Kind Words', narration: 'We use kind and gentle words.', emoji: '💬', kind: LessonKind.doThis, pose: AvatarPose.wave),
      LessonCard(title: 'Stay With Parents', narration: 'Stay close to your grown-up.', emoji: '👨‍👦', kind: LessonKind.doThis, pose: AvatarPose.hold),
      LessonCard(title: 'Walk Calmly', narration: 'We walk calmly, we do not run.', emoji: '🚶', kind: LessonKind.doThis, pose: AvatarPose.walk),
      LessonCard(title: 'Listen to Teacher', narration: 'Look and listen to your teacher.', emoji: '👂', kind: LessonKind.doThis, pose: AvatarPose.idle),
      LessonCard(title: 'Raise Your Hand', narration: 'Raise your hand and wait your turn.', emoji: '🙋', kind: LessonKind.doThis, pose: AvatarPose.wave),
      LessonCard(title: 'Wait Your Turn', narration: 'Good things come when we wait.', emoji: '⏳', kind: LessonKind.doThis, pose: AvatarPose.idle),
      LessonCard(title: 'Wear a Seatbelt', narration: 'Buckle up to stay safe in the car.', emoji: '🚗', kind: LessonKind.doThis, pose: AvatarPose.sit),
      LessonCard(title: 'Brush Your Teeth', narration: 'Brush your teeth every morning and night.', emoji: '🪥', kind: LessonKind.doThis, pose: AvatarPose.brush),
      LessonCard(title: 'Wash Your Hands', narration: 'Wash hands to stay clean and healthy.', emoji: '🧼', kind: LessonKind.doThis, pose: AvatarPose.wash),
      LessonCard(title: "Don't Run Away", narration: 'We never run away from our grown-up.', emoji: '🏃', kind: LessonKind.dontThis, pose: AvatarPose.idle),
      LessonCard(title: "Don't Hit", narration: 'Hands are not for hitting.', emoji: '✋', kind: LessonKind.dontThis, pose: AvatarPose.idle),
      LessonCard(title: "Don't Bite", narration: 'Teeth are not for biting people.', emoji: '🦷', kind: LessonKind.dontThis, pose: AvatarPose.idle),
      LessonCard(title: "Don't Throw", narration: 'We keep toys safe, we do not throw.', emoji: '🧸', kind: LessonKind.dontThis, pose: AvatarPose.idle),
      LessonCard(title: "Don't Push", narration: 'We give friends gentle space.', emoji: '🙅', kind: LessonKind.dontThis, pose: AvatarPose.idle),
      LessonCard(title: "Don't Touch Hot Things", narration: 'Hot things can hurt. Stay away.', emoji: '🔥', kind: LessonKind.dontThis, pose: AvatarPose.idle),
      LessonCard(title: "Don't Go With Strangers", narration: 'Only go with people your family trusts.', emoji: '🚫', kind: LessonKind.dontThis, pose: AvatarPose.idle),
    ],
  );

  static const LessonDeck socialSkills = LessonDeck(
    id: 'social',
    title: 'Social Skills',
    subtitle: 'Playing and talking together',
    emoji: '❤️',
    gradient: <Color>[Color(0xFFEF476F), Color(0xFF9B5DE5)],
    cards: <LessonCard>[
      LessonCard(title: 'Say Hello', narration: 'Wave and say hello to say hi.', emoji: '👋', kind: LessonKind.good, pose: AvatarPose.wave),
      LessonCard(title: 'Say Goodbye', narration: 'Wave and say goodbye when you leave.', emoji: '🖐️', kind: LessonKind.good, pose: AvatarPose.wave),
      LessonCard(title: 'Say Please', narration: 'Say please when you ask for something.', emoji: '🥺', kind: LessonKind.good, pose: AvatarPose.idle),
      LessonCard(title: 'Say Thank You', narration: 'Say thank you when someone helps you.', emoji: '🙏', kind: LessonKind.good, pose: AvatarPose.idle),
      LessonCard(title: 'Say Sorry', narration: 'Say sorry if you make a mistake.', emoji: '💛', kind: LessonKind.good, pose: AvatarPose.idle),
      LessonCard(title: 'Wait Nicely', narration: 'Sometimes we wait. Waiting is okay.', emoji: '⏳', kind: LessonKind.good, pose: AvatarPose.idle),
      LessonCard(title: 'Share Toys', narration: 'Sharing makes playing more fun.', emoji: '🧸', kind: LessonKind.good, pose: AvatarPose.idle),
      LessonCard(title: 'Take Turns', narration: 'First you, then me. We take turns.', emoji: '🔄', kind: LessonKind.good, pose: AvatarPose.clap),
      LessonCard(title: 'Ask for Help', narration: 'Stuck? It is okay to ask for help.', emoji: '🙋', kind: LessonKind.good, pose: AvatarPose.wave),
      LessonCard(title: 'Listen', narration: 'Look and listen when a friend talks.', emoji: '👂', kind: LessonKind.good, pose: AvatarPose.idle),
      LessonCard(title: 'Follow Instructions', narration: 'We listen and do what is asked.', emoji: '✅', kind: LessonKind.good, pose: AvatarPose.idle),
      LessonCard(title: 'Not Grabbing', narration: 'We ask first, we do not grab.', emoji: '🚫', kind: LessonKind.bad, pose: AvatarPose.idle),
    ],
  );

  static const LessonDeck staySafe = LessonDeck(
    id: 'safety',
    title: 'Stay Safe',
    subtitle: 'Holding hands keeps us safe',
    emoji: '🤝',
    gradient: <Color>[Color(0xFFFB8500), Color(0xFFEF476F)],
    cards: <LessonCard>[
      LessonCard(title: 'Parking Lot', narration: 'In the parking lot, hold your grown-up\'s hand.', emoji: '🅿️', kind: LessonKind.good, pose: AvatarPose.hold),
      LessonCard(title: 'Never Let Go', narration: 'Cars are near. Never let go of the hand.', emoji: '🚗', kind: LessonKind.bad, pose: AvatarPose.idle),
      LessonCard(title: 'Shopping Mall', narration: 'In the mall, stay right beside your family.', emoji: '🛍️', kind: LessonKind.good, pose: AvatarPose.hold),
      LessonCard(title: "Don't Wander", narration: 'Do not wander off alone in the mall.', emoji: '🚫', kind: LessonKind.bad, pose: AvatarPose.idle),
      LessonCard(title: 'Airport', narration: 'At the airport, hold hands and stay close.', emoji: '✈️', kind: LessonKind.good, pose: AvatarPose.hold),
      LessonCard(title: 'Crossing the Street', narration: 'Stop, hold hands, look both ways, then walk.', emoji: '🚦', kind: LessonKind.good, pose: AvatarPose.hold),
      LessonCard(title: 'Never Run Across', narration: 'Never run into the street alone.', emoji: '🛑', kind: LessonKind.bad, pose: AvatarPose.idle),
      LessonCard(title: 'School Pickup', narration: 'Wait calmly for your grown-up at pickup.', emoji: '🏫', kind: LessonKind.good, pose: AvatarPose.idle),
      LessonCard(title: 'In the Store', narration: 'In the store, keep the cart in sight.', emoji: '🛒', kind: LessonKind.good, pose: AvatarPose.hold),
    ],
  );

  static const List<LessonDeck> decks = <LessonDeck>[dosDonts, socialSkills, staySafe];

  static LessonDeck? deckById(String id) {
    for (final d in decks) {
      if (d.id == id) return d;
    }
    return null;
  }
}
