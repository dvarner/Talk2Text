import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/recorder.dart';
import '../stt/transcription_engine.dart';

enum AppStatus { idle, recording, transcribing, error }

/// Single source of truth for the screen, mirroring the desktop app's
/// `Talk2TextApp` controller responsibilities (record toggle, live timer,
/// transcribe-on-stop) but as a [ChangeNotifier] driving the Flutter UI.
class AppController extends ChangeNotifier {
  AppController({AudioCapture? recorder, TranscriptionEngine? engine})
      : _recorder = recorder ?? Recorder(),
        _engine = engine ?? StubEngine();

  final AudioCapture _recorder;
  // Becomes swappable in Phase 5 (engine picker); single engine for now.
  final TranscriptionEngine _engine;

  AppStatus _status = AppStatus.idle;
  AppStatus get status => _status;

  String _transcript = '';
  String get transcript => _transcript;

  String _message = 'Ready — tap Record to start';
  String get message => _message;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();

  bool get isRecording => _status == AppStatus.recording;
  bool get isBusy => _status == AppStatus.transcribing;
  bool get hasTranscript => _transcript.trim().isNotEmpty;

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

    _status = AppStatus.transcribing;
    _message = 'Transcribing…';
    notifyListeners();

    if (path == null) {
      _status = AppStatus.error;
      _message = 'No audio captured. Try again.';
      notifyListeners();
      return;
    }

    try {
      if (!await _engine.isReady()) await _engine.prepare();
      _transcript = await _engine.transcribe(path);
      _status = AppStatus.idle;
      _message = 'Done!';
    } catch (e) {
      _status = AppStatus.error;
      _message = 'Transcription failed: $e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
