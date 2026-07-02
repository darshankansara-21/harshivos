import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import 'avatar/avatar.dart';
import 'state/lifeskills_providers.dart';

/// Design the child's own avatar guide — skin, hair, clothing, glasses and a
/// proudly-worn hearing aid. The avatar then appears throughout the app.
class AvatarStudioScreen extends ConsumerStatefulWidget {
  const AvatarStudioScreen({super.key});

  @override
  ConsumerState<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends ConsumerState<AvatarStudioScreen> {
  late AvatarConfig _draft;
  int _poseIdx = 0;
  static const _poses = <AvatarPose>[
    AvatarPose.wave,
    AvatarPose.clap,
    AvatarPose.cheer,
    AvatarPose.idle,
  ];

  @override
  void initState() {
    super.initState();
    _draft = ref.read(avatarConfigProvider);
  }

  void _set(AvatarConfig next) {
    HapticFeedback.selectionClick();
    setState(() => _draft = next);
  }

  void _save() {
    HapticFeedback.mediumImpact();
    ref.read(avatarConfigProvider.notifier).update(_draft);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: <Widget>[
                  _round(Icons.arrow_back_rounded,
                      () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  const Text('Avatar Studio',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          // Live preview.
          GestureDetector(
            onTap: () => setState(
                () => _poseIdx = (_poseIdx + 1) % _poses.length),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.1,
                  colors: <Color>[Color(0xFF2A2350), Color(0xFF12102A)],
                ),
                border:
                    Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
              ),
              child: AvatarWidget(config: _draft, pose: _poses[_poseIdx]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              children: <Widget>[
                _label('Skin'),
                _swatchRow(
                  AvatarConfig.skinTones,
                  _draft.skin,
                  (c) => _set(_draft.copyWith(skin: c)),
                ),
                _label('Hair Style'),
                _hairStyleRow(),
                _label('Hair Colour'),
                _swatchRow(
                  AvatarConfig.hairColors,
                  _draft.hairColor,
                  (c) => _set(_draft.copyWith(hairColor: c)),
                ),
                _label('Shirt'),
                _swatchRow(
                  AvatarConfig.shirtColors,
                  _draft.shirt,
                  (c) => _set(_draft.copyWith(shirt: c)),
                ),
                _label('Extras'),
                _toggle('👓  Glasses', _draft.glasses,
                    (v) => _set(_draft.copyWith(glasses: v))),
                const SizedBox(height: 10),
                _toggle('🦻  Hearing Aid', _draft.hearingAid,
                    (v) => _set(_draft.copyWith(hearingAid: v))),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Material(
                color: const Color(0xFF06D6A0),
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _save,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.check_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Save My Avatar',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 0, 10),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
      );

  Widget _swatchRow(
      List<Color> colors, Color selected, ValueChanged<Color> onPick) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((c) {
        final on = c.value == selected.value;
        return GestureDetector(
          onTap: () => onPick(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                  color: on ? Colors.white : Colors.white24,
                  width: on ? 3.5 : 1.5),
              boxShadow: on
                  ? <BoxShadow>[
                      BoxShadow(
                          color: c.withOpacity(0.7),
                          blurRadius: 14,
                          spreadRadius: 1)
                    ]
                  : null,
            ),
            child: on
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 22)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _hairStyleRow() {
    const labels = <HairStyle, String>{
      HairStyle.short: 'Short',
      HairStyle.ponytail: 'Ponytail',
      HairStyle.curly: 'Curly',
      HairStyle.buzz: 'Buzz',
      HairStyle.bun: 'Bun',
      HairStyle.spiky: 'Spiky',
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: HairStyle.values.map((s) {
        final on = _draft.hair == s;
        return GestureDetector(
          onTap: () => _set(_draft.copyWith(hair: s)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: on
                  ? const Color(0xFF9B5DE5)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: on ? Colors.white : Colors.white24, width: 1.5),
            ),
            child: Text(labels[s]!,
                style: TextStyle(
                    color: on ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700)),
          ),
        );
      }).toList(),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: value
                  ? const Color(0xFF06D6A0)
                  : Colors.white24,
              width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 30,
              padding: const EdgeInsets.all(3),
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF06D6A0)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
