import 'package:equatable/equatable.dart';
import '../../models/session.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object> get props => [];
}


class CreateSession extends SessionEvent {}


class SendMessage extends SessionEvent {
  final String sessionId;
  final String message;

  const SendMessage({required this.sessionId, required this.message});

  @override
  List<Object> get props => [sessionId, message];
}

class CancelSessionOperation extends SessionEvent {
  final String sessionId;

  const CancelSessionOperation(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}

class SessionUpdated extends SessionEvent {
  final Session session;

  const SessionUpdated(this.session);

  @override
  List<Object> get props => [session];
}

class LoadStoredSession extends SessionEvent {}

class ValidateSession extends SessionEvent {
  final String sessionId;

  const ValidateSession(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}

class SetCurrentSession extends SessionEvent {
  final String sessionId;

  const SetCurrentSession(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}