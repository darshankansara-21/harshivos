part of '../arcade_games.dart';

/// Catch-the-Beat — colour orbs drop in four lanes. Tap a lane the instant its
/// orb crosses the glowing line. Keep a combo and catch 20 to win.
class CatchBeatGame extends StatefulWidget {
  const CatchBeatGame({super.key});
  @override
  State<CatchBeatGame> createState() => _CatchBeatGameState();
}

class _Orb {
  _Orb(this.lane, this.y);
  final int lane;
  double y;
  bool dead = false;
}

class _CatchBeatGameState extends State<CatchBeatGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'catch_beat';
  static const int _lanes = 4;
  static const int _target = 20;
  static const double _hitY = 0.82;
  static const double _window = 0.1;
  static const List<int> _laneNotes = <int>[0, 4, 7, 11];
  static const List<Color> _laneColors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF8CE99A),
    Color(0xFF66D9E8),
  ];
  final math.Random _rnd = math.Random();
  final List<_Orb> _orbs = <_Orb>[];
  final List<_Shard> _bits = <_Shard>[];
  double _spawnT = 0;
  double _fall = 0.55;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _lives = 3;
  int _best = 0;
  int _laneFlash = -1;
  double _laneFlashT = 0;
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

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.2;
  }

  // Stagger the two difficulty knobs so only one gets harder at a time: the
  // first half of the run the orbs arrive faster (spawn interval shrinks
  // while fall speed holds steady), the second half the spawn rate is
  // locked and only the fall speed keeps climbing — instead of both
  // compounding together from the very first catch.
  double _spawnInterval(int score) {
    const half = _target / 2;
    if (score <= half) return math.max(0.65, 1.1 - score * 0.045);
    return 0.65;
  }

  double _fallSpeed(int score) {
    const half = _target / 2;
    if (score <= half) return 0.55;
    return (0.55 + (score - half) * 0.04).clamp(0.55, 0.95);
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_laneFlashT > 0) {
      _laneFlashT -= dt;
      if (_laneFlashT <= 0) _laneFlash = -1;
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    _spawnT -= dt;
    if (_spawnT <= 0) {
      _orbs.add(_Orb(_rnd.nextInt(_lanes), -0.05));
      _spawnT = _spawnInterval(_score);
    }
    for (var i = _orbs.length - 1; i >= 0; i--) {
      final o = _orbs[i];
      o.y += _fall * dt;
      if (o.dead) {
        _orbs.removeAt(i);
        continue;
      }
      if (o.y > _hitY + _window) {
        // Missed.
        o.dead = true;
        _combo = 0;
        _lives--;
        if (_lives <= 0) {
          // Out of lives is the real end of the run — it must sound distinct
          // from a routine miss, never just the same gentle-retry cue.
          _status = GameStatus.over;
          _flash('Out of lives!');
          TonePlayer.instance.playCue(SoundCue.gameOver);
          emit(ExperienceEvent.incorrectAnswer);
        } else {
          _flash('Missed!');
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
        }
        _orbs.removeAt(i);
      }
    }
  }

  void _tapLane(int lane) {
    if (_status != GameStatus.playing) return;
    _laneFlash = lane;
    _laneFlashT = 0.2;
    _Orb? best;
    var bestDist = 999.0;
    for (final o in _orbs) {
      if (o.lane != lane || o.dead) continue;
      final d = (o.y - _hitY).abs();
      if (d < bestDist) {
        bestDist = d;
        best = o;
      }
    }
    if (best != null && bestDist <= _window) {
      best.dead = true;
      _score++;
      _combo++;
      if (_combo > _bestCombo) _bestCombo = _combo;
      _fall = _fallSpeed(_score);
      for (var i = 0; i < 10; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard((lane + 0.5) / _lanes, _hitY, math.cos(a) * sp,
            math.sin(a) * sp, _laneColors[lane]));
      }
      TonePlayer.instance.playNote(_laneNotes[lane], seconds: 0.22);
      emit(ExperienceEvent.bubblePopped);
      if (bestDist < _window * 0.4) {
        _flash(_combo >= 3 ? 'Perfect! x$_combo 🔥' : 'Perfect!');
      } else if (_combo >= 3) {
        _flash('Combo x$_combo');
      }
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      }
    }
  }

  void _reset() {
    setState(() {
      _orbs.clear();
      _bits.clear();
      _spawnT = 0;
      _fall = 0.55;
      _score = 0;
      _combo = 0;
      _lives = 3;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎶 Catch the Beat',
      introHow:
          'Orbs fall in four lanes. Tap a lane right when its orb hits the glowing line. Keep your combo!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Caught $_score/$_target · ${'💛' * _lives}',
      overEmoji: '🎶',
      // _bestCombo is tracked all run but, until now, was only ever surfaced
      // on the win screen — a run that ends in a miss (the more common
      // outcome for a new player) silently threw the same stat away.
      overText: _bestCombo >= 2
          ? 'Nice rhythm! Best combo x$_bestCombo 🔥'
          : 'Nice rhythm!',
      winEmoji: '🎶',
      winText: _bestCombo >= 2
          ? 'Rhythm star! Best combo x$_bestCombo 🔥'
          : 'Rhythm star!',
      accent: const Color(0xFF66D9E8),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _tapLane((d.localPosition.dx / w * _lanes).floor().clamp(0, _lanes - 1)),
            child: CustomPaint(
              painter: _CatchPainter(
                lanes: _lanes,
                hitY: _hitY,
                orbs: _orbs,
                colors: _laneColors,
                laneFlash: _laneFlash,
                laneFlashT: _laneFlashT,
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

class _CatchPainter extends CustomPainter {
  _CatchPainter({
    required this.lanes,
    required this.hitY,
    required this.orbs,
    required this.colors,
    required this.laneFlash,
    required this.laneFlashT,
    required this.bits,
  });
  final int lanes;
  final double hitY;
  final List<_Orb> orbs;
  final List<Color> colors;
  final int laneFlash;
  final double laneFlashT;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF13112A));
    final lw = w / lanes;
    for (var i = 0; i < lanes; i++) {
      if (i.isOdd) {
        canvas.drawRect(Rect.fromLTWH(i * lw, 0, lw, h),
            Paint()..color = Colors.white.withOpacity(0.03));
      }
      if (laneFlash == i) {
        canvas.drawRect(Rect.fromLTWH(i * lw, 0, lw, h),
            Paint()..color = colors[i].withOpacity(laneFlashT / 0.2 * 0.25));
      }
    }
    // Hit line.
    canvas.drawLine(Offset(0, hitY * h), Offset(w, hitY * h),
        Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..strokeWidth = 3);
    for (var i = 0; i < lanes; i++) {
      canvas.drawCircle(Offset((i + 0.5) * lw, hitY * h), lw * 0.3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = colors[i].withOpacity(0.6));
    }
    for (final o in orbs) {
      if (o.dead) continue;
      canvas.drawCircle(Offset((o.lane + 0.5) * lw, o.y * h), lw * 0.3,
          Paint()..color = colors[o.lane]);
      canvas.drawCircle(
          Offset((o.lane + 0.5) * lw - lw * 0.08, o.y * h - lw * 0.08),
          lw * 0.1,
          Paint()..color = Colors.white.withOpacity(0.7));
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_CatchPainter old) => true;
}

