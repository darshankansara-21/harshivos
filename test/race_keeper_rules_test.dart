import 'package:flutter_test/flutter_test.dart';
import 'package:harshivos/features/play/toys/goal_games.dart';
import 'package:harshivos/features/play/toys/mini_games.dart';

void main() {
  test('a lane tap is not a dodge until the car visually overlaps the new lane', () {
    expect(
      racingTrafficHits(playerLane: 1.0, trafficLane: 1, trafficY: 0.85),
      isTrue,
    );
    // Just after a tap toward the right lane the eased car is still in danger.
    expect(
      racingTrafficHits(playerLane: 1.2, trafficLane: 1, trafficY: 0.85),
      isTrue,
    );
    expect(
      racingTrafficHits(playerLane: 1.7, trafficLane: 1, trafficY: 0.85),
      isFalse,
    );
    expect(
      racingTrafficHits(playerLane: 1.0, trafficLane: 1, trafficY: 0.5),
      isFalse,
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
