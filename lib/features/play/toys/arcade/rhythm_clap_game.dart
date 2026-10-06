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
  static const List<String> _winPraisePool = <String>[
    'In the groove!', 'Perfect rhythm!', 'Beat master!', 'On the beat!',
  ];
  String _winPraise = _winPraisePool[0];
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  List<double> _markers = <double>[0.2, 0.4, 0.6, 0.8];
  List<bool> _hit = <bool>[false, false, false, false];
  List<bool> _missed = <bool>[false, false, false, false];
  double _head = 0;
  double _barTime = 2.6;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  bool _beatBest = false;
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
    _missed = List<bool>.filled(n, false);
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
      if (!_hit[i] && !_missed[i] && prev < _markers[i] &&
          _head >= _markers[i] + _window) {
        _missed[i] = true; // resolved as a miss, NOT a hit — keep the two
        // visually distinct so a missed beat never looks like a success.
        _lives--;
        // Every missed beat deserves the companion's gentle encouraging
        // reaction, not just the one that happens to end the game.
        emit(ExperienceEvent.incorrectAnswer);
        if (_lives <= 0) {
          // The run-ending miss needs its own distinct cue, not the routine
          // gentle-retry sound used for every other missed beat.
          _status = GameStatus.over;
          TonePlayer.instance.playCue(SoundCue.gameOver);
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
      if (!_hit[i] && !_missed[i] && (_head - _markers[i]).abs() <= _window) {
        _hit[i] = true;
        _score++;
        final bitCount = _reduceMotion ? 3 : 8;
        for (var j = 0; j < bitCount; j++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.15 + _rnd.nextDouble() * 0.3;
          _bits.add(_Shard(_markers[i], 0.4, math.cos(a) * sp, math.sin(a) * sp,
              const Color(0xFFFFD166)));
        }
        TonePlayer.instance.playNote(4 + (_score % 5), seconds: 0.18);
        emit(ExperienceEvent.bubblePopped);
        // A child who runs out of lives right after this clap still
        // deserves the companion's loudest celebration if it's a genuine
        // all-time record, not just the routine correct-clap chime.
        final crossedBest = _score > _best && !_beatBest && _best > 0;
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        if (crossedBest) {
          _beatBest = true;
          // Every sibling game shows "New personal best! 🏆" on screen the
          // instant a record falls, not just a sound — this was the one
          // arcade game left where `_banner`/`_bannerT` existed and were
          // already wired into the banner widget below, but the
          // personal-best branch never actually populated them, so a child
          // smashing their own record heard the milestone chime with zero
          // matching text on screen.
          _banner = 'New personal best! 🏆';
          _bannerT = 1.4;
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        if (_score >= _target) {
          _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
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
      _beatBest = false;
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
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '👏 Rhythm Clap',
      introHow:
          'A line sweeps across the beats. Tap the big pad right as it reaches each glowing beat! '
          'A missed beat costs one of your 3 lives.',
      onStart: () => setState(() {
        _newBar();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Clap on the beat! · ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '👏',
      winText: _winPraise,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          return Semantics(
            // This whole-screen pad was tappable only via a bare
            // GestureDetector with zero Semantics tree, so a screen-reader
            // user had no focusable element at all to find or double-tap —
            // not just an unlabeled one, but a game with no accessible
            // surface whatsoever. The label never reveals *when* the beat
            // lands (that's the real rhythm challenge every child faces),
            // only that this pad is what to tap.
            button: true,
            label: 'Clap pad. Tap in time with the beat.',
            onTap: _clap,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _clap(),
              child: CustomPaint(
                painter: _RhythmPainter(
                  markers: _markers,
                  hit: _hit,
                  missed: _missed,
                  head: _head,
                  padFlash: _padFlash,
                  bits: _bits,
                ),
                size: Size.infinite,
              ),
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
    required this.missed,
    required this.head,
    required this.padFlash,
    required this.bits,
  });
  final List<double> markers;
  final List<bool> hit;
  final List<bool> missed;
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
      final color = hit[i]
          ? const Color(0xFFFFD166)
          : (missed[i] ? Colors.white24 : Colors.white70);
      canvas.drawCircle(Offset(mx(markers[i]), trackY), 14,
          Paint()..color = color);
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

