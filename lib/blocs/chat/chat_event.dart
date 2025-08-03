import 'package:equatable/equatable.dart';
import '../../models/opencode_event.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class StartChat extends ChatEvent {
  final String sessionId;
  final String? initialMessage;

  const StartChat({required this.sessionId, this.initialMessage});

  @override
  List<Object> get props => [sessionId, initialMessage ?? ''];
}

class SendChatMessage extends ChatEvent {
  final String message;

  const SendChatMessage(this.message);

  @override
  List<Object> get props => [message];
}

class CancelCurrentOperation extends ChatEvent {}

class ChatSessionChanged extends ChatEvent {
  final String sessionId;

  const ChatSessionChanged(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}

// SSE-related events (merged from MessageBloc)
class SSEEventReceived extends ChatEvent {
  final OpenCodeEvent event;

  const SSEEventReceived(this.event);

  @override
  List<Object> get props => [event];
}

class SSEErrorOccurred extends ChatEvent {
  final String error;

  const SSEErrorOccurred(this.error);

  @override
  List<Object> get props => [error];
}

class ClearMessages extends ChatEvent {}

class AddUserMessage extends ChatEvent {
  final String sessionId;
  final String content;

  const AddUserMessage({
    required this.sessionId,
    required this.content,
  });

  @override
  List<Object> get props => [sessionId, content];
}