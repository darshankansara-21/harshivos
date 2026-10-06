part of '../arcade_games.dart';

/// Color Mixer — drop primary paints into the bowl to match the target colour.
/// Teaches mixing (red + yellow = orange) through play. Match eight to win.
class ColorMixerGame extends StatefulWidget {
  const ColorMixerGame({super.key});
  @override
  State<ColorMixerGame> createState() => _ColorMixerGameState();
}

class _ColorMixerGameState extends State<ColorMixerGame> with _Emit {
  static const String _id = 'color_mixer';
  static const int _target = 8;
  // Primaries as (r,g,b) 0..1: red, yellow, blue, white.
  static const List<List<double>> _dye = <List<double>>[
    <double>[0.90, 0.20, 0.22],
    <double>[0.98, 0.85, 0.22],
    <double>[0.20, 0.45, 0.90],
    <double>[0.96, 0.96, 0.96],
  ];
  static const List<String> _dyeName = <String>['Red', 'Yellow', 'Blue', 'White'];
  static const List<Color> _dyeColor = <Color>[
    Color(0xFFE63339),
    Color(0xFFFAD938),
    Color(0xFF3373E6),
    Color(0xFFF5F5F5),
  ];
  // Recipes: name + primary indices.
  static const List<List<int>> _recipes = <List<int>>[
    <int>[0, 1], // orange
    <int>[1, 2], // green
    <int>[0, 2], // purple
    <int>[0, 1, 2], // brown
    <int>[0, 3], // pink
    <int>[2, 3], // sky
  ];
  static const List<String> _recipeName = <String>[
    'Orange', 'Green', 'Purple', 'Brown', 'Pink', 'Sky blue',
  ];
  // Pool of full-game win phrases so a replaying child doesn't always see
  // the identical "Master mixer!" line on win screen.
  static const List<String> _winPraisePool = <String>[
    'Master mixer!',
    'Color genius!',
    'Perfect palette!',
    'True colour champion!',
  ];
  String _winPraise = _winPraisePool[0];
  final math.Random _rnd = math.Random();
  final List<int> _drops = <int>[];
  final List<int> _bag = <int>[];
  int _recipe = 0;
  int _score = 0;
  int _best = 0;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  List<double> _mixOf(List<int> drops) {
    if (drops.isEmpty) return <double>[0.96, 0.96, 0.96];
    var r = 0.0, g = 0.0, b = 0.0;
    for (final d in drops) {
      r += _dye[d][0];
      g += _dye[d][1];
      b += _dye[d][2];
    }
    return <double>[r / drops.length, g / drops.length, b / drops.length];
  }

  List<double> get _targetRgb => _mixOf(_recipes[_recipe]);

  Color _toColor(List<double> c) =>
      Color.fromARGB(255, (c[0] * 255).round(), (c[1] * 255).round(),
          (c[2] * 255).round());

  int _drawRecipe() {
    // Shuffled bag with no immediate repeat: with only 6 recipes and 8 wins
    // needed, plain Random.nextInt() with replacement let a child see the
    // same recipe repeat back-to-back or miss others across a whole round
    // (same gap class as kindness_match/calm_choices/weather_sort).
    if (_bag.isEmpty) {
      _bag.addAll(List<int>.generate(_recipes.length, (i) => i)..shuffle(_rnd));
    }
    return _bag.removeLast();
  }

  void _newTarget() {
    _recipe = _drawRecipe();
    _drops.clear();
  }

  double _dist(List<double> a, List<double> b) => math.sqrt(
      math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2) + math.pow(a[2] - b[2], 2));

  void _addDrop(int i) {
    if (_status != GameStatus.playing) return;
    setState(() {
      final t = _targetRgb;
      // Capture the distance BEFORE this drop so a blind-guessing child gets
      // an honest "warmer/colder" steer on every pour, not just silence until
      // (if ever) they happen to land inside the match threshold. Without
      // this, diluting the bowl with the wrong colour for 10+ drops gave zero
      // feedback at all — the one gap left in this catalog's wrong-answer
      // feedback pattern.
      final prevDist = _drops.isEmpty ? double.infinity : _dist(_mixOf(_drops), t);
      _drops.add(i);
      TonePlayer.instance.playPop(0.6 + _drops.length * 0.03);
      final mix = _mixOf(_drops);
      final dist = _dist(mix, t);
      if (_drops.length >= 2 && dist < 0.14) {
        _score++;
        _banner = 'Matched ${_recipeName[_recipe]}! 🎨';
        emit(ExperienceEvent.bubblePopped);
        TonePlayer.instance.playCue(SoundCue.success);
        GameScores.instance.submit(_id, _score).then((b) {
          if (mounted) setState(() => _best = b);
        });
        if (_score >= _target) {
          _status = GameStatus.won;
          _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _newTarget();
        }
      } else if (_drops.length >= 2) {
        if (dist < prevDist - 0.01) {
          _banner = 'Getting warmer!';
        } else if (dist > prevDist + 0.01) {
          _banner = 'Getting colder — try Empty the bowl';
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
          emit(ExperienceEvent.incorrectAnswer);
        }
      }
    });
  }

  void _clearBowl() {
    if (_status != GameStatus.playing) return;
    setState(() => _drops.clear());
  }

  void _reset() {
    setState(() {
      _score = 0;
      _banner = null;
      _bag.clear();
      _newTarget();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    final target = _toColor(_targetRgb);
    final mix = _toColor(_mixOf(_drops));
    return _Shell(
      title: '🎨 Color Mixer',
      introHow:
          'Tap the paint drops to pour them in and match the target colour. Red + yellow = orange!',
      onStart: () => setState(() {
        _bag.clear();
        _newTarget();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Make ${_recipeName[_recipe]}',
      winEmoji: '🎨',
      winText: _winPraise,
      accent: const Color(0xFFE0407A),
      onPlayAgain: _reset,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Column(
              children: <Widget>[
                Text('Make ${_recipeName[_recipe]}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: target,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 3),
                  ),
                ),
              ],
            ),
            Column(
              children: <Widget>[
                const Text('Your bowl',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                // Each new drop should visibly BLEND into the bowl rather than
                // snap instantly — but `TweenAnimationBuilder<Color?>` was
                // given `begin: mix, end: mix`, the same freshly-computed
                // value for both ends of its own tween, on every rebuild. An
                // interpolation between two identical colours is a no-op, so
                // the "smooth mixing" polish this widget was built for never
                // actually ran; the bowl just jumped straight to the new
                // colour. `AnimatedContainer` genuinely animates its `color`
                // property across rebuilds by diffing the previous widget,
                // so swapping to it makes every pour visibly swirl/blend in.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: mix,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black38, blurRadius: 8)
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(_drops.isEmpty ? 'empty' : '${_drops.length}',
                      style: TextStyle(
                          color: Colors.black.withOpacity(0.45),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < _dye.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    // The 4 paint drops were only tappable via a bare
                    // GestureDetector with zero Semantics tree, so a blind
                    // child's screen reader announced nothing at all here —
                    // not even "button" — making the whole "tap to pour"
                    // premise silently undiscoverable. The label states only
                    // each drop's own colour name (already shown as visible
                    // text beneath it), never which combination makes the
                    // target, preserving the real mixing-logic challenge
                    // exactly as a sighted child must work it out.
                    child: Semantics(
                      button: true,
                      label: '${_dyeName[i]} paint. Tap to pour into the bowl.',
                      onTap: () => _addDrop(i),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => _addDrop(i),
                        child: Column(
                          children: <Widget>[
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _dyeColor[i],
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white70, width: 2),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_dyeName[i],
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: _clearBowl,
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
              label: const Text('Empty the bowl',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

