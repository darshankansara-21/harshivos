import 'dart:math' as math;

import 'package:flutter/material.dart';
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

  test('the race camera keeps the whole oval on a phone canvas', () {
    void expectFits(Size size) {
      final frame = driveFrame(size);
      const halfW = 420 + 95;
      const halfH = 260 + 95;
      final left = frame.center.dx - halfW * frame.scale;
      final right = frame.center.dx + halfW * frame.scale;
      final top = frame.center.dy - halfH * frame.scale;
      final bottom = frame.center.dy + halfH * frame.scale;
      expect(left, greaterThan(4), reason: '$size left');
      expect(right, lessThan(size.width - 4), reason: '$size right');
      expect(top, greaterThan(4), reason: '$size top');
      expect(bottom, lessThan(size.height - 4), reason: '$size bottom');
      expect(
        halfH * 2 * frame.scale,
        greaterThan(size.shortestSide * 0.45),
        reason: '$size must not shrink the oval into a speck',
      );
    }

    expectFits(const Size(411, 820));
    expectFits(const Size(914, 411));
  });

  test('holding gas follows the oval instead of driving onto the grass', () {
    var x = 0.0;
    var y = 260.0;
    var heading = -math.pi / 2;
    var speed = 0.0;
    for (var i = 0; i < 40; i++) {
      final step = stepDrive(
        x: x,
        y: y,
        heading: heading,
        speed: speed,
        steer: 0,
        accelerate: true,
        brake: false,
        dt: 0.05,
      );
      x = step.x;
      y = step.y;
      heading = step.heading;
      speed = step.speed;
      expect(step.onRoad, isTrue, reason: 'step $i');
    }
    expect(speed, greaterThan(80));
    for (final dt in <double>[0.016, 0.099]) {
      x = 0;
      y = 260;
      heading = -math.pi / 2;
      speed = 0;
      for (var i = 0; i < (6 / dt).floor(); i++) {
        final step = stepDrive(
          x: x,
          y: y,
          heading: heading,
          speed: speed,
          steer: 0,
          accelerate: true,
          brake: false,
          dt: dt,
        );
        x = step.x;
        y = step.y;
        heading = step.heading;
        speed = step.speed;
        expect(step.onRoad, isTrue, reason: 'dt $dt step $i');
      }
      expect(speed, greaterThan(150));
    }
  });

  test('a gas or brake hold is not also a steer', () {
    const landscape = Size(914, 411);
    expect(raceTouchIsPedal(const Offset(850, 216), landscape), isTrue);
    expect(raceTouchIsPedal(const Offset(40, 220), landscape), isTrue);
    expect(raceTouchIsPedal(const Offset(457, 200), landscape), isFalse);
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

  test('landscape goalkeeper pitch stays clear of chrome and the side HUD', () {
    const phone = Size(914, 411);
    final pitch = keeperPitchRect(phone);
    expect(pitch.top, greaterThanOrEqualTo(64));
    expect(pitch.bottom, lessThan(phone.height - 24));
    expect(pitch.left, greaterThan(120));
    expect(pitch.right, lessThan(phone.width - 160));
    final goalTop = pitch.top + pitch.height * 0.12;
    final goalLine = pitch.top + pitch.height * 0.34;
    final kicker = pitch.top + pitch.height * 0.9;
    expect(goalTop, greaterThan(80));
    expect(goalLine - goalTop, greaterThan(48));
    expect(kicker, lessThan(phone.height - 36));
    expect(keeperPitchRect(const Size(411, 820)), const Offset(0, 0) & const Size(411, 820));
  });
}
