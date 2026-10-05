part of '../arcade_games.dart';

/// Bug Catch — bugs scurry around. Catch only the colour you're asked for
/// before they wander off. Tapping a wrong bug costs a life. Twelve to win.
class BugCatchGame extends StatefulWidget {
  const BugCatchGame({super.key});
  @override
  State<BugCatchGame> createState() => _BugCatchGameState();
}

class _Bug {
  _Bug(this.x, this.y, this.vx, this.vy, this.colorIndex, this.phase);
  double x, y, vx, vy, phase;
  int colorIndex;
}

class _BugCatchGameState extends State<BugCatchGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'bug_catch';
  static const int _target = 12;
  static const List<Color> _colors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
  ];
  static const List<String> _names = <String>['red', 'yellow', 'green', 'blue'];
  final math.Random _rnd = math.Random();
  final List<_Bug> _bugs = <_Bug>[];
  final List<_Shard> _bits = <_Shard>[];
  int _targetColor = 0;
  int _score = 0;
  int _lives = 3;
  int _best = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  // Scurry gets busier and faster as you go: more bugs on screen and a
  // quicker wander speed, so round 12 is a genuinely harder hunt than round 1.
  int get _maxBugs => math.min(6 + _score ~/ 4, 10);
  double get _speedBoost => 1 + _score * 0.035;

  void _spawn() {
    final edge = _rnd.nextInt(4);
    double x, y;
    switch (edge) {
      case 0:
        x = _rnd.nextDouble();
        y = -0.05;
      case 1:
        x = 1.05;
        y = _rnd.nextDouble();
      case 2:
        x = _rnd.nextDouble();
        y = 1.05;
      default:
        x = -0.05;
        y = _rnd.nextDouble();
    }
    final a = _rnd.nextDouble() * math.pi * 2;
    final sp = (0.08 + _rnd.nextDouble() * 0.1) * _speedBoost;
    _bugs.add(_Bug(x, y, math.cos(a) * sp, math.sin(a) * sp,
        _rnd.nextInt(_colors.length), _rnd.nextDouble() * math.pi * 2));
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    while (_bugs.length < _maxBugs) {
      _spawn();
    }
    for (var i = _bugs.length - 1; i >= 0; i--) {
      final b = _bugs[i];
      b.phase += dt * 10;
      // gentle wander
      if (_rnd.nextDouble() < dt * 2) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = (0.08 + _rnd.nextDouble() * 0.1) * _speedBoost;
        b.vx = math.cos(a) * sp;
        b.vy = math.sin(a) * sp;
      }
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.x < -0.1 || b.x > 1.1 || b.y < -0.1 || b.y > 1.1) {
        _bugs.removeAt(i);
      }
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
    }
  }

  void _tap(Offset p, double w, double h) {
    if (_status != GameStatus.playing) return;
    for (var i = _bugs.length - 1; i >= 0; i--) {
      final b = _bugs[i];
      if ((b.x - p.dx / w).abs() < 0.07 && (b.y - p.dy / h).abs() < 0.07) {
        if (b.colorIndex == _targetColor) {
          _score++;
          for (var j = 0; j < 10; j++) {
            final a = _rnd.nextDouble() * math.pi * 2;
            final sp = 0.15 + _rnd.nextDouble() * 0.3;
            _bits.add(_Shard(b.x, b.y, math.cos(a) * sp, math.sin(a) * sp,
                _colors[b.colorIndex]));
          }
          _bugs.removeAt(i);
          TonePlayer.instance.playCue(SoundCue.success);
          emit(ExperienceEvent.bubblePopped);
          if (_score % 4 == 0) {
            _targetColor = _rnd.nextInt(_colors.length);
            _banner = 'Now catch ${_names[_targetColor]}!';
            _bannerT = 1.4;
          }
          GameScores.instance.submit(_id, _score).then((v) {
            if (mounted) setState(() => _best = v);
          });
          if (_score >= _target) {
            _status = GameStatus.won;
            TonePlayer.instance.playCue(SoundCue.gameStart);
            emit(ExperienceEvent.gameCompleted);
          }
        } else {
          _lives--;
          if (_lives <= 0) {
            // Distinct terminal cue — the catching run really ends here.
            _status = GameStatus.over;
            TonePlayer.instance.playCue(SoundCue.gameOver);
            emit(ExperienceEvent.incorrectAnswer);
          } else {
            TonePlayer.instance.playCue(SoundCue.gentleRetry);
          }
          _banner = 'Only ${_names[_targetColor]} bugs!';
          _bannerT = 1.2;
        }
        setState(() {});
        return;
      }
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _lives = 3;
      _targetColor = _rnd.nextInt(_colors.length);
      _bugs.clear();
      _bits.clear();
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🐞 Bug Catch',
      introHow:
          'Catch only the colour of bug you are asked for! Tap them before they scurry off the screen.',
      onStart: () => setState(() {
        _targetColor = _rnd.nextInt(_colors.length);
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Catch the ${_names[_targetColor]} bugs! · ${'💛' * _lives}',
      overEmoji: '💪',
      overText: 'Out of lives — nice try!',
      winEmoji: '🐞',
      winText: 'Bug buster!',
      accent: _colors[_targetColor],
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d.localPosition, w, h),
            child: CustomPaint(
              painter: _BugPainter(
                bugs: _bugs,
                colors: _colors,
                targetColor: _targetColor,
                bits: _bits,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BugPainter extends CustomPainter {
  _BugPainter({
    required this.bugs,
    required this.colors,
    required this.targetColor,
    required this.bits,
  });
  final List<_Bug> bugs;
  final List<Color> colors;
  final int targetColor;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2B3B23), Color(0xFF1A2416)],
          ).createShader(Offset.zero & size));
    for (final b in bugs) {
      final c = Offset(b.x * w, b.y * h);
      final r = w * 0.045;
      final wiggle = math.sin(b.phase) * 2;
      // legs
      final leg = Paint()
        ..color = Colors.black54
        ..strokeWidth = 2;
      for (var k = -1; k <= 1; k++) {
        canvas.drawLine(c + Offset(-r, k * r * 0.5),
            c + Offset(-r * 1.8, k * r * 0.7 + wiggle), leg);
        canvas.drawLine(c + Offset(r, k * r * 0.5),
            c + Offset(r * 1.8, k * r * 0.7 - wiggle), leg);
      }
      canvas.drawCircle(c, r, Paint()..color = colors[b.colorIndex]);
      canvas.drawCircle(c + Offset(0, -r * 0.8), r * 0.5,
          Paint()..color = Colors.black87);
      canvas.drawLine(c + Offset(0, -r), c + Offset(0, r),
          Paint()
            ..color = Colors.black38
            ..strokeWidth = 1.5);
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_BugPainter old) => true;
}

