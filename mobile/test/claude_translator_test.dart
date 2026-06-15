import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:talk2text_mobile/storage/secret_store.dart';
import 'package:talk2text_mobile/stt/claude_translator.dart';

import 'fakes.dart';

void main() {
  test('translate posts to the Anthropic Messages API and returns text',
      () async {
    late Uri seenUri;
    String? seenKey;
    Object? seenBody;
    final translator = ClaudeTranslator(
      secretStore: FakeSecretStore({SecretKeys.anthropicApiKey: 'sk-ant-1'}),
      client: MockClient((request) async {
        seenUri = request.url;
        seenKey = request.headers['x-api-key'];
        seenBody = request.body;
        return http.Response(
          '{"content":[{"type":"text","text":"Hola mundo"}]}',
          200,
        );
      }),
    );

    final out = await translator.translate('Hello world', 'Spanish');

    expect(out, 'Hola mundo');
    expect(seenUri.toString(), 'https://api.anthropic.com/v1/messages');
    expect(seenKey, 'sk-ant-1');
    expect(seenBody, contains('Spanish')); // target language in the system prompt
    expect(seenBody, contains('claude-haiku-4-5'));
  });

  test('translate throws when no Claude key is set', () async {
    final translator = ClaudeTranslator(
      secretStore: FakeSecretStore(),
      client: MockClient((_) async => http.Response('', 200)),
    );
    expect(
      () => translator.translate('Hi', 'French'),
      throwsA(isA<Exception>()),
    );
  });

  test('translate surfaces non-200 errors', () async {
    final translator = ClaudeTranslator(
      secretStore: FakeSecretStore({SecretKeys.anthropicApiKey: 'sk-ant-1'}),
      client: MockClient((_) async => http.Response('nope', 401)),
    );
    expect(
      () => translator.translate('Hi', 'French'),
      throwsA(isA<Exception>()),
    );
  });
}
