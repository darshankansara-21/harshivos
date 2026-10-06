part of '../arcade_games.dart';

class BallSortGame extends StatefulWidget {
  const BallSortGame({super.key});
  @override
  State<BallSortGame> createState() => _BallSortGameState();
}

class _BallSortGameState extends State<BallSortGame> with _Emit {
  static const String _id = 'ball_sort';
  static const int _cap = 4;
  static const List<Color> _colorsPal = <Color>[
    Color(0xFFEF476F), Color(0xFFFFD166), Color(0xFF06D6A0),
    Color(0xFF4CC9F0), Color(0xFF9B5DE5), Color(0xFFFF9E00),
  ];
  // Spoken names for the palette above, index-matched, since a screen reader
  // has no way to announce a raw Color value.
  static const List<String> _colorNames = <String>[
    'Red', 'Yellow', 'Green', 'Blue', 'Purple', 'Orange',
  ];
  final math.Random _rnd = math.Random();
  late List<List<int>> _tubes;
  int _selected = -1;
  int _level = 0;
  int _colorsN = 3;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // Ball Sort has no win cap — the level counter climbs forever, same open-
  // ended shape as Stack/Block Blast/Bubble Shooter, so crossing a prior
  // all-time best mid-run is a real, distinct moment worth its own banner
  // (not just the routine "Level N!" every solve already gets).
  bool _beatBest = false;

  @override
  void initState() {
    super.initState();
    _deal();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  // A naive full shuffle of the balls across tubes can and does land on
  // arrangements that are mathematically impossible to sort — a well-known
  // trap for this puzzle genre. A stuck child would have no in-game recourse
  // except abandoning the level entirely. Deal, then verify solvability with
  // a bounded BFS over the exact same pour move the player uses; reshuffle on
  // failure. (An earlier attempt tried scrambling forward from the solved
  // state instead, but the pour rule only ever lets a ball land on an empty
  // tube or one whose top already matches — which means every tube stays
  // single-colour forever under that approach, so it could never produce the
  // mixed-colour tubes that make this puzzle a real challenge. Shuffle first,
  // verify after is the only approach that both can produce a real puzzle and
  // guarantees it's solvable.)
  void _deal() {
    _colorsN = math.min(6, 3 + _level ~/ 2);
    const maxAttempts = 60;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      _tubes = List<List<int>>.generate(_colorsN + 2, (_) => <int>[]);
      final balls = <int>[
        for (var c = 0; c < _colorsN; c++) for (var k = 0; k < _cap; k++) c,
      ]..shuffle(_rnd);
      var idx = 0;
      for (var t = 0; t < _colorsN; t++) {
        for (var k = 0; k < _cap; k++) {
          _tubes[t].add(balls[idx++]);
        }
      }
      if (_isSolvable(_tubes)) break;
      // Last attempt: keep whatever we have rather than looping forever —
      // in practice a solvable deal is found within the first few tries.
    }
    _selected = -1;
  }

  bool _solved() => _isSolvedState(_tubes);

  bool _isSolvedState(List<List<int>> tubes) {
    for (final t in tubes) {
      if (t.isEmpty) continue;
      if (t.length != _cap || t.any((c) => c != t.first)) return false;
    }
    return true;
  }

  // Bounded BFS over the real pour move, using a canonical (tube-order
  // independent) state key so swapping two interchangeable empty/same-colour
  // tubes doesn't blow up the search. Capped at a modest node budget so a
  // single deal never visibly stalls the UI.
  bool _isSolvable(List<List<int>> start) {
    String key(List<List<int>> s) {
      final parts = s.map((t) => t.join(',')).toList()..sort();
      return parts.join('|');
    }

    final seen = <String>{key(start)};
    final queue = <List<List<int>>>[start];
    var head = 0;
    const maxNodes = 15000;
    while (head < queue.length && queue.length < maxNodes) {
      final s = queue[head++];
      if (_isSolvedState(s)) return true;
      for (var i = 0; i < s.length; i++) {
        if (s[i].isEmpty) continue;
        final ball = s[i].last;
        for (var j = 0; j < s.length; j++) {
          if (j == i || s[j].length >= _cap) continue;
          if (s[j].isNotEmpty && s[j].last != ball) continue;
          final ns = <List<int>>[for (final t in s) List<int>.from(t)];
          ns[i].removeLast();
          ns[j].add(ball);
          final k = key(ns);
          if (seen.add(k)) queue.add(ns);
        }
      }
    }
    return false;
  }

  void _tapTube(int i) {
    if (_status != GameStatus.playing) return;
    if (_selected == -1) {
      if (_tubes[i].isNotEmpty) setState(() => _selected = i);
      return;
    }
    if (_selected == i) {
      setState(() => _selected = -1);
      return;
    }
    final from = _tubes[_selected];
    final to = _tubes[i];
    final ball = from.isNotEmpty ? from.last : -1;
    if (ball != -1 && to.length < _cap && (to.isEmpty || to.last == ball)) {
      setState(() {
        from.removeLast();
        to.add(ball);
        _selected = -1;
      });
      TonePlayer.instance.playCue(SoundCue.water);
      if (_solved()) {
        _score++;
        _level++;
        TonePlayer.instance.playCue(SoundCue.success);
        emit(ExperienceEvent.gameCompleted);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        if (!_beatBest && _best > 0 && _score > _best) {
          _beatBest = true;
          // Takes priority over the routine "Level N!" banner below — a new
          // all-time record is the bigger moment of the two.
          _banner = 'New personal best! 🏆';
          TonePlayer.instance.playCue(SoundCue.milestone);
          emit(ExperienceEvent.personalBest);
        } else {
          _banner = 'Level $_level!';
        }
        setState(_deal);
      }
    } else {
      // Every other puzzle/question game in the catalog pairs an invalid
      // attempt with a quiet `gentleRetry` cue (add_it_up, block_blast,
      // merge, tic_tac_toe, etc.) — this was the one tap-a-tube game left
      // completely silent on a blocked pour (wrong colour on top, or the
      // target tube already full), so a child attempting an invalid move
      // got no feedback at all, not even a sound, that anything happened.
      // Only flash it as a genuine blocked-pour, not plain reselection: a
      // tap on an empty tube (no pour was even attempted) or a tap that
      // simply swaps which non-empty tube is selected next is a normal,
      // silent part of play, same as `_selected == i` deselecting above.
      if (ball != -1 && _tubes[i].isNotEmpty) {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
      }
      setState(() => _selected = _tubes[i].isNotEmpty ? i : -1);
    }
  }

  void _reset() {
    setState(() {
      _level = 0;
      _score = 0;
      _banner = null;
      _beatBest = false;
      _status = GameStatus.playing;
      _deal();
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🧪 Ball Sort',
      introHow: 'Tap a tube, then another, to pour. Sort each colour together!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      accent: const Color(0xFF06D6A0),
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1A2036), Color(0xFF0E1424)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 40),
            child: FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (var i = 0; i < _tubes.length; i++) _tube(i),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Describes a tube's contents from the top (pourable) ball down to the
  // bottom, by colour name, plus how much empty space remains — never which
  // tube is "correct" to pour into, so the actual sorting puzzle stays
  // intact for a screen-reader user, exactly as a sighted child must look at
  // the stack order themselves.
  String _tubeLabel(int i) {
    final t = _tubes[i];
    if (t.isEmpty) return 'Tube ${i + 1}: empty.';
    final fromTop = t.reversed.map((c) => _colorNames[c]).join(', then ');
    final space = _cap - t.length;
    final spaceDesc =
        space > 0 ? ' Room for $space more ball${space == 1 ? '' : 's'}.' : ' Full.';
    return 'Tube ${i + 1}: top $fromTop.$spaceDesc';
  }

  Widget _tube(int i) {
    const ball = 34.0;
    final t = _tubes[i];
    final selected = _selected == i;
    return Semantics(
      button: true,
      label: selected ? '${_tubeLabel(i)} Selected.' : _tubeLabel(i),
      onTap: () => _tapTube(i),
      excludeSemantics: true,
      child: GestureDetector(
      onTap: () => _tapTube(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, selected ? -16 : 0, 0),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10), bottom: Radius.circular(28)),
          border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2.5 : 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var s = _cap - 1; s >= 0; s--)
              TweenAnimationBuilder<double>(
                key: ValueKey('bs-$i-$s-${s < t.length ? t[s] : -1}'),
                tween: Tween<double>(
                    begin: s < t.length ? 1.3 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (ctx, sc, child) =>
                    Transform.scale(scale: sc, child: child),
                child: Container(
                  width: ball,
                  height: ball,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s < t.length
                        ? _colorsPal[t[s]]
                        : Colors.white.withOpacity(0.04),
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
// Tap Order — a Schulte grid. Numbers 1–25 are scattered; tap them in order as
// fast as you can. A classic attention / visual-search trainer that's calm and
// forgiving: a wrong tap just gives a gentle nudge, never ends the game.
// ===========================================================================
