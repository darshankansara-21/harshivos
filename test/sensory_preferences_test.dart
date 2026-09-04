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
}