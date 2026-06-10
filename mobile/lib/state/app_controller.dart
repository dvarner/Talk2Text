import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/recorder.dart';
import '../models/app_settings.dart';
import '../storage/settings_store.dart';
import '../storage/transcript_store.dart';
import '../stt/transcription_engine.dart';
import '../stt/whisper_engine.dart';

enum AppStatus { idle, recording, transcribing, error }

/// Single source of truth for the screen, mirroring the desktop app's
/// `Talk2TextApp` controller responsibilities (record toggle, live timer,
/// transcribe-on-stop, auto-save, settings) but as a [ChangeNotifier].
class AppController extends ChangeNotifier {
  AppController({
    AudioCapture? recorder,
    TranscriptionEngine? engine,
    TranscriptStore? store,
    SettingsStore? settingsStore,
  })  : _recorder = recorder ?? Recorder(),
        _engine = engine ?? WhisperEngine(),
        _store = store ?? FileTranscriptStore(),
        _settingsStore = settingsStore ?? PrefsSettingsStore();

  final AudioCapture _recorder;
  // Becomes swappable in Phase 5 (engine picker); single engine for now.
  final TranscriptionEngine _engine;
  final TranscriptStore _store;
  final SettingsStore _settingsStore;

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

  /// Loads persisted settings and applies them to the active engine. Call once
  /// at startup (e.g. `AppController()..init()`).
  Future<void> init() async {
    _settings = await _settingsStore.load();
    _engine.configure(_settings);
    if (_status == AppStatus.idle) {
      _message = _idleMessage();
      notifyListeners();
    }
  }

  /// Persists [settings] and reconfigures the engine (model size / language).
  Future<void> applySettings(AppSettings settings) async {
    _settings = settings;
    _engine.configure(settings);
    await _settingsStore.save(settings);
    if (_status == AppStatus.idle) {
      _message = _idleMessage();
    }
    notifyListeners();
  }

  String _idleMessage() =>
      'Ready (${_settings.modelSize}) — tap Record to start';

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
    final ok = await _recorder.start();
    if (!ok) {
      _status = AppStatus.error;
      _message = 'Could not open microphone. Check permissions.';
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
    final path = await _recorder.stop();

    if (path == null) {
      _status = AppStatus.error;
      _message = 'No audio captured. Try again.';
      notifyListeners();
      return;
    }

    try {
      _status = AppStatus.transcribing;
      if (!await _engine.isReady()) {
        // First run downloads the model (e.g. ~142 MB for base).
        _message = 'Downloading ${_engine.label} model (first run)…';
        notifyListeners();
        await _engine.prepare();
      }
      _message = 'Transcribing…';
      notifyListeners();

      _transcript = await _engine.transcribe(path);
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
