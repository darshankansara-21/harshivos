part of '../arcade_games.dart';

class MergeGame extends StatefulWidget {
  const MergeGame({super.key});
  @override
  State<MergeGame> createState() => _MergeGameState();
}

class _MergeGameState extends State<MergeGame> with _Emit {
  static const String _id = 'merge';
  static const int _n = 4;
  static const int _target = 64;
  final math.Random _rnd = math.Random();
  late List<List<int>> _g;
  int _maxTile = 2;
  int _milestone = 0;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _g = List<List<int>>.generate(_n, (_) => List<int>.filled(_n, 0));
    _spawn();
    _spawn();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _spawn() {
    final empty = <List<int>>[];
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (_g[r][c] == 0) empty.add(<int>[r, c]);
      }
    }
    if (empty.isEmpty) return;
    final cell = empty[_rnd.nextInt(empty.length)];
    _g[cell[0]][cell[1]] = _rnd.nextDouble() < 0.85 ? 2 : 4;
  }

  List<int> _slide(List<int> row) {
    final nums = row.where((v) => v != 0).toList();
    final out = <int>[];
    for (var i = 0; i < nums.length; i++) {
      if (i + 1 < nums.length && nums[i] == nums[i + 1]) {
        final merged = nums[i] * 2;
        out.add(merged);
        _score += merged;
        if (merged > _maxTile) {
          _maxTile = merged;
          _milestone = merged;
        }
        if (merged >= _target) _status = GameStatus.won;
        i++;
      } else {
        out.add(nums[i]);
      }
    }
    while (out.length < _n) {
      out.add(0);
    }
    return out;
  }

  void _move(int dir) {
    if (_status != GameStatus.playing) return;
    _banner = null;
    final before = _g.map((r) => r.join(',')).join('|');
    // 0 left, 1 right, 2 up, 3 down — normalise to a left-slide.
    List<List<int>> g = _g;
    for (var k = 0; k < dir; k++) {
      g = _rotate(g);
    }
    // For right/down we reverse rows to reuse the left-slide.
    final reverse = dir == 1 || dir == 2;
    g = <List<int>>[
      for (final row in g)
        (reverse ? _slide(row.reversed.toList()).reversed.toList() : _slide(row))
    ];
    for (var k = 0; k < ((4 - dir) % 4); k++) {
      g = _rotate(g);
    }
    _g = g;
    final after = _g.map((r) => r.join(',')).join('|');
    if (before != after) {
      _spawn();
      TonePlayer.instance.playCue(SoundCue.wood);
      emit(ExperienceEvent.bubblePopped);
    }
    if (_milestone > 0 && _status != GameStatus.won) {
      _banner = 'New best: $_milestone! 🎉';
      TonePlayer.instance.playCue(SoundCue.milestone);
      _milestone = 0;
    }
    if (_status == GameStatus.won) {
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
    } else if (_isStuck()) {
      _status = GameStatus.over;
      TonePlayer.instance.playCue(SoundCue.gameOver);
      emit(ExperienceEvent.incorrectAnswer);
    }
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
    setState(() {});
  }

  List<List<int>> _rotate(List<List<int>> g) {
    final out = List<List<int>>.generate(_n, (_) => List<int>.filled(_n, 0));
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        out[c][_n - 1 - r] = g[r][c];
      }
    }
    return out;
  }

  bool _isStuck() {
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (_g[r][c] == 0) return false;
        if (c + 1 < _n && _g[r][c] == _g[r][c + 1]) return false;
        if (r + 1 < _n && _g[r][c] == _g[r + 1][c]) return false;
      }
    }
    return true;
  }

  void _reset() {
    setState(() {
      _g = List<List<int>>.generate(_n, (_) => List<int>.filled(_n, 0));
      _score = 0;
      _maxTile = 2;
      _milestone = 0;
      _banner = null;
      _status = GameStatus.playing;
      _spawn();
      _spawn();
    });
  }

  Color _tileColor(int v) {
    if (v == 0) return Colors.white.withOpacity(0.05);
    final hue = (math.log(v) / math.ln2 * 28) % 360;
    return HSVColor.fromAHSV(1, hue, 0.6, 0.95).toColor();
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🔢 Merge',
      introHow: 'Slide to move the tiles. Matching numbers merge into bigger ones!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🔢',
      overText: 'Board full!',
      accent: const Color(0xFFF7B801),
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (d) =>
            _move((d.primaryVelocity ?? 0) < 0 ? 1 : 0),
        onVerticalDragEnd: (d) => _move((d.primaryVelocity ?? 0) < 0 ? 2 : 3),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF2A2036), Color(0xFF1A1226)],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.count(
                  crossAxisCount: _n,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (var r = 0; r < _n; r++)
                      for (var c = 0; c < _n; c++)
                        TweenAnimationBuilder<double>(
                          key: ValueKey('merge-$r-$c-${_g[r][c]}'),
                          tween: Tween<double>(
                              begin: _g[r][c] == 0 ? 1.0 : 1.18, end: 1.0),
                          duration: const Duration(milliseconds: 170),
                          curve: Curves.easeOutBack,
                          builder: (ctx, s, child) =>
                              Transform.scale(scale: s, child: child),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _tileColor(_g[r][c]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _g[r][c] == 0 ? '' : '${_g[r][c]}',
                                maxLines: 1,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Echo — watch the colour sequence, then repeat it. Each round adds one more.
// Reach a sequence of 8 to win. A calm memory challenge.
// ===========================================================================
