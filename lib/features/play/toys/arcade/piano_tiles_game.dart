part of '../arcade_games.dart';

class PianoTilesGame extends StatefulWidget {
  const PianoTilesGame({super.key});
  @override
  State<PianoTilesGame> createState() => _PianoTilesGameState();
}

class _PRow {
  _PRow(this.col, this.y, this.note);
  final int col;
  double y;
  final int note;
}

class _PianoTilesGameState extends State<PianoTilesGame>
    with TickerProviderStateMixin, ToyTicker, _Emit {
  static const String _id = 'piano_tiles';
  static const int _cols = 4;
  static const double _gap = 0.26;
  // A gentle pentatonic motif — tapping tiles in time plays a real little tune.
  static const List<int> _melody = <int>[
    0, 2, 4, 7, 4, 2, 0, 2, 4, 5, 7, 9, 7, 5, 4, 2
  ];
  final math.Random _rnd = math.Random();
  final List<_PRow> _rows = <_PRow>[];
  int _mPos = 0;
  int _flashCol = -1;
  double _flashT = 0;
  double _speed = 0.42;
  double _spawnIn = 0;
  int _score = 0;
  int _best = 0;
  int _lastCol = -1;
  // Every other audited game in the catalog flashes a celebratory banner at
  // score milestones (whack's 'Round N!', star_tap's 'Combo xN!', etc.) —
  // Piano Tiles, the Phase-5 benchmark game, had none at all: its only
  // in-run feedback was a 0.26s column-color flash + note sound, so a child
  // climbing toward a new personal best got zero acknowledgement of it.
  String? _banner;
  double _bannerT = 0;
  int _lastMilestone = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 4; i++) {
      _rows.add(_spawnRow(-0.05 - i * _gap));
    }
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  _PRow _spawnRow(double y) {
    final row = _PRow(_pickCol(), y, _melody[_mPos % _melody.length]);
    _mPos++;
    return row;
  }

  int _pickCol() {
    var c = _rnd.nextInt(_cols);
    if (c == _lastCol) c = (c + 1) % _cols;
    _lastCol = c;
    return c;
  }

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    if (_flashT > 0) _flashT -= dt;
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }
    for (final r in _rows) {
      r.y += _speed * dt;
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnIn = _gap / _speed;
      _rows.add(_spawnRow(-0.08));
    }
    for (final r in _rows) {
      if (r.y > 1.02) {
        _gameOver();
        return;
      }
    }
  }

  void _tapCol(int c) {
    if (_status != GameStatus.playing) return;
    _PRow? target;
    for (final r in _rows) {
      if (r.y > 0.04 && (target == null || r.y > target.y)) target = r;
    }
    if (target == null) return;
    if (target.col == c) {
      _rows.remove(target);
      _score++;
      TonePlayer.instance.playNote(target.note, seconds: 0.22);
      _flashCol = c;
      _flashT = 0.26;
      emit(ExperienceEvent.bubblePopped);
      _speed = math.min(0.95, _speed + 0.006);
      // Milestone banners every 10 tiles, matching the celebratory-progress
      // pattern every other audited arcade game already uses.
      if (_score ~/ 10 > _lastMilestone) {
        _lastMilestone = _score ~/ 10;
        _flash(_speed >= 0.9 ? '$_score tiles! Presto! 🎹' : '$_score tiles! 🎵');
        TonePlayer.instance.playCue(SoundCue.milestone);
      }
      GameScores.instance.submit(_id, _score).then((b) {
        if (mounted && b != _best) setState(() => _best = b);
      });
    } else {
      _gameOver();
    }
  }

  void _flash(String s) {
    _banner = s;
    _bannerT = 1.1;
  }

  void _gameOver() {
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

  void _reset() {
    setState(() {
      _rows.clear();
      _speed = 0.42;
      _spawnIn = 0;
      _score = 0;
      _lastCol = -1;
      _mPos = 0;
      _flashCol = -1;
      _flashT = 0;
      _banner = null;
      _bannerT = 0;
      _lastMilestone = 0;
      _status = GameStatus.playing;
      for (var i = 0; i < 4; i++) {
        _rows.add(_spawnRow(-0.05 - i * _gap));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    drain(context);
    return _Shell(
      title: '🎹 Piano Tiles',
      introHow:
          'Tap the glowing tile sliding down each lane — it plays the tune as you go. Don’t miss one!',
      onStart: () => setState(() => _status = GameStatus.playing),
      score: _score,
      best: _best,
      status: _status,
      banner: _banner,
      overEmoji: '🎹',
      overText: 'Missed a tile!',
      accent: const Color(0xFF9B5DE5),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tapCol(
                (d.localPosition.dx / c.maxWidth * _cols)
                    .floor()
                    .clamp(0, _cols - 1)),
            child: CustomPaint(
              painter: _PianoPainter(_rows, _cols, _flashCol, _flashT),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _PianoPainter extends CustomPainter {
  _PianoPainter(this.rows, this.cols, this.flashCol, this.flashT);
  final List<_PRow> rows;
  final int cols;
  final int flashCol;
  final double flashT;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF4F1FB));
    final cw = size.width / cols;
    final div = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (var i = 1; i < cols; i++) {
      canvas.drawLine(Offset(cw * i, 0), Offset(cw * i, size.height), div);
    }
    // Column hit-flash so every note lands with a visible pulse.
    if (flashCol >= 0 && flashT > 0) {
      final k = (flashT / 0.26).clamp(0.0, 1.0);
      canvas.drawRect(
          Rect.fromLTWH(flashCol * cw, 0, cw, size.height),
          Paint()..color = const Color(0xFF9B5DE5).withOpacity(0.22 * k));
    }
    final th = size.height * 0.22;
    for (final r in rows) {
      final x = r.col * cw;
      final y = r.y * size.height - th;
      // Tile hue rises with its pitch so the child sees the melody climb.
      final hue = 250 + r.note * 9.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 4, y, cw - 8, th - 6), const Radius.circular(8)),
        Paint()..color = HSVColor.fromAHSV(1, hue % 360, 0.45, 0.42).toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(_PianoPainter oldDelegate) => true;
}

// ===========================================================================
// Block Blast — pick a block piece and tap where it goes on the 8×8 grid. Fill
// a whole row or column to clear it and score big. When no piece fits, the
// board is done. A calm spatial puzzle.
// ===========================================================================
