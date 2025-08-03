import 'package:flutter/material.dart';
import '../theme/opencode_theme.dart';
import '../models/opencode_message.dart';
import '../models/message_part.dart';
import 'streaming_text.dart';

class TerminalMessage extends StatelessWidget {
  final OpenCodeMessage message;
  final bool isStreaming;

  const TerminalMessage({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.role == 'user') _buildUserMessage(),
        if (message.role == 'assistant') ...[
          const SizedBox(height: 16),
          _buildAssistantMessage(),
          const SizedBox(height: 16), // Space below assistant response
        ],
      ],
    );
  }

  Widget _buildUserMessage() {
    final content = message.parts.isNotEmpty && message.parts.first.content != null
        ? message.parts.first.content!
        : '';
    
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Color(0xFF444444),
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 12, top: 8, bottom: 12),
      child: Text(
        content,
        style: OpenCodeTextStyles.terminal,
      ),
    );
  }

  Widget _buildAssistantMessage() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: OpenCodeTheme.secondary,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 12, top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...message.parts.map((part) => _buildMessagePart(part)),
        ],
      ),
    );
  }

  Widget _buildMessagePart(MessagePart part) {
    switch (part.type) {
      case 'text':
        return _buildTextPart(part);
      case 'tool':
        return _buildToolPart(part);
      case 'step-start':
        return _buildStepStartPart(part);
      case 'step-finish':
        return _buildStepFinishPart(part);
      default:
        return _buildTextPart(part);
    }
  }

  Widget _buildTextPart(MessagePart part) {
    if (part.content == null || part.content!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isLastPart = message.parts.last == part;
    final shouldStream = isStreaming && isLastPart && message.role == 'assistant';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: shouldStream
          ? StreamingText(
              text: part.content!,
              style: OpenCodeTextStyles.terminal,
              isStreaming: true,
            )
          : Text(
              part.content!,
              style: OpenCodeTextStyles.terminal,
            ),
    );
  }

  Widget _buildToolPart(MessagePart part) {
    print('🔧 [TerminalMessage] Building tool part with metadata: ${part.metadata}');
    print('🔧 [TerminalMessage] Tool part content: ${part.content}');
    
    // Extract tool name from metadata
    String toolName = part.metadata?['name'] as String? ?? 
                      part.metadata?['tool_name'] as String? ??
                      part.metadata?['function_name'] as String? ??
                      'tool';
    
    // Convert storage.write to a more user-friendly name
    if (toolName == 'storage.write') {
      toolName = 'write_file';
    }
    
    // Extract key parameter - prioritize common ones
    String? keyParam;
    final metadata = part.metadata;
    if (metadata != null) {
      // Try common parameter names
      keyParam = metadata['file_path'] as String? ??
                 metadata['path'] as String? ??
                 metadata['command'] as String? ??
                 metadata['url'] as String? ??
                 metadata['key'] as String?;
      
      // If parameters object exists, try to extract from there
      if (keyParam == null && metadata['parameters'] is Map<String, dynamic>) {
        final params = metadata['parameters'] as Map<String, dynamic>;
        keyParam = params['file_path'] as String? ??
                   params['path'] as String? ??
                   params['command'] as String? ??
                   params['url'] as String? ??
                   params['key'] as String?;
      }
      
      // Check if content might contain useful info
      if (keyParam == null && part.content != null && part.content!.isNotEmpty) {
        // If content is short enough, use it as the parameter
        if (part.content!.length < 100) {
          keyParam = part.content;
        }
      }
    }
    
    // Format the display text
    final displayText = keyParam != null ? '$toolName: $keyParam' : toolName;
    
    print('🔧 [TerminalMessage] Final tool display text: "$displayText"');
    
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Text(
        displayText,
        style: OpenCodeTextStyles.terminal.copyWith(
          color: OpenCodeTheme.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStepStartPart(MessagePart part) {
    // Hide step start messages
    return const SizedBox.shrink();
  }

  Widget _buildStepFinishPart(MessagePart part) {
    // Hide step finish messages
    return const SizedBox.shrink();
  }


}