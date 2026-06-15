import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_settings.dart';
import '../storage/secret_store.dart';
import 'transcription_engine.dart';

/// Cloud transcription backend targeting the OpenAI-compatible
/// `POST {baseUrl}/audio/transcriptions` endpoint (configurable base URL so
/// other providers can be used). Only available once the user supplies an API
/// key, which is read from secure storage — never persisted in settings.
class CloudEngine implements TranscriptionEngine {
  CloudEngine({required SecretStore secretStore, http.Client? client})
      : _secrets = secretStore,
        _client = client ?? http.Client();

  final SecretStore _secrets;
  final http.Client _client;

  String _baseUrl = AppSettings.defaults.cloudBaseUrl;
  String _model = AppSettings.defaults.cloudModel;
  String _language = AppSettings.defaults.language;
  bool _translateToEnglish = AppSettings.defaults.translateToEnglish;

  @override
  String get id => 'cloud';

  @override
  String get label => 'Cloud API';

  @override
  void configure(AppSettings settings) {
    _baseUrl = settings.cloudBaseUrl.trim();
    _model = settings.cloudModel.trim();
    _language = settings.language.trim();
    _translateToEnglish = settings.translateToEnglish;
  }

  @override
  Future<bool> isReady() => _secrets.hasApiKey();

  @override
  Future<void> prepare() async {
    if (!await _secrets.hasApiKey()) {
      throw Exception('No API key set — add one in Settings.');
    }
  }

  @override
  Future<String> transcribe(String wavPath) async {
    final key = await _secrets.getApiKey();
    if (key == null || key.isEmpty) {
      throw Exception('No API key set — add one in Settings.');
    }

    // OpenAI-compatible APIs translate-to-English via a separate endpoint that
    // always returns English text (and ignores the `language` source hint).
    final endpoint =
        _translateToEnglish ? '/audio/translations' : '/audio/transcriptions';
    final uri =
        Uri.parse('${_baseUrl.replaceAll(RegExp(r'/+$'), '')}$endpoint');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $key'
      ..fields['model'] = _model
      ..files.add(await http.MultipartFile.fromPath('file', wavPath));
    if (_language.isNotEmpty && !_translateToEnglish) {
      request.fields['language'] = _language;
    }

    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception('Cloud transcription failed (${streamed.statusCode}): '
          '${body.isEmpty ? 'no response body' : body}');
    }

    final decoded = jsonDecode(body);
    final text = decoded is Map<String, dynamic> ? decoded['text'] : null;
    if (text is! String) {
      throw Exception('Unexpected response from cloud API.');
    }
    return text.trim();
  }
}
