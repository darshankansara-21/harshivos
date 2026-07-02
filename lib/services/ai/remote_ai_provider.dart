import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/social_story.dart';
import 'ai_provider.dart';
import 'mock_ai_provider.dart';

/// A live LLM provider that speaks to Ollama (local), Gemini or OpenAI over
/// HTTP.
///
/// All structured calls request strict JSON and fall back to [MockAiProvider]
/// on any error, so the UX never breaks. Configure via
/// assets/config/ai_config.json (+ optional gitignored secrets.json).
///
/// - `ollama` → local, free, private. No key; needs a running Ollama daemon.
/// - `gemini` → Google AI Studio free tier. Best for mobile builds.
/// - `openai` → paid.
class RemoteAiProvider implements AiProvider {
  RemoteAiProvider({
    required this.providerName,
    this.apiKey = '',
    required this.model,
    this.baseUrl = 'http://localhost:11434',
    this.temperature = 0.7,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _fallback = MockAiProvider();

  final String providerName; // 'ollama' | 'gemini' | 'openai'
  final String apiKey;
  final String model;
  final String baseUrl; // used by Ollama
  final double temperature;
  final http.Client _client;
  final MockAiProvider _fallback;

  @override
  String get name => providerName;

  bool get _isGemini => providerName == 'gemini';
  bool get _isOllama => providerName == 'ollama';

  @override
  Future<String> complete(String prompt, {String? system}) async {
    try {
      return await _chat(system: system, user: prompt);
    } catch (_) {
      return _fallback.complete(prompt, system: system);
    }
  }

  @override
  Future<String> expandPhrase(String basePhrase) async {
    try {
      final reply = await _chat(
        system: 'You expand a short AAC phrase from an autistic child into one '
            'warm, grammatically complete first-person sentence. Reply with the '
            'sentence only.',
        user: basePhrase,
      );
      return reply.trim();
    } catch (_) {
      return _fallback.expandPhrase(basePhrase);
    }
  }

  @override
  Future<SocialStory> generateStory(StoryRequest request) async {
    try {
      final json = await _chatJson(
        system: 'You write gentle, first-person social stories for autistic '
            'children. Reply with strict JSON: '
            '{"title":str,"pages":[{"text":str,"emoji":str,"imagePrompt":str}]}.',
        user: 'Situation: ${request.situation}. '
            'Child name: ${request.childName}. '
            'Pages: ${request.pageCount}.',
      );
      final pages = (json['pages'] as List<dynamic>)
          .map((e) => SocialStoryPage.fromJson(e as Map<String, dynamic>))
          .toList();
      return SocialStory(
        title: (json['title'] as String?) ?? request.situation,
        situation: request.situation,
        pages: pages,
      );
    } catch (_) {
      return _fallback.generateStory(request);
    }
  }

  @override
  Future<CopilotReply> assistCaregiver(CopilotRequest request) async {
    try {
      final json = await _chatJson(
        system: 'You are a calm, non-judgemental autism parenting coach. Reply '
            'with strict JSON: {"summary":str,"likelyCauses":[str],'
            '"regulationActivities":[str],"communicationPrompts":[str],'
            '"environmentChanges":[str]}.',
        user: request.message + (request.context != null ? '\n\nContext: ${request.context}' : ''),
      );
      List<String> list(String k) =>
          ((json[k] as List<dynamic>?) ?? const <dynamic>[]).cast<String>();
      return CopilotReply(
        summary: (json['summary'] as String?) ?? '',
        likelyCauses: list('likelyCauses'),
        regulationActivities: list('regulationActivities'),
        communicationPrompts: list('communicationPrompts'),
        environmentChanges: list('environmentChanges'),
      );
    } catch (_) {
      return _fallback.assistCaregiver(request);
    }
  }

  // ---- transport -----------------------------------------------------------

  /// Best-effort reachability probe used by [AiService] to auto-select a
  /// provider at startup. Returns true if the backend is likely usable.
  Future<bool> isReachable({Duration timeout = const Duration(milliseconds: 1200)}) async {
    try {
      if (_isOllama) {
        final res = await _client
            .get(Uri.parse('$baseUrl/api/tags'))
            .timeout(timeout);
        return res.statusCode == 200;
      }
      // Cloud providers are "reachable" as long as a key was supplied; we don't
      // burn a request just to probe.
      return apiKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _chatJson({
    required String system,
    required String user,
  }) async {
    final raw = await _chat(system: system, user: user, json: true);
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1) throw const FormatException('No JSON in reply');
    return jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
  }

  Future<String> _chat({String? system, required String user, bool json = false}) {
    if (_isOllama) return _ollama(system, user, json);
    if (_isGemini) return _gemini(system, user, json);
    return _openai(system, user, json);
  }

  Future<String> _ollama(String? system, String user, bool json) async {
    final uri = Uri.parse('$baseUrl/api/chat');
    final body = <String, dynamic>{
      'model': model,
      'stream': false,
      if (json) 'format': 'json',
      'options': <String, dynamic>{'temperature': temperature},
      'messages': <Map<String, String>>[
        if (system != null) <String, String>{'role': 'system', 'content': system},
        <String, String>{'role': 'user', 'content': user},
      ],
    };
    final res = await _client.post(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw http.ClientException('Ollama ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (decoded['message'] as Map<String, dynamic>)['content'] as String;
  }

  Future<String> _gemini(String? system, String user, bool json) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final body = <String, dynamic>{
      if (system != null)
        'systemInstruction': <String, dynamic>{
          'parts': <Map<String, String>>[<String, String>{'text': system}],
        },
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'parts': <Map<String, String>>[<String, String>{'text': user}],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': temperature,
        if (json) 'responseMimeType': 'application/json',
      },
    };
    final res = await _client.post(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw http.ClientException('Gemini ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>;
    final parts = (candidates.first as Map<String, dynamic>)['content']
        ['parts'] as List<dynamic>;
    return (parts.first as Map<String, dynamic>)['text'] as String;
  }

  Future<String> _openai(String? system, String user, bool json) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final res = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(<String, dynamic>{
        'model': model,
        'temperature': temperature,
        if (json) 'response_format': <String, String>{'type': 'json_object'},
        'messages': <Map<String, String>>[
          if (system != null) <String, String>{'role': 'system', 'content': system},
          <String, String>{'role': 'user', 'content': user},
        ],
      }),
    );
    if (res.statusCode != 200) {
      throw http.ClientException('OpenAI ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>;
    return (choices.first as Map<String, dynamic>)['message']['content'] as String;
  }
}
