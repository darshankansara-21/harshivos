import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harshivos/services/storage/local_storage.dart';
import 'package:harshivos/state/providers.dart';

void main() {
  test('sensory preferences persist locally', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    final first = ProviderContainer(overrides: <Override>[
      localStorageProvider.overrideWithValue(storage),
    ]);

    await first
        .read(sensoryPreferencesProvider.notifier)
        .setAudioLevel(AudioLevel.soft);
    await first
        .read(sensoryPreferencesProvider.notifier)
        .setReduceMotion(true);
    first.dispose();

    final restored = ProviderContainer(overrides: <Override>[
      localStorageProvider.overrideWithValue(storage),
    ]);
    expect(restored.read(sensoryPreferencesProvider).audioLevel,
        AudioLevel.soft);
    expect(restored.read(sensoryPreferencesProvider).reduceMotion, true);
    restored.dispose();
  });

  group('global mute', () {
    test('volumeScale is 0 when muted, regardless of audio level', () {
      const normalMuted =
          SensoryPreferences(audioLevel: AudioLevel.normal, muted: true);
      const softMuted =
          SensoryPreferences(audioLevel: AudioLevel.soft, muted: true);
      expect(normalMuted.volumeScale, 0);
      expect(softMuted.volumeScale, 0);
    });

    test('unmuting restores the audio-level volume', () {
      const normal = SensoryPreferences(audioLevel: AudioLevel.normal);
      const soft = SensoryPreferences(audioLevel: AudioLevel.soft);
      expect(normal.volumeScale, 1);
      expect(soft.volumeScale, closeTo(0.35, 0.001));
    });

    test('mute toggles and persists across containers', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final first = ProviderContainer(overrides: <Override>[
        localStorageProvider.overrideWithValue(storage),
      ]);
      expect(first.read(sensoryPreferencesProvider).muted, false);
      await first.read(sensoryPreferencesProvider.notifier).toggleMuted();
      expect(first.read(sensoryPreferencesProvider).muted, true);
      expect(first.read(sensoryPreferencesProvider).volumeScale, 0);
      first.dispose();

      final restored = ProviderContainer(overrides: <Override>[
        localStorageProvider.overrideWithValue(storage),
      ]);
      expect(restored.read(sensoryPreferencesProvider).muted, true);
      await restored.read(sensoryPreferencesProvider.notifier).setMuted(false);
      expect(restored.read(sensoryPreferencesProvider).muted, false);
      expect(restored.read(sensoryPreferencesProvider).volumeScale, 1);
      restored.dispose();
    });
  });
}