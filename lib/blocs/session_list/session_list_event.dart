import 'package:equatable/equatable.dart';

abstract class SessionListEvent extends Equatable {
  const SessionListEvent();

  @override
  List<Object?> get props => [];
}

class LoadSessions extends SessionListEvent {}

class DeleteSession extends SessionListEvent {
  final String sessionId;

  const DeleteSession(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}

class RefreshSessions extends SessionListEvent {}

class UpdateSessionSummary extends SessionListEvent {
  final String sessionId;
  final String summary;

  const UpdateSessionSummary(this.sessionId, this.summary);

  @override
  List<Object> get props => [sessionId, summary];
}

class SetSessionLoadingState extends SessionListEvent {
  final String sessionId;
  final bool isLoading;

  const SetSessionLoadingState(this.sessionId, this.isLoading);

  @override
  List<Object> get props => [sessionId, isLoading];
}

class DeleteAllSessions extends SessionListEvent {
  final String? excludeSessionId;

  const DeleteAllSessions({this.excludeSessionId});

  @override
  List<Object?> get props => [excludeSessionId];
}