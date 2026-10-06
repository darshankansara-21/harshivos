part of '../arcade_games.dart';

/// Weather Sort — each item belongs to sunny, rainy or snowy weather. Tap the
/// weather it fits. Sort twelve to win.
class WeatherSortGame extends StatefulWidget {
  const WeatherSortGame({super.key});
  @override
  State<WeatherSortGame> createState() => _WeatherSortGameState();
}

class _WeatherSortGameState extends State<WeatherSortGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'weather_sort';
  static const int _target = 12;
  static const List<String> _bins = <String>['☀️', '🌧️', '❄️'];
  // item emoji -> correct bin index (0 sun, 1 rain, 2 snow)
  static const List<List<String>> _items = <List<String>>[
    <String>['🕶️', '🍦', '🏖️', '🌻', '🩳', '🏄'],
    <String>['☂️', '🥾', '🐸', '🌂', '💧', '🦆'],
    <String>['🧤', '⛄', '🧣', '⛷️', '🎿', '🧊'],
  ];
  // Human-readable names for the Semantics labels below — raw emoji glyphs
  // don't always read sensibly through a screen reader, so every item and
  // bin gets an explicit spoken name instead (same convention as the
  // _shapeNames/_colorName helpers used by odd_one_out/shadow_match).
  static const Map<String, String> _itemNames = <String, String>{
    '🕶️': 'sunglasses',
    '🍦': 'ice cream',
    '🏖️': 'beach umbrella',
    '🌻': 'sunflower',
    '🩳': 'shorts',
    '🏄': 'surfing',
    '☂️': 'open umbrella',
    '🥾': 'rain boot',
    '🐸': 'frog',
    '🌂': 'folded umbrella',
    '💧': 'water droplet',
    '🦆': 'duck',
    '🧤': 'mittens',
    '⛄': 'snowman',
    '🧣': 'scarf',
    '⛷️': 'skier',
    '🎿': 'skis',
    '🧊': 'ice cube',
  };
  static const List<String> _binNames = <String>['sunny', 'rainy', 'snowy'];
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Weather wise!', 'Forecast star!', 'Sorting champ!', 'Great sorting!',
  ];
  String _winPraise = _winPraisePool[0];
  String _overPraise = _gentleTryAgainPool[0];
  // Every routine timeout flashed the exact same "Too slow — next one!"
  // banner (up to several times in one round); vary it like the
  // win-screen/over-screen pools above.
  static const List<String> _missPool = <String>[
    'Too slow — next one!', "Time's up — next one!", 'Just missed it — next one!', 'Next one!',
  ];
  // full 12-item win sees real variety across all 18 items instead of
  // risking the same emoji (or even the same bin) several times in a row.
  final List<int> _bag = <int>[];
  String _item = '🕶️';
  int _answer = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  bool _beatBest = false;
  int _wrongFlash = -1;
  // Unlike the wrong tap (which flashes the bin red), a correct sort gave
  // zero tile-level feedback — the item just silently swapped for the next
  // one. Flash the tapped bin green for a beat first, same convention. The
  // timer freezes for this same beat (via `_locked`) so a correct answer can
  // never itself cost a life to a timeout while its own flash is showing.
  int _correctFlash = -1;
  bool _locked = false;
  String? _banner;
  GameStatus _status = GameStatus.ready;
  // Every other sort was answerable at a dead-calm, infinite pace — zero
  // challenge curve, the same flat-forever gap already fixed across
  // letter_trace/mirror_draw/shape_builder/color_mixer. Unlike those games'
  // tap-tolerance, there's no shrinkable domain here (always exactly 3
  // weather bins), so the honest escalation is a per-item think-time window
  // that narrows as `_score` climbs — same additive, score-gated shape, just
  // along the time axis instead of space. A timeout costs a life exactly
  // like a wrong tap (never a different, harsher penalty) and is always
  // visibly countered by the on-screen timer bar below, never a silent clock.
  double _timeLeft = 0;
  double get _timeLimit =>
      (6.0 - (_score + _careerSkillRamp) * (6.0 - 3.0) / _target)
          .clamp(3.0, 6.0);
  // The think-time ramp above only ever read the current round's `_score`,
  // so a veteran with a high all-time `_best` restarted every single
  // playthrough at the identical easy 6-second round 1 — the same
  // "flat-forever difficulty never fed by career `_best`" bug class already
  // closed for the quiz-game family. Nudge the effective score a little
  // from round 1 for a seasoned player, capped small so round 1 stays
  // genuinely playable even for them.
  int get _careerSkillRamp => (_best ~/ 3).clamp(0, 2);

  @override
  void initState() {
    super.initState();
    _newItem();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing || _locked) return;
    _timeLeft -= dt;
    if (_timeLeft <= 0) _timeOut();
  }

  void _timeOut() {
    _wrongFlash = -1;
    _lives--;
    // Every timed-out item deserves the companion's gentle encouraging
    // reaction, not just the one that happens to end the game.
    emit(ExperienceEvent.incorrectAnswer);
    if (_lives <= 0) {
      _status = GameStatus.over;
      _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
      TonePlayer.instance.playCue(SoundCue.gameOver);
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = _missPool[_rnd.nextInt(_missPool.length)];
      _newItem();
    }
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
    _correctFlash = -1;
    _timeLeft = _timeLimit;
  }

  void _pick(int bin) {
    if (_status != GameStatus.playing || _locked) return;
    if (bin == _answer) {
      _score++;
      _correctFlash = bin;
      _locked = true;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Good sort! ${_bins[bin]}';
      // A child who runs out of lives right after this sort still deserves
      // the companion's loudest celebration if it's a genuine all-time
      // record, not just the routine correct-sort chime.
      final crossedBest = _score > _best && !_beatBest && _best > 0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (crossedBest) {
        _beatBest = true;
        _banner = 'New personal best! 🏆';
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
      if (_score >= _target) {
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        // The final correct tap used to jump straight to the win overlay in
        // the same frame, so the green bin flash above was set but never
        // actually rendered before the whole game view was replaced. Give
        // it the same 220ms beat as every other correct sort before
        // declaring the win, so the last item is visibly confirmed too;
        // `_locked` already freezes the countdown for this same beat.
        Future.delayed(const Duration(milliseconds: 220), () {
          if (!mounted) return;
          setState(() => _status = GameStatus.won);
          TonePlayer.instance.playCue(SoundCue.gameStart);
          emit(ExperienceEvent.gameCompleted);
        });
      } else {
        // Let the green flash above actually be seen before the item swaps
        // out for the next one; `_locked` freezes the countdown meanwhile.
        Future.delayed(const Duration(milliseconds: 220), () {
          if (!mounted || _status != GameStatus.playing) return;
          setState(() {
            _locked = false;
            _newItem();
          });
        });
      }
    } else {
      _wrongFlash = bin;
      _lives--;
      // Every wrong bin deserves the companion's gentle encouraging
      // reaction, not just the one that happens to end the game.
      emit(ExperienceEvent.incorrectAnswer);
      if (_lives <= 0) {
        // Final miss ends the round — give it its own distinct cue instead
        // of reusing the routine gentle-retry miss sound.
        _status = GameStatus.over;
        _overPraise = _gentleTryAgainPool[_rnd.nextInt(_gentleTryAgainPool.length)];
        TonePlayer.instance.playCue(SoundCue.gameOver);
      } else {
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
        // The red flash is a momentary "that's wrong" cue, not a permanent
        // state — clear it shortly after so a miss doesn't leave the bin
        // stuck red until the next correct answer (matches the
        // catalog-standard auto-clear pattern used by shape_builder/
        // sorting_train's wrong-flash feedback).
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _wrongFlash == bin) setState(() => _wrongFlash = -1);
        });
      }
      _banner = 'Which weather fits?';
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _beatBest = false;
      _locked = false;
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
          'Look at the item, then tap the weather it belongs to — sunny, rainy '
          'or snowy! Answer before the bar runs out.',
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
      overEmoji: '💪',
      overText: _overPraise,
      winEmoji: '🌦️',
      winText: _winPraise,
      accent: const Color(0xFF66D9E8),
      onPlayAgain: _reset,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Semantics(
              label: 'Item to sort: ${_itemNames[_item] ?? _item}',
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_item, style: const TextStyle(fontSize: 56)),
                ),
              ),
            ),
            // Decorative think-time countdown — purely visual, never the
            // only cue a timeout is coming; the banner/lives text above
            // already tells a screen-reader user everything a timeout needs.
            if (_status == GameStatus.playing)
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_timeLeft / _timeLimit).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timeLeft < _timeLimit * 0.3
                            ? const Color(0xFFE23B3B)
                            : const Color(0xFF66D9E8),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (var i = 0; i < _bins.length; i++)
                  Semantics(
                    button: true,
                    label: '${_binNames[i]} weather bin',
                    onTap: () => _pick(i),
                    // Without this, the bin's own emoji Text below forms its
                    // own separate, unlabeled semantics node nested inside
                    // this labeled button — the one bin-tap target left in
                    // the whole arcade catalog missing the `excludeSemantics`
                    // every sibling Semantics-wrapping-GestureDetector tap
                    // target already sets, which left a screen-reader user
                    // hearing a confusing duplicate/competing node instead
                    // of just the one clearly-labeled "sunny weather bin"
                    // button.
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => _pick(i),
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: _wrongFlash == i
                              ? const Color(0xFFE23B3B)
                              : _correctFlash == i
                                  ? const Color(0xFF80ED99)
                                  : Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(_bins[i],
                              style: const TextStyle(fontSize: 44)),
                        ),
                      ),
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

