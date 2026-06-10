import 'package:speech_to_text/speech_to_text.dart';

import '../models/app_settings.dart';
import 'transcription_engine.dart';

/// OS-native speech recognition (Apple Speech on iOS, SpeechRecognizer on
/// Android) via the `speech_to_text` plugin. Free and built into the OS, with
/// no model download — but it captures live, so it implements
/// [LiveTranscriptionEngine] rather than the file-based transcribe path.
class NativeSpeechEngine implements LiveTranscriptionEngine {
  NativeSpeechEngine({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  String _language = AppSettings.defaults.language;
  String _recognized = '';
  bool _initialized = false;

  @override
  String get id => 'native';

  @override
  String get label => 'Device speech';

  @override
  void configure(AppSettings settings) {
    _language = settings.language.trim();
  }

  @override
  Future<bool> isReady() async => _initialized || await _init();

  @override
  Future<void> prepare() async {
    await _init();
  }

  Future<bool> _init() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize();
    return _initialized;
  }

  @override
  Future<bool> startListening() async {
    if (!await _init()) return false;
    _recognized = '';
    await _speech.listen(
      onResult: (result) => _recognized = result.recognizedWords,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: _language.isEmpty ? null : _language,
      ),
    );
    return true;
  }

  @override
  Future<String> stopListening() async {
    await _speech.stop();
    return _recognized.trim();
  }

  @override
  Future<String> transcribe(String wavPath) =>
      throw UnsupportedError('NativeSpeechEngine recognizes live, not files.');
}
