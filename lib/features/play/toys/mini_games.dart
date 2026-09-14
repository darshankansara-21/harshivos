import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/toy/toy_ticker.dart';
import '../../../services/audio/tone_player.dart';
import '../../companion/companion.dart';

/// Shared chrome for the goal-based mini games: a score pill, a target, and a
/// celebratory win overlay with a "Play again" button. Games fill the
/// immersive toy canvas; the companion sits in the corner (added by the host).
class _GameShell extends StatelessWidget {
  const _GameShell({
    required this.title,
    required this.score,
    required this.target,
    required this.won,
    required this.onPlayAgain,
    required this.child,
    this.accent = const Color(0xFFFFD166),
  });

  final String title;
  final int score;
  final int target;
  final bool won;
  final VoidCallback onPlayAgain;
  final Widget child;
  final Color accent;

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
              padding: const EdgeInsets.only(top: 72),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$title   $score / $target',
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (won)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('🎉', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 8),
                    const Text(
                      'You did it!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onPlayAgain,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Play again'),
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

// ===========================================================================
// Fruit Catch — drag the basket to catch falling fruit. Reach the target to
// win. Never punishes misses, so it stays gentle and encouraging.
// ===========================================================================
class FruitCatchGame extends StatefulWidget {
  const FruitCatchGame({super.key});
  @override
  State<FruitCatchGame> createState() => _FruitCatchGameState();
}

class _Fruit {
  _Fruit(this.x, this.y, this.vy, this.emoji);
  double x;
  double y;
  double vy;
  final String emoji;
}

class _FruitCatchGameState extends State<FruitCatchGame>
    with TickerProviderStateMixin, ToyTicker {
  static const List<String> _fruits = <String>['🍓', '🍎', '🍌', '🍇', '🍊', '🍑'];
  static const int _target = 12;
  final math.Random _rnd = math.Random();
  final List<_Fruit> _items = <_Fruit>[];
  double _basketX = 0.5;
  double _spawnIn = 0.6;
  int _score = 0;
  bool _won = false;
  bool _winSent = false;

  @override
  void onTick(double dt) {
    if (_won) return;
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = 0.55 + _rnd.nextDouble() * 0.5;
      _items.add(_Fruit(0.08 + _rnd.nextDouble() * 0.84, -0.05,
          0.28 + _rnd.nextDouble() * 0.18 + _score * 0.01,
          _fruits[_rnd.nextInt(_fruits.length)]));
    }
    for (final f in _items) {
      f.y += f.vy * dt;
    }
    _items.removeWhere((f) {
      if (f.y >= 0.84 && f.y <= 0.96 && (f.x - _basketX).abs() < 0.13) {
        _score++;
        TonePlayer.instance.playPop(0.5 + _rnd.nextDouble() * 0.4);
        if (_score >= _target) _won = true;
        return true;
      }
      return f.y > 1.05;
    });
  }

  void _moveTo(double px, double width) {
    setState(() => _basketX = (px / width).clamp(0.06, 0.94));
  }

  void _reset() {
    setState(() {
      _items.clear();
      _score = 0;
      _won = false;
      _winSent = false;
      _spawnIn = 0.6;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_won && !_winSent) {
      _winSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          const CompanionEventNotification(ExperienceEvent.gameCompleted)
              .dispatch(context);
        }
      });
    }
    return _GameShell(
      title: '🧺 Catch',
      score: _score,
      target: _target,
      won: _won,
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _moveTo(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _moveTo(d.localPosition.dx, w),
            onPanUpdate: (d) => _moveTo(d.localPosition.dx, w),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF15324A), Color(0xFF0B2436)],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  for (final f in _items)
                    Positioned(
                      left: f.x * w - 22,
                      top: f.y * h - 22,
                      child: Text(f.emoji,
                          style: const TextStyle(fontSize: 40)),
                    ),
                  Positioned(
                    left: _basketX * w - 40,
                    top: 0.86 * h,
                    child: const Text('🧺', style: TextStyle(fontSize: 64)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Balloon Pop — balloons drift up; tap them to pop before they float away.
// Reach the target to win. Pure popping joy, with a satisfying pop each time.
// ===========================================================================
class BalloonPopGame extends StatefulWidget {
  const BalloonPopGame({super.key});
  @override
  State<BalloonPopGame> createState() => _BalloonPopGameState();
}

class _Balloon {
  _Balloon(this.x, this.y, this.vy, this.sway, this.color);
  double x;
  double y;
  double vy;
  double sway;
  final Color color;
}

class _BalloonPopGameState extends State<BalloonPopGame>
    with TickerProviderStateMixin, ToyTicker {
  static const List<Color> _colors = <Color>[
    Color(0xFFEF476F), Color(0xFFFFD166), Color(0xFF06D6A0),
    Color(0xFF118AB2), Color(0xFF9B5DE5),
  ];
  static const int _target = 14;
  final math.Random _rnd = math.Random();
  final List<_Balloon> _items = <_Balloon>[];
  double _spawnIn = 0.4;
  double _t = 0;
  int _score = 0;
  bool _won = false;
  bool _winSent = false;

  @override
  void onTick(double dt) {
    if (_won) return;
    _t += dt;
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = 0.5 + _rnd.nextDouble() * 0.5;
      _items.add(_Balloon(0.1 + _rnd.nextDouble() * 0.8, 1.1,
          0.16 + _rnd.nextDouble() * 0.12, _rnd.nextDouble() * 6.28,
          _colors[_rnd.nextInt(_colors.length)]));
    }
    for (final b in _items) {
      b.y -= b.vy * dt;
    }
    _items.removeWhere((b) => b.y < -0.1);
  }

  void _tap(double px, double py, double w, double h) {
    if (_won) return;
    for (var i = _items.length - 1; i >= 0; i--) {
      final b = _items[i];
      final bx = (b.x + math.sin(_t * 1.5 + b.sway) * 0.03) * w;
      final by = b.y * h;
      if ((px - bx).abs() < 52 && (py - by).abs() < 62) {
        _items.removeAt(i);
        _score++;
        TonePlayer.instance.playPop(0.4 + _rnd.nextDouble() * 0.5);
        if (_score >= _target) setState(() => _won = true);
        return;
      }
    }
  }

  void _reset() {
    setState(() {
      _items.clear();
      _score = 0;
      _won = false;
      _winSent = false;
      _spawnIn = 0.4;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_won && !_winSent) {
      _winSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          const CompanionEventNotification(ExperienceEvent.gameCompleted)
              .dispatch(context);
        }
      });
    }
    return _GameShell(
      title: '🎈 Pop',
      score: _score,
      target: _target,
      accent: const Color(0xFF06D6A0),
      won: _won,
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _tap(d.localPosition.dx, d.localPosition.dy, w, h),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF1A1246), Color(0xFF241A5E)],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  for (final b in _items)
                    Positioned(
                      left: (b.x + math.sin(_t * 1.5 + b.sway) * 0.03) * w - 26,
                      top: b.y * h - 32,
                      child: _BalloonShape(color: b.color),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BalloonShape extends StatelessWidget {
  const _BalloonShape({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 52,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(30),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 12),
            ],
          ),
        ),
        Container(width: 2, height: 18, color: Colors.white24),
      ],
    );
  }
}

// ===========================================================================
// Star Tap — a reaction game. One star glows at a time; tap it before it
// fades and a new one appears. Reach the target to win. Trains attention and
// quick response without any fail state.
// ===========================================================================
class StarTapGame extends StatefulWidget {
  const StarTapGame({super.key});
  @override
  State<StarTapGame> createState() => _StarTapGameState();
}

class _StarTapGameState extends State<StarTapGame>
    with TickerProviderStateMixin, ToyTicker {
  static const int _target = 12;
  static const int _cells = 9;
  final math.Random _rnd = math.Random();
  int _active = 0;
  double _life = 0;
  int _score = 0;
  bool _won = false;
  bool _winSent = false;

  @override
  void initState() {
    super.initState();
    _active = _rnd.nextInt(_cells);
    _life = 1.6;
  }

  @override
  void onTick(double dt) {
    if (_won) return;
    _life -= dt;
    if (_life <= 0) {
      _active = _rnd.nextInt(_cells);
      _life = math.max(0.7, 1.5 - _score * 0.06);
    }
  }

  void _tapCell(int i) {
    if (_won) return;
    if (i == _active) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.correct);
      if (_score >= _target) {
        setState(() => _won = true);
        return;
      }
      setState(() {
        _active = _rnd.nextInt(_cells);
        _life = math.max(0.7, 1.5 - _score * 0.06);
      });
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _won = false;
      _winSent = false;
      _active = _rnd.nextInt(_cells);
      _life = 1.6;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_won && !_winSent) {
      _winSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          const CompanionEventNotification(ExperienceEvent.gameCompleted)
              .dispatch(context);
        }
      });
    }
    return _GameShell(
      title: '⭐ Tap',
      score: _score,
      target: _target,
      accent: const Color(0xFFFFD166),
      won: _won,
      onPlayAgain: _reset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0E1F3A), Color(0xFF13294B)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (var i = 0; i < _cells; i++)
                GestureDetector(
                  onTapDown: (_) => _tapCell(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: i == _active
                          ? const Color(0xFFFFD166)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: i == _active
                          ? <BoxShadow>[
                              const BoxShadow(
                                  color: Color(0xAAFFD166), blurRadius: 24)
                            ]
                          : const <BoxShadow>[],
                    ),
                    child: Center(
                      child: Text(
                        i == _active ? '⭐' : '',
                        style: const TextStyle(fontSize: 44),
                      ),
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
