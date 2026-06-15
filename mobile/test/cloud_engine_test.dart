import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:talk2text_mobile/models/app_settings.dart';
import 'package:talk2text_mobile/storage/secret_store.dart';
import 'package:talk2text_mobile/stt/cloud_engine.dart';

class _FakeSecrets implements SecretStore {
  _FakeSecrets(this.key);
  String? key;

  @override
  Future<String?> getApiKey() async => key;
  @override
  Future<void> setApiKey(String value) async => key = value;
  @override
  Future<void> clearApiKey() async => key = null;
  @override
  Future<bool> hasApiKey() async => key != null && key!.isNotEmpty;
}

void main() {
  test('isReady reflects whether an API key is present', () async {
    final ready = CloudEngine(
      secretStore: _FakeSecrets('sk-test'),
      client: MockClient((_) async => http.Response('', 200)),
    );
    final notReady = CloudEngine(
      secretStore: _FakeSecrets(null),
      client: MockClient((_) async => http.Response('', 200)),
    );
    expect(await ready.isReady(), isTrue);
    expect(await notReady.isReady(), isFalse);
  });

  test('transcribe posts to /audio/transcriptions and returns text', () async {
    late Uri seenUri;
    String? seenAuth;
    final engine = CloudEngine(
      secretStore: _FakeSecrets('sk-test'),
      client: MockClient((request) async {
        seenUri = request.url;
        seenAuth = request.headers['Authorization'];
        return http.Response('{"text": "hello world"}', 200);
      }),
    )..configure(const AppSettings(
        engineId: 'cloud',
        cloudBaseUrl: 'https://api.example.com/v1',
      ));

    // A file is needed for the multipart part; reuse this test file's path.
    final text = await engine.transcribe('test/cloud_engine_test.dart');

    expect(text, 'hello world');
    expect(seenUri.toString(),
        'https://api.example.com/v1/audio/transcriptions');
    expect(seenAuth, 'Bearer sk-test');
  });

  test('translate-to-English posts to /audio/translations', () async {
    late Uri seenUri;
    final engine = CloudEngine(
      secretStore: _FakeSecrets('sk-test'),
      client: MockClient((request) async {
        seenUri = request.url;
        return http.Response('{"text": "hello world"}', 200);
      }),
    )..configure(const AppSettings(
        engineId: 'cloud',
        cloudBaseUrl: 'https://api.example.com/v1',
        language: 'es',
        outputLanguage: 'en',
      ));

    final text = await engine.transcribe('test/cloud_engine_test.dart');

    expect(text, 'hello world');
    expect(seenUri.toString(),
        'https://api.example.com/v1/audio/translations');
  });

  test('transcribe surfaces non-200 errors', () async {
    final engine = CloudEngine(
      secretStore: _FakeSecrets('sk-test'),
      client: MockClient((_) async => http.Response('nope', 401)),
    );
    expect(
      () => engine.transcribe('test/cloud_engine_test.dart'),
      throwsA(isA<Exception>()),
    );
  });
}
