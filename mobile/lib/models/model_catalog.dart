/// Download/size metadata for a Whisper model, shown in the settings picker.
class ModelInfo {
  const ModelInfo(this.size, this.disk, this.note);

  /// Key matching [AppSettings.modelSize] and the whisper_ggml model name.
  final String size;
  final String disk;
  final String note;
}

/// Mobile-appropriate subset of the desktop app's MODEL_HW table. medium/large
/// are intentionally omitted — they're impractical on phones (RAM + speed).
class ModelCatalog {
  static const List<ModelInfo> models = [
    ModelInfo('tiny', '~75 MB', 'Fastest, least accurate'),
    ModelInfo('base', '~142 MB', 'Good balance of speed & accuracy'),
    ModelInfo('small', '~466 MB', 'Better accuracy, slower on phone'),
  ];

  static List<String> get sizes => models.map((m) => m.size).toList();

  static ModelInfo infoFor(String size) =>
      models.firstWhere((m) => m.size == size, orElse: () => models[1]);
}
