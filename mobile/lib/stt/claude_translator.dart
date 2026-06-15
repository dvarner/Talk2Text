import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/secret_store.dart';

/// Second-stage translator: turns a transcript (in whatever language was
/// spoken) into a chosen target language using Claude Haiku.
///
/// Used only when the output language is something *other* than "native" or
/// English — English is handled offline by Whisper's built-in translate task,
/// while arbitrary targets (Spanish, French, …) need real machine translation.
/// Only the transcript *text* is sent to the API; the audio never leaves the
/// device.
class ClaudeTranslator {
  ClaudeTranslator({required SecretStore secretStore, http.Client? client})
      : _secrets = secretStore,
        _client = client ?? http.Client();

  final SecretStore _secrets;
  final http.Client _client;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  // Haiku is fast and cheap — a good default for short, high-resource-language
  // translation. The caller can pass a stronger model for harder languages.
  static const defaultModel = 'claude-haiku-4-5';

  Future<bool> hasKey() => _secrets.has(SecretKeys.anthropicApiKey);

  /// Translates [text] into [targetLanguage] (a human-readable name such as
  /// "Spanish") with [model], and returns the translation only.
  Future<String> translate(
    String text,
    String targetLanguage, {
    String model = defaultModel,
  }) async {
    if (text.trim().isEmpty) return text;

    final key = await _secrets.read(SecretKeys.anthropicApiKey);
    if (key == null || key.isEmpty) {
      throw Exception('No Claude API key set — add one in Settings.');
    }

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 2048,
        'system': 'You are a translation engine. Translate the user message '
            'into $targetLanguage. Output only the translation — no preamble, '
            'notes, or surrounding quotation marks. Preserve meaning, tone, '
            'and line breaks.',
        'messages': [
          {'role': 'user', 'content': text},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Translation failed (${response.statusCode}): '
          '${response.body.isEmpty ? 'no response body' : response.body}');
    }

    final decoded = jsonDecode(response.body);
    final content = decoded is Map<String, dynamic> ? decoded['content'] : null;
    if (content is List) {
      final buffer = StringBuffer();
      for (final block in content) {
        if (block is Map &&
            block['type'] == 'text' &&
            block['text'] is String) {
          buffer.write(block['text']);
        }
      }
      final out = buffer.toString().trim();
      if (out.isNotEmpty) return out;
    }
    throw Exception('Unexpected response from translation API.');
  }
}
