part of '../arcade_games.dart';

class EchoGame extends StatefulWidget {
  const EchoGame({super.key});
  @override
  State<EchoGame> createState() => _EchoGameState();
}

class _EchoGameState extends State<EchoGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'echo';
  static const int _target = 8;
  static const List<Color> _pads = <Color>[
    Color(0xFFEF476F),
    Color(0xFF06D6A0),
    Color(0xFF118AB2),
    Color(0xFFFFD166),
  ];
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Tune master!',
    'Perfect echo!',
    'Sharp ears!',
    'Melody master!',
  ];
  String _winPraise = _winPraisePool.first;
  final List<int> _seq = <int>[];
  int _inputAt = 0;
  int _flash = -1;
  int _tapFlash = -1;
  double _tapFlashT = 0;
  // Unlike every other tap-the-right-thing game in the catalog
  // (shadow_match/spot_difference/pattern_weaver/weather_sort all flash red
  // on a miss), a wrong tap here used the same `_tapFlash` as a correct tap —
  // the pad lit up exactly the same colour either way, so the ONLY signal a
  // child got that they made a mistake was the full-screen game-over card a
  // moment later. Track the wrong pad separately so it can render with the
  // same distinct red tint used catalog-wide.
  int _wrongPad = -1;
  int _showAt = 0;
  double _showT = 0;
  bool _showing = false;
  int _best = 0;
  // Every other scoring arcade game already celebrates the moment a run's
  // score passes the child's all-time best with a banner + milestone chime
  // + ExperienceEvent.personalBest — Echo's score is the sequence length
  // (`_seq.length`), open-ended just like those games, but it only ever
  // submitted the new best silently. Guard it the same way (reset in
  // `_reset()`) so repeating one's own longest tune gets the same
  // celebration every sibling game gives.
  bool _beatBest = false;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
    _nextRound();
  }

  void _nextRound() {
    _seq.add(_rnd.nextInt(4));
    _inputAt = 0;
    _showAt = 0;
    _showT = 0;
    _showing = true;
    _flash = -1;
    _wrongPad = -1;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_tapFlashT > 0) {
      _tapFlashT -= dt;
      if (_tapFlashT <= 0) _tapFlash = -1;
    }
    if (!_showing) return;
    _showT += dt;
    // Longer sequences flash faster, so recall gets harder as you go.
    final onT = math.max(0.16, 0.35 - _seq.length * 0.015);
    final stepLen = onT + 0.2;
    final step = _showT % stepLen;
    if (_showAt < _seq.length) {
      if (step < onT) {
        if (_flash != _seq[_showAt]) {
          _flash = _seq[_showAt];
          TonePlayer.instance.playNote(_seq[_showAt] + 2, seconds: 0.2);
        }
      } else if (_flash != -1) {
        _flash = -1;
        _showAt++;
        _showT = 0;
      }
    } else {
      _showing = false;
      _flash = -1;
    }
  }

  void _tap(int pad) {
    if (_status != GameStatus.playing || _showing) return;
    _tapFlash = pad;
    _tapFlashT = 0.22;
    TonePlayer.instance.playNote(pad + 2, seconds: 0.18);
    if (_seq[_inputAt] == pad) {
      _inputAt++;
      if (_inputAt >= _seq.length) {
        // A child who completes a run that is itself a genuine all-time
        // record still deserves the companion's loudest celebration, not
        // just the routine round-clear chime.
        final crossedBest = _seq.length > _best && !_beatBest && _best > 0;
        if (crossedBest) {
          _beatBest = true;
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        if (_seq.length >= _target) {
          _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
          setState(() => _status = GameStatus.won);
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.gameCompleted);
          // Fire-and-forget here (unlike the other submit() calls below) left
          // the win screen's "best" stat stale if this run was itself the new
          // best, since the Future resolves after this frame's own setState
          // has already run.
          GameScores.instance.submit(_id, _seq.length).then((b) {
            if (mounted) setState(() => _best = b);
          });
          return;
        }
        GameScores.instance.submit(_id, _seq.length).then((b) {
          if (mounted) setState(() => _best = b);
        });
        emit(ExperienceEvent.bubblePopped);
        setState(_nextRound);
      }
    } else {
      // A distinct red flash on the pad actually touched, not the same
      // highlight a correct tap gets — see `_wrongPad`'s doc comment.
      _tapFlash = -1;
      _wrongPad = pad;
      setState(() => _status = GameStatus.over);
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
      GameScores.instance.submit(_id, _seq.length - 1).then((b) {
        if (mounted) setState(() => _best = b);
      });
    }
  }

  void _reset() {
    setState(() {
      _seq.clear();
      _wrongPad = -1;
      _beatBest = false;
      _status = GameStatus.playing;
      _nextRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎵 Echo',
      introHow: 'Watch the colours light up, then tap them back in order.',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _seq.length,
      target: _target,
      best: _best,
      status: _status,
      overEmoji: '🎵',
      overText: 'Missed the tune',
      winEmoji: '🏆',
      winText: _winPraise,
      accent: const Color(0xFF9B5DE5),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1B1140), Color(0xFF120C2E)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 120, 28, 90),
            child: Column(
              children: <Widget>[
                Text(_showing ? 'Watch…' : 'Your turn!  $_inputAt/${_seq.length}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    physics: const NeverScrollableScrollPhysics(),
                    children: <Widget>[
                      for (var i = 0; i < 4; i++)
                        // Pads were tappable only via a bare GestureDetector
                        // with zero Semantics tree, making the "watch the
                        // colours light up, then tap them back" premise
                        // silently unplayable by a blind child, even though
                        // each pad already plays its own distinct note on
                        // tap/flash. Label states only the pad's own number,
                        // never the sequence, matching rhythm_clap/
                        // echo_drums' convention of not revealing the answer.
                        Semantics(
                          button: true,
                          label: 'Pad ${i + 1}',
                          onTap: () => _tap(i),
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTapDown: (_) => _tap(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 90),
                              decoration: BoxDecoration(
                                color: _wrongPad == i
                                    ? const Color(0xFFE23B3B)
                                    : (_flash == i || _tapFlash == i)
                                        ? _pads[i]
                                        : _pads[i].withOpacity(0.35),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: (_flash == i ||
                                        _tapFlash == i ||
                                        _wrongPad == i)
                                    ? <BoxShadow>[
                                        BoxShadow(
                                            color: _wrongPad == i
                                                ? const Color(0xFFE23B3B)
                                                : _pads[i],
                                            blurRadius: 24)
                                      ]
                                    : const <BoxShadow>[],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Tic-Tac-Toe — you are ⭐, Pico is 🐾. A friendly opponent that blocks and
// wins when it can. First to three in a row.
// ===========================================================================
