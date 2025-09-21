import 'dart:async';
import 'dart:collection';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_state.dart';
import '../models/opencode_message.dart';

/// Represents a queued message with retry metadata
class QueuedMessage {
  final String messageId;
  final String sessionId;
  final String content;
  final DateTime queuedAt;
  final Function(MessageSendStatus) onStatusChange;
  int retryCount;
  DateTime? lastRetryAt;

  QueuedMessage({
    required this.messageId,
    required this.sessionId,
    required this.content,
    required this.queuedAt,
    required this.onStatusChange,
    this.retryCount = 0,
    this.lastRetryAt,
  });
}

/// Service to handle message queuing for offline scenarios and retry logic
class MessageQueueService {
  final ConnectionBloc connectionBloc;
  final SessionBloc sessionBloc;
  
  final Queue<QueuedMessage> _messageQueue = Queue<QueuedMessage>();
  StreamSubscription<ConnectionState>? _connectionSubscription;
  StreamSubscription<SessionState>? _sessionSubscription;
  StreamSubscription? _chatBlocSubscription;
  Timer? _retryTimer;
  
  // Track pending messages waiting for SSE confirmation
  final Map<String, Timer> _pendingMessageTimeouts = {};
  final Map<String, Function(MessageSendStatus)> _pendingCallbacks = {};
  
  static const int maxRetries = 3;
  static const List<Duration> retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  MessageQueueService({
    required this.connectionBloc,
    required this.sessionBloc,
  }) {
    _initConnectionListener();
  }
  
  /// Initialize ChatBloc listener - called after ChatBloc is created
  void initChatBlocListener(dynamic chatBloc) {
    _chatBlocSubscription = chatBloc.stream.listen((chatState) {
      // Check if assistant started streaming (ChatReady with isStreaming: true)
      if (chatState.runtimeType.toString().contains('ChatReady')) {
        final isStreaming = chatState.isStreaming as bool? ?? false;
        if (isStreaming) {
          _handleStreamingStarted();
        }
      }
    });
  }
  
  /// Called when assistant starts streaming - marks pending message as sent
  void _handleStreamingStarted() {
    print('📬 [MessageQueue] Assistant streaming started - checking for pending messages');
    
    // Mark the most recent pending message as sent
    if (_pendingMessageTimeouts.isNotEmpty) {
      final messageId = _pendingMessageTimeouts.keys.first;
      print('📬 [MessageQueue] Marking pending message $messageId as sent via SSE');
      _markMessageSentViaSSE(messageId);
    }
  }
  
  /// Mark a message as sent via SSE (cancel timeout)
  void _markMessageSentViaSSE(String messageId) {
    if (_pendingMessageTimeouts.containsKey(messageId)) {
      // Cancel timeout
      _pendingMessageTimeouts[messageId]?.cancel();
      
      // Mark as sent
      final callback = _pendingCallbacks[messageId];
      if (callback != null) {
        print('📊 [MessageQueue] Message $messageId status → sent (reason: SSE streaming started)');
        callback(MessageSendStatus.sent);
      }
      
      // Clean up
      _cleanupPendingMessage(messageId);
    }
  }
  
  /// Mark a message as failed
  void _markMessageFailed(String messageId, String reason) {
    final callback = _pendingCallbacks[messageId];
    if (callback != null) {
      print('📊 [MessageQueue] Message $messageId status → failed (reason: $reason)');
      callback(MessageSendStatus.failed);
    }
    _cleanupPendingMessage(messageId);
  }
  
  /// Clean up tracking for a message
  void _cleanupPendingMessage(String messageId) {
    _pendingMessageTimeouts.remove(messageId)?.cancel();
    _pendingCallbacks.remove(messageId);
    print('📬 [MessageQueue] Cleaned up pending message: $messageId');
  }

  /// Initialize listeners for connection and session state changes
  void _initConnectionListener() {
    _connectionSubscription = connectionBloc.stream.listen((connectionState) {
      
      if (connectionState is Connected) {
        _processQueue();
      }
    });
    
    // Listen for session state changes to clear queue when session becomes invalid
    _sessionSubscription = sessionBloc.stream.listen((sessionState) {
      if (sessionState is SessionError || sessionState is SessionNotFound) {
        print('📬 [MessageQueue] Session invalid - clearing ${_messageQueue.length} queued messages');
        _messageQueue.clear();
      }
    });
  }

  /// Send a message, queuing if offline or sending directly if online
  Future<void> sendMessage({
    required String messageId,
    required String sessionId,
    required String content,
    required Function(MessageSendStatus) onStatusChange,
  }) async {
    final connectionState = connectionBloc.state;
    print('📤 [MessageQueue] Sending message $messageId: "$content" (session: $sessionId, connectionState: ${connectionState.runtimeType})');
    
    if (connectionState is Connected) {
      // Online: send directly
      print('📬 [MessageQueue] Online - sending message $messageId directly');
      onStatusChange(MessageSendStatus.sending);
      await _sendMessageDirect(messageId, sessionId, content, onStatusChange);
    } else {
      // Offline: add to queue
      print('📬 [MessageQueue] Offline (${connectionState.runtimeType}) - queuing message $messageId');
      final queuedMessage = QueuedMessage(
        messageId: messageId,
        sessionId: sessionId,
        content: content,
        queuedAt: DateTime.now(),
        onStatusChange: onStatusChange,
      );
      
      _messageQueue.add(queuedMessage);
      onStatusChange(MessageSendStatus.queued);
      print('📬 [MessageQueue] Message $messageId queued. Queue size: ${_messageQueue.length}');
    }
  }

  /// Remove a message from the queue (user-requested deletion)
  bool removeFromQueue(String messageId) {
    final initialSize = _messageQueue.length;
    _messageQueue.removeWhere((msg) => msg.messageId == messageId);
    final removed = _messageQueue.length < initialSize;
    
    if (removed) {
      print('📬 [MessageQueue] Removed message from queue: $messageId');
    }
    
    return removed;
  }

  /// Retry a failed message manually
  Future<void> retryMessage({
    required String messageId,
    required String sessionId,
    required String content,
    required Function(MessageSendStatus) onStatusChange,
  }) async {
    print('📬 [MessageQueue] Manual retry requested for message: "$content"');
    onStatusChange(MessageSendStatus.sending);
    await _sendMessageDirect(messageId, sessionId, content, onStatusChange);
  }

  /// Process all queued messages when connection is restored
  Future<void> _processQueue() async {
    if (_messageQueue.isEmpty) {
      return;
    }

    // Process messages one by one to avoid overwhelming the server
    while (_messageQueue.isNotEmpty) {
      final message = _messageQueue.removeFirst();
      print('📬 [MessageQueue] Processing queued message: "${message.content}"');
      
      message.onStatusChange(MessageSendStatus.sending);
      await _sendMessageDirect(
        message.messageId,
        message.sessionId, 
        message.content,
        message.onStatusChange,
      );
      
      // Small delay between messages to avoid overwhelming server
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Send message directly via SessionBloc using Future approach (no subscriptions)
  Future<void> _sendMessageDirect(
    String messageId,
    String sessionId,
    String content,
    Function(MessageSendStatus) onStatusChange,
  ) async {
    final startTime = DateTime.now();
    print('📤 [MessageQueue] Message $messageId - calling SessionBloc.sendMessageDirect at ${startTime.millisecondsSinceEpoch}');
    
    // Set initial status
    onStatusChange(MessageSendStatus.sending);
    print('📊 [MessageQueue] Message $messageId status → sending (reason: starting SessionBloc call)');
    
    // Start timeout timer (will be cancelled if SSE streaming starts)
    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_pendingMessageTimeouts.containsKey(messageId)) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        print('⏱️ [MessageQueue] Message $messageId - timeout after ${elapsed}ms (no SSE response)');
        _markMessageFailed(messageId, 'Timeout - no response from server');
      }
    });
    
    // Track this pending message
    _pendingMessageTimeouts[messageId] = timeoutTimer;
    _pendingCallbacks[messageId] = onStatusChange;
    print('📬 [MessageQueue] Message $messageId - tracking as pending with timeout');
    
    // Start HTTP request (don't await it)
    final httpFuture = sessionBloc.sendMessageDirect(sessionId, content);
    
    // Handle the eventual HTTP completion (but don't wait for it)
    httpFuture.then((_) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      print('📤 [MessageQueue] Message $messageId - HTTP completed successfully in ${elapsed}ms');
      // Don't update status here - SSE streaming will have already handled it
      _cleanupPendingMessage(messageId);
    }).catchError((error) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      print('❌ [MessageQueue] Message $messageId - HTTP failed after ${elapsed}ms: $error');
      // Only mark as failed if not already handled by SSE or timeout
      if (_pendingMessageTimeouts.containsKey(messageId)) {
        _markMessageFailed(messageId, 'HTTP error: ${error.runtimeType}: $error');
      }
    });
  }

  /// Get current queue size
  int get queueSize => _messageQueue.length;

  /// Check if service is currently connected
  bool get isConnected => connectionBloc.state is Connected;

  /// Dispose resources
  void dispose() {
    _connectionSubscription?.cancel();
    _sessionSubscription?.cancel();
    _chatBlocSubscription?.cancel();
    _retryTimer?.cancel();
    _messageQueue.clear();
    
    // Cancel any pending timeouts
    for (final timer in _pendingMessageTimeouts.values) {
      timer.cancel();
    }
    _pendingMessageTimeouts.clear();
    _pendingCallbacks.clear();
    
    print('📬 [MessageQueue] Service disposed');
  }
}