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
  final h = heading + turn * dt;
  final nx = x + math.sin(h) * v * dt;
  final ny = y - math.cos(h) * v * dt;
  return DriveStep(x: nx, y: ny, heading: h, speed: v, onRoad: driveOnRoad(nx, ny));
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
  const padTop = 108.0;
  const padBottom = 248.0;
  const padX = 28.0;
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
    if (_steerHold > 0) {
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
        ? 'Red — hold the wheel'
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
      introHow: 'Hold Gas to build speed and Brake to slow down.\n'
          'Drag left or right to steer around the oval. '
          'Stay on the grey road — grass kills your speed. '
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
                    onTapDown: (d) => _nudgeSteer(d.localPosition.dx < w / 2 ? -1 : 1),
                    onPanUpdate: (d) {
                      if (d.localPosition.dy > h - 250) return;
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
    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
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

class _DrivePainter extends CustomPainter {
  _DrivePainter({
    required this.x,
    required this.y,
    required this.heading,
    required this.steer,
    required this.lights,
    required this.reduceMotion,
    required this.rivals,
  });

  final double x;
  final double y;
  final double heading;
  final double steer;
  final double lights;
  final bool reduceMotion;
  final List<_CupRival> rivals;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF7CB342),
    );
    final frame = driveFrame(size);
    canvas.save();
    canvas.translate(frame.center.dx, frame.center.dy);
    canvas.scale(frame.scale);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: _trackA * 2.7, height: _trackB * 2.9),
      Paint()..color = const Color(0xFF8BC34A),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: _trackA * 2 - 150,
        height: _trackB * 2 - 150,
      ),
      Paint()..color = const Color(0xFF9CCC65),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: _trackA * 2, height: _trackB * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 150
        ..color = const Color(0xFF3A4150),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: _trackA * 2, height: _trackB * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white70,
    );
    const finish = Offset(0, _trackB);
    canvas.drawLine(
      finish + const Offset(-70, 0),
      finish + const Offset(70, 0),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 10,
    );
    for (final r in rivals) {
      final p = Offset(
        _trackA * r.scale * math.cos(r.theta),
        _trackB * r.scale * math.sin(r.theta),
      );
      final dx = -math.sin(r.theta);
      final dy = math.cos(r.theta);
      _car(canvas, p, math.atan2(dx, -dy), r.tint, 0.85);
    }
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(heading + (reduceMotion ? 0 : steer * 0.18));
    _body(canvas, const Color(0xFFFF6B6B), 1.15);
    canvas.restore();
    if (lights > 0) {
      final lit = lights > 0.9 ? 0 : 1;
      const colors = <Color>[Color(0xFFEF476F), Color(0xFF06D6A0)];
      for (var i = 0; i < 2; i++) {
        canvas.drawCircle(
          Offset(-28 + i * 56, -18),
          16,
          Paint()..color = i == lit ? colors[i] : const Color(0xFF1B1E27),
        );
      }
    }
    canvas.restore();
  }

  void _car(Canvas canvas, Offset at, double angle, Color color, double scale) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    _body(canvas, color, scale);
    canvas.restore();
  }

  void _body(Canvas canvas, Color color, double scale) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 0), width: 28 * scale, height: 48 * scale),
        Radius.circular(8 * scale),
      ),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -8 * scale), width: 16 * scale, height: 14 * scale),
        Radius.circular(3 * scale),
      ),
      Paint()..color = const Color(0xFFD6F3FF),
    );
  }

  @override
  bool shouldRepaint(_DrivePainter oldDelegate) => true;
}
