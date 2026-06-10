import 'dart:io';

import 'package:whisper_ggml/whisper_ggml.dart';

import '../models/app_settings.dart';
import 'transcription_engine.dart';

/// On-device Whisper backend (whisper.cpp via the `whisper_ggml` plugin).
///
/// Runs fully offline once the GGML model is downloaded, preserving the
/// desktop app's local/private character. The model file is fetched on first
/// use into the app's support directory and reused thereafter.
class WhisperEngine implements TranscriptionEngine {
  WhisperEngine({
    this.model = WhisperModel.base,
    this.language = 'en',
  });

  /// Which GGML model to use. Only tiny/base/small are practical on phones;
  /// the settings screen (Phase 4) restricts the choices accordingly.
  WhisperModel model;

  /// ISO language code, or empty string for auto-detect.
  String language;

  final WhisperController _controller = WhisperController();

  @override
  String get id => 'whisper';

  @override
  String get label => 'On-device Whisper';

  @override
  void configure(AppSettings settings) {
    model = modelForSize(settings.modelSize);
    language = settings.language;
  }

  /// Maps a settings size key to the whisper_ggml multilingual model.
  static WhisperModel modelForSize(String size) {
    switch (size) {
      case 'tiny':
        return WhisperModel.tiny;
      case 'small':
        return WhisperModel.small;
      case 'base':
      default:
        return WhisperModel.base;
    }
  }

  @override
  Future<bool> isReady() async {
    final path = await _controller.getPath(model);
    return File(path).existsSync();
  }

  @override
  Future<void> prepare() async {
    // No-op if the model file is already present.
    await _controller.downloadModel(model);
  }

  @override
  Future<String> transcribe(String wavPath) async {
    final result = await _controller.transcribe(
      model: model,
      audioPath: wavPath,
      lang: language.trim().isEmpty ? 'auto' : language.trim(),
    );
    if (result == null) {
      throw Exception('Whisper returned no result');
    }
    return result.transcription.text.trim();
  }
}
