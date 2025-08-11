import 'package:equatable/equatable.dart';
import 'message_part.dart';

/// Enum to track the sending status of a user-authored message.
enum MessageSendStatus {
  // Message has been successfully sent and acknowledged by the server.
  sent,
  // The message failed to send and can be retried.
  failed,
  // Message is queued for sending when network connection is restored.
  queued,
  // Message is currently being sent to the server.
  sending,
}

class OpenCodeMessage extends Equatable {
  final String id;
  final String sessionId;
  final String role; // 'user' or 'assistant'
  final DateTime created;
  final DateTime? completed;
  final List<MessagePart> parts;
  final bool isStreaming;
  final MessageSendStatus? sendStatus; // Nullable, only for user messages

  const OpenCodeMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.created,
    this.completed,
    required this.parts,
    this.isStreaming = false,
    this.sendStatus,
  });

  factory OpenCodeMessage.fromJson(Map<String, dynamic> json) {
    // Handle both direct message format and nested info format
    final info = json['info'] as Map<String, dynamic>?;
    final time = info?['time'] as Map<String, dynamic>?;
    
    // Extract ID from various possible locations
    final id = info?['id'] as String? ?? 
               json['id'] as String? ?? 
               DateTime.now().millisecondsSinceEpoch.toString();
    
    // Extract session ID
    final sessionId = info?['sessionID'] as String? ?? 
                      json['sessionID'] as String? ?? 
                      json['sessionId'] as String? ?? '';
    
    // Extract role
    final role = info?['role'] as String? ?? 
                 json['role'] as String? ?? 
                 'assistant';
    
    // Handle timestamps (could be milliseconds or ISO strings)
    DateTime createdTime;
    try {
      final createdValue = time?['created'] ?? json['created'];
      if (createdValue is int) {
        createdTime = DateTime.fromMillisecondsSinceEpoch(createdValue);
      } else if (createdValue is String) {
        createdTime = DateTime.parse(createdValue);
      } else {
        createdTime = DateTime.now();
      }
    } catch (e) {
      createdTime = DateTime.now();
    }
    
    DateTime? completedTime;
    try {
      final completedValue = time?['completed'] ?? json['completed'];
      if (completedValue is int) {
        completedTime = DateTime.fromMillisecondsSinceEpoch(completedValue);
      } else if (completedValue is String) {
        completedTime = DateTime.parse(completedValue);
      }
    } catch (e) {
      completedTime = null;
    }

    return OpenCodeMessage(
      id: id,
      sessionId: sessionId,
      role: role,
      created: createdTime,
      completed: completedTime,
      parts: (json['parts'] as List<dynamic>?)
              ?.map((part) => MessagePart.fromJson(part as Map<String, dynamic>))
              .toList() ??
          [],
      isStreaming: json['isStreaming'] as bool? ?? 
                   (completedTime == null && role == 'assistant'),
    );
  }



  /// Factory constructor specifically for OpenCode API responses
  factory OpenCodeMessage.fromApiResponse(Map<String, dynamic> json) {
    // Extract the message info - it's directly in the response
    final messageId = json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final sessionId = json['sessionID'] as String? ?? 
                      json['sessionId'] as String? ?? 
                      json['session_id'] as String? ?? '';
    
    
    // Check if session ID might be in nested data
    if (json.containsKey('parts') && json['parts'] is List) {
      final parts = json['parts'] as List;
      // Check if session ID might be in nested part data
      if (parts.isNotEmpty && parts[0] is Map<String, dynamic>) {
        // Part data available for potential session ID extraction
      }
    }
    
    final role = json['role'] as String? ?? 'assistant';
    
    // Handle time - it's nested in the response
    final timeData = json['time'] as Map<String, dynamic>?;
    DateTime createdTime = DateTime.now();
    DateTime? completedTime;
    
    if (timeData != null) {
      try {
        if (timeData['created'] != null) {
          createdTime = DateTime.fromMillisecondsSinceEpoch(timeData['created'] as int);
        }
        if (timeData['completed'] != null) {
          completedTime = DateTime.fromMillisecondsSinceEpoch(timeData['completed'] as int);
        }
      } catch (e) {
        print('❌ [OpenCodeMessage] Error parsing time: $e');
      }
    }
    
    // Parse parts - this is the key part that was missing
    final partsList = json['parts'] as List<dynamic>? ?? [];
    final parts = partsList.map((partData) {
      return MessagePart.fromJson(partData as Map<String, dynamic>);
    }).toList();
    
    print('🔍 [OpenCodeMessage] Parsed ${parts.length} parts');
    // Removed individual part content logging to prevent giant system prompt dumps
    
    // A message is only streaming if:
    // 1. It's an assistant message AND
    // 2. It has no completed time AND  
    // 3. At least one part doesn't have an end time
    bool isMessageStreaming = false;
    if (role == 'assistant' && completedTime == null) {
      // Check if any text parts are still streaming (no end time)
      for (final part in parts) {
        if (part.type == 'text' && part.metadata != null) {
          final timeData = part.metadata!['time'] as Map<String, dynamic>?;
          if (timeData != null && timeData['end'] == null) {
            isMessageStreaming = true;
            break;
          }
        }
      }
    }
    
    final message = OpenCodeMessage(
      id: messageId,
      sessionId: sessionId,
      role: role,
      created: createdTime,
      completed: completedTime,
      parts: parts,
      isStreaming: isMessageStreaming,
    );
    
    print('📝 Message ${message.id}: ${message.parts.length} parts');
    return message;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'role': role,
      'created': created.toIso8601String(),
      'completed': completed?.toIso8601String(),
      'parts': parts.map((part) => part.toJson()).toList(),
      'isStreaming': isStreaming,
      'sendStatus': sendStatus?.toString(), // Add sendStatus to JSON
    };
  }

  OpenCodeMessage copyWith({
    String? id,
    String? sessionId,
    String? role,
    DateTime? created,
    DateTime? completed,
    List<MessagePart>? parts,
    bool? isStreaming,
    MessageSendStatus? sendStatus,
  }) {
    return OpenCodeMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      created: created ?? this.created,
      completed: completed ?? this.completed,
      parts: parts ?? this.parts,
      isStreaming: isStreaming ?? this.isStreaming,
      sendStatus: sendStatus ?? this.sendStatus,
    );
  }

  @override
  List<Object?> get props => [id, sessionId, role, created, completed, parts, isStreaming, sendStatus];
}