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
  Timer? _retryTimer;
  
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

  /// Initialize listeners for connection and session state changes
  void _initConnectionListener() {
    _connectionSubscription = connectionBloc.stream.listen((connectionState) {
      print('📬 [MessageQueue] Connection state: ${connectionState.runtimeType}');
      
      if (connectionState is Connected) {
        print('📬 [MessageQueue] Connected - processing ${_messageQueue.length} queued messages');
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
    
    if (connectionState is Connected) {
      // Online: send directly
      print('📬 [MessageQueue] Online - sending message directly: "$content"');
      onStatusChange(MessageSendStatus.sending);
      await _sendMessageDirect(messageId, sessionId, content, onStatusChange);
    } else {
      // Offline: add to queue
      print('📬 [MessageQueue] Offline - queuing message: "$content"');
      final queuedMessage = QueuedMessage(
        messageId: messageId,
        sessionId: sessionId,
        content: content,
        queuedAt: DateTime.now(),
        onStatusChange: onStatusChange,
      );
      
      _messageQueue.add(queuedMessage);
      onStatusChange(MessageSendStatus.queued);
      print('📬 [MessageQueue] Message queued. Queue size: ${_messageQueue.length}');
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
      print('📬 [MessageQueue] No messages in queue to process');
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
    try {
      onStatusChange(MessageSendStatus.sending);
      
      // Use SessionBloc's direct method with timeout - NO SUBSCRIPTIONS
      await sessionBloc.sendMessageDirect(sessionId, content)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Send timeout', const Duration(seconds: 10)),
          );
      
      // Success - Future completed normally
      print('📬 [MessageQueue] Message sent successfully: "$content"');
      onStatusChange(MessageSendStatus.sent);
      
    } catch (error) {
      // Any error (network, timeout, validation)
      print('📬 [MessageQueue] Send error: $error');
      onStatusChange(MessageSendStatus.failed);
      // Don't rethrow - error handled via callback
    }
  }

  /// Get current queue size
  int get queueSize => _messageQueue.length;

  /// Check if service is currently connected
  bool get isConnected => connectionBloc.state is Connected;

  /// Dispose resources
  void dispose() {
    _connectionSubscription?.cancel();
    _sessionSubscription?.cancel();
    _retryTimer?.cancel();
    _messageQueue.clear();
    print('📬 [MessageQueue] Service disposed');
  }
}