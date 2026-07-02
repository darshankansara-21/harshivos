import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import 'antistress_player_screen.dart';
import 'toys/bubble_wrap.dart';
import 'toys/click_pen.dart';
import 'toys/combo_lock.dart';
import 'toys/dimmer_knob.dart';
import 'toys/fidget_spinner.dart';
import 'toys/gears.dart';
import 'toys/keypad.dart';
import 'toys/kinetic_dots.dart';
import 'toys/latch_bolt.dart';
import 'toys/lava_blobs.dart';
import 'toys/newtons_cradle.dart';
import 'toys/pendulum_waves.dart';
import 'toys/pop_it.dart';
import 'toys/rotary_dial.dart';
import 'toys/sand_fall.dart';
import 'toys/slinky.dart';
import 'toys/spin_wheel.dart';
import 'toys/stress_ball.dart';
import 'toys/switch_board.dart';
import 'toys/water_drop.dart';
import 'toys/zipper.dart';

/// One antistress fidget toy in the grid.
class _Fidget {
  const _Fidget(this.title, this.emoji, this.color, this.builder);
  final String title;
  final String emoji;
  final Color color;
  final Widget Function() builder;
}

/// The Antistress tab — a toybox of squishy, clicky, spinny fidget toys.
/// Tap any tile to open it full-screen. Calm, no-fail, instant feedback.
class AntistressHubScreen extends StatelessWidget {
  const AntistressHubScreen({super.key});

  static final List<_Fidget> _toys = <_Fidget>[
    _Fidget('Pop It', '🫧', const Color(0xFFEF476F), PopItToy.new),
    _Fidget('Bubble Wrap', '🎈', const Color(0xFF06D6A0), BubbleWrapToy.new),
    _Fidget('Stress Ball', '🔴', const Color(0xFFFF6B6B), StressBallToy.new),
    _Fidget('Fidget Spinner', '🌀', const Color(0xFF118AB2), FidgetSpinnerToy.new),
    _Fidget('Spin Wheel', '🎡', const Color(0xFFFFD166), SpinWheelToy.new),
    _Fidget('Gears', '⚙️', const Color(0xFF8D99AE), GearsToy.new),
    _Fidget('Switch Board', '🔌', const Color(0xFF06D6A0), SwitchBoardToy.new),
    _Fidget('Keypad', '🔢', const Color(0xFF4CC9F0), KeypadToy.new),
    _Fidget('Click Pen', '🖊️', const Color(0xFFFFD166), ClickPenToy.new),
    _Fidget('Latch & Bolt', '🔩', const Color(0xFF8D99AE), LatchBoltToy.new),
    _Fidget('Zipper', '🤐', const Color(0xFFEF476F), ZipperToy.new),
    _Fidget('Combo Lock', '🔒', const Color(0xFF118AB2), ComboLockToy.new),
    _Fidget("Newton's Cradle", '⚪', const Color(0xFFCED4DA), NewtonsCradleToy.new),
    _Fidget('Slinky', '🌈', const Color(0xFF9B5DE5), SlinkyToy.new),
    _Fidget('Pendulum Waves', '〰️', const Color(0xFF00BBF9), PendulumWavesToy.new),
    _Fidget('Lava Blobs', '🫠', const Color(0xFFF15BB5), LavaBlobsToy.new),
    _Fidget('Water Drops', '💧', const Color(0xFF00BBF9), WaterDropToy.new),
    _Fidget('Dimmer Knob', '💡', const Color(0xFFFFD166), DimmerKnobToy.new),
    _Fidget('Falling Sand', '🏜️', const Color(0xFFFFB703), SandFallToy.new),
    _Fidget('Kinetic Dots', '✨', const Color(0xFF9B5DE5), KineticDotsToy.new),
    _Fidget('Rotary Dial', '☎️', const Color(0xFF06D6A0), RotaryDialToy.new),
  ];

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Text('Antistress',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  const Text('🫧', style: TextStyle(fontSize: 26)),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text('Squishy, clicky, spinny toys to fidget and calm down.',
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 4, bottom: 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ToyTile(fidget: _toys[i]),
                childCount: _toys.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToyTile extends StatelessWidget {
  const _ToyTile({required this.fidget});
  final _Fidget fidget;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: fidget.color,
      padding: const EdgeInsets.all(14),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AntistressPlayerScreen(
              toy: fidget.builder(),
              title: fidget.title,
              emoji: fidget.emoji,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[
                  fidget.color,
                  Color.lerp(fidget.color, Colors.black, 0.35)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                    color: fidget.color.withOpacity(0.5),
                    blurRadius: 18,
                    spreadRadius: 1),
              ],
            ),
            child: Text(fidget.emoji, style: const TextStyle(fontSize: 28)),
          ),
          const Spacer(),
          Text(fidget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
