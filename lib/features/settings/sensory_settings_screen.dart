import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import '../../state/providers.dart';

class SensorySettingsScreen extends ConsumerWidget {
  const SensorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(sensoryPreferencesProvider);
    final notifier = ref.read(sensoryPreferencesProvider.notifier);
    return HarshivScaffold(
      child: SafeArea(
        child: ListView(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
                const Text('Sensory settings',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Sound and voice',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<AudioLevel>(
              segments: const <ButtonSegment<AudioLevel>>[
                ButtonSegment(value: AudioLevel.off, label: Text('Off')),
                ButtonSegment(value: AudioLevel.soft, label: Text('Soft')),
                ButtonSegment(value: AudioLevel.normal, label: Text('Normal')),
              ],
              selected: <AudioLevel>{preferences.audioLevel},
              onSelectionChanged: (levels) =>
                  notifier.setAudioLevel(levels.first),
            ),
            const SizedBox(height: 28),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce motion',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              subtitle: const Text('Use calmer transitions and animations',
                  style: TextStyle(color: Colors.white70)),
              value: preferences.reduceMotion,
              onChanged: notifier.setReduceMotion,
            ),
            const SizedBox(height: 12),
            const Text(
              'These choices stay on this device. Haptic feedback is not yet controlled here.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}