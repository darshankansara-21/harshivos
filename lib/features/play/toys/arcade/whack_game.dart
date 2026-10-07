part of '../arcade_games.dart';

class WhackGame extends StatefulWidget {
  const WhackGame({super.key});
  @override
  State<WhackGame> createState() => _WhackGameState();
}

class _WhackGameState extends State<WhackGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'whack';
  static const int _holes = 9;
  static const int _winTarget = 35;
  // Shown once on the full-game win screen; a small pool keeps a child who
  // replays the SAME game many times from seeing the identical phrase every
  // time they finally win (the across-restarts sibling of the per-round
  // praise-variety fixes applied to sky_hop/echo_drums/brick_break).
  static const List<String> _winPraisePool = <String>[
    'Whack champion!',
    'Mole master!',
    'Golden hammer!',
    'Reflexes on fire!',
  ];
  String _winPraise = _winPraisePool[0];
  // Every sibling arcade game (basketball, soccer_kick, steady_hand,
  // piano_tiles, block_blast, goal_keeper, ...) rotates its game-over line
  // through the shared `_gentleTryAgainPool` so the catalog's most-seen
  // screen — shown on every loss, and losses are the common outcome for a
  // child still learning — never feels like a broken record. Whack's loss
  // screen instead hard-coded the exact identical 'Out of lives! Reached
  // Round N' text on every single run, forever. Pair the round number with
  // a pooled variant like everywhere else.
  String _overPraise = _gentleTryAgainPool[0];
  // Routine miss-reason banners fire many times per run (every unhit mole,
  // every bomb tap) — a flat identical phrase each time is the same
  // flat-repeated-praise/miss gap already fixed catalog-wide (catch_beat's
  // 'Missed!', brick_break's 'Nice hit!', etc.). The `$_lives left` suffix
  // in `_loseLife` already varies, but the reason text itself never did.
  static const List<String> _missPool = <String>[
    'Missed it!',
    'So close!',
    'Too slow!',
    'Next one!',
  ];
  static const List<String> _bombPool = <String>[
    'Ouch! Avoid 💣',
    'Oops, a bomb!',
    'Bombs hurt!',
    'Watch for bombs!',
  ];
  final math.Random _rnd = math.Random();
  final List<double> _mole = List<double>.filled(_holes, 0); // seconds left
  final List<bool> _isBomb = List<bool>.filled(_holes, false);
  final List<double> _splat = List<double>.filled(_holes, 0); // hit burst timer
  double _spawnIn = 0.7;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  int _lives = 3;
  int _round = 1;
  int _roundTarget = 10;
  int _dangerLevel = 0;
  double _bannerT = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // Mirrors mini_games.dart's FruitCatchGame/BalloonPopGame/StarTapGame/
  // SnakeGame/RacingGame/BowlingGame live "beat your own all-time best"
  // celebration: Whack has the identical shape (a fixed win target of 35,
  // but most runs end early on a lost life well short of it), so crossing a
  // prior personal best mid-run is a real, frequent, judgment-free moment
  // worth its own banner — not just the eventual win/over screen.
  bool _beatBest = false;

  // Same "flat-forever difficulty never fed by career `_best`" bug class
  // already fixed in air_hockey/goal_keeper/snake/racing (batches 395-396):
  // every single replay opened at the identical round-1/dangerLevel-0 mole
  // pace regardless of how many times this child has already mastered that
  // exact opener. A small, capped nudge — never reaching the in-run max
  // dangerLevel of 3 — keeps a seasoned player's opener a bit livelier
  // without ever starting as hard as the late-game ramp.
  int get _careerDangerRamp {
    if (_best >= 30) return 2;
    if (_best >= 15) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (var i = 0; i < _holes; i++) {
      if (_splat[i] > 0) _splat[i] -= dt;
      if (_mole[i] > 0) {
        _mole[i] -= dt;
        if (_mole[i] <= 0) {
          if (!_isBomb[i]) {
            _combo = 0;
            _loseLife(_missPool[_rnd.nextInt(_missPool.length)]);
          }
          _isBomb[i] = false;
        }
      }
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.22, 0.75 - _round * 0.05 - _combo * 0.015) *
          (0.55 + _rnd.nextDouble() * 0.55);
      final free = <int>[
        for (var i = 0; i < _holes; i++)
          if (_mole[i] <= 0) i
      ];
      if (free.isNotEmpty) {
        final h = free[_rnd.nextInt(free.length)];
        // Bomb risk and mole lifetime scale only with the round's danger
        // level, not with the player's combo — a child doing WELL (a long
        // combo) should never be punished with a harder board than someone
        // doing poorly at the same round. That combo-linked spike used to
        // push bomb odds as high as 44%; it's capped at 36% here, tied
        // purely to round progression.
        _isBomb[h] = _rnd.nextDouble() < (0.12 + _dangerLevel * 0.08);
        _mole[h] = math.max(0.42, 1.05 - _round * 0.06 - _dangerLevel * 0.04) +
            _rnd.nextDouble() * 0.35;
      }
    }
  }

  void _loseLife(String reason) {
    if (_status != GameStatus.playing) return;
    _lives = math.max(0, _lives - 1);
    _combo = 0;
    _dangerLevel = math.max(0, _dangerLevel - 1);
    _banner = _lives > 0 ? '$reason ${_lives} left' : 'Game over!';
    _bannerT = 1.0;
    TonePlayer.instance.playCue(SoundCue.crash);
    emit(ExperienceEvent.incorrectAnswer);
    if (_lives <= 0) {
      final prev = GameScores.instance.best(_id);
      _status = GameStatus.over;
      _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
      emit(_score > prev
          ? ExperienceEvent.gameCompleted
          : ExperienceEvent.incorrectAnswer);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
    }
  }

  void _checkWin() {
    if (_status != GameStatus.playing || _score < _winTarget) return;
    _status = GameStatus.won;
    _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
    _banner = 'Whack complete! $_score points!';
    _bannerT = 1.8;
    TonePlayer.instance.playCue(SoundCue.success);
    emit(ExperienceEvent.gameCompleted);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
    // The winning hit (reaching 35) is guarded out of the ordinary
    // `!_beatBest` check in `_hit` below once `_status` flips to `won` here
    // — so a final blow that ALSO crosses the player's all-time best used
    // to submit the record silently with no milestone chime or
    // `ExperienceEvent.personalBest`, the same win-branch-skips-the-
    // celebration-the-routine-branch-already-gets bug class fixed in
    // mirror_draw/xylophone_tap/drum_garden/echo_drums.
    if (!_beatBest && _best > 0 && _score > _best) {
      _beatBest = true;
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
  }

  void _advanceRound() {
    if (_status != GameStatus.playing) return;
    if (_score >= _winTarget) {
      _checkWin();
      return;
    }
    if (_score < _roundTarget) return;
    _round++;
    _lives = math.min(5, _lives + 1);
    _roundTarget += 8;
    _dangerLevel = math.min(3, _dangerLevel + 1);
    _spawnIn = math.max(0.22, 0.6 - (_round * 0.04));
    _banner =
        _dangerLevel > 1 ? 'Round $_round! Bombs rise!' : 'Round $_round!';
    _bannerT = 1.2;
    TonePlayer.instance.playCue(SoundCue.milestone);
  }

  void _hit(int i) {
    if (_status != GameStatus.playing) return;
    if (_mole[i] > 0) {
      final wasBomb = _isBomb[i];
      _mole[i] = 0;
      _isBomb[i] = false;
      if (wasBomb) {
        // Apply the bomb's score penalty BEFORE ending the run: _loseLife
        // reads `_score` directly to decide the final-run emit (gameCompleted
        // vs incorrectAnswer) and to submit the leaderboard entry when this
        // is the life-ending hit. With the decrement after the call (the old
        // order), a bomb that costs the last life submitted/compared the
        // pre-penalty score — one point higher than what the child actually
        // ends up seeing on the game-over screen.
        _score = math.max(0, _score - 1);
        _loseLife(_bombPool[_rnd.nextInt(_bombPool.length)]);
        return;
      }
      _combo++;
      _score += 1 + (_combo >= 5 ? 1 : 0) + (_combo >= 9 ? 1 : 0);
      _splat[i] = 0.35;
      TonePlayer.instance.playCue(SoundCue.wood);
      emit(ExperienceEvent.bubblePopped);
      if (_score >= _winTarget) {
        _checkWin();
      } else if (_score >= _roundTarget) {
        _advanceRound();
      } else if (_score == 10 ||
          _score == 25 ||
          (_score >= 50 && _score % 25 == 0)) {
        _banner = '$_score moles! 🎉';
        _bannerT = 1.3;
        TonePlayer.instance.playCue(SoundCue.milestone);
      } else if (_combo >= 5) {
        _banner = 'Combo x$_combo!';
        _bannerT = 1.0;
      }
      if (_status == GameStatus.playing &&
          !_beatBest &&
          _best > 0 &&
          _score > _best) {
        _beatBest = true;
        // Takes priority over the combo/milestone banner just set above — a
        // new all-time record is the bigger moment of the two. Guarded to
        // `GameStatus.playing` only: `_checkWin` above may have already
        // flipped to `won` and set its own win banner, which must not be
        // clobbered here.
        _banner = 'New personal best! 🏆';
        _bannerT = 1.6;
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) setState(() => _best = b);
      });
    }
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < _holes; i++) {
        _mole[i] = 0;
        _isBomb[i] = false;
        _splat[i] = 0;
      }
      _score = 0;
      _combo = 0;
      _lives = 3;
      _round = 1;
      _roundTarget = 10;
      _dangerLevel = _careerDangerRamp;
      _beatBest = false;
      _overPraise = _gentleTryAgainPool[0];
      _banner = 'Whack 35 points to win!';
      _bannerT = 1.4;
      _spawnIn = 0.7;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔨 Whack',
      introHow:
          'Tap the moles as they pop up, dodge bombs, and reach 35 points before your 3 lives run out!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _winTarget,
      status: _status,
      banner: _banner,
      overEmoji: '🔨',
      overText: '$_overPraise Reached Round $_round.',
      winEmoji: '🏆',
      winText: _winPraise,
      accent: const Color(0xFF8D5A3B),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF3B2A1A), Color(0xFF241810)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 60),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (var i = 0; i < _holes; i++)
                Semantics(
                  button: true,
                  // States only what a sighted child already sees at a
                  // glance in this hole — mole / bomb / empty — never
                  // revealing which hole will pop next.
                  label: _mole[i] <= 0
                      ? 'Hole ${i + 1}, empty.'
                      : (_isBomb[i]
                          ? 'Hole ${i + 1}, bomb! Avoid it.'
                          : 'Hole ${i + 1}, mole. Tap to whack.'),
                  onTap: () => _hit(i),
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTapDown: (_) => _hit(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A120A),
                        borderRadius: BorderRadius.circular(80),
                        border: Border.all(
                            color: const Color(0xFF4A3420), width: 3),
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          AnimatedScale(
                            scale: _mole[i] > 0 ? 1 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_isBomb[i] ? '💣' : '🐹',
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 46)),
                            ),
                          ),
                          if (_splat[i] > 0)
                            Opacity(
                              opacity: (_splat[i] / 0.35).clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 1 + (1 - _splat[i] / 0.35) * 1.5,
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('💥',
                                      maxLines: 1,
                                      style: TextStyle(fontSize: 44)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Sky Hop — one-tap flappy. Tap to flap the bird up through the gaps. Each gap
// cleared scores a point; touching a pipe or the ground ends the run.
// ===========================================================================
