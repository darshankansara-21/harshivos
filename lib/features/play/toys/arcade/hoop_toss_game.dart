part of '../arcade_games.dart';

/// Hoop Toss — the peg slides back and forth; tap to toss the ring and time it
/// so the peg is under the ring when it lands. The peg speeds up as you score.
/// Ring it ten times to win; five misses ends the game.
class HoopTossGame extends StatefulWidget {
  const HoopTossGame({super.key});
  @override
  State<HoopTossGame> createState() => _HoopTossGameState();
}

class _HoopTossGameState extends State<HoopTossGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'hoop_toss';
  static const int _target = 10;
  static const double _pegY = 0.3;

  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Good tosses!',
    'Ringer streak!',
    'Perfect aim!',
    'Hoop champion!',
  ];
  String _winPraise = _winPraisePool.first;
  String _overPraise = _gentleTryAgainPool[0];
  // Every routine near-miss flashed the exact same "Just missed!" banner
  // (up to several times in one round); vary it like the win-screen praise.
  static const List<String> _missPool = <String>[
    'Just missed!', 'So close!', 'Almost there!', 'Nearly!',
  ];
  // Every other aim-and-score game in the catalog (basketball, target_toss,
  // bug_catch, pinball, brick_break...) bursts a few shards of colour on a
  // successful hit; Hoop Toss only ever flashed the banner text + a sound,
  // making a "Ringer!" feel flatter than catching a single bug elsewhere in
  // the same catalog. Mirror the established celebratory-burst convention.
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  double _t = 0;
  double _pegX = 0.5;
  double _ringY = 0.86;
  bool _flying = false;
  int _score = 0, _misses = 0, _best = 0;
  // Unlike every sibling score-with-lives game (balloon_math, firefly_count,
  // odd_one_out...), five misses can end a Hoop Toss run before the 10-ring
  // win target — but a near-miss-ending run that still beat a prior all-time
  // best silently got nothing but the routine "Ringer!" banner. Mirror the
  // catalog-wide mid-run personal-best celebration.
  bool _beatBest = false;
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

  // Same "flat-forever opening pace never fed by career `_best`" bug class
  // already fixed in space_dodge_game/whack_game/rhythm_clap_game/
  // echo_drums_game/drum_garden_game/air_hockey_game/penalty_dash_game/
  // piano_tiles_game: the peg's swing speed only ever ramped within a
  // single run (`_score * 0.13`), so a child who has already ringed dozens
  // of career hoops still opens every fresh toss at the exact same gentle
  // 1.7 pace as a first-time player. Small capped career nudge (well short
  // of the in-run ramp above) so a returning skilled player meets a
  // slightly livelier peg from toss one, while a fresh/low-`_best` child
  // still gets the original easy opener.
  double get _careerPaceRamp => (_best / (_target * 4)).clamp(0.0, 1.0) * 0.5;

  double get _speed => 1.7 + _careerPaceRamp + _score * 0.13;
  // The catch tolerance below only ever read the current round's `_score`,
  // so a veteran's opening toss was just as forgiving as a first-timer's —
  // the same "flat-forever difficulty never fed by career `_best`" bug
  // class as `_speed` above, just on the tolerance axis. Reuse the same
  // `_careerPaceRamp` (already capped) scaled down to this axis's range.
  double get _catch =>
      (0.1 - _score * 0.004 - _careerPaceRamp * 0.02).clamp(0.05, 0.1);

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _pegX = 0.5 + 0.36 * math.sin(_t * _speed);
    if (_flying) {
      _ringY -= 1.15 * dt;
      if (_ringY <= _pegY) _resolve();
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.5 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    setState(() {});
  }

  void _burst(Color color) {
    final n = _reduceMotion ? 4 : 12;
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.3;
      _bits.add(_Shard(_pegX, _pegY, math.cos(a) * sp, math.sin(a) * sp, color));
    }
  }

  void _resolve() {
    _flying = false;
    _ringY = 0.86;
    if ((_pegX - 0.5).abs() < _catch) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _burst(const Color(0xFFFFD166));
      _banner = 'Ringer!  🎯';
      _bannerT = 1.1;
      // A child whose run ends in misses right after this toss still
      // deserves the companion's loudest celebration if it's a genuine
      // all-time record, not just the routine ringer chime.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (crossedBest) {
        _beatBest = true;
        _banner = 'New personal best! 🏆';
        _bannerT = 1.2;
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_score >= _target) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
      }
    } else {
      _misses++;
      if (_misses >= 5) {
        // The game-ending miss must sound distinct from a routine miss,
        // never just the same gentle-retry cue as every other near-miss.
        _status = GameStatus.over;
        _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
        _banner = 'Out of rings!';
        _bannerT = 1.2;
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = _missPool[_rnd.nextInt(_missPool.length)];
        _bannerT = 1.1;
      }
    }
  }

  void _toss() {
    if (_status != GameStatus.playing || _flying) return;
    _flying = true;
    _ringY = 0.86;
    TonePlayer.instance.playCue(SoundCue.wood);
  }

  void _reset() {
    setState(() {
      _score = 0;
      _misses = 0;
      _beatBest = false;
      _t = 0;
      _flying = false;
      _ringY = 0.86;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '🎪 Hoop Toss',
      introHow:
          'Tap to toss the ring and time it so the sliding peg is right under '
          'it. Ring it ten times to win!',
      onStart: () => setState(() {
        _t = 0;
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Ringers $_score/$_target  ·  ${'⭕' * (5 - _misses)}',
      overEmoji: '💪',
      overText: _overPraise,
      winEmoji: '🎪',
      winText: _winPraise,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: Semantics(
        button: true,
        label: 'Ringers $_score of $_target. Tap to toss the ring when the '
            'sliding peg is under it.',
        onTap: _toss,
        excludeSemantics: true,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _toss(),
        child: CustomPaint(
          painter: _HoopTossPainter(
              pegX: _pegX,
              pegY: _pegY,
              ringY: _ringY,
              flying: _flying,
              bits: _bits),
          size: Size.infinite,
        ),
        ),
      ),
    );
  }
}

class _HoopTossPainter extends CustomPainter {
  _HoopTossPainter({
    required this.pegX,
    required this.pegY,
    required this.ringY,
    required this.flying,
    required this.bits,
  });
  final double pegX, pegY, ringY;
  final bool flying;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF3A2A5E), Color(0xFF1C1430)],
          ).createShader(Offset.zero & size));

    // Peg + base.
    final px = pegX * w, py = pegY * h;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(px, py + h * 0.03), width: w * 0.05, height: h * 0.12),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFBC6C25));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py + h * 0.1), width: w * 0.16, height: h * 0.03),
        Paint()..color = const Color(0xFF8A4F18));

    // Ring.
    final ry = (flying ? ringY : 0.86) * h;
    canvas.drawCircle(
        Offset(w * 0.5, ry),
        w * 0.075,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0xFF48CAE4));
    canvas.drawCircle(
        Offset(w * 0.5, ry),
        w * 0.075,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white70);

    for (final b in bits) {
      final k = (b.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(b.x * w, b.y * h), 2 + 3 * k,
          Paint()..color = b.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_HoopTossPainter oldDelegate) => true;
}
