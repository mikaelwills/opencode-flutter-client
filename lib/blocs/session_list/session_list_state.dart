import 'package:equatable/equatable.dart';
import '../../models/session.dart';

abstract class SessionListState extends Equatable {
  const SessionListState();

  @override
  List<Object?> get props => [];
}

class SessionListInitial extends SessionListState {}

class SessionListLoading extends SessionListState {}

class SessionListLoaded extends SessionListState {
  final List<Session> sessions;
  final String? selectedSessionId;

  const SessionListLoaded({
    required this.sessions,
    this.selectedSessionId,
  });

  @override
  List<Object?> get props => [sessions, selectedSessionId];

  SessionListLoaded copyWith({
    List<Session>? sessions,
    String? selectedSessionId,
  }) {
    return SessionListLoaded(
      sessions: sessions ?? this.sessions,
      selectedSessionId: selectedSessionId ?? this.selectedSessionId,
    );
  }
}

class SessionListError extends SessionListState {
  final String message;

  const SessionListError(this.message);

  @override
  List<Object> get props => [message];
}

class SessionDeleting extends SessionListState {
  final List<Session> sessions;
  final String deletingSessionId;

  const SessionDeleting({
    required this.sessions,
    required this.deletingSessionId,
  });

  @override
  List<Object> get props => [sessions, deletingSessionId];
}