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

  void _addDrop(int i) {
    if (_status != GameStatus.playing) return;
    setState(() {
      _drops.add(i);
      TonePlayer.instance.playPop(0.6 + _drops.length * 0.03);
      final mix = _mixOf(_drops);
      final t = _targetRgb;
      final dist = math.sqrt(math.pow(mix[0] - t[0], 2) +
          math.pow(mix[1] - t[1], 2) +
          math.pow(mix[2] - t[2], 2));
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
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        } else {
          _newTarget();
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
      overEmoji: '🎨',
      overText: 'Master mixer!',
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
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(begin: mix, end: mix),
                  duration: const Duration(milliseconds: 250),
                  builder: (context, c, _) => Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: c ?? mix,
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
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < _dye.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
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
                              border:
                                  Border.all(color: Colors.white70, width: 2),
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

