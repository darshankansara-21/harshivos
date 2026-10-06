part of '../arcade_games.dart';

class MemoryFlipGame extends StatefulWidget {
  const MemoryFlipGame({super.key});
  @override
  State<MemoryFlipGame> createState() => _MemoryFlipGameState();
}

class _MemoryFlipGameState extends State<MemoryFlipGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'memory_flip';
  static const List<String> _facePool = <String>[
    '🍎',
    '⭐',
    '🐢',
    '🎈',
    '🌸',
    '🚗',
    '🐬',
    '🎵',
    '🦋',
    '🍩'
  ];
  // Spoken names for the face pool above — a screen reader can't rely on the
  // raw emoji glyph alone (it reads inconsistently/ambiguously across
  // TalkBack/VoiceOver), so a flipped card needs a reliable human-readable
  // label, same pattern as `feelings_match`/`weather_sort`.
  static const Map<String, String> _faceNames = <String, String>{
    '🍎': 'apple',
    '⭐': 'star',
    '🐢': 'turtle',
    '🎈': 'balloon',
    '🌸': 'flower',
    '🚗': 'car',
    '🐬': 'dolphin',
    '🎵': 'music note',
    '🦋': 'butterfly',
    '🍩': 'donut',
  };
  static const int _maxLevel = 5;
  final math.Random _rnd = math.Random();
  late List<String> _cards;
  late List<bool> _matched;
  int _first = -1;
  int _second = -1;
  bool _locked = false;
  int _pairs = 0;
  int _level = 1;
  int _streak = 0;
  int _score = 0;
  int _best = 0;
  int _lives = 3;
  bool _previewing = false;
  double _previewLeft = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // Mirrors whack_game/fruit_catch_game's live "beat your own all-time best"
  // celebration. MemoryFlipGame has a fixed _maxLevel cap, but score varies
  // per run with streak bonuses and most runs end early on a lost life well
  // short of the final level — the same shape as WhackGame/FruitCatchGame,
  // where the pattern already fits despite the eventual win cap.
  bool _beatBest = false;

  // Every sibling "find the match" game in the catalog (shadow_match,
  // odd_one_out, pattern_weaver...) bursts a few shards of colour on a
  // correct hit; this one only ever gave a scale-pop + glow on the two
  // matched tiles themselves, with zero screen-space celebration — the one
  // feeling this whole game is built around (finding a pair) landed flatter
  // than every other matching sibling. `_lastSize` mirrors mini_games.dart's
  // StarTapGame cache so `_tap` (which has no direct LayoutBuilder access)
  // can still resolve a card index to its real on-screen centre.
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  Size? _lastSize;

  // Per-level think-fast timer: running out costs a life (same as a wrong
  // match) but banking leftover time pays out a bonus, so players choose
  // between careful memorising and a faster, riskier pace.
  double _timeLimit = 0;
  double _timeLeft = 0;

  // Per-level pair counts, picked so every resulting card count (2x this)
  // factors into a clean rectangle in `_cols` below — a straight
  // `(5 + level).clamp(...)` used to produce 7 pairs (14 cards) and 9 pairs
  // (18 cards) at levels 2/4, and 14/18 don't evenly divide by the 3-or-4
  // column choice the grid used, leaving a dangling half-empty last row
  // (the same bug class already fixed in memory_pairs_deluxe).
  static const List<int> _pairsSchedule = <int>[6, 8, 9, 10, 10];
  int get _pairsThisLevel =>
      _pairsSchedule[(_level - 1).clamp(0, _pairsSchedule.length - 1)];
  double get _levelTimeLimit => 16 + _pairsThisLevel * 2.2;

  // The memorize-the-board preview used to be a flat 1.4s no matter how many
  // cards were on it: fine for level 1's 12 cards, but level 5 deals all 20
  // cards (10 pairs) and flashed them for the exact same 1.4s — nowhere near
  // enough time to actually memorize a board that size, so later levels
  // weren't "harder", they were just unwinnable-by-design. Scale the preview
  // with the real card count so the training-wheels grow with the board.
  double get _previewDuration => 0.8 + _pairsThisLevel * 0.25;

  // Card index -> fractional (0..1) centre, matching the GridView.count
  // layout built below (20/120/20/70 padding, `_cols` columns, 12px spacing,
  // square cells since `childAspectRatio` is left at the GridView.count
  // default of 1.0).
  Offset _cellCenter(int i, double w, double h) {
    final cols = _cols;
    const padLeft = 20.0, padTop = 120.0, spacing = 12.0;
    final availW = w - padLeft - 20.0;
    final cellW = (availW - spacing * (cols - 1)) / cols;
    final col = i % cols, row = i ~/ cols;
    final cx = padLeft + col * (cellW + spacing) + cellW / 2;
    final cy = padTop + row * (cellW + spacing) + cellW / 2;
    return Offset(cx / w, cy / h);
  }

  void _burst(Offset fracPos, Color color) {
    final n = _reduceMotion ? 4 : 12;
    for (var k = 0; k < n; k++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.15 + _rnd.nextDouble() * 0.3;
      _bits.add(_Shard(fracPos.dx, fracPos.dy, math.cos(a) * sp,
          math.sin(a) * sp, color));
    }
  }

  @override
  void initState() {
    super.initState();
    _deal();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    // Shards keep animating through the preview/locked beats below (a
    // level-clear burst shouldn't freeze mid-flight just because the board
    // is momentarily locked for the next deal).
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_previewing) {
      _previewLeft -= dt;
      if (_previewLeft <= 0) _previewing = false;
      return;
    }
    if (_locked) return;
    _timeLeft -= dt;
    if (_timeLeft <= 0) {
      _timeLeft = _timeLimit;
      _loseLife('Too slow! $_lives left');
    }
  }

  void _deal() {
    // Pick which icons appear this round from a shuffled copy of the pool
    // instead of always slicing the front of `_facePool` — otherwise every
    // level 1 deal is always the exact same first N icons, forever, on
    // every playthrough (only card *position* varied, never *content*).
    final pool = List<String>.of(_facePool)..shuffle(_rnd);
    final faces = pool.take(_pairsThisLevel).toList();
    _cards = <String>[...faces, ...faces];
    _cards.shuffle();
    _matched = List<bool>.filled(_cards.length, false);
    _first = -1;
    _second = -1;
    _locked = false;
    _pairs = 0;
    _timeLimit = _levelTimeLimit;
    _timeLeft = _timeLimit;
  }

  void _startPreview() {
    setState(() {
      _previewing = true;
      _previewLeft = _previewDuration;
    });
  }

  /// Shared penalty path for a wrong match or a timeout: drops a life, ends
  /// the game if that was the last one, otherwise flashes [missMessage].
  void _loseLife(String missMessage) {
    _streak = 0;
    _lives--;
    // Every wrong match or timeout deserves the companion's gentle
    // encouraging reaction, not just the one that happens to end the game.
    emit(ExperienceEvent.incorrectAnswer);
    if (_lives <= 0) {
      _status = GameStatus.over;
      TonePlayer.instance.playCue(SoundCue.gameOver);
      final prev = GameScores.instance.best(_id);
      emit(_score > prev
          ? ExperienceEvent.gameCompleted
          : ExperienceEvent.incorrectAnswer);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      _flash('Game over!');
      return;
    }
    TonePlayer.instance.playCue(SoundCue.gentleRetry);
    _flash(missMessage);
  }

  bool get _gameOver => _status == GameStatus.over;

  // The final level's leftover-time bonus so it can survive onto the win
  // overlay below — `_flash` only shows its banner for ~1s and that banner
  // is instantly hidden the moment `_status` flips to `GameStatus.won` (the
  // win overlay is drawn on top of it in the same frame), so the bonus a
  // child just earned was silently thrown away and never actually seen.
  int _finalTimeBonus = 0;

  /// Rewards leftover level time as score, shown appended to [base].
  String _bankTimeBonus(String base) {
    final bonus = (_timeLeft * 2).round();
    _finalTimeBonus = bonus;
    if (bonus <= 0) return base;
    _score += bonus;
    return '$base (+$bonus time bonus)';
  }

  void _flash(String s) {
    _banner = s;
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  void _tap(int i) {
    if (_previewing ||
        _locked ||
        _matched[i] ||
        i == _first ||
        _status != GameStatus.playing) {
      return;
    }
    // A card flip is a flat paper/cardboard tile, not a wooden block — use
    // the dedicated `paper` grain cue (previously orphaned) instead of the
    // percussive `wood` click so the sound actually matches what's drawn.
    TonePlayer.instance.playCue(SoundCue.paper);
    setState(() {
      if (_first == -1) {
        _first = i;
      } else {
        _second = i;
        if (_cards[_first] == _cards[_second]) {
          _matched[_first] = true;
          _matched[_second] = true;
          _pairs++;
          _streak++;
          _score += 10 + (_streak >= 3 ? 5 : 0);
          TonePlayer.instance.playCue(SoundCue.learnGood);
          final size = _lastSize;
          if (size != null) {
            const matchGlow = Color(0xFF06D6A0);
            _burst(_cellCenter(_first, size.width, size.height), matchGlow);
            _burst(_cellCenter(_second, size.width, size.height), matchGlow);
          }
          if (_streak >= 3) _flash('Streak x$_streak!');
          if (_status == GameStatus.playing &&
              !_beatBest &&
              _best > 0 &&
              _score > _best) {
            _beatBest = true;
            // Takes priority over the streak banner just set above — a new
            // all-time record is the bigger moment of the two.
            _flash('New personal best! 🏆');
            TonePlayer.instance.playCue(SoundCue.milestone);
            emit(ExperienceEvent.personalBest);
          }
          _first = -1;
          _second = -1;
          if (_pairs >= _pairsThisLevel) {
            if (_level >= _maxLevel) {
              _flash(_bankTimeBonus('Galaxy cleared!'));
              _status = GameStatus.won;
              TonePlayer.instance.playCue(SoundCue.success);
              emit(ExperienceEvent.gameCompleted);
              GameScores.instance.submit(_id, _score).then((b) {
                if (mounted) setState(() => _best = b);
              });
            } else {
              _flash(_bankTimeBonus('Level $_level!'));
              _level++;
              _score += 20;
              TonePlayer.instance.playCue(SoundCue.milestone);
              // Clearing a level is a real in-run milestone, not the end of
              // the galaxy — only the _level >= _maxLevel branch above is
              // the true completion that earns the full celebration.
              emit(ExperienceEvent.bubblePopped);
              _locked = true;
              Future<void>.delayed(const Duration(milliseconds: 650), () {
                if (!mounted) return;
                setState(_deal);
                _startPreview();
              });
            }
          } else {
            emit(ExperienceEvent.bubblePopped);
          }
        } else {
          _loseLife('Miss! $_lives left');
          if (_gameOver) return;
          _locked = true;
          Future<void>.delayed(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            setState(() {
              _first = -1;
              _second = -1;
              _locked = false;
            });
          });
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _level = 1;
      _streak = 0;
      _score = 0;
      _lives = 3;
      _banner = null;
      _beatBest = false;
      _previewing = false;
      _previewLeft = 0;
      _finalTimeBonus = 0;
      _bits.clear();
      _deal();
      _status = GameStatus.playing;
    });
    _startPreview();
  }

  // Maps an exact card count to a column count that divides it evenly, so
  // the board is always a clean rectangle (no dangling half-empty last
  // row) for every count `_pairsSchedule` above can actually produce.
  int get _cols {
    switch (_cards.length) {
      case 12:
        return 3;
      case 16:
        return 4;
      case 18:
        return 6;
      case 20:
        return 4;
      default:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final cols = _cols;
    return _Shell(
      title: '🧠 Memory Flip',
      introHow:
          'Flip two cards to find matching pairs before the timer runs out. You have 3 lives — wrong matches and timeouts cost one. Clear every level, bank leftover time as bonus points!',
      onStart: () {
        setState(() {
          _status = GameStatus.playing;
          _previewing = false;
          _previewLeft = 0;
        });
        _startPreview();
      },
      score: _score,
      best: _best,
      status: _status,
      banner: _banner ??
          (_previewing
              ? 'Memorize the pairs!'
              : 'Level $_level · ⏱ ${_timeLeft.ceil()}s · $_lives❤'),
      overEmoji: '💔',
      // Reaching level 3 of 5 before running out of lives is real progress a
      // child earned — the old static text threw it away and said nothing
      // but "nice try" regardless of how far they actually got.
      overText: 'Out of lives — reached Level $_level!',
      winEmoji: '🧠',
      // The leftover-time bonus just banked on the winning level used to
      // flash in a banner that the win overlay covered in the very same
      // frame, so it was never actually visible — fold it into the win
      // text itself so the reward a child just earned is the thing they see.
      winText: _finalTimeBonus > 0
          ? 'Great memory! +$_finalTimeBonus time bonus'
          : 'Great memory!',
      accent: const Color(0xFF06D6A0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF10233A), Color(0xFF0A1626)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
            _reduceMotion = MediaQuery.disableAnimationsOf(context);
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 120, 20, 70),
                    child: GridView.count(
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      children: <Widget>[
                for (var i = 0; i < _cards.length; i++)
                  Builder(builder: (context) {
                    final faceUp = _previewing ||
                        _matched[i] ||
                        i == _first ||
                        i == _second;
                    // Only describe what is CURRENTLY visible on this exact
                    // card — never the hidden identity of a face-down card —
                    // so a screen-reader user faces the same memory
                    // challenge (remember what you've already seen flipped)
                    // as a sighted child, not an easier one.
                    final name = _faceNames[_cards[i]] ?? 'card';
                    final label = _matched[i]
                        ? 'Matched $name card'
                        : faceUp
                            ? '$name card'
                            : 'Hidden card';
                    return Semantics(
                      button: true,
                      label: label,
                      onTap: () => _tap(i),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTapDown: (_) => _tap(i),
                        child: TweenAnimationBuilder<double>(
                          // Re-keys when a card becomes matched, firing a pop.
                          key: ValueKey('mem-$i-${_matched[i]}'),
                          tween: Tween<double>(
                              begin: _matched[i] ? 1.35 : 1.0, end: 1.0),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _matched[i]
                                  ? const Color(0xFF06D6A0).withOpacity(0.35)
                                  : faceUp
                                      ? Colors.white
                                      : const Color(0xFF1E3A5F),
                              borderRadius: BorderRadius.circular(14),
                              border: _matched[i]
                                  ? Border.all(
                                      color: const Color(0xFFFFD166), width: 2)
                                  : null,
                              boxShadow: _matched[i]
                                  ? <BoxShadow>[
                                      BoxShadow(
                                          color: const Color(0xFF06D6A0)
                                              .withOpacity(0.5),
                                          blurRadius: 14)
                                    ]
                                  : const <BoxShadow>[],
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                faceUp ? _cards[i] : '',
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: cols <= 3
                                        ? 40
                                        : cols == 4
                                            ? 30
                                            : 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _MemoryShardPainter(_bits)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemoryShardPainter extends CustomPainter {
  _MemoryShardPainter(this.bits);
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_MemoryShardPainter oldDelegate) => true;
}

// ===========================================================================
// Ball Sort — pour coloured balls between tubes until each tube holds a single
// colour. A calm, deeply satisfying sorting puzzle that quietly trains planning
// and colour sorting. Levels add more colours as you go.
// ===========================================================================
