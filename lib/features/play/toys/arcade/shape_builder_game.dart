part of '../arcade_games.dart';

/// Shape Builder — assemble the picture by tapping the slot that matches each
/// piece. Houses, rockets and more. Build five to win.
class ShapeBuilderGame extends StatefulWidget {
  const ShapeBuilderGame({super.key});
  @override
  State<ShapeBuilderGame> createState() => _ShapeBuilderGameState();
}

class _BuildSlot {
  _BuildSlot(this.shape, this.cx, this.cy, this.r, this.color);
  final int shape;
  final double cx, cy, r;
  final Color color;
  bool filled = false;
}

class _ShapeBuilderGameState extends State<ShapeBuilderGame> with _Emit {
  static const String _id = 'shape_builder';
  static const int _target = 5;
  final math.Random _rnd = math.Random();
  List<_BuildSlot> _slots = <_BuildSlot>[];
  List<int> _order = <int>[];
  final List<int> _figOrder = <int>[0, 1, 2, 3, 4];
  int _placed = 0;
  int _fig = 0;
  int _score = 0;
  int _best = 0;
  int _wrongFlash = -1;
  String? _banner;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  // shapes: 0 circle,1 square,2 triangle,3 star,4 heart,5 diamond
  void _buildFigure() {
    final figs = <List<_BuildSlot>>[
      // House
      <_BuildSlot>[
        _BuildSlot(1, 0.5, 0.56, 0.16, const Color(0xFFFFD166)),
        _BuildSlot(2, 0.5, 0.33, 0.18, const Color(0xFFFF6B6B)),
      ],
      // Rocket
      <_BuildSlot>[
        _BuildSlot(2, 0.5, 0.22, 0.12, const Color(0xFFFF6B6B)),
        _BuildSlot(1, 0.5, 0.45, 0.13, const Color(0xFF66D9E8)),
        _BuildSlot(5, 0.5, 0.68, 0.14, const Color(0xFFFFD166)),
      ],
      // Tree
      <_BuildSlot>[
        _BuildSlot(2, 0.5, 0.3, 0.16, const Color(0xFF63E6BE)),
        _BuildSlot(2, 0.5, 0.48, 0.2, const Color(0xFF63E6BE)),
        _BuildSlot(1, 0.5, 0.72, 0.08, const Color(0xFF8A5A2B)),
      ],
      // Flower
      <_BuildSlot>[
        _BuildSlot(0, 0.5, 0.4, 0.1, const Color(0xFFFFD166)),
        _BuildSlot(4, 0.32, 0.4, 0.1, const Color(0xFFFF6B6B)),
        _BuildSlot(4, 0.68, 0.4, 0.1, const Color(0xFFFF6B6B)),
        _BuildSlot(1, 0.5, 0.68, 0.06, const Color(0xFF63E6BE)),
      ],
      // Star badge
      <_BuildSlot>[
        _BuildSlot(0, 0.5, 0.45, 0.2, const Color(0xFF66D9E8)),
        _BuildSlot(3, 0.5, 0.45, 0.12, const Color(0xFFFFD166)),
      ],
    ];
    _slots = figs[_figOrder[_fig % _figOrder.length]];
    for (final s in _slots) {
      s.filled = false;
    }
    _order = List<int>.generate(_slots.length, (i) => i);
    _placed = 0;
    _wrongFlash = -1;
  }

  int get _currentShape =>
      _placed < _order.length ? _slots[_order[_placed]].shape : -1;

  void _tap(Offset p, double w, double h) {
    if (_status != GameStatus.playing || _placed >= _slots.length) return;
    for (var i = 0; i < _slots.length; i++) {
      final s = _slots[i];
      if (s.filled) continue;
      if ((s.cx - p.dx / w).abs() < s.r + 0.03 &&
          (s.cy - p.dy / h).abs() < s.r + 0.03) {
        if (s.shape == _currentShape) {
          s.filled = true;
          _placed++;
          TonePlayer.instance.playNote(2 + _placed * 2, seconds: 0.16);
          if (_placed >= _slots.length) {
            _score++;
            TonePlayer.instance.playCue(SoundCue.success);
            emit(ExperienceEvent.bubblePopped);
            _banner = 'Built it! 🛠️';
            GameScores.instance.submit(_id, _score).then((b) {
              if (mounted) setState(() => _best = b);
            });
            if (_score >= _target) {
              _status = GameStatus.won;
              TonePlayer.instance.playCue(SoundCue.gameStart);
              emit(ExperienceEvent.gameCompleted);
            } else {
              _fig++;
              _buildFigure();
            }
          }
          setState(() {});
        } else {
          setState(() => _wrongFlash = i);
          TonePlayer.instance.playCue(SoundCue.gentleRetry);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && _wrongFlash == i) setState(() => _wrongFlash = -1);
          });
        }
        return;
      }
    }
  }

  void _reset() {
    setState(() {
      _score = 0;
      _fig = 0;
      _figOrder.shuffle(_rnd);
      _banner = null;
      _buildFigure();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    if (_slots.isEmpty) _buildFigure();
    return _Shell(
      title: '🛠️ Shape Builder',
      introHow:
          'A piece appears at the bottom. Tap the matching empty slot to place it and build the picture!',
      onStart: () => setState(() {
        _figOrder.shuffle(_rnd);
        _buildFigure();
        _status = GameStatus.playing;
      }),
      score: _score,
      best: _best,
      target: _target,
      status: _status,
      banner: _banner ?? 'Place the piece',
      winEmoji: '🛠️',
      winText: 'Master builder!',
      accent: const Color(0xFFFFD166),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tap(d.localPosition, w, h),
            child: CustomPaint(
              painter: _BuilderPainter(
                slots: _slots,
                currentShape: _currentShape,
                wrongFlash: _wrongFlash,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _BuilderPainter extends CustomPainter {
  _BuilderPainter({
    required this.slots,
    required this.currentShape,
    required this.wrongFlash,
  });
  final List<_BuildSlot> slots;
  final int currentShape, wrongFlash;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF26314A), Color(0xFF161C2C)],
          ).createShader(Offset.zero & size));
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      final c = Offset(s.cx * w, s.cy * h);
      final r = s.r * w;
      if (s.filled) {
        _paintPolyShape(canvas, c, r, s.shape, Paint()..color = s.color);
      } else {
        _paintPolyShape(
            canvas,
            c,
            r,
            s.shape,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = wrongFlash == i
                  ? const Color(0xFFE23B3B)
                  : Colors.white.withOpacity(0.4));
      }
    }
    // Current piece tray.
    if (currentShape >= 0) {
      final tray = Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.9), width: w * 0.9, height: h * 0.16);
      canvas.drawRRect(
          RRect.fromRectAndRadius(tray, const Radius.circular(16)),
          Paint()..color = Colors.white.withOpacity(0.08));
      _paintPolyShape(canvas, tray.center, h * 0.05, currentShape,
          Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_BuilderPainter old) => true;
}

