import '../models/app_settings.dart';

/// The pluggable STT boundary. Every backend — on-device Whisper (default),
/// OS-native speech, or a cloud API — implements this interface, so the UI and
/// controller never need to know which engine actually ran. This mirrors the
/// desktop app's `Transcriber` seam while making the backend swappable.
abstract class TranscriptionEngine {
  /// Stable identifier, e.g. "whisper" | "native" | "cloud".
  String get id;

  /// Human-readable name shown in the settings engine picker.
  String get label;

  /// Apply user settings (model size, language, …). Engines use what applies
  /// to them and ignore the rest.
  void configure(AppSettings settings);

  /// True when the engine is ready to transcribe (model downloaded for
  /// on-device, API key present for cloud, etc.).
  Future<bool> isReady();

  /// Download/load models or validate credentials. Safe to call repeatedly.
  Future<void> prepare();

  /// Transcribe a 16 kHz mono WAV file at [wavPath] and return the text.
  Future<String> transcribe(String wavPath);
}

/// Engines that capture live from the microphone (the OS speech recognizers)
/// rather than transcribing a recorded file. The controller drives these via
/// [startListening] / [stopListening] instead of the file recorder + transcribe,
/// since platforms like Android can't feed a recorded file to SpeechRecognizer.
abstract class LiveTranscriptionEngine implements TranscriptionEngine {
  /// Begins live recognition. Returns false if it couldn't start.
  Future<bool> startListening();

  /// Stops recognition and returns the recognized text.
  Future<String> stopListening();
}

/// Placeholder engine used until the on-device Whisper backend lands in
/// Phase 2. It keeps the record → transcribe → display loop runnable
/// end-to-end so the app is demoable from Phase 1.
class StubEngine implements TranscriptionEngine {
  @override
  String get id => 'stub';

  @override
  String get label => 'Placeholder';

  @override
  void configure(AppSettings settings) {}

  @override
  Future<bool> isReady() async => true;

  @override
  Future<void> prepare() async {}

  @override
  Future<String> transcribe(String wavPath) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return 'Recording captured.\n\n'
        'On-device transcription (whisper.cpp) arrives in Phase 2 — this '
        'placeholder confirms the record → transcribe → display loop works.';
  }
}
