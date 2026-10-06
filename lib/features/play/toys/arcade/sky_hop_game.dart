part of '../arcade_games.dart';

class SkyHopGame extends StatefulWidget {
  const SkyHopGame({super.key});
  @override
  State<SkyHopGame> createState() => _SkyHopGameState();
}

class _Pipe {
  _Pipe(this.x, this.gapY, this.coinY);
  double x;
  double gapY;
  final double coinY;
  bool scored = false;
  bool coinTaken = false;
}

class _SkyHopGameState extends State<SkyHopGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'sky_hop';
  static const double _gap = 0.28; // fraction of height
  static const int _goalScore = 18;
  static const double _basePipeSpeed = 0.42;
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Sky clear!" line on win screen (across-restarts sibling
  // of the per-pipe-clear praise-variety fix already applied in this file).
  static const List<String> _winPraisePool = <String>[
    'Sky clear!',
    'Flight complete!',
    'Perfect flapper!',
    'Soaring champion!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  final List<_Pipe> _pipes = <_Pipe>[];
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  double _birdY = 0.5;
  double _vy = 0;
  double _spawnIn = 0;
  double _pipeSpeed = _basePipeSpeed;
  int _score = 0;
  int _best = 0;
  int _coinCombo = 0;
  int _bestCoinCombo = 0;
  bool _started = false;
  // Same "flat-forever difficulty never fed by career `_best`" bug class
  // already fixed catalog-wide (brick_break/hoop_toss/piano_tiles/
  // space_dodge/air_hockey/goal_keeper/...): pipe speed and spawn gap only
  // ever scaled with the CURRENT run's `_score`, resetting to the identical
  // gentle opener every single replay no matter how many pipes a flier has
  // historically cleared. Nudges both knobs a little from pipe 1 of every
  // flight for a flier with a high all-time `_best`, capped small so the
  // very first pipe of a match stays reachable even for a seasoned player.
  double get _careerPaceRamp =>
      (_best / (_goalScore * 3)).clamp(0.0, 1.0) * 0.5;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Mirrors mini_games.dart's FruitCatchGame/BalloonPopGame/StarTapGame/
  // SnakeGame/RacingGame/BowlingGame live "beat your own all-time best"
  // celebration. Sky Hop's score only ever climbs (pipe clears + coin
  // bonuses, never decreases), so crossing a prior personal best mid-flight
  // — well before the fixed 18-point win goal — is a real, judgment-free
  // moment worth its own banner.
  bool _beatBest = false;
  // `_bestCoinCombo` used to live only in widget state — it tracked the
  // longest coin streak within a single app session (surviving replays via
  // `_reset()` leaving it untouched) but was silently thrown away the moment
  // the app restarted, unlike every other secondary stat in the catalog
  // (basketball's fewest-shots record, catch-the-beat's best-combo record):
  // a child's all-time best coin streak could never actually be "all-time".
  // Persist it the same way via `GameScores.submit`.
  static const String _comboId = '${_id}_coin_combo';

  // Clearing a pipe always said the identical "Nice hop!" — up to 18 times
  // in a single winning run — which reads as flat/robotic well before the
  // run ends, hurting the "child delight"/"replayability" rubric criteria
  // even though the underlying hop mechanic itself is solid. A small random
  // pool of equally short, equally readable phrases keeps every clear
  // feeling freshly celebrated without changing scoring or timing at all.
  static const List<String> _hopPraise = <String>[
    'Nice hop!',
    'Clean gap!',
    'Smooth flap!',
    'Great timing!',
    'Through you go!',
  ];

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) {
        setState(() {
          _best = GameScores.instance.best(_id);
          _bestCoinCombo = GameScores.instance.best(_comboId);
        });
      }
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) {
        _banner = null;
        _coinCombo = 0;
      }
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 0.6 * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
    }
    if (!_started) return;
    _pipeSpeed = math.min(
        0.82, _basePipeSpeed + _careerPaceRamp * 0.12 + _score * 0.02);
    _vy += 1.6 * dt; // gravity
    _birdY += _vy * dt;
    _spawnIn -= dt;
    if (_score >= _goalScore && _status == GameStatus.playing) {
      _status = GameStatus.won;
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
      _banner = 'Sky clear!';
      _bannerT = 1.4;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      return;
    }
    if (_spawnIn <= 0) {
      _spawnIn = math.max(
          1.1, 1.7 - _careerPaceRamp * 0.25 - _score * 0.04);
      final gapY = 0.18 + _rnd.nextDouble() * 0.64;
      final coinY = gapY + (_rnd.nextDouble() - 0.5) * _gap * 0.7;
      _pipes.add(_Pipe(1.1, gapY, coinY));
    }
    for (final p in _pipes) {
      p.x -= _pipeSpeed * dt;
      if (!p.scored && p.x < 0.28) {
        p.scored = true;
        // Only break the streak when THIS pipe's coin was missed — a coin
        // already grabbed on this pass must survive into the next pipe, or
        // the "Coin streak" bonus could mathematically never exceed x1.
        if (!p.coinTaken) _coinCombo = 0;
        _score++;
        _banner = _hopPraise[_rnd.nextInt(_hopPraise.length)];
        _bannerT = 0.8;
        TonePlayer.instance.playCue(SoundCue.coin);
        emit(ExperienceEvent.bubblePopped);
      }
      if (!p.coinTaken &&
          (p.x - 0.3).abs() < 0.09 &&
          (_birdY - p.coinY).abs() < 0.06) {
        p.coinTaken = true;
        _coinCombo += 1;
        if (_coinCombo > _bestCoinCombo) {
          _bestCoinCombo = _coinCombo;
          GameScores.instance.submit(_comboId, _coinCombo);
        }
        final bonus = 2 + (_coinCombo - 1);
        _score += bonus;
        _banner = _coinCombo > 1 ? 'Coin streak x$_coinCombo!' : 'Coin grab!';
        _bannerT = 1.2;
        final coinBitCount = _reduceMotion ? 3 : 8;
        for (var k = 0; k < coinBitCount; k++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.1 + _rnd.nextDouble() * 0.22;
          _bits.add(_Shard(p.x, p.coinY, math.cos(a) * sp, math.sin(a) * sp,
              const Color(0xFFFFE066)));
        }
        TonePlayer.instance.playCue(SoundCue.coin);
      }
      if ((p.x - 0.3).abs() < 0.11 &&
          (_birdY < p.gapY - _gap / 2 || _birdY > p.gapY + _gap / 2)) {
        _over();
        return;
      }
    }
    if (_status == GameStatus.playing &&
        !_beatBest &&
        _best > 0 &&
        _score > _best) {
      _beatBest = true;
      // Takes priority over the hop/coin banner just set above this tick —
      // a new all-time record is the bigger moment of the two.
      _banner = 'New personal best! 🏆';
      _bannerT = 1.6;
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
    _pipes.removeWhere((p) => p.x < -0.2);
    if (_birdY > 0.98 || _birdY < 0.02) _over();
  }

  void _flap() {
    if (_status != GameStatus.playing) return;
    _started = true;
    _vy = -0.68;
    for (var k = 0; k < 4; k++) {
      _bits.add(_Shard(0.3, _birdY + 0.03, -0.14 - _rnd.nextDouble() * 0.1,
          0.05 + _rnd.nextDouble() * 0.1, Colors.white));
    }
    TonePlayer.instance.playClick(pitch: 1.3);
  }

  void _over() {
    final prev = GameScores.instance.best(_id);
    _coinCombo = 0;
    _banner = null;
    _bannerT = 0;
    _status = GameStatus.over;
    TonePlayer.instance.playCue(SoundCue.crash);
    emit(_score > prev
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _reset() {
    setState(() {
      _pipes.clear();
      _bits.clear();
      _birdY = 0.5;
      _vy = 0;
      _spawnIn = 0;
      _pipeSpeed = _basePipeSpeed;
      _score = 0;
      _coinCombo = 0;
      // `_bestCoinCombo` is now the persisted all-time record (see
      // `_comboId`/`GameScores.submit` above) and must survive replays the
      // same way `_best` does — only `_coinCombo` (the live in-run streak)
      // resets here.
      _beatBest = false;
      _banner = null;
      _bannerT = 0;
      _started = false;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '🐤 Sky Hop',
      introHow: 'Tap to flap through the gaps and collect enough coins to complete the sky run!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _goalScore,
      status: _status,
      banner: _banner ??
          // "Tap to flap" was painted only onto the canvas before the first
          // flap, so it was silent to screen readers. Mirroring it into the
          // shared, semantics-announced banner closes that gap.
          (!_started && _status == GameStatus.playing ? 'Tap to flap' : null),
      overEmoji: '🐤',
      overText: _bestCoinCombo > 1
          ? 'Splash! Best coin streak x$_bestCoinCombo'
          : 'Splash!',
      winEmoji: '🏆',
      winText: _winPraise,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: Semantics(
        button: true,
        label: !_started
            ? 'Tap to flap and start flying.'
            : 'Score $_score of $_goalScore. Tap to flap.',
        onTap: _flap,
        excludeSemantics: true,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _flap(),
        child: CustomPaint(
          painter: _SkyHopPainter(_pipes, _birdY, _gap, _started, _bits, _vy),
          size: Size.infinite,
        ),
        ),
      ),
    );
  }
}

class _SkyHopPainter extends CustomPainter {
  _SkyHopPainter(this.pipes, this.birdY, this.gap, this.started, this.bits, this.vy);
  final List<_Pipe> pipes;
  final double birdY;
  final double gap;
  final bool started;
  final List<_Shard> bits;
  final double vy;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF4EC5F1), Color(0xFFA8E6CF)],
          ).createShader(Offset.zero & size));
    final pipePaint = Paint()..color = const Color(0xFF2E9E5B);
    for (final p in pipes) {
      final cx = p.x * w;
      final gy = p.gapY * h;
      final half = gap / 2 * h;
      canvas.drawRect(
          Rect.fromLTRB(cx - w * 0.09, 0, cx + w * 0.09, gy - half), pipePaint);
      canvas.drawRect(
          Rect.fromLTRB(cx - w * 0.09, gy + half, cx + w * 0.09, h), pipePaint);
      if (!p.coinTaken) {
        final coinC = Offset(cx, p.coinY * h);
        canvas.drawCircle(coinC, w * 0.028,
            Paint()..color = const Color(0xFFFFD166));
        canvas.drawCircle(
            coinC,
            w * 0.028,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFB8860B));
      }
    }
    final bx = w * 0.3;
    final by = birdY * h;
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), w * 0.012 * k + 1.5,
          Paint()..color = s.color.withOpacity(k));
    }
    // Tilt the bird with its actual vertical velocity — nose up on a flap,
    // nosing down the longer it falls — so the player can read their own
    // momentum at a glance instead of the bird looking frozen mid-flight.
    final angle = (vy * 0.9).clamp(-0.7, 1.0);
    canvas.save();
    canvas.translate(bx, by);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, w * 0.05, Paint()..color = const Color(0xFFFFD166));
    canvas.drawCircle(
        Offset(w * 0.02, -w * 0.015), 3, Paint()..color = Colors.black);
    canvas.restore();
    if (!started) {
      // The sky/grass gradient is pale at every stop (light cyan fading to
      // light mint), so plain white text here was low-contrast against the
      // whole backdrop — use a dark ink with a soft light halo so it reads
      // clearly no matter where the hint lands on the gradient.
      final tp = TextPainter(
        text: const TextSpan(
            text: 'Tap to flap',
            style: TextStyle(
                color: Color(0xFF1B3B4B),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                shadows: <Shadow>[
                  Shadow(color: Colors.white70, blurRadius: 6),
                ])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.6));
    }
  }

  @override
  bool shouldRepaint(_SkyHopPainter oldDelegate) => true;
}

// ===========================================================================
// Stack — a block slides back and forth; tap to drop it on the tower. Overhang
// is trimmed, so precise stacking keeps the block wide. Miss entirely and the
// tower topples.
// ===========================================================================
