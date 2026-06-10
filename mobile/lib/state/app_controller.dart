import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/recorder.dart';
import '../models/app_settings.dart';
import '../storage/secret_store.dart';
import '../storage/settings_store.dart';
import '../storage/transcript_store.dart';
import '../stt/cloud_engine.dart';
import '../stt/native_speech_engine.dart';
import '../stt/transcription_engine.dart';
import '../stt/whisper_engine.dart';

enum AppStatus { idle, recording, transcribing, error }

/// Single source of truth for the screen, mirroring the desktop app's
/// `Talk2TextApp` controller responsibilities (record toggle, live timer,
/// transcribe-on-stop, auto-save, settings) but as a [ChangeNotifier].
class AppController extends ChangeNotifier {
  factory AppController({
    AudioCapture? recorder,
    TranscriptStore? store,
    SettingsStore? settingsStore,
    SecretStore? secretStore,
    Map<String, TranscriptionEngine>? engines,
  }) {
    final secrets = secretStore ?? SecureSecretStore();
    return AppController._(
      recorder ?? Recorder(),
      store ?? FileTranscriptStore(),
      settingsStore ?? PrefsSettingsStore(),
      secrets,
      engines ??
          {
            'whisper': WhisperEngine(),
            'native': NativeSpeechEngine(),
            'cloud': CloudEngine(secretStore: secrets),
          },
    );
  }

  AppController._(
    this._recorder,
    this._store,
    this._settingsStore,
    this._secretStore,
    this._engines,
  );

  final AudioCapture _recorder;
  final TranscriptStore _store;
  final SettingsStore _settingsStore;
  final SecretStore _secretStore;

  /// Available engines keyed by id; the active one is chosen by
  /// [AppSettings.engineId].
  final Map<String, TranscriptionEngine> _engines;

  /// The engine selected in settings, falling back to the first registered.
  TranscriptionEngine get _engine =>
      _engines[_settings.engineId] ?? _engines.values.first;

  /// Engines available for the settings picker.
  List<TranscriptionEngine> get engines => _engines.values.toList();

  AppSettings _settings = AppSettings.defaults;
  AppSettings get settings => _settings;

  AppStatus _status = AppStatus.idle;
  AppStatus get status => _status;

  String _transcript = '';
  String get transcript => _transcript;

  String? _savedPath;
  String? get savedPath => _savedPath;

  String _message = 'Ready — tap Record to start';
  String get message => _message;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();

  bool get isRecording => _status == AppStatus.recording;
  bool get isBusy => _status == AppStatus.transcribing;
  bool get hasTranscript => _transcript.trim().isNotEmpty;

  /// Loads persisted settings and applies them to every engine. Call once at
  /// startup (e.g. `AppController()..init()`).
  Future<void> init() async {
    _settings = await _settingsStore.load();
    _configureEngines();
    if (_status == AppStatus.idle) {
      _message = _idleMessage();
      notifyListeners();
    }
  }

  /// Persists [settings] and reconfigures every engine (model, language, cloud).
  Future<void> applySettings(AppSettings settings) async {
    _settings = settings;
    _configureEngines();
    await _settingsStore.save(settings);
    if (_status == AppStatus.idle) {
      _message = _idleMessage();
    }
    notifyListeners();
  }

  void _configureEngines() {
    for (final engine in _engines.values) {
      engine.configure(_settings);
    }
  }

  // ── Cloud API key (secure storage) ──────────────────────────────────────
  Future<bool> hasApiKey() => _secretStore.hasApiKey();

  Future<void> setApiKey(String key) async {
    await _secretStore.setApiKey(key.trim());
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    await _secretStore.clearApiKey();
    notifyListeners();
  }

  String _idleMessage() {
    final label = _settings.engineId == 'whisper'
        ? _settings.modelSize
        : _engine.label;
    return 'Ready ($label) — tap Record to start';
  }

  /// "MM:SS" elapsed-time label, matching the desktop timer format.
  String get timerLabel {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> toggleRecord() async {
    if (isRecording) {
      await _stop();
    } else if (!isBusy) {
      await _start();
    }
  }

  Future<void> _start() async {
    final engine = _engine;
    // Live engines (OS recognizers) capture themselves; others use the recorder.
    final ok = engine is LiveTranscriptionEngine
        ? await engine.startListening()
        : await _recorder.start();
    if (!ok) {
      _status = AppStatus.error;
      _message = 'Could not start. Check microphone permissions.';
      notifyListeners();
      return;
    }
    _transcript = '';
    _savedPath = null;
    _status = AppStatus.recording;
    _message = 'Recording…';
    _elapsed = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsed = _stopwatch.elapsed;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _stopwatch.stop();
    final engine = _engine;

    try {
      _status = AppStatus.transcribing;
      if (engine is LiveTranscriptionEngine) {
        _message = 'Finishing…';
        notifyListeners();
        _transcript = await engine.stopListening();
      } else {
        final path = await _recorder.stop();
        if (path == null) {
          _status = AppStatus.error;
          _message = 'No audio captured. Try again.';
          notifyListeners();
          return;
        }
        if (!await engine.isReady()) {
          // First run downloads the model (e.g. ~142 MB for base).
          _message = 'Downloading ${engine.label} model (first run)…';
          notifyListeners();
          await engine.prepare();
        }
        _message = 'Transcribing…';
        notifyListeners();
        _transcript = await engine.transcribe(path);
      }

      _savedPath = await _store.save(_transcript);
      _status = AppStatus.idle;
      _message = _savedPath != null ? 'Done! Saved.' : 'Done! (auto-save failed)';
    } catch (e) {
      _status = AppStatus.error;
      _message = 'Transcription failed: $e';
    }
    notifyListeners();
  }

  // ── Saved transcripts (mobile has no file browser) ──────────────────────
  Future<List<TranscriptFile>> listTranscripts() => _store.list();
  Future<String> readTranscript(String path) => _store.read(path);
  Future<void> deleteTranscript(String path) => _store.delete(path);

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
