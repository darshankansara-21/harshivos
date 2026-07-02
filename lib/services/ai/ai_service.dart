import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'ai_provider.dart';
import 'mock_ai_provider.dart';
import 'remote_ai_provider.dart';

/// Selects and constructs the active [AiProvider] from configuration.
///
/// Reads assets/config/ai_config.json (+ optional gitignored secrets.json).
/// With `provider: "auto"` (the default) it prefers a local **Ollama** daemon
/// (free + private, ideal on desktop/web), then falls back to **Gemini Flash**
/// if an API key is present (ideal on mobile), and finally to the fully-offline
/// **Mock** provider so the app always works out of the box.
class AiService {
  AiService._(this.provider);

  final AiProvider provider;

  static Future<AiService> create() async {
    final config = await _readJsonAsset('assets/config/ai_config.json');
    final secrets = await _readJsonAsset('assets/config/secrets.json');

    final mode = (config['provider'] as String?) ?? 'auto';
    final temperature = (config['temperature'] as num?)?.toDouble() ?? 0.7;

    final ollamaCfg = (config['ollama'] as Map<String, dynamic>?) ?? const {};
    final geminiCfg = (config['gemini'] as Map<String, dynamic>?) ?? const {};
    final ollamaBaseUrl =
        (ollamaCfg['baseUrl'] as String?) ?? 'http://localhost:11434';
    final ollamaModel = (ollamaCfg['model'] as String?) ?? 'llama3.2';
    final geminiModel =
        (geminiCfg['model'] as String?) ?? (config['model'] as String?) ?? 'gemini-1.5-flash';
    // Accept either the new or the legacy secrets key.
    final geminiKey = (secrets['geminiApiKey'] as String?) ??
        (secrets['apiKey'] as String?) ??
        '';

    RemoteAiProvider buildOllama() => RemoteAiProvider(
          providerName: 'ollama',
          model: ollamaModel,
          baseUrl: ollamaBaseUrl,
          temperature: temperature,
        );
    RemoteAiProvider buildGemini() => RemoteAiProvider(
          providerName: 'gemini',
          apiKey: geminiKey,
          model: geminiModel,
          temperature: temperature,
        );

    switch (mode) {
      case 'mock':
        return AiService._(MockAiProvider());
      case 'ollama':
        final o = buildOllama();
        return AiService._(await o.isReachable() ? o : MockAiProvider());
      case 'gemini':
      case 'openai':
        return AiService._(
            geminiKey.isEmpty ? MockAiProvider() : buildGemini());
      case 'auto':
      default:
        // 1) Local Ollama if the daemon is up.
        final o = buildOllama();
        if (await o.isReachable()) return AiService._(o);
        // 2) Gemini Flash if a key is configured (mobile path).
        if (geminiKey.isNotEmpty) return AiService._(buildGemini());
        // 3) Always-available offline fallback.
        return AiService._(MockAiProvider());
    }
  }

  static Future<Map<String, dynamic>> _readJsonAsset(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
