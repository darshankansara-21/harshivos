import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

enum SoundCue {
  tap,
  navigation,
  selection,
  correct,
  gentleRetry,
  milestone,
  completion,
  calm,
  // --- Contextual material / interaction vocabulary -------------------------
  // Each of these renders a physically distinct sound so a wooden tap, a metal
  // click, a water drop and a coin never share one generic beep.
  sand,
  water,
  bubble,
  balloon,
  ball,
  bowling,
  wood,
  metal,
  coin,
  marble,
  stack,
  engine,
  crash,
  laser,
  brick,
  snakeEat,
  paint,
  paper,
  fruit,
  ripple,
  learnGood,
  talkAck,
  routineDone,
  success,
  gameOver,
}

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
  final List<AudioPlayer> _pool = <AudioPlayer>[];
  int _next = 0;
  bool _ready = false;
  double volumeScale = 1;

  /// Directory where synthesised WAVs are cached on disk. Android's low-latency
  /// SoundPool backend cannot play in-memory byte streams — it needs a real
  /// file — so every sound is rendered once to [_cacheDir] and replayed from
  /// there. This is the difference between silence and an audible pop.
  Directory? _cacheDir;
  final Map<String, String> _fileCache = <String, String>{};

  bool get _audioAvailable => !WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  /// A warm major-pentatonic scale (C D E G A) over two octaves — every
  /// combination sounds pleasant, which is exactly what a calm toy wants.
  static const List<double> pentatonic = <double>[
    261.63, 293.66, 329.63, 392.00, 440.00, // C4 D4 E4 G4 A4
    523.25, 587.33, 659.25, 783.99, 880.00, // C5 D5 E5 G5 A5
  ];

  Future<bool> _ensureReady() async {
    if (!_audioAvailable) return false;
    if (_ready) return true;
    _cacheDir = await getTemporaryDirectory();
    _pool.addAll(List<AudioPlayer>.generate(_poolSize, (_) => AudioPlayer()));
    _ready = true;
    for (final p in _pool) {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setPlayerMode(PlayerMode.lowLatency);
    }
    return true;
  }

  /// Resolves a cached WAV file for [key], synthesising and writing it once.
  Future<String?> _fileFor(String key, Uint8List Function() build) async {
    final cached = _fileCache[key];
    if (cached != null) return cached;
    final dir = _cacheDir;
    if (dir == null) return null;
    final file = File('${dir.path}/wp_$key.wav');
    if (!await file.exists()) {
      await file.writeAsBytes(build(), flush: true);
    }
    _fileCache[key] = file.path;
    return file.path;
  }

  /// Plays a keyed, cached sound through the round-robin pool.
  Future<void> _playKeyed(
    String key,
    Uint8List Function() build, {
    required double volume,
  }) async {
    if (volumeScale <= 0) return;
    try {
      if (!await _ensureReady()) return;
      final path = await _fileFor(key, build);
      if (path == null) return;
      await _player.play(
        DeviceFileSource(path),
        volume: (volume * volumeScale).clamp(0, 1),
      );
    } catch (_) {
      // Best-effort: never let audio crash a toy.
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

  final Map<SoundCue, DateTime> _lastCueAt = <SoundCue, DateTime>{};

  Future<void> playCue(SoundCue cue) async {
    if (volumeScale <= 0 || !_audioAvailable) return;
    final now = DateTime.now();
    final last = _lastCueAt[cue];
    final cooldown = switch (cue) {
      SoundCue.tap || SoundCue.selection => 90,
      SoundCue.navigation => 160,
      SoundCue.correct || SoundCue.gentleRetry => 220,
      SoundCue.milestone || SoundCue.completion => 700,
      SoundCue.calm => 500,
      // Contextual cues: fast tactile ones get short cooldowns, ambient and
      // resolution cues get long ones so they never spam.
      SoundCue.brick ||
      SoundCue.marble ||
      SoundCue.snakeEat =>
        60,
      SoundCue.ball ||
      SoundCue.wood ||
      SoundCue.metal ||
      SoundCue.stack ||
      SoundCue.bubble ||
      SoundCue.paper =>
        70,
      SoundCue.sand || SoundCue.paint => 100,
      SoundCue.water || SoundCue.fruit || SoundCue.coin => 110,
      SoundCue.balloon || SoundCue.laser => 130,
      SoundCue.engine => 150,
      SoundCue.talkAck || SoundCue.learnGood => 180,
      SoundCue.ripple || SoundCue.routineDone => 400,
      SoundCue.bowling => 500,
      SoundCue.success || SoundCue.crash || SoundCue.gameOver => 700,
    };
    if (last != null && now.difference(last).inMilliseconds < cooldown) return;
    _lastCueAt[cue] = now;

    switch (cue) {
      case SoundCue.tap:
        await playClick(pitch: 1.15);
      case SoundCue.navigation:
        await playNote(2, seconds: 0.12);
      case SoundCue.selection:
        await playPop(0.35);
      case SoundCue.correct:
        await playNote(5, seconds: 0.24);
      case SoundCue.gentleRetry:
        await _play(220,
            seconds: 0.18, wave: _Wave.sine, attack: 0.02, decay: 7);
      case SoundCue.milestone:
        await playNote(7, seconds: 0.3);
      case SoundCue.completion:
        await playNote(5, seconds: 0.22);
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await playNote(8, seconds: 0.42);
      case SoundCue.calm:
        await _play(196,
            seconds: 0.55, wave: _Wave.sine, attack: 0.08, decay: 3.2);
      // --- Contextual material vocabulary ------------------------------------
      case SoundCue.sand:
        await _playKeyed('sand', () => _synthGrain(0.20, 0.9), volume: 0.5);
      case SoundCue.water:
        await _playKeyed('water', () => _synthDroplet(760), volume: 0.7);
      case SoundCue.bubble:
        await _playKeyed('bubble', () => _synthPop(520), volume: 0.7);
      case SoundCue.balloon:
        await _playKeyed('balloon', () => _synthPop(280), volume: 0.95);
      case SoundCue.ball:
        await _playNoise(
            'ball', () => _synthClick(420, 0.06, 60, 0.4), volume: 0.7);
      case SoundCue.bowling:
        await _playKeyed('bowl', () => _synthRumble(0.5), volume: 0.75);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _playNoise(
            'bowlpins', () => _synthClick(1400, 0.09, 90, 0.7), volume: 0.6);
      case SoundCue.wood:
        await _playNoise(
            'wood', () => _synthClick(300, 0.07, 45, 0.35), volume: 0.7);
      case SoundCue.metal:
        await _playKeyed('metal', () => _synthRing(1250, 0.22), volume: 0.55);
      case SoundCue.coin:
        await playNote(5, seconds: 0.10);
        await Future<void>.delayed(const Duration(milliseconds: 55));
        await playNote(9, seconds: 0.16);
      case SoundCue.marble:
        await _playNoise(
            'marble', () => _synthClick(1600, 0.03, 120, 0.5), volume: 0.5);
      case SoundCue.stack:
        await _playNoise(
            'stack', () => _synthClick(220, 0.08, 40, 0.3), volume: 0.75);
      case SoundCue.engine:
        await _playKeyed('engine', () => _synthEngine(0.18), volume: 0.5);
      case SoundCue.crash:
        await _playNoise(
            'crash', () => _synthClick(140, 0.20, 16, 0.85), volume: 0.8);
      case SoundCue.laser:
        await _playKeyed('laser', () => _synthLaser(0.22), volume: 0.55);
      case SoundCue.brick:
        await _playNoise(
            'brick', () => _synthClick(1000, 0.04, 120, 0.4), volume: 0.6);
      case SoundCue.snakeEat:
        await _playKeyed('eat', () => _synthPop(620), volume: 0.7);
      case SoundCue.paint:
        await _playKeyed('paint', () => _synthGrain(0.26, 0.75), volume: 0.5);
      case SoundCue.paper:
        await _playKeyed('paper', () => _synthGrain(0.12, 1.0), volume: 0.55);
      case SoundCue.fruit:
        await _playKeyed('fruit', () => _synthPop(440), volume: 0.7);
      case SoundCue.ripple:
        await _play(196,
            seconds: 0.62, wave: _Wave.sine, attack: 0.12, decay: 2.4);
      case SoundCue.learnGood:
        await playNote(4, seconds: 0.16);
        await Future<void>.delayed(const Duration(milliseconds: 70));
        await playNote(7, seconds: 0.22);
      case SoundCue.talkAck:
        await _play(392,
            seconds: 0.28, wave: _Wave.sine, attack: 0.03, decay: 4);
      case SoundCue.routineDone:
        await playNote(2, seconds: 0.16);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await playNote(5, seconds: 0.28);
      case SoundCue.success:
        await playNote(4, seconds: 0.14);
        await Future<void>.delayed(const Duration(milliseconds: 70));
        await playNote(7, seconds: 0.14);
        await Future<void>.delayed(const Duration(milliseconds: 70));
        await playNote(9, seconds: 0.34);
      case SoundCue.gameOver:
        await _play(300,
            seconds: 0.20, wave: _Wave.sine, attack: 0.02, decay: 5);
        await Future<void>.delayed(const Duration(milliseconds: 110));
        await _play(200,
            seconds: 0.30, wave: _Wave.sine, attack: 0.02, decay: 4);
    }
  }

  /// Play a soft "pop" — a short pitched blip whose frequency rises with the
  /// supplied [pitch] (0..1), used by Bubble Pop so small/large bubbles sound
  /// different.
  Future<void> playPop(double pitch) async {
    final p = pitch.clamp(0.0, 1.0);
    final freq = 320 + p * 520;
    final key = 'pop_${(p * 20).round()}';
    await _playKeyed(key, () => _synthPop(freq), volume: 0.95);
  }

  // ---------------------------------------------------------------------------
  // Mechanical one-shots for the fidget toys. These mix a short pitched "body"
  // with white noise and a very fast decay so they read as physical clicks,
  // ticks and thocks rather than musical notes.
  // ---------------------------------------------------------------------------

  final math.Random _rng = math.Random();

  /// A crisp mechanical click — pen clicks, keypad keys, switch flips.
  /// [pitch] scales the body frequency (1.0 = default).
  Future<void> playClick({double pitch = 1.0}) async {
    await _playNoise('click_${(pitch * 20).round()}',
        () => _synthClick(900 * pitch, 0.05, 90, 0.6), volume: 0.7);
  }

  /// A deeper, softer key press "thock".
  Future<void> playThock({double pitch = 1.0}) async {
    await _playNoise('thock_${(pitch * 20).round()}',
        () => _synthClick(260 * pitch, 0.08, 55, 0.45), volume: 0.75);
  }

  /// A light detent "tick" — rotary dial notches, combo-lock wheels.
  Future<void> playTick() async {
    await _playNoise(
        'tick', () => _synthClick(1500, 0.03, 140, 0.7), volume: 0.5);
  }

  /// A toggle click; slightly brighter for the "on" position.
  Future<void> playSwitch({required bool on}) async {
    await _playNoise('switch_$on',
        () => _synthClick(on ? 1100 : 700, 0.045, 100, 0.65), volume: 0.65);
  }

  /// A soft low "squish" for the stress ball.
  Future<void> playSquish() async {
    await _playNoise(
        'squish', () => _synthClick(180, 0.16, 22, 0.35), volume: 0.65);
  }

  /// A rising ratchet buzz for the zipper.
  Future<void> playZip() async {
    await _playNoise('zip', () => _synthZip(0.20), volume: 0.6);
  }

  /// A soft airy whir for the fidget spinner (call once per flick).
  Future<void> playWhir() async {
    await _playNoise('whir', () => _synthWhir(0.55), volume: 0.7);
  }

  Future<void> _playNoise(String key, Uint8List Function() build,
      {double volume = 0.6}) async {
    await _playKeyed(key, build, volume: volume);
  }

  /// A short pitched body blended with white noise and a fast exponential
  /// decay — the building block for clicks, ticks and thocks.
  Uint8List _synthClick(
      double bodyFreq, double seconds, double decay, double noiseMix) {
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    final twoPiF = 2 * math.pi * bodyFreq;
    for (var i = 0; i < frames; i++) {
      final t = i / _sampleRate;
      final env = math.exp(-t * decay);
      final body = math.sin(twoPiF * t);
      final noise = _rng.nextDouble() * 2 - 1;
      final s = body * (1 - noiseMix) + noise * noiseMix;
      data[i] = (s * env * 32767 * 0.7).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  /// A noise burst gated by a buzz whose rate rises over time — a zip sound.
  Uint8List _synthZip(double seconds) {
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    for (var i = 0; i < frames; i++) {
      final t = i / _sampleRate;
      final prog = t / seconds;
      final rate = 60 + prog * 200;
      final buzz = math.sin(2 * math.pi * rate * t) >= 0 ? 1.0 : -1.0;
      final noise = _rng.nextDouble() * 2 - 1;
      final env = math.sin(math.pi * prog);
      final s = noise * buzz;
      data[i] = (s * env * 32767 * 0.5).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  /// Low-passed noise with a soft decay — an airy spinner whir.
  Uint8List _synthWhir(double seconds) {
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    double prev = 0;
    for (var i = 0; i < frames; i++) {
      final t = i / _sampleRate;
      final env = math.exp(-t * 5);
      final noise = _rng.nextDouble() * 2 - 1;
      prev = prev * 0.92 + noise * 0.08;
      data[i] = (prev * env * 32767 * 3.0).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  /// Heavily low-passed noise under a soft bell envelope — granular movement
  /// for sand, paint strokes and paper. [smooth] (0..1) sets how muffled it is.
  Uint8List _synthGrain(double seconds, double smooth) {
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    final a = 0.02 + smooth * 0.14; // low-pass coefficient
    double prev = 0;
    for (var i = 0; i < frames; i++) {
      final prog = i / frames;
      final env = math.sin(math.pi * prog); // soft swell in/out
      final noise = _rng.nextDouble() * 2 - 1;
      prev = prev * (1 - a) + noise * a;
      data[i] = (prev * env * 32767 * 2.6).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  /// A single water droplet: a short sine whose pitch rises then falls with a
  /// tiny transient plip at the very start.
  Uint8List _synthDroplet(double baseFreq) {
    const seconds = 0.13;
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    for (var i = 0; i < frames; i++) {
      final t = i / _sampleRate;
      final prog = t / seconds;
      // Pitch arcs up ~50% then settles.
      final freq = baseFreq * (1.0 + 0.5 * math.sin(prog * math.pi));
      final env = t < 0.004 ? t / 0.004 : math.exp(-(t - 0.004) * 26);
      final body = math.sin(2 * math.pi * freq * t);
      final plip = i < 60 ? (_rng.nextDouble() * 2 - 1) * 0.3 : 0.0;
      final s = body * 0.85 + plip;
      data[i] = (s * env * 32767 * 0.85).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  /// A metallic ring — fundamental plus a slightly detuned upper partial with a
  /// long-ish decay so it shimmers like struck metal.
  Uint8List _synthRing(double freq, double seconds) {
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    for (var i = 0; i < frames; i++) {
      final t = i / _sampleRate;
      final env = t < 0.003 ? t / 0.003 : math.exp(-(t - 0.003) * 14);
      final s = math.sin(2 * math.pi * freq * t) * 0.6 +
          math.sin(2 * math.pi * freq * 2.76 * t) * 0.4;
      data[i] = (s * env * 32767 * 0.6).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  /// A low rolling rumble — heavily low-passed noise that swells then fades,
  /// used for a bowling ball travelling the lane.
  Uint8List _synthRumble(double seconds) {
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    double prev = 0;
    for (var i = 0; i < frames; i++) {
      final prog = i / frames;
      final env = math.sin(math.pi * prog);
      final noise = _rng.nextDouble() * 2 - 1;
      prev = prev * 0.975 + noise * 0.025; // very low cutoff = deep rumble
      data[i] = (prev * env * 32767 * 5.0).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  /// A steady buzzy engine tone — stacked low sines with a touch of grit.
  Uint8List _synthEngine(double seconds) {
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    for (var i = 0; i < frames; i++) {
      final t = i / _sampleRate;
      final env = t < 0.02
          ? t / 0.02
          : (t > seconds - 0.03 ? (seconds - t) / 0.03 : 1.0);
      final s = math.sin(2 * math.pi * 90 * t) * 0.5 +
          math.sin(2 * math.pi * 135 * t) * 0.3 +
          (_rng.nextDouble() * 2 - 1) * 0.15;
      data[i] = (s * env.clamp(0, 1) * 32767 * 0.5)
          .round()
          .clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  /// A futuristic zap — a sine sweeping downward in pitch with a bright ring,
  /// for space dodging and laser bricks.
  Uint8List _synthLaser(double seconds) {
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    for (var i = 0; i < frames; i++) {
      final t = i / _sampleRate;
      final prog = t / seconds;
      final freq = 1400 * (1.0 - 0.7 * prog) + 200;
      final env = math.exp(-t * 10);
      final s = math.sin(2 * math.pi * freq * t) * 0.7 +
          math.sin(2 * math.pi * freq * 1.5 * t) * 0.3;
      data[i] = (s * env * 32767 * 0.6).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
  }

  Future<void> _play(
    double freq, {
    required double seconds,
    required _Wave wave,
    double attack = 0.01,
    double decay = 3.5,
  }) async {
    final key = 't${freq.round()}_${wave.index}_${(seconds * 1000).round()}'
        '_${(attack * 1000).round()}_${decay.round()}';
    await _playKeyed(
      key,
      () => _synth(freq, seconds, wave, attack, decay),
      volume: 0.85,
    );
  }

  /// A punchy bubble pop: a fast downward pitch sweep with a soft noise
  /// transient so it reads as a real "pop" rather than a musical blip.
  Uint8List _synthPop(double startFreq) {
    const seconds = 0.14;
    final frames = (seconds * _sampleRate).round();
    final data = Int16List(frames);
    for (var i = 0; i < frames; i++) {
      final t = i / _sampleRate;
      final prog = t / seconds;
      // Pitch drops ~40% over the life of the pop.
      final freq = startFreq * (1.0 - 0.4 * prog);
      final env = t < 0.006 ? t / 0.006 : math.exp(-(t - 0.006) * 24);
      final body = math.sin(2 * math.pi * freq * t);
      final transient = i < 90 ? (_rng.nextDouble() * 2 - 1) * 0.4 : 0.0;
      final s = body * 0.85 + transient;
      data[i] = (s * env * 32767 * 0.9).round().clamp(-32768, 32767);
    }
    return _wrapWav(data);
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
