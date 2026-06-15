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
    this.translateToEnglish = false,
  });

  /// Which GGML model to use. Only tiny/base/small are practical on phones;
  /// the settings screen (Phase 4) restricts the choices accordingly.
  WhisperModel model;

  /// ISO language code, or empty string for auto-detect.
  String language;

  /// When true, run Whisper's `translate` task: any spoken language is
  /// transcribed straight to English text in a single pass. Whisper only
  /// translates *to* English, so this is a flag rather than a target language.
  bool translateToEnglish;

  final WhisperController _controller = WhisperController();

  @override
  String get id => 'whisper';

  @override
  String get label => 'On-device Whisper';

  @override
  void configure(AppSettings settings) {
    model = modelForSize(settings.modelSize);
    language = settings.language;
    translateToEnglish = settings.translateToEnglish;
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
    final lang = language.trim().isEmpty ? 'auto' : language.trim();

    if (!translateToEnglish) {
      // Default path: keep the transcript in the spoken language.
      final result = await _controller.transcribe(
        model: model,
        audioPath: wavPath,
        lang: lang,
      );
      if (result == null) {
        throw Exception('Whisper returned no result');
      }
      return result.transcription.text.trim();
    }

    // Translate task: Whisper outputs English from any source language in one
    // pass. WhisperController.transcribe hardcodes translate=false, so drive the
    // engine directly (same request params it uses, plus isTranslate).
    final modelPath = await _controller.getPath(model);
    final response = await Whisper(model: model).transcribe(
      transcribeRequest: TranscribeRequest(
        audio: wavPath,
        language: lang,
        isTranslate: true,
        isNoTimestamps: true,
        isRealtime: true,
      ),
      modelPath: modelPath,
    );
    return response.text.trim();
  }
}
