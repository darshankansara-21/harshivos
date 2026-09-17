import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/player_progress.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  group('PlayerProgress model', () {
    test('level and xp-into-level derive from xp', () {
      const p = PlayerProgress(xp: 130);
      expect(p.level, 1 + 130 ~/ 60); // 3
      expect(p.xpIntoLevel, 130 % 60); // 10
      expect(p.levelProgress, closeTo(10 / 60, 0.001));
    });

    test('achievements unlock deterministically from stats', () {
      const fresh = PlayerProgress();
      expect(fresh.earnedAchievements, isEmpty);

      const played = PlayerProgress(plays: 10, records: 1);
      expect(played.earnedAchievements,
          containsAll(<String>['first_play', 'explorer_10', 'record_1']));

      // level 5 needs 4*60 = 240 xp.
      const leveled = PlayerProgress(xp: 240);
      expect(leveled.level, 5);
      expect(leveled.earnedAchievements, contains('level_5'));
    });

    test('json round-trips', () {
      const p = PlayerProgress(
          xp: 42, plays: 3, records: 2, achievements: <String>{'first_play'});
      final back = PlayerProgress.fromJson(p.toJson());
      expect(back.xp, 42);
      expect(back.plays, 3);
      expect(back.records, 2);
      expect(back.achievements, <String>{'first_play'});
    });
  });

  group('PlayerProgressNotifier', () {
    test('records XP from real activity and persists', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final c1 = ProviderContainer(overrides: <Override>[
        localStorageProvider.overrideWithValue(storage),
      ]);

      final unlocked =
          c1.read(playerProgressProvider.notifier).recordSession(newBest: true);
      final p = c1.read(playerProgressProvider);
      expect(p.xp, 6 + 12); // engagement + new best
      expect(p.plays, 1);
      expect(p.records, 1);
      expect(unlocked, containsAll(<String>['first_play', 'record_1']));
      c1.dispose();

      // A fresh container reads the persisted progress.
      final c2 = ProviderContainer(overrides: <Override>[
        localStorageProvider.overrideWithValue(storage),
      ]);
      expect(c2.read(playerProgressProvider).xp, 18);
      expect(c2.read(playerProgressProvider).plays, 1);
      c2.dispose();
    });

    test('a plain session grants only engagement XP and no record', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final c = ProviderContainer(overrides: <Override>[
        localStorageProvider.overrideWithValue(storage),
      ]);
      c.read(playerProgressProvider.notifier).recordSession();
      expect(c.read(playerProgressProvider).xp, 6);
      expect(c.read(playerProgressProvider).records, 0);
      c.dispose();
    });
  });
}
