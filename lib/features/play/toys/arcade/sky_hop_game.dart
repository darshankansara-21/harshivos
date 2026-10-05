part of '../arcade_games.dart';

class SkyHopGame extends StatefulWidget {
  const SkyHopGame({super.key});
  @override
  State<SkyHopGame> createState() => _SkyHopGameState();
}

class _Pipe {
  _Pipe(this.x, this.gapY, this.coinY);
  double x;
  double gapY;
  final double coinY;
  bool scored = false;
  bool coinTaken = false;
}

class _SkyHopGameState extends State<SkyHopGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'sky_hop';
  static const double _gap = 0.28; // fraction of height
  static const int _goalScore = 18;
  static const double _basePipeSpeed = 0.42;
  final math.Random _rnd = math.Random();
  final List<_Pipe> _pipes = <_Pipe>[];
  final List<_Shard> _bits = <_Shard>[];
  double _birdY = 0.5;
  double _vy = 0;
  double _spawnIn = 0;
  double _pipeSpeed = _basePipeSpeed;
  int _score = 0;
  int _best = 0;
  int _coinCombo = 0;
  bool _started = false;
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
      if (_bannerT <= 0) {
        _banner = null;
        _coinCombo = 0;
      }
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 0.6 * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
    }
    if (!_started) return;
    _pipeSpeed = math.min(0.82, _basePipeSpeed + _score * 0.02);
    _vy += 1.6 * dt; // gravity
    _birdY += _vy * dt;
    _spawnIn -= dt;
    if (_score >= _goalScore && _status == GameStatus.playing) {
      _status = GameStatus.won;
      _banner = 'Sky clear!';
      _bannerT = 1.4;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      return;
    }
    if (_spawnIn <= 0) {
      _spawnIn = math.max(1.1, 1.7 - _score * 0.04);
      final gapY = 0.18 + _rnd.nextDouble() * 0.64;
      final coinY = gapY + (_rnd.nextDouble() - 0.5) * _gap * 0.7;
      _pipes.add(_Pipe(1.1, gapY, coinY));
    }
    for (final p in _pipes) {
      p.x -= _pipeSpeed * dt;
      if (!p.scored && p.x < 0.28) {
        p.scored = true;
        // Only break the streak when THIS pipe's coin was missed — a coin
        // already grabbed on this pass must survive into the next pipe, or
        // the "Coin streak" bonus could mathematically never exceed x1.
        if (!p.coinTaken) _coinCombo = 0;
        _score++;
        _banner = 'Nice hop!';
        _bannerT = 0.8;
        TonePlayer.instance.playCue(SoundCue.coin);
        emit(ExperienceEvent.bubblePopped);
      }
      if (!p.coinTaken &&
          (p.x - 0.3).abs() < 0.09 &&
          (_birdY - p.coinY).abs() < 0.06) {
        p.coinTaken = true;
        _coinCombo += 1;
        final bonus = 2 + (_coinCombo - 1);
        _score += bonus;
        _banner = _coinCombo > 1 ? 'Coin streak x$_coinCombo!' : 'Coin grab!';
        _bannerT = 1.2;
        for (var k = 0; k < 8; k++) {
          final a = _rnd.nextDouble() * math.pi * 2;
          final sp = 0.1 + _rnd.nextDouble() * 0.22;
          _bits.add(_Shard(p.x, p.coinY, math.cos(a) * sp, math.sin(a) * sp,
              const Color(0xFFFFE066)));
        }
        TonePlayer.instance.playCue(SoundCue.coin);
      }
      if ((p.x - 0.3).abs() < 0.11 &&
          (_birdY < p.gapY - _gap / 2 || _birdY > p.gapY + _gap / 2)) {
        _over();
        return;
      }
    }
    _pipes.removeWhere((p) => p.x < -0.2);
    if (_birdY > 0.98 || _birdY < 0.02) _over();
  }

  void _flap() {
    if (_status != GameStatus.playing) return;
    _started = true;
    _vy = -0.68;
    for (var k = 0; k < 4; k++) {
      _bits.add(_Shard(0.3, _birdY + 0.03, -0.14 - _rnd.nextDouble() * 0.1,
          0.05 + _rnd.nextDouble() * 0.1, Colors.white));
    }
    TonePlayer.instance.playClick(pitch: 1.3);
  }

  void _over() {
    final prev = GameScores.instance.best(_id);
    _coinCombo = 0;
    _banner = null;
    _bannerT = 0;
    _status = GameStatus.over;
    TonePlayer.instance.playCue(SoundCue.crash);
    emit(_score > prev
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _reset() {
    setState(() {
      _pipes.clear();
      _bits.clear();
      _birdY = 0.5;
      _vy = 0;
      _spawnIn = 0;
      _pipeSpeed = _basePipeSpeed;
      _score = 0;
      _coinCombo = 0;
      _banner = null;
      _bannerT = 0;
      _started = false;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🐤 Sky Hop',
      introHow: 'Tap to flap through the gaps and collect enough coins to complete the sky run!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _goalScore,
      status: _status,
      banner: _banner,
      overEmoji: '🐤',
      overText: 'Splash!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _flap(),
        child: CustomPaint(
          painter: _SkyHopPainter(_pipes, _birdY, _gap, _started, _bits),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SkyHopPainter extends CustomPainter {
  _SkyHopPainter(this.pipes, this.birdY, this.gap, this.started, this.bits);
  final List<_Pipe> pipes;
  final double birdY;
  final double gap;
  final bool started;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF4EC5F1), Color(0xFFA8E6CF)],
          ).createShader(Offset.zero & size));
    final pipePaint = Paint()..color = const Color(0xFF2E9E5B);
    for (final p in pipes) {
      final cx = p.x * w;
      final gy = p.gapY * h;
      final half = gap / 2 * h;
      canvas.drawRect(
          Rect.fromLTRB(cx - w * 0.09, 0, cx + w * 0.09, gy - half), pipePaint);
      canvas.drawRect(
          Rect.fromLTRB(cx - w * 0.09, gy + half, cx + w * 0.09, h), pipePaint);
      if (!p.coinTaken) {
        final coinC = Offset(cx, p.coinY * h);
        canvas.drawCircle(coinC, w * 0.028,
            Paint()..color = const Color(0xFFFFD166));
        canvas.drawCircle(
            coinC,
            w * 0.028,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFB8860B));
      }
    }
    final bx = w * 0.3;
    final by = birdY * h;
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), w * 0.012 * k + 1.5,
          Paint()..color = s.color.withOpacity(k));
    }
    canvas.drawCircle(Offset(bx, by), w * 0.05, Paint()..color = const Color(0xFFFFD166));
    canvas.drawCircle(
        Offset(bx + w * 0.02, by - w * 0.015), 3, Paint()..color = Colors.black);
    if (!started) {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'Tap to flap',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.6));
    }
  }

  @override
  bool shouldRepaint(_SkyHopPainter oldDelegate) => true;
}

// ===========================================================================
// Stack — a block slides back and forth; tap to drop it on the tower. Overhang
// is trimmed, so precise stacking keeps the block wide. Miss entirely and the
// tower topples.
// ===========================================================================
