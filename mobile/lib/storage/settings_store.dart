import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Settings persistence seam. Interface so the controller is testable without
/// the shared_preferences platform channel.
abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Persists settings with shared_preferences. (The cloud API key is stored
/// separately in secure storage, never here.)
class PrefsSettingsStore implements SettingsStore {
  static const _kEngine = 'engine_id';
  static const _kModel = 'model_size';
  static const _kLanguage = 'language';
  static const _kCloudUrl = 'cloud_base_url';
  static const _kCloudModel = 'cloud_model';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    const d = AppSettings.defaults;
    return AppSettings(
      engineId: prefs.getString(_kEngine) ?? d.engineId,
      modelSize: prefs.getString(_kModel) ?? d.modelSize,
      language: prefs.getString(_kLanguage) ?? d.language,
      cloudBaseUrl: prefs.getString(_kCloudUrl) ?? d.cloudBaseUrl,
      cloudModel: prefs.getString(_kCloudModel) ?? d.cloudModel,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEngine, settings.engineId);
    await prefs.setString(_kModel, settings.modelSize);
    await prefs.setString(_kLanguage, settings.language);
    await prefs.setString(_kCloudUrl, settings.cloudBaseUrl);
    await prefs.setString(_kCloudModel, settings.cloudModel);
  }
}
