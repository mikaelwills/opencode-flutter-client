import 'package:equatable/equatable.dart';
import '../../models/opencode_event.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class LoadMessagesForCurrentSession extends ChatEvent {}

class SendChatMessage extends ChatEvent {
  final String message;

  const SendChatMessage(this.message);

  @override
  List<Object> get props => [message];
}

class CancelCurrentOperation extends ChatEvent {}

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

class ClearChat extends ChatEvent {}

class AddUserMessage extends ChatEvent {
  final String content;

  const AddUserMessage(this.content);

  @override
  List<Object> get props => [content];
}