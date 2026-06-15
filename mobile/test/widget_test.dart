import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:talk2text_mobile/home_page.dart';
import 'package:talk2text_mobile/models/app_settings.dart';
import 'package:talk2text_mobile/state/app_controller.dart';
import 'package:talk2text_mobile/storage/secret_store.dart';
import 'package:talk2text_mobile/storage/settings_store.dart';
import 'package:talk2text_mobile/stt/claude_translator.dart';
import 'package:talk2text_mobile/stt/transcription_engine.dart';

import 'fakes.dart';

AppController _controller({SettingsStore? settingsStore}) => AppController(
      recorder: FakeCapture(),
      engines: {'stub': StubEngine()},
      store: FakeStore(),
      settingsStore: settingsStore ?? FakeSettingsStore(),
      secretStore: FakeSecretStore(),
    );

void main() {
  test('timerLabel formats as MM:SS', () {
    expect(_controller().timerLabel, '00:00');
  });

  test('record then stop transcribes and auto-saves', () async {
    final store = FakeStore();
    final c = AppController(
      recorder: FakeCapture(),
      engines: {'stub': StubEngine()},
      store: store,
      settingsStore: FakeSettingsStore(),
      secretStore: FakeSecretStore(),
    );

    await c.toggleRecord(); // start
    expect(c.isRecording, isTrue);

    await c.toggleRecord(); // stop + transcribe + save
    expect(c.isRecording, isFalse);
    expect(c.status, AppStatus.idle);
    expect(c.hasTranscript, isTrue);
    expect(c.savedPath, isNotNull);
    expect(store.saved, hasLength(1));
  });

  test('applySettings persists and reconfigures the engine', () async {
    final settingsStore = FakeSettingsStore();
    final c = _controller(settingsStore: settingsStore);

    const next = AppSettings(modelSize: 'small', language: 'fr');
    await c.applySettings(next);

    expect(c.settings, next);
    expect(settingsStore.saved, next);
  });

  test('setApiKey / hasApiKey / clearApiKey round-trip via secret store',
      () async {
    final secrets = FakeSecretStore();
    final c = AppController(
      recorder: FakeCapture(),
      engines: {'stub': StubEngine()},
      store: FakeStore(),
      settingsStore: FakeSettingsStore(),
      secretStore: secrets,
    );

    expect(await c.hasApiKey(), isFalse);
    await c.setApiKey('sk-test');
    expect(await c.hasApiKey(), isTrue);
    expect(secrets.store[SecretKeys.cloudApiKey], 'sk-test');
    await c.clearApiKey();
    expect(await c.hasApiKey(), isFalse);
  });

  test('non-English output language runs the Claude translation step',
      () async {
    final secrets = FakeSecretStore({SecretKeys.anthropicApiKey: 'sk-ant'});
    final translator = ClaudeTranslator(
      secretStore: secrets,
      client: MockClient((_) async => http.Response(
            '{"content":[{"type":"text","text":"Hola"}]}',
            200,
          )),
    );
    final store = FakeStore();
    final c = AppController(
      recorder: FakeCapture(),
      engines: {'stub': StubEngine()},
      store: store,
      settingsStore: FakeSettingsStore()
        ..saved = const AppSettings(outputLanguage: 'es'),
      secretStore: secrets,
      translator: translator,
    );
    await c.init();

    await c.toggleRecord(); // start
    await c.toggleRecord(); // stop → transcribe → translate

    expect(c.transcript, 'Hola');
    expect(store.saved.single, 'Hola');
  });

  test('live engine path uses startListening/stopListening, not the recorder',
      () async {
    final live = FakeLiveEngine();
    final capture = FakeCapture();
    final c = AppController(
      recorder: capture,
      engines: {'live': live},
      store: FakeStore(),
      settingsStore: FakeSettingsStore(),
      secretStore: FakeSecretStore(),
    );

    await c.toggleRecord(); // start → startListening
    expect(live.started, isTrue);
    expect(c.isRecording, isTrue);

    await c.toggleRecord(); // stop → stopListening
    expect(live.stopped, isTrue);
    expect(c.transcript, 'live transcript');
    expect(c.status, AppStatus.idle);
  });

  testWidgets('home screen shows the action buttons', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => _controller(),
        child: const MaterialApp(home: HomePage()),
      ),
    );

    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });
}
