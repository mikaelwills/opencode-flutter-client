import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/opencode_theme.dart';
import '../models/opencode_message.dart';
import '../models/message_part.dart';
import '../utils/text_sanitizer.dart';
import '../utils/tool_display_helper.dart';
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
        _safeTextSanitize(content, preserveMarkdown: false),
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
              text: _safeTextSanitize(part.content!, preserveMarkdown: true),
              style: OpenCodeTextStyles.terminal,
              isStreaming: true,
              useMarkdown: true,
            )
          : MarkdownBody(
              data: _safeTextSanitize(part.content!, preserveMarkdown: true),
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
    final toolName = ToolDisplayHelper.getDisplayName(part);
    
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Text(
        _safeTextSanitize(toolName, preserveMarkdown: false),
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

  /// Safe text sanitization with fallback handling
  String _safeTextSanitize(String text, {bool preserveMarkdown = true}) {
    try {
      return TextSanitizer.sanitize(text, preserveMarkdown: preserveMarkdown);
    } catch (e) {
      print('⚠️ [TerminalMessage] Text sanitization failed, using ASCII fallback: $e');
      return TextSanitizer.sanitizeToAscii(text);
    }
  }

}