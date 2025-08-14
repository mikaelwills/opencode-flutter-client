import 'package:equatable/equatable.dart';
import '../../models/opencode_event.dart';
import '../../models/opencode_message.dart';

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

class ClearMessages extends ChatEvent {}

class ClearChat extends ChatEvent {}

class AddUserMessage extends ChatEvent {
  final String content;

  const AddUserMessage(this.content);

  @override
  List<Object> get props => [content];
}

class RetryMessage extends ChatEvent {
  final String messageContent;

  const RetryMessage(this.messageContent);

  @override
  List<Object> get props => [messageContent];
}

class DeleteQueuedMessage extends ChatEvent {
  final String messageContent;

  const DeleteQueuedMessage(this.messageContent);

  @override
  List<Object> get props => [messageContent];
}

// Internal event for refreshing chat state during reconnection
class RefreshChatStateEvent extends ChatEvent {}

class MessageStatusChanged extends ChatEvent {
  final MessageSendStatus status;

  const MessageStatusChanged(this.status);

  @override
  List<Object> get props => [status];
}