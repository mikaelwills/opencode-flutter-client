import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_state.dart';

class ConfigCubit extends Cubit<ConfigState> {
  static const String _defaultServerIp = '0.0.0.0';
  static const int _defaultPort = 4096;

  ConfigCubit() : super(ConfigLoading());

  /// Initialize configuration from SharedPreferences
  Future<void> initialize() async {
    try {
      emit(ConfigLoading());

      final prefs = await SharedPreferences.getInstance();
      final savedIP = prefs.getString('server_ip') ?? _defaultServerIp;
      final port = prefs.getInt('server_port') ?? _defaultPort;
      final baseUrl = 'http://$savedIP:$port';

      emit(ConfigLoaded(
        baseUrl: baseUrl,
        serverIp: savedIP,
        port: port,
      ));
    } catch (e) {
      emit(ConfigError('Failed to initialize config: ${e.toString()}'));
    }
  }

  /// Update the server IP and port
  Future<void> updateServer(String serverIp, {int? port}) async {
    try {
      final currentState = state;
      if (currentState is! ConfigLoaded) {
        emit(const ConfigError('Cannot update server when config is not loaded'));
        return;
      }

      final newPort = port ?? currentState.port;
      final newBaseUrl = 'http://$serverIp:$newPort';

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', serverIp);
      await prefs.setInt('server_port', newPort);

      emit(ConfigLoaded(
        baseUrl: newBaseUrl,
        serverIp: serverIp,
        port: newPort,
      ));
    } catch (e) {
      emit(ConfigError('Failed to update server: ${e.toString()}'));
    }
  }

  /// Reset to default configuration
  Future<void> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('server_ip');
      await prefs.remove('server_port');

      const baseUrl = 'http://$_defaultServerIp:$_defaultPort';

      emit(const ConfigLoaded(
        baseUrl: baseUrl,
        serverIp: _defaultServerIp,
        port: _defaultPort,
      ));
    } catch (e) {
      emit(ConfigError('Failed to reset config: ${e.toString()}'));
    }
  }

  /// Get current base URL (for backward compatibility)
  String get baseUrl {
    final currentState = state;
    if (currentState is ConfigLoaded) {
      return currentState.baseUrl;
    }
    return 'http://$_defaultServerIp:$_defaultPort';
  }

  /// Get current server IP
  String get serverIp {
    final currentState = state;
    if (currentState is ConfigLoaded) {
      return currentState.serverIp;
    }
    return _defaultServerIp;
  }

  /// Get current port
  int get port {
    final currentState = state;
    if (currentState is ConfigLoaded) {
      return currentState.port;
    }
    return _defaultPort;
  }

  // Static endpoints (unchanged)
  static const String sseEndpoint = '/event';
  static const String sessionEndpoint = '/session';
  static const String configEndpoint = '/config';

  // Dynamic endpoints (require parameters)
  static String messageEndpoint(String sessionId) =>
      '/session/$sessionId/message';
  static String abortEndpoint(String sessionId) => '/session/$sessionId/abort';
  static String sessionByIdEndpoint(String sessionId) => '/session/$sessionId';

  // Connection settings
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const int maxReconnectAttempts = 5;

  // SSE settings
  static const Duration sseTimeout = Duration(seconds: 120);
  static const Map<String, String> sseHeaders = {
    'Accept': 'text/event-stream',
    'Cache-Control': 'no-cache',
  };

  // HTTP headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

