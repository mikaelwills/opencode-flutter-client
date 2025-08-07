import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/opencode_client.dart';
import '../../models/session.dart';
import 'session_list_event.dart';
import 'session_list_state.dart';

class SessionListBloc extends Bloc<SessionListEvent, SessionListState> {
  final OpenCodeClient openCodeClient;
  List<Session> _cachedSessions = [];

  SessionListBloc({required this.openCodeClient}) : super(SessionListInitial()) {
    on<LoadSessions>(_onLoadSessions);
    on<DeleteSession>(_onDeleteSession);
    on<RefreshSessions>(_onRefreshSessions);
    on<UpdateSessionSummary>(_onUpdateSessionSummary);
    on<SetSessionLoadingState>(_onSetSessionLoadingState);
    on<DeleteAllSessions>(_onDeleteAllSessions);
  }

  Future<void> _onLoadSessions(
    LoadSessions event,
    Emitter<SessionListState> emit,
  ) async {
    emit(SessionListLoading());

    try {
      final sessions = await openCodeClient.getSessions();
      
      // Sort by lastUpdated descending (newest first)
      sessions.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      
      _cachedSessions = sessions;
      emit(SessionListLoaded(sessions: sessions));

      // Start loading summaries for the newest 10 sessions (fallback to session ID if needed)
      _loadSessionSummaries(sessions.take(10).toList());
    } catch (e) {
      emit(SessionListError('Failed to load sessions: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteSession(
    DeleteSession event,
    Emitter<SessionListState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionListLoaded) return;

    emit(SessionDeleting(
      sessions: currentState.sessions,
      deletingSessionId: event.sessionId,
    ));

    try {
      await openCodeClient.deleteSession(event.sessionId);
      
      // Remove from local cache
      _cachedSessions.removeWhere((session) => session.id == event.sessionId);
      
      // Clear cached summary
      await _clearCachedSummary(event.sessionId);
      
      emit(SessionListLoaded(sessions: List.from(_cachedSessions)));
    } catch (e) {
      emit(SessionListError('Failed to delete session: ${e.toString()}'));
      // Restore previous state on error
      emit(currentState);
    }
  }

  Future<void> _onRefreshSessions(
    RefreshSessions event,
    Emitter<SessionListState> emit,
  ) async {
    // Refresh sessions list
    add(LoadSessions());
  }

  Future<void> _onUpdateSessionSummary(
    UpdateSessionSummary event,
    Emitter<SessionListState> emit,
  ) async {
    final currentState = state;
    if (currentState is! SessionListLoaded) return;

    // Update the session with the new summary
    final updatedSessions = currentState.sessions.map((session) {
      if (session.id == event.sessionId) {
        return session.copyWith(
          description: event.summary,
          isLoadingSummary: false,
        );
      }
      return session;
    }).toList();

    _cachedSessions = updatedSessions;
    emit(currentState.copyWith(sessions: updatedSessions));

    // Cache the summary
    await _cacheSummary(event.sessionId, event.summary);
  }

  Future<void> _onSetSessionLoadingState(
    SetSessionLoadingState event,
    Emitter<SessionListState> emit,
  ) async {
    final currentState = state;
    if (currentState is SessionListLoaded) {
      final updatedSessions = currentState.sessions.map((s) {
        if (s.id == event.sessionId) {
          return s.copyWith(isLoadingSummary: event.isLoading);
        }
        return s;
      }).toList();
      
      _cachedSessions = updatedSessions;
      emit(currentState.copyWith(sessions: updatedSessions));
    }
  }

  Future<void> _onDeleteAllSessions(
    DeleteAllSessions event,
    Emitter<SessionListState> emit,
  ) async {
    final currentState = state;
    
    // If sessions aren't loaded, load them first
    if (currentState is! SessionListLoaded) {
      emit(SessionListLoading());
      try {
        final sessions = await openCodeClient.getSessions();
        _cachedSessions = sessions;
        emit(SessionListLoaded(sessions: sessions));
      } catch (e) {
        emit(SessionListError('Failed to load sessions: ${e.toString()}'));
        return;
      }
    }

    // Filter out the excluded session if provided
    final sessionsToDelete = _cachedSessions
        .where((session) => session.id != event.excludeSessionId)
        .toList();
    
    if (sessionsToDelete.isEmpty) {
      // If no sessions to delete (either empty or only excluded session remains)
      final remainingSessions = event.excludeSessionId != null
          ? _cachedSessions.where((s) => s.id == event.excludeSessionId).toList()
          : <Session>[];
      emit(SessionListLoaded(sessions: remainingSessions));
      return;
    }

    emit(SessionListLoading());

    try {
      // Delete all sessions from server except excluded one
      for (final session in sessionsToDelete) {
        await openCodeClient.deleteSession(session.id);
        // Clear cached summary
        await _clearCachedSummary(session.id);
      }
      
      // Update local cache to only keep excluded session
      if (event.excludeSessionId != null) {
        _cachedSessions = _cachedSessions
            .where((session) => session.id == event.excludeSessionId)
            .toList();
      } else {
        _cachedSessions.clear();
      }
      
      emit(SessionListLoaded(sessions: List.from(_cachedSessions)));
    } catch (e) {
      emit(SessionListError('Failed to delete all sessions: ${e.toString()}'));
      // Restore previous state on error
      if (currentState is SessionListLoaded) {
        emit(currentState);
      }
    }
  }

  bool _isGenericDescription(String description) {
    if (description.isEmpty) return true;
    
    // Filter out "New Session -" prefix (already handled in Session model)
    if (description.startsWith('New Session -')) return true;
    
    // Filter out "Session {id}" pattern - likely generic session ID
    if (description.startsWith('Session ') && description.length < 50) {
      return true;
    }
    
    // Filter out "Starting new conversation" variants - generic auto-generated text
    if (description == 'Starting a new conversation' ||
        description == 'Starting new conversation') {
      return true;
    }
    
    // Filter out very short descriptions that are likely auto-generated
    if (description.length < 10 && 
        (description.toLowerCase().contains('session') || 
         description.toLowerCase().contains('chat'))) {
      return true;
    }
    
    return false;
  }

  Future<void> _loadSessionSummaries(List<Session> sessions) async {
    print('🔍 Starting summary generation for ${sessions.length} sessions...');
    int processedCount = 0;
    int skippedCount = 0;
    int generatedCount = 0;
    
    for (final session in sessions) {
      processedCount++;
      print('🔍 Processing session $processedCount/${sessions.length}: ${session.id}');
      // Skip if session already has a meaningful (non-generic) description
      if (!_isGenericDescription(session.description)) {
        skippedCount++;
        print('⏭️ Skipping session ${session.id} - already has meaningful description: "${session.description}"');
        continue;
      }

      // Check cache first
      final cachedSummary = await _getCachedSummary(session.id);
      if (cachedSummary != null) {
        print('💾 Using cached summary for session ${session.id}');
        add(UpdateSessionSummary(session.id, cachedSummary));
        continue;
      }

      // Set loading state
      add(SetSessionLoadingState(session.id, true));

      // Load summary from server
      try {
        print('🔄 Generating summary for session ${session.id}...');
        final summary = await openCodeClient.generateSessionSummary(session.id);
        generatedCount++;
        print('✅ Generated summary for session ${session.id}: "${summary.length > 50 ? "${summary.substring(0, 50)}..." : summary}"');
        add(UpdateSessionSummary(session.id, summary));
      } catch (e) {
        print('❌ Failed to load summary for session ${session.id}: $e');
        // Mark as failed and don't retry
        await _cacheSummary(session.id, '');
        add(UpdateSessionSummary(session.id, ''));
        // Continue with next session even if this one failed
      }
    }
    
    print('✅ Summary generation completed: $processedCount sessions processed, $skippedCount skipped (meaningful), $generatedCount generated');
  }

  Future<String?> _getCachedSummary(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_summary_$sessionId');
    } catch (e) {
      print('Failed to get cached summary: $e');
      return null;
    }
  }

  Future<void> _cacheSummary(String sessionId, String summary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_summary_$sessionId', summary);
    } catch (e) {
      print('Failed to cache summary: $e');
    }
  }

  Future<void> _clearCachedSummary(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_summary_$sessionId');
    } catch (e) {
      print('Failed to clear cached summary: $e');
    }
  }
}