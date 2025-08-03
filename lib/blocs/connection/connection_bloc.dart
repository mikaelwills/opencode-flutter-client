import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/opencode_client.dart';
import '../session/session_bloc.dart';
import '../session/session_event.dart' as session_events;

import 'connection_event.dart';
import 'connection_state.dart';

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  final OpenCodeClient openCodeClient;
  final SessionBloc sessionBloc;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempt = 0;
  StreamSubscription? _sessionSubscription;

  ConnectionBloc({
    required this.openCodeClient,
    required this.sessionBloc,
  }) : super(ConnectionInitial()) {
    on<CheckConnection>(_onCheckConnection);
    on<ConnectionEstablished>(_onConnectionEstablished);
    on<ConnectionLost>(_onConnectionLost);
    on<StartReconnection>(_onStartReconnection);
    on<ResetConnection>(_onResetConnection);
    

    // Start initial connection check
    add(CheckConnection());

    // Set up periodic ping when connected
    _startPeriodicPing();
  }

  void _startPeriodicPing() {
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (state is ConnectedWithSession) {
        add(CheckConnection());
      }
    });
  }

  Future<void> _onCheckConnection(
    CheckConnection event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      final isReachable = await openCodeClient.ping();
      if (isReachable) {
        if (state is! ConnectedWithSession) {
          print('🔍 [Connection] Ping successful - connection established');
          add(ConnectionEstablished());
        } else {
          print('🔍 [Connection] Ping successful - connection active');
        }
      } else {
        add(const ConnectionLost(reason: 'Server unreachable'));
      }
    } catch (e) {
      print('❌ [Connection] Ping failed: $e');
      add(ConnectionLost(reason: e.toString()));
    }
  }

  Future<void> _onConnectionEstablished(
    ConnectionEstablished event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      // Fetch config to get provider and model information
      print('🔍 [Connection] Fetching server config...');
      await openCodeClient.getProviders();
      print(
          '✅ [Connection] Config fetched successfully - Provider: ${openCodeClient.providerID}, Model: ${openCodeClient.modelID}');

      _reconnectAttempt = 0;
      _cancelReconnectTimer();

      // Automatically create a session when connection is established
      print(
          '🔍 [Connection] Connection established - creating session automatically');
      final session = await openCodeClient.createSession();
      sessionBloc.add(session_events.SessionUpdated(session));
      emit(ConnectedWithSession(sessionId: session.id));
    } catch (e) {
      print('❌ [Connection] Failed to fetch config or create session: $e');
      add(ConnectionLost(reason: e.toString()));
    }
  }

  void _onConnectionLost(
    ConnectionLost event,
    Emitter<ConnectionState> emit,
  ) {
    _sessionSubscription?.cancel();
    emit(Disconnected(reason: event.reason));
    // add(const StartReconnection());
  }

  void _onStartReconnection(
    StartReconnection event,
    Emitter<ConnectionState> emit,
  ) {
    print('🔍 [ConnectionBloc] _onStartReconnection called');
    print('🔍 [ConnectionBloc] Previous state: ${state.runtimeType}');
    print('🔍 [ConnectionBloc] Attempt number: ${event.attempt}');

    _reconnectAttempt = event.attempt;
    emit(Reconnecting(attempt: _reconnectAttempt));
    print(
        '🔍 [ConnectionBloc] Emitted Reconnecting state (attempt $_reconnectAttempt)');

    // Schedule next connection check with exponential backoff
    final delaySeconds = math.pow(2, _reconnectAttempt).toInt().clamp(1, 30);
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
    emit(ConnectionInitial());
    add(CheckConnection());
  }

  

  @override
  Future<void> close() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sessionSubscription?.cancel();
    return super.close();
  }
}

