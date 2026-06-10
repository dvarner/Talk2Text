/// User-tunable settings, mirroring the subset of the desktop app's
/// DEFAULT_CONFIG that makes sense on mobile (model size + language), plus the
/// mobile-only engine selection. The cloud API *key* is NOT stored here — it
/// lives in secure storage (see SecretStore).
class AppSettings {
  const AppSettings({
    this.engineId = 'whisper',
    this.modelSize = 'base',
    this.language = 'en',
    this.cloudBaseUrl = 'https://api.openai.com/v1',
    this.cloudModel = 'whisper-1',
  });

  /// Active engine: 'whisper' (on-device, default) | 'native' | 'cloud'.
  final String engineId;

  /// On-device Whisper model size: 'tiny' | 'base' | 'small'.
  final String modelSize;

  /// ISO language code (e.g. 'en'), or empty string for auto-detect.
  final String language;

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
    String? cloudBaseUrl,
    String? cloudModel,
  }) =>
      AppSettings(
        engineId: engineId ?? this.engineId,
        modelSize: modelSize ?? this.modelSize,
        language: language ?? this.language,
        cloudBaseUrl: cloudBaseUrl ?? this.cloudBaseUrl,
        cloudModel: cloudModel ?? this.cloudModel,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.engineId == engineId &&
      other.modelSize == modelSize &&
      other.language == language &&
      other.cloudBaseUrl == cloudBaseUrl &&
      other.cloudModel == cloudModel;

  @override
  int get hashCode =>
      Object.hash(engineId, modelSize, language, cloudBaseUrl, cloudModel);
}
