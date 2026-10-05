part of '../arcade_games.dart';

/// Sorting Train — each parcel is a colour. Tap the wagon that matches to load
/// it. Sort twelve parcels to complete the train.
class SortingTrainGame extends StatefulWidget {
  const SortingTrainGame({super.key});
  @override
  State<SortingTrainGame> createState() => _SortingTrainGameState();
}

class _SortingTrainGameState extends State<SortingTrainGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'sorting_train';
  static const int _target = 12;
  static const List<Color> _colors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF63E6BE),
    Color(0xFF66D9E8),
  ];
  final math.Random _rnd = math.Random();
  final List<_Shard> _bits = <_Shard>[];
  // Shuffled bag of colour indices so the 12-parcel win draws each colour an
  // even number of times with no repeat, instead of plain Random-with-
  // replacement risking the same colour several times in a row while the
  // child never sees another one — same gap class as kindness_match /
  // calm_choices / weather_sort.
  final List<int> _bag = <int>[];
  int _item = 0;
  double _bob = 0;
  int _score = 0;
  int _best = 0;
  int _wrongFlash = -1;
  double _wrongT = 0;
  String? _banner;
  double _bannerT = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _item = _drawItem();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  int _drawItem() {
    if (_bag.isEmpty) {
      _bag.addAll(List<int>.generate(_colors.length, (i) => i)..shuffle(_rnd));
    }
    return _bag.removeLast();
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _bob += dt * 2;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    if (_wrongT > 0) {
      _wrongT -= dt;
      if (_wrongT <= 0) _wrongFlash = -1;
    }
    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vy += 0.5 * dt;
      b.life -= dt;
      if (b.life <= 0) _bits.removeAt(i);
    }
  }

  void _drop(int wagon) {
    if (_status != GameStatus.playing) return;
    if (wagon == _item) {
      _score++;
      for (var i = 0; i < 12; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final sp = 0.15 + _rnd.nextDouble() * 0.3;
        _bits.add(_Shard((wagon + 0.5) / _colors.length, 0.8, math.cos(a) * sp,
            math.sin(a) * sp, _colors[wagon]));
      }
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      _banner = 'Loaded! 🚃';
      _bannerT = 1.0;
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted) setState(() => _best = b);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _item = _drawItem();
      }
    } else {
      _wrongFlash = wagon;
      _wrongT = 0.4;
      TonePlayer.instance.playCue(SoundCue.gentleRetry);
      _banner = 'Match the colour!';
      _bannerT = 1.0;
    }
    setState(() {});
  }

  void _reset() {
    setState(() {
      _score = 0;
      _bag.clear();
      _item = _drawItem();
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
      title: '🚂 Sorting Train',
      introHow:
          'A coloured parcel floats on top. Tap the wagon with the same colour to load it!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Load $_score/$_target parcels',
      winEmoji: '🚂',
      winText: 'All aboard!',
      accent: const Color(0xFF63E6BE),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (d.localPosition.dy < h * 0.62) return;
              final i = (d.localPosition.dx / w * _colors.length)
                  .floor()
                  .clamp(0, _colors.length - 1);
              _drop(i);
            },
            child: CustomPaint(
              painter: _TrainPainter(
                colors: _colors,
                item: _item,
                bob: _bob,
                wrongFlash: _wrongFlash,
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

class _TrainPainter extends CustomPainter {
  _TrainPainter({
    required this.colors,
    required this.item,
    required this.bob,
    required this.wrongFlash,
    required this.bits,
  });
  final List<Color> colors;
  final int item;
  final double bob;
  final int wrongFlash;
  final List<_Shard> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF162032));
    // Parcel floating on top.
    final pc = Offset(w * 0.5, h * 0.3 + math.sin(bob) * 8);
    final box = Rect.fromCenter(center: pc, width: w * 0.18, height: w * 0.18);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(10)),
        Paint()..color = colors[item]);
    canvas.drawLine(Offset(box.left, pc.dy), Offset(box.right, pc.dy),
        Paint()..color = Colors.white70..strokeWidth = 3);
    canvas.drawLine(Offset(pc.dx, box.top), Offset(pc.dx, box.bottom),
        Paint()..color = Colors.white70..strokeWidth = 3);
    // Wagons.
    final lw = w / colors.length;
    for (var i = 0; i < colors.length; i++) {
      final rect = Rect.fromLTWH(i * lw + 8, h * 0.68, lw - 16, h * 0.22);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()..color = colors[i].withOpacity(wrongFlash == i ? 0.4 : 0.9));
      // wheels
      canvas.drawCircle(Offset(rect.left + lw * 0.25, rect.bottom + 8), 7,
          Paint()..color = Colors.black54);
      canvas.drawCircle(Offset(rect.right - lw * 0.25, rect.bottom + 8), 7,
          Paint()..color = Colors.black54);
    }
    for (final s in bits) {
      final k = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * w, s.y * h), 2 + 3 * k,
          Paint()..color = s.color.withOpacity(k));
    }
  }

  @override
  bool shouldRepaint(_TrainPainter old) => true;
}

void _paintPolyShape(Canvas canvas, Offset c, double r, int shape, Paint p) {
  switch (shape) {
    case 0: // circle
      canvas.drawCircle(c, r, p);
    case 1: // square
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: r * 1.8, height: r * 1.8),
              const Radius.circular(6)),
          p);
    case 2: // triangle
      final tri = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy + r * 0.8)
        ..lineTo(c.dx - r, c.dy + r * 0.8)
        ..close();
      canvas.drawPath(tri, p);
    case 3: // star
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final rr = i.isEven ? r : r * 0.45;
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
        i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
      }
      star.close();
      canvas.drawPath(star, p);
    case 4: // heart
      final heart = Path()..moveTo(c.dx, c.dy + r * 0.7);
      heart.cubicTo(c.dx + r * 1.4, c.dy - r * 0.4, c.dx + r * 0.4,
          c.dy - r * 1.1, c.dx, c.dy - r * 0.35);
      heart.cubicTo(c.dx - r * 0.4, c.dy - r * 1.1, c.dx - r * 1.4,
          c.dy - r * 0.4, c.dx, c.dy + r * 0.7);
      canvas.drawPath(heart, p);
    case 5: // diamond
      final dia = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 0.8, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r * 0.8, c.dy)
        ..close();
      canvas.drawPath(dia, p);
  }
}

