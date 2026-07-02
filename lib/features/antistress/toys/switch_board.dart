import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A full-bleed panel of big chunky wall/breaker switches.
///
/// Flip each one on/off with a sliding lever and a glowing indicator light.
/// Purely tactile — no fail states, just satisfying clicks.
class SwitchBoardToy extends StatefulWidget {
  const SwitchBoardToy({super.key});

  @override
  State<SwitchBoardToy> createState() => _SwitchBoardToyState();
}

class _SwitchBoardToyState extends State<SwitchBoardToy> {
  static const int _count = 8;

  // Each switch gets a warm/cool indicator hue so the board feels alive.
  static const List<Color> _hues = <Color>[
    Color(0xFF06D6A0),
    Color(0xFFFFD166),
    Color(0xFF4CC9F0),
    Color(0xFFEF476F),
    Color(0xFFB388FF),
    Color(0xFF80ED99),
    Color(0xFFFF8FA3),
    Color(0xFF64DFDF),
  ];

  final List<bool> _on = List<bool>.filled(_count, false);

  void _toggle(int i) {
    setState(() => _on[i] = !_on[i]);
    if (_on[i]) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF101826), Color(0xFF1B2740), Color(0xFF0B1220)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _count,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 22,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (BuildContext context, int i) => _SwitchPlate(
                  on: _on[i],
                  hue: _hues[i],
                  onTap: () => _toggle(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single rocker/lever switch mounted on a metallic plate.
class _SwitchPlate extends StatelessWidget {
  const _SwitchPlate({
    required this.on,
    required this.hue,
    required this.onTap,
  });

  final bool on;
  final Color hue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2B3650), Color(0xFF1A2236)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            if (on)
              BoxShadow(
                color: hue.withOpacity(0.35),
                blurRadius: 26,
                spreadRadius: 1,
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: <Widget>[
            _IndicatorLight(on: on, hue: hue),
            const SizedBox(width: 14),
            Expanded(child: _Lever(on: on, hue: hue)),
          ],
        ),
      ),
    );
  }
}

/// The round glow lamp that lights up when the switch is on.
class _IndicatorLight extends StatelessWidget {
  const _IndicatorLight({required this.on, required this.hue});

  final bool on;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? hue : const Color(0xFF273049),
        border: Border.all(color: Colors.black.withOpacity(0.4), width: 2),
        boxShadow: <BoxShadow>[
          if (on)
            BoxShadow(color: hue.withOpacity(0.9), blurRadius: 16, spreadRadius: 2),
        ],
      ),
    );
  }
}

/// The sliding lever that snaps between the on (top) and off (bottom) tracks.
class _Lever extends StatelessWidget {
  const _Lever({required this.on, required this.hue});

  final bool on;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double trackH = c.maxHeight.clamp(64.0, 120.0);
        return Container(
          height: trackH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF11182A),
            border: Border.all(color: Colors.black.withOpacity(0.5), width: 2),
          ),
          padding: const EdgeInsets.all(6),
          child: Stack(
            children: <Widget>[
              AnimatedAlign(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutBack,
                alignment: on ? Alignment.topCenter : Alignment.bottomCenter,
                child: Container(
                  height: (trackH - 12) * 0.52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: on
                          ? <Color>[hue.withOpacity(0.95), hue.withOpacity(0.7)]
                          : const <Color>[Color(0xFF3A455F), Color(0xFF273049)],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(on ? 0.85 : 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Transform.rotate(
                    angle: math.pi,
                    child: Icon(
                      Icons.power_settings_new,
                      size: 12,
                      color: Colors.white.withOpacity(on ? 0.0 : 0.18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
