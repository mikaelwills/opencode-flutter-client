import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/opencode_client.dart';
import '../../models/session.dart';

import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final OpenCodeClient openCodeClient;
  Session? _currentSession;
  bool _isCreatingSession = false; // Guard to prevent concurrent session creation
  
  static const String _currentSessionKey = 'current_session_id';

  SessionBloc({required this.openCodeClient}) : super(SessionInitial()) {
    on<CreateSession>(_onCreateSession);
    on<SendMessage>(_onSendMessage);
    on<CancelSessionOperation>(_onCancelSessionOperation);
    on<SessionUpdated>(_onSessionUpdated);
    on<LoadStoredSession>(_onLoadStoredSession);
    on<ValidateSession>(_onValidateSession);
    on<SetCurrentSession>(_onSetCurrentSession);
  }

  Session? get currentSession => _currentSession;

  Future<void> _onCreateSession(
    CreateSession event,
    Emitter<SessionState> emit,
  ) async {
    // Prevent concurrent session creation
    if (_isCreatingSession) {
      print('🔍 [SessionBloc] Session creation already in progress, skipping duplicate request');
      return;
    }

    _isCreatingSession = true;
    emit(SessionLoading());

    try {
      final session = await openCodeClient.createSession();
      print('✅ Session created: ${session.id}');

      _currentSession = session;
      await _persistCurrentSessionId(session.id);
      emit(SessionLoaded(session: session));
    } catch (e, stackTrace) {
      print('❌ [SessionBloc] Failed to create session: $e');
      print('❌ [SessionBloc] Stack trace: $stackTrace');
      emit(SessionError('Failed to create session: ${e.toString()}'));
    } finally {
      _isCreatingSession = false;
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<SessionState> emit,
  ) async {
    // Validate inputs
    if (event.sessionId.trim().isEmpty) {
      emit(const SessionError('Invalid session ID'));
      return;
    }

    if (event.message.trim().isEmpty) {
      emit(const SessionError('Message cannot be empty'));
      return;
    }

    if (_currentSession == null) {
      emit(const SessionError('No active session to send message'));
      return;
    }

    // Validate session ID matches current session
    if (_currentSession!.id != event.sessionId) {
      emit(SessionError(
          'Session ID mismatch: expected ${_currentSession!.id}, got ${event.sessionId}'));
      return;
    }

    emit(MessageSending(_currentSession!));

    try {
      await openCodeClient.sendMessage(event.sessionId, event.message);
      print('📤 Message sent');

      // Update session to active state
      final updatedSession = _currentSession!.copyWith(
        isActive: true,
        lastActivity: DateTime.now(),
      );
      _currentSession = updatedSession;

      emit(SessionLoaded(session: updatedSession, isActive: true));
    } catch (e, stackTrace) {
      print('❌ [SessionBloc] Failed to send message: $e');
      print('❌ [SessionBloc] Stack trace: $stackTrace');
      emit(SessionError('Failed to send message: ${e.toString()}'));
    }
  }

  Future<void> _onCancelSessionOperation(
    CancelSessionOperation event,
    Emitter<SessionState> emit,
  ) async {
    // Validate input
    if (event.sessionId.trim().isEmpty) {
      emit(const SessionError('Invalid session ID for cancel operation'));
      return;
    }

    try {
      await openCodeClient.abortSession(event.sessionId);

      if (_currentSession?.id == event.sessionId) {
        final updatedSession = _currentSession!.copyWith(isActive: false);
        _currentSession = updatedSession;
        emit(SessionLoaded(session: updatedSession, isActive: false));
      }
    } catch (e, stackTrace) {
      print('❌ [SessionBloc] Failed to cancel operation: $e');
      print('❌ [SessionBloc] Stack trace: $stackTrace');
      emit(SessionError('Failed to cancel operation: ${e.toString()}'));
    }
  }

  void _onSessionUpdated(
    SessionUpdated event,
    Emitter<SessionState> emit,
  ) {
    _currentSession = event.session;
    emit(SessionLoaded(session: event.session));
  }

  Future<void> _onLoadStoredSession(
    LoadStoredSession event,
    Emitter<SessionState> emit,
  ) async {
    try {
      final storedSessionId = await _getStoredSessionId();
      if (storedSessionId != null) {
        print('🔍 Found stored session ID: $storedSessionId');
        add(ValidateSession(storedSessionId));
      } else {
        print('🔍 No stored session found, creating new session');
        _safelyCreateSession();
      }
    } catch (e) {
      print('❌ [SessionBloc] Failed to load stored session: $e');
      emit(SessionError('Failed to load stored session: ${e.toString()}'));
    }
  }

  Future<void> _onValidateSession(
    ValidateSession event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionValidating(event.sessionId));

    try {
      final sessions = await openCodeClient.getSessions();
      Session? session;
      try {
        session = sessions.firstWhere((s) => s.id == event.sessionId);
      } catch (e) {
        session = null;
      }
      
      if (session != null) {
        print('✅ Session validated: ${session.id}');
        _currentSession = session;
        emit(SessionLoaded(session: session));
      } else {
        print('❌ Session not found on server: ${event.sessionId}');
        emit(SessionNotFound(event.sessionId));
        await _clearStoredSessionId();
        _safelyCreateSession();
      }
    } catch (e) {
      print('❌ [SessionBloc] Failed to validate session: $e');
      emit(SessionNotFound(event.sessionId));
      await _clearStoredSessionId();
      _safelyCreateSession();
    }
  }

  Future<void> _onSetCurrentSession(
    SetCurrentSession event,
    Emitter<SessionState> emit,
  ) async {
    try {
      final sessions = await openCodeClient.getSessions();
      Session? session;
      try {
        session = sessions.firstWhere((s) => s.id == event.sessionId);
      } catch (e) {
        session = null;
      }
      
      if (session != null) {
        _currentSession = session;
        await _persistCurrentSessionId(session.id);
        emit(SessionLoaded(session: session));
        print('✅ Current session set to: ${session.id}');
      } else {
        emit(SessionError('Session not found: ${event.sessionId}'));
      }
    } catch (e) {
      print('❌ [SessionBloc] Failed to set current session: $e');
      emit(SessionError('Failed to set current session: ${e.toString()}'));
    }
  }

  String? get currentSessionId => _currentSession?.id;

  Future<void> _persistCurrentSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentSessionKey, sessionId);
      print('💾 Session ID persisted: $sessionId');
    } catch (e) {
      print('❌ Failed to persist session ID: $e');
    }
  }

  Future<String?> _getStoredSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentSessionKey);
    } catch (e) {
      print('❌ Failed to get stored session ID: $e');
      return null;
    }
  }

  Future<void> _clearStoredSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentSessionKey);
      print('🗑️ Stored session ID cleared');
    } catch (e) {
      print('❌ Failed to clear stored session ID: $e');
    }
  }

  /// Safely creates a session only if one isn't already being created
  void _safelyCreateSession() {
    if (!_isCreatingSession) {
      add(CreateSession());
    } else {
      print('🔍 [SessionBloc] Session creation already in progress, skipping additional request');
    }
  }
}
