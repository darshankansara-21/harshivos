import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toy_registry.dart';
import 'package:harshivos/features/universe/universe_catalog.dart';
import 'package:harshivos/models/toy_meta.dart';

/// Guards against registration drift: every arcade game must be wired end to
/// end (playable builder + reachable universe entry + implemented metadata),
/// and every discovery rail must contain only real, working toys.
void main() {
  const gameIds = <String>[
    'whack', 'sky_hop', 'stack', 'merge', 'echo', 'tictactoe',
    'brick_break', 'space_dodge', 'memory_flip',
    'ball_sort', 'tap_order', 'piano_tiles', 'block_blast', 'bubble_shooter',
    'color_quest', 'shape_scout', 'number_splash', 'path_finder', 'goal_keeper',
    'trace_it', 'quick_tap',
  ];

  test('every registered game is playable, reachable and implemented', () {
    for (final id in gameIds) {
      expect(toyBuilders.containsKey(id), isTrue, reason: 'no builder: $id');
      final toy = kToyUniverseById[id];
      expect(toy, isNotNull, reason: 'not in universe: $id');
      expect(toy!.working, isTrue, reason: 'not working: $id');
      final meta = kToyCatalog.firstWhere((m) => m.id == id,
          orElse: () => kToyCatalog.first);
      expect(meta.id, id, reason: 'no toy_meta entry: $id');
      expect(meta.implemented, isTrue, reason: 'meta not implemented: $id');
    }
  });

  test('discovery rails contain only working toys, no dead entries', () {
    final rails = <String, List<UniverseToy>>{
      'featured': featuredToys(),
      'games': gamesToys(),
      'arcade': arcadeToys(),
      'puzzleBrain': puzzleBrainToys(),
      'stressBuster': stressBusterToys(),
      'sensoryPlay': sensoryPlayToys(),
      'smartPlay': smartPlayToys(),
      'racingSkill': racingSkillToys(),
    };
    rails.forEach((name, toys) {
      expect(toys, isNotEmpty, reason: '$name rail is empty');
      for (final t in toys) {
        expect(t.working, isTrue, reason: '$name has non-working ${t.id}');
      }
    });
  });

  test('the three newest games appear in their rails', () {
    expect(gamesToys().map((t) => t.id), containsAll(<String>[
      'brick_break', 'space_dodge', 'memory_flip',
    ]));
    expect(arcadeToys().map((t) => t.id),
        containsAll(<String>['brick_break', 'space_dodge']));
    expect(puzzleBrainToys().map((t) => t.id), contains('memory_flip'));
  });

  test('the five newest arcade games appear in their rails', () {
    expect(gamesToys().map((t) => t.id), containsAll(<String>[
      'ball_sort', 'tap_order', 'piano_tiles', 'block_blast', 'bubble_shooter',
    ]));
    expect(arcadeToys().map((t) => t.id), containsAll(<String>[
      'piano_tiles', 'block_blast', 'bubble_shooter',
    ]));
    expect(puzzleBrainToys().map((t) => t.id),
        containsAll(<String>['ball_sort', 'block_blast', 'tap_order']));
  });

  test('the five goal games appear in appropriate discovery rails', () {
    const goalIds = <String>[
      'color_quest', 'shape_scout', 'number_splash', 'path_finder', 'goal_keeper',
    ];
    expect(gamesToys().map((t) => t.id), containsAll(goalIds));
    expect(smartPlayToys().map((t) => t.id), containsAll(<String>[
      'color_quest', 'shape_scout', 'number_splash', 'path_finder',
    ]));
    expect(arcadeToys().map((t) => t.id), contains('goal_keeper'));
    expect(racingSkillToys().map((t) => t.id), contains('goal_keeper'));
  });
}
