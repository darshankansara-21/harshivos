import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/harshiv_scaffold.dart';
import '../../state/providers.dart';
import 'avatar/avatar.dart';
import 'state/lifeskills_providers.dart';

/// Quick first-launch setup, with an optional full character editor.
class ProfileWizardScreen extends ConsumerStatefulWidget {
  const ProfileWizardScreen({super.key, this.fullEditor = false});

  final bool fullEditor;

  @override
  ConsumerState<ProfileWizardScreen> createState() =>
      _ProfileWizardScreenState();
}

class _ProfileWizardScreenState extends ConsumerState<ProfileWizardScreen> {
  final _nameCtrl = TextEditingController();
  AvatarConfig _draft = const AvatarConfig();
  AvatarConfig? _customBeforeHarshiv;
  int _step = 0;

  int get _lastStep => 1;

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
      _customBeforeHarshiv ??= _draft;
      _draft = AvatarConfig.harshiv;
      if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = 'Harshiv';
    });
  }

  void _applyCustom() {
    HapticFeedback.selectionClick();
    setState(() {
      _draft = _customBeforeHarshiv ?? const AvatarConfig();
      _customBeforeHarshiv = null;
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
    if (widget.fullEditor && mounted) Navigator.of(context).pop();
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
              child: ChildAvatar(config: _draft),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
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
                          _step >= _lastStep
                            ? widget.fullEditor
                              ? 'Save'
                              : "Let's go!"
                            : 'Next',
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
    return _step == 0 ? _nameStep() : _lookStep();
  }

  // The three authored Hari looks the child can choose from.
  Widget _lookStep() {
    final selected = _draft.glasses
        ? 'glasses'
        : _draft.device == HearingDevice.cochlear
            ? 'cochlear'
            : 'hearing_aid';
    void pick(String look) {
      switch (look) {
        case 'hearing_aid':
          _set(_draft.copyWith(device: HearingDevice.hearingAid, glasses: false));
        case 'cochlear':
          _set(_draft.copyWith(device: HearingDevice.cochlear, glasses: false));
        case 'glasses':
          _set(_draft.copyWith(device: HearingDevice.hearingAid, glasses: true));
      }
    }

    const looks = <(String, String)>[
      ('hearing_aid', 'Hearing Aid'),
      ('cochlear', 'Cochlear'),
      ('glasses', 'Glasses'),
    ];
    return _panel('Pick your look', [
      const Text('Hari can look like you. Tap a look — change it anytime.',
          style: TextStyle(color: Colors.white70, fontSize: 13.5)),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final l in looks) ...<Widget>[
            Expanded(child: _lookCard(l.$1, l.$2, selected == l.$1, () => pick(l.$1))),
            if (l != looks.last) const SizedBox(width: 10),
          ],
        ],
      ),
      const SizedBox(height: 16),
      _harshivButton(),
    ]);
  }

  Widget _lookCard(String look, String label, bool on, VoidCallback onTap) {
    final AvatarConfig lookConfig = switch (look) {
      'cochlear' => _draft.copyWith(
          device: HearingDevice.cochlear,
          hearingSide: HearingSide.left,
          glasses: false,
        ),
      'glasses' => _draft.copyWith(
          device: HearingDevice.hearingAid,
          hearingSide: HearingSide.left,
          glasses: true,
        ),
      _ => _draft.copyWith(
          device: HearingDevice.hearingAid,
          hearingSide: HearingSide.left,
          glasses: false,
        ),
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: on ? const Color(0x3306D6A0) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: on ? const Color(0xFF06D6A0) : Colors.white.withOpacity(0.12),
            width: on ? 2.4 : 1.2,
          ),
        ),
        child: Column(
          children: <Widget>[
            Container(
              height: 92,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0x1AFFFFFF), Color(0x05FFFFFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ChildAvatar(config: lookConfig, animate: false),
              ),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
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

  Widget _harshivButton() {
    final usingPreset = _draft == AvatarConfig.harshiv;
    return GestureDetector(
      onTap: usingPreset ? _applyCustom : _applyHarshiv,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: usingPreset
              ? const <Color>[Color(0xFF6D5DF6), Color(0xFF3A86FF)]
              : const <Color>[Color(0xFF0891B2), Color(0xFF06D6A0)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: <Widget>[
            Text(usingPreset ? '✨' : '💙', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(usingPreset ? 'Custom Mode' : 'Harshiv Mode',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  Text(
                    usingPreset
                        ? 'Tap to switch back and customize fully'
                        : 'Preset: unilateral BAHA · sensory-calm look',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(
              usingPreset ? Icons.tune_rounded : Icons.auto_awesome_rounded,
              color: Colors.white,
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
