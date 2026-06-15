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
  /// the spoken language; 'en' translates to English (Whisper/Cloud only — the
  /// translate task targets English, so it's the one non-native option for now).
  final String outputLanguage;

  /// True when the transcript should be translated to English instead of kept
  /// in the spoken language. Handled offline by the engine's translate task.
  bool get translateToEnglish => outputLanguage == 'en';

  /// True when the target is a non-English language that needs the Claude
  /// translation step (the engines can only translate *to* English).
  bool get translateViaClaude =>
      outputLanguage.isNotEmpty &&
      outputLanguage != 'native' &&
      outputLanguage != 'en';


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
    String? cloudBaseUrl,
    String? cloudModel,
  }) =>
      AppSettings(
        engineId: engineId ?? this.engineId,
        modelSize: modelSize ?? this.modelSize,
        language: language ?? this.language,
        outputLanguage: outputLanguage ?? this.outputLanguage,
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
      other.cloudBaseUrl == cloudBaseUrl &&
      other.cloudModel == cloudModel;

  @override
  int get hashCode => Object.hash(
        engineId,
        modelSize,
        language,
        outputLanguage,
        cloudBaseUrl,
        cloudModel,
      );
}
