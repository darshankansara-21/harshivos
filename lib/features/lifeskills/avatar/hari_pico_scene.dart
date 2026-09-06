import 'package:flutter/material.dart';

import 'avatar.dart';
import 'pico.dart';

/// Reusable relationship states for Hari and Pico. The characters keep their
/// own animation and semantics while this widget provides intentional staging.
enum HariPicoMoment { greeting, reacting, encouraging, celebrating, calm, play }

class HariPicoScene extends StatelessWidget {
  const HariPicoScene({
    super.key,
    this.moment = HariPicoMoment.greeting,
    this.animate = true,
  });

  final HariPicoMoment moment;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final values = switch (moment) {
      HariPicoMoment.greeting => (HariPose.wave, HariEmotion.happy,
          PicoMood.excited, -0.32, 0.48, 0.00, 0.10),
      HariPicoMoment.reacting => (HariPose.idle, HariEmotion.curious,
          PicoMood.curious, -0.32, 0.48, 0.03, 0.05),
      HariPicoMoment.encouraging => (HariPose.point, HariEmotion.encouraging,
          PicoMood.happy, -0.32, 0.48, 0.02, 0.12),
      HariPicoMoment.celebrating => (HariPose.cheer, HariEmotion.excited,
          PicoMood.celebrating, -0.32, 0.48, -0.02, 0.04),
      HariPicoMoment.calm => (HariPose.sit, HariEmotion.calm,
          PicoMood.comforting, -0.32, 0.48, 0.04, 0.15),
      HariPicoMoment.play => (HariPose.jump, HariEmotion.excited,
          PicoMood.excited, -0.32, 0.48, -0.05, 0.04),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
            Align(
              alignment: Alignment(values.$4, values.$6),
              child: SizedBox(
                width: size * 0.62,
                height: size * 0.88,
                child: Hari(
                  pose: values.$1,
                  emotion: values.$2,
                  animate: animate,
                ),
              ),
            ),
            Align(
              alignment: Alignment(values.$5, values.$7),
              child: SizedBox(
                width: size * 0.38,
                height: size * 0.48,
                child: PicoWidget(mood: values.$3, animate: animate),
              ),
            ),
          ],
        );
      },
    );
  }
}