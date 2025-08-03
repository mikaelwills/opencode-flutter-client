import 'package:equatable/equatable.dart';

class OpenCodeEvent extends Equatable {
  final String type;
  final String? sessionId;
  final String? messageId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const OpenCodeEvent({
    required this.type,
    this.sessionId,
    this.messageId,
    this.data,
    required this.timestamp,
  });

  factory OpenCodeEvent.fromJson(Map<String, dynamic> json) {
    
    final eventType = json['type'] as String;
    String? sessionId;
    String? messageId;
    
    // Try multiple field name variations for session ID at root level
    sessionId = json['sessionId'] as String? ?? 
                json['sessionID'] as String? ?? 
                json['session_id'] as String?;
    
    // Try multiple field name variations for message ID at root level
    messageId = json['messageId'] as String? ?? 
                json['messageID'] as String? ?? 
                json['message_id'] as String?;
    
    
    // If not found at root level, check nested properties based on event type
    if (sessionId == null || messageId == null) {
      if (json['properties'] is Map<String, dynamic>) {
        final properties = json['properties'] as Map<String, dynamic>;
        
        // For session.idle events, session ID is directly in properties
        if (eventType == 'session.idle') {
          sessionId = sessionId ?? (properties['sessionID'] as String? ?? properties['sessionId'] as String?);
          messageId = messageId ?? (properties['messageID'] as String? ?? properties['messageId'] as String?);
        }
        
        // For message.part.updated events, session info is in properties.part
        else if (eventType == 'message.part.updated' && properties['part'] is Map<String, dynamic>) {
          final part = properties['part'] as Map<String, dynamic>;
          sessionId = sessionId ?? (part['sessionID'] as String? ?? part['sessionId'] as String?);
          messageId = messageId ?? (part['messageID'] as String? ?? part['messageId'] as String?);
        }
        
        // For storage.write events, extract session ID from the key path
        else if (eventType == 'storage.write' && properties['key'] is String) {
          final key = properties['key'] as String;
          // Key format: "session/part/ses_XXX/msg_XXX/prt_XXX"
          final keyParts = key.split('/');
          if (keyParts.length >= 3 && keyParts[2].startsWith('ses_')) {
            sessionId = sessionId ?? keyParts[2];
          }
          if (keyParts.length >= 4 && keyParts[3].startsWith('msg_')) {
            messageId = messageId ?? keyParts[3];
          }
          
          // Also check if there's session info in the content
          if (properties['content'] is Map<String, dynamic>) {
            final content = properties['content'] as Map<String, dynamic>;
            sessionId = sessionId ?? (content['sessionID'] as String? ?? content['sessionId'] as String?);
            messageId = messageId ?? (content['messageID'] as String? ?? content['messageId'] as String?);
          }
        }
      }
    }
    
    return OpenCodeEvent(
      type: eventType,
      sessionId: sessionId,
      messageId: messageId,
      data: json,  // Store the entire JSON for later processing
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'sessionId': sessionId,
      'messageId': messageId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [type, sessionId, messageId, data, timestamp];
}