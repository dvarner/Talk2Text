import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Microphone capture seam. Kept as an interface so the controller can be
/// unit-tested with a fake that doesn't touch platform channels.
abstract class AudioCapture {
  Future<bool> hasPermission();

  /// Starts capture. Returns false if mic permission is denied.
  Future<bool> start();

  /// Stops recording and returns the path to the captured WAV, or null.
  Future<String?> stop();

  Future<bool> isRecording();

  Future<void> dispose();
}

/// Thin wrapper over the `record` plugin that captures 16 kHz mono WAV — the
/// input format Whisper expects (matches the desktop app's SAMPLE_RATE = 16000).
class Recorder implements AudioCapture {
  static const int sampleRate = 16000;

  final AudioRecorder _record = AudioRecorder();
  String? _currentPath;

  @override
  Future<bool> hasPermission() => _record.hasPermission();

  @override
  Future<bool> start() async {
    if (!await _record.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/talk2text_recording.wav';
    _currentPath = path;
    await _record.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
      path: path,
    );
    return true;
  }

  @override
  Future<String?> stop() async {
    final path = await _record.stop();
    return path ?? _currentPath;
  }

  @override
  Future<bool> isRecording() => _record.isRecording();

  @override
  Future<void> dispose() => _record.dispose();
}
