part of '../arcade_games.dart';

class StackGame extends StatefulWidget {
  const StackGame({super.key});
  @override
  State<StackGame> createState() => _StackGameState();
}

class _Block {
  _Block(this.left, this.width);
  double left;
  double width;
}

class _StackGameState extends State<StackGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'stack';
  final math.Random _rnd = math.Random();
  final List<_Block> _tower = <_Block>[];
  final List<_Shard> _bits = <_Shard>[];
  bool _reduceMotion = false;
  Size _view = const Size(360, 640);
  double _curLeft = 0.1;
  double _curWidth = 0.44;
  double _dir = 1;
  double _speed = 0.55;
  int _score = 0;
  int _best = 0;
  int _level = 1;
  int _perfectStreak = 0;
  double _dashTimer = 2.6;
  double _dashActive = 0;
  bool _seenDash = false;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;
  // Mirrors mini_games.dart's FruitCatchGame/BalloonPopGame/StarTapGame/
  // SnakeGame/RacingGame/BowlingGame live "beat your own all-time best"
  // celebration. Stack has no win cap at all — score climbs purely with
  // tower height and precision multipliers until the player topples — so
  // crossing a prior personal best mid-tower is a real, judgment-free
  // moment worth its own banner.
  bool _beatBest = false;

  @override
  void initState() {
    super.initState();
    _tower.add(_Block(0.28, 0.44));
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
    for (var i = _bits.length - 1; i >= 0; i--) {
      final s = _bits[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 400 * dt;
      s.life -= dt;
      if (s.life <= 0) _bits.removeAt(i);
    }
    // From level 2 on, the block periodically "dashes" at 1.8x speed for a
    // short burst — a real timing/reflex challenge, not just a faster base
    // speed. Keeps the core loop reactive instead of purely rhythmic.
    if (_level >= 2) {
      if (_dashActive > 0) {
        _dashActive -= dt;
        if (_dashActive <= 0) _dashTimer = 2.2 - math.min(1.0, _level * 0.12);
      } else {
        _dashTimer -= dt;
        if (_dashTimer <= 0) {
          _dashActive = 0.4;
          if (!_seenDash) {
            _seenDash = true;
            _banner = 'Speed dash! Time it carefully.';
            _bannerT = 1.2;
          }
        }
      }
    }
    final effSpeed = _speed * (_dashActive > 0 ? 1.8 : 1.0);
    _curLeft += _dir * effSpeed * dt;
    if (_curLeft + _curWidth > 1) {
      _curLeft = 1 - _curWidth;
      _dir = -1;
    } else if (_curLeft < 0) {
      _curLeft = 0;
      _dir = 1;
    }
  }

  void _updateLevel() {
    _level = 1 + ((_tower.length - 1) ~/ 6);
    _speed = math.min(1.35, 0.55 + (_level - 1) * 0.05);
  }

  void _drop() {
    if (_status != GameStatus.playing) return;
    final top = _tower.last;
    final l = math.max(_curLeft, top.left);
    final r = math.min(_curLeft + _curWidth, top.left + top.width);
    final overlap = r - l;
    if (overlap <= 0) {
      _over();
      return;
    }
    final targetCenter = top.left + top.width / 2;
    final movingCenter = _curLeft + _curWidth / 2;
    final misalign = (movingCenter - targetCenter).abs();
    final tolerance = math.max(0.02, top.width * 0.12);
    final perfect = misalign < tolerance;
    final partialBonus = (1 - (misalign / math.max(top.width, 0.18))).clamp(0.0, 1.0);
    if (perfect) {
      _perfectStreak++;
      _tower.add(_Block(top.left, top.width));
      _curWidth = top.width;
      final mult = _perfectStreak.clamp(1, 5);
      _score += (2 + partialBonus.round()) * mult;
      if (_perfectStreak > 0 && _perfectStreak % 5 == 0 && _curWidth < 0.4) {
        // Reward real precision mastery: a 5-in-a-row perfect streak earns a
        // full-width rescue, a genuine comeback payoff for skilled play
        // rather than a cosmetic bonus.
        _curWidth = 0.4;
        _tower.last.width = 0.4;
        _tower.last.left =
            (top.left + top.width / 2 - 0.2).clamp(0.0, 1 - 0.4);
        _banner = 'Mastery Reset! x$mult';
        _bannerT = 1.3;
        TonePlayer.instance.playCue(SoundCue.milestone);
      } else {
        _banner = 'Perfect x$mult!';
        _bannerT = 1.1;
      }
      TonePlayer.instance.playCue(SoundCue.success);
    } else {
      _perfectStreak = 0;
      _tower.add(_Block(l, overlap));
      _curWidth = overlap;
      _score += 1 + partialBonus.round();
      _banner = partialBonus > 0.75 ? 'Nice save!' : 'Build the stack';
      _bannerT = 0.9;
      TonePlayer.instance.playCue(SoundCue.stack);
    }
    _updateLevel();
    _curLeft = _dir > 0 ? 0 : 1 - _curWidth;
    final nb = _tower.last;
    _impact((nb.left + nb.width / 2) * _view.width, _view.height - 70, perfect);
    emit(ExperienceEvent.bubblePopped);
    if (!_beatBest && _best > 0 && _score > _best) {
      _beatBest = true;
      // Takes priority over the perfect/save banner just set above — a
      // new all-time record is the bigger moment of the two.
      _banner = 'New personal best! 🏆';
      _bannerT = 1.6;
      TonePlayer.instance.playCue(SoundCue.milestone);
      emit(ExperienceEvent.personalBest);
    }
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted && b != _best) setState(() => _best = b);
    });
  }

  void _over() {
    final prev = GameScores.instance.best(_id);
    _status = GameStatus.over;
    TonePlayer.instance.playCue(SoundCue.gameOver);
    emit(_score > prev
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _impact(double x, double y, bool perfect) {
    final color =
        perfect ? const Color(0xFFFFD166) : const Color(0xFF9EE7FF);
    final bitCount = perfect ? 12 : 7;
    final effectiveBitCount =
        _reduceMotion ? math.max(3, (bitCount / 3).round()) : bitCount;
    for (var i = 0; i < effectiveBitCount; i++) {
      final a = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 2.4;
      final sp = 80 + _rnd.nextDouble() * 170;
      _bits.add(_Shard(x, y, math.cos(a) * sp, math.sin(a) * sp, color));
    }
  }

  void _reset() {
    setState(() {
      _tower
        ..clear()
        ..add(_Block(0.28, 0.44));
      _bits.clear();
      _curLeft = 0.1;
      _curWidth = 0.44;
      _dir = 1;
      _speed = 0.55;
      _score = 0;
      _level = 1;
      _perfectStreak = 0;
      _dashTimer = 2.6;
      _dashActive = 0;
      _seenDash = false;
      _beatBest = false;
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
      title: '🧱 Stack',
      introHow: 'Tap to drop the moving block and stack it as high as you can.',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner ?? 'Level $_level · streak x$_perfectStreak',
      overEmoji: '🧱',
      // Score has streak/precision multipliers baked in, so it no longer
      // reads 1:1 as tower height — the game-over card otherwise loses the
      // one stat (how high the tower actually got) a child can see and
      // instantly understand, unlike the abstract score number.
      overText: 'Toppled! Stacked ${_tower.length} high',
      accent: const Color(0xFF4CC9F0),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          _view = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _drop(),
            child: CustomPaint(
              painter: _StackPainter(
                  _tower, _curLeft, _curWidth, _bits, _dashActive > 0),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _StackPainter extends CustomPainter {
  _StackPainter(this.tower, this.curLeft, this.curWidth, this.bits, this.dashing);
  final List<_Block> tower;
  final double curLeft;
  final double curWidth;
  final List<_Shard> bits;
  final bool dashing;

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
            colors: <Color>[Color(0xFF11294B), Color(0xFF0B1B33)],
          ).createShader(Offset.zero & size));
    const blockH = 26.0;
    final baseY = h - 70;
    final visible = tower.length > 14 ? 14 : tower.length;
    final lastBlock = tower.last;
    final centerGuide = lastBlock.left + lastBlock.width / 2;
    final guidePaint = Paint()..color = Colors.white.withOpacity(0.28);
    canvas.drawLine(
      Offset(centerGuide * w, baseY - (visible - 1) * blockH - 8),
      Offset(centerGuide * w, baseY + 20),
      guidePaint,
    );
    for (var i = 0; i < visible; i++) {
      final idx = tower.length - visible + i;
      final b = tower[idx];
      final y = baseY - (visible - 1 - i) * blockH;
      final hue = (idx * 28) % 360;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(b.left * w, y, b.width * w, blockH - 3),
            const Radius.circular(5)),
        Paint()..color = HSVColor.fromAHSV(1, hue.toDouble(), 0.55, 0.95).toColor(),
      );
    }
    final movingY = baseY - visible * blockH;
    final movingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: dashing
            ? const <Color>[Color(0xFFFFD166), Color(0xFFFFF3BF)]
            : const <Color>[Color(0xFFB8F0FF), Color(0xFFFFFFFF)],
      ).createShader(Rect.fromLTWH(curLeft * w, movingY, curWidth * w, blockH - 3));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(curLeft * w, movingY, curWidth * w, blockH - 3),
          const Radius.circular(5)),
      movingPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(curLeft * w, movingY, curWidth * w, blockH - 3),
          const Radius.circular(5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dashing ? 2.5 : 1.5
        ..color = dashing
            ? const Color(0xFFFFD166)
            : Colors.white.withOpacity(0.7),
    );
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x, s.y), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_StackPainter oldDelegate) => true;
}

// ===========================================================================
// Merge — slide the board; equal numbers merge and double. Reach 64 to win.
// A gentle, original take on the classic sliding-merge puzzle.
// ===========================================================================
