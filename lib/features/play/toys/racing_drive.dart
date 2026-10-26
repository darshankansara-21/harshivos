part of 'mini_games.dart';

/// One driving step: gas builds speed, brake and grass bleed it off, and
/// steering changes heading instead of teleporting between lanes.
DriveStep stepDrive({
  required double x,
  required double y,
  required double heading,
  required double speed,
  required double steer,
  required bool accelerate,
  required bool brake,
  required double dt,
}) {
  final onRoad = driveOnRoad(x, y);
  var v = speed;
  if (accelerate && !brake) {
    v += (onRoad ? 240 : 50) * dt;
  }
  if (brake) v -= 420 * dt;
  v -= (onRoad ? 0.55 : 3.4) * v * dt;
  final maxSpeed = onRoad ? 250.0 : 70.0;
  if (v > maxSpeed) v = maxSpeed;
  if (v < 0) v = 0;
  final grip = onRoad ? 1.0 : 0.4;
  final turn = steer.clamp(-1.0, 1.0) * (1.1 + v / 220) * grip;
  // A straight hold stays on the racing line. A blend was not enough: on the
  // Pixel the car was on the grass and nearly stopped after a two-second
  // gas hold. Steering still leaves the line.
  var px = x;
  var py = y;
  var h = heading;
  if (steer.abs() < 0.15 && onRoad) {
    final theta = math.atan2(y / _trackB, x / _trackA);
    final line = Offset(_trackA * math.cos(theta), _trackB * math.sin(theta));
    final pull = math.min(1.0, dt * 8);
    px += (line.dx - px) * pull;
    py += (line.dy - py) * pull;
    h = ovalHeading(px, py);
  } else {
    h += turn * dt;
  }
  final nx = px + math.sin(h) * v * dt;
  final ny = py - math.cos(h) * v * dt;
  return DriveStep(x: nx, y: ny, heading: h, speed: v, onRoad: driveOnRoad(nx, ny));
}

/// Racing-line heading at a point on the oval, increasing around the lap.
double ovalHeading(double x, double y) {
  final theta = math.atan2(y / _trackB, x / _trackA);
  final tx = -_trackA * math.sin(theta);
  final ty = _trackB * math.cos(theta);
  return math.atan2(tx, -ty);
}

/// Pedal rectangles. A hold there must not also steer — a Pixel gas hold
/// was stolen by the full-screen pan and turned the car onto the grass.
bool raceTouchIsPedal(Offset local, Size size) {
  const width = 130.0;
  const height = 120.0;
  final top = size.height - 158 - height;
  return (local.dx < width && local.dy > top) ||
      (local.dx > size.width - width && local.dy > top);
}

/// Pedals and the center steer arrows. A drag there must not also steer.
bool raceTouchIsControl(Offset local, Size size) {
  if (raceTouchIsPedal(local, size)) return true;
  return local.dy > size.height - 250 &&
      (local.dx - size.width / 2).abs() < 96;
}

bool driveOnRoad(double x, double y) {
  final r = _trackRadius(x, y);
  return (r - 1).abs() <= 0.16;
}

double _trackRadius(double x, double y) {
  return math.sqrt((x / _trackA) * (x / _trackA) + (y / _trackB) * (y / _trackB));
}

const double _trackA = 420;
const double _trackB = 260;

/// Top-down frame that keeps the oval, including the road stroke, inside a
/// phone canvas. A chase zoom that only showed one clipped bend did not read
/// as a track.
class DriveFrame {
  const DriveFrame({required this.scale, required this.center});

  final double scale;
  final Offset center;
}

DriveFrame driveFrame(Size size) {
  // Portrait keeps the oval above the companion and pedals. Landscape is
  // short, so those same fixed margins crushed the track into a speck
  // under the score pill on a Pixel 6a held sideways.
  final landscape = size.width > size.height;
  final padTop = landscape ? 64.0 : 96.0;
  final padBottom = landscape ? 12.0 : 150.0;
  final padX = landscape ? 118.0 : 20.0;
  final availW = math.max(48.0, size.width - padX * 2);
  final availH = math.max(48.0, size.height - padTop - padBottom);
  const worldW = _trackA * 2 + 210;
  const worldH = _trackB * 2 + 210;
  final scale = math.min(availW / worldW, availH / worldH);
  return DriveFrame(
    scale: scale,
    center: Offset(size.width / 2, padTop + availH / 2),
  );
}

class DriveStep {
  const DriveStep({
    required this.x,
    required this.y,
    required this.heading,
    required this.speed,
    required this.onRoad,
  });

  final double x;
  final double y;
  final double heading;
  final double speed;
  final bool onRoad;
}

class _CupRival {
  _CupRival(this.theta, this.speed, this.scale, this.tint);
  double theta;
  double progress = 0;
  double speed;
  final double scale;
  final Color tint;
}

class RacingGame extends StatefulWidget {
  const RacingGame({super.key});
  @override
  State<RacingGame> createState() => _RacingGameState();
}

class _RacingGameState extends State<RacingGame>
    with TickerProviderStateMixin, ToyTicker, _CompanionEmitter {
  static const String _id = 'racing';
  static const double _lapsToWin = 2;
  static const double _lap = math.pi * 2;
  static const List<Color> _tints = <Color>[
    Color(0xFF4CC9F0),
    Color(0xFFFFD166),
    Color(0xFFB388FF),
  ];

  final List<_CupRival> _rivals = <_CupRival>[];
  double _x = 0;
  double _y = _trackB;
  double _heading = -math.pi / 2;
  double _speed = 0;
  double _steer = 0;
  double _steerHold = 0;
  double _gasPulse = 0;
  double _forward = 0;
  double _lastTheta = math.pi / 2;
  double _lights = 1.4;
  double _shuntT = 0;
  double _clock = 0;
  bool _gas = false;
  bool _brake = false;
  bool _reduceMotion = false;
  bool _greenPlayed = false;
  int _finishPlace = 0;
  int _score = 0;
  int _best = 0;
  GameStatus _status = GameStatus.ready;

  @override
  void initState() {
    super.initState();
    _resetTrack();
    GameScores.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _best = GameScores.instance.best(_id));
    });
  }

  void _resetTrack() {
    _x = 0;
    _y = _trackB;
    _heading = -math.pi / 2;
    _speed = 0;
    _steer = 0;
    _steerHold = 0;
    _gasPulse = 0;
    _forward = 0;
    _lastTheta = math.pi / 2;
    _lights = 1.4;
    _shuntT = 0;
    _clock = 0;
    _gas = false;
    _brake = false;
    _greenPlayed = false;
    _finishPlace = 0;
    _score = 0;
    _rivals
      ..clear()
      ..addAll(<_CupRival>[
        _CupRival(math.pi / 2 + 0.35, 150, 0.96, _tints[0]),
        _CupRival(math.pi / 2 + 0.7, 162, 1.02, _tints[1]),
        _CupRival(math.pi / 2 + 1.05, 146, 1.08, _tints[2]),
      ]);
    for (final r in _rivals) {
      r.progress = r.theta - math.pi / 2;
    }
  }

  int get _place {
    var ahead = 0;
    for (final r in _rivals) {
      if (r.progress > _forward) ahead++;
    }
    return ahead + 1;
  }

  int get _lapShown =>
      (_forward / _lap).floor().clamp(0, _lapsToWin.toInt() - 1) + 1;

  @override
  void onTick(double dt) {
    if (_status != GameStatus.playing) return;
    _clock += dt;
    if (_lights > 0) {
      _lights -= dt;
      if (_lights <= 0 && !_greenPlayed) {
        _greenPlayed = true;
        TonePlayer.instance.playCue(SoundCue.engine);
      }
      return;
    }
    if (_steerHold > 0 && _steerHold < 10) {
      _steerHold -= dt;
      if (_steerHold <= 0) _steer = 0;
    }
    if (_gasPulse > 0) _gasPulse -= dt;
    if (_shuntT > 0) _shuntT -= dt;
    final step = stepDrive(
      x: _x,
      y: _y,
      heading: _heading,
      speed: _speed,
      steer: _steer,
      accelerate: _gas || _gasPulse > 0,
      brake: _brake,
      dt: dt,
    );
    _x = step.x;
    _y = step.y;
    _heading = step.heading;
    _speed = step.speed;
    _noteProgress();
    _advanceRivals(dt);
    _collide();
    _score = (_forward * 12).round();
    if (_forward >= _lap * _lapsToWin || _clock > 50) _finish();
  }

  void _noteProgress() {
    final theta = math.atan2(_y / _trackB, _x / _trackA);
    var d = theta - _lastTheta;
    while (d > math.pi) {
      d -= _lap;
    }
    while (d < -math.pi) {
      d += _lap;
    }
    if (driveOnRoad(_x, _y) && d > 0) _forward += d;
    _lastTheta = theta;
  }

  void _advanceRivals(double dt) {
    for (final r in _rivals) {
      final radius = (_trackA + _trackB) / 2 * r.scale;
      final dTheta = r.speed / radius * dt;
      r.theta += dTheta;
      r.progress += dTheta;
    }
  }

  void _collide() {
    if (_shuntT > 0 || _speed < 30) return;
    for (final r in _rivals) {
      final p = _point(r.theta, r.scale);
      if ((p - Offset(_x, _y)).distance < 46) {
        _speed *= 0.55;
        _shuntT = 0.7;
        TonePlayer.instance.playCue(SoundCue.crash);
        return;
      }
    }
  }

  Offset _point(double theta, double scale) =>
      Offset(_trackA * scale * math.cos(theta), _trackB * scale * math.sin(theta));

  void _finish() {
    _finishPlace = _place;
    _status = _finishPlace == 1 ? GameStatus.won : GameStatus.over;
    _gas = false;
    _brake = false;
    TonePlayer.instance
        .playCue(_finishPlace == 1 ? SoundCue.success : SoundCue.gameOver);
    emit(_finishPlace == 1
        ? ExperienceEvent.gameCompleted
        : ExperienceEvent.incorrectAnswer);
    GameScores.instance.submit(_id, _score).then((b) {
      if (mounted) setState(() => _best = b);
    });
  }

  void _pulseGas() {
    if (_status != GameStatus.playing) return;
    _gasPulse = 0.45;
  }

  void _nudgeSteer(double steer) {
    if (_status != GameStatus.playing) return;
    _steer = steer;
    _steerHold = 0.28;
  }

  void _setPedal({required bool gas, required bool down}) {
    if (_status != GameStatus.playing) return;
    if (gas) {
      _gas = down;
    } else {
      _brake = down;
    }
  }

  void _holdSteer(double value) {
    setState(() {
      _steer = value;
      _steerHold = value == 0 ? 0 : 99;
      if (value == 0) _steer = 0;
    });
  }

  void _reset() {
    setState(() {
      _resetTrack();
      _status = GameStatus.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    drainCompanion(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final kmh = (_speed * 0.85).round();
    final banner = _lights > 0.9
        ? 'Red — get ready'
        : _lights > 0
            ? 'Green soon'
            : 'Lap $_lapShown/2 · ${kmh} km/h · P$_place'
                '${driveOnRoad(_x, _y) ? '' : ' · grass'}';
    return _GameShell(
      title: '🏎️ Track Racer',
      score: _score,
      best: _best,
      status: _status,
      banner: banner,
      overEmoji: '🏁',
      overText: _finishPlace > 0 ? 'Finished P$_finishPlace' : 'Race on',
      winEmoji: '🏆',
      winText: 'P$_finishPlace — two laps, you drove it',
      accent: const Color(0xFFFF6B6B),
      introHow: 'Hold Gas. Use the arrows to pass.\n'
          'Brake to slow down. Stay on the grey road — grass kills speed. '
          'Finish 2 laps ahead of the other cars.',
      onStart: () => setState(() => _status = GameStatus.playing),
      onPlayAgain: _reset,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Semantics(
            label: 'Lap $_lapShown of 2. Steer, accelerate, or brake.',
            customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
              const CustomSemanticsAction(label: 'Steer left'): () =>
                  _nudgeSteer(-1),
              const CustomSemanticsAction(label: 'Steer right'): () =>
                  _nudgeSteer(1),
              const CustomSemanticsAction(label: 'Accelerate'): _pulseGas,
              const CustomSemanticsAction(label: 'Brake'): () =>
                  _setPedal(gas: false, down: true),
            },
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      if (raceTouchIsControl(d.localPosition, Size(w, h))) return;
                      _nudgeSteer(d.localPosition.dx < w / 2 ? -1 : 1);
                    },
                    onPanUpdate: (d) {
                      if (raceTouchIsControl(d.localPosition, Size(w, h))) return;
                      _nudgeSteer((d.delta.dx / 14).clamp(-1.0, 1.0));
                    },
                    child: CustomPaint(
                      size: Size(w, h),
                      painter: _DrivePainter(
                        x: _x,
                        y: _y,
                        heading: _heading,
                        steer: _steer,
                        lights: _lights,
                        speed: _speed,
                        reduceMotion: _reduceMotion,
                        rivals: _rivals,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 158,
                  child: _Pedal(
                    label: 'Brake',
                    color: const Color(0xFFEF476F),
                    down: _brake,
                    onChanged: (down) => _setPedal(gas: false, down: down),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 168,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _SteerPad(
                        icon: Icons.chevron_left_rounded,
                        down: _steer < -0.2,
                        onChanged: (down) => _holdSteer(down ? -1 : 0),
                      ),
                      const SizedBox(width: 14),
                      _SteerPad(
                        icon: Icons.chevron_right_rounded,
                        down: _steer > 0.2,
                        onChanged: (down) => _holdSteer(down ? 1 : 0),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 158,
                  child: _Pedal(
                    label: 'Gas',
                    color: const Color(0xFF06D6A0),
                    down: _gas,
                    onChanged: (down) => _setPedal(gas: true, down: down),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Pedal extends StatelessWidget {
  const _Pedal({
    required this.label,
    required this.color,
    required this.down,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final bool down;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 92,
        height: down ? 64 : 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: down ? color : color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _SteerPad extends StatelessWidget {
  const _SteerPad({
    required this.icon,
    required this.down,
    required this.onChanged,
  });

  final IconData icon;
  final bool down;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: down ? const Color(0xFFFFF3BF) : const Color(0xF21B1E27),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: down ? Colors.black : Colors.white, size: 36),
      ),
    );
  }
}

class _DrivePainter extends CustomPainter {
  _DrivePainter({
    required this.x,
    required this.y,
    required this.heading,
    required this.steer,
    required this.lights,
    required this.speed,
    required this.reduceMotion,
    required this.rivals,
  });

  final double x;
  final double y;
  final double heading;
  final double steer;
  final double lights;
  final double speed;
  final bool reduceMotion;
  final List<_CupRival> rivals;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF3E7D2C));
    for (var i = 0.0; i < size.width; i += 36) {
      canvas.drawRect(
        Rect.fromLTWH(i, 0, 18, size.height),
        Paint()..color = const Color(0xFF4C9A38).withOpacity(0.28),
      );
    }
    if (reduceMotion) {
      final frame = driveFrame(size);
      canvas.save();
      canvas.translate(frame.center.dx, frame.center.dy);
      canvas.scale(frame.scale);
      _drawWorld(canvas);
      _drawCars(canvas);
      canvas.restore();
      return;
    }
    final landscape = size.width > size.height;
    final focus = Offset(
      size.width / 2,
      landscape ? size.height * 0.46 : size.height * 0.54,
    );
    final scale = landscape
        ? (size.height / 560).clamp(0.48, 0.95)
        : (size.shortestSide / 420).clamp(0.85, 1.35);
    canvas.save();
    canvas.translate(focus.dx, focus.dy);
    canvas.scale(scale);
    canvas.rotate(-heading);
    canvas.translate(-x, -y);
    _drawWorld(canvas);
    _drawCars(canvas);
    canvas.restore();
    _minimap(canvas, size);
  }

  void _drawWorld(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: _trackA * 2.8, height: _trackB * 3.1),
      Paint()..color = const Color(0xFF2F6B28),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: _trackA * 2 - 170,
        height: _trackB * 2 - 150,
      ),
      Paint()..color = const Color(0xFF7CB342),
    );
    canvas.drawCircle(Offset.zero, 78, Paint()..color = const Color(0xFF2E7D4F));
    canvas.drawCircle(
      Offset.zero,
      46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white24,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: _trackA * 2, height: _trackB * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 188
        ..color = Colors.white,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: _trackA * 2, height: _trackB * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 168
        ..color = const Color(0xFF2C313C),
    );
    for (var i = 0; i < 42; i++) {
      if (i.isOdd) continue;
      final t = i / 42 * math.pi * 2;
      final p = Offset(_trackA * math.cos(t), _trackB * math.sin(t));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(math.atan2(-_trackA * math.sin(t), _trackB * math.cos(t)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 28, height: 6),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white70,
      );
      canvas.restore();
    }
    for (var i = 0; i < 56; i++) {
      final t = i / 56 * math.pi * 2;
      final outer = Offset(_trackA * 1.2 * math.cos(t), _trackB * 1.28 * math.sin(t));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: outer, width: 16, height: 8),
          const Radius.circular(2),
        ),
        Paint()..color = i.isEven ? const Color(0xFFE53935) : Colors.white,
      );
    }
    const trees = <Offset>[
      Offset(-520, -80),
      Offset(-470, 180),
      Offset(500, -40),
      Offset(460, 200),
      Offset(-80, -390),
      Offset(160, -370),
      Offset(-200, 390),
      Offset(220, 400),
    ];
    for (final tree in trees) {
      canvas.drawCircle(tree.translate(3, 8), 16, Paint()..color = const Color(0xFF1B3A1A));
      canvas.drawCircle(tree, 22, Paint()..color = const Color(0xFF1B5E20));
      canvas.drawCircle(tree.translate(-6, -8), 14, Paint()..color = const Color(0xFF43A047));
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -390), width: 260, height: 42),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF37474F),
    );
    for (var seat = -90.0; seat <= 90; seat += 22) {
      canvas.drawCircle(
        Offset(seat, -390),
        6,
        Paint()..color = seat.abs() < 30 ? const Color(0xFFFFD166) : const Color(0xFF90A4AE),
      );
    }
    const finish = Offset(0, _trackB);
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(
        Rect.fromLTWH(finish.dx - 56 + i * 14, finish.dy - 8, 14, 8),
        Paint()..color = i.isEven ? Colors.white : Colors.black,
      );
      canvas.drawRect(
        Rect.fromLTWH(finish.dx - 56 + i * 14, finish.dy, 14, 8),
        Paint()..color = i.isEven ? Colors.black : Colors.white,
      );
    }
    if (lights > 0) {
      const gantry = Offset(-70, _trackB);
      canvas.drawLine(
        gantry + const Offset(0, -70),
        gantry + const Offset(0, 70),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      final lit = lights > 0.9 ? 0 : 1;
      const colors = <Color>[Color(0xFFEF476F), Color(0xFF06D6A0)];
      for (var i = 0; i < 2; i++) {
        canvas.drawCircle(
          gantry + Offset(0, -28 + i * 36),
          12,
          Paint()..color = i == lit ? colors[i] : const Color(0xFF1B1E27),
        );
      }
    }
  }

  void _drawCars(Canvas canvas) {
    for (final r in rivals) {
      final p = Offset(
        _trackA * r.scale * math.cos(r.theta),
        _trackB * r.scale * math.sin(r.theta),
      );
      final dx = -math.sin(r.theta);
      final dy = math.cos(r.theta);
      _car(canvas, p, math.atan2(dx, -dy), r.tint, 1);
    }
    if (!reduceMotion && speed > 70) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(heading);
      final streak = Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(-16 + i * 16, 36),
          Offset(-16 + i * 16, 36 + 18 + speed / 18),
          streak,
        );
      }
      canvas.restore();
    }
    _car(canvas, Offset(x, y), heading + (reduceMotion ? 0 : steer * 0.18), const Color(0xFFFF5252), 1.15);
  }

  void _minimap(Canvas canvas, Size size) {
    final map = Rect.fromLTWH(16, size.height * 0.30, 108, 68);
    canvas.drawRRect(
      RRect.fromRectAndRadius(map, const Radius.circular(12)),
      Paint()..color = const Color(0xCC102016),
    );
    final center = map.center;
    final sx = map.width / (_trackA * 2.4);
    final sy = map.height / (_trackB * 2.6);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: _trackA * 2 * sx, height: _trackB * 2 * sy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF90A4AE),
    );
    for (final r in rivals) {
      canvas.drawCircle(
        center + Offset(_trackA * r.scale * math.cos(r.theta) * sx, _trackB * r.scale * math.sin(r.theta) * sy),
        3,
        Paint()..color = r.tint,
      );
    }
    canvas.drawCircle(
      center + Offset(x * sx, y * sy),
      4,
      Paint()..color = const Color(0xFFFF5252),
    );
  }

  void _car(Canvas canvas, Offset at, double angle, Color color, double scale) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    _body(canvas, color, scale);
    canvas.restore();
  }

  void _body(Canvas canvas, Color color, double scale) {
    final s = scale * 1.7;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 6 * s), width: 28 * s, height: 12 * s),
      Paint()..color = Colors.black38,
    );
    final wheel = Paint()..color = const Color(0xFF1A1A1A);
    final rim = Paint()..color = const Color(0xFFECEFF1);
    for (final spot in <Offset>[
      Offset(-13 * s, -16 * s),
      Offset(13 * s, -16 * s),
      Offset(-14 * s, 14 * s),
      Offset(14 * s, 14 * s),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: spot, width: 8 * s, height: 12 * s),
          Radius.circular(3 * s),
        ),
        wheel,
      );
      canvas.drawCircle(spot, 2.2 * s, rim);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, 18 * s), width: 30 * s, height: 6 * s),
        Radius.circular(2 * s),
      ),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 22 * s, height: 40 * s),
        Radius.circular(8 * s),
      ),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, 2 * s), width: 12 * s, height: 12 * s),
        Radius.circular(4 * s),
      ),
      Paint()..color = const Color(0xFF102027),
    );
    canvas.drawCircle(Offset(0, 1 * s), 3.2 * s, Paint()..color = const Color(0xFFFFE082));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -20 * s), width: 16 * s, height: 8 * s),
        Radius.circular(2 * s),
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_DrivePainter oldDelegate) => true;
}
