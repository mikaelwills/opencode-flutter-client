import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../session/session_bloc.dart';
import '../session/session_event.dart' as session_events;
import '../session/session_state.dart' as session_states;
import '../../services/sse_service.dart';
import '../../models/opencode_message.dart';
import '../../models/opencode_event.dart';
import '../../models/message_part.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final SessionBloc sessionBloc;
  final SSEService sseService;

  final List<OpenCodeMessage> _messages = [];
  final Map<String, int> _messageIndex = {}; // messageId -> index mapping
  String? _currentSessionId;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _sessionSubscription;

  static const int _maxMessages = 100;

  ChatBloc({
    required this.sessionBloc,
    required this.sseService,
  }) : super(ChatInitial()) {
    on<StartChat>(_onStartChat);
    on<SendChatMessage>(_onSendChatMessage);
    on<CancelCurrentOperation>(_onCancelCurrentOperation);
    on<ChatSessionChanged>(_onChatSessionChanged);
    on<SSEEventReceived>(_onSSEEventReceived);
    on<SSEErrorOccurred>(_onSSEErrorOccurred);
    on<ClearMessages>(_onClearMessages);
    on<ClearChat>(_onClearChat);
    on<AddUserMessage>(_onAddUserMessage);
  }

  Future<void> _onStartChat(
    StartChat event,
    Emitter<ChatState> emit,
  ) async {
    try {
      print(
          '🔍 [ChatBloc] Starting chat with existing session: ${event.sessionId}');

      // Use existing session (no creation needed)
      final sessionId = event.sessionId;

      // Start listening for SSE events directly
      _startListening(sessionId);
      emit(ChatReady(sessionId: sessionId, messages: _messages));

      // If there's an initial message, send it immediately
      if (event.initialMessage != null && event.initialMessage!.isNotEmpty) {
        add(SendChatMessage(event.initialMessage!));
      }
    } catch (e) {
      emit(ChatError('Failed to start chat: ${e.toString()}'));
    }
  }

  void _startListening(String sessionId) {
    print('🔍 [ChatBloc] Starting to listen for session: $sessionId');
    _currentSessionId = sessionId;
    _messages.clear();
    _messageIndex.clear();

    // Cancel any existing subscription
    _eventSubscription?.cancel();

    // Subscribe to SSE events and handle them properly
    _eventSubscription = sseService.connectToEventStream().listen(
      (sseEvent) {
        // No logging here - handled in SSEService

        // Only process events for the current session
        if (sseEvent.sessionId == _currentSessionId) {
          add(SSEEventReceived(sseEvent));
        }
      },
      onError: (error) {
        print('❌ [ChatBloc] SSE stream error: $error');
        add(SSEErrorOccurred('SSE stream error: ${error.toString()}'));
      },
    );
  }

  Future<void> _onSendChatMessage(
    SendChatMessage event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatReady) {
      emit(const ChatError('Chat not ready'));
      return;
    }

    final sessionId = currentState.sessionId;

    try {
      // Add user message to display immediately
      _addUserMessage(sessionId, event.message);

      // Emit state with the new user message
      emit(ChatSendingMessage(
        sessionId: sessionId,
        message: event.message,
        messages: List.from(_messages),
      ));

      // Send message to server
      sessionBloc.add(session_events.SendMessage(
        sessionId: sessionId,
        message: event.message,
      ));

      // Listen for session response without blocking
      _sessionSubscription?.cancel();
      _sessionSubscription = sessionBloc.stream.listen((sessionState) {
        if (sessionState is session_states.SessionLoaded) {
          // Return to ready state after message is sent
          final actuallyStreaming = _messages.isNotEmpty &&
              _messages.last.role == 'assistant' &&
              _messages.last.isStreaming;
          print('🔧 Session response: actuallyStreaming=$actuallyStreaming');
          emit(_createChatReadyState(isStreaming: actuallyStreaming));
          _sessionSubscription?.cancel();
        } else if (sessionState is session_states.SessionError) {
          emit(ChatError(sessionState.message));
          _sessionSubscription?.cancel();
        }
      });
    } catch (e) {
      emit(ChatError('Failed to send message: ${e.toString()}'));
    }
  }

  void _addUserMessage(String sessionId, String content) {
    if (sessionId == _currentSessionId) {
      // Check if we already have a user message with the same content to prevent duplicates
      final existingUserMessages = _messages.where((msg) =>
          msg.role == 'user' &&
          msg.parts.isNotEmpty &&
          msg.parts.first.content == content);

      if (existingUserMessages.isNotEmpty) {
        print(
            '🔍 [ChatBloc] User message already exists, skipping duplicate: "$content"');
        return;
      }

      final userMessage = OpenCodeMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: sessionId,
        role: 'user',
        created: DateTime.now(),
        parts: [
          MessagePart(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'text',
            content: content,
          ),
        ],
      );

      _messages.add(userMessage);
      _messageIndex[userMessage.id] = _messages.length - 1;
      _enforceMessageLimit();
      print('🔥 [ChatBloc] Added user message: "$content"');
    }
  }

  Future<void> _onCancelCurrentOperation(
    CancelCurrentOperation event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is ChatReady || currentState is ChatSendingMessage) {
      final sessionId = currentState is ChatReady
          ? currentState.sessionId
          : (currentState as ChatSendingMessage).sessionId;

      try {
        sessionBloc.add(session_events.CancelSessionOperation(sessionId));
        _handleSessionAborted(sessionId);
        emit(_createChatReadyState());
      } catch (e) {
        emit(ChatError('Failed to cancel operation: ${e.toString()}'));
      }
    }
  }

  void _onChatSessionChanged(
    ChatSessionChanged event,
    Emitter<ChatState> emit,
  ) {
    _startListening(event.sessionId);
    emit(_createChatReadyState());
  }

  void _onSSEEventReceived(
    SSEEventReceived event,
    Emitter<ChatState> emit,
  ) {
    final sseEvent = event.event;

    // Only process events for the current session
    if (sseEvent.sessionId != _currentSessionId) {
      print('❌ [ChatBloc] Session ID mismatch - ignoring event');
      return;
    }

    // Handle different event types
    switch (sseEvent.type) {
      case 'message.updated':
        if (sseEvent.data != null) {
          try {
            final message = OpenCodeMessage.fromJson(sseEvent.data!);
            _updateOrAddMessage(message);
            _emitCurrentState(emit);
          } catch (e) {
            print('❌ [ChatBloc] Failed to parse message update: $e');
            emit(ChatError('Failed to parse message update: ${e.toString()}'));
          }
        }
        break;
      case 'message.part.updated':
        if (sseEvent.data != null) {
          final stateChanged = _handlePartialUpdate(sseEvent);
          if (stateChanged) {
            _emitCurrentState(emit);
          }
        }
        break;
      case 'session.idle':
        print('💤 Session idle');
        _handleSessionIdle();
        _emitCurrentState(emit);
        break;
      default:
      // print('🔍 [ChatBloc] Unknown event type: ${sseEvent.type}');
    }
  }

  void _onSSEErrorOccurred(
    SSEErrorOccurred event,
    Emitter<ChatState> emit,
  ) {
    print('❌ [ChatBloc] SSE error occurred: ${event.error}');
    emit(ChatError(event.error));
  }

  void _onClearMessages(
    ClearMessages event,
    Emitter<ChatState> emit,
  ) {
    _messages.clear();
    _messageIndex.clear();
    if (_currentSessionId != null) {
      emit(_createChatReadyState());
    }
  }

  void _onClearChat(
    ClearChat event,
    Emitter<ChatState> emit,
  ) {
    // Clear all chat state and prepare for new session
    _messages.clear();
    _messageIndex.clear();
    _currentSessionId = null;
    
    // Cancel any existing event subscription
    _eventSubscription?.cancel();
    _eventSubscription = null;
    
    // Emit initial state
    emit(ChatInitial());
  }

  void _onAddUserMessage(
    AddUserMessage event,
    Emitter<ChatState> emit,
  ) {
    _addUserMessage(event.sessionId, event.content);
    _emitCurrentState(emit);
  }

  void _updateOrAddMessage(OpenCodeMessage message) {
    final messageIndex = _messageIndex[message.id];

    if (messageIndex != null && messageIndex < _messages.length) {
      // Update existing message
      _messages[messageIndex] = message;
      print('🔍 [ChatBloc] Updated existing message: ${message.id}');
    } else {
      // Check for duplicate content before adding new message
      final messageContent = message.parts
          .where((part) => part.type == 'text')
          .map((part) => part.content ?? '')
          .join(' ')
          .trim();

      if (_isDuplicateContent(messageContent, message.role)) {
        print('🚫 Skipping duplicate message: ${message.id}');
        return;
      }

      // Add new message
      _messages.add(message);
      _messageIndex[message.id] = _messages.length - 1;
      _enforceMessageLimit();
      print('🔍 [ChatBloc] Added new message: ${message.id}');
    }
  }

  bool _handlePartialUpdate(OpenCodeEvent sseEvent) {
    try {
      // Extract part data from the event
      Map<String, dynamic>? partData;
      if (sseEvent.data != null &&
          sseEvent.data!['properties'] is Map<String, dynamic>) {
        final properties = sseEvent.data!['properties'] as Map<String, dynamic>;
        if (properties['part'] is Map<String, dynamic>) {
          partData = properties['part'] as Map<String, dynamic>;
        }
      }

      if (partData == null) {
        print('❌ [ChatBloc] No part data found in event');
        return false;
      }

      final messageId =
          sseEvent.messageId ?? partData['messageID'] ?? partData['messageId'];
      final partId = partData['id'] as String?;
      final partType = partData['type'] as String?;
      final partText = partData['text'] as String?;

      if (messageId != null) {
        final messageIndex = _messageIndex[messageId];

        if (messageIndex != null && messageIndex < _messages.length) {
          final currentMessage = _messages[messageIndex];

          // Update or add the part to the message
          final updatedParts = List<MessagePart>.from(currentMessage.parts);
          final partIndex = updatedParts.indexWhere((p) => p.id == partId);

          if (partIndex != -1) {
            // Update existing part
            updatedParts[partIndex] = MessagePart(
              id: partId ?? updatedParts[partIndex].id,
              type: partType ?? updatedParts[partIndex].type,
              content: partText ?? updatedParts[partIndex].content,
              metadata: partData['time'] as Map<String, dynamic>?,
            );
          } else {
            // Add new part
            updatedParts.add(MessagePart(
              id: partId ?? DateTime.now().millisecondsSinceEpoch.toString(),
              type: partType ?? 'text',
              content: partText,
              metadata: partData['time'] as Map<String, dynamic>?,
            ));
          }

          // Create updated message with streaming flag
          final updatedMessage = currentMessage.copyWith(
            parts: updatedParts,
            isStreaming: true,
          );

          _messages[messageIndex] = updatedMessage;
        } else {
          // Check for duplicate content before creating new message
          if (partText != null && _isDuplicateContent(partText, 'assistant')) {
            print('🚫 Skipping duplicate streaming message: $messageId');
            return false;
          }

          // Create a new streaming message
          final newMessage = OpenCodeMessage(
            id: messageId,
            sessionId: sseEvent.sessionId ?? _currentSessionId ?? '',
            role: 'assistant',
            created: DateTime.now(),
            parts: [
              MessagePart(
                id: partId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                type: partType ?? 'text',
                content: partText,
                metadata: partData['time'] as Map<String, dynamic>?,
              ),
            ],
            isStreaming: true,
          );

          _messages.add(newMessage);
          _messageIndex[newMessage.id] = _messages.length - 1;
          _enforceMessageLimit();
        }
      }
      return true;
    } catch (e) {
      print('❌ [ChatBloc] Failed to handle partial update: $e');
      return false;
    }
  }

  void _handleSessionIdle() {
    if (_messages.isNotEmpty) {
      final lastMessage = _messages.last;
      if (lastMessage.role == 'assistant' && lastMessage.isStreaming) {
        print('🔄 Marking assistant message as completed: ${lastMessage.id}');
        final completedMessage = lastMessage.copyWith(
          isStreaming: false,
          completed: DateTime.now(),
        );
        _messages[_messages.length - 1] = completedMessage;
        print(
            '✅ Message marked as completed, isStreaming: ${completedMessage.isStreaming}');
      } else {
        print('🔍 No streaming assistant message to complete');
      }
    }
  }

  void _handleSessionAborted(String sessionId) {
    if (sessionId == _currentSessionId) {
      print('🔍 [ChatBloc] Session aborted - stopping streaming');

      // Mark the last message as completed if it was streaming
      if (_messages.isNotEmpty) {
        final lastMessage = _messages.last;
        if (lastMessage.role == 'assistant' && lastMessage.isStreaming) {
          final completedMessage = lastMessage.copyWith(
            isStreaming: false,
            completed: DateTime.now(),
          );
          _messages[_messages.length - 1] = completedMessage;
        }
      }
    }
  }

  /// Check if a message's content duplicates a recent message from a different role
  bool _isDuplicateContent(String content, String role) {
    if (content.trim().isEmpty) return false;

    // Look for messages from the opposite role in the last 30 seconds
    final now = DateTime.now();
    final recentMessages = _messages.where((msg) =>
        msg.role != role && now.difference(msg.created).inSeconds < 30);

    for (final message in recentMessages) {
      if (message.parts.isNotEmpty) {
        final messageContent = message.parts
            .where((part) => part.type == 'text')
            .map((part) => part.content ?? '')
            .join(' ')
            .trim();

        // Check for exact content match (case insensitive)
        if (messageContent.toLowerCase() == content.toLowerCase()) {
          print(
              '🚫 Duplicate content detected: "$content" ($role duplicates ${message.role})');
          return true;
        }
      }
    }

    return false;
  }

  void _enforceMessageLimit() {
    if (_messages.length > _maxMessages) {
      final messagesToRemove = _messages.length - _maxMessages;

      // Remove old messages and update index map
      for (int i = 0; i < messagesToRemove; i++) {
        final removedMessage = _messages.removeAt(0);
        _messageIndex.remove(removedMessage.id);
      }

      // Update remaining message indices
      _messageIndex.clear();
      for (int i = 0; i < _messages.length; i++) {
        _messageIndex[_messages[i].id] = i;
      }

      print(
          '🗑️ Removed $messagesToRemove old messages to enforce limit of $_maxMessages');
    }
  }

  ChatReady _createChatReadyState({bool? isStreaming}) {
    final streaming = isStreaming ??
        (_messages.isNotEmpty &&
            _messages.last.role == 'assistant' &&
            _messages.last.isStreaming);

    return ChatReady(
      sessionId: _currentSessionId!,
      messages: List.from(_messages),
      isStreaming: streaming,
    );
  }

  void _emitCurrentState(Emitter<ChatState> emit) {
    if (_currentSessionId != null) {
      emit(_createChatReadyState());
    }
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    _sessionSubscription?.cancel();
    return super.close();
  }
}
