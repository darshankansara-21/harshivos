import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/game_music_host.dart';
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
    this.introHow,
    this.onStart,
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

  @override
  Widget build(BuildContext context) {
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
        if (status == GameStatus.won || status == GameStatus.over)
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
                        onStart!();
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
  int _wrongIndex = -1;
  String? _message;
  GameStatus _status = GameStatus.ready;
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
        _wrongIndex = index;
        _message = 'Try another one';
      });
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      return;
    }
    TonePlayer.instance.playCue(SoundCue.correct);
    setState(() {
      _wrongIndex = -1;
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
      _wrongIndex = -1;
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
                            child: swatch != null
                                ? const SizedBox.shrink()
                                : Text(_round.options[index],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                    )),
                          ),
                        ),
                      ),
                    );
                  },
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
        buildRound: (round, random) {
          final choices = List<String>.of(_colors)..shuffle(random);
          final options = choices.take(4).toList();
          final answer = random.nextInt(4);
          return _ChoiceRound('Tap ${options[answer]}', options, answer,
              colors: <Color>[for (final o in options) _swatch[o]!]);
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
  GameStatus _status = GameStatus.ready;

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
      introHow: 'Tap each glowing tile to trace a path to the treasure!',
      onStart: () => setState(() => _status = GameStatus.playing),
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
    with TickerProviderStateMixin, ToyTicker {
  static const String _id = 'goal_keeper';
  static const int _target = 10;
  // Goal mouth + keeper plane, in normalised canvas space.
  static const double _goalLeft = 0.14;
  static const double _goalRight = 0.86;
  static const double _crossbarY = 0.12;
  static const double _lineY = 0.34; // where the keeper stands
  static const double _spotY = 0.88; // penalty spot
  static const double _reach = 0.135; // how far the keeper's dive covers
  double _kMin = _goalLeft + 0.05;
  double _kMax = _goalRight - 0.05;

  final math.Random _random = math.Random();
  final List<_Spark> _sparks = <_Spark>[];

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
  int _conceded = 0;
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
    _conceded = 0;
    _lives = 5;
    _streak = 0;
    _shotNum = 0;
    _keeperX = 0.5;
    _keeperTargetX = 0.5;
    _sparks.clear();
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
    for (var i = 0; i < n; i++) {
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
      _message = _streak >= 3 ? 'SAVE! Streak x$_streak 🧤' : 'SAVE! 🧤';
      TonePlayer.instance.playCue(SoundCue.success);
      _burst(_keeperX, _lineY, const Color(0xFFFFE066), 14, 0.5);
      // Deflect the ball away from goal.
      _ballPos = Offset(_keeperX, _lineY);
      if (_score >= _target) {
        _finish(GameStatus.won);
        return;
      }
    } else {
      _conceded++;
      _lives--;
      _streak = 0;
      _lastSaved = false;
      _message = 'Goal in! Lives ${'⚽' * _lives}${'·' * (5 - _lives)}';
      TonePlayer.instance.playCue(SoundCue.crash);
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
    _submit();
    TonePlayer.instance.playCue(
        status == GameStatus.won ? SoundCue.success : SoundCue.gameOver);
  }

  void _moveTo(double localX, double width) {
    if (_status != GameStatus.playing) return;
    _keeperTargetX = (localX / width).clamp(_kMin, _kMax);
  }

  void _reset() => setState(() {
        _status = GameStatus.playing;
        _begin();
      });

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    return _GoalShell(
      title: '🥅 Goal Keeper',
      goal: 'Read the shot, slide and dive · Make 10 saves',
      introHow:
          'A ball is kicked at your goal — slide left/right to get your gloves in its path and save it!',
      onStart: () => setState(() {
        _status = GameStatus.playing;
        _begin();
      }),
      score: _score,
      target: _target,
      best: _best,
      status: _status,
      accent: const Color(0xFFFFD166),
      message: _message ?? 'Lives ${'⚽' * _lives}${'·' * (5 - _lives)}',
      onReset: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          return GestureDetector(
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
              ),
              size: Size.infinite,
            ),
            // A hidden hit target keeps the old save affordance working for
            // tests and for taps near the keeper.
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
  });
  final double keeperX;
  final double lean;
  final Offset ball;
  final double ballScale;
  final int phase;
  final bool lastSaved;
  final List<_Spark> sparks;
  final double aimHint;

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

    // Goal net.
    final netRect = Rect.fromLTRB(sx(_goalLeft), sy(_crossbarY),
        sx(_goalRight), sy(_lineY));
    final net = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..strokeWidth = 1;
    for (var gx = 0; gx <= 10; gx++) {
      final x = netRect.left + netRect.width * gx / 10;
      canvas.drawLine(Offset(x, netRect.top), Offset(x, netRect.bottom), net);
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