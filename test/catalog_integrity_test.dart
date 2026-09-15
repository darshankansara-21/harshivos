import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toy_registry.dart';
import 'package:harshivos/features/universe/universe_catalog.dart';
import 'package:harshivos/models/toy_meta.dart';

/// Guards against registration drift: every arcade game must be wired end to
/// end (playable builder + reachable universe entry + implemented metadata),
/// and every discovery rail must contain only real, working toys.
void main() {
  const arcadeIds = <String>[
    'whack', 'sky_hop', 'stack', 'merge', 'echo', 'tictactoe',
    'brick_break', 'space_dodge', 'memory_flip',
  ];

  test('every arcade game is playable, reachable and implemented', () {
    for (final id in arcadeIds) {
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
}
