import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Stream controller for network status changes
  final StreamController<NetworkStatus> _networkController = 
      StreamController<NetworkStatus>.broadcast();
  
  Stream<NetworkStatus> get networkStatusStream => _networkController.stream;
  
  NetworkStatus? _currentStatus;
  NetworkStatus? get currentStatus => _currentStatus;

  Future<void> initialize() async {
    // Get initial connectivity status
    final List<ConnectivityResult> connectivityResults = 
        await _connectivity.checkConnectivity();
    _updateNetworkStatus(connectivityResults);
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen(_updateNetworkStatus);
  }

  void _updateNetworkStatus(List<ConnectivityResult> connectivityResults) {
    final NetworkStatus newStatus = _determineNetworkStatus(connectivityResults);

    // Only emit if status actually changed
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;

      _networkController.add(newStatus);
    }
  }

  NetworkStatus _determineNetworkStatus(List<ConnectivityResult> results) {
    // Handle multiple connection types (e.g., WiFi + Cellular)
    if (results.contains(ConnectivityResult.none)) {
      return NetworkStatus.disconnected;
    }
    
    // Prioritize connection types by reliability
    if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkStatus.ethernet;
    } else if (results.contains(ConnectivityResult.wifi)) {
      return NetworkStatus.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      return NetworkStatus.mobile;
    } else if (results.contains(ConnectivityResult.vpn)) {
      return NetworkStatus.vpn;
    } else {
      return NetworkStatus.other;
    }
  }

  /// Check if device has any network connectivity
  bool get isConnected => _currentStatus != NetworkStatus.disconnected;
  
  /// Check if on a metered connection (mobile data)
  bool get isMetered => _currentStatus == NetworkStatus.mobile;
  
  /// Check if on a reliable connection (WiFi/Ethernet)
  bool get isReliable => _currentStatus == NetworkStatus.wifi || 
                        _currentStatus == NetworkStatus.ethernet;

  void dispose() {
    _connectivitySubscription?.cancel();
    _networkController.close();
  }
}

enum NetworkStatus {
  disconnected('Disconnected'),
  wifi('WiFi'),
  mobile('Mobile'),
  ethernet('Ethernet'),
  vpn('VPN'),
  other('Connected');

  const NetworkStatus(this.displayName);
  final String displayName;
}

/// Extension to provide additional network status information
extension NetworkStatusExtension on NetworkStatus {
  /// Returns an icon representation for the network status
  String get icon {
    switch (this) {
      case NetworkStatus.disconnected:
        return '🛜❌';
      case NetworkStatus.wifi:
        return '🛜';
      case NetworkStatus.mobile:
        return '📱';
      case NetworkStatus.ethernet:
        return '🌐';
      case NetworkStatus.vpn:
        return '🔒';
      case NetworkStatus.other:
        return '🔗';
    }
  }
  
  /// Returns whether this status represents a connected state
  bool get isConnected => this != NetworkStatus.disconnected;
  
  /// Returns whether this is a metered connection
  bool get isMetered => this == NetworkStatus.mobile;
}