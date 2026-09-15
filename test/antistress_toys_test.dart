import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harshivos/features/antistress/toys/bubble_wrap.dart';
import 'package:harshivos/features/antistress/toys/click_pen.dart';
import 'package:harshivos/features/antistress/toys/combo_lock.dart';
import 'package:harshivos/features/antistress/toys/dimmer_knob.dart';
import 'package:harshivos/features/antistress/toys/fidget_spinner.dart';
import 'package:harshivos/features/antistress/toys/gears.dart';
import 'package:harshivos/features/antistress/toys/keypad.dart';
import 'package:harshivos/features/antistress/toys/kinetic_dots.dart';
import 'package:harshivos/features/antistress/toys/latch_bolt.dart';
import 'package:harshivos/features/antistress/toys/lava_blobs.dart';
import 'package:harshivos/features/antistress/toys/newtons_cradle.dart';
import 'package:harshivos/features/antistress/toys/pendulum_waves.dart';
import 'package:harshivos/features/antistress/toys/pop_it.dart';
import 'package:harshivos/features/antistress/toys/rotary_dial.dart';
import 'package:harshivos/features/antistress/toys/sand_fall.dart';
import 'package:harshivos/features/antistress/toys/slinky.dart';
import 'package:harshivos/features/antistress/toys/spin_wheel.dart';
import 'package:harshivos/features/antistress/toys/stress_ball.dart';
import 'package:harshivos/features/antistress/toys/switch_board.dart';
import 'package:harshivos/features/antistress/toys/water_drop.dart';
import 'package:harshivos/features/antistress/toys/zipper.dart';

/// Every antistress toy must build, accept a drag, and survive a few animation
/// frames without throwing. These toys run continuous ticker loops, so we drive
/// them with explicit pumps (never pumpAndSettle) and tear down by replacing the
/// tree.
void main() {
  final builders = <String, Widget Function()>{
    'Pop It': PopItToy.new,
    'Bubble Wrap': BubbleWrapToy.new,
    'Stress Ball': StressBallToy.new,
    'Fidget Spinner': FidgetSpinnerToy.new,
    'Spin Wheel': SpinWheelToy.new,
    'Gears': GearsToy.new,
    'Switch Board': SwitchBoardToy.new,
    'Keypad': KeypadToy.new,
    'Click Pen': ClickPenToy.new,
    'Latch & Bolt': LatchBoltToy.new,
    'Zipper': ZipperToy.new,
    'Combo Lock': ComboLockToy.new,
    "Newton's Cradle": NewtonsCradleToy.new,
    'Slinky': SlinkyToy.new,
    'Pendulum Waves': PendulumWavesToy.new,
    'Lava Blobs': LavaBlobsToy.new,
    'Water Drops': WaterDropToy.new,
    'Dimmer Knob': DimmerKnobToy.new,
    'Falling Sand': SandFallToy.new,
    'Kinetic Dots': KineticDotsToy.new,
    'Rotary Dial': RotaryDialToy.new,
  };

  builders.forEach((name, build) {
    testWidgets('$name builds, accepts a drag, and does not throw',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: build())));
      await tester.pump(const Duration(milliseconds: 16));

      // A drag across the toy exercises the primary interaction.
      await tester.dragFrom(const Offset(250, 400), const Offset(120, 80));
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull, reason: '$name threw');

      // Replace the tree to dispose the continuous ticker cleanly.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
