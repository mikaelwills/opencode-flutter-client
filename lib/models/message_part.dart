import 'package:equatable/equatable.dart';

class MessagePart extends Equatable {
  final String id;
  final String type; // 'text', 'tool', 'diff', 'plan-options'
  final String? content;
  final Map<String, dynamic>? metadata;

  const MessagePart({
    required this.id,
    required this.type,
    this.content,
    this.metadata,
  });

  factory MessagePart.fromJson(Map<String, dynamic> json) {
    // print('🔍 [MessagePart] Parsing part: $json'); // REMOVED: Too verbose, can contain large content
    
    final id = json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    final type = json['type'] as String;
    final content = json['text'] as String? ?? json['content'] as String?;
    
    // Extract metadata from various fields
    Map<String, dynamic>? metadata = json['metadata'] as Map<String, dynamic>?;
    
    // Add additional fields as metadata if they exist
    metadata ??= <String, dynamic>{};
    
    // Add time information if present
    if (json['time'] != null) {
      metadata['time'] = json['time'];
    }
    
    // Add tokens information if present
    if (json['tokens'] != null) {
      metadata['tokens'] = json['tokens'];
    }
    
    // Add cost information if present
    if (json['cost'] != null) {
      metadata['cost'] = json['cost'];
    }
    
    // For tool parts, preserve all tool-related fields as metadata
    if (type == 'tool') {
      // Add tool name if present
      if (json['tool'] != null) {
        metadata['tool'] = json['tool'];
      }
      
      // Add call ID if present
      if (json['callID'] != null) {
        metadata['callID'] = json['callID'];
      }
      
      // Add state information if present
      if (json['state'] != null) {
        metadata['state'] = json['state'];
      }
      
      // Add any other tool-specific fields
      for (final field in ['name', 'status', 'input', 'output', 'args']) {
        if (json.containsKey(field) && json[field] != null) {
          metadata[field] = json[field];
        }
      }
    }
    
    // Only log tool parts when they're actually created (reduce spam)
    if (type == 'tool' && (metadata['tool'] != null || metadata['name'] != null)) {
      print('🔧 Tool: ${metadata['tool'] ?? metadata['name']}');
    }
    
    return MessagePart(
      id: id,
      type: type,
      content: content,
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'content': content,
      'metadata': metadata,
    };
  }

  MessagePart copyWith({
    String? id,
    String? type,
    String? content,
    Map<String, dynamic>? metadata,
  }) {
    return MessagePart(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [id, type, content, metadata];
}