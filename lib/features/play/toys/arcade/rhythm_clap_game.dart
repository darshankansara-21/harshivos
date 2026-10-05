part of '../arcade_games.dart';

/// Rhythm Clap — a playhead sweeps a bar of beat markers. Tap the big pad right
/// as it crosses each marker. Hit sixteen beats to win.
class RhythmClapGame extends StatefulWidget {
  const RhythmClapGame({super.key});
  @override
  State<RhythmClapGame> createState() => _RhythmClapGameState();
}

class _RhythmClapGameState extends State<RhythmClapGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'rhythm_clap';
  static const int _target = 16;
  static const double _window = 0.06;
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  List<double> _markers = <double>[0.2, 0.4, 0.6, 0.8];
  List<bool> _hit = <bool>[false, false, false, false];
  double _head = 0;
  double _barTime = 2.6;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  double _padFlash = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newBar() {
    final n = 3 + _rnd.nextInt(3); // 3..5 markers
    _markers = <double>[];
    for (var i = 0; i < n; i++) {
      _markers.add(0.15 + (i + _rnd.nextDouble() * 0.5) * (0.7 / n));
    }
    _hit = List<bool>.filled(n, false);
    _head = 0;
    _barTime = (2.6 - _score * 0.06).clamp(1.6, 2.6);
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_padFlash > 0) _padFlash -= dt;
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
    }
    final prev = _head;
    _head += dt / _barTime;
    // Mark missed markers the playhead passed without a hit.
    for (var i = 0; i < _markers.length; i++) {
      if (!_hit[i] && prev < _markers[i] && _head >= _markers[i] + _window) {
        _hit[i] = true; // count as resolved (missed)
        _lives--;
        if (_lives <= 0) {
          // The run-ending miss needs its own distinct cue, not the routine
          // gentle-retry sound used for every other missed beat.
          _status = GameStatus.over;
          TonePlayer.instance.playCue(SoundCue.gameOver);
          emit(ExperienceEvent.incorrectAnswer);
        } else {
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
        }
      }
    }
    if (_head >= 1) _newBar();
  }

  void _clap() {
    if (_status != GameStatus.playing) return;
    _padFlash = 0.25;
    for (var i = 0; i < _markers.length; i++) {
      if (!_hit[i] && (_head - _markers[i]).abs() <= _window) {
        _hit[i] = true;
        _score++;
        for (var j = 0; j < 8; j++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.15 + _rnd.nextDouble() * 0.3;
          _bits.add(_Shard(_markers[i], 0.4, math.cos(a) * sp, math.sin(a) * sp,
              const Color(0xFFFFD166)));
        }
        TonePlayer.instance.playNote(4 + (_score % 5), seconds: 0.18);
        emit(ExperienceEvent.bubblePopped);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        if (_score >= _target) {
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        }
        return;
      }
    }
    TonePlayer.instance.playThock();
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _newBar();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '👏 Rhythm Clap',
      introHow:
          'A line sweeps across the beats. Tap the big pad right as it reaches each glowing beat!',
      onStart: () => setState(() {
        _newBar();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Clap on the beat! · ${'💛' * _lives}',
      overEmoji: 'u{1F4AA}',
      overText: 'Out of lives — nice try!',
      winEmoji: '👏',
      winText: 'In the groove!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _clap(),
            child: CustomPaint(
              painter: _RhythmPainter(
                markers: _markers,
                hit: _hit,
                head: _head,
                padFlash: _padFlash,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _RhythmPainter extends CustomPainter {
  _RhythmPainter({
    required this.markers,
    required this.hit,
    required this.head,
    required this.padFlash,
    required this.bits,
  });
  final List<double> markers;
  final List<bool> hit;
  final double head, padFlash;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF241B3A));
    final trackY = h * 0.4;
    canvas.drawLine(Offset(w * 0.1, trackY), Offset(w * 0.9, trackY),
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 4);
    double mx(double m) => w * (0.1 + m * 0.8);
    for (var i = 0; i < markers.length; i++) {
      canvas.drawCircle(Offset(mx(markers[i]), trackY), 14,
          Paint()..color = hit[i] ? const Color(0xFFFFD166) : Colors.white70);
    }
    // Playhead.
    canvas.drawLine(Offset(mx(head), trackY - 30), Offset(mx(head), trackY + 30),
        Paint()
          ..color = const Color(0xFF66D9E8)
          ..strokeWidth = 3);
    // Clap pad.
    final pad = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.76), width: w * 0.5, height: h * 0.28);
    canvas.drawRRect(
        RRect.fromRectAndRadius(pad, const Radius.circular(24)),
        Paint()
          ..color = Color.lerp(const Color(0xFF3A2E5E), Colors.white,
              (padFlash / 0.25).clamp(0.0, 1.0) * 0.6)!);
    final tp = TextPainter(
      text: const TextSpan(text: '👏', style: TextStyle(fontSize: 48)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pad.center - Offset(tp.width / 2, tp.height / 2));
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_RhythmPainter old) => true;
}

