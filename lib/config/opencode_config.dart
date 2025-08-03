import 'package:shared_preferences/shared_preferences.dart';
import '../blocs/config/config_cubit.dart';

/// OpenCode API configuration
/// 
/// DEPRECATED: This class is kept for backward compatibility.
/// New code should use ConfigCubit directly.
class OpenCodeConfig {
  static ConfigCubit? _configCubit;
  
  // Fallback values for when cubit is not available
  static String _fallbackBaseUrl = 'http://192.168.1.161:4096';
  
  /// Set the ConfigCubit instance for this class to use
  static void setConfigCubit(ConfigCubit cubit) {
    _configCubit = cubit;
  }
  
  /// Get current base URL
  static String get baseUrl {
    return _configCubit?.baseUrl ?? _fallbackBaseUrl;
  }
  
  /// Update the base URL dynamically
  /// DEPRECATED: Use ConfigCubit.updateServer() instead
  static void updateBaseUrl(String newBaseUrl) {
    _fallbackBaseUrl = newBaseUrl;
    
    // Extract IP and port from URL if cubit is available
    if (_configCubit != null) {
      final uri = Uri.tryParse(newBaseUrl);
      if (uri != null && uri.host.isNotEmpty) {
        _configCubit!.updateServer(uri.host, port: uri.port);
      }
    }
  }
  
  /// Initialize base URL from SharedPreferences
  /// DEPRECATED: Use ConfigCubit.initialize() instead
  static Future<void> initializeBaseUrl() async {
    if (_configCubit != null) {
      await _configCubit!.initialize();
    } else {
      // Fallback behavior
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedIP = prefs.getString('server_ip') ?? '192.168.1.161';
        _fallbackBaseUrl = 'http://$savedIP:4096';
      } catch (e) {
        _fallbackBaseUrl = 'http://192.168.1.161:4096'; // fallback
      }
    }
  }
  
  // API endpoints
  static const String sseEndpoint = '/event';
  static const String sessionEndpoint = '/session';
  static const String configEndpoint = '/config';
  
  // Dynamic endpoints (require parameters)
  static String messageEndpoint(String sessionId) => '/session/$sessionId/message';
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