import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage seam for secrets (the cloud API key). Kept separate from
/// [SettingsStore] so the key never lands in plaintext shared_preferences, and
/// as an interface so it can be faked in tests.
abstract class SecretStore {
  Future<String?> getApiKey();
  Future<void> setApiKey(String key);
  Future<void> clearApiKey();
  Future<bool> hasApiKey();
}

/// Backed by flutter_secure_storage (Keychain on iOS, Keystore on Android).
class SecureSecretStore implements SecretStore {
  static const _kApiKey = 'cloud_api_key';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> getApiKey() => _storage.read(key: _kApiKey);

  @override
  Future<void> setApiKey(String key) =>
      _storage.write(key: _kApiKey, value: key);

  @override
  Future<void> clearApiKey() => _storage.delete(key: _kApiKey);

  @override
  Future<bool> hasApiKey() async {
    final v = await _storage.read(key: _kApiKey);
    return v != null && v.isNotEmpty;
  }
}
