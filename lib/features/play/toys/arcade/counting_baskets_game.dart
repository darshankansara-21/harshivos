part of '../arcade_games.dart';

/// Counting Baskets — read the number, then drag exactly that many fruits into
/// the basket. The target grows as you go. Ten baskets to win. Gentle counting
/// practice with no way to fail.
class CountingBasketsGame extends StatefulWidget {
  const CountingBasketsGame({super.key});
  @override
  State<CountingBasketsGame> createState() => _CountingBasketsGameState();
}

class _Fruit {
  _Fruit(this.x, this.y, this.emoji);
  double x, y; // center, normalized
  final String emoji;
  bool collected = false;
}

class _CountingBasketsGameState extends State<CountingBasketsGame> with _Emit {
  static const String _id = 'counting_baskets';
  static const int _target = 10;
  static const List<String> _emojis = <String>['🍎', '🍊', '🍌', '🍓', '🍇', '🍐'];
  final math.Random _rnd = math.Random();
  static const List<String> _winPraisePool = <String>[
    'Great counting!',
    'Basket champion!',
    'Perfect fill!',
    'Fruit sorter pro!',
  ];
  String _winPraise = _winPraisePool.first;

  final List<_Fruit> _fruits = <_Fruit>[];
  int _need = 3;
  int _inBasket = 0;
  int _score = 0;
  int _best = 0;
  int? _dragging;
  // Screen-reader-only selection: a blind child cannot perform the pixel
  // precision drag the sighted gesture relies on, so a tap on a fruit
  // selects it, then a tap on the basket collects it via the same _collect
  // path a successful sighted drag uses.
  int? _selected;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _newRound() {
    // Target genuinely grows across the ten baskets (matching the file's own
    // "the target grows as you go" claim) instead of being flat random noise:
    // a steady base trend from 2 up toward 8 by the final round, plus a
    // small +0/+1 wobble so it still feels alive round to round.
    final base = 2 + (_score * 6 / 9).round();
    _need = (base + _rnd.nextInt(2)).clamp(2, 8);
    _inBasket = 0;
    _selected = null;
    _fruits.clear();
    final count = _need + 2;
    for (var i = 0; i < count; i++) {
      _fruits.add(_Fruit(
        0.12 + _rnd.nextDouble() * 0.76,
        0.16 + _rnd.nextDouble() * 0.34,
        _emojis[_rnd.nextInt(_emojis.length)],
      ));
    }
  }

  // Hit-test in pixel space with a single fixed-pixel tolerance: the painter
  // draws every loose fruit at a constant 38px emoji size regardless of
  // screen dimensions, so a tolerance normalized separately by width and
  // height would desync the hit zone from the visible fruit on any
  // non-square (portrait) screen — the same aspect-ratio hit-test bug class
  // already fixed in `bug_catch`, `shape_builder`, `bigger_number`, etc.
  int? _fruitAt(Offset p, double w, double h) {
    const tol = 26.0;
    for (var i = _fruits.length - 1; i >= 0; i--) {
      final f = _fruits[i];
      if (f.collected) continue;
      final dx = p.dx - f.x * w;
      final dy = p.dy - f.y * h;
      if (dx.abs() < tol && dy.abs() < tol) return i;
    }
    return null;
  }

  void _collect(_Fruit f) {
    f.collected = true;
    _inBasket++;
    TonePlayer.instance.playCue(SoundCue.fruit);
    if (_inBasket >= _need) {
      _score++;
      TonePlayer.instance.playCue(SoundCue.success);
      emit(ExperienceEvent.bubblePopped);
      GameScores.instance.submit(_id, _score).then((v) {
        if (mounted) setState(() => _best = v);
      });
      if (_score >= _target) {
        _status = GameStatus.won;
        _winPraise = _winPraisePool[_rnd.nextInt(_winPraisePool.length)];
        TonePlayer.instance.playCue(SoundCue.gameStart);
        emit(ExperienceEvent.gameCompleted);
      } else {
        _banner = 'Yes! $_need in the basket 🧺';
        _newRound();
      }
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _banner = null;
      _newRound();
      _status = GameStatus.playing;
    });
  }

  /// Screen-reader path: collect the selected loose fruit into the basket,
  /// running the exact same `_collect` logic a sighted drag-into-basket uses.
  void _collectSelected() {
    final i = _selected;
    if (i == null || _status != GameStatus.playing) return;
    setState(() {
      _selected = null;
      final f = _fruits[i];
      if (f.collected) return;
      _collect(f);
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🧺 Counting Baskets',
      introHow:
          'Read the number on the basket, then drag exactly that many fruits '
          'into it. Fill ten baskets to win!',
      onStart: () => setState(() {
        _newRound();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ??
          (_status == GameStatus.playing
              ? 'Put $_need in the basket  ·  $_inBasket/$_need'
              : 'Drag fruits to match the number'),
      winEmoji: '🧺',
      winText: _winPraise,
      accent: const Color(0xFFF4A261),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final gesture = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              _dragging = _fruitAt(d.localPosition, w, h);
            },
            onPanUpdate: (d) {
              final i = _dragging;
              if (i == null) return;
              setState(() {
                _fruits[i].x = (d.localPosition.dx / w).clamp(0.0, 1.0);
                _fruits[i].y = (d.localPosition.dy / h).clamp(0.0, 1.0);
              });
            },
            onPanEnd: (_) {
              final i = _dragging;
              _dragging = null;
              if (i == null) return;
              final f = _fruits[i];
              // Basket mouth is the lower-centre area.
              if (f.y > 0.7 && f.x > 0.28 && f.x < 0.72) {
                setState(() => _collect(f));
              }
            },
            // A cancelled pan (gesture arena interruption) never calls
            // onPanEnd, so without this a fruit mid-drag would stay stuck
            // wherever it was last dragged to — never checked against the
            // basket, never resettable except by a later drag happening to
            // grab it again. Run the exact same basket-mouth check onPanEnd
            // does so an interrupted drag still honestly resolves.
            onPanCancel: () {
              final i = _dragging;
              _dragging = null;
              if (i == null) return;
              final f = _fruits[i];
              if (f.y > 0.7 && f.x > 0.28 && f.x < 0.72) {
                setState(() => _collect(f));
              }
            },
            child: CustomPaint(
              painter: _FruitBasketPainter(fruits: _fruits, need: _need, inBasket: _inBasket),
              size: Size.infinite,
            ),
          );
          return Stack(children: <Widget>[
            gesture,
            _a11yOverlay(w, h),
          ]);
        },
      ),
    );
  }

  /// Screen-reader overlay: one button per loose fruit (select it) and one
  /// button over the basket mouth (collect the selected fruit there) — the
  /// exact same basket-mouth region (`y > 0.7 && 0.28 < x < 0.72`) the
  /// sighted drag-and-drop check uses, so a screen-reader user faces the same
  /// "get exactly $_need in" counting challenge, never an auto-solved one.
  Widget _a11yOverlay(double w, double h) {
    final kids = <Widget>[];
    for (var i = 0; i < _fruits.length; i++) {
      final f = _fruits[i];
      if (f.collected) continue;
      const box = 52.0;
      kids.add(Positioned(
        left: f.x * w - box / 2,
        top: f.y * h - box / 2,
        width: box,
        height: box,
        child: Semantics(
          button: true,
          label: 'Fruit, not yet in the basket.${_selected == i ? ' Selected.' : ''}',
          onTap: () => setState(() => _selected = (_selected == i) ? null : i),
          excludeSemantics: true,
          child: const SizedBox.expand(),
        ),
      ));
    }
    kids.add(Positioned(
      left: w * 0.28,
      top: h * 0.7,
      width: w * (0.72 - 0.28),
      height: h * 0.3,
      child: Semantics(
        button: true,
        label: 'Basket, needs $_need, has $_inBasket.',
        onTap: _collectSelected,
        excludeSemantics: true,
        child: const SizedBox.expand(),
      ),
    ));
    return Stack(children: kids);
  }
}

class _FruitBasketPainter extends CustomPainter {
  _FruitBasketPainter({required this.fruits, required this.need, required this.inBasket});
  final List<_Fruit> fruits;
  final int need, inBasket;

  void _emoji(Canvas canvas, String s, Offset c, double size) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          ).createShader(Offset.zero & size));

    // Basket.
    final bx = w * 0.5, by = h * 0.86;
    final bw = w * 0.42, bh = h * 0.2;
    final basket = Path()
      ..moveTo(bx - bw / 2, by - bh / 2)
      ..lineTo(bx - bw / 2 * 0.78, by + bh / 2)
      ..lineTo(bx + bw / 2 * 0.78, by + bh / 2)
      ..lineTo(bx + bw / 2, by - bh / 2)
      ..close();
    canvas.drawPath(basket, Paint()..color = const Color(0xFFA9744F));
    canvas.drawPath(
        basket,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF7A4E33));
    // Weave lines.
    final weave = Paint()
      ..color = const Color(0xFF7A4E33)
      ..strokeWidth = 2;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(bx - bw / 2 * (1 - i * 0.05), by - bh / 2 + bh * i / 4),
          Offset(bx + bw / 2 * (1 - i * 0.05), by - bh / 2 + bh * i / 4), weave);
    }
    // Big target number on the basket.
    _emoji(canvas, '$need', Offset(bx, by), 44);

    // Collected fruits peeking out of the basket.
    for (var i = 0; i < inBasket; i++) {
      final a = (i / math.max(1, need)) * 1.4 - 0.7;
      _emoji(canvas, '🍎', Offset(bx + a * bw * 0.4, by - bh / 2 - 6), 20);
    }

    // Loose fruits.
    for (final f in fruits) {
      if (f.collected) continue;
      _emoji(canvas, f.emoji, Offset(f.x * w, f.y * h), 38);
    }
  }

  @override
  bool shouldRepaint(_FruitBasketPainter oldDelegate) => true;
}
