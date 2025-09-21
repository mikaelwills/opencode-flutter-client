import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/opencode_client.dart';
import '../../services/network_service.dart';
import '../session/session_bloc.dart';
import '../session/session_event.dart' as session_events;
import '../session/session_state.dart' as session_states;

import 'connection_event.dart';
import 'connection_state.dart';

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  final OpenCodeClient openCodeClient;
  final SessionBloc sessionBloc;
  final NetworkService _networkService = NetworkService();
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempt = 0;
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _networkSubscription;
  DateTime _lastActivity = DateTime.now();
  Emitter<ConnectionState>? _currentEmitter;
  bool _isFastReconnectMode = false;
  int _fastReconnectAttempt = 0;
  static const Duration _activePingInterval = Duration(seconds: 30);
  static const Duration _idlePingInterval = Duration(minutes: 2);
  static const List<Duration> _fastReconnectDelays = [
    Duration(milliseconds: 500),  // 0.5s
    Duration(seconds: 1),         // 1s  
    Duration(seconds: 2),         // 2s
  ];

  ConnectionBloc({
    required this.openCodeClient,
    required this.sessionBloc,
  }) : super(ConnectionInitial()) {
    on<CheckConnection>(_onCheckConnection);
    on<ConnectionEstablished>(_onConnectionEstablished);
    on<ConnectionLost>(_onConnectionLost);
    on<StartReconnection>(_onStartReconnection);
    on<ResetConnection>(_onResetConnection);
    on<IntentionalDisconnect>(_onIntentionalDisconnect);
    on<NetworkSignalLost>(_onNetworkSignalLost);
    on<NetworkRestored>(_onNetworkRestored);
    

    // Initialize network monitoring
    _initializeNetworkMonitoring();

    // Start initial connection check
    add(CheckConnection());

    // Set up periodic ping when connected
    _startPeriodicPing();
  }

  Future<void> _initializeNetworkMonitoring() async {
    // Initialize the network service
    await _networkService.initialize();
    
    // Listen for network status changes
    _networkSubscription = _networkService.networkStatusStream.listen((networkStatus) {
      if (!networkStatus.isConnected) {
        // Immediate signal loss detection
        add(NetworkSignalLost(reason: 'Network signal lost (${networkStatus.displayName})'));
      } else {
        // Network restored - trigger fast reconnection if we're currently disconnected
        if (state is Disconnected || state is Reconnecting) {
          add(NetworkRestored(networkType: networkStatus.displayName));
        }
      }
    });
  }

  void _startPeriodicPing() {
    _scheduleNextPing();
  }
  
  void _scheduleNextPing() {
    _pingTimer?.cancel();
    
    if (state is! Connected) {
      return; // Don't ping if not connected
    }
    
    // Use adaptive ping interval based on activity
    final timeSinceActivity = DateTime.now().difference(_lastActivity);
    final isIdle = timeSinceActivity > const Duration(minutes: 5);
    final interval = isIdle ? _idlePingInterval : _activePingInterval;
    
    _pingTimer = Timer(interval, () {
      if (state is Connected) {
        add(CheckConnection());
        _scheduleNextPing(); // Schedule next ping
      }
    });
  }
  
  void _markActivity() {
    _lastActivity = DateTime.now();
  }

  Future<void> _onCheckConnection(
    CheckConnection event,
    Emitter<ConnectionState> emit,
  ) async {
    _currentEmitter = emit;
    _markActivity(); // Mark activity for adaptive ping
    
    try {
      // Use shorter timeout for fast reconnect mode
      final timeout = _isFastReconnectMode 
          ? const Duration(seconds: 3)
          : const Duration(seconds: 10);
      
      final isReachable = await openCodeClient.ping()
          .timeout(timeout);
      
      if (isReachable) {
        if (state is! Connected) {
          await _handleConnectionEstablished(emit);
        }
      } else {
        _handleConnectionLost('Server unreachable', emit);
      }
    } on TimeoutException {
      final timeoutMsg = _isFastReconnectMode
          ? 'Fast reconnect timeout'
          : 'Connection timeout';
      _handleConnectionLost(timeoutMsg, emit);
    } catch (e) {
      _handleConnectionLost(e.toString(), emit);
    }
  }

  Future<void> _onConnectionEstablished(
    ConnectionEstablished event,
    Emitter<ConnectionState> emit,
  ) async {
    await _handleConnectionEstablished(emit);
  }

  Future<void> _handleConnectionEstablished(Emitter<ConnectionState> emit) async {
    _currentEmitter = emit;
    try {
      // Fetch config to get provider and model information with timeout
      await openCodeClient.getProviders()
          .timeout(const Duration(seconds: 15));

      _reconnectAttempt = 0;
      _isFastReconnectMode = false; // Disable fast reconnect mode on successful connection
      _fastReconnectAttempt = 0;
      _cancelReconnectTimer();

      // Connection is established - handle session appropriately
      if (sessionBloc.currentSession != null) {
        // Reconnection scenario - validate existing session
        sessionBloc.add(session_events.ValidateSession(sessionBloc.currentSession!.id));
      } else {
        // Initial connection - load stored session (validates or creates new)
        sessionBloc.add(session_events.LoadStoredSession());
      }
      
      // Listen for session creation to get the session ID with timeout
      _sessionSubscription?.cancel();
      final sessionCompleter = Completer<void>();
      
      _sessionSubscription = sessionBloc.stream.listen((sessionState) {
        if (sessionState is session_states.SessionLoaded) {
          emit(const Connected());
          _scheduleNextPing(); // Start adaptive pinging once we have a session
          _sessionSubscription?.cancel();
          if (!sessionCompleter.isCompleted) {
            sessionCompleter.complete();
          }
        } else if (sessionState is session_states.SessionError) {
          _sessionSubscription?.cancel();
          if (!sessionCompleter.isCompleted) {
            sessionCompleter.completeError(sessionState.message);
          }
        }
      });
      
      // Wait for session creation with timeout (no intermediate state)
      await sessionCompleter.future
          .timeout(const Duration(seconds: 20));
          
    } on TimeoutException {
      _handleConnectionLost('Connection establishment timeout', emit);
    } catch (e) {
      _handleConnectionLost(e.toString(), emit);
    }
  }

  void _onConnectionLost(
    ConnectionLost event,
    Emitter<ConnectionState> emit,
  ) {
    _handleConnectionLost(event.reason, emit);
  }

  void _handleConnectionLost(String? reason, Emitter<ConnectionState>? emit) {
    final emitter = emit ?? _currentEmitter;
    if (emitter == null) return;
    _sessionSubscription?.cancel();
    _pingTimer?.cancel();
    emitter(Disconnected(reason: reason, isIntentional: false));
    
    // Choose reconnection strategy based on mode
    if (_isFastReconnectMode && _fastReconnectAttempt < _fastReconnectDelays.length) {
      // Fast reconnect mode - use rapid retry pattern
      _startFastReconnection();
    } else {
      // Normal reconnection with exponential backoff
      if (_isFastReconnectMode) {
        // Fast reconnect attempts exhausted, switch to normal mode
        _isFastReconnectMode = false;
        _fastReconnectAttempt = 0;
        _reconnectAttempt = 1; // Start at attempt 1 for normal reconnection
      } else {
        _reconnectAttempt++;
      }
      add(StartReconnection(attempt: _reconnectAttempt));
    }
  }

  void _startFastReconnection() {
    final delay = _fastReconnectDelays[_fastReconnectAttempt];
    _fastReconnectAttempt++;

    _reconnectTimer = Timer(delay, () {
      add(CheckConnection());
    });
  }

  void _onStartReconnection(
    StartReconnection event,
    Emitter<ConnectionState> emit,
  ) {
  
    _reconnectAttempt = event.attempt;
    emit(Reconnecting(attempt: _reconnectAttempt));

    // Schedule next connection check with improved exponential backoff
    final delaySeconds = math.pow(2, _reconnectAttempt).toInt().clamp(1, 120); // Increased max to 2 minutes
    final delay = Duration(seconds: delaySeconds);

    _reconnectTimer = Timer(delay, () {
      add(CheckConnection());
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _onResetConnection(
    ResetConnection event,
    Emitter<ConnectionState> emit,
  ) {
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _sessionSubscription?.cancel();
    _pingTimer?.cancel();
    emit(ConnectionInitial());
    add(CheckConnection());
  }

  void _onIntentionalDisconnect(
    IntentionalDisconnect event,
    Emitter<ConnectionState> emit,
  ) {
    // Clean up all timers and subscriptions
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _sessionSubscription?.cancel();

    // Reset reconnect attempt counter
    _reconnectAttempt = 0;

    // Emit disconnected state without triggering reconnection
    emit(Disconnected(
      reason: event.reason ?? 'User disconnected',
      isIntentional: true,
    ));
  }

  void _onNetworkSignalLost(
    NetworkSignalLost event,
    Emitter<ConnectionState> emit,
  ) {
    // Disable fast reconnect mode when signal is lost
    _isFastReconnectMode = false;
    _fastReconnectAttempt = 0;

    // Use the existing connection lost handler but with network-specific reason
    _handleConnectionLost(event.reason ?? 'Network signal lost', emit);
  }

  void _onNetworkRestored(
    NetworkRestored event,
    Emitter<ConnectionState> emit,
  ) {
    // Enable fast reconnect mode for immediate network restoration
    _isFastReconnectMode = true;
    _fastReconnectAttempt = 0;
    _reconnectAttempt = 0; // Reset normal reconnect attempts

    // Cancel any existing reconnect timer
    _cancelReconnectTimer();

    // Start immediate fast reconnection
    add(CheckConnection());
  }

  

  @override
  Future<void> close() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sessionSubscription?.cancel();
    _networkSubscription?.cancel();
    _networkService.dispose();
    return super.close();
  }
}

