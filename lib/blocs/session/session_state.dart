import 'package:equatable/equatable.dart';
import '../../models/session.dart';
import '../../models/opencode_message.dart';

abstract class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

class SessionInitial extends SessionState {}

class SessionLoading extends SessionState {}


class SessionLoaded extends SessionState {
  final Session session;
  final bool isActive;
  final OpenCodeMessage? lastMessage;

  const SessionLoaded({
    required this.session,
    this.isActive = false,
    this.lastMessage,
  });

  @override
  List<Object?> get props => [session, isActive, lastMessage];
}

class SessionError extends SessionState {
  final String message;

  const SessionError(this.message);

  @override
  List<Object> get props => [message];
}

class MessageSending extends SessionState {
  final Session session;

  const MessageSending(this.session);

  @override
  List<Object> get props => [session];
}