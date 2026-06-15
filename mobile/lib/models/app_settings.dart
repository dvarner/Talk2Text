import 'output_languages.dart';

/// User-tunable settings, mirroring the subset of the desktop app's
/// DEFAULT_CONFIG that makes sense on mobile (model size + language), plus the
/// mobile-only engine selection. The cloud API *key* is NOT stored here — it
/// lives in secure storage (see SecretStore).
class AppSettings {
  const AppSettings({
    this.engineId = 'whisper',
    this.modelSize = 'base',
    this.language = 'en',
    this.outputLanguage = 'native',
    this.customOutputLanguage = '',
    this.translationModel = 'haiku',
    this.cloudBaseUrl = 'https://api.openai.com/v1',
    this.cloudModel = 'whisper-1',
  });

  /// Active engine: 'whisper' (on-device, default) | 'native' | 'cloud'.
  final String engineId;

  /// On-device Whisper model size: 'tiny' | 'base' | 'small'.
  final String modelSize;

  /// ISO language code of the *spoken* audio (e.g. 'en'), or empty string for
  /// auto-detect. This is the source-language hint.
  final String language;

  /// Desired *output* text language. 'native' (default) keeps the transcript in
  /// the spoken language; 'en' translates to English offline (Whisper/Cloud);
  /// 'custom' uses [customOutputLanguage]; any other value is a preset Claude
  /// target (see OutputLanguages).
  final String outputLanguage;

  /// Free-text target language used when [outputLanguage] is 'custom'.
  final String customOutputLanguage;

  /// Which Claude model translates non-English targets:
  /// 'haiku' (default) | 'sonnet' | 'opus'.
  final String translationModel;

  /// True when the transcript should be translated to English instead of kept
  /// in the spoken language. Handled offline by the engine's translate task.
  bool get translateToEnglish => outputLanguage == 'en';

  /// True when the target needs the Claude translation step (any non-English,
  /// non-native target — for 'custom', only once a language has been entered).
  bool get translateViaClaude {
    if (outputLanguage.isEmpty ||
        outputLanguage == 'native' ||
        outputLanguage == 'en') {
      return false;
    }
    if (outputLanguage == 'custom') return customOutputLanguage.trim().isNotEmpty;
    return true;
  }

  /// Human-readable target language for the Claude translator.
  String get targetLanguageName => outputLanguage == 'custom'
      ? customOutputLanguage.trim()
      : OutputLanguages.nameFor(outputLanguage);

  /// Resolves [translationModel] to a concrete Claude model id.
  String get translationModelId {
    switch (translationModel) {
      case 'opus':
        return 'claude-opus-4-8';
      case 'sonnet':
        return 'claude-sonnet-4-6';
      case 'haiku':
      default:
        return 'claude-haiku-4-5';
    }
  }

  /// OpenAI-compatible base URL for the cloud engine (configurable so other
  /// providers can be slotted in).
  final String cloudBaseUrl;

  /// Cloud transcription model name (e.g. 'whisper-1').
  final String cloudModel;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    String? engineId,
    String? modelSize,
    String? language,
    String? outputLanguage,
    String? customOutputLanguage,
    String? translationModel,
    String? cloudBaseUrl,
    String? cloudModel,
  }) =>
      AppSettings(
        engineId: engineId ?? this.engineId,
        modelSize: modelSize ?? this.modelSize,
        language: language ?? this.language,
        outputLanguage: outputLanguage ?? this.outputLanguage,
        customOutputLanguage: customOutputLanguage ?? this.customOutputLanguage,
        translationModel: translationModel ?? this.translationModel,
        cloudBaseUrl: cloudBaseUrl ?? this.cloudBaseUrl,
        cloudModel: cloudModel ?? this.cloudModel,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.engineId == engineId &&
      other.modelSize == modelSize &&
      other.language == language &&
      other.outputLanguage == outputLanguage &&
      other.customOutputLanguage == customOutputLanguage &&
      other.translationModel == translationModel &&
      other.cloudBaseUrl == cloudBaseUrl &&
      other.cloudModel == cloudModel;

  @override
  int get hashCode => Object.hash(
        engineId,
        modelSize,
        language,
        outputLanguage,
        customOutputLanguage,
        translationModel,
        cloudBaseUrl,
        cloudModel,
      );
}
