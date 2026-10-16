import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/services/audio/tone_player.dart';

void main() {
  group('WonderAudioPolicy', () {
    test('ordinary interaction and navigation are quieter than gameplay', () {
      expect(WonderAudioPolicy.scale(WonderAudioKind.interaction),
          lessThan(WonderAudioPolicy.scale(WonderAudioKind.gameplay)));
      expect(WonderAudioPolicy.scale(WonderAudioKind.navigation),
          lessThan(WonderAudioPolicy.scale(WonderAudioKind.gameplay)));
    });

    test('success remains distinct without reaching full scale', () {
      final gameplay = WonderAudioPolicy.scale(WonderAudioKind.gameplay);
      expect(WonderAudioPolicy.scale(WonderAudioKind.celebration),
          greaterThanOrEqualTo(gameplay));
      expect(WonderAudioPolicy.scale(WonderAudioKind.success),
          greaterThanOrEqualTo(gameplay));
      expect(WonderAudioPolicy.scale(WonderAudioKind.celebration),
        lessThan(1.0));
      expect(WonderAudioPolicy.scale(WonderAudioKind.success), lessThan(1.0));
    });

    test('frequent cues have conservative sensory ceilings', () {
      expect(WonderAudioPolicy.scale(WonderAudioKind.interaction),
        lessThanOrEqualTo(0.35));
      expect(WonderAudioPolicy.scale(WonderAudioKind.navigation),
        lessThanOrEqualTo(0.35));
      expect(WonderAudioPolicy.scale(WonderAudioKind.gameplay),
        lessThanOrEqualTo(0.75));
    });

    test('every kind maps to a sane 0..1 multiplier', () {
      for (final kind in WonderAudioKind.values) {
        final v = WonderAudioPolicy.scale(kind);
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
