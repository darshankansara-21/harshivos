import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/tone_player.dart';
import 'mini_games.dart' show GameScores, GameStatus;

class _GoalShell extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                  Container(
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (status != GameStatus.playing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(0.72),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(status == GameStatus.won ? '🎉' : '💪',
                        style: const TextStyle(fontSize: 70)),
                    const SizedBox(height: 8),
                    Text(
                      status == GameStatus.won ? 'Goal complete!' : 'Good try!',
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
      ],
    );
  }
}

class _ChoiceRound {
  const _ChoiceRound(this.prompt, this.options, this.answer);

  final String prompt;
  final List<String> options;
  final int answer;
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
  });

  final String id;
  final String title;
  final String goal;
  final Color accent;
  final List<Color> background;
  final _RoundBuilder buildRound;

  @override
  State<_ChoiceGoalGame> createState() => _ChoiceGoalGameState();
}

class _ChoiceGoalGameState extends State<_ChoiceGoalGame> {
  static const int _target = 8;
  final math.Random _random = math.Random();
  int _score = 0;
  int _best = 0;
  int _roundNumber = 0;
  int _wrong = 0;
  int _streak = 0;
  String? _message;
  GameStatus _status = GameStatus.playing;
  late _ChoiceRound _round;

  int get _stars => _wrong == 0 ? 3 : (_wrong <= 2 ? 2 : 1);

  @override
  void initState() {
    super.initState();
    _round = widget.buildRound(_roundNumber, _random);
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
        _message = 'Try another one';
      });
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      return;
    }
    TonePlayer.instance.playCue(SoundCue.correct);
    setState(() {
      _score++;
      _roundNumber++;
      _streak++;
      _message = _streak >= 3 ? 'Streak x$_streak! 🔥' : 'Correct!';
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.success);
      } else {
        _round = widget.buildRound(_roundNumber, _random);
      }
    });
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
      _message = null;
      _status = GameStatus.playing;
      _round = widget.buildRound(_roundNumber, _random);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _GoalShell(
      title: widget.title,
      goal: widget.goal,
      score: _score,
      target: _target,
      best: _best,
      stars: _stars,
      status: _status,
      accent: widget.accent,
      message: _message,
      onReset: _reset,
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
                Text(_round.prompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    )),
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
                  itemBuilder: (context, index) => Semantics(
                    button: true,
                    label: _round.options[index],
                    child: Material(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        key: ValueKey('${widget.id}-option-$index'),
                        onTap: () => _choose(index),
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: Text(_round.options[index],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              )),
                        ),
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

class ColorQuestGame extends StatelessWidget {
  const ColorQuestGame({super.key});

  static const List<String> _colors = <String>[
    'RED', 'BLUE', 'GREEN', 'YELLOW', 'ORANGE', 'PURPLE'
  ];

  @override
  Widget build(BuildContext context) => _ChoiceGoalGame(
        id: 'color_quest',
        title: '🎨 Color Quest',
        goal: 'Find the named color · 8 correct answers wins',
        accent: const Color(0xFFFFD166),
        background: const <Color>[Color(0xFF28205A), Color(0xFF111836)],
        buildRound: (round, random) {
          final answer = random.nextInt(4);
          final choices = List<String>.of(_colors)..shuffle(random);
          final options = choices.take(4).toList();
          return _ChoiceRound('Find ${options[answer]}', options, answer);
        },
      );
}

class ShapeScoutGame extends StatelessWidget {
  const ShapeScoutGame({super.key});

  static const List<String> _shapes = <String>['●', '■', '▲', '◆'];

  @override
  Widget build(BuildContext context) => _ChoiceGoalGame(
        id: 'shape_scout',
        title: '🔷 Shape Scout',
        goal: 'Match the shape shown above · 8 matches wins',
        accent: const Color(0xFF4CC9F0),
        background: const <Color>[Color(0xFF123A52), Color(0xFF081D2E)],
        buildRound: (round, random) {
          final options = List<String>.of(_shapes)..shuffle(random);
          final answer = random.nextInt(options.length);
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
        buildRound: (round, random) {
          final left = 1 + random.nextInt(5 + round ~/ 3);
          final right = 1 + random.nextInt(5 + round ~/ 3);
          final sum = left + right;
          final values = <int>{sum};
          while (values.length < 4) {
            values.add(math.max(1, sum + random.nextInt(7) - 3));
          }
          final options = values.map((value) => '$value').toList()
            ..shuffle(random);
          return _ChoiceRound(
              '$left + $right = ?', options, options.indexOf('$sum'));
        },
      );
}

class PathFinderGame extends StatefulWidget {
  const PathFinderGame({super.key});

  @override
  State<PathFinderGame> createState() => _PathFinderGameState();
}

class _PathFinderGameState extends State<PathFinderGame> {
  static const String _id = 'path_finder';
  static const List<int> _path = <int>[20, 15, 16, 11, 6, 7, 8, 3, 4];
  int _step = 0;
  int _best = 0;
  String? _message;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _tap(int cell) {
    if (_status != GameStatus.playing) return;
    if (cell != _path[_step]) {
      setState(() => _message = 'Follow the glowing next step');
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      return;
    }
    setState(() {
      _step++;
      _message = _step == _path.length ? 'Treasure found!' : 'Keep going!';
      if (_step == _path.length) _status = GameStatus.won;
    });
    TonePlayer.instance.playCue(
        _status == GameStatus.won ? SoundCue.success : SoundCue.correct);
    GameScores.instance.submit(_id, _step).then((best) {
      if (mounted && best != _best) setState(() => _best = best);
    });
  }

  void _reset() => setState(() {
        _step = 0;
        _message = null;
        _status = GameStatus.playing;
      });

  @override
  Widget build(BuildContext context) {
    return _GoalShell(
      title: '🗺️ Path Finder',
      goal: 'Start at the flag · Follow the glowing path to the treasure',
      score: _step,
      target: _path.length,
      best: _best,
      status: _status,
      accent: const Color(0xFFFFD166),
      message: _message,
      onReset: _reset,
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

class _GoalKeeperGameState extends State<GoalKeeperGame>
    with TickerProviderStateMixin, ToyTicker {
  static const String _id = 'goal_keeper';
  static const int _target = 10;
  final math.Random _random = math.Random();
  int _activeLane = 1;
  int _score = 0;
  int _best = 0;
  int _lives = 3;
  int _streak = 0;
  double _timeLeft = 1.8;
  double _shotDuration = 1.8;
  String? _message;
  GameStatus _status = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _timeLeft -= dt;
    if (_timeLeft <= 0) {
      _lives--;
      _streak = 0;
      _message = 'Missed! Watch the glowing goal';
      if (_lives <= 0) {
        _finish(GameStatus.over);
      } else {
        _nextShot();
      }
    }
  }

  void _save(int score) {
    GameScores.instance.submit(_id, score).then((best) {
      if (mounted && best != _best) setState(() => _best = best);
    });
  }

  void _finish(GameStatus status) {
    _status = status;
    _save(_score);
    TonePlayer.instance.playCue(
        status == GameStatus.won ? SoundCue.success : SoundCue.gameOver);
  }

  void _nextShot() {
    var next = _random.nextInt(3);
    if (next == _activeLane) next = (next + 1) % 3;
    _activeLane = next;
    _shotDuration = math.max(0.75, 1.8 - _score * 0.07);
    _timeLeft = _shotDuration;
  }

  void _block(int lane) {
    if (_status != GameStatus.playing) return;
    if (lane != _activeLane) {
      setState(() => _message = 'Move to the glowing goal');
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      return;
    }
    setState(() {
      _score++;
      _streak++;
      _message = _streak >= 3 ? 'Streak x$_streak! \ud83e\udde4' : 'Saved!';
      if (_score >= _target) {
        _finish(GameStatus.won);
      } else {
        _nextShot();
      }
    });
    if (_status == GameStatus.playing) {
      TonePlayer.instance.playCue(SoundCue.ball);
      _save(_score);
    }
  }

  void _reset() => setState(() {
        _activeLane = 1;
        _score = 0;
        _lives = 3;
        _streak = 0;
        _timeLeft = 1.8;
        _shotDuration = 1.8;
        _message = null;
        _status = GameStatus.playing;
      });

  @override
  Widget build(BuildContext context) {
    return _GoalShell(
      title: '🥅 Goal Keeper',
      goal: 'Tap the glowing goal before the ball arrives · Make 10 saves',
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      accent: const Color(0xFFFFD166),
      message: _message ?? 'Lives ${'●' * _lives}${'○' * (3 - _lives)}',
      onReset: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF12614A), Color(0xFF073527)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 190, 18, 54),
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_timeLeft / _shotDuration).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _timeLeft / _shotDuration < 0.35
                          ? const Color(0xFFEF476F)
                          : const Color(0xFFFFD166),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      for (var lane = 0; lane < 3; lane++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Semantics(
                              button: true,
                              label: 'Goal ${lane + 1}',
                              child: InkWell(
                                key: ValueKey('goal-lane-$lane'),
                                onTap: () => _block(lane),
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  decoration: BoxDecoration(
                                    color: lane == _activeLane
                                        ? const Color(0xFFFFD166)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: lane == _activeLane
                                          ? Colors.white
                                          : Colors.white24,
                                      width: lane == _activeLane ? 4 : 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                      lane == _activeLane ? '⚽' : '🥅',
                                      style: const TextStyle(fontSize: 40)),
                                ),
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