part of '../arcade_games.dart';

class TapOrderGame extends StatefulWidget {
  const TapOrderGame({super.key});
  @override
  State<TapOrderGame> createState() => _TapOrderGameState();
}

class _TapOrderGameState extends State<TapOrderGame> with _Emit {
  static const String _id = 'tap_order';
  final math.Random _rnd = math.Random();
  late List<int> _cells; // number shown at each of the 25 cells
  int _next = 1;
  int _score = 0;
  int _round = 1;
  int _best = 0;
  String? _banner;
  // Every round/best banner was only ever cleared by `_reset()`, so it
  // glued itself on screen through the rest of the session.
  Timer? _bannerTimer;
  int _wrongCell = -1;
  GameStatus _status = GameStatus.ready;

  void _flashBanner(String text, {Duration duration = const Duration(milliseconds: 1300)}) {
    _banner = text;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(duration, () {
      if (mounted) setState(() => _banner = null);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }
  // Rounds repeat the exact same 1-25 shuffle forever with no escalation at
  // all, leaving the game with zero challenge curve — the quality bar every
  // other round-based game in the catalog clears. Rather than bolt on a
  // generic difficulty gimmick, track how fast each round is cleared and
  // celebrate a genuine personal-best time, so going again has a real,
  // honest goal (beat your own speed) instead of just repeating forever.
  //
  // This was kept as a plain in-memory `Duration?` field, so it reset to
  // null every time the widget was recreated (leaving the game, re-opening
  // it, or an app restart) — the exact "stat that can never move"/doesn't
  // persist bug class already fixed via `GameScores.bestLow`/`submitLow`
  // for jigsaw_four's fastest-rebuild-time. Mirror that same lower-is-better
  // persisted-best pattern here so a genuinely faster round is remembered
  // across sessions, not just within the current one.
  static const String _timeId = '${_id}_time_ms';
  DateTime? _roundStart;
  int _bestRoundTimeMs = 0;
  // `_score` is a running tally across every round this session (it only
  // ever resets via `_reset()`, not between rounds), so it climbs open-
  // ended exactly like bubble_wrap/maze_run/echo/quick_tap's run totals —
  // but unlike every one of those siblings, crossing a prior all-time best
  // here only ever updated `_best` silently with no banner, milestone chime
  // or `ExperienceEvent.personalBest`. Guard it the same way (reset in
  // `_reset()`) so a genuinely record-setting session gets the same
  // celebration every other open-ended-score game in the catalog gives.
  bool _beatBest = false;

  @override
  void initState() {
    super.initState();
    _shuffle();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) {
        setState(() {
          _best = GameScores.instance.best(_id);
          _bestRoundTimeMs = GameScores.instance.bestLow(_timeId);
        });
      }
    });
  }

  void _shuffle() {
    _cells = List<int>.generate(25, (i) => i + 1)..shuffle(_rnd);
    _next = 1;
    _roundStart = DateTime.now();
  }

  String _fmtTime(Duration d) =>
      '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';

  void _tap(int cell) {
    if (_status != GameStatus.playing) return;
    if (_cells[cell] == _next) {
      _score++;
      _next++;
      TonePlayer.instance.playNote(_next % 10, seconds: 0.16);
      emit(ExperienceEvent.bubblePopped);
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) setState(() => _best = b);
      });
      if (_next > 25) {
        _round++;
        final elapsed = DateTime.now().difference(_roundStart!);
        final elapsedMs = elapsed.inMilliseconds;
        final isBest = _bestRoundTimeMs <= 0 || elapsedMs < _bestRoundTimeMs;
        // A record-setting session total is the bigger moment of the two if
        // both land on the same tap — takes priority over the routine
        // round/time banner, same convention as ball_sort/maze_run's
        // "New personal best!" vs. their own routine level banner.
        _flashBanner(crossedBest
            ? 'New personal best! 🏆'
            : isBest
                ? 'Round $_round! ${_fmtTime(elapsed)} · ⭐ New best time!'
                : 'Round $_round! ${_fmtTime(elapsed)} · '
                    'best ${_fmtTime(Duration(milliseconds: _bestRoundTimeMs))}');
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
        if (isBest) {
          GameScores.instance.submitLow(_timeId, elapsedMs).then((v) {
            if (mounted) setState(() => _bestRoundTimeMs = v);
          });
        }
        if (crossedBest) {
          _beatBest = true;
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        }
        setState(_shuffle);
      } else if (crossedBest) {
        _beatBest = true;
        _flashBanner('New personal best! 🏆');
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
        setState(() {});
      } else {
        setState(() {});
      }
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      emit(ExperienceEvent.incorrectAnswer);
      setState(() => _wrongCell = cell);
      // Guard on `_wrongCell == cell`, not just `mounted` — a second wrong
      // tap on a different cell before this timer fires would otherwise let
      // the stale first timer clear the newer cell's highlight early, same
      // index-specific-clear convention every sibling wrong-flash timer in
      // the catalog already follows (add_it_up/bigger_number's `_wrong == i`,
      // odd_one_out/shadow_match/weather_sort's `_wrongFlash == idx`, etc.).
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _wrongCell == cell) setState(() => _wrongCell = -1);
      });
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _round = 1;
      _banner = null;
      _bannerTimer?.cancel();
      _beatBest = false;
      _status = GameStatus.playing;
      _shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔢 Tap Order',
      introHow: 'Tap the numbers in order — 1, 2, 3… as fast as you can!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF10233A), Color(0xFF0A1626)],
          ),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 116),
            Text('Tap $_next',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var i = 0; i < 25; i++)
                      Semantics(
                        button: true,
                        label: _cells[i] < _next
                            ? 'Cell already cleared'
                            : 'Cell showing number ${_cells[i]}',
                        onTap: () => _tap(i),
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTapDown: (_) => _tap(i),
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey('tap-$i-${_cells[i] < _next}'),
                            tween: Tween<double>(
                                begin: _cells[i] < _next ? 1.25 : 1.0,
                                end: 1.0),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            builder: (c, s, child) =>
                                Transform.scale(scale: s, child: child),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _wrongCell == i
                                    ? const Color(0xFFEF476F)
                                    : _cells[i] < _next
                                        ? const Color(0xFF06D6A0)
                                            .withOpacity(0.3)
                                        : Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _cells[i] < _next ? '' : '${_cells[i]}',
                                  maxLines: 1,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Piano Tiles — tap the falling tiles in their column before they slip past the
// bottom. Each tap plays a note so a melody builds; it speeds up as you go.
// ===========================================================================
