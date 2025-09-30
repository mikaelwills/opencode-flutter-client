import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/obsidian_instance.dart';
import 'obsidian_connection_state.dart';

class ObsidianConnectionCubit extends Cubit<ObsidianConnectionState> {
  static const String _activeInstanceIdKey = 'active_obsidian_instance_id';
  static const String _activeApiKeyKey = 'active_obsidian_api_key';
  static const String _activeBaseUrlKey = 'active_obsidian_base_url';

  ObsidianConnectionCubit() : super(const ObsidianConnectionLoaded(
    activeInstance: null,
    baseUrl: '',
    apiKey: null,
  ));

  /// Load saved connection from SharedPreferences (optional - called on demand)
  Future<void> loadSavedConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString(_activeApiKeyKey);
      final baseUrl = prefs.getString(_activeBaseUrlKey) ?? '';

      final currentState = state;
      if (currentState is ObsidianConnectionLoaded) {
        emit(currentState.copyWith(
          baseUrl: baseUrl,
          apiKey: apiKey,
        ));
      }
    } catch (e) {
      emit(ObsidianConnectionError('Failed to load saved connection: ${e.toString()}'));
    }
  }

  /// Connect to an Obsidian instance
  Future<void> connectToInstance(ObsidianInstance instance) async {
    try {
      final currentState = state;
      if (currentState is! ObsidianConnectionLoaded) {
        emit(const ObsidianConnectionError('Cannot connect when connection is not loaded'));
        return;
      }

      final baseUrl = 'http://${instance.ip}:${instance.port}';

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeInstanceIdKey, instance.id);
      await prefs.setString(_activeApiKeyKey, instance.apiKey);
      await prefs.setString(_activeBaseUrlKey, baseUrl);

      emit(ObsidianConnectionLoaded(
        activeInstance: instance,
        baseUrl: baseUrl,
        apiKey: instance.apiKey,
      ));
    } catch (e) {
      emit(ObsidianConnectionError('Failed to connect to instance: ${e.toString()}'));
    }
  }

  /// Disconnect from current instance
  Future<void> disconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeInstanceIdKey);
      await prefs.remove(_activeApiKeyKey);
      await prefs.remove(_activeBaseUrlKey);

      emit(const ObsidianConnectionLoaded(
        activeInstance: null,
        baseUrl: '',
        apiKey: null,
      ));
    } catch (e) {
      emit(ObsidianConnectionError('Failed to disconnect: ${e.toString()}'));
    }
  }

  /// Update active instance details (when instance is modified)
  Future<void> updateActiveInstance(ObsidianInstance instance) async {
    try {
      final currentState = state;
      if (currentState is! ObsidianConnectionLoaded) return;

      // Only update if this is the currently active instance
      if (currentState.activeInstance?.id != instance.id) return;

      final baseUrl = 'http://${instance.ip}:${instance.port}';

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeApiKeyKey, instance.apiKey);
      await prefs.setString(_activeBaseUrlKey, baseUrl);

      emit(currentState.copyWith(
        activeInstance: instance,
        baseUrl: baseUrl,
        apiKey: instance.apiKey,
      ));
    } catch (e) {
      emit(ObsidianConnectionError('Failed to update active instance: ${e.toString()}'));
    }
  }

  /// Check if given instance is currently active
  bool isInstanceActive(ObsidianInstance instance) {
    final currentState = state;
    if (currentState is ObsidianConnectionLoaded) {
      return currentState.activeInstance?.id == instance.id;
    }
    return false;
  }

  /// Get current base URL for API calls
  String get baseUrl {
    final currentState = state;
    if (currentState is ObsidianConnectionLoaded) {
      return currentState.baseUrl;
    }
    return '';
  }

  /// Get current API key for authentication
  String? get apiKey {
    final currentState = state;
    if (currentState is ObsidianConnectionLoaded) {
      return currentState.apiKey;
    }
    return null;
  }

  /// Get current active instance
  ObsidianInstance? get activeInstance {
    final currentState = state;
    if (currentState is ObsidianConnectionLoaded) {
      return currentState.activeInstance;
    }
    return null;
  }

  /// Check if there's an active connection
  bool get hasActiveConnection {
    final currentState = state;
    if (currentState is ObsidianConnectionLoaded) {
      return currentState.hasActiveConnection;
    }
    return false;
  }
}