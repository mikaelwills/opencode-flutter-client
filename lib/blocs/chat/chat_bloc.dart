import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../session/session_bloc.dart';
import '../session/session_event.dart' as session_events;
import '../session/session_state.dart';
import '../../services/sse_service.dart';
import '../../services/opencode_client.dart';
import '../../services/message_queue_service.dart';
import '../../models/opencode_message.dart';
import '../../models/opencode_event.dart';
import '../../models/message_part.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final SessionBloc sessionBloc;
  final SSEService sseService;
  final OpenCodeClient openCodeClient;
  final MessageQueueService messageQueueService;

  final List<OpenCodeMessage> _messages = [];
  final Map<String, int> _messageIndex = {}; // messageId -> index mapping
  StreamSubscription? _eventSubscription;
  StreamSubscription? _sessionSubscription; // For temporary subscriptions (e.g., in _onSendChatMessage)
  StreamSubscription? _permanentSessionSubscription; // For constructor subscription

  static const int _maxMessages = 100;

  ChatBloc({
    required this.sessionBloc,
    required this.sseService,
    required this.openCodeClient,
    required this.messageQueueService,
  }) : super(ChatInitial()) {
    on<LoadMessagesForCurrentSession>(_onLoadMessagesForCurrentSession);
    on<SendChatMessage>(_onSendChatMessage);
    on<CancelCurrentOperation>(_onCancelCurrentOperation);
    on<SSEEventReceived>(_onSSEEventReceived);
    on<ClearMessages>(_onClearMessages);
    on<ClearChat>(_onClearChat);
    on<AddUserMessage>(_onAddUserMessage);
    on<RetryMessage>(_onRetryMessage);
    on<DeleteQueuedMessage>(_onDeleteQueuedMessage);
    on<MessageStatusChanged>(_onMessageStatusChanged);
    
    // Listen to SessionBloc for session changes (permanent subscription)
    _permanentSessionSubscription = sessionBloc.stream.listen((sessionState) {
      if (sessionState is SessionLoaded) {
        add(LoadMessagesForCurrentSession());
      }
    });
  }

  Future<void> _onLoadMessagesForCurrentSession(
    LoadMessagesForCurrentSession event,
    Emitter<ChatState> emit,
  ) async {
    final currentSessionId = sessionBloc.currentSessionId;
    
    if (currentSessionId == null) {
      // Silently return, as the SessionBloc listener in ChatScreen will handle navigation.
      return;
    }

    try {
      
      emit(ChatConnecting());

      // Clear current state
      _messages.clear();
      _messageIndex.clear();

      // Load message history from API
      final messages = await openCodeClient.getSessionMessages(currentSessionId);
      
      // Add messages to local state
      for (final message in messages) {
        _messages.add(message);
        _messageIndex[message.id] = _messages.length - 1;
      }
      

      // Start listening for new SSE events (without clearing messages)
      _startListening(currentSessionId);
      
      // Emit ready state with loaded messages
      emit(ChatReady(sessionId: currentSessionId, messages: List.from(_messages)));
      
    } catch (e) {
      print('❌ [ChatBloc] Failed to load messages for current session: $e');
      emit(const ChatError('Failed to load messages. Please try again.'));
    }
  }

  void _startListening(String sessionId) {

    // Cancel any existing subscription
    _eventSubscription?.cancel();

    // Subscribe to SSE events and handle them properly
    _eventSubscription = sseService.connectToEventStream().listen(
      (sseEvent) {
        // Only process events for the current session
        if (sseEvent.sessionId == sessionBloc.currentSessionId) {
          add(SSEEventReceived(sseEvent));
        }
      },
      onError: (error) {
        // Errors are now handled by the ConnectionBloc and displayed in the ConnectionStatusRow.
        // This avoids showing a full-screen error and breaking the chat UI.
        print('❌ [ChatBloc] SSE stream error: $error');
      },
    );
  }

  Future<void> _onSendChatMessage(
    SendChatMessage event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatReady) {
      // Silently return, chat is not in a state to send messages.
      return;
    }

    final sessionId = currentState.sessionId;

    // Add user message to display immediately and get its ID
    final messageId = _addUserMessage(sessionId, event.message);
    
    if (messageId == null) {
      print('📬 [ChatBloc] Failed to add user message - session mismatch');
      return;
    }

    try {
      // Emit state with the new user message
      emit(ChatSendingMessage(
        sessionId: sessionId,
        message: event.message,
        messages: List.from(_messages),
      ));

      // Send message via MessageQueueService using the actual message ID (non-blocking)
      messageQueueService.sendMessage(
        messageId: messageId,
        sessionId: sessionId,
        content: event.message,
        onStatusChange: (status) {
          _updateMessageStatus(messageId, status);
          add(MessageStatusChanged(status));
        },
      );
      
    } catch (e) {
      // On failure, update the message status to failed
      _updateMessageStatus(messageId, MessageSendStatus.failed);
      print('📬 [ChatBloc] Failed to send message: ${e.toString()}');
      emit(_createChatReadyState()); // Emit ready state to allow retry
    }
  }

  String? _addUserMessage(String sessionId, String content) {
    if (sessionId == sessionBloc.currentSessionId) {
      // Check if we already have a user message with the same content to prevent duplicates
      final existingUserMessages = _messages.where((msg) =>
          msg.role == 'user' &&
          msg.parts.isNotEmpty &&
          msg.parts.first.content == content &&
          msg.sendStatus != MessageSendStatus.failed); // Don't skip failed messages that are being retried

      if (existingUserMessages.isNotEmpty) {
        print(
            '🔍 [ChatBloc] User message already exists, skipping duplicate: "$content"');
        return existingUserMessages.first.id; // Return existing message ID
      }

      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final userMessage = OpenCodeMessage(
        id: messageId,
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
        sendStatus: MessageSendStatus.sent, // Default to sent
      );

      _messages.add(userMessage);
      _messageIndex[userMessage.id] = _messages.length - 1;
      _enforceMessageLimit();
      print('🔥 [ChatBloc] Added user message: "$content"');
      
      return messageId; // Return the new message ID
    }
    return null; // Session mismatch
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

  void _onSSEEventReceived(
    SSEEventReceived event,
    Emitter<ChatState> emit,
  ) {
    final sseEvent = event.event;

    // Only process events for the current session
    if (sseEvent.sessionId != sessionBloc.currentSessionId) {
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
            // Don't emit an error state, just log it.
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
      case 'storage.write':
      case 'session.updated':
        // These are internal server events - ignore
        break;
      default:
      // print('🔍 [ChatBloc] Unknown event type: ${sseEvent.type}');
    }
  }

  void _onClearMessages(
    ClearMessages event,
    Emitter<ChatState> emit,
  ) {
    _messages.clear();
    _messageIndex.clear();
    if (sessionBloc.currentSessionId != null) {
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
    final currentSessionId = sessionBloc.currentSessionId;
    if (currentSessionId != null) {
      _addUserMessage(currentSessionId, event.content);
      _emitCurrentState(emit);
    }
  }

  Future<void> _onRetryMessage(
    RetryMessage event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatReady) {
      return;
    }

    final sessionId = currentState.sessionId;
    print('📬 [ChatBloc] Retrying message: "${event.messageContent}"');

    // Find the failed message to get its ID
    final failedMessageIndex = _messages.lastIndexWhere((msg) =>
        msg.role == 'user' &&
        msg.parts.isNotEmpty &&
        msg.parts.first.content == event.messageContent &&
        msg.sendStatus == MessageSendStatus.failed);

    if (failedMessageIndex == -1) {
      print('📬 [ChatBloc] Failed message not found for retry');
      return;
    }

    final failedMessage = _messages[failedMessageIndex];
    final messageId = failedMessage.id;

    // Retry message via MessageQueueService using existing message ID (non-blocking)
    messageQueueService.retryMessage(
      messageId: messageId,
      sessionId: sessionId,
      content: event.messageContent,
      onStatusChange: (status) {
        _updateMessageStatus(messageId, status);
        add(MessageStatusChanged(status));
      },
    );
  }

  void _onDeleteQueuedMessage(
    DeleteQueuedMessage event,
    Emitter<ChatState> emit,
  ) {
    print('📬 [ChatBloc] Deleting queued message: "${event.messageContent}"');
    
    // Find the queued message to get its actual ID
    final queuedMessageIndex = _messages.lastIndexWhere((msg) =>
        msg.role == 'user' &&
        msg.parts.isNotEmpty &&
        msg.parts.first.content == event.messageContent &&
        msg.sendStatus == MessageSendStatus.queued);

    if (queuedMessageIndex == -1) {
      print('📬 [ChatBloc] Queued message not found for deletion');
      return;
    }

    final queuedMessage = _messages[queuedMessageIndex];
    final messageId = queuedMessage.id;
    
    // Remove from queue service using actual message ID
    final removed = messageQueueService.removeFromQueue(messageId);
    
    if (removed) {
      print('📬 [ChatBloc] Message removed from queue: $messageId');
    }
    
    // Remove the message from local display
    _messages.removeAt(queuedMessageIndex);
    
    // Update message index
    _rebuildMessageIndex();
    
    emit(_createChatReadyState());
  }

  void _onMessageStatusChanged(
    MessageStatusChanged event,
    Emitter<ChatState> emit,
  ) {
    final status = event.status;
    
    // Update UI based on status change
    if (status == MessageSendStatus.sent) {
      final actuallyStreaming = _messages.isNotEmpty &&
          _messages.last.role == 'assistant' &&
          _messages.last.isStreaming;
      print('📬 [ChatBloc] Message sent successfully, actuallyStreaming=$actuallyStreaming');
      emit(_createChatReadyState(isStreaming: actuallyStreaming));
    } else if (status == MessageSendStatus.failed) {
      print('📬 [ChatBloc] Message send failed');
      emit(_createChatReadyState()); // Emit ready state to allow retry
    } else if (status == MessageSendStatus.queued) {
      print('📬 [ChatBloc] Message queued for offline sending');
      emit(_createChatReadyState());
    } else if (status == MessageSendStatus.sending) {
      print('📬 [ChatBloc] Message being sent');
      // Keep current state, no need to emit
    }
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
              metadata: partData,
            );
          } else {
            // Special handling for tool parts to prevent spam
            if (partType == 'tool') {
              // Extract tool name from the 'tool' field (not 'name')
              final toolName = partData['tool'] as String?;
              
              // Look for existing tool parts - if no name, just check if any tool part exists
              final existingToolIndex = toolName != null 
                ? updatedParts.indexWhere((p) => 
                    p.type == 'tool' && p.metadata?['tool'] == toolName)
                : updatedParts.indexWhere((p) => p.type == 'tool');
              
              if (existingToolIndex != -1) {
                // Update existing tool part instead of creating new one
                updatedParts[existingToolIndex] = MessagePart(
                  id: updatedParts[existingToolIndex].id,
                  type: 'tool',
                  content: partText ?? updatedParts[existingToolIndex].content,
                  metadata: partData.isNotEmpty ? partData : updatedParts[existingToolIndex].metadata,
                );
                return true; // Skip adding new part
              } else {
                // Add new tool part only if no duplicate exists
                updatedParts.add(MessagePart(
                  id: partId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  type: 'tool',
                  content: partText,
                  metadata: partData,
                ));
              }
            } else {
              // Add new non-tool part normally
              updatedParts.add(MessagePart(
                id: partId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                type: partType ?? 'text',
                content: partText,
                metadata: partData,
              ));
            }
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
            sessionId: sseEvent.sessionId ?? sessionBloc.currentSessionId ?? '',
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
    if (sessionId == sessionBloc.currentSessionId) {
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

  /// Smart duplicate detection that blocks exact echoes but allows legitimate responses
  bool _isDuplicateContent(String content, String role) {
    if (content.trim().isEmpty) return false;

    final now = DateTime.now();
    final contentLower = content.toLowerCase().trim();

    // 1. Check for same-role duplicates (actual duplicate messages)
    final sameRoleRecentMessages = _messages.where((msg) =>
        msg.role == role && now.difference(msg.created).inSeconds < 30);

    for (final message in sameRoleRecentMessages) {
      if (message.parts.isNotEmpty) {
        final messageContent = message.parts
            .where((part) => part.type == 'text')
            .map((part) => part.content ?? '')
            .join(' ')
            .trim();

        // Check for exact content match (case insensitive)
        if (messageContent.toLowerCase() == contentLower) {
          print('🚫 [ChatBloc] Same-role duplicate content detected: "$content" ($role duplicates another $role message)');
          return true;
        }
      }
    }

    // 2. Check for exact echoes from opposite role (server echoing user input)
    if (role == 'assistant') {
      final recentUserMessages = _messages.where((msg) =>
          msg.role == 'user' && now.difference(msg.created).inSeconds < 10); // Shorter window for echoes

      for (final message in recentUserMessages) {
        if (message.parts.isNotEmpty) {
          final userContent = message.parts
              .where((part) => part.type == 'text')
              .map((part) => part.content ?? '')
              .join(' ')
              .trim()
              .toLowerCase();

          // Check for EXACT echo (assistant exactly repeating user input)
          if (userContent == contentLower) {
            print('🚫 [ChatBloc] Exact echo detected - blocking assistant message that exactly repeats user input: "$content"');
            return true;
          }

          // If assistant message is much longer, it's probably a legitimate response that includes the user's content
          if (contentLower.length > userContent.length * 1.5) {
            continue;
          }

          // Check if it starts with common response patterns (legitimate responses)
          final responsePatterns = [
            'i\'ll help you',
            'i can help',
            'let me help',
            'to test',
            'for testing',
            'you can test',
            'here\'s how',
            'to do this',
          ];

          bool isLegitimateResponse = responsePatterns.any((pattern) => 
              contentLower.startsWith(pattern));

          if (isLegitimateResponse) {
            continue;
          }

          // If it contains the user content but has additional meaningful content, allow it
          if (contentLower.contains(userContent) && contentLower.length > userContent.length + 10) {
            continue;
          }
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
      sessionId: sessionBloc.currentSessionId!,
      messages: List.from(_messages),
      isStreaming: streaming,
    );
  }

  void _rebuildMessageIndex() {
    _messageIndex.clear();
    for (int i = 0; i < _messages.length; i++) {
      _messageIndex[_messages[i].id] = i;
    }
  }

  void _emitCurrentState(Emitter<ChatState> emit) {
    if (sessionBloc.currentSessionId != null) {
      emit(_createChatReadyState());
    }
  }

  void _updateMessageStatus(String messageId, MessageSendStatus status) {
    // Use O(1) lookup with message index map
    final index = _messageIndex[messageId];
    
    if (index != null && index < _messages.length) {
      final originalMessage = _messages[index];
      _messages[index] = originalMessage.copyWith(sendStatus: status);
      print('📬 [ChatBloc] Updated message $messageId status to $status');
    } else {
      print('📬 [ChatBloc] Message $messageId not found for status update');
    }
  }

  /// Restart SSE event subscription - used when SSE service reconnects to new server
  void restartSSESubscription() {
    print('🔄 [ChatBloc] Restarting SSE subscription...');
    
    // Cancel existing subscription
    _eventSubscription?.cancel();
    
    // Reestablish SSE event subscription
    _eventSubscription = sseService.connectToEventStream().listen(
      (sseEvent) {
        // Only process events for the current session
        if (sseEvent.sessionId == sessionBloc.currentSessionId) {
          add(SSEEventReceived(sseEvent));
        }
      },
      onError: (error) {
        // Errors are now handled by the ConnectionBloc and displayed in the ConnectionStatusRow.
        print('❌ [ChatBloc] SSE stream error after restart: $error');
      },
    );
    
    print('✅ [ChatBloc] SSE subscription restarted successfully');
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    _sessionSubscription?.cancel();
    _permanentSessionSubscription?.cancel();
    messageQueueService.dispose();
    return super.close();
  }
}
