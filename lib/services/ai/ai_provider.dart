import '../../models/social_story.dart';

/// Request payload for generating a social story.
class StoryRequest {
  const StoryRequest({
    required this.situation,
    this.childName = 'I',
    this.pageCount = 5,
  });

  final String situation;
  final String childName;
  final int pageCount;
}

/// A free-form caregiver question for Parent Copilot.
class CopilotRequest {
  const CopilotRequest({required this.message, this.context});

  final String message;
  final String? context;
}

/// Structured advice returned to a caregiver.
class CopilotReply {
  const CopilotReply({
    required this.summary,
    required this.likelyCauses,
    required this.regulationActivities,
    required this.communicationPrompts,
    required this.environmentChanges,
  });

  final String summary;
  final List<String> likelyCauses;
  final List<String> regulationActivities;
  final List<String> communicationPrompts;
  final List<String> environmentChanges;
}

/// Provider-agnostic contract for the AI layer.
///
/// Concrete implementations: [MockAiProvider] (offline), `GeminiProvider`,
/// `OpenAiProvider`. The rest of the app only ever talks to this interface.
abstract class AiProvider {
  String get name;

  Future<String> complete(String prompt, {String? system});

  Future<SocialStory> generateStory(StoryRequest request);

  Future<CopilotReply> assistCaregiver(CopilotRequest request);

  /// Suggest a richer phrasing for a tapped communication item.
  Future<String> expandPhrase(String basePhrase);
}
