import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import '../../state/providers.dart';
import 'avatar/avatar.dart';
import 'state/lifeskills_providers.dart';

/// First-launch wizard: build the child's own character.
///
/// Name → boy/girl → skin → hair → eyes → clothing/favourite colour →
/// hearing device → glasses → meet your character. Every choice updates the
/// live preview so the child literally watches themselves come to life.
class ProfileWizardScreen extends ConsumerStatefulWidget {
  const ProfileWizardScreen({super.key});

  @override
  ConsumerState<ProfileWizardScreen> createState() =>
      _ProfileWizardScreenState();
}

class _ProfileWizardScreenState extends ConsumerState<ProfileWizardScreen> {
  final _nameCtrl = TextEditingController();
  AvatarConfig _draft = const AvatarConfig();
  int _step = 0;
  static const _lastStep = 7;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = ref.read(childNameProvider);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _set(AvatarConfig next) {
    HapticFeedback.selectionClick();
    setState(() => _draft = next);
  }

  void _applyHarshiv() {
    HapticFeedback.mediumImpact();
    setState(() {
      _draft = AvatarConfig.harshiv;
      if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = 'Harshiv';
    });
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    final name =
        _nameCtrl.text.trim().isEmpty ? 'Friend' : _nameCtrl.text.trim();
    final storage = ref.read(localStorageProvider);
    await ref.read(avatarConfigProvider.notifier).update(_draft);
    ref.read(childNameProvider.notifier).state = name;
    await storage.writeString('child_name', name);
    await storage.writeBool('profile_complete', true);
    ref.read(profileCompleteProvider.notifier).state = true;
  }

  void _next() {
    if (_step >= _lastStep) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final celebrate = _step == _lastStep;
    return HarshivScaffold(
      padding: EdgeInsets.zero,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // Progress dots.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: <Widget>[
                  if (_step > 0)
                    _round(Icons.arrow_back_rounded, _back)
                  else
                    const SizedBox(width: 44),
                  const Spacer(),
                  ...List.generate(_lastStep + 1, (i) {
                    final on = i <= _step;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _step ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: on
                            ? const Color(0xFF06D6A0)
                            : Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            // Live preview.
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              height: 210,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.1,
                  colors: <Color>[Color(0xFF2A2350), Color(0xFF12102A)],
                ),
                border: Border.all(
                    color: Colors.white.withOpacity(0.12), width: 1.5),
              ),
              child: AvatarWidget(
                config: _draft,
                pose: celebrate ? AvatarPose.cheer : AvatarPose.wave,
                emotion:
                    celebrate ? AvatarEmotion.excited : AvatarEmotion.happy,
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: SingleChildScrollView(
                  key: ValueKey<int>(_step),
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                  child: _stepBody(),
                ),
              ),
            ),
            // Next / Finish.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Material(
                color: const Color(0xFF06D6A0),
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _next,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          _step >= _lastStep ? "Let's go!" : 'Next',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                            _step >= _lastStep
                                ? Icons.celebration_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _nameStep();
      case 1:
        return _genderStep();
      case 2:
        return _panel("Choose a skin tone", [
          _swatchRow(AvatarConfig.skinTones, _draft.skin,
              (c) => _set(_draft.copyWith(skin: c))),
        ]);
      case 3:
        return _panel("Pick a hairstyle", [
          _hairStyleRow(),
          const SizedBox(height: 16),
          _sub('Hair colour'),
          _swatchRow(AvatarConfig.hairColors, _draft.hairColor,
              (c) => _set(_draft.copyWith(hairColor: c))),
        ]);
      case 4:
        return _panel("Eye colour", [
          _swatchRow(AvatarConfig.eyeColors, _draft.eyeColor,
              (c) => _set(_draft.copyWith(eyeColor: c))),
        ]);
      case 5:
        return _panel("Clothes & favourite colour", [
          _sub('Shirt'),
          _swatchRow(AvatarConfig.shirtColors, _draft.shirt,
              (c) => _set(_draft.copyWith(shirt: c))),
          const SizedBox(height: 16),
          _sub('Favourite colour (shoes, accents & device)'),
          _swatchRow(AvatarConfig.favoriteColors, _draft.favoriteColor,
              (c) => _set(_draft.copyWith(favoriteColor: c))),
        ]);
      case 6:
        return _deviceStep();
      default:
        return _finalStep();
    }
  }

  // ---- Steps --------------------------------------------------------------

  Widget _nameStep() {
    return _panel("What's your child's name?", [
      TextField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          hintText: 'Type a name',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _harshivButton(),
    ]);
  }

  Widget _genderStep() {
    const options = <AvatarGender, String>{
      AvatarGender.boy: '👦  Boy',
      AvatarGender.girl: '👧  Girl',
      AvatarGender.neutral: '🌟  Prefer not to say',
    };
    return _panel("Who is your child?", [
      ...options.entries.map((e) {
        final on = _draft.gender == e.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _bigChoice(e.value, on,
              () => _set(_draft.copyWith(gender: e.key))),
        );
      }),
    ]);
  }

  Widget _deviceStep() {
    const devices = <HearingDevice, String>{
      HearingDevice.none: '🙂  No device',
      HearingDevice.hearingAid: '🦻  Hearing aid',
      HearingDevice.baha: '💠  BAHA',
      HearingDevice.cochlear: '🔵  Cochlear implant',
    };
    return _panel("Hearing device", [
      const Text(
        'Devices are worn with pride — your child should see themselves.',
        style: TextStyle(color: Colors.white70, fontSize: 13.5),
      ),
      const SizedBox(height: 14),
      ...devices.entries.map((e) {
        final on = _draft.device == e.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _bigChoice(e.value, on,
              () => _set(_draft.copyWith(device: e.key))),
        );
      }),
      if (_draft.device != HearingDevice.none) ...<Widget>[
        const SizedBox(height: 8),
        _sub('Which side?'),
        Row(
          children: <Widget>[
            _sideChip('Left', HearingSide.left),
            const SizedBox(width: 10),
            _sideChip('Right', HearingSide.right),
            const SizedBox(width: 10),
            _sideChip('Both', HearingSide.both),
          ],
        ),
      ],
    ]);
  }

  Widget _finalStep() {
    final name =
        _nameCtrl.text.trim().isEmpty ? 'your character' : _nameCtrl.text.trim();
    return _panel("Meet $name! ✨", [
      const Text(
        'Add glasses if you like — then tap "Let\'s go!"',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
      const SizedBox(height: 14),
      _toggle('👓  Glasses', _draft.glasses,
          (v) => _set(_draft.copyWith(glasses: v))),
      const SizedBox(height: 14),
      _harshivButton(),
    ]);
  }

  // ---- Reusable pieces ----------------------------------------------------

  Widget _panel(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _sub(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      );

  Widget _harshivButton() {
    return GestureDetector(
      onTap: _applyHarshiv,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: <Color>[Color(0xFF0891B2), Color(0xFF06D6A0)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: <Widget>[
            Text('💙', style: TextStyle(fontSize: 22)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Harshiv Mode',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  Text('Unilateral BAHA · sensory-calm look',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _sideChip(String label, HearingSide side) {
    final on = _draft.hearingSide == side;
    return Expanded(
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
          child: Text(label,
              style: TextStyle(
                  color: on ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _bigChoice(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: on
              ? const Color(0xFF9B5DE5).withOpacity(0.35)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: on ? const Color(0xFF9B5DE5) : Colors.white24,
              width: on ? 2 : 1.2),
        ),
        child: Row(
          children: <Widget>[
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (on)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF06D6A0)),
          ],
        ),
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
            width: 48,
            height: 48,
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
        final on = _draft.hair == st;
        return GestureDetector(
          onTap: () => _set(_draft.copyWith(hair: st)),
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
            child: Text(labels[st]!,
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
