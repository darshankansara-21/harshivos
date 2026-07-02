import 'package:flutter/material.dart';

import 'sensory_profile.dart';

/// Pure metadata describing a sensory toy. No widgets here so the regulation
/// engine and analytics can reason about toys without importing UI.
class ToyMeta {
  const ToyMeta({
    required this.id,
    required this.title,
    required this.emoji,
    required this.gradient,
    required this.channels,
    this.implemented = false,
  });

  final String id;
  final String title;
  final String emoji;
  final List<Color> gradient;

  /// Which sensory channels this toy primarily feeds.
  final List<SensoryChannel> channels;

  /// True when a fully-playable implementation ships in this MVP.
  final bool implemented;
}

/// The full toy catalogue from the product spec. Every toy listed here is a
/// fully-playable implementation in this MVP.
const List<ToyMeta> kToyCatalog = <ToyMeta>[
  ToyMeta(id: 'bubble_pop', title: 'Bubble Pop World', emoji: '🫧', implemented: true,
      gradient: [Color(0xFF43E97B), Color(0xFF38F9D7)],
      channels: [SensoryChannel.visual, SensoryChannel.auditory, SensoryChannel.tactile]),
  ToyMeta(id: 'particle_galaxy', title: 'Particle Galaxy', emoji: '🌌', implemented: true,
      gradient: [Color(0xFF6C3CE0), Color(0xFF3A7BFF)],
      channels: [SensoryChannel.visual, SensoryChannel.vestibular]),
  ToyMeta(id: 'water_ripples', title: 'Water Ripples', emoji: '💧', implemented: true,
      gradient: [Color(0xFF36D1DC), Color(0xFF5B86E5)],
      channels: [SensoryChannel.visual, SensoryChannel.tactile]),
  ToyMeta(id: 'fireworks', title: 'Fireworks Touch', emoji: '🎆', implemented: true,
      gradient: [Color(0xFFFA709A), Color(0xFFFEE140)],
      channels: [SensoryChannel.visual, SensoryChannel.auditory]),
  ToyMeta(id: 'paint_light', title: 'Paint With Light', emoji: '✨', implemented: true,
      gradient: [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
      channels: [SensoryChannel.visual, SensoryChannel.tactile]),
  ToyMeta(id: 'sand_garden', title: 'Sand Garden', emoji: '🏜️', implemented: true,
      gradient: [Color(0xFFE6B980), Color(0xFFEACDA3)],
      channels: [SensoryChannel.tactile, SensoryChannel.proprioceptive]),
  ToyMeta(id: 'magnetic_balls', title: 'Magnetic Balls', emoji: '🧲', implemented: true,
      gradient: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      channels: [SensoryChannel.visual, SensoryChannel.proprioceptive]),
  ToyMeta(id: 'fluid_sim', title: 'Fluid Simulator', emoji: '🌊', implemented: true,
      gradient: [Color(0xFF21D4FD), Color(0xFFB721FF)],
      channels: [SensoryChannel.visual, SensoryChannel.tactile]),
  ToyMeta(id: 'lava_lamp', title: 'Sensory Lava Lamp', emoji: '🔮', implemented: true,
      gradient: [Color(0xFFFF6B6B), Color(0xFFFFB88C)],
      channels: [SensoryChannel.visual]),
  ToyMeta(id: 'kaleidoscope', title: 'Kaleidoscope Mirror', emoji: '🔷', implemented: true,
      gradient: [Color(0xFFF857A6), Color(0xFFFF5858)],
      channels: [SensoryChannel.visual]),
  ToyMeta(id: 'music_garden', title: 'Music Garden', emoji: '🌸', implemented: true,
      gradient: [Color(0xFFFBC2EB), Color(0xFFA6C1EE)],
      channels: [SensoryChannel.auditory, SensoryChannel.visual]),
  ToyMeta(id: 'fidget_cube', title: 'Fidget Cube Digital', emoji: '🎲', implemented: true,
      gradient: [Color(0xFF30CFD0), Color(0xFF330867)],
      channels: [SensoryChannel.tactile, SensoryChannel.proprioceptive]),
  ToyMeta(id: 'calm_clouds', title: 'Calm Clouds', emoji: '☁️', implemented: true,
      gradient: [Color(0xFF89F7FE), Color(0xFF66A6FF)],
      channels: [SensoryChannel.visual, SensoryChannel.tactile]),
  ToyMeta(id: 'rainbow_rain', title: 'Rainbow Rain', emoji: '🌈', implemented: true,
      gradient: [Color(0xFF43CEA2), Color(0xFF185A9D)],
      channels: [SensoryChannel.visual, SensoryChannel.auditory]),
  // --- Tactile / advanced toys ---
  ToyMeta(id: 'slime', title: 'Slime Stretch', emoji: '🟢', implemented: true,
      gradient: [Color(0xFF96E6A1), Color(0xFFD4FC79)],
      channels: [SensoryChannel.tactile, SensoryChannel.proprioceptive]),
  ToyMeta(id: 'color_mix', title: 'Color Mixing Lab', emoji: '🎨', implemented: true,
      gradient: [Color(0xFFFAD961), Color(0xFFF76B1C)],
      channels: [SensoryChannel.visual]),
  ToyMeta(id: 'car_track', title: 'Car Track Builder', emoji: '🏎️', implemented: true,
      gradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
      channels: [SensoryChannel.visual, SensoryChannel.proprioceptive]),
  ToyMeta(id: 'spin_universe', title: 'Spin Universe', emoji: '🪐', implemented: true,
      gradient: [Color(0xFF200122), Color(0xFF6F0000)],
      channels: [SensoryChannel.visual, SensoryChannel.vestibular]),
  ToyMeta(id: 'marble_run', title: 'Infinite Marble Run', emoji: '🔵', implemented: true,
      gradient: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
      channels: [SensoryChannel.visual, SensoryChannel.proprioceptive]),
];

ToyMeta toyMetaById(String id) =>
    kToyCatalog.firstWhere((t) => t.id == id, orElse: () => kToyCatalog.first);
