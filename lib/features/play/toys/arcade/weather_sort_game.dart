part of '../arcade_games.dart';

/// Weather Sort — each item belongs to sunny, rainy or snowy weather. Tap the
/// weather it fits. Sort twelve to win.
class WeatherSortGame extends StatefulWidget {
  const WeatherSortGame({super.key});
  @override
  State<WeatherSortGame> createState() => _WeatherSortGameState();
}

class _WeatherSortGameState extends State<WeatherSortGame> with _Emit {
  static const String _id = 'weather_sort';
  static const int _target = 12;
  static const List<String> _bins = <String>['☀️', '🌧️', '❄️'];
  // item emoji -> correct bin index (0 sun, 1 rain, 2 snow)
  static const List<List<String>> _items = <List<String>>[
    <String>['🕶️', '🍦', '🏖️', '🌻', '🩳', '🏄'],
    <String>['☂️', '🥾', '🐸', '🌂', '💧', '🦆'],
    <String>['🧤', '⛄', '🧣', '⛷️', '🎿', '🧊'],
  ];
  final math.Random _rnd = math.Random();
  // Flattened (bin, item) draw order — shuffled bag with no repeat so a
  // full 12-item win sees real variety across all 18 items instead of
  // risking the same emoji (or even the same bin) several times in a row.
  final List<int> _bag = <int>[];
  String _item = '🕶️';
  int _answer = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  int _wrongFlash = -1;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _newItem();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int _drawFlatIndex() {
    if (_bag.isEmpty) {
      final total = _items.fold<int>(0, (sum, l) => sum + l.length);
      _bag.addAll(List<int>.generate(total, (i) => i)..shuffle(_rnd));
    }
    return _bag.removeLast();
  }

  void _newItem() {
    var flat = _drawFlatIndex();
    for (var bin = 0; bin < _items.length; bin++) {
      if (flat < _items[bin].length) {
        _answer = bin;
        _item = _items[bin][flat];
        break;
      }
      flat -= _items[bin].length;
    }
    _wrongFlash = -1;
  }

  void _pick(int bin) {
    if (_status != GameStatus.playing) return;
    if (bin == _answer) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Good sort! ${_bins[bin]}';
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _newItem();
      }
    } else {
      _wrongFlash = bin;
      _lives--;
      if (_lives <= 0) {
        // Final miss ends the round — give it its own distinct cue instead
        // of reusing the routine gentle-retry miss sound.
        _status = GameStatus.over;
        TonePlayer.instance.playCue(SoundCue.gameOver);
        emit(ExperienceEvent.incorrectAnswer);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
      }
      _banner = 'Which weather fits?';
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _banner = null;
      _bag.clear();
      _newItem();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🌦️ Weather Sort',
      introHow:
          'Look at the item, then tap the weather it belongs to — sunny, rainy or snowy!',
      onStart: () => setState(() {
        _bag.clear();
        _newItem();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Where does it go? · ${'💛' * _lives}',
      overEmoji: 'u{1F4AA}',
      overText: 'Out of lives — nice try!',
      winEmoji: '🌦️',
      winText: 'Weather wise!',
      accent: const Color(0xFF66D9E8),
      onPlayAgain: _reset,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(_item, style: const TextStyle(fontSize: 56)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (var i = 0; i < _bins.length; i++)
                  GestureDetector(
                    onTap: () => _pick(i),
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: _wrongFlash == i
                            ? const Color(0xFFE23B3B)
                            : Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(_bins[i], style: const TextStyle(fontSize: 44)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

