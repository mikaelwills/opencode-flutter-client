import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/opencode_client.dart';
import '../session/session_bloc.dart';
import '../session/session_event.dart' as session_events;
import '../session/session_state.dart' as session_states;

import 'connection_event.dart';
import 'connection_state.dart';

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  final OpenCodeClient openCodeClient;
  final SessionBloc sessionBloc;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempt = 0;
  StreamSubscription? _sessionSubscription;
  DateTime _lastActivity = DateTime.now();
  static const Duration _activePingInterval = Duration(seconds: 30);
  static const Duration _idlePingInterval = Duration(minutes: 2);

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
    

    // Start initial connection check
    add(CheckConnection());

    // Set up periodic ping when connected
    _startPeriodicPing();
  }

  void _startPeriodicPing() {
    _scheduleNextPing();
  }
  
  void _scheduleNextPing() {
    _pingTimer?.cancel();
    
    if (state is! ConnectedWithSession) {
      return; // Don't ping if not connected
    }
    
    // Use adaptive ping interval based on activity
    final timeSinceActivity = DateTime.now().difference(_lastActivity);
    final isIdle = timeSinceActivity > const Duration(minutes: 5);
    final interval = isIdle ? _idlePingInterval : _activePingInterval;
    
    _pingTimer = Timer(interval, () {
      if (state is ConnectedWithSession) {
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
    _markActivity(); // Mark activity for adaptive ping
    
    try {
      // Add timeout to ping operation
      final isReachable = await openCodeClient.ping()
          .timeout(const Duration(seconds: 10));
      
      if (isReachable) {
        if (state is! ConnectedWithSession) {
          print('🔍 [Connection] Ping successful - connection established');
          await _handleConnectionEstablished(emit);
        } else {
          print('🔍 [Connection] Ping successful - connection active');
        }
      } else {
        _handleConnectionLost('Server unreachable', emit);
      }
    } on TimeoutException {
      print('❌ [Connection] Ping timeout');
      _handleConnectionLost('Connection timeout', emit);
    } catch (e) {
      print('❌ [Connection] Ping failed: $e');
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
    try {
      // Fetch config to get provider and model information with timeout
      print('🔍 [Connection] Fetching server config...');
      await openCodeClient.getProviders()
          .timeout(const Duration(seconds: 15));
      print(
          '✅ [Connection] Config fetched successfully - Provider: ${openCodeClient.providerID}, Model: ${openCodeClient.modelID}');

      _reconnectAttempt = 0;
      _cancelReconnectTimer();

      // Connection is established - let SessionBloc handle session creation
      print('🔍 [Connection] Connection established');
      sessionBloc.add(session_events.CreateSession());
      
      // Listen for session creation to get the session ID with timeout
      _sessionSubscription?.cancel();
      final sessionCompleter = Completer<void>();
      
      _sessionSubscription = sessionBloc.stream.listen((sessionState) {
        if (sessionState is session_states.SessionLoaded) {
          emit(ConnectedWithSession(sessionId: sessionState.session.id));
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
      print('❌ [Connection] Connection establishment timeout');
      _handleConnectionLost('Connection establishment timeout', emit);
    } catch (e) {
      print('❌ [Connection] Failed to establish connection: $e');
      _handleConnectionLost(e.toString(), emit);
    }
  }

  void _onConnectionLost(
    ConnectionLost event,
    Emitter<ConnectionState> emit,
  ) {
    _handleConnectionLost(event.reason, emit);
  }

  void _handleConnectionLost(String? reason, Emitter<ConnectionState> emit) {
    _sessionSubscription?.cancel();
    _pingTimer?.cancel();
    emit(Disconnected(reason: reason, isIntentional: false));
    
    // Start reconnection with improved strategy
    _reconnectAttempt++;
    add(StartReconnection(attempt: _reconnectAttempt));
  }

  void _onStartReconnection(
    StartReconnection event,
    Emitter<ConnectionState> emit,
  ) {
  
    _reconnectAttempt = event.attempt;
    emit(Reconnecting(attempt: _reconnectAttempt));
    print(
        '🔍 [ConnectionBloc] Emitted Reconnecting state (attempt $_reconnectAttempt)');

    // Schedule next connection check with improved exponential backoff
    final delaySeconds = math.pow(2, _reconnectAttempt).toInt().clamp(1, 120); // Increased max to 2 minutes
    final delay = Duration(seconds: delaySeconds);

    print(
        '🔍 [ConnectionBloc] Scheduling next connection check in ${delay.inSeconds} seconds');

    _reconnectTimer = Timer(delay, () {
      print('🔍 [ConnectionBloc] Reconnect timer fired, checking connection');
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
    print('🔍 [Connection] Intentional disconnect: ${event.reason ?? 'User initiated'}');
    
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

  

  @override
  Future<void> close() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sessionSubscription?.cancel();
    return super.close();
  }
}

