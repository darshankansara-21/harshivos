import 'package:flutter_tts/flutter_tts.dart';

/// Hari's voice — one warm, gentle narrator shared across the app.
///
/// Slow enough to process, soft pitch, never harsh or commanding. Volume is
/// always driven by the family's sensory setting (0 = voice off, respected).
class HariVoice {
  HariVoice._();
  static final HariVoice instance = HariVoice._();

  FlutterTts? _tts;
  bool _init = false;

  Future<void> _ensure() async {
    if (_init) return;
    _init = true;
    final tts = FlutterTts();
    await tts.setSpeechRate(0.4);
    await tts.setPitch(1.12);
    await tts.setVolume(1.0);
    _tts = tts;
  }

  /// Speak [text] gently. [volume] (0..1) comes from the sensory setting; 0
  /// keeps Hari silent. Never throws — voice is always best-effort.
  Future<void> speak(String text, {double volume = 1.0}) async {
    if (volume <= 0) return;
    try {
      await _ensure();
      await _tts!.stop();
      await _tts!.setVolume(volume.clamp(0.0, 1.0));
      await _tts!.speak(text);
    } catch (_) {
      // Best-effort: a missing TTS engine must never break the experience.
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
