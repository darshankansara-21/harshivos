part of '../arcade_games.dart';

/// Echo Drums — watch the drum phrase light up, then tap it back from memory.
/// Each round the phrase grows by one. A wrong tap costs a life and replays the
/// phrase. Echo a phrase of eight to win.
class EchoDrumsGame extends StatefulWidget {
  const EchoDrumsGame({super.key});
  @override
  State<EchoDrumsGame> createState() => _EchoDrumsGameState();
}

class _EchoDrumsGameState extends State<EchoDrumsGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'echo_drums';
  static const int _winLen = 8;
  static const List<int> _notes = <int>[0, 4, 7, 12];
  static const List<Color> _colors = <Color>[
    Color(0xFFE63946), Color(0xFF48CAE4), Color(0xFFFFD166), Color(0xFF80ED99),
  ];
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Good listening!', 'Golden ears!', 'Rhythm master!', 'Echo champion!',
  ];
  String _winPraise = _winPraisePool[0];

  final List<int> _seq = <int>[];
  bool _showing = false;
  int _showStep = 0;
  bool _showOn = false;
  double _timer = 0;
  // The playback itself used to run at one flat 0.5s-on/0.18s-gap pace for
  // every round — only the sequence length grew (1 to 8 notes), so a child
  // replaying a short early phrase heard it at exactly the same tempo as a
  // long late one. Every other multi-round game in the catalog ramps a real
  // pace/speed dimension with progress (balloon_math's drift speed,
  // target_toss's ring speed), so Echo Drums' own "growing phrase" curve was
  // missing its matching tempo escalation. Both durations now shrink toward a
  // floor as the phrase grows, so round 8's memorised echo is genuinely
  // faster to watch — and harder to track — than round 1's, not just longer.
  double _showDur = 0.5;
  double _gapDur = 0.18;

  // Every correctly echoed round used to flash the identical "Nice echo!" —
  // up to seven times in a single winning run — reading as flat/robotic well
  // before the run ends, the same "child delight" gap already fixed in
  // sky_hop's per-clear banner. A small random phrase pool keeps every
  // correct round feeling freshly celebrated without changing scoring,
  // timing, or difficulty at all.
  static const List<String> _echoPraise = <String>[
    'Nice echo!',
    'Great memory!',
    'Spot on!',
    'Right on beat!',
    'You got it!',
  ];
  int _inputIdx = 0;
  int _lit = -1;
  double _flashT = 0;
  int _lives = 3;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  int get _score => (_seq.length - 1).clamp(0, _winLen);

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _begin() {
    _seq.clear();
    _lives = 3;
    _nextRound();
  }

  void _nextRound() {
    _seq.add(_rnd.nextInt(4));
    _startShow();
  }

  void _startShow() {
    // Ramp tempo with phrase length: 0.5s/0.18s at round 1 down to a 0.3s/0.1s
    // floor by the final (8-note) round — fast enough to feel like a real
    // escalation, never so fast the lights blur together.
    final progress = (_seq.length / _winLen).clamp(0.0, 1.0);
    _showDur = 0.5 - progress * 0.2;
    _gapDur = 0.18 - progress * 0.08;
    _showing = true;
    _showStep = 0;
    _showOn = true;
    _lit = _seq[0];
    _timer = _showDur;
    TonePlayer.instance.playNote(_notes[_seq[0]], seconds: 0.3);
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_flashT > 0) {
      _flashT -= dt;
      if (_flashT <= 0 && !_showing) _lit = -1;
    }
    if (!_showing) {
      setState(() {});
      return;
    }
    _timer -= dt;
    if (_timer <= 0) {
      if (_showOn) {
        _showOn = false;
        _lit = -1;
        _timer = _gapDur;
      } else {
        _showStep++;
        if (_showStep >= _seq.length) {
          _showing = false;
          _inputIdx = 0;
          _lit = -1;
          _banner = 'Your turn — tap it back!';
        } else {
          _showOn = true;
          _lit = _seq[_showStep];
          _timer = _showDur;
          TonePlayer.instance.playNote(_notes[_lit], seconds: 0.3);
        }
      }
    }
    setState(() {});
  }

  void _tap(int pad) {
    if (_status != GameStatus.playing || _showing) return;
    _lit = pad;
    _flashT = 0.25;
    TonePlayer.instance.playNote(_notes[pad], seconds: 0.25);
    if (pad == _seq[_inputIdx]) {
      _inputIdx++;
      if (_inputIdx >= _seq.length) {
        if (_seq.length >= _winLen) {
          _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
          _status = GameStatus.won;
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
          // The win branch never used to call submit() at all, so the final
          // (longest, highest-scoring) phrase a child ever echoes was always
          // left out of their best — the win screen's "best" stat showed the
          // second-to-last round's score instead of the run that just won.
          // Same fire-and-forget-then-setState pattern as every other submit
          // call site here (matches the identical fix already applied to
          // echo_game.dart's win path).
          GameScores.instance.submit(_id, _score).then((b) {
            if (mounted) setState(() => _best = b);
          });
        } else {
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.bubblePopped);
          _banner = _echoPraise[_rnd.nextInt(_echoPraise.length)];
          GameScores.instance.submit(_id, _score).then((b) {
            if (mounted) setState(() => _best = b);
          });
          _nextRound();
        }
      }
    } else {
      _lives--;
      if (_lives <= 0) {
        // The life-ending miss must sound distinct from a routine miss,
        // never just the same gentle-retry cue as every other wrong tap.
        _status = GameStatus.over;
        _banner = 'Out of lives!';
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        _banner = 'Oops — listen again';
        _startShow();
      }
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _banner = null;
      _begin();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🪘 Echo Drums',
      introHow:
          'Watch the drums light up in order, then tap them back from memory. '
          'The phrase grows each round — echo eight to win!',
      onStart: () => setState(() {
        _begin();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _winLen,
      status: _status,
      banner: _banner ?? 'Phrase of ${_seq.length}  ·  ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '🪘',
      winText: _winPraise,
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF241A2E), Color(0xFF130C18)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 150, 28, 40),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (var i = 0; i < 4; i++)
                  // Pads were tappable only via a bare GestureDetector with
                  // zero Semantics tree, so the "watch the phrase light up,
                  // then tap it back" premise was silently unplayable by a
                  // blind child — the note each pad plays already makes the
                  // memory challenge audio-complete, this was purely the
                  // missing tap affordance. Label states only the pad's own
                  // number, never the sequence, matching tone_match's
                  // convention of describing visible/audible state, not the
                  // answer.
                  Semantics(
                    button: true,
                    label: 'Pad ${i + 1}',
                    onTap: () => _tap(i),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => _tap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          color: _lit == i
                              ? Color.lerp(_colors[i], Colors.white, 0.5)
                              : _colors[i].withOpacity(0.55),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: _lit == i
                              ? <BoxShadow>[
                                  BoxShadow(
                                      color: _colors[i], blurRadius: 24, spreadRadius: 2)
                                ]
                              : const <BoxShadow>[],
                        ),
                        child: const Center(
                          child: Text('🥁', style: TextStyle(fontSize: 40)),
                        ),
                      ),
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
