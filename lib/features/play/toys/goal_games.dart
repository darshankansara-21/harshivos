import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/game_music_host.dart';
import '../../../services/audio/tone_player.dart';
import '../../companion/companion.dart';
import 'mini_games.dart' show GameScores, GameStatus;

/// Lets a goal-shell game emit companion events (correct / win / encourage)
/// and flushes them to the host after the frame — the same pattern
/// arcade_games.dart's `_Emit` and mini_games.dart's `_CompanionEmitter` use,
/// duplicated here because each of these is a separate library.
mixin _GoalEmit<T extends StatefulWidget> on State<T> {
  final List<ExperienceEvent> _pendingEvents = <ExperienceEvent>[];

  void emit(ExperienceEvent event) => _pendingEvents.add(event);

  void drainCompanion(BuildContext context) {
    if (_pendingEvents.isEmpty) return;
    final events = List<ExperienceEvent>.from(_pendingEvents);
    _pendingEvents.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final event in events) {
        CompanionEventNotification(event).dispatch(context);
      }
    });
  }
}

class _GoalShell extends StatefulWidget {
  const _GoalShell({
    required this.title,
    required this.goal,
    required this.score,
    required this.target,
    required this.status,
    required this.accent,
    required this.onReset,
    required this.child,
    this.best = 0,
    this.stars = 0,
    this.message,
    this.introHow,
    this.onStart,
    this.winEmoji,
    this.winText,
    this.overEmoji,
    this.overText,
  });

  final String title;
  final String goal;
  final int score;
  final int target;
  final int best;
  final int stars;
  final GameStatus status;
  final Color accent;
  final VoidCallback onReset;
  final Widget child;
  final String? message;
  final String? introHow;
  final VoidCallback? onStart;
  // Optional per-game win/lose flavour. Null falls back to the shared
  // generic '🎉 Goal complete!' / '💪 Good try!' so every untouched game
  // stays pixel-identical — same additive, zero-regression pattern used by
  // `_Shell`/`_GameShell`'s own winEmoji/winText/overEmoji/overText.
  final String? winEmoji;
  final String? winText;
  final String? overEmoji;
  final String? overText;

  @override
  State<_GoalShell> createState() => _GoalShellState();
}

class _GoalShellState extends State<_GoalShell> {
  // Same freeze-at-run-start pattern as _Shell/_GameShell: `best` ratchets
  // upward mid-run as soon as the score ties/beats the prior record, so
  // comparing the final score against the live `best` would wrongly call an
  // exact tie with a pre-existing record a "new best". Freeze it instead.
  late int _runStartBest = widget.best;

  @override
  void didUpdateWidget(covariant _GoalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != GameStatus.playing &&
        widget.status == GameStatus.playing) {
      _runStartBest = oldWidget.best;
    }
    // See _Shell's matching comment in arcade_games.dart: one discrete
    // haptic pulse when a run ends, not on every tap. Must gate on
    // hapticsEnabled itself since it bypasses TonePlayer.playCue.
    if (oldWidget.status == GameStatus.playing &&
        widget.status != GameStatus.playing &&
        TonePlayer.instance.hapticsEnabled) {
      if (widget.status == GameStatus.won) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final goal = widget.goal;
    final score = widget.score;
    final target = widget.target;
    final best = widget.best;
    final stars = widget.stars;
    final status = widget.status;
    final accent = widget.accent;
    final onReset = widget.onReset;
    final child = widget.child;
    final message = widget.message;
    final introHow = widget.introHow;
    final onStart = widget.onStart;
    final winEmoji = widget.winEmoji;
    final winText = widget.winText;
    final overEmoji = widget.overEmoji;
    final overText = widget.overText;
    return GameMusicHost(
      playing: status == GameStatus.playing,
      bed: WonderMusicBed.puzzle,
      child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 72, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Semantics(
                    container: true,
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.62),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        '$title   $score / $target${best > 0 ? '   ★ $best' : ''}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.48),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      goal,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (message != null) ...<Widget>[
                    const SizedBox(height: 6),
                    // See _Shell's matching comment in arcade_games.dart:
                    // this pill carries live status (e.g. GoalKeeper's
                    // "Lives 🧤🧤·" readout after each shot) via setState,
                    // previously silent to assistive tech on change.
                    Semantics(
                      container: true,
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (status == GameStatus.won || status == GameStatus.over)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(0.72),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // See _Shell's matching comment in arcade_games.dart: a
                    // one-shot merged announcement so a screen-reader user
                    // learns the win/lose screen appeared without having to
                    // manually swipe around to find it.
                    Semantics(
                      liveRegion: true,
                      label: status == GameStatus.won
                          ? '${winText ?? 'Goal complete!'} Score $score of $target.'
                              '${stars >= 3 ? ' Perfect, no mistakes!' : stars == 2 ? ' Great work!' : ' You did it!'}'
                              '${score > 0 && score > _runStartBest ? ' New best!' : ''}'
                          : '${overText ?? 'Good try!'} Score $score of $target.',
                      child: const SizedBox.shrink(),
                    ),
                    Text(
                        status == GameStatus.won
                            ? (winEmoji ?? '🎉')
                            : (overEmoji ?? '💪'),
                        style: const TextStyle(fontSize: 70)),
                    const SizedBox(height: 8),
                    Text(
                      status == GameStatus.won
                          ? (winText ?? 'Goal complete!')
                          : (overText ?? 'Good try!'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Score $score of $target',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    if (status == GameStatus.won) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        <String>['⭐', '⭐⭐', '⭐⭐⭐'][
                            (stars.clamp(1, 3)) - 1],
                        style: const TextStyle(fontSize: 30),
                      ),
                      Text(
                        stars >= 3
                            ? 'Perfect — no mistakes!'
                            : stars == 2
                                ? 'Great work!'
                                : 'You did it!',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (score > 0 && score > _runStartBest) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD166),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('🏆 New best!',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Play again'),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) => TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.grid_view_rounded,
                            color: Colors.white70, size: 20),
                        label: const Text('Back to games',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (status == GameStatus.ready && onStart != null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withOpacity(0.6),
                    accent.withOpacity(0.3),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title.split(' ').first,
                        style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: 8),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(introHow ?? goal,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 1.35)),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () {
                        TonePlayer.instance.playCue(SoundCue.gameStart);
                        onStart();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 14),
                        textStyle: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text('Play'),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) => TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back to games',
                            style: TextStyle(color: Colors.white60)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
    );
  }
}

class _ChoiceRound {
  const _ChoiceRound(this.prompt, this.options, this.answer, {this.colors});

  final String prompt;
  final List<String> options;
  final int answer;
  final List<Color>? colors;
}

typedef _RoundBuilder = _ChoiceRound Function(int round, math.Random random);

class _ChoiceGoalGame extends StatefulWidget {
  const _ChoiceGoalGame({
    required this.id,
    required this.title,
    required this.goal,
    required this.accent,
    required this.background,
    required this.buildRound,
    this.winEmoji,
    this.winTextPool,
  });

  final String id;
  final String title;
  final String goal;
  final Color accent;
  final List<Color> background;
  final _RoundBuilder buildRound;
  // Themed win screen for this specific game; null keeps the shared shell's
  // generic '🎉 Goal complete!' (this game family is no-fail, so there is no
  // lose screen to theme).
  final String? winEmoji;
  // A small pool of themed praise phrases, picked at random the moment the
  // win condition fires — the across-restarts sibling of the arcade win-text
  // variety fix (same lens as the arcade `_winPraisePool` pattern).
  final List<String>? winTextPool;

  @override
  State<_ChoiceGoalGame> createState() => _ChoiceGoalGameState();
}

class _ChoiceGoalGameState extends State<_ChoiceGoalGame> with _GoalEmit {
  static const int _target = 8;
  // Mid-round banner text seen up to 8 times per round, every round, forever
  // — a much higher-frequency repetition than the once-per-playthrough
  // win-screen text fixed in batches 245-248, so a flat single phrase here is
  // the bigger "robotic repetition" gap. Small pools + _random.nextInt() pick
  // keep every wrong/right tap feeling fresh instead of printing the exact
  // same word hundreds of times across a sitting.
  static const List<String> _tryAgainPool = <String>[
    'Try another one',
    'Almost — try again',
    'Not quite, give it a go',
    'Close! Pick again',
  ];
  static const List<String> _correctPool = <String>[
    'Correct!',
    'Nice one!',
    'Well done!',
    'Great pick!',
  ];
  final math.Random _random = math.Random();
  int _score = 0;
  int _best = 0;
  int _roundNumber = 0;
  int _wrong = 0;
  int _streak = 0;
  int _wrongIndex = -1;
  DateTime _shownAt = DateTime.now();
  String? _message;
  String? _winPraise;
  GameStatus _status = GameStatus.ready;
  late _ChoiceRound _round;

  int get _stars => _wrong == 0 ? 3 : (_wrong <= 2 ? 2 : 1);

  @override
  void initState() {
    super.initState();
    _round = widget.buildRound(_roundNumber, _random);
    _shownAt = DateTime.now();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(widget.id));
    });
  }

  void _choose(int index) {
    if (_status != GameStatus.playing) return;
    if (index != _round.answer) {
      setState(() {
        _wrong++;
        _streak = 0;
        _wrongIndex = index;
        _message = _tryAgainPool[_random.nextInt(_tryAgainPool.length)];
      });
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      emit(ExperienceEvent.incorrectAnswer);
      // Same stuck-wrong-flash bug class fixed catalog-wide elsewhere
      // (weather_sort/bigger_number/calm_choices/kindness_match/
      // feelings_match/odd_one_out): without an auto-clear, a missed tile's
      // red border only ever cleared on the NEXT correct answer, so a child
      // who kept missing while hunting for the right tile saw every prior
      // wrong tile stay red the whole time instead of a brief mistake flash.
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && _wrongIndex == index) {
          setState(() => _wrongIndex = -1);
        }
      });
      return;
    }
    TonePlayer.instance.playCue(SoundCue.correct);
    final quick = DateTime.now().difference(_shownAt).inMilliseconds < 2200;
    setState(() {
      _wrongIndex = -1;
      _score++;
      _roundNumber++;
      _streak++;
      _message = quick
          ? 'Quick! ⚡'
          : _streak >= 3
              ? 'Streak x$_streak! 🔥'
              : _correctPool[_random.nextInt(_correctPool.length)];
      if (_score >= _target) {
        final pool = widget.winTextPool;
        if (pool != null && pool.isNotEmpty) {
          _winPraise = pool[_random.nextInt(pool.length)];
        }
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.success);
      } else {
        _round = widget.buildRound(_roundNumber, _random);
        _shownAt = DateTime.now();
      }
    });
    emit(_status == GameStatus.won
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.correctAnswer);
    GameScores.instance.submit(widget.id, _score).then((best) {
      if (mounted && best != _best) setState(() => _best = best);
    });
  }

  void _reset() {
    setState(() {
      _score = 0;
      _roundNumber = 0;
      _wrong = 0;
      _streak = 0;
      _wrongIndex = -1;
      _message = null;
      _status = GameStatus.playing;
      _round = widget.buildRound(_roundNumber, _random);
      _shownAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    return _GoalShell(
      title: widget.title,
      goal: widget.goal,
      introHow: 'Tap the right answer. Get 8 correct to win!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      target: _target,
      best: _best,
      stars: _stars,
      status: _status,
      accent: widget.accent,
      message: _message,
      onReset: _reset,
      winEmoji: widget.winEmoji,
      winText: _winPraise ?? (widget.winTextPool?.isNotEmpty == true ? widget.winTextPool![0] : null),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.background,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 178, 22, 34),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Same scaleDown guard as the tiles below: the prompt is the
                // single largest font in the scene, so without it a raised
                // accessibility text-scale setting could push the grid below
                // the fold on a short/small device (this Column is never
                // scrollable).
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_round.prompt,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                      )),
                ),
                const SizedBox(height: 34),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: _round.options.length,
                  itemBuilder: (context, index) {
                    final swatch =
                        _round.colors != null ? _round.colors![index] : null;
                    final isWrong = index == _wrongIndex;
                    return Semantics(
                      button: true,
                      label: _round.options[index],
                      child: Material(
                        color: swatch ?? Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          key: ValueKey('${widget.id}-option-$index'),
                          onTap: () => _choose(index),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: isWrong
                                  ? Border.all(
                                      color: Colors.redAccent, width: 4)
                                  : (swatch != null
                                      ? Border.all(
                                          color: Colors.white24, width: 2)
                                      : null),
                            ),
                            alignment: Alignment.center,
                            // A pure color swatch with no label is unplayable
                            // for a colorblind child (or any child who simply
                            // can't yet reliably tell e.g. green from orange
                            // apart) even though the prompt above names the
                            // target color in text — the tile itself gave no
                            // text/pattern backup to colour. Always show the
                            // name, with a dark shadow so it stays readable
                            // over every swatch, including the pale yellow.
                            // FittedBox/scaleDown keeps the longest option
                            // words (e.g. "ORANGE"/"PURPLE") on one line and
                            // inside the tile's fixed-aspect-ratio bounds even
                            // when the OS accessibility text-scale setting is
                            // raised (clamped to 1.3x app-wide in app.dart) —
                            // it only ever shrinks, never grows past the
                            // author-intended size, so normal-scale play is
                            // pixel-identical to before this change.
                            child: swatch != null
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: Text(_round.options[index],
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                            shadows: <Shadow>[
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 6,
                                              ),
                                              Shadow(
                                                color: Colors.black54,
                                                offset: Offset(1, 1),
                                              ),
                                            ],
                                          )),
                                    ),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(_round.options[index],
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                        )),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 26),
                // Collection tray — fills with a star for each correct answer,
                // turning "8 correct" into a visible treasure hunt.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (var i = 0; i < _target; i++)
                      TweenAnimationBuilder<double>(
                        key: ValueKey('tray-$i-${i < _score}'),
                        tween: Tween<double>(
                            begin: i < _score ? 1.6 : 1.0, end: 1.0),
                        duration: const Duration(milliseconds: 340),
                        curve: Curves.easeOutBack,
                        builder: (ctx, s, child) =>
                            Transform.scale(scale: s, child: child),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: i < _score
                                ? widget.accent.withOpacity(0.92)
                                : Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          alignment: Alignment.center,
                          child: Text(i < _score ? '⭐' : '',
                              style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ColorQuestGame extends StatelessWidget {
  const ColorQuestGame({super.key});

  static const List<String> _colors = <String>[
    'RED', 'BLUE', 'GREEN', 'YELLOW', 'ORANGE', 'PURPLE'
  ];

  static const Map<String, Color> _swatch = <String, Color>{
    'RED': Color(0xFFE63946),
    'BLUE': Color(0xFF4361EE),
    'GREEN': Color(0xFF2A9D8F),
    'YELLOW': Color(0xFFFFD166),
    'ORANGE': Color(0xFFF77F00),
    'PURPLE': Color(0xFF9B5DE5),
  };

  @override
  Widget build(BuildContext context) => _ChoiceGoalGame(
        id: 'color_quest',
        title: '🎨 Color Quest',
        goal: 'Find the named color · 8 correct answers wins',
        accent: const Color(0xFFFFD166),
        background: const <Color>[Color(0xFF28205A), Color(0xFF111836)],
        winEmoji: '🎨',
        winTextPool: const <String>[
          'Color Quest complete!', 'Color champion!', 'Rainbow master!', 'Great colors!',
        ],
        buildRound: (round, random) {
          // Flat 4-of-6 choices every round of every playthrough gave round 1
          // and round 8 the exact same odds — a genuine difficulty-curve gap
          // (the same class already fixed catalog-wide: kindness_match's
          // 3->4 distractor growth, sorting_train's 3->6 wagon growth).
          // Grows the choice set from 3 up to the full 6-colour pool as the
          // round count climbs toward the 8-correct target, narrowing the
          // odds of a lucky guess without changing the colours/names shown.
          final optionCount =
              (3 + round ~/ 3).clamp(3, _colors.length);
          final choices = List<String>.of(_colors)..shuffle(random);
          final options = choices.take(optionCount).toList();
          final answer = random.nextInt(optionCount);
          return _ChoiceRound('Tap ${options[answer]}', options, answer,
              colors: <Color>[for (final o in options) _swatch[o]!]);
        },
      );
}

class ShapeScoutGame extends StatelessWidget {
  const ShapeScoutGame({super.key});

  static const List<String> _shapes = <String>[
    '●', '■', '▲', '◆', '★', '♥', '♠', '♣'
  ];

  @override
  Widget build(BuildContext context) => _ChoiceGoalGame(
        id: 'shape_scout',
        title: '🔷 Shape Scout',
        goal: 'Match the shape shown above · 8 matches wins',
        accent: const Color(0xFF4CC9F0),
        background: const <Color>[Color(0xFF123A52), Color(0xFF081D2E)],
        winEmoji: '🔷',
        winTextPool: const <String>[
          'Shape Scout champion!', 'Shape master!', 'Great matching!', 'Sharp eyes!',
        ],
        buildRound: (round, random) {
          // Same flat-4-choices difficulty-curve gap fixed in ColorQuestGame
          // above — grows from 3 up to the full 8-shape pool as the round
          // count climbs toward the 8-correct target.
          final optionCount =
              (3 + round ~/ 3).clamp(3, _shapes.length);
          final choices = List<String>.of(_shapes)..shuffle(random);
          final options = choices.take(optionCount).toList();
          final answer = random.nextInt(optionCount);
          return _ChoiceRound('Match  ${options[answer]}', options, answer);
        },
      );
}

class NumberSplashGame extends StatelessWidget {
  const NumberSplashGame({super.key});

  @override
  Widget build(BuildContext context) => _ChoiceGoalGame(
        id: 'number_splash',
        title: '➕ Number Splash',
        goal: 'Solve the sum · 8 correct answers wins',
        accent: const Color(0xFF43E97B),
        background: const <Color>[Color(0xFF174D3A), Color(0xFF092A28)],
        winEmoji: '➕',
        winTextPool: const <String>[
          'Number Splash master!', 'Math whiz!', 'Number star!', 'Great counting!',
        ],
        buildRound: (round, random) {
          final hi = 5 + round ~/ 3;
          final a = 1 + random.nextInt(hi);
          final b = 1 + random.nextInt(hi);
          // Subtraction starts appearing once the child is warmed up.
          final sub = round >= 3 && random.nextBool();
          final left = sub ? math.max(a, b) : a;
          final right = sub ? math.min(a, b) : b;
          final answer = sub ? left - right : left + right;
          final op = sub ? '−' : '+';
          final values = <int>{answer};
          while (values.length < 4) {
            values.add(math.max(0, answer + random.nextInt(7) - 3));
          }
          final options = values.map((value) => '$value').toList()
            ..shuffle(random);
          return _ChoiceRound(
              '$left $op $right = ?', options, options.indexOf('$answer'));
        },
      );
}

class PathFinderGame extends StatefulWidget {
  const PathFinderGame({super.key});

  @override
  State<PathFinderGame> createState() => _PathFinderGameState();
}

class _PathFinderGameState extends State<PathFinderGame> with _GoalEmit {
  static const String _id = 'path_finder';
  final math.Random _rnd = math.Random();
  List<int> _path = <int>[];
  int _level = 0;
  int _step = 0;
  int _best = 0;
  String? _message;
  GameStatus _status = GameStatus.ready;
  static const List<String> _winPraisePool = <String>[
    'Treasure found!', 'Path master!', 'Maze champion!', 'Great navigating!',
  ];
  String _winPraise = _winPraisePool[0];
  // Every correct step (up to 16 per round) flashed the exact same flat
  // 'Keep going!' literal — the same robotic-repetition gap already fixed
  // catalog-wide elsewhere (e.g. _ChoiceGoalGameState's _correctPool above).
  // A small pool + _rnd pick keeps each step feeling distinct.
  static const List<String> _stepPraisePool = <String>[
    'Keep going!', 'Nice step!', 'On track!', 'Great eye!',
  ];

  @override
  void initState() {
    super.initState();
    _path = _makePath(_pathLenFor(_level));
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int _pathLenFor(int level) => math.min(16, 9 + level);

  // Self-avoiding random walk on the 5x5 grid (orthogonal steps only), so
  // every game is a brand-new maze instead of one memorised fixed route.
  List<int> _makePath(int length) {
    while (true) {
      final visited = <int>{};
      final path = <int>[_rnd.nextInt(25)];
      visited.add(path.first);
      var stuck = false;
      while (path.length < length) {
        final cur = path.last;
        final r = cur ~/ 5, c = cur % 5;
        final next = <int>[];
        for (final d in const <List<int>>[
          [-1, 0], [1, 0], [0, -1], [0, 1]
        ]) {
          final nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr >= 5 || nc < 0 || nc >= 5) continue;
          final cell = nr * 5 + nc;
          if (!visited.contains(cell)) next.add(cell);
        }
        if (next.isEmpty) {
          stuck = true;
          break;
        }
        final pick = next[_rnd.nextInt(next.length)];
        path.add(pick);
        visited.add(pick);
      }
      if (!stuck) return path;
    }
  }

  void _tap(int cell) {
    if (_status != GameStatus.playing) return;
    if (cell != _path[_step]) {
      setState(() => _message = 'Follow the glowing next step');
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      // Every sibling goal-shell game (_ChoiceGoalGame, GoalKeeperGame) pairs
      // a wrong-tap sound with an incorrectAnswer companion emit so Hari/Pico
      // can offer a contextual encouragement; Path Finder's off-path tap only
      // ever played the sound, leaving the companion silent on every mistake.
      emit(ExperienceEvent.incorrectAnswer);
      return;
    }
    setState(() {
      _step++;
      _message = _step == _path.length
          ? 'Treasure found!'
          : _stepPraisePool[_rnd.nextInt(_stepPraisePool.length)];
      if (_step == _path.length) {
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        _status = GameStatus.won;
        _level++;
      }
    });
    TonePlayer.instance.playCue(
        _status == GameStatus.won ? SoundCue.success : SoundCue.correct);
    emit(_status == GameStatus.won
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.correctAnswer);
    GameScores.instance.submit(_id, _step).then((best) {
      if (mounted && best != _best) setState(() => _best = best);
    });
  }

  void _reset() => setState(() {
        _path = _makePath(_pathLenFor(_level));
        _step = 0;
        _message = null;
        _status = GameStatus.playing;
      });

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    return _GoalShell(
      title: '🗺️ Path Finder',
      goal: 'Start at the flag · Follow the glowing path to the treasure',
      introHow: 'Tap each glowing tile to trace a path to the treasure!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _step,
      target: _path.length,
      best: _best,
      status: _status,
      accent: const Color(0xFFFFD166),
      message: _message,
      onReset: _reset,
      winEmoji: '🗺️',
      winText: _winPraise,
      child: ColoredBox(
        color: const Color(0xFF10283A),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 180, 24, 48),
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 7,
                  ),
                  itemCount: 25,
                  itemBuilder: (context, cell) {
                    final completed = _path.take(_step).contains(cell);
                    final next = _step < _path.length && _path[_step] == cell;
                    final onPath = _path.contains(cell);
                    return Semantics(
                      button: true,
                      label: next ? 'Next path step' : 'Maze cell',
                      child: InkWell(
                        key: ValueKey('path-cell-$cell'),
                        onTap: () => _tap(cell),
                        borderRadius: BorderRadius.circular(12),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('pf-$cell-$completed'),
                          tween: Tween<double>(
                              begin: completed ? 1.3 : 1.0, end: 1.0),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutBack,
                          builder: (ctx, s, child) =>
                              Transform.scale(scale: s, child: child),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: completed
                                  ? const Color(0xFF43E97B)
                                  : next
                                      ? const Color(0xFFFFD166)
                                      : onPath
                                          ? Colors.white.withOpacity(0.13)
                                          : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: next
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              cell == _path.first
                                  ? '🚩'
                                  : cell == _path.last
                                      ? '🎁'
                                      : next
                                          ? '•'
                                          : '',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoalKeeperGame extends StatefulWidget {
  const GoalKeeperGame({super.key});

  @override
  State<GoalKeeperGame> createState() => _GoalKeeperGameState();
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.color) : life = 0.5;
  double x, y, vx, vy;
  final Color color;
  double life;
}

class _GoalKeeperGameState extends State<GoalKeeperGame>
    with TickerProviderStateMixin, ToyTicker, _GoalEmit {
  static const String _id = 'goal_keeper';
  static const int _target = 10;
  // Goal mouth + keeper plane, in normalised canvas space.
  static const double _goalLeft = 0.14;
  static const double _goalRight = 0.86;
  static const double _lineY = 0.34; // where the keeper stands
  static const double _spotY = 0.88; // penalty spot
  // How far the keeper's dive covers. Matches the painter's actual glove
  // span (armSpan 0.12 + glove radius 0.03 = 0.15 from the keeper's centre)
  // so a save that visibly shows glove-on-ball always registers as a save
  // instead of a child seeing contact and still being told "Goal in!".
  static const double _reach = 0.15;
  // Every non-streak save (up to 10 per playthrough) flashed the exact same
  // "SAVE! 🧤" banner — the same flat mid-round repetition gap fixed in
  // _ChoiceGoalGameState above. A small pool + _random pick keeps each save
  // feeling distinct instead of printing one identical word every time.
  static const List<String> _savePool = <String>[
    'SAVE! 🧤',
    'Great dive! 🧤',
    'Keeper ball! 🧤',
    'Shut out! 🧤',
  ];
  double _kMin = _goalLeft + 0.05;
  double _kMax = _goalRight - 0.05;

  final math.Random _random = math.Random();
  final List<_Spark> _sparks = <_Spark>[];
  bool _reduceMotion = false;
  // Pool of win phrases so a replaying child doesn't always see the same
  // "Saved the match!" line on win screen (across-restarts sibling of the
  // per-round praise-variety fixes applied elsewhere this sprint).
  static const List<String> _winPraisePool = <String>[
    'Saved the match!',
    'Golden gloves!',
    'Shutout hero!',
    'Wall between the posts!',
  ];
  String _winPraise = _winPraisePool[0];
  // Goal Keeper has the same shape as balloon_bounce/sky_hop/whack: a fixed
  // win target (10 saves) reached by a slowly climbing score, but a single
  // missed dive costs a life and 5 missed dives ends the run well short of
  // the target — so most playthroughs never see the win screen at all. The
  // identical live "beat your own all-time best" celebration belongs here
  // too, not just on the eventual win/over screen.
  bool _beatBest = false;

  double _keeperX = 0.5;
  double _keeperTargetX = 0.5;
  double _lean = 0; // -1..1 dive lean for the keeper

  Offset _ballPos = const Offset(0.5, _spotY);
  double _ballTargetX = 0.5;
  double _curve = 0; // mid-flight deception
  double _flightT = 0;
  double _flightDur = 1.7;
  double _ballScale = 0.4;

  int _phase = 0; // 0 = between shots, 1 = flying, 2 = result flash
  double _phaseT = 0;
  bool _lastSaved = false;

  int _score = 0; // saves
  int _lives = 5;
  int _streak = 0;
  int _shotNum = 0;
  int _best = 0;
  String? _message;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _begin() {
    _score = 0;
    _lives = 5;
    _streak = 0;
    _shotNum = 0;
    _keeperX = 0.5;
    _keeperTargetX = 0.5;
    _sparks.clear();
    _beatBest = false;
    _message = 'Read the shot — slide to save!';
    _startShot();
  }

  void _startShot() {
    _shotNum++;
    _phase = 1;
    _flightT = 0;
    _ballPos = const Offset(0.5, _spotY);
    _ballScale = 0.4;
    if (_shotNum == 1) {
      // Gentle first shot: straight down the middle so the child learns.
      _ballTargetX = 0.5;
      _curve = 0;
      _flightDur = 1.8;
    } else {
      _ballTargetX =
          _kMin + 0.02 + _random.nextDouble() * (_kMax - _kMin - 0.04);
      // Curve grows with score so reading the ball gets trickier.
      final curveChance = math.min(0.6, 0.12 + _score * 0.05);
      _curve = _random.nextDouble() < curveChance
          ? (_random.nextBool() ? 1 : -1) *
              (0.08 + _random.nextDouble() * 0.12)
          : 0;
      _flightDur = math.max(0.82, 1.7 - _score * 0.085);
    }
  }

  void _burst(double x, double y, Color color, int n, double speed) {
    final count = _reduceMotion ? math.max(3, n ~/ 3) : n;
    for (var i = 0; i < count; i++) {
      final a = _random.nextDouble() * math.pi * 2;
      final sp = speed * (0.4 + _random.nextDouble());
      _sparks.add(_Spark(
          x, y, math.cos(a) * sp, math.sin(a) * sp, color));
    }
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    // Keeper glides toward the finger.
    _keeperX += (_keeperTargetX - _keeperX) * math.min(1, dt * 13);
    _keeperX = _keeperX.clamp(_kMin, _kMax);
    for (var i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 0.4 * dt;
      s.life -= dt;
      if (s.life <= 0) _sparks.removeAt(i);
    }

    if (_phase == 1) {
      _flightT += dt / _flightDur;
      final t = _flightT.clamp(0.0, 1.0);
      final ease = t * t; // accelerate toward the goal
      final bx = _lerp(0.5, _ballTargetX, t) + _curve * math.sin(math.pi * t);
      final by = _lerp(_spotY, _lineY, ease);
      _ballPos = Offset(bx, by);
      _ballScale = 0.4 + t * 0.9;
      // Keeper leans toward the incoming ball as it nears.
      final want = ((bx - _keeperX) / _reach).clamp(-1.0, 1.0);
      _lean += (want * t - _lean) * math.min(1, dt * 8);
      if (_flightT >= 1) _resolveShot();
    } else if (_phase == 2) {
      _phaseT -= dt;
      _lean *= (1 - math.min(1, dt * 4));
      if (_phaseT <= 0 && _status == GameStatus.playing) _startShot();
    }
  }

  void _resolveShot() {
    final dist = (_ballTargetX - _keeperX).abs();
    if (dist <= _reach) {
      _score++;
      _streak++;
      _lastSaved = true;
      _message = _streak >= 3 ? 'SAVE! Streak x$_streak 🧤' : _savePool[_random.nextInt(_savePool.length)];
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.correctAnswer);
      _burst(_keeperX, _lineY, const Color(0xFFFFE066), 14, 0.5);
      // Deflect the ball away from goal.
      _ballPos = Offset(_keeperX, _lineY);
      if (_score >= _target) {
        _finish(GameStatus.won);
        return;
      } else if (!_beatBest && _best > 0 && _score > _best) {
        _beatBest = true;
        // Takes priority over the streak/save banner just set above — a new
        // all-time record is the bigger moment of the two.
        _message = 'New personal best! 🏆';
        TonePlayer.instance.playCue(SoundCue.milestone);
        emit(ExperienceEvent.personalBest);
      }
    } else {
      _lives--;
      _streak = 0;
      _lastSaved = false;
      // Remaining lives are a keeper's gloves, not soccer balls — a ⚽ here
      // reads as "goals scored", the opposite of what this stat means, right
      // in the same breath as "Goal in!". Match the glove used by the
      // "SAVE! 🧤" message so the icon matches what the stat represents.
      _message = 'Goal in! Lives ${'🧤' * _lives}${'·' * (5 - _lives)}';
      TonePlayer.instance.playCue(SoundCue.crash);
      emit(ExperienceEvent.incorrectAnswer);
      _burst(_ballTargetX, _lineY, const Color(0xFFEF476F), 10, 0.35);
      _ballPos = Offset(_ballTargetX, _lineY + 0.04);
      if (_lives <= 0) {
        _finish(GameStatus.over);
        return;
      }
    }
    _phase = 2;
    _phaseT = 0.85;
    _submit();
  }

  void _submit() {
    GameScores.instance.submit(_id, _score).then((best) {
      if (mounted && best != _best) setState(() => _best = best);
    });
  }

  void _finish(GameStatus status) {
    _phase = 2;
    _status = status;
    if (status == GameStatus.won) {
      _winPraise = _winPraisePool[_random.nextInt(_winPraisePool.length)];
    }
    _submit();
    TonePlayer.instance.playCue(
        status == GameStatus.won ? SoundCue.success : SoundCue.gameOver);
    if (status == GameStatus.won) emit(ExperienceEvent.gameCompleted);
  }

  void _moveTo(double localX, double width) {
    if (_status != GameStatus.playing) return;
    _keeperTargetX = (localX / width).clamp(_kMin, _kMax);
  }

  // Screen-reader bridge: dives straight to the shot's real target x, the
  // same number the sighted `aimHint` overlay already reveals for the first
  // three saves. The keeper still eases toward it at the same speed as a
  // sighted drag (see `onTick`'s lerp), so this is a faithful stand-in for
  // "slide under the ball" rather than an auto-win.
  void _diveToTarget() {
    if (_status != GameStatus.playing) return;
    _keeperTargetX = _ballTargetX.clamp(_kMin, _kMax);
  }

  void _reset() => setState(() {
        _status = GameStatus.playing;
        _begin();
      });

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _GoalShell(
      title: '🥅 Goal Keeper',
      goal: 'Read the shot, slide and dive · Make 10 saves',
      introHow:
          'A ball is kicked at your goal — slide left/right to get your gloves in its path and save it! You have 5 lives, so don\u2019t let too many past.',
      onStart: () => setState(() {
        _status = GameStatus.playing;
        _begin();
      }),
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      accent: const Color(0xFFFFD166),
      message: _message ?? 'Lives ${'🧤' * _lives}${'·' * (5 - _lives)}',
      onReset: _reset,
      winEmoji: '🧤',
      winText: _winPraise,
      overEmoji: '🥅',
      overText: 'Out of lives!',
      child: LayoutBuilder(
        builder: (context, c) {
          return Semantics(
            button: true,
            label: 'Saves $_score of $_target. Dive to the ball\'s path.',
            onTap: _diveToTarget,
            excludeSemantics: true,
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _moveTo(d.localPosition.dx, c.maxWidth),
            onPanDown: (d) => _moveTo(d.localPosition.dx, c.maxWidth),
            onPanUpdate: (d) => _moveTo(d.localPosition.dx, c.maxWidth),
            child: CustomPaint(
              painter: _KeeperPainter(
                keeperX: _keeperX,
                lean: _lean,
                ball: _ballPos,
                ballScale: _ballScale,
                phase: _phase,
                lastSaved: _lastSaved,
                sparks: _sparks,
                aimHint: _score < 3 && _phase == 1 ? _ballTargetX : -1,
                phaseT: _phaseT,
              ),
              size: Size.infinite,
            ),
            // A hidden hit target keeps the old save affordance working for
            // tests and for taps near the keeper.
            ),
          );
        },
      ),
    );
  }
}

class _KeeperPainter extends CustomPainter {
  _KeeperPainter({
    required this.keeperX,
    required this.lean,
    required this.ball,
    required this.ballScale,
    required this.phase,
    required this.lastSaved,
    required this.sparks,
    required this.aimHint,
    required this.phaseT,
  });
  final double keeperX;
  final double lean;
  final Offset ball;
  final double ballScale;
  final int phase;
  final bool lastSaved;
  final List<_Spark> sparks;
  final double aimHint;
  // Countdown from 0.85s set when a shot resolves (see _resolveShot); used to
  // fade the save/goal result flash in then out instead of either snapping
  // on and off or — before this fix — never using `lastSaved` at all.
  final double phaseT;

  static const double _goalLeft = 0.14;
  static const double _goalRight = 0.86;
  static const double _crossbarY = 0.12;
  static const double _lineY = 0.34;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double sx(double x) => x * w;
    double sy(double y) => y * h;

    // Pitch.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1E8A5C), Color(0xFF0C3E2B)],
          ).createShader(Offset.zero & size));
    // Mown stripes.
    for (var i = 0; i < 6; i++) {
      if (i.isEven) continue;
      canvas.drawRect(
          Rect.fromLTWH(0, sy(0.36) + i * h * 0.1, w, h * 0.1),
          Paint()..color = Colors.white.withOpacity(0.03));
    }

    // Result flash — fades in then out across the 0.85s pause after a shot
    // resolves. `lastSaved` used to be computed and threaded all the way to
    // this painter but never actually read here, so a save and a goal looked
    // visually identical except for the text banner; this gives each a
    // distinct, satisfying payoff a child can see at a glance.
    final resultFlash =
        phase == 2 ? (phaseT / 0.85).clamp(0.0, 1.0) : 0.0;
    final netRippleOn = phase == 2 && !lastSaved && resultFlash > 0;
    final rippleX = sx(ball.dx);

    // Goal net.
    final netRect = Rect.fromLTRB(sx(_goalLeft), sy(_crossbarY),
        sx(_goalRight), sy(_lineY));
    final net = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..strokeWidth = 1;
    for (var gx = 0; gx <= 10; gx++) {
      final x = netRect.left + netRect.width * gx / 10;
      // On a goal, bulge the net cords outward near where the ball crossed
      // the line — the bottom of each cord shifts, the top (fixed to the
      // crossbar) doesn't, so the net reads as genuinely pushed by impact.
      var bottomShift = 0.0;
      if (netRippleOn) {
        final d = (x - rippleX) / (w * 0.12);
        bottomShift = math.exp(-d * d) * w * 0.035 * resultFlash;
      }
      canvas.drawLine(Offset(x, netRect.top),
          Offset(x + bottomShift, netRect.bottom), net);
    }
    for (var gy = 0; gy <= 5; gy++) {
      final y = netRect.top + netRect.height * gy / 5;
      canvas.drawLine(Offset(netRect.left, y), Offset(netRect.right, y), net);
    }
    // Posts + crossbar.
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(sx(_goalLeft), sy(_crossbarY)),
        Offset(sx(_goalLeft), sy(_lineY)), post);
    canvas.drawLine(Offset(sx(_goalRight), sy(_crossbarY)),
        Offset(sx(_goalRight), sy(_lineY)), post);
    canvas.drawLine(Offset(sx(_goalLeft), sy(_crossbarY)),
        Offset(sx(_goalRight), sy(_crossbarY)), post);

    // Aim hint (early shots) — a pulsing target the child learns to read.
    if (aimHint >= 0) {
      canvas.drawCircle(
          Offset(sx(aimHint), sy(_lineY)),
          w * 0.045,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFFE066).withOpacity(0.7));
    }

    // Penalty spot + ball shadow.
    canvas.drawCircle(Offset(sx(0.5), sy(0.88)), 4,
        Paint()..color = Colors.white.withOpacity(0.7));
    final ballR = w * 0.03 * ballScale;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(sx(ball.dx), sy(ball.dy) + ballR * 0.9),
            width: ballR * 1.8,
            height: ballR * 0.7),
        Paint()..color = Colors.black.withOpacity(0.22));

    // Keeper — body + outstretched gloves, leaning into the dive.
    final kx = sx(keeperX);
    final ky = sy(_lineY);
    final lean = this.lean.clamp(-1.0, 1.0);
    final armSpan = w * 0.12;
    final bodyPaint = Paint()..color = const Color(0xFF2D6CDF);
    canvas.save();
    canvas.translate(kx, ky);
    canvas.rotate(lean * 0.5);
    // Torso.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: const Offset(0, 0),
                width: w * 0.07,
                height: h * 0.09),
            const Radius.circular(10)),
        bodyPaint);
    // Head.
    canvas.drawCircle(
        Offset(0, -h * 0.065), w * 0.028, Paint()..color = const Color(0xFFFFCDA8));
    // Arms + gloves.
    final glove = Paint()..color = const Color(0xFFFFE066);
    canvas.drawLine(
        const Offset(0, -6),
        Offset(-armSpan, -h * 0.02),
        Paint()
          ..color = bodyPaint.color
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        const Offset(0, -6),
        Offset(armSpan, -h * 0.02),
        Paint()
          ..color = bodyPaint.color
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(-armSpan, -h * 0.02), w * 0.03, glove);
    canvas.drawCircle(Offset(armSpan, -h * 0.02), w * 0.03, glove);
    canvas.restore();

    // The ball itself.
    final bc = Offset(sx(ball.dx), sy(ball.dy));
    canvas.drawCircle(bc, ballR, Paint()..color = Colors.white);
    canvas.drawCircle(bc, ballR, Paint()..color = Colors.black12);
    for (var i = 0; i < 5; i++) {
      final a = i / 5 * math.pi * 2 - math.pi / 2;
      canvas.drawCircle(
          bc + Offset(math.cos(a), math.sin(a)) * ballR * 0.5,
          ballR * 0.22,
          Paint()..color = Colors.black87);
    }

    // Save glow — an expanding, fading golden ring around the ball right
    // where the glove met it, so "SAVE!" has a clear visual payoff distinct
    // from a goal, instead of only differing by particle colour + text.
    if (phase == 2 && lastSaved && resultFlash > 0) {
      canvas.drawCircle(
          bc,
          ballR * (1.7 + (1 - resultFlash) * 1.6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFFE066).withOpacity(0.85 * resultFlash));
    }

    // Sparks.
    for (final s in sparks) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(sx(s.x), sy(s.y)),
          3 + 3 * k,
          Paint()
            ..color = s.color.withOpacity(k)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  @override
  bool shouldRepaint(_KeeperPainter old) => true;
}