part of '../arcade_games.dart';

/// Skee Ball — drag up and release to roll the ball up the ramp. The further it
/// reaches, the better the ring it lands in. Build up 100 points to win.
class SkeeBallGame extends StatefulWidget {
  const SkeeBallGame({super.key});
  @override
  State<SkeeBallGame> createState() => _SkeeBallGameState();
}

class _SkeeBallGameState extends State<SkeeBallGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'skee_ball';
  static const int _target = 100;

  // Single source of truth for the scoring bands, shared with the painter so
  // the decorative rings can never visually drift out of sync with the real
  // scoring thresholds used by `_resolve()`. Each entry is the upper y-bound
  // (ball-travel fraction, 0 = top of ramp) and the points it awards.
  static const List<double> _bandUpperY = <double>[0.2, 0.33, 0.46, 0.72];
  // Unlike every other game reaching 100 (target_toss speeds its target up,
  // soccer_kick sharpens the keeper's read), skee_ball's bands never moved —
  // round 1 and round-nearly-won required the exact same drag precision, so
  // the back half of a 100-point run felt identical to the front half. These
  // are the fully-escalated bands a perfect run eventually reaches: every
  // zone narrower than its start value, so landing a 50 or 30 late in the
  // game genuinely demands a steadier drag than it did early on.
  static const List<double> _bandUpperYHard = <double>[0.1, 0.19, 0.3, 0.58];
  static const List<int> _bandPts = <int>[50, 30, 20, 10];

  // Interpolates from the easy opening bands to the hard late-game bands as
  // score climbs toward target, giving the run a real difficulty curve while
  // keeping the point values themselves unchanged.
  List<double> get _liveBandUpperY {
    final t = (_score / _target).clamp(0.0, 1.0);
    return <double>[
      for (var i = 0; i < _bandUpperY.length; i++)
        _bandUpperY[i] + (_bandUpperYHard[i] - _bandUpperY[i]) * t,
    ];
  }

  double _ballY = 0.86;
  double _targetY = 0.86;
  bool _rolling = false;
  bool _dragging = false;
  double _power = 0;
  double _startY = 0;
  int _score = 0, _best = 0;
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

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_rolling) {
      final dir = _targetY - _ballY;
      _ballY += dir * 6 * dt;
      if ((_targetY - _ballY).abs() < 0.01) {
        _ballY = _targetY;
        _resolve();
      }
    }
    setState(() {});
  }

  void _resolve() {
    _rolling = false;
    int pts = 0;
    String label = 'Gutter!';
    final bands = _liveBandUpperY;
    for (var i = 0; i < bands.length; i++) {
      if (_targetY < bands[i]) {
        pts = _bandPts[i];
        label = i == 0 ? 'Bullseye! +50' : '+$pts';
        break;
      }
    }
    if (pts > 0) {
      _score += pts;
      TonePlayer.instance.playCue(pts >= 30 ? SoundCue.success : SoundCue.coin);
      emit(ExperienceEvent.bubblePopped);
    } else {
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
    }
    _banner = label;
    _bannerT = 1.1;
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
    if (_score >= _target) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.gameStart);
      emit(ExperienceEvent.gameCompleted);
    } else {
      _ballY = 0.86;
    }
  }

  void _launch() {
    _targetY = (0.86 - _power * 1.05).clamp(0.08, 0.86);
    _rolling = true;
    TonePlayer.instance.playCue(SoundCue.ball);
  }

  void _reset() {
    setState(() {
      _score = 0;
      _ballY = 0.86;
      _rolling = false;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎳 Skee Ball',
      introHow:
          'Drag up and let go to roll the ball up the ramp. Aim for the top '
          'ring for the most points. Reach 100 to win!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? (_dragging ? 'Power: ${(_power * 100).round()}%' : 'Drag up to roll'),
      winEmoji: '🎳',
      winText: 'Nice rolling!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              if (_rolling) return;
              _dragging = true;
              _startY = d.localPosition.dy;
              _power = 0;
            },
            onPanUpdate: (d) {
              if (_rolling || !_dragging) return;
              _power = ((_startY - d.localPosition.dy) / h).clamp(0.0, 1.0);
              setState(() {});
            },
            onPanEnd: (_) {
              if (_rolling || !_dragging) return;
              _dragging = false;
              if (_power > 0.05) {
                _launch();
              } else {
                // Too weak a flick to count as a roll — give the same
                // audible nudge every other blocked gesture in the catalog
                // gets, so a child can tell "too soft" from "nothing happened".
                TonePlayer.instance.playCue(SoundCue.gentleRetry);
                setState(() => _power = 0);
              }
            },
            // A cancelled drag (onPanEnd never fires) would otherwise leave
            // the "Power: X%" banner and ramp indicator frozen on screen
            // forever. Drop back to idle instead.
            onPanCancel: () {
              if (_rolling || !_dragging) return;
              setState(() {
                _dragging = false;
                _power = 0;
              });
            },
            child: CustomPaint(
              painter: _SkeeBallPainter(
                  ballY: _ballY,
                  power: _dragging ? _power : 0,
                  bandUpperY: _liveBandUpperY),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _SkeeBallPainter extends CustomPainter {
  _SkeeBallPainter(
      {required this.ballY, required this.power, required this.bandUpperY});
  final double ballY, power;
  final List<double> bandUpperY;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2A1E12), Color(0xFF150E08)],
          ).createShader(Offset.zero & size));

    // Ramp.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.32, h * 0.06, w * 0.36, h * 0.86),
            const Radius.circular(20)),
        Paint()..color = const Color(0xFF6B4A2A));

    // Scoring bands — drawn to EXACTLY match `_SkeeBallGameState`'s real
    // live y-threshold boundaries (passed in, not the static base values),
    // so what a child sees always matches what actually scores, even as the
    // bands narrow with difficulty. Each band is a horizontal ring-hole
    // spanning its real vertical extent, narrower (harder) the higher it is.
    const cols = <Color>[
      Color(0xFFFF5DA2), Color(0xFFFFD166), Color(0xFF80ED99), Color(0xFF48CAE4),
    ];
    const widthFrac = <double>[0.16, 0.20, 0.24, 0.28];
    double prevY = 0.0;
    for (var i = 0; i < bandUpperY.length; i++) {
      final topY = prevY;
      final bottomY = bandUpperY[i];
      final midY = (topY + bottomY) / 2 * h;
      final halfH = (bottomY - topY) / 2 * h;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * 0.5, midY),
              width: w * widthFrac[i],
              height: halfH * 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = cols[i]);
      prevY = bottomY;
    }

    // Power meter at the left.
    if (power > 0) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.08, h * 0.9 - h * 0.8 * power, w * 0.05, h * 0.8 * power),
              const Radius.circular(6)),
          Paint()..color = Color.lerp(const Color(0xFF80ED99), const Color(0xFFE63946), power)!);
    }

    // Ball.
    canvas.drawCircle(Offset(w * 0.5, ballY * h), w * 0.05,
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.5 - w * 0.015, ballY * h - w * 0.015), w * 0.015,
        Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(_SkeeBallPainter oldDelegate) => true;
}
