import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:talk2text_mobile/audio/recorder.dart';
import 'package:talk2text_mobile/home_page.dart';
import 'package:talk2text_mobile/models/app_settings.dart';
import 'package:talk2text_mobile/state/app_controller.dart';
import 'package:talk2text_mobile/storage/secret_store.dart';
import 'package:talk2text_mobile/storage/settings_store.dart';
import 'package:talk2text_mobile/storage/transcript_store.dart';
import 'package:talk2text_mobile/stt/transcription_engine.dart';

/// In-memory capture that never touches platform channels, so the controller
/// and UI can be exercised in plain unit/widget tests.
class FakeCapture implements AudioCapture {
  bool _recording = false;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> start() async {
    _recording = true;
    return true;
  }

  @override
  Future<String?> stop() async {
    _recording = false;
    return '/tmp/fake.wav';
  }

  @override
  Future<bool> isRecording() async => _recording;

  @override
  Future<void> dispose() async {}
}

/// In-memory transcript store for tests (no filesystem / path_provider).
class FakeStore implements TranscriptStore {
  final List<String> saved = [];

  @override
  Future<String?> save(String text, {DateTime? at}) async {
    if (text.trim().isEmpty) return null;
    saved.add(text);
    return '/tmp/transcripts/fake.txt';
  }

  @override
  Future<List<TranscriptFile>> list() async => const [];

  @override
  Future<void> delete(String path) async {}

  @override
  Future<String> read(String path) async => '';
}

/// In-memory settings store for tests (no shared_preferences channel).
class FakeSettingsStore implements SettingsStore {
  AppSettings saved = AppSettings.defaults;

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

/// In-memory secret store for tests (no flutter_secure_storage channel).
class FakeSecretStore implements SecretStore {
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

/// Fake live engine (OS-recognizer style) recording its lifecycle calls.
class FakeLiveEngine implements LiveTranscriptionEngine {
  bool started = false;
  bool stopped = false;

  @override
  String get id => 'live';
  @override
  String get label => 'Device speech';
  @override
  void configure(AppSettings settings) {}
  @override
  Future<bool> isReady() async => true;
  @override
  Future<void> prepare() async {}
  @override
  Future<bool> startListening() async {
    started = true;
    return true;
  }

  @override
  Future<String> stopListening() async {
    stopped = true;
    return 'live transcript';
  }

  @override
  Future<String> transcribe(String wavPath) =>
      throw UnsupportedError('live engine');
}

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
    expect(secrets.key, 'sk-test');
    await c.clearApiKey();
    expect(await c.hasApiKey(), isFalse);
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
