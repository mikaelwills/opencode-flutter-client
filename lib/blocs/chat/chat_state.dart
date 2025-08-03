import 'package:equatable/equatable.dart';
import '../../models/opencode_message.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatConnecting extends ChatState {}

class ChatReady extends ChatState {
  final String sessionId;
  final List<OpenCodeMessage> messages;
  final bool isStreaming;

  const ChatReady({
    required this.sessionId,
    this.messages = const [],
    this.isStreaming = false,
  });

  @override
  List<Object> get props => [sessionId, messages, isStreaming];

  ChatReady copyWith({
    String? sessionId,
    List<OpenCodeMessage>? messages,
    bool? isStreaming,
  }) {
    return ChatReady(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class ChatSendingMessage extends ChatState {
  final String sessionId;
  final String message;
  final List<OpenCodeMessage> messages;

  const ChatSendingMessage({
    required this.sessionId,
    required this.message,
    this.messages = const [],
  });

  @override
  List<Object> get props => [sessionId, message, messages];
}

class ChatError extends ChatState {
  final String error;

  const ChatError(this.error);

  @override
  List<Object> get props => [error];
}
