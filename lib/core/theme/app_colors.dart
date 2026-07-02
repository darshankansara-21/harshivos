import 'package:flutter/material.dart';

/// Central colour + gradient tokens for the whole toybox.
///
/// The palette intentionally avoids clinical whites and harsh primaries —
/// think Pixar night skies and soft candy gradients, never hospital software.
class AppColors {
  AppColors._();

  // Deep, calming background (dark-mode first).
  static const Color bgTop = Color(0xFF0B1026);
  static const Color bgMid = Color(0xFF1A1240);
  static const Color bgBottom = Color(0xFF05101C);

  // Glass surfaces.
  static const Color glassFill = Color(0x14FFFFFF);
  static const Color glassStroke = Color(0x33FFFFFF);

  // Text.
  static const Color textPrimary = Color(0xFFF4F6FF);
  static const Color textSecondary = Color(0xB3F4F6FF);

  // Ambient background blobs.
  static const Color blobViolet = Color(0xFF6C3CE0);
  static const Color blobTeal = Color(0xFF18C8C8);
  static const Color blobPink = Color(0xFFF857A6);
  static const Color blobBlue = Color(0xFF3A7BFF);

  // Per-destination gradients (used by the floating home cards).
  static const List<Color> calmGradient = <Color>[Color(0xFF36D1DC), Color(0xFF5B86E5)];
  static const List<Color> talkGradient = <Color>[Color(0xFFF857A6), Color(0xFFFF5858)];
  static const List<Color> playGradient = <Color>[Color(0xFF43E97B), Color(0xFF38F9D7)];
  static const List<Color> storyGradient = <Color>[Color(0xFFFA709A), Color(0xFFFEE140)];
  static const List<Color> learnGradient = <Color>[Color(0xFFA18CD1), Color(0xFFFBC2EB)];
  static const List<Color> parentGradient = <Color>[Color(0xFF4FACFE), Color(0xFF00F2FE)];

  // Mood colours for Calm Me.
  static const Color moodOverwhelmed = Color(0xFFFF6B6B);
  static const Color moodFrustrated = Color(0xFFFF9F43);
  static const Color moodSad = Color(0xFF54A0FF);
  static const Color moodAnxious = Color(0xFFA55EEA);
  static const Color moodTired = Color(0xFF26DE81);
}
