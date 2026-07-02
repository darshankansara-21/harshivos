import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import 'avatar/avatar.dart';
import 'state/lifeskills_providers.dart';

/// Design the child's character — skin, hair, eyes, clothing, favourite colour
/// and a proudly-worn hearing device. Tap the preview to cycle emotions.
class AvatarStudioScreen extends ConsumerStatefulWidget {
  const AvatarStudioScreen({super.key});

  @override
  ConsumerState<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends ConsumerState<AvatarStudioScreen> {
  late AvatarConfig _draft;
  int _emoIdx = 0;

  static const _emotions = <AvatarEmotion>[
    AvatarEmotion.happy,
    AvatarEmotion.excited,
    AvatarEmotion.proud,
    AvatarEmotion.calm,
    AvatarEmotion.sad,
    AvatarEmotion.frustrated,
    AvatarEmotion.tired,
    AvatarEmotion.nervous,
  ];
  static const _emotionLabels = <AvatarEmotion, String>{
    AvatarEmotion.happy: '😀 Happy',
    AvatarEmotion.excited: '🤩 Excited',
    AvatarEmotion.proud: '😌 Proud',
    AvatarEmotion.calm: '🙂 Calm',
    AvatarEmotion.sad: '😢 Sad',
    AvatarEmotion.frustrated: '😤 Frustrated',
    AvatarEmotion.tired: '🥱 Tired',
    AvatarEmotion.nervous: '😰 Nervous',
  };

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
    final emotion = _emotions[_emoIdx];
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
          // Live preview — tap to cycle through emotions.
          GestureDetector(
            onTap: () => setState(
                () => _emoIdx = (_emoIdx + 1) % _emotions.length),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              height: 210,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.1,
                  colors: <Color>[Color(0xFF2A2350), Color(0xFF12102A)],
                ),
                border: Border.all(
                    color: Colors.white.withOpacity(0.12), width: 1.5),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: AvatarWidget(
                        config: _draft,
                        pose: AvatarPose.wave,
                        emotion: emotion),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_emotionLabels[emotion]}   ·  tap to change',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              children: <Widget>[
                _harshivButton(),
                _label('Character'),
                _genderRow(),
                _label('Skin'),
                _swatchRow(AvatarConfig.skinTones, _draft.skin,
                    (c) => _set(_draft.copyWith(skin: c))),
                _label('Hair Style'),
                _hairStyleRow(),
                _label('Hair Colour'),
                _swatchRow(AvatarConfig.hairColors, _draft.hairColor,
                    (c) => _set(_draft.copyWith(hairColor: c))),
                _label('Eye Colour'),
                _swatchRow(AvatarConfig.eyeColors, _draft.eyeColor,
                    (c) => _set(_draft.copyWith(eyeColor: c))),
                _label('Shirt'),
                _swatchRow(AvatarConfig.shirtColors, _draft.shirt,
                    (c) => _set(_draft.copyWith(shirt: c))),
                _label('Favourite Colour'),
                _swatchRow(AvatarConfig.favoriteColors, _draft.favoriteColor,
                    (c) => _set(_draft.copyWith(favoriteColor: c))),
                _label('Hearing Device'),
                _deviceRow(),
                if (_draft.device != HearingDevice.none) ...<Widget>[
                  const SizedBox(height: 12),
                  _sideRow(),
                ],
                _label('Extras'),
                _toggle('👓  Glasses', _draft.glasses,
                    (v) => _set(_draft.copyWith(glasses: v))),
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
                        Text('Save My Character',
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

  // ---- Rows ----------------------------------------------------------------

  Widget _genderRow() {
    const labels = <AvatarGender, String>{
      AvatarGender.boy: '👦 Boy',
      AvatarGender.girl: '👧 Girl',
      AvatarGender.neutral: '🌟 Either',
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AvatarGender.values.map((g) {
        return _pill(labels[g]!, _draft.gender == g,
            () => _set(_draft.copyWith(gender: g)));
      }).toList(),
    );
  }

  Widget _deviceRow() {
    const labels = <HearingDevice, String>{
      HearingDevice.none: '🙂 None',
      HearingDevice.hearingAid: '🦻 Hearing Aid',
      HearingDevice.baha: '💠 BAHA',
      HearingDevice.cochlear: '🔵 Cochlear',
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: HearingDevice.values.map((d) {
        return _pill(labels[d]!, _draft.device == d,
            () => _set(_draft.copyWith(device: d)));
      }).toList(),
    );
  }

  Widget _sideRow() {
    const labels = <HearingSide, String>{
      HearingSide.left: 'Left',
      HearingSide.right: 'Right',
      HearingSide.both: 'Both',
    };
    return Row(
      children: HearingSide.values.map((side) {
        final on = _draft.hearingSide == side;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => _set(_draft.copyWith(hearingSide: side)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on
                      ? const Color(0xFF06D6A0)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: on ? Colors.white : Colors.white24, width: 1.5),
                ),
                child: Text(labels[side]!,
                    style: TextStyle(
                        color: on ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _harshivButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _draft = AvatarConfig.harshiv);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: <Color>[Color(0xFF0891B2), Color(0xFF06D6A0)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: <Widget>[
              Text('💙', style: TextStyle(fontSize: 20)),
              SizedBox(width: 12),
              Expanded(
                child: Text('Harshiv Mode — unilateral BAHA, sensory-calm',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ),
              Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Shared pieces -------------------------------------------------------

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 0, 10),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
      );

  Widget _pill(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF9B5DE5) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: on ? Colors.white : Colors.white24, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: on ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

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
      children: HairStyle.values.map((st) {
        return _pill(labels[st]!, _draft.hair == st,
            () => _set(_draft.copyWith(hair: st)));
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
              color: value ? const Color(0xFF06D6A0) : Colors.white24,
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
                color: value ? const Color(0xFF06D6A0) : Colors.white24,
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
