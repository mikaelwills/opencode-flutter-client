import 'package:flutter/material.dart';
import '../theme/opencode_theme.dart';
import '../models/opencode_message.dart';
import 'message_part_widget.dart';

class MessageBubble extends StatelessWidget {
  final OpenCodeMessage message;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    print('🔍 [MessageBubble] Building message bubble');
    print('🔍 [MessageBubble] Message ID: ${message.id}');
    print('🔍 [MessageBubble] Message role: ${message.role}');
    print('🔍 [MessageBubble] Message parts: ${message.parts.length}');
    print('🔍 [MessageBubble] Is streaming: $isStreaming');
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message header with role indicator
          if (message.role == 'user')
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Text(
                    OpenCodeSymbols.prompt,
                    style: OpenCodeTextStyles.prompt,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message.parts.isNotEmpty && message.parts.first.content != null
                        ? message.parts.first.content!
                        : '',
                    style: OpenCodeTextStyles.terminal,
                  ),
                ],
              ),
            ),

          // Assistant message parts
          if (message.role == 'assistant') ...[
            ...message.parts.map((part) {
              print('🔍 [MessageBubble] Creating MessagePartWidget for part: ${part.type}');
              return MessagePartWidget(
                part: part,
                isStreaming: isStreaming && part == message.parts.last,
              );
            }),
          ],

          // Streaming indicator - only show if actually streaming and has content
          if (isStreaming && 
              message.role == 'assistant' && 
              message.parts.isNotEmpty &&
              message.parts.any((part) => part.type == 'text' && (part.content?.isNotEmpty ?? false)))
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: OpenCodeTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Streaming...',
                    style: OpenCodeTextStyles.terminal.copyWith(
                      fontSize: 12,
                      color: OpenCodeTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}