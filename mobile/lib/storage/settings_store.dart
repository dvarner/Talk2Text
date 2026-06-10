import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Settings persistence seam. Interface so the controller is testable without
/// the shared_preferences platform channel.
abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Persists settings with shared_preferences.
class PrefsSettingsStore implements SettingsStore {
  static const _kModel = 'model_size';
  static const _kLanguage = 'language';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      modelSize: prefs.getString(_kModel) ?? AppSettings.defaults.modelSize,
      language: prefs.getString(_kLanguage) ?? AppSettings.defaults.language,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModel, settings.modelSize);
    await prefs.setString(_kLanguage, settings.language);
  }
}
