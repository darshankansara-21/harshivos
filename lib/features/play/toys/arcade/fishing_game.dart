part of '../arcade_games.dart';

/// Fishing — tap the water to cast, wait for a nibble, then tap the moment the
/// bobber dips to land the fish. Golden fish are worth more; catch 10 to win.
class FishingGame extends StatefulWidget {
  const FishingGame({super.key});
  @override
  State<FishingGame> createState() => _FishingGameState();
}

class _Fish {
  _Fish(this.x, this.y, this.vx, this.gold);
  double x, y, vx;
  final bool gold;
}

class _FishingGameState extends State<FishingGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'fishing';
  static const int _target = 10;
  static const double _waterTop = 0.42;
  final math.Random _rnd = math.Random();
  final List<_Fish> _fish = <_Fish>[];
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  double _hookX = 0.5;
  final double _hookY = 0.6;
  double _biteT = 0; // >0 while a fish nibbles (tap window)
  bool _biteGold = false;
  double _bobT = 0; // bob animation
  int _score = 0;
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

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.4;
  }

  void _spawnFish() {
    final fromLeft = _rnd.nextBool();
    // The bobber never moves vertically (`_hookY` is fixed at 0.6, and a bite
    // only triggers within `(f.y - _hookY).abs() < 0.12`, i.e. y in
    // [0.48, 0.72]). Spawning fish across the old full water depth
    // (0.50-0.90) meant ~45% of fish swam past at a depth the bobber could
    // never reach — invisible "dead" fish a child would watch cross right by
    // the hook with nothing happening. Keep every fish inside the catchable
    // band so any fish that reaches the bobber's x can always be caught.
    final y = _waterTop + 0.06 + _rnd.nextDouble() * 0.24;
    final speed = 0.08 + _rnd.nextDouble() * 0.12;
    _fish.add(_Fish(fromLeft ? -0.05 : 1.05, y, fromLeft ? speed : -speed,
        _rnd.nextInt(4) == 0));
  }

  double get _window => math.max(0.55, 1.2 - _score * 0.06);

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    _bobT += dt;
    while (_fish.length < 4) {
      _spawnFish();
    }
    for (var i = _fish.length - 1; i >= 0; i--) {
      final f = _fish[i];
      f.x += f.vx * dt;
      if (f.x < -0.1 || f.x > 1.1) _fish.removeAt(i);
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.5 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
    if (_biteT > 0) {
      _biteT -= dt;
      if (_biteT <= 0) {
        _flash('It got away…');
        TonePlayer.instance.playCue(SoundCue.gentleRetry);
      }
      return;
    }
    // Look for a fish reaching the hook to start a nibble.
    for (final f in _fish) {
      if ((f.x - _hookX).abs() < 0.05 && (f.y - _hookY).abs() < 0.12) {
        _biteT = _window;
        _biteGold = f.gold;
        _fish.remove(f);
        TonePlayer.instance.playCue(SoundCue.bubble);
        break;
      }
    }
  }

  void _tap(Offset p, double w, double h) {
    if (_status != GameStatus.playing) return;
    if (_biteT > 0) {
      final pts = _biteGold ? 3 : 1;
      _score += pts;
      final bitCount = _reduceMotion ? 4 : 14;
      for (var i = 0; i < bitCount; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard(_hookX, _hookY, math.cos(a) * sp, math.sin(a) * sp,
            _biteGold ? const Color(0xFFFFD166) : const Color(0xFF9BE3FF)));
      }
      _biteT = 0;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _flash(_biteGold ? 'Golden catch! +3 🐟' : 'Caught it! +1 🐟');
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      }
    } else {
      _hookX = (p.dx / w).clamp(0.05, 0.95);
      TonePlayer.instance.playPop(0.5);
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _fish.clear();
      _bits.clear();
      _biteT = 0;
      _hookX = 0.5;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _Shell(
      title: '🎣 Fishing',
      introHow:
          'Tap the water to move your bobber. When a fish nibbles and the bobber dips, tap fast to catch it!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_biteT > 0 ? 'A bite! Tap now!' : 'Caught $_score/$_target'),
      winEmoji: '🎣',
      winText: 'Reel master!',
      accent: const Color(0xFF2FA7C4),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d.localPosition, w, h),
            child: CustomPaint(
              painter: _FishingPainter(
                waterTop: _waterTop,
                hookX: _hookX,
                hookY: _hookY,
                biteT: _biteT,
                window: _window,
                bobT: _bobT,
                fish: _fish,
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

class _FishingPainter extends CustomPainter {
  _FishingPainter({
    required this.waterTop,
    required this.hookX,
    required this.hookY,
    required this.biteT,
    required this.window,
    required this.bobT,
    required this.fish,
    required this.bits,
  });
  final double waterTop, hookX, hookY, biteT, window, bobT;
  final List<_Fish> fish;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double sx(double x) => x * w;
    double sy(double y) => y * h;
    // Sky.
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, sy(waterTop)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF8FD3F4), Color(0xFFBDE8F7)],
          ).createShader(Rect.fromLTWH(0, 0, w, sy(waterTop))));
    // Water.
    canvas.drawRect(
        Rect.fromLTWH(0, sy(waterTop), w, h - sy(waterTop)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2FA7C4), Color(0xFF12506B)],
          ).createShader(Rect.fromLTWH(0, sy(waterTop), w, h - sy(waterTop))));
    // Surface ripples.
    final surf = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..moveTo(0, sy(waterTop));
    for (var x = 0.0; x <= w; x += 12) {
      path.lineTo(x, sy(waterTop) + math.sin(x / 26 + bobT * 2) * 3);
    }
    canvas.drawPath(path, surf);

    // Fish.
    for (final f in fish) {
      final c = Offset(sx(f.x), sy(f.y));
      final dir = f.vx >= 0 ? 1.0 : -1.0;
      final body = Paint()
        ..color = f.gold ? const Color(0xFFFFD166) : const Color(0xFF7FDBFF);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: w * 0.08, height: w * 0.05), body);
      final tail = Path()
        ..moveTo(c.dx - dir * w * 0.04, c.dy)
        ..lineTo(c.dx - dir * w * 0.07, c.dy - w * 0.025)
        ..lineTo(c.dx - dir * w * 0.07, c.dy + w * 0.025)
        ..close();
      canvas.drawPath(tail, body);
      canvas.drawCircle(
          Offset(c.dx + dir * w * 0.025, c.dy - w * 0.008), 2, Paint()..color = Colors.black87);
    }

    // Line + bobber (dips during a bite).
    final dip = biteT > 0 ? math.sin(bobT * 30) * 0.02 + 0.03 : 0.0;
    final bob = Offset(sx(hookX), sy(hookY + dip));
    canvas.drawLine(Offset(sx(hookX), 0), bob,
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5);
    canvas.drawCircle(bob, w * 0.03, Paint()..color = Colors.white);
    canvas.drawCircle(bob, w * 0.03,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFE23B3B));
    if (biteT > 0) {
      canvas.drawCircle(bob, w * 0.03 + (1 - biteT / window) * w * 0.08,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withOpacity(biteT / window));
    }

    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(sx(s.x), sy(s.y)), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_FishingPainter old) => true;
}

