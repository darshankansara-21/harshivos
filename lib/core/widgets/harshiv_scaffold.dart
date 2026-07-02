import 'package:flutter/material.dart';

import 'animated_background.dart';
import 'floating_particles.dart';

/// Standard screen shell: animated background + particles + safe area.
class HarshivScaffold extends StatelessWidget {
  const HarshivScaffold({
    super.key,
    required this.child,
    this.showParticles = true,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
  });

  final Widget child;
  final bool showParticles;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedBackground(
        child: Stack(
          children: <Widget>[
            if (showParticles) const Positioned.fill(child: FloatingParticles()),
            Positioned.fill(
              child: SafeArea(
                child: Padding(padding: padding, child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
