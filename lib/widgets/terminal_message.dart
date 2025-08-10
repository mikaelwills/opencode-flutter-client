import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/opencode_theme.dart';
import '../models/opencode_message.dart';
import '../models/message_part.dart';
import '../utils/text_sanitizer.dart';
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
        TextSanitizer.sanitize(content, preserveMarkdown: false),
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
              text: TextSanitizer.sanitize(part.content!, preserveMarkdown: true),
              style: OpenCodeTextStyles.terminal,
              isStreaming: true,
              useMarkdown: true,
            )
          : MarkdownBody(
              data: TextSanitizer.sanitize(part.content!, preserveMarkdown: true),
              styleSheet: MarkdownStyleSheet(
                p: OpenCodeTextStyles.terminal,
                code: OpenCodeTextStyles.code,
                codeblockDecoration: BoxDecoration(
                  color: OpenCodeTheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                codeblockPadding: const EdgeInsets.all(8),
                blockquote: OpenCodeTextStyles.terminal.copyWith(
                  color: OpenCodeTheme.textSecondary,
                ),
                blockquoteDecoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: OpenCodeTheme.textSecondary,
                      width: 2,
                    ),
                  ),
                ),
                h1: OpenCodeTextStyles.terminal.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                h2: OpenCodeTextStyles.terminal.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                h3: OpenCodeTextStyles.terminal.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                listBullet: OpenCodeTextStyles.terminal,
                listIndent: 16,
              ),
              selectable: true,
            ),
    );
  }

  Widget _buildToolPart(MessagePart part) {
    final toolName = _getToolDisplayName(part);
    
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Text(
        TextSanitizer.sanitize(toolName, preserveMarkdown: false),
        style: OpenCodeTextStyles.terminal.copyWith(
          color: OpenCodeTheme.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
  
  String _getToolDisplayName(MessagePart part) {
    // Try multiple metadata fields for tool name
    final metadata = part.metadata ?? {};
    
    // Primary tool name sources - based on actual SSE data structure
    String? toolName = metadata['tool'] as String? ??
                      metadata['name'] as String? ?? 
                      metadata['tool_name'] as String? ??
                      metadata['function_name'] as String?;
    
    // If no name found, try to extract from other metadata
    if (toolName == null || toolName.isEmpty) {
      // Default fallback
      return 'tool';
    }
    
    // Extract additional context from state.input if available
    final state = metadata['state'] as Map<String, dynamic>?;
    final input = state?['input'] as Map<String, dynamic>?;
    
    if (input != null) {
      // For file operations, show the file path
      final filePath = input['path'] as String? ?? input['filePath'] as String?;
      if (filePath != null) {
        final fileName = filePath.split('/').last;
        final cleanToolName = _formatToolName(toolName);
        return '$cleanToolName $fileName';
      }
      
      // For bash commands, show command
      final command = input['command'] as String?;
      if (command != null) {
        final commandName = command.split(' ').first;
        return 'bash $commandName';
      }
      
      // For grep/search operations
      final pattern = input['pattern'] as String?;
      if (pattern != null) {
        return 'search "$pattern"';
      }
    }
    
    // Clean up the tool name for better display
    return _formatToolName(toolName);
  }
  
  String _formatToolName(String toolName) {
    // Convert common tool names to more readable format
    switch (toolName.toLowerCase()) {
      case 'read':
        return 'read';
      case 'write':
        return 'write';
      case 'bash':
        return 'bash';
      case 'grep':
        return 'search';
      case 'list':
        return 'list';
      case 'glob':
        return 'find';
      case 'obsidian-server_view':
        return 'view';
      case 'obsidian-server_str_replace':
        return 'edit';
      case 'obsidian-server_create':
        return 'create';
      case 'storage.write':
        return 'write';
      default:
        // Remove prefixes and clean up tool names
        if (toolName.contains('_')) {
          return toolName.split('_').last;
        }
        return toolName;
    }
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