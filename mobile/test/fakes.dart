import 'package:talk2text_mobile/audio/recorder.dart';
import 'package:talk2text_mobile/models/app_settings.dart';
import 'package:talk2text_mobile/storage/secret_store.dart';
import 'package:talk2text_mobile/storage/settings_store.dart';
import 'package:talk2text_mobile/storage/transcript_store.dart';
import 'package:talk2text_mobile/stt/transcription_engine.dart';

/// Shared in-memory fakes so tests never touch platform channels.

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

class FakeSettingsStore implements SettingsStore {
  AppSettings saved = AppSettings.defaults;

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

class FakeSecretStore implements SecretStore {
  FakeSecretStore([Map<String, String>? seed]) : store = {...?seed};

  final Map<String, String> store;

  @override
  Future<String?> read(String name) async => store[name];

  @override
  Future<void> write(String name, String value) async => store[name] = value;

  @override
  Future<void> delete(String name) async => store.remove(name);

  @override
  Future<bool> has(String name) async {
    final v = store[name];
    return v != null && v.isNotEmpty;
  }
}

/// Live (OS-recognizer style) engine recording its lifecycle calls.
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
