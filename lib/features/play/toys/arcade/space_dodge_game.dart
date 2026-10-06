part of '../arcade_games.dart';

class SpaceDodgeGame extends StatefulWidget {
  const SpaceDodgeGame({super.key});
  @override
  State<SpaceDodgeGame> createState() => _SpaceDodgeGameState();
}

class _Meteor {
  _Meteor(this.x, this.y, this.r, this.vy, {this.kind = 0, this.vx = 0.0});
  double x, y, r, vy, vx;
  final int kind; // 0 = rock, 1 = gem (+bonus), 2 = shield pickup,
  // 3 = seeker (homing, steers toward the ship), 4 = splitter (forks in two)
  bool split = false; // splitter: already forked
}

class _SpaceDodgeGameState extends State<SpaceDodgeGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'space_dodge';
  static const int _startingLives = 3;
  static const int _goalScore = 180;
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Galaxy clear!" line on win screen (across-restarts sibling
  // of the per-wave praise-variety fixes elsewhere in this sprint).
  static const List<String> _winPraisePool = <String>[
    'Galaxy clear!',
    'Ace pilot!',
    'Meteor storm survived!',
    'Clean flight!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  final List<_Meteor> _meteors = <_Meteor>[];
  final List<Offset> _stars = <Offset>[];
  final List<_Shard> _shards = <_Shard>[];
  double _shipX = 0.5;
  double _elapsed = 0;
  double _spawnIn = 0.6;
  int _score = 0;
  int _best = 0;
  int _bonus = 0;
  int _lives = _startingLives;
  int _lastMilestone = 0;
  int _wave = 1;
  bool _invulnerable = false;
  double _hitCooldown = 0;
  bool _shield = false;
  bool _seenSeeker = false;
  bool _seenSplitter = false;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Mirrors mini_games.dart's FruitCatchGame/BalloonPopGame/StarTapGame/
  // SnakeGame/RacingGame/BowlingGame live "beat your own all-time best"
  // celebration. Space Dodge's score is a pure monotonic climb (elapsed
  // time + gem bonus, never decreases), so crossing a prior personal best
  // mid-flight — well before the fixed 180-point win goal — is a real,
  // judgment-free moment worth its own banner.
  bool _beatBest = false;
  // Collision math below runs in normalized (0..1) coordinates, but every
  // shape on screen is drawn with a pixel radius scaled only by the canvas
  // *width* (see _SpacePainter), so on a typical taller-than-wide phone a
  // raw normalized dx/dy distance check builds an invisible hit-ellipse far
  // taller than the circle the child actually sees — a meteor can "hit" the
  // ship while still looking a full ship-height away vertically. Track the
  // real aspect ratio so hit-testing matches what's drawn.
  double _aspect = 1.0; // height / width of the last laid-out canvas

  // Sensory Settings' "Reduce motion" toggle otherwise only shortens Flutter's
  // own implicit animations/page transitions — every arcade game's hand-rolled
  // particle bursts kept firing at full density regardless, so a child who
  // turned it on for exactly this kind of overstimulation got no relief here.
  bool _reduceMotion = false;

  static const double _shipR = 0.045;

  // Same "flat-forever difficulty never fed by career `_best`" bug class
  // already fixed in air_hockey/goal_keeper/snake/racing/whack (batches
  // 395-397): every replay opened at the identical wave-1 meteor pace
  // regardless of how many times this child has already cleared the
  // 180-point galaxy. A small, capped head start on the wave counter (which
  // drives both speed and the seeker/splitter unlock gates) keeps a
  // seasoned pilot's opener a bit livelier without ever starting as hard as
  // the late-game ramp a fresh run would eventually reach on its own.
  int get _careerWaveRamp {
    if (_best >= 140) return 2;
    if (_best >= 70) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 40; i++) {
      _stars.add(Offset(_rnd.nextDouble(), _rnd.nextDouble()));
    }
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _elapsed += dt;
    final wave = (_elapsed / 12).floor() + 1;
    if (wave > _wave) {
      _wave = wave;
      TonePlayer.instance.playCue(SoundCue.milestone);
      _flash('Wave $_wave!');
    }
    if (_invulnerable) {
      _hitCooldown -= dt;
      if (_hitCooldown <= 0) {
        _invulnerable = false;
        _banner = 'Back in the fight!';
        _bannerT = 0.9;
      }
    }

    // The one-off hit/pickup bursts below already thin themselves under
    // Reduce Motion via `_burstAt`'s `effectiveN`, but this continuous
    // every-tick exhaust trail kept spawning at full density regardless —
    // over a long run that's actually the single biggest source of ambient
    // particles on screen, the exact overstimulation the toggle exists to
    // relieve. Thin it the same way instead of ignoring the setting here.
    if (_rnd.nextDouble() < (_reduceMotion ? 0.3 : 0.9)) {
      _shards.add(_Shard(
          _shipX + (_rnd.nextDouble() - 0.5) * 0.03,
          0.9,
          (_rnd.nextDouble() - 0.5) * 0.08,
          0.25 + _rnd.nextDouble() * 0.18,
          _rnd.nextBool() ? const Color(0xFFFFB703) : const Color(0xFFFB5607)));
    }
    for (var i = _shards.length - 1; i >= 0; i--) {
      final s = _shards[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) _shards.removeAt(i);
    }
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }

    _score = (_elapsed * 5).round() + _bonus;
    if (!_beatBest && _best > 0 && _score > _best) {
      _beatBest = true;
      // Takes priority over the wave/pickup banner just set above this tick
      // — a new all-time record is the bigger moment. The win-goal check
      // right below runs after this and will overwrite it if the same tick
      // also crosses the 180-point goal, since winning the whole game is
      // the bigger moment still.
      _banner = 'New personal best! 🏆';
      _bannerT = 1.6;
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
    if (_score >= _goalScore && _status == GameStatus.playing) {
      _status = GameStatus.won;
      _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      _flash('Galaxy cleared!');
      return;
    }

    if (_score ~/ 45 > _lastMilestone) {
      _lastMilestone = _score ~/ 45;
      TonePlayer.instance.playCue(SoundCue.coin);
      emit(ExperienceEvent.bubblePopped);
    }

    final speed = 0.38 + _elapsed * 0.025 + _wave * 0.02;
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.25, 0.78 - _elapsed * 0.018);
      final cluster = _wave > 1 && _rnd.nextDouble() < 0.18;
      if (cluster) {
        final baseX = 0.12 + _rnd.nextDouble() * 0.76;
        for (final offset in <double>[-0.08, 0.08]) {
          final vx = (_rnd.nextBool() ? -1.0 : 1.0) *
              (0.04 + _rnd.nextDouble() * 0.12);
          _meteors.add(
              _Meteor(baseX + offset, -0.1, 0.032, speed, kind: 0, vx: vx));
        }
      } else {
        final roll = _rnd.nextDouble();
        final seekerChance = _wave >= 2 ? 0.1 : 0.0;
        final splitterChance = _wave >= 3 ? 0.1 : 0.0;
        int kind;
        if (roll < 0.1) {
          kind = 1; // gem
        } else if (roll < 0.16) {
          kind = 2; // shield
        } else if (roll < 0.16 + seekerChance) {
          kind = 3; // seeker
        } else if (roll < 0.16 + seekerChance + splitterChance) {
          kind = 4; // splitter
        } else {
          kind = 0; // plain rock
        }
        final r = kind == 4
            ? 0.05
            : kind == 0
                ? 0.03 + _rnd.nextDouble() * 0.045
                : 0.032;
        final x = _rnd.nextDouble();
        final vx = kind == 3
            ? 0.0
            : (_rnd.nextBool() ? -1.0 : 1.0) *
                (0.04 + _rnd.nextDouble() * 0.12);
        final vy = kind == 3
            ? speed * 0.75
            : kind == 4
                ? speed * 0.85
                : speed + _rnd.nextDouble() * 0.12;
        _meteors.add(_Meteor(x, -0.1, r, vy, kind: kind, vx: vx));
        if (kind == 3 && !_seenSeeker) {
          _seenSeeker = true;
          _flash('Seeker incoming! It tracks you.');
        }
        if (kind == 4 && !_seenSplitter) {
          _seenSplitter = true;
          _flash('Watch out, it splits in two!');
        }
      }
    }

    final toSpawn = <_Meteor>[];
    for (var i = _meteors.length - 1; i >= 0; i--) {
      final m = _meteors[i];
      if (m.kind == 3) {
        // Seeker: steers toward the ship's x position with a capped turn rate.
        final dxToShip = _shipX - m.x;
        final desiredVx = dxToShip.sign * 0.16;
        m.vx += (desiredVx - m.vx) * dt * 1.4;
      } else {
        if (m.x < 0.04 || m.x > 0.96) m.vx *= -1;
      }
      m.x += m.vx * dt;
      m.y += m.vy * dt;

      if (m.kind == 4 && !m.split && m.y > 0.45) {
        m.split = true;
        _burstAt(m.x, m.y, const Color(0xFFB5B5B5), 10);
        TonePlayer.instance.playCue(SoundCue.metal);
        toSpawn.add(_Meteor(m.x, m.y, 0.028, m.vy * 1.1,
            kind: 0, vx: -0.22 - _rnd.nextDouble() * 0.08));
        toSpawn.add(_Meteor(m.x, m.y, 0.028, m.vy * 1.1,
            kind: 0, vx: 0.22 + _rnd.nextDouble() * 0.08));
        _meteors.removeAt(i);
        continue;
      }

      final dx = (m.x - _shipX);
      // Scale the vertical delta by the aspect ratio so the hit test
      // measures the same physical (pixel) distance in both axes as what's
      // actually rendered (shapes are drawn with radius scaled only by
      // canvas width), instead of an invisible tall ellipse.
      final dy = (m.y - 0.85) * _aspect;
      if (dx * dx + dy * dy < (m.r + _shipR) * (m.r + _shipR)) {
        if (m.kind == 1) {
          _bonus += 20;
          _burstAt(m.x, m.y, const Color(0xFF06D6A0), 12);
          _meteors.removeAt(i);
          TonePlayer.instance.playCue(SoundCue.coin);
          _flash('Gem +20');
          emit(ExperienceEvent.bubblePopped);
          continue;
        }
        if (m.kind == 2) {
          _shield = true;
          _burstAt(m.x, m.y, const Color(0xFF4CC9F0), 12);
          _meteors.removeAt(i);
          TonePlayer.instance.playCue(SoundCue.success);
          _flash('Shield up!');
          // Same positive-pickup class as the gem above (which already
          // emits), but the shield pickup left the companion silent on an
          // identical "good grab" moment — Hari/Pico had nothing to react
          // to here.
          emit(ExperienceEvent.bubblePopped);
          continue;
        }
        if (_shield) {
          _shield = false;
          _burstAt(m.x, m.y, const Color(0xFF4CC9F0), 16);
          _meteors.removeAt(i);
          TonePlayer.instance.playCue(SoundCue.metal);
          _flash('Shield saved you!');
          continue;
        }

        if (_invulnerable) {
          _meteors.removeAt(i);
          continue;
        }
        _lives -= 1;
        _invulnerable = true;
        _hitCooldown = 1.1;
        _burstAt(m.x, m.y, const Color(0xFFFF6B6B), 18);
        _meteors.removeAt(i);
        if (_lives <= 0) {
          _status = GameStatus.over;
          TonePlayer.instance.playCue(SoundCue.crash);
          final prev = GameScores.instance.best(_id);
          emit(_score > prev
              ? ExperienceEvent.gameCompleted
              : ExperienceEvent.incorrectAnswer);
          GameScores.instance.submit(_id, _score).then((b) {
            if (mounted) setState(() => _best = b);
          });
          _flash('Ship lost');
          return;
        }
        TonePlayer.instance.playCue(SoundCue.metal);
        emit(ExperienceEvent.incorrectAnswer);
        _flash('Ouch! $_lives left');
      }
    }
    _meteors.addAll(toSpawn);
    _meteors.removeWhere((m) => m.y > 1.2 || m.y < -0.25);
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.0;
  }

  void _burstAt(double x, double y, Color color, int n) {
    // Thin the burst (never cut it to zero — some feedback still matters)
    // when the child has asked for reduced motion.
    final effectiveN = _reduceMotion ? math.max(3, (n / 3).round()) : n;
    for (var i = 0; i < effectiveN; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.2 + _rnd.nextDouble() * 0.4;
      _shards.add(_Shard(x, y, math.cos(a) * sp, math.sin(a) * sp, color));
    }
  }

  void _steer(double localX, double width) {
    _shipX = (localX / width).clamp(_shipR, 1 - _shipR);
  }

  void _reset() {
    setState(() {
      _meteors.clear();
      _shards.clear();
      _shipX = 0.5;
      _elapsed = 0;
      _spawnIn = 0.6;
      _score = 0;
      _bonus = 0;
      _lives = _startingLives;
      _lastMilestone = 0;
      _wave = 1 + _careerWaveRamp;
      _invulnerable = false;
      _hitCooldown = 0;
      _shield = false;
      _seenSeeker = false;
      _seenSplitter = false;
      _beatBest = false;
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
      title: '🚀 Space Dodge',
      introHow:
          'Steer to dodge the meteors, grab gems, and reach 180 points before all 3 ships are gone.',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _goalScore,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Ships: $_lives${_shield ? ' | Shielded' : ''}'
              : null),
      overEmoji: '💥',
      // _wave only ever surfaces as a transient 'Wave N!' banner during
      // play, which the full-screen game-over card then covers — without
      // this the child's actual run progress (how deep into the meteor
      // field they got) vanishes the instant the ship is lost.
      overText: 'Mission failed! Reached Wave $_wave',
      winEmoji: '🎉',
      winText: _winPraise,
      accent: const Color(0xFF9B5DE5),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 0) {
            _aspect = constraints.maxHeight / constraints.maxWidth;
          }
          // Like brick_break/air_hockey/maze_marble/balance_ball's drag
          // surfaces, this horizontal drag-to-steer ship had zero Semantics
          // — a previously stale record claiming it was exempt ("whole-
          // screen reduce-motion-only trail") confused the one-off exhaust
          // particles with the actual steering mechanic. The ship only
          // ever moves horizontally (see _steer), so a fixed-size
          // left/right nudge of its own position reproduces the same
          // effect onPanUpdate drives every frame, clamped the same way.
          void nudge(double dx) =>
              setState(() => _shipX = (_shipX + dx).clamp(_shipR, 1 - _shipR));
          return Semantics(
            label: 'Meteor field. Drag or use the nudge actions to steer '
                'your ship left and right and dodge the meteors.',
            customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
              const CustomSemanticsAction(label: 'Nudge ship left'): () =>
                  nudge(-0.12),
              const CustomSemanticsAction(label: 'Nudge ship right'): () =>
                  nudge(0.12),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) =>
                  _steer(d.localPosition.dx, constraints.maxWidth),
              onPanDown: (d) =>
                  _steer(d.localPosition.dx, constraints.maxWidth),
              child: CustomPaint(
                painter: _SpacePainter(
                    _meteors, _stars, _shipX, _shipR, _shield, _shards),
                size: Size.infinite,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.meteors, this.stars, this.shipX, this.shipR, this.shield,
      this.shards);
  final List<_Meteor> meteors;
  final List<Offset> stars;
  final double shipX;
  final double shipR;
  final bool shield;
  final List<_Shard> shards;

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
            colors: <Color>[Color(0xFF0B1030), Color(0xFF05030F)],
          ).createShader(Offset.zero & size));
    final star = Paint()..color = Colors.white70;
    for (final s in stars) {
      canvas.drawCircle(Offset(s.dx * w, s.dy * h), 1.4, star);
    }
    final rock = Paint()..color = const Color(0xFF8D6E63);
    for (final m in meteors) {
      final c = Offset(m.x * w, m.y * h);
      final rr = m.r * w;
      if (m.kind == 1) {
        final p = Path()
          ..moveTo(c.dx, c.dy - rr)
          ..lineTo(c.dx + rr, c.dy)
          ..lineTo(c.dx, c.dy + rr)
          ..lineTo(c.dx - rr, c.dy)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF06D6A0));
        canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white);
      } else if (m.kind == 2) {
        canvas.drawCircle(
            c, rr, Paint()..color = const Color(0xFF4CC9F0).withOpacity(0.5));
        canvas.drawCircle(
            c,
            rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFF4CC9F0));
      } else if (m.kind == 3) {
        // Seeker: pulsing magenta core with a directional glow toward travel.
        canvas.drawCircle(
            c, rr * 1.3, Paint()..color = const Color(0xFFFF006E).withOpacity(0.25));
        canvas.drawCircle(c, rr, Paint()..color = const Color(0xFFFF006E));
        canvas.drawCircle(
            c, rr * 0.4, Paint()..color = Colors.white.withOpacity(0.9));
      } else if (m.kind == 4) {
        // Splitter: larger rock with a warning seam showing where it forks.
        canvas.drawCircle(c, rr, Paint()..color = const Color(0xFFB5B5B5));
        canvas.drawLine(Offset(c.dx - rr, c.dy), Offset(c.dx + rr, c.dy),
            Paint()
              ..color = const Color(0xFFFFD60A)
              ..strokeWidth = 3);
        canvas.drawCircle(
            c, rr * 0.5, Paint()..color = const Color(0xFF8D6E63));
      } else {
        canvas.drawCircle(c, rr, rock);
        canvas.drawCircle(
            c, rr * 0.6, Paint()..color = const Color(0xFF5D4037));
      }
    }
    final sx = shipX * w;
    final sy = 0.85 * h;
    for (final s in shards) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(s.x * w, s.y * h),
          2 + 3 * k,
          Paint()
            ..color = s.color.withOpacity(k)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
    final path = Path()
      ..moveTo(sx, sy - shipR * w)
      ..lineTo(sx - shipR * w * 0.7, sy + shipR * w)
      ..lineTo(sx + shipR * w * 0.7, sy + shipR * w)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF4CC9F0));
    canvas.drawCircle(
        Offset(sx, sy), shipR * w * 0.35, Paint()..color = Colors.white);
    if (shield) {
      canvas.drawCircle(
          Offset(sx, sy),
          shipR * w * 1.7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF4CC9F0).withOpacity(0.9));
    }
  }

  @override
  bool shouldRepaint(_SpacePainter oldDelegate) => true;
}
