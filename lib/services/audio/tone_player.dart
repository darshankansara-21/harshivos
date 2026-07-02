import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Lightweight procedural sound engine for the sensory toys.
///
/// No audio assets are bundled — every sound is synthesised to an in-memory
/// 16-bit PCM WAV buffer and played through a small round-robin pool of
/// [AudioPlayer]s. This keeps the app tiny and works identically on web,
/// Android and iOS. All calls are best-effort: if audio fails (e.g. a browser
/// that blocks autoplay before the first interaction) the toys still work,
/// they simply fall back to silence.
class TonePlayer {
  TonePlayer._();

  static final TonePlayer instance = TonePlayer._();

  static const int _sampleRate = 44100;
  static const int _poolSize = 8;

  final List<AudioPlayer> _pool =
      List<AudioPlayer>.generate(_poolSize, (_) => AudioPlayer());
  int _next = 0;
  bool _ready = false;

  /// A warm major-pentatonic scale (C D E G A) over two octaves — every
  /// combination sounds pleasant, which is exactly what a calm toy wants.
  static const List<double> pentatonic = <double>[
    261.63, 293.66, 329.63, 392.00, 440.00, // C4 D4 E4 G4 A4
    523.25, 587.33, 659.25, 783.99, 880.00, // C5 D5 E5 G5 A5
  ];

  Future<void> _ensureReady() async {
    if (_ready) return;
    _ready = true;
    for (final p in _pool) {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setPlayerMode(PlayerMode.lowLatency);
    }
  }

  AudioPlayer get _player {
    final p = _pool[_next];
    _next = (_next + 1) % _poolSize;
    return p;
  }

  /// Play one note of the pentatonic scale (index is wrapped/clamped).
  Future<void> playNote(int index, {double seconds = 0.45}) async {
    final freq = pentatonic[index % pentatonic.length];
    await _play(freq, seconds: seconds, wave: _Wave.triangle, attack: 0.01);
  }

  /// Play a soft "pop" — a short pitched blip whose frequency rises with the
  /// supplied [pitch] (0..1), used by Bubble Pop so small/large bubbles sound
  /// different.
  Future<void> playPop(double pitch) async {
    final freq = 320 + pitch.clamp(0.0, 1.0) * 520;
    await _play(freq, seconds: 0.16, wave: _Wave.sine, attack: 0.004, decay: 6);
  }

  Future<void> _play(
    double freq, {
    required double seconds,
    required _Wave wave,
    double attack = 0.01,
    double decay = 3.5,
  }) async {
    try {
      await _ensureReady();
      final bytes = _synth(freq, seconds, wave, attack, decay);
      await _player.play(BytesSource(bytes), volume: 0.7);
    } catch (_) {
      // Best-effort: never let audio crash a toy.
    }
  }

  /// Build a mono 16-bit PCM WAV with a quick attack and exponential decay so
  /// notes never click or sound harsh.
  Uint8List _synth(double freq, double seconds, _Wave wave, double attack,
      double decay) {
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    final twoPiF = 2 * math.pi * freq;
    for (var i = 0; i < frames; i++) {
      final t = i / _sampleRate;
      // Envelope: linear attack then exponential decay.
      final env = t < attack
          ? t / attack
          : math.exp(-(t - attack) * decay);
      final phase = twoPiF * t;
      double s;
      switch (wave) {
        case _Wave.sine:
          s = math.sin(phase);
          break;
        case _Wave.triangle:
          final frac = (phase / (2 * math.pi)) % 1.0;
          s = 4 * (frac < 0.5 ? frac : 1 - frac) - 1;
          break;
      }
      data[i] = (s * env * 32767 * 0.6).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  Uint8List _wrapWav(Int16List samples) {
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = _sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final dataBytes = samples.buffer.asUint8List();
    final dataLen = dataBytes.length;
    final buffer = BytesBuilder();

    void writeString(String s) => buffer.add(s.codeUnits);
    void writeU32(int v) => buffer.add(<int>[
          v & 0xFF,
          (v >> 8) & 0xFF,
          (v >> 16) & 0xFF,
          (v >> 24) & 0xFF,
        ]);
    void writeU16(int v) => buffer.add(<int>[v & 0xFF, (v >> 8) & 0xFF]);

    writeString('RIFF');
    writeU32(36 + dataLen);
    writeString('WAVE');
    writeString('fmt ');
    writeU32(16); // PCM chunk size
    writeU16(1); // audio format = PCM
    writeU16(channels);
    writeU32(_sampleRate);
    writeU32(byteRate);
    writeU16(blockAlign);
    writeU16(bitsPerSample);
    writeString('data');
    writeU32(dataLen);
    buffer.add(dataBytes);
    return buffer.toBytes();
  }

  void dispose() {
    for (final p in _pool) {
      p.dispose();
    }
  }
}

enum _Wave { sine, triangle }
