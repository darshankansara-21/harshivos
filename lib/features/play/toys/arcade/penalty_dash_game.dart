part of '../arcade_games.dart';

/// Penalty Dash — a striker marker and the keeper both slide along the goal.
/// Tap to shoot the instant the marker is clear of the keeper and inside the
/// posts. It all speeds up as you score. Ten goals to win, five misses is over.
class PenaltyDashGame extends StatefulWidget {
  const PenaltyDashGame({super.key});
  @override
  State<PenaltyDashGame> createState() => _PenaltyDashGameState();
}

class _PenaltyDashGameState extends State<PenaltyDashGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'penalty_dash';
  static const int _target = 10;

  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Ten goals! You won the shootout!',
    'Golden boot!',
    'Shootout champion!',
    'Clinical finish!',
  ];
  String _winPraise = _winPraisePool.first;
  // The routine (non-fatal) miss banner was a flat, always-identical 'Saved!'
  // or 'Wide!' literal — the exact same flat-repeated-miss-text gap already
  // fixed in whack_game.dart/catch_beat_game.dart. Up to 4 misses can fire
  // this per playthrough, every playthrough, forever.
  static const List<String> _savedPool = <String>[
    'Saved!',
    'Great stop!',
    'Keeper got it!',
    'Denied!',
  ];
  static const List<String> _widePool = <String>[
    'Wide!',
    'Just off target!',
    'Not this time!',
    'So close!',
  ];
  // Mirrors hoop_toss_game.dart's fix: every other aim-and-score game in the
  // catalog bursts a few shards of colour on a successful hit, but a GOAL
  // here only ever flashed the banner text + a sound — flatter than almost
  // every other scoring moment in the catalog.
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  double _t = 0;
  double _marker = 0.5;
  double _keeper = 0.5;
  int _score = 0, _misses = 0, _best = 0;
  // Every other target-based scoring game in the catalog (basketball,
  // firefly_count, block_blast, soccer_kick) fires a mid-run "beat your own
  // all-time best" celebration the moment a run's score overtakes the prior
  // record — Penalty Dash tracked `_best` but never checked for or
  // celebrated crossing it, so a child quietly beating their record mid-run
  // got only the routine 'GOAL!' chime, same as every other goal.
  bool _beatBest = false;
  double _flashX = -1, _flashT = 0;
  double _shotLockT = 0;
  bool _flashGoal = false;
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
  // echo_drums_game/drum_garden_game/air_hockey_game: the marker/keeper
  // slide speed only ramped within a single run (`_score * 0.12`), so a
  // child who has already scored dozens of career goals still opens every
  // fresh shootout at the exact same gentle 1.6 pace as a first-time
  // player. Small capped career nudge (well short of the in-run ramp above)
  // so a returning skilled player meets a slightly livelier keeper from
  // shot one, while a fresh/low-`_best` child still gets the original easy
  // opener.
  double get _careerPaceRamp => (_best / (_target * 4)).clamp(0.0, 1.0) * 0.6;

  double get _speed => 1.6 + _careerPaceRamp + _score * 0.12;

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _t += dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_flashT > 0) _flashT -= dt;
    if (_shotLockT > 0) _shotLockT -= dt;
    _marker = 0.5 + 0.38 * math.sin(_t * _speed);
    _keeper = 0.5 + 0.30 * math.sin(_t * _speed * 0.8 + 1.7);
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

  void _shoot() {
    if (_status != GameStatus.playing || _shotLockT > 0) return;
    // Penalty Dash resolves a shot immediately on tap, so without a brief lock
    // an accidental double-tap or two near-simultaneous fingers can score (or
    // miss) twice off the exact same keeper/marker state before the next frame.
    _shotLockT = 0.18;
    _flashX = _marker;
    _flashT = 0.5;
    final inPosts = _marker > 0.17 && _marker < 0.83;
    final beatsKeeper = (_marker - _keeper).abs() > 0.14;
    if (inPosts && beatsKeeper) {
      _flashGoal = true;
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      final n = _reduceMotion ? 4 : 12;
      for (var i = 0; i < n; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard(_marker, 0.3, math.cos(a) * sp, math.sin(a) * sp,
            const Color(0xFF80ED99)));
      }
      _banner = 'GOAL!  ⚽';
      _bannerT = 1.1;
      // Capture before the async submit resolves so a win on this same goal
      // can't race the best-update and silently swallow the celebration.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (crossedBest) {
        _beatBest = true;
        // Takes priority over the routine 'GOAL!' banner just set above —
        // a new all-time record is the bigger moment of the two.
        _banner = 'New personal best! 🏆';
        _bannerT = 1.1;
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_score >= _target) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      }
    } else {
      _flashGoal = false;
      _misses++;
      if (_misses >= 5) {
        // The game-ending miss must sound distinct from a routine miss,
        // never just the same gentle-retry cue as every other shot.
        _status = GameStatus.over;
        _banner = 'Out of shots!';
        _bannerT = 1.1;
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = inPosts
            ? _savedPool[_rnd.nextInt(_savedPool.length)]
            : _widePool[_rnd.nextInt(_widePool.length)];
        _bannerT = 1.1;
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _misses = 0;
      _t = 0;
      _beatBest = false;
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _shotLockT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '🥅 Penalty Dash',
      introHow:
          'Tap to shoot when the striker marker is clear of the keeper and '
          'between the posts. Ten goals to win!',
      onStart: () => setState(() {
        _t = 0;
        _shotLockT = 0;
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Goals $_score/$_target  ·  ${'🧤' * (5 - _misses)}',
      overEmoji: '💪',
      overText: 'Out of shots — nice try!',
      winEmoji: '🥅',
      winText: _winPraise,
      accent: const Color(0xFF80ED99),
      onPlayAgain: _reset,
      child: Semantics(
        button: true,
        label: 'Goals $_score of $_target. Tap to shoot when the striker is '
            'clear of the keeper and between the posts.',
        onTap: _shoot,
        excludeSemantics: true,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _shoot(),
        child: CustomPaint(
          painter: _PenaltyDashPainter(
            marker: _marker,
            keeper: _keeper,
            flashX: _flashT > 0 ? _flashX : -1,
            flashGoal: _flashGoal,
            bits: _bits,
          ),
          size: Size.infinite,
        ),
        ),
      ),
    );
  }
}

class _PenaltyDashPainter extends CustomPainter {
  _PenaltyDashPainter({
    required this.marker,
    required this.keeper,
    required this.flashX,
    required this.flashGoal,
    required this.bits,
  });
  final double marker, keeper, flashX;
  final bool flashGoal;
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
            colors: <Color>[Color(0xFF2E7D32), Color(0xFF1B5E20)],
          ).createShader(Offset.zero & size));

    final gy = h * 0.3;
    final goalL = w * 0.17, goalR = w * 0.83;
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(goalL, gy), Offset(goalL, gy - h * 0.14), post);
    canvas.drawLine(Offset(goalR, gy), Offset(goalR, gy - h * 0.14), post);
    canvas.drawLine(Offset(goalL, gy - h * 0.14), Offset(goalR, gy - h * 0.14), post);

    // Keeper.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(keeper * w, gy - h * 0.05),
                width: w * 0.12,
                height: h * 0.09),
            const Radius.circular(10)),
        Paint()..color = const Color(0xFFFFD166));

    // Striker meter at the bottom.
    final my = h * 0.82;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.1, my - 8, w * 0.8, 16),
            const Radius.circular(8)),
        Paint()..color = Colors.black26);
    canvas.drawCircle(Offset(marker * w, my), 14,
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(marker * w, my), 7,
        Paint()..color = const Color(0xFF222222));

    // Shot flash.
    if (flashX >= 0) {
      canvas.drawLine(
          Offset(flashX * w, my),
          Offset(flashX * w, gy),
          Paint()
            ..color = (flashGoal ? const Color(0xFF80ED99) : const Color(0xFFE23B3B))
                .withOpacity(0.8)
            ..strokeWidth = 4);
    }

    for (final b in bits) {
      final k = (b.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(b.x * w, b.y * h), 2 + 3 * k,
          Paint()..color = b.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_PenaltyDashPainter oldDelegate) => true;
}
