import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Names of the secrets kept in secure storage.
class SecretKeys {
  /// OpenAI-compatible cloud *transcription* key (the Cloud engine).
  static const cloudApiKey = 'cloud_api_key';

  /// Anthropic key for the Claude *translation* step (non-English targets).
  static const anthropicApiKey = 'anthropic_api_key';
}

/// Secure storage seam for named secrets. Kept separate from [SettingsStore] so
/// keys never land in plaintext shared_preferences, and as an interface so it
/// can be faked in tests.
abstract class SecretStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
  Future<bool> has(String name);
}

/// Backed by flutter_secure_storage (Keychain on iOS, Keystore on Android).
class SecureSecretStore implements SecretStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);

  @override
  Future<bool> has(String name) async {
    final v = await _storage.read(key: name);
    return v != null && v.isNotEmpty;
  }
}
