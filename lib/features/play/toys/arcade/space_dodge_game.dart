part of '../arcade_games.dart';

class SpaceDodgeGame extends StatefulWidget {
  const SpaceDodgeGame({super.key});
  @override
  State<SpaceDodgeGame> createState() => _SpaceDodgeGameState();
}

class _Meteor {
  _Meteor(this.x, this.y, this.r, this.vy, {this.kind = 0, this.vx = 0.0});
  double x, y, r, vy, vx;
  final int kind; // 0 = rock (deadly), 1 = gem (+bonus), 2 = shield pickup
}

class _SpaceDodgeGameState extends State<SpaceDodgeGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'space_dodge';
  static const int _startingLives = 3;
  static const int _goalScore = 180;
  final math.Random _rnd = math.Random();
  final List<_Meteor> _meteors = <_Meteor>[];
  final List<Offset> _stars = <Offset>[];
  final List<_Shard> _shards = <_Shard>[];
  double _shipX = 0.5;
  double _elapsed = 0;
  double _spawnIn = 0.6;
  int _score = 0;
  int _best = 0;
  int _bonus = 0;
  int _lives = _startingLives;
  int _lastMilestone = 0;
  int _wave = 1;
  bool _invulnerable = false;
  double _hitCooldown = 0;
  bool _shield = false;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  static const double _shipR = 0.045;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 40; i++) {
      _stars.add(Offset(_rnd.nextDouble(), _rnd.nextDouble()));
    }
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _elapsed += dt;
    final wave = (_elapsed / 12).floor() + 1;
    if (wave > _wave) {
      _wave = wave;
      TonePlayer.instance.playCue(SoundCue.milestone);
      _flash('Wave $_wave!');
    }
    if (_invulnerable) {
      _hitCooldown -= dt;
      if (_hitCooldown <= 0) {
        _invulnerable = false;
        _banner = 'Back in the fight!';
        _bannerT = 0.9;
      }
    }

    if (_rnd.nextDouble() < 0.9) {
      _shards.add(_Shard(
          _shipX + (_rnd.nextDouble() - 0.5) * 0.03,
          0.9,
          (_rnd.nextDouble() - 0.5) * 0.08,
          0.25 + _rnd.nextDouble() * 0.18,
          _rnd.nextBool() ? const Color(0xFFFFB703) : const Color(0xFFFB5607)));
    }
    for (var i = _shards.length - 1; i >= 0; i--) {
      final s = _shards[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) _shards.removeAt(i);
    }
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }

    _score = (_elapsed * 5).round() + _bonus;
    if (_score >= _goalScore && _status == GameStatus.playing) {
      _status = GameStatus.won;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.gameCompleted);
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      _flash('Galaxy cleared!');
      return;
    }

    if (_score ~/ 45 > _lastMilestone) {
      _lastMilestone = _score ~/ 45;
      TonePlayer.instance.playCue(SoundCue.coin);
      emit(ExperienceEvent.bubblePopped);
    }

    final speed = 0.38 + _elapsed * 0.025 + _wave * 0.02;
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = math.max(0.25, 0.78 - _elapsed * 0.018);
      final cluster = _wave > 1 && _rnd.nextDouble() < 0.18;
      if (cluster) {
        final baseX = 0.12 + _rnd.nextDouble() * 0.76;
        for (final offset in <double>[-0.08, 0.08]) {
          final vx = (_rnd.nextBool() ? -1.0 : 1.0) *
              (0.04 + _rnd.nextDouble() * 0.12);
          _meteors.add(
              _Meteor(baseX + offset, -0.1, 0.032, speed, kind: 0, vx: vx));
        }
      } else {
        final roll = _rnd.nextDouble();
        final kind = roll < 0.12 ? 1 : (roll < 0.18 ? 2 : 0);
        final r = kind == 0 ? 0.03 + _rnd.nextDouble() * 0.045 : 0.032;
        final x = _rnd.nextDouble();
        final vx =
            (_rnd.nextBool() ? -1.0 : 1.0) * (0.04 + _rnd.nextDouble() * 0.12);
        _meteors.add(_Meteor(x, -0.1, r, speed + _rnd.nextDouble() * 0.12,
            kind: kind, vx: vx));
      }
    }

    for (var i = _meteors.length - 1; i >= 0; i--) {
      final m = _meteors[i];
      m.x += m.vx * dt;
      if (m.x < 0.04 || m.x > 0.96) m.vx *= -1;
      m.y += m.vy * dt;

      final dx = (m.x - _shipX);
      final dy = (m.y - 0.85);
      if (dx * dx + dy * dy < (m.r + _shipR) * (m.r + _shipR)) {
        if (m.kind == 1) {
          _bonus += 20;
          _burstAt(m.x, m.y, const Color(0xFF06D6A0), 12);
          _meteors.removeAt(i);
          TonePlayer.instance.playCue(SoundCue.coin);
          _flash('Gem +20');
          emit(ExperienceEvent.bubblePopped);
          continue;
        }
        if (m.kind == 2) {
          _shield = true;
          _burstAt(m.x, m.y, const Color(0xFF4CC9F0), 12);
          _meteors.removeAt(i);
          TonePlayer.instance.playCue(SoundCue.success);
          _flash('Shield up!');
          continue;
        }
        if (_shield) {
          _shield = false;
          _burstAt(m.x, m.y, const Color(0xFF4CC9F0), 16);
          _meteors.removeAt(i);
          TonePlayer.instance.playCue(SoundCue.metal);
          _flash('Shield saved you!');
          continue;
        }

        if (_invulnerable) {
          _meteors.removeAt(i);
          continue;
        }
        _lives -= 1;
        _invulnerable = true;
        _hitCooldown = 1.1;
        _burstAt(m.x, m.y, const Color(0xFFFF6B6B), 18);
        _meteors.removeAt(i);
        if (_lives <= 0) {
          _status = GameStatus.over;
          TonePlayer.instance.playCue(SoundCue.crash);
          final prev = GameScores.instance.best(_id);
          emit(_score > prev
              ? ExperienceEvent.gameCompleted
              : ExperienceEvent.incorrectAnswer);
          GameScores.instance.submit(_id, _score).then((b) {
            if (mounted) setState(() => _best = b);
          });
          _flash('Ship lost');
          return;
        }
        TonePlayer.instance.playCue(SoundCue.metal);
        emit(ExperienceEvent.incorrectAnswer);
        _flash('Ouch! $_lives left');
      }
    }
    _meteors.removeWhere((m) => m.y > 1.2 || m.y < -0.25);
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.0;
  }

  void _burstAt(double x, double y, Color color, int n) {
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final sp = 0.2 + _rnd.nextDouble() * 0.4;
      _shards.add(_Shard(x, y, math.cos(a) * sp, math.sin(a) * sp, color));
    }
  }

  void _steer(double localX, double width) {
    _shipX = (localX / width).clamp(_shipR, 1 - _shipR);
  }

  void _reset() {
    setState(() {
      _meteors.clear();
      _shards.clear();
      _shipX = 0.5;
      _elapsed = 0;
      _spawnIn = 0.6;
      _score = 0;
      _bonus = 0;
      _lives = _startingLives;
      _lastMilestone = 0;
      _wave = 1;
      _invulnerable = false;
      _hitCooldown = 0;
      _shield = false;
      _banner = null;
      _bannerT = 0;
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🚀 Space Dodge',
      introHow:
          'Steer to dodge the meteors. Survive the waves, grab gems, and reach 180 points before all 3 ships are gone.',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _goalScore,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Ships: $_lives${_shield ? ' | Shielded' : ''}'
              : null),
      overEmoji: _lives <= 0 ? '💥' : '🎉',
      overText: _lives <= 0 ? 'Mission failed!' : 'Galaxy clear!',
      accent: const Color(0xFF9B5DE5),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) =>
                _steer(d.localPosition.dx, constraints.maxWidth),
            onPanDown: (d) => _steer(d.localPosition.dx, constraints.maxWidth),
            child: CustomPaint(
              painter: _SpacePainter(
                  _meteors, _stars, _shipX, _shipR, _shield, _shards),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.meteors, this.stars, this.shipX, this.shipR, this.shield,
      this.shards);
  final List<_Meteor> meteors;
  final List<Offset> stars;
  final double shipX;
  final double shipR;
  final bool shield;
  final List<_Shard> shards;

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
            colors: <Color>[Color(0xFF0B1030), Color(0xFF05030F)],
          ).createShader(Offset.zero & size));
    final star = Paint()..color = Colors.white70;
    for (final s in stars) {
      canvas.drawCircle(Offset(s.dx * w, s.dy * h), 1.4, star);
    }
    final rock = Paint()..color = const Color(0xFF8D6E63);
    for (final m in meteors) {
      final c = Offset(m.x * w, m.y * h);
      final rr = m.r * w;
      if (m.kind == 1) {
        final p = Path()
          ..moveTo(c.dx, c.dy - rr)
          ..lineTo(c.dx + rr, c.dy)
          ..lineTo(c.dx, c.dy + rr)
          ..lineTo(c.dx - rr, c.dy)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF06D6A0));
        canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white);
      } else if (m.kind == 2) {
        canvas.drawCircle(
            c, rr, Paint()..color = const Color(0xFF4CC9F0).withOpacity(0.5));
        canvas.drawCircle(
            c,
            rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFF4CC9F0));
      } else {
        canvas.drawCircle(c, rr, rock);
        canvas.drawCircle(
            c, rr * 0.6, Paint()..color = const Color(0xFF5D4037));
      }
    }
    final sx = shipX * w;
    final sy = 0.85 * h;
    for (final s in shards) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(s.x * w, s.y * h),
          2 + 3 * k,
          Paint()
            ..color = s.color.withOpacity(k)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
    final path = Path()
      ..moveTo(sx, sy - shipR * w)
      ..lineTo(sx - shipR * w * 0.7, sy + shipR * w)
      ..lineTo(sx + shipR * w * 0.7, sy + shipR * w)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF4CC9F0));
    canvas.drawCircle(
        Offset(sx, sy), shipR * w * 0.35, Paint()..color = Colors.white);
    if (shield) {
      canvas.drawCircle(
          Offset(sx, sy),
          shipR * w * 1.7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF4CC9F0).withOpacity(0.9));
    }
  }

  @override
  bool shouldRepaint(_SpacePainter oldDelegate) => true;
}
