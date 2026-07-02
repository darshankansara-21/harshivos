/// A generated social story (AI or template-based) used to rehearse situations.
class SocialStory {
  SocialStory({
    required this.title,
    required this.situation,
    required this.pages,
  });

  final String title;
  final String situation;
  final List<SocialStoryPage> pages;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'situation': situation,
        'pages': pages.map((p) => p.toJson()).toList(),
      };

  factory SocialStory.fromJson(Map<String, dynamic> json) => SocialStory(
        title: json['title'] as String,
        situation: json['situation'] as String,
        pages: (json['pages'] as List<dynamic>)
            .map((e) => SocialStoryPage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SocialStoryPage {
  SocialStoryPage({
    required this.text,
    required this.emoji,
    required this.imagePrompt,
  });

  /// Narrated, first-person, reassuring sentence.
  final String text;

  /// A friendly emoji stand-in until generated artwork is wired up.
  final String emoji;

  /// Prompt an image model would use to illustrate this page.
  final String imagePrompt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'emoji': emoji,
        'imagePrompt': imagePrompt,
      };

  factory SocialStoryPage.fromJson(Map<String, dynamic> json) => SocialStoryPage(
        text: json['text'] as String,
        emoji: json['emoji'] as String,
        imagePrompt: json['imagePrompt'] as String,
      );
}
