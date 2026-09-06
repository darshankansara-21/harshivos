import 'avatar.dart';

/// Serializable child profile data used by experience engines.
///
/// This wraps the existing avatar configuration with a stable id and display
/// name so one profile can participate across routines, stories and adventures.
class AvatarProfile {
  const AvatarProfile({
    required this.id,
    required this.name,
    required this.avatar,
    this.joinHeroWorld = true,
  });

  final String id;
  final String name;
  final AvatarConfig avatar;
  final bool joinHeroWorld;

  AvatarProfile copyWith({
    String? id,
    String? name,
    AvatarConfig? avatar,
    bool? joinHeroWorld,
  }) {
    return AvatarProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      joinHeroWorld: joinHeroWorld ?? this.joinHeroWorld,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'avatar': avatar.toJson(),
        'joinHeroWorld': joinHeroWorld,
      };

  factory AvatarProfile.fromJson(Map<String, dynamic> json) => AvatarProfile(
        id: json['id'] as String? ?? 'child-1',
        name: json['name'] as String? ?? 'Friend',
        avatar: AvatarConfig.fromJson(
            (json['avatar'] as Map<String, dynamic>?) ??
                const <String, dynamic>{}),
        joinHeroWorld: json['joinHeroWorld'] as bool? ?? true,
      );
}