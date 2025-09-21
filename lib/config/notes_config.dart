import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotesConfig {
  static const String _defaultBaseUrl = 'http://192.168.1.161:27123';
  static const String _baseUrlKey = 'notes_base_url';
  static const String _apiKeyKey = 'notes_api_key';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Get the base URL for the Obsidian API
  static Future<String> get baseUrl async {
    try {
      final storedUrl = await _secureStorage.read(key: _baseUrlKey);
      final result = storedUrl ?? _defaultBaseUrl;
      return result;
    } catch (e) {
      return _defaultBaseUrl;
    }
  }

  /// Get the API key for the Obsidian API
  static Future<String?> get apiKey async {
    try {
      final key = await _secureStorage.read(key: _apiKeyKey);
      return key;
    } catch (e) {
      return null;
    }
  }

  /// Set the base URL for the Obsidian API
  static Future<void> setBaseUrl(String url) async {
    try {
      await _secureStorage.write(key: _baseUrlKey, value: url);
    } catch (e) {
      throw Exception('Failed to store base URL: $e');
    }
  }

  /// Set the API key for the Obsidian API
  static Future<void> setApiKey(String key) async {
    try {
      await _secureStorage.write(key: _apiKeyKey, value: key);
    } catch (e) {
      throw Exception('Failed to store API key: $e');
    }
  }

  /// Check if the configuration is complete
  static Future<bool> get isConfigured async {
    final key = await apiKey;
    final configured = key != null && key.isNotEmpty;
    return configured;
  }

  /// Clear all stored configuration
  static Future<void> clearConfiguration() async {
    try {
      await _secureStorage.delete(key: _baseUrlKey);
      await _secureStorage.delete(key: _apiKeyKey);
    } catch (e) {
      throw Exception('Failed to clear configuration: $e');
    }
  }

  /// Initialize with default API key (for backward compatibility during development)
  static Future<void> initializeWithDefaults() async {
    if (!(await isConfigured)) {
      await setApiKey('d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b');
    }
  }
}