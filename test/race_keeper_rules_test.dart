import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/goal_games.dart';
import 'package:harshivos/features/play/toys/mini_games.dart';

void main() {
  test('gas builds speed, brake and grass take it away, steering turns the car', () {
    const start = DriveStep(x: 0, y: 260, heading: -1.5708, speed: 0, onRoad: true);
    final gas = stepDrive(
      x: start.x,
      y: start.y,
      heading: start.heading,
      speed: start.speed,
      steer: 0,
      accelerate: true,
      brake: false,
      dt: 0.4,
    );
    expect(gas.speed, greaterThan(40));
    expect(driveOnRoad(0, 260), isTrue);
    final braked = stepDrive(
      x: gas.x,
      y: gas.y,
      heading: gas.heading,
      speed: gas.speed,
      steer: 0,
      accelerate: false,
      brake: true,
      dt: 0.3,
    );
    expect(braked.speed, lessThan(gas.speed));
    final turned = stepDrive(
      x: 0,
      y: 260,
      heading: 0,
      speed: 120,
      steer: 1,
      accelerate: true,
      brake: false,
      dt: 0.3,
    );
    expect(turned.heading, greaterThan(0.2));
    final grass = stepDrive(
      x: 0,
      y: 0,
      heading: 0,
      speed: 200,
      steer: 0,
      accelerate: true,
      brake: false,
      dt: 0.5,
    );
    expect(grass.onRoad, isFalse);
    expect(grass.speed, lessThan(120));
  });

  test('the fruit basket slides toward a touch instead of teleporting', () {
    final moved = basketSlide(
      current: 0.2,
      target: 0.8,
      dt: 0.05,
      reduceMotion: false,
    );
    expect(moved, greaterThan(0.2));
    expect(moved, lessThan(0.8));
    expect(
      basketSlide(current: 0.2, target: 0.8, dt: 0.05, reduceMotion: true),
      0.8,
    );
  });

  test('goalkeeper saves require both line and height', () {
    expect(
      keeperMakesSave(
        ballX: 0.5,
        keeperX: 0.5,
        reach: 0.15,
        shotHeight: 0,
        keeperJump: 0,
      ),
      isTrue,
    );
    expect(
      keeperMakesSave(
        ballX: 0.8,
        keeperX: 0.5,
        reach: 0.15,
        shotHeight: 0,
        keeperJump: 0,
      ),
      isFalse,
    );
    expect(
      keeperMakesSave(
        ballX: 0.5,
        keeperX: 0.5,
        reach: 0.15,
        shotHeight: 1,
        keeperJump: 0.2,
      ),
      isFalse,
      reason: 'a chip goes over a grounded keeper',
    );
    expect(
      keeperMakesSave(
        ballX: 0.5,
        keeperX: 0.5,
        reach: 0.15,
        shotHeight: 1,
        keeperJump: 0.8,
      ),
      isTrue,
    );
    expect(
      keeperMakesSave(
        ballX: 0.5,
        keeperX: 0.5,
        reach: 0.15,
        shotHeight: 0,
        keeperJump: 0.9,
      ),
      isFalse,
      reason: 'leaping over a ground shot is a miss',
    );
  });
}
