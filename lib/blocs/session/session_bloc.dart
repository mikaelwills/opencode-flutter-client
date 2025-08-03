import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/opencode_client.dart';
import '../../models/session.dart';

import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final OpenCodeClient openCodeClient;
  Session? _currentSession;

  SessionBloc({required this.openCodeClient}) : super(SessionInitial()) {
    on<CreateSession>(_onCreateSession);
    on<SendMessage>(_onSendMessage);
    on<CancelSessionOperation>(_onCancelSessionOperation);
    on<SessionUpdated>(_onSessionUpdated);
  }

  Session? get currentSession => _currentSession;

  Future<void> _onCreateSession(
    CreateSession event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading());

    try {
      final session = await openCodeClient.createSession();
      print('✅ Session created: ${session.id}');

      _currentSession = session;
      emit(SessionLoaded(session: session));
    } catch (e, stackTrace) {
      print('❌ [SessionBloc] Failed to create session: $e');
      print('❌ [SessionBloc] Stack trace: $stackTrace');
      emit(SessionError('Failed to create session: ${e.toString()}'));
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
      emit(SessionError('Session ID mismatch: expected ${_currentSession!.id}, got ${event.sessionId}'));
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
}
