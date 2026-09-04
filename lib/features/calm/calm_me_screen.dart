import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harshiv_scaffold.dart';
import '../../models/regulation_entry.dart';
import '../lifeskills/avatar/hari_cards.dart';
import '../lifeskills/avatar/pico.dart';
import 'calm_sequence_screen.dart';

/// Calm Me — one-tap emergency regulation. Big, low-pressure mood buttons.
class CalmMeScreen extends StatelessWidget {
  const CalmMeScreen({super.key});

  static const Map<CalmMood, Color> _colors = <CalmMood, Color>{
    CalmMood.overwhelmed: AppColors.moodOverwhelmed,
    CalmMood.frustrated: AppColors.moodFrustrated,
    CalmMood.sad: AppColors.moodSad,
    CalmMood.anxious: AppColors.moodAnxious,
    CalmMood.tired: AppColors.moodTired,
  };

  @override
  Widget build(BuildContext context) {
    return HarshivScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text('How do you feel?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(
                width: 52,
                height: 52,
                child: PicoWidget(mood: PicoMood.comforting),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text('Try a calming idea with Hari, or tell me how you feel.',
                style: TextStyle(color: Colors.white70)),
          ),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              itemCount: kCalmingStrategies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SizedBox(
                width: 200,
                child: CalmingStrategyCard(strategy: kCalmingStrategies[i]),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Text('How do you feel right now?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: CalmMood.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final mood = CalmMood.values[i];
                return _MoodButton(
                  mood: mood,
                  color: _colors[mood]!,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CalmSequenceScreen(mood: mood),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.mood, required this.color, required this.onTap});
  final CalmMood mood;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      gradient: LinearGradient(
        colors: <Color>[color.withOpacity(0.55), color.withOpacity(0.20)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      child: Row(
        children: <Widget>[
          Text(mood.emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(width: 18),
          Text(mood.label,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 30),
        ],
      ),
    );
  }
}
